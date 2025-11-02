const std = @import("std");
const config = @import("config.zig");
const led = @import("led.zig");
const ipc = @import("ipc.zig");
const ipc_commands = @import("ipc_commands.zig");
const device_cache = @import("device_cache.zig");

const ServiceState = struct {
    led_device: led.LedDevice,
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
            .led_device = undefined,
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

    // Initialize LED device
    state.led_device = led.initLedDevice(allocator) catch |err| {
        std.log.err("Failed to initialize LED device: {}", .{err});
        std.log.err("Make sure USB devices are connected and you have proper permissions", .{});
        return err;
    };
    defer led.cleanupLedDevice(&state.led_device);

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
        _ = led.device.queryMasterDevice(&state.led_device, state.led_device.active_channel) catch {};
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

fn deviceQueryThread(state: *ServiceState) void {
    while (state.running.load(.acquire)) {
        // Query devices multiple times
        var all_devices = std.StringHashMap(led.RfDeviceInfo).init(state.allocator);
        defer all_devices.deinit();

        var attempt: usize = 0;
        while (attempt < 10) : (attempt += 1) {
            const devices = led.queryDevices(&state.led_device, state.allocator) catch continue;
            defer state.allocator.free(devices);

            for (devices) |device| {
                if (device.rx_type != 255) {
                    all_devices.put(device.mac_str, device) catch {};
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
            while (it.next()) |device| {
                state.devices_cache.append(state.allocator, device.*) catch {};
            }

            // Save cache
            device_cache.saveDeviceCache(state.devices_cache.items, state.allocator) catch {};

            std.log.info("Found {} devices", .{state.devices_cache.items.len});
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
                .master_mac = state.led_device.master_mac,
                .active_channel = state.led_device.active_channel,
                .fw_version = state.led_device.fw_version,
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
            // Parse identify request
            const parsed = try std.json.parseFromSlice(ipc_commands.IdentifyRequest, state.allocator, msg.payload, .{});
            defer parsed.deinit();

            // Convert to DeviceIdentifyInfo array
            var identify_infos = try state.allocator.alloc(led.DeviceIdentifyInfo, parsed.value.devices.len);
            defer state.allocator.free(identify_infos);

            for (parsed.value.devices, 0..) |device, i| {
                var device_mac: [6]u8 = undefined;

                // Remove colons from MAC address string
                var mac_no_colons = try state.allocator.alloc(u8, 12);
                defer state.allocator.free(mac_no_colons);
                var idx: usize = 0;
                for (device.mac_str) |c| {
                    if (c != ':') {
                        mac_no_colons[idx] = c;
                        idx += 1;
                    }
                }

                _ = try std.fmt.hexToBytes(&device_mac, mac_no_colons[0..12]);

                identify_infos[i] = led.DeviceIdentifyInfo{
                    .device_mac = device_mac,
                    .rx_type = device.rx_type,
                    .channel = device.channel,
                };
            }

            // Send identify commands
            led.identifyDevicesBatch(&state.led_device, identify_infos, state.allocator) catch |err| {
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
