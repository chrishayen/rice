const std = @import("std");
const config = @import("config.zig");
const led = @import("led.zig");
const ipc = @import("ipc.zig");
const ipc_commands = @import("ipc_commands.zig");
const device_cache = @import("device_cache.zig");

const ServiceState = struct {
    led_device: ?led.LedDevice,
    socket_server: ipc.SocketServer,
    running: std.atomic.Value(bool),
    poll_interval_seconds: u32,
    devices_cache: std.ArrayList(led.RfDeviceInfo),
    devices_mutex: std.Thread.Mutex,
    master_poll_thread: ?std.Thread,
    device_query_thread: ?std.Thread,
    epoll_fd: i32,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) ServiceState {
        return ServiceState{
            .led_device = null,
            .socket_server = undefined,
            .running = std.atomic.Value(bool).init(true),
            .poll_interval_seconds = 10,
            .devices_cache = .{},
            .devices_mutex = std.Thread.Mutex{},
            .master_poll_thread = null,
            .device_query_thread = null,
            .epoll_fd = -1,
            .allocator = allocator,
        };
    }
};

pub fn runService(allocator: std.mem.Allocator) !void {
    std.log.info("Starting Fan Control Service...", .{});

    // Initialize config directory
    try config.initConfigDir(allocator);
    const config_dir = try config.getConfigDir(allocator);
    defer allocator.free(config_dir);
    std.log.info("Config directory: {s}", .{config_dir});

    // Get socket path
    const socket_path = try config.getSocketPath(allocator);
    defer allocator.free(socket_path);
    std.log.info("Socket path: {s}", .{socket_path});

    // Clean up old socket
    _ = config.cleanupSocket(allocator);

    var state = ServiceState.init(allocator);
    defer state.devices_cache.deinit(allocator);

    // Initialize LED device (optional - service continues without it)
    if (led.initLedDevice(allocator)) |device| {
        state.led_device = device;
    } else |err| {
        std.log.warn("Failed to initialize LED device: {}", .{err});
        std.log.warn("Service will continue without hardware access", .{});
        std.log.warn("Make sure USB devices are connected and you have proper permissions", .{});
    }
    defer if (state.led_device) |*device| led.cleanupLedDevice(device);

    // Create socket server
    state.socket_server = try ipc.createSocketServer(socket_path, allocator);
    defer ipc.closeServer(&state.socket_server);
    std.log.info("Socket server listening on {s}", .{socket_path});

    // Create epoll instance
    state.epoll_fd = try std.posix.epoll_create1(std.os.linux.EPOLL.CLOEXEC);
    defer std.posix.close(state.epoll_fd);

    // Add server socket to epoll
    var event = std.os.linux.epoll_event{
        .events = std.os.linux.EPOLL.IN,
        .data = .{ .fd = state.socket_server.socket_fd },
    };
    try std.posix.epoll_ctl(state.epoll_fd, std.os.linux.EPOLL.CTL_ADD, state.socket_server.socket_fd, &event);

    // Start master polling thread
    state.master_poll_thread = try std.Thread.spawn(.{}, masterPollingThread, .{&state});

    // Start device query thread
    state.device_query_thread = try std.Thread.spawn(.{}, deviceQueryThread, .{&state});

    std.log.info("Service initialized successfully", .{});
    std.log.info("Press Ctrl+C to stop", .{});

    // Main service loop
    const MAX_EVENTS = 10;
    var events: [MAX_EVENTS]std.os.linux.epoll_event = undefined;

    while (state.running.load(.acquire)) {
        const num_events = std.posix.epoll_wait(state.epoll_fd, &events, 1000);

        for (events[0..@intCast(num_events)]) |ev| {
            if (ev.data.fd == state.socket_server.socket_fd) {
                // Accept connection
                const client_fd = ipc.acceptConnection(&state.socket_server) catch continue;
                std.log.info("Client connected", .{});

                // Handle request
                handleSocketMessage(client_fd, &state) catch |err| {
                    std.log.warn("Failed to handle message: {}", .{err});
                };

                // Close client
                std.posix.close(client_fd);
            }
        }
    }

    // Wait for threads
    if (state.master_poll_thread) |thread| thread.join();
    if (state.device_query_thread) |thread| thread.join();

    std.log.info("Service stopped", .{});
}

fn masterPollingThread(state: *ServiceState) void {
    while (state.running.load(.acquire)) {
        if (state.led_device) |*device| {
            _ = led.device.queryMasterDevice(device, device.active_channel) catch {};
        }
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

fn deviceQueryThread(state: *ServiceState) void {
    while (state.running.load(.acquire)) {
        if (state.led_device) |*device| {
            // Query devices multiple times
            var all_devices = std.StringHashMap(led.RfDeviceInfo).init(state.allocator);
            defer all_devices.deinit();

            var attempt: usize = 0;
            while (attempt < 10) : (attempt += 1) {
                const devices = led.queryDevices(device, state.allocator) catch continue;
                defer state.allocator.free(devices);

                for (devices) |dev| {
                    if (dev.rx_type != 255) {
                        all_devices.put(dev.mac_str, dev) catch {};
                    }
                }

                if (all_devices.count() > 0) break;
                std.Thread.sleep(100 * std.time.ns_per_ms);
            }

            // Update cache
            if (all_devices.count() > 0) {
                state.devices_mutex.lock();
                defer state.devices_mutex.unlock();

                state.devices_cache.clearRetainingCapacity();
                var it = all_devices.valueIterator();
                while (it.next()) |dev| {
                    state.devices_cache.append(state.allocator, dev.*) catch {};
                }

                // Save cache
                device_cache.saveDeviceCache(state.devices_cache.items, state.allocator) catch {};

                std.log.info("Found {} devices", .{state.devices_cache.items.len});
            }
        }

        std.Thread.sleep(@as(u64, state.poll_interval_seconds) * std.time.ns_per_s);
    }
}

fn handleSocketMessage(client_fd: std.posix.socket_t, state: *ServiceState) !void {
    const msg = try ipc.receiveMessage(client_fd, state.allocator);
    defer if (msg.payload.len > 0) state.allocator.free(msg.payload);

    switch (msg.type) {
        .get_devices => {
            const cached = try device_cache.loadDeviceCache(state.allocator);
            defer device_cache.freeCacheEntries(cached, state.allocator);

            const json_string = try std.json.Stringify.valueAlloc(state.allocator, cached, .{});
            defer state.allocator.free(json_string);

            const response = ipc_commands.IpcMessage{
                .type = .devices_response,
                .payload = json_string,
            };
            try ipc.sendMessage(client_fd, response);
        },
        .get_status => {
            state.devices_mutex.lock();
            const device_count = state.devices_cache.items.len;
            state.devices_mutex.unlock();

            const status = ipc_commands.StatusInfo{
                .running = state.running.load(.acquire),
                .master_mac = if (state.led_device) |dev| dev.master_mac else [_]u8{0} ** 6,
                .active_channel = if (state.led_device) |dev| dev.active_channel else 0,
                .fw_version = if (state.led_device) |dev| dev.fw_version else 0,
                .device_count = @intCast(device_count),
            };

            const json_string = try std.json.Stringify.valueAlloc(state.allocator, status, .{});
            defer state.allocator.free(json_string);

            const response = ipc_commands.IpcMessage{
                .type = .status_response,
                .payload = json_string,
            };
            try ipc.sendMessage(client_fd, response);
        },
        .identify_device => {
            if (state.led_device) |*device| {
                // Parse identify request
                const parsed = try std.json.parseFromSlice(ipc_commands.IdentifyRequest, state.allocator, msg.payload, .{});
                defer parsed.deinit();

                // Convert to DeviceIdentifyInfo array
                var identify_infos = try state.allocator.alloc(led.DeviceIdentifyInfo, parsed.value.devices.len);
                defer state.allocator.free(identify_infos);

                for (parsed.value.devices, 0..) |dev, i| {
                    var device_mac: [6]u8 = undefined;

                    // Remove colons from MAC address string
                    var mac_no_colons = try state.allocator.alloc(u8, 12);
                    defer state.allocator.free(mac_no_colons);
                    var idx: usize = 0;
                    for (dev.mac_str) |c| {
                        if (c != ':') {
                            mac_no_colons[idx] = c;
                            idx += 1;
                        }
                    }

                    _ = try std.fmt.hexToBytes(&device_mac, mac_no_colons[0..12]);

                    identify_infos[i] = led.DeviceIdentifyInfo{
                        .device_mac = device_mac,
                        .rx_type = dev.rx_type,
                        .channel = dev.channel,
                    };
                }

                // Send identify commands
                led.identifyDevicesBatch(device, identify_infos, state.allocator) catch |err| {
                    std.log.err("Failed to identify devices: {}", .{err});
                    const response = ipc_commands.IpcMessage{
                        .type = .err,
                        .payload = "Failed to identify devices",
                    };
                    try ipc.sendMessage(client_fd, response);
                    return;
                };

                const response = ipc_commands.IpcMessage{
                    .type = .identify_success,
                    .payload = "",
                };
                try ipc.sendMessage(client_fd, response);
            } else {
                const response = ipc_commands.IpcMessage{
                    .type = .err,
                    .payload = "LED device not available",
                };
                try ipc.sendMessage(client_fd, response);
            }
        },
        .set_effect => {
            const parsed = try std.json.parseFromSlice(ipc_commands.EffectRequest, state.allocator, msg.payload, .{});
            defer parsed.deinit();

            const effect_req = parsed.value;

            // Apply effect to each selected device
            for (effect_req.devices) |device_entry| {
                // Find full device info from cache
                state.devices_mutex.lock();
                var device_info: ?led.RfDeviceInfo = null;
                for (state.devices_cache.items) |cached_device| {
                    if (std.mem.eql(u8, cached_device.mac_str, device_entry.mac_str)) {
                        device_info = cached_device;
                        break;
                    }
                }
                state.devices_mutex.unlock();

                if (device_info == null) {
                    std.log.warn("Device not found in cache: {s}", .{device_entry.mac_str});
                    continue;
                }

                const device = device_info.?;

                // Determine LED count
                var leds_per_fan: usize = 40;
                for (device.fan_types) |fan_type| {
                    if (fan_type >= 28) {
                        leds_per_fan = 26;
                        break;
                    }
                }
                const num_leds = leds_per_fan * device.fan_num;

                // Generate effect data
                const led_effects = @import("led_effects.zig");
                const rgb_data = if (std.mem.eql(u8, effect_req.effect_name, "Static"))
                    try led_effects.generateStaticColor(num_leds, effect_req.color1[0], effect_req.color1[1], effect_req.color1[2], state.allocator)
                else if (std.mem.eql(u8, effect_req.effect_name, "Rainbow"))
                    try led_effects.generateRainbow(num_leds, effect_req.brightness, state.allocator)
                else if (std.mem.eql(u8, effect_req.effect_name, "Alternating"))
                    try led_effects.generateAlternating(num_leds, effect_req.color1, effect_req.color2, 0, state.allocator)
                else if (std.mem.eql(u8, effect_req.effect_name, "Breathing"))
                    try led_effects.generateBreathing(num_leds, 680, effect_req.brightness, state.allocator)
                else
                    try led_effects.generateStaticColor(num_leds, effect_req.color1[0], effect_req.color1[1], effect_req.color1[2], state.allocator);

                defer state.allocator.free(rgb_data);

                // Apply effect
                if (state.led_device) |*led_dev| {
                    const led_operations = @import("led_operations.zig");
                    const total_frames: u16 = if (std.mem.eql(u8, effect_req.effect_name, "Static") or std.mem.eql(u8, effect_req.effect_name, "Alternating")) 1 else 680;
                    led_operations.setLedEffect(led_dev, device, rgb_data, total_frames, state.allocator) catch |err| {
                        std.log.err("Failed to apply effect to device {s}: {}", .{ device.mac_str, err });
                        continue;
                    };

                    std.log.info("Applied effect '{s}' to device {s}", .{ effect_req.effect_name, device.mac_str });
                } else {
                    std.log.warn("Cannot apply effect - LED device not available", .{});
                }
            }

            const response = ipc_commands.IpcMessage{
                .type = .effect_applied,
                .payload = "",
            };
            try ipc.sendMessage(client_fd, response);
        },
        .ping => {
            const response = ipc_commands.IpcMessage{
                .type = .pong,
                .payload = "",
            };
            try ipc.sendMessage(client_fd, response);
        },
        else => {
            std.log.warn("Unknown message type", .{});
        },
    }
}
