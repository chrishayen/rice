const std = @import("std");
const config = @import("config.zig");
const ipc = @import("ipc.zig");
const ipc_commands = @import("ipc_commands.zig");
const device_cache = @import("device_cache.zig");

pub const IpcClient = struct {
    socket_path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !IpcClient {
        const socket_path = try config.getSocketPath(allocator);
        return IpcClient{
            .socket_path = socket_path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IpcClient) void {
        self.allocator.free(self.socket_path);
    }

    pub fn ping(self: *IpcClient) !bool {
        var client = try ipc.connectToServer(self.socket_path, self.allocator);
        defer ipc.closeClient(&client);

        const ping_msg = ipc_commands.IpcMessage{
            .type = .ping,
            .payload = "",
        };
        try ipc.sendMessage(client.socket_fd, ping_msg);

        const response = try ipc.receiveMessage(client.socket_fd, self.allocator);
        defer if (response.payload.len > 0) self.allocator.free(response.payload);

        return response.type == .pong;
    }

    pub fn getDevices(self: *IpcClient) ![]device_cache.DeviceCacheEntry {
        var client = try ipc.connectToServer(self.socket_path, self.allocator);
        defer ipc.closeClient(&client);

        const get_devices_msg = ipc_commands.IpcMessage{
            .type = .get_devices,
            .payload = "",
        };
        try ipc.sendMessage(client.socket_fd, get_devices_msg);

        const response = try ipc.receiveMessage(client.socket_fd, self.allocator);
        defer if (response.payload.len > 0) self.allocator.free(response.payload);

        if (response.type != .devices_response) {
            return error.UnexpectedResponse;
        }

        const parsed = try std.json.parseFromSlice([]device_cache.DeviceCacheEntry, self.allocator, response.payload, .{});
        defer parsed.deinit();

        // Duplicate the array so it outlives the parsed data
        const devices = try self.allocator.alloc(device_cache.DeviceCacheEntry, parsed.value.len);
        for (parsed.value, 0..) |device, i| {
            devices[i] = device_cache.DeviceCacheEntry{
                .mac_str = try self.allocator.dupe(u8, device.mac_str),
                .dev_type_name = try self.allocator.dupe(u8, device.dev_type_name),
                .channel = device.channel,
                .bound_to_us = device.bound_to_us,
                .fan_num = device.fan_num,
                .rx_type = device.rx_type,
                .timestamp = device.timestamp,
                .fan_types = device.fan_types,
                .has_lcd = device.has_lcd,
            };
        }

        return devices;
    }

    pub fn getStatus(self: *IpcClient) !ipc_commands.StatusInfo {
        var client = try ipc.connectToServer(self.socket_path, self.allocator);
        defer ipc.closeClient(&client);

        const get_status_msg = ipc_commands.IpcMessage{
            .type = .get_status,
            .payload = "",
        };
        try ipc.sendMessage(client.socket_fd, get_status_msg);

        const response = try ipc.receiveMessage(client.socket_fd, self.allocator);
        defer if (response.payload.len > 0) self.allocator.free(response.payload);

        if (response.type != .status_response) {
            return error.UnexpectedResponse;
        }

        const parsed = try std.json.parseFromSlice(ipc_commands.StatusInfo, self.allocator, response.payload, .{});
        defer parsed.deinit();

        return parsed.value;
    }

    pub fn identifyDevices(self: *IpcClient, devices: []const device_cache.DeviceCacheEntry) !void {
        if (devices.len == 0) return;

        var client = try ipc.connectToServer(self.socket_path, self.allocator);
        defer ipc.closeClient(&client);

        // Build identify request
        var identify_devices = try self.allocator.alloc(ipc_commands.IdentifyDeviceInfo, devices.len);
        defer self.allocator.free(identify_devices);

        for (devices, 0..) |device, i| {
            identify_devices[i] = ipc_commands.IdentifyDeviceInfo{
                .mac_str = device.mac_str,
                .rx_type = device.rx_type,
                .channel = device.channel,
            };
        }

        const request = ipc_commands.IdentifyRequest{
            .devices = identify_devices,
        };

        const json_string = try std.json.Stringify.valueAlloc(self.allocator, request, .{});
        defer self.allocator.free(json_string);

        const identify_msg = ipc_commands.IpcMessage{
            .type = .identify_device,
            .payload = json_string,
        };
        try ipc.sendMessage(client.socket_fd, identify_msg);

        const response = try ipc.receiveMessage(client.socket_fd, self.allocator);
        defer if (response.payload.len > 0) self.allocator.free(response.payload);

        if (response.type == .err) {
            return error.IdentifyFailed;
        }
    }

    pub fn setEffect(self: *IpcClient, devices: []const device_cache.DeviceCacheEntry, effect_name: []const u8, color1: [3]u8, color2: [3]u8, brightness: u8) !void {
        if (devices.len == 0) return;

        var client = try ipc.connectToServer(self.socket_path, self.allocator);
        defer ipc.closeClient(&client);

        // Build simplified device list for effect request
        var effect_devices = try self.allocator.alloc(ipc_commands.EffectDeviceInfo, devices.len);
        defer self.allocator.free(effect_devices);

        for (devices, 0..) |device, i| {
            effect_devices[i] = ipc_commands.EffectDeviceInfo{
                .mac_str = device.mac_str,
            };
        }

        // Build effect request
        const request = ipc_commands.EffectRequest{
            .devices = effect_devices,
            .effect_name = effect_name,
            .color1 = color1,
            .color2 = color2,
            .brightness = brightness,
        };

        const json_string = try std.json.Stringify.valueAlloc(self.allocator, request, .{});
        defer self.allocator.free(json_string);

        const set_effect_msg = ipc_commands.IpcMessage{
            .type = .set_effect,
            .payload = json_string,
        };
        try ipc.sendMessage(client.socket_fd, set_effect_msg);

        const response = try ipc.receiveMessage(client.socket_fd, self.allocator);
        defer if (response.payload.len > 0) self.allocator.free(response.payload);

        if (response.type == .err) {
            return error.SetEffectFailed;
        }
    }

    pub fn freeDevices(self: *IpcClient, devices: []device_cache.DeviceCacheEntry) void {
        for (devices) |device| {
            self.allocator.free(device.mac_str);
            self.allocator.free(device.dev_type_name);
        }
        self.allocator.free(devices);
    }
};
