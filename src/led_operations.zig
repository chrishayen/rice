const std = @import("std");
const types = @import("led_types.zig");
const protocol = @import("led_protocol.zig");
const tinyuz = @import("tinyuz");

pub fn identifyDevice(dev: *types.LedDevice, device_mac: [6]u8, _: u8, channel: u8, allocator: std.mem.Allocator) !void {
    // Send identify multiple times for reliability
    var attempt: usize = 0;
    while (attempt < 10) : (attempt += 1) {
        var try_rx_type: u8 = 1;
        while (try_rx_type <= 3) : (try_rx_type += 1) {
            const seq = protocol.getNextCmdSeq(dev);
            const rf_packet = protocol.buildIdentifyPacket(device_mac, dev.master_mac, try_rx_type, channel, seq);
            try protocol.sendRfPacket(dev, &rf_packet, channel, try_rx_type, 0.5, allocator);
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

pub fn identifyDevicesBatch(dev: *types.LedDevice, devices: []const types.DeviceIdentifyInfo, allocator: std.mem.Allocator) !void {
    if (devices.len == 0) return;

    // Send identify packets for all devices in round-robin fashion
    var attempt: usize = 0;
    while (attempt < 10) : (attempt += 1) {
        for (devices) |device| {
            var try_rx_type: u8 = 1;
            while (try_rx_type <= 3) : (try_rx_type += 1) {
                const seq = protocol.getNextCmdSeq(dev);
                const rf_packet = protocol.buildIdentifyPacket(device.device_mac, dev.master_mac, try_rx_type, device.channel, seq);
                try protocol.sendRfPacket(dev, &rf_packet, device.channel, try_rx_type, 0.5, allocator);
            }
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

pub fn bindDevice(dev: *types.LedDevice, device_mac: [6]u8, _: u8, channel: u8, allocator: std.mem.Allocator) !void {
    // Send bind command multiple times for reliability
    var attempt: usize = 0;
    while (attempt < 5) : (attempt += 1) {
        var try_rx_type: u8 = 1;
        while (try_rx_type <= 3) : (try_rx_type += 1) {
            const rf_packet = protocol.buildBindPacket(
                device_mac,
                dev.master_mac,
                try_rx_type,
                channel,
                1, // sequence
                [_]u8{ 99, 99, 99, 99 }, // pwm
            );
            try protocol.sendRfPacket(dev, &rf_packet, channel, try_rx_type, 0.5, allocator);
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

pub fn unbindDevice(dev: *types.LedDevice, device_mac: [6]u8, _: u8, channel: u8, allocator: std.mem.Allocator) !void {
    // Send unbind command multiple times for reliability
    var attempt: usize = 0;
    while (attempt < 5) : (attempt += 1) {
        var try_rx_type: u8 = 1;
        while (try_rx_type <= 3) : (try_rx_type += 1) {
            const rf_packet = protocol.buildBindPacket(
                device_mac,
                dev.master_mac,
                try_rx_type,
                channel,
                0, // sequence = 0 for unbind
                [_]u8{ 99, 99, 99, 99 }, // pwm
            );
            try protocol.sendRfPacket(dev, &rf_packet, channel, try_rx_type, 0.5, allocator);
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

pub fn setLedEffect(
    dev: *types.LedDevice,
    device_info: types.RfDeviceInfo,
    rgb_data: []const u8,
    total_frame: u16,
    allocator: std.mem.Allocator,
) !void {
    // Determine LED count based on fan types
    var leds_per_fan: usize = 40; // Default SL
    for (device_info.fan_types) |fan_type| {
        if (fan_type >= 28) {
            leds_per_fan = 26; // TL fans
            break;
        }
    }
    const total_leds: u8 = @intCast(leds_per_fan * device_info.fan_num);

    // Compress RGB data
    const compressed = try allocator.alloc(u8, rgb_data.len * 2);
    defer allocator.free(compressed);

    const compressed_size = try tinyuz.compress(rgb_data, compressed);

    // Build LED effect packets
    const rf_packets = try protocol.buildLedEffectPackets(
        compressed[0..compressed_size],
        total_leds,
        device_info.mac,
        dev.master_mac,
        total_frame,
        null,
        allocator,
    );
    defer allocator.free(rf_packets);

    // Send metadata packet 4 times with 20ms delays
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        try protocol.sendRfPacket(dev, &rf_packets[0], device_info.channel, device_info.rx_type, 0.5, allocator);
        std.Thread.sleep(20 * std.time.ns_per_ms);
    }

    // Send data packets once each
    for (rf_packets[1..]) |*data_packet| {
        try protocol.sendRfPacket(dev, data_packet, device_info.channel, device_info.rx_type, 0.5, allocator);
    }
}

pub fn saveConfig(dev: *types.LedDevice, channel: u8, allocator: std.mem.Allocator) !void {
    const save_packet = protocol.buildSaveConfigPacket(dev.master_mac);

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        try protocol.sendRfPacket(dev, &save_packet, channel, 0xFF, 0.5, allocator);
        if (i < 2) {
            std.Thread.sleep(200 * std.time.ns_per_ms);
        }
    }
}
