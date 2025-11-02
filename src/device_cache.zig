const std = @import("std");
const config = @import("config.zig");
const led = @import("led.zig");

pub const DeviceCacheError = error{
    SaveFailed,
    LoadFailed,
    MarshalFailed,
    UnmarshalFailed,
    PathError,
};

// JSON-serializable device info
pub const DeviceCacheEntry = struct {
    mac_str: []const u8,
    dev_type_name: []const u8,
    channel: u8,
    bound_to_us: bool,
    fan_num: u8,
    rx_type: u8,
    timestamp: u32,
    fan_types: [4]u8,
    has_lcd: bool,
};

pub const DeviceCache = struct {
    devices: []DeviceCacheEntry,
    updated_at: i64, // Unix timestamp
};

fn getDeviceCachePath(allocator: std.mem.Allocator) ![]const u8 {
    const config_dir = try config.getConfigDir(allocator);
    defer allocator.free(config_dir);

    const cache_path = try std.fs.path.join(allocator, &.{ config_dir, "devices.json" });
    return cache_path;
}

fn deviceToCacheEntry(device: led.RfDeviceInfo, allocator: std.mem.Allocator) !DeviceCacheEntry {
    // Detect if device has LCD by checking fan_types array
    // Types 24 and 25 are SL 120 fans with LCD screens
    var has_lcd = false;
    var i: usize = 0;
    while (i < device.fan_num) : (i += 1) {
        const fan_type = device.fan_types[i];
        if (fan_type == 24 or fan_type == 25) {
            has_lcd = true;
            break;
        }
    }

    return DeviceCacheEntry{
        .mac_str = try allocator.dupe(u8, device.mac_str),
        .dev_type_name = try allocator.dupe(u8, device.dev_type_name),
        .channel = device.channel,
        .bound_to_us = device.bound_to_us,
        .fan_num = device.fan_num,
        .rx_type = device.rx_type,
        .timestamp = device.timestamp,
        .fan_types = device.fan_types,
        .has_lcd = has_lcd,
    };
}

pub fn saveDeviceCache(devices: []const led.RfDeviceInfo, allocator: std.mem.Allocator) !void {
    const cache_path = try getDeviceCachePath(allocator);
    defer allocator.free(cache_path);

    // Convert devices to cache entries
    var cache_entries: std.ArrayList(DeviceCacheEntry) = .{};
    defer {
        for (cache_entries.items) |entry| {
            allocator.free(entry.mac_str);
            allocator.free(entry.dev_type_name);
        }
        cache_entries.deinit(allocator);
    }

    for (devices) |device| {
        const entry = try deviceToCacheEntry(device, allocator);
        try cache_entries.append(allocator, entry);
    }

    // Create cache structure
    const cache = DeviceCache{
        .devices = cache_entries.items,
        .updated_at = std.time.timestamp(),
    };

    // Marshal to JSON
    var json_string: std.ArrayList(u8) = .{};
    defer json_string.deinit(allocator);

    const writer = json_string.writer(allocator);
    try writer.print("{any}", .{std.json.fmt(cache, .{ .whitespace = .indent_2 })});

    // Write to file
    const file = try std.fs.createFileAbsolute(cache_path, .{});
    defer file.close();

    try file.writeAll(json_string.items);
}

pub fn loadDeviceCache(allocator: std.mem.Allocator) ![]DeviceCacheEntry {
    const cache_path = try getDeviceCachePath(allocator);
    defer allocator.free(cache_path);

    // Check if file exists
    const file = std.fs.openFileAbsolute(cache_path, .{}) catch {
        // Return empty array if cache doesn't exist
        return &[_]DeviceCacheEntry{};
    };
    defer file.close();

    // Read file
    const file_size = try file.getEndPos();
    const json_data = try allocator.alloc(u8, file_size);
    defer allocator.free(json_data);

    _ = try file.readAll(json_data);

    // Parse JSON
    const parsed = try std.json.parseFromSlice(DeviceCache, allocator, json_data, .{});
    defer parsed.deinit();

    // Duplicate the devices array so it outlives the parsed data
    const devices = try allocator.alloc(DeviceCacheEntry, parsed.value.devices.len);
    for (parsed.value.devices, 0..) |device, i| {
        devices[i] = DeviceCacheEntry{
            .mac_str = try allocator.dupe(u8, device.mac_str),
            .dev_type_name = try allocator.dupe(u8, device.dev_type_name),
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

pub fn freeCacheEntries(entries: []DeviceCacheEntry, allocator: std.mem.Allocator) void {
    for (entries) |entry| {
        allocator.free(entry.mac_str);
        allocator.free(entry.dev_type_name);
    }
    allocator.free(entries);
}
