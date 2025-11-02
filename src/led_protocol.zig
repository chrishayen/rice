const std = @import("std");
const usb = @import("usb.zig");
const types = @import("led_types.zig");

pub fn splitRfToUsb(rf_data: []const u8, channel: u8, rx_type: u8, allocator: std.mem.Allocator) ![][types.USB_PACKET_SIZE]u8 {
    if (rf_data.len != types.RF_PACKET_SIZE) {
        return types.LedError.SendFailed;
    }

    var packets_list: std.ArrayList([types.USB_PACKET_SIZE]u8) = .{};
    errdefer packets_list.deinit(allocator);

    var seq: u8 = 0;
    var i: usize = 0;
    while (i < types.RF_PACKET_SIZE) : (i += 60) {
        const chunk_end = @min(i + 60, types.RF_PACKET_SIZE);
        const chunk = rf_data[i..chunk_end];

        var packet: [types.USB_PACKET_SIZE]u8 = [_]u8{0} ** types.USB_PACKET_SIZE;
        packet[0] = 0x10;
        packet[1] = seq;
        packet[2] = channel;
        packet[3] = rx_type;
        @memcpy(packet[4 .. 4 + chunk.len], chunk);

        try packets_list.append(allocator, packet);
        seq += 1;
    }

    return packets_list.toOwnedSlice(allocator);
}

pub fn sendRfPacket(dev: *types.LedDevice, rf_data: []const u8, channel: u8, rx_type: u8, delay_ms: f32, allocator: std.mem.Allocator) !void {
    const packets = try splitRfToUsb(rf_data, channel, rx_type, allocator);
    defer allocator.free(packets);

    for (packets) |*packet| {
        var bytes_transferred: c_int = 0;
        const ret = usb.bulkTransfer(
            dev.rf_sender,
            dev.ep_out_tx,
            packet,
            types.USB_PACKET_SIZE,
            &bytes_transferred,
            5000,
        );

        if (ret != usb.LIBUSB_SUCCESS) {
            return types.LedError.UsbTransferFailed;
        }

        if (delay_ms > 0) {
            std.Thread.sleep(@intFromFloat(delay_ms * 1_000_000));
        }
    }
}

pub fn buildBindPacket(
    device_mac: [6]u8,
    master_mac: [6]u8,
    rx_type: u8,
    channel: u8,
    sequence: u8,
    pwm: [4]u8,
) [types.RF_PACKET_SIZE]u8 {
    var packet: [types.RF_PACKET_SIZE]u8 = [_]u8{0} ** types.RF_PACKET_SIZE;
    packet[0] = types.CMD_RF_SEND;
    packet[1] = types.SUBCMD_BIND;
    @memcpy(packet[2..8], &device_mac);
    @memcpy(packet[8..14], &master_mac);
    packet[14] = rx_type;
    packet[15] = channel;
    packet[16] = sequence;
    @memcpy(packet[17..21], &pwm);
    return packet;
}

pub fn buildIdentifyPacket(
    device_mac: [6]u8,
    master_mac: [6]u8,
    rx_type: u8,
    channel: u8,
    cmd_seq: u8,
) [types.RF_PACKET_SIZE]u8 {
    var packet: [types.RF_PACKET_SIZE]u8 = [_]u8{0} ** types.RF_PACKET_SIZE;
    packet[0] = types.CMD_RF_SEND;
    packet[1] = types.SUBCMD_IDENTIFY;
    @memcpy(packet[2..8], &device_mac);
    @memcpy(packet[8..14], &master_mac);
    packet[14] = rx_type;
    packet[15] = channel;
    packet[16] = 0x00; // Device index
    packet[17] = cmd_seq;
    return packet;
}

pub fn buildSaveConfigPacket(master_mac: [6]u8) [types.RF_PACKET_SIZE]u8 {
    var packet: [types.RF_PACKET_SIZE]u8 = [_]u8{0} ** types.RF_PACKET_SIZE;
    packet[0] = types.CMD_RF_SEND;
    packet[1] = types.SUBCMD_SAVE_CONFIG;
    // Broadcast MAC
    @memset(packet[2..8], 0xFF);
    @memcpy(packet[8..14], &master_mac);
    packet[14] = 0xFF; // rx_type broadcast
    packet[15] = 0x00;
    packet[16] = 0x00;
    return packet;
}

pub fn buildLedEffectPackets(
    compressed_data: []const u8,
    led_count: u8,
    device_mac: [6]u8,
    master_mac: [6]u8,
    total_frame: u16,
    effect_index: ?[4]u8,
    allocator: std.mem.Allocator,
) ![][types.RF_PACKET_SIZE]u8 {
    // Generate timestamp for effect_index if not provided
    const effect_idx = effect_index orelse blk: {
        const timestamp_i64 = std.time.milliTimestamp();
        const timestamp: u32 = @truncate(@as(u64, @bitCast(timestamp_i64)));
        break :blk [4]u8{
            @intCast((timestamp >> 24) & 0xFF),
            @intCast((timestamp >> 16) & 0xFF),
            @intCast((timestamp >> 8) & 0xFF),
            @intCast(timestamp & 0xFF),
        };
    };

    // Calculate number of data packets needed
    const lzo_rgb_rf_valid_len: usize = 220;
    const total_pk_num = (compressed_data.len + lzo_rgb_rf_valid_len - 1) / lzo_rgb_rf_valid_len;

    var packets_list: std.ArrayList([types.RF_PACKET_SIZE]u8) = .{};
    errdefer packets_list.deinit(allocator);

    // Metadata packet (packet_idx=0)
    var metadata: [types.RF_PACKET_SIZE]u8 = [_]u8{0} ** types.RF_PACKET_SIZE;
    metadata[0] = types.CMD_RF_SEND;
    metadata[1] = types.SUBCMD_LED_EFFECT;
    @memcpy(metadata[2..8], &device_mac);
    @memcpy(metadata[8..14], &master_mac);
    @memcpy(metadata[14..18], &effect_idx);
    metadata[18] = 0; // packet_idx
    metadata[19] = @intCast(total_pk_num + 1); // total packets including metadata

    // Compressed data length (big-endian)
    const compressed_len: u32 = @intCast(compressed_data.len);
    metadata[20] = @intCast((compressed_len >> 24) & 0xFF);
    metadata[21] = @intCast((compressed_len >> 16) & 0xFF);
    metadata[22] = @intCast((compressed_len >> 8) & 0xFF);
    metadata[23] = @intCast(compressed_len & 0xFF);

    // Total frames (big-endian)
    metadata[25] = @intCast((total_frame >> 8) & 0xFF);
    metadata[26] = @intCast(total_frame & 0xFF);
    metadata[27] = led_count;

    // Set interval
    const interval: u16 = if (total_frame > 1) 100 else 20;
    metadata[32] = @intCast((interval >> 8) & 0xFF);
    metadata[33] = @intCast(interval & 0xFF);
    metadata[34] = 0;
    metadata[35] = @intCast((interval >> 8) & 0xFF);
    metadata[36] = @intCast(interval & 0xFF);
    metadata[37] = 1; // isOuterMatchMax
    metadata[38] = 0; // total_sub_frame high byte
    metadata[39] = 1; // total_sub_frame low byte

    try packets_list.append(allocator, metadata);

    // Data packets
    var offset: usize = 0;
    var packet_idx: usize = 1;
    while (packet_idx <= total_pk_num) : (packet_idx += 1) {
        var data_pkt: [types.RF_PACKET_SIZE]u8 = [_]u8{0} ** types.RF_PACKET_SIZE;
        data_pkt[0] = types.CMD_RF_SEND;
        data_pkt[1] = types.SUBCMD_LED_EFFECT;
        @memcpy(data_pkt[2..8], &device_mac);
        @memcpy(data_pkt[8..14], &master_mac);
        @memcpy(data_pkt[14..18], &effect_idx);
        data_pkt[18] = @intCast(packet_idx);
        data_pkt[19] = @intCast(total_pk_num + 1);

        const chunk_size = @min(lzo_rgb_rf_valid_len, compressed_data.len - offset);
        @memcpy(data_pkt[20 .. 20 + chunk_size], compressed_data[offset .. offset + chunk_size]);
        offset += lzo_rgb_rf_valid_len;

        try packets_list.append(allocator, data_pkt);
    }

    return packets_list.toOwnedSlice(allocator);
}

pub fn getNextCmdSeq(dev: *types.LedDevice) u8 {
    const seq = dev.cmd_seq;
    dev.cmd_seq +%= 1;
    if (dev.cmd_seq == 0) {
        dev.cmd_seq = 1;
    }
    return seq;
}
