const std = @import("std");
const usb = @import("usb.zig");
const types = @import("led_types.zig");

pub fn initLedDevice(allocator: std.mem.Allocator) !types.LedDevice {
    var dev = types.LedDevice{
        .ctx = null,
        .rf_sender = null,
        .rf_receiver = null,
        .ep_out_tx = 0,
        .ep_in_tx = 0,
        .ep_out_rx = 0,
        .ep_in_rx = 0,
        .master_mac = [_]u8{0} ** 6,
        .active_channel = 0,
        .time_tmos = 0,
        .sys_clock = 0,
        .fw_version = 0,
        .cmd_seq = 1,
    };

    // Initialize libusb
    var ret = usb.init(&dev.ctx);
    if (ret != usb.LIBUSB_SUCCESS) {
        return types.LedError.UsbInitFailed;
    }
    errdefer usb.exit(dev.ctx);

    // Get device list
    var device_list: [*c]?*usb.c.struct_libusb_device = undefined;
    const device_count = usb.getDeviceList(dev.ctx, &device_list);
    if (device_count < 0) {
        return types.LedError.UsbInitFailed;
    }
    defer usb.freeDeviceList(device_list, 1);

    // Find and open both TX and RX devices
    var found_tx = false;
    var found_rx = false;

    var i: usize = 0;
    while (i < device_count) : (i += 1) {
        const device = device_list[i];

        var desc: usb.DeviceDescriptor = undefined;
        ret = usb.getDeviceDescriptor(device, &desc);
        if (ret != usb.LIBUSB_SUCCESS) {
            continue;
        }

        if (desc.idVendor != types.VENDOR_ID) {
            continue;
        }

        // Check for TX device
        if (desc.idProduct == types.PRODUCT_ID_TX and !found_tx) {
            ret = usb.open(device, &dev.rf_sender);
            if (ret != usb.LIBUSB_SUCCESS) {
                continue;
            }

            // Detach kernel driver if active
            if (usb.kernelDriverActive(dev.rf_sender, 0) == 1) {
                _ = usb.detachKernelDriver(dev.rf_sender, 0);
            }

            // Set configuration and claim interface
            _ = usb.setConfiguration(dev.rf_sender, 1);
            ret = usb.claimInterface(dev.rf_sender, 0);
            if (ret != usb.LIBUSB_SUCCESS) {
                usb.close(dev.rf_sender);
                dev.rf_sender = null;
                continue;
            }

            dev.ep_out_tx = 0x01;
            dev.ep_in_tx = 0x81;
            found_tx = true;
        }

        // Check for RX device
        if (desc.idProduct == types.PRODUCT_ID_RX and !found_rx) {
            ret = usb.open(device, &dev.rf_receiver);
            if (ret != usb.LIBUSB_SUCCESS) {
                continue;
            }

            // Detach kernel driver if active
            if (usb.kernelDriverActive(dev.rf_receiver, 0) == 1) {
                _ = usb.detachKernelDriver(dev.rf_receiver, 0);
            }

            // Set configuration and claim interface
            _ = usb.setConfiguration(dev.rf_receiver, 1);
            ret = usb.claimInterface(dev.rf_receiver, 0);
            if (ret != usb.LIBUSB_SUCCESS) {
                usb.close(dev.rf_receiver);
                dev.rf_receiver = null;
                continue;
            }

            dev.ep_out_rx = 0x01;
            dev.ep_in_rx = 0x81;
            found_rx = true;
        }

        if (found_tx and found_rx) {
            break;
        }
    }

    if (!found_tx or !found_rx) {
        cleanupLedDevice(&dev);
        return types.LedError.DeviceNotFound;
    }

    // Try to query master device on different channels
    var channels_to_try = try allocator.alloc(u8, 1 + types.VALID_CHANNELS.len);
    defer allocator.free(channels_to_try);
    channels_to_try[0] = types.DEFAULT_CHANNEL;
    @memcpy(channels_to_try[1..], &types.VALID_CHANNELS);

    for (channels_to_try) |channel| {
        if (try queryMasterDevice(&dev, channel)) {
            dev.active_channel = channel;
            dev.cmd_seq = 1;
            std.log.info("LED Device initialized", .{});
            std.log.info("  Master MAC: {x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{
                dev.master_mac[0],
                dev.master_mac[1],
                dev.master_mac[2],
                dev.master_mac[3],
                dev.master_mac[4],
                dev.master_mac[5],
            });
            std.log.info("  Channel: {d}", .{dev.active_channel});
            std.log.info("  Firmware Version: 0x{x:0>4}", .{dev.fw_version});
            return dev;
        }
    }

    cleanupLedDevice(&dev);
    return types.LedError.QueryFailed;
}

pub fn cleanupLedDevice(dev: *types.LedDevice) void {
    if (dev.rf_sender) |sender| {
        _ = usb.releaseInterface(sender, 0);
        usb.close(sender);
        dev.rf_sender = null;
    }
    if (dev.rf_receiver) |receiver| {
        _ = usb.releaseInterface(receiver, 0);
        usb.close(receiver);
        dev.rf_receiver = null;
    }
    if (dev.ctx) |ctx| {
        usb.exit(ctx);
        dev.ctx = null;
    }
}

pub fn queryMasterDevice(dev: *types.LedDevice, channel: u8) !bool {
    var query: [types.USB_PACKET_SIZE]u8 = [_]u8{0} ** types.USB_PACKET_SIZE;
    query[0] = types.CMD_QUERY_MASTER;
    query[1] = channel;

    var bytes_transferred: c_int = 0;
    var ret = usb.bulkTransfer(
        dev.rf_sender,
        dev.ep_out_tx,
        &query,
        types.USB_PACKET_SIZE,
        &bytes_transferred,
        500,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return false;
    }

    var response: [types.USB_PACKET_SIZE]u8 = [_]u8{0} ** types.USB_PACKET_SIZE;
    ret = usb.bulkTransfer(
        dev.rf_sender,
        dev.ep_in_tx,
        &response,
        types.USB_PACKET_SIZE,
        &bytes_transferred,
        500,
    );

    if (ret != usb.LIBUSB_SUCCESS or response[0] != types.CMD_QUERY_MASTER) {
        return false;
    }

    // Parse and store values
    @memcpy(&dev.master_mac, response[1..7]);

    // Bytes 7-10: 32-bit timestamp value
    dev.time_tmos = (@as(u32, response[7]) << 24) |
        (@as(u32, response[8]) << 16) |
        (@as(u32, response[9]) << 8) |
        @as(u32, response[10]);
    dev.sys_clock = @as(u32, @intFromFloat(@as(f32, @floatFromInt(dev.time_tmos)) * 0.625));

    // Bytes 11-12: Firmware version
    dev.fw_version = (@as(u16, response[11]) << 8) | @as(u16, response[12]);

    return true;
}

pub fn queryDevices(dev: *types.LedDevice, allocator: std.mem.Allocator) ![]types.RfDeviceInfo {
    var query: [types.USB_PACKET_SIZE]u8 = [_]u8{0} ** types.USB_PACKET_SIZE;
    query[0] = types.CMD_QUERY_DEVICES;
    query[1] = 1; // page

    var bytes_transferred: c_int = 0;
    var ret = usb.bulkTransfer(
        dev.rf_receiver,
        dev.ep_out_rx,
        &query,
        types.USB_PACKET_SIZE,
        &bytes_transferred,
        15000,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return types.LedError.UsbTransferFailed;
    }

    // Read response
    const response = try allocator.alloc(u8, types.USB_PACKET_SIZE * 4);
    defer allocator.free(response);

    ret = usb.bulkTransfer(
        dev.rf_receiver,
        dev.ep_in_rx,
        @ptrCast(response.ptr),
        @intCast(response.len),
        &bytes_transferred,
        15000,
    );

    if (ret != usb.LIBUSB_SUCCESS or response.len < 4 or response[0] != types.CMD_QUERY_DEVICES) {
        return types.LedError.QueryFailed;
    }

    const num_devices = response[1];
    if (num_devices == 0) {
        return &[_]types.RfDeviceInfo{};
    }

    var devices_list: std.ArrayList(types.RfDeviceInfo) = .{};
    errdefer devices_list.deinit(allocator);

    var offset: usize = 4;
    var i: usize = 0;
    while (i < num_devices) : (i += 1) {
        if (offset + types.DEVICE_ENTRY_SIZE > response.len) {
            break;
        }

        // Check validation byte
        if (response[offset + types.DEV_TYPE_VALIDATION_OFFSET] != 28) {
            offset += types.DEVICE_ENTRY_SIZE;
            continue;
        }

        var device_info: types.RfDeviceInfo = undefined;

        // Parse MAC addresses
        @memcpy(&device_info.mac, response[offset + types.DEV_MAC_OFFSET .. offset + types.DEV_MAC_OFFSET + 6]);
        @memcpy(&device_info.master_mac, response[offset + types.DEV_MASTER_MAC_OFFSET .. offset + types.DEV_MASTER_MAC_OFFSET + 6]);

        // Format MAC strings
        device_info.mac_str = try std.fmt.allocPrint(allocator, "{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{
            device_info.mac[0], device_info.mac[1], device_info.mac[2],
            device_info.mac[3], device_info.mac[4], device_info.mac[5],
        });
        device_info.master_mac_str = try std.fmt.allocPrint(allocator, "{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}", .{
            device_info.master_mac[0], device_info.master_mac[1], device_info.master_mac[2],
            device_info.master_mac[3], device_info.master_mac[4], device_info.master_mac[5],
        });

        // Parse timestamp
        const ts_offset = offset + types.DEV_TIMESTAMP_OFFSET;
        device_info.timestamp = (@as(u32, response[ts_offset]) << 24) |
            (@as(u32, response[ts_offset + 1]) << 16) |
            (@as(u32, response[ts_offset + 2]) << 8) |
            @as(u32, response[ts_offset + 3]);

        // Check if bound to us
        device_info.bound_to_us = std.mem.eql(u8, &device_info.master_mac, &dev.master_mac);
        device_info.is_unbound = std.mem.allEqual(u8, &device_info.master_mac, 0);

        device_info.channel = response[offset + types.DEV_CHANNEL_OFFSET];
        device_info.rx_type = response[offset + types.DEV_RX_TYPE_OFFSET];
        device_info.dev_type = response[offset + types.DEV_TYPE_OFFSET];
        device_info.fan_num = response[offset + types.DEV_FAN_NUM_OFFSET];
        @memcpy(&device_info.fan_types, response[offset + types.DEV_FAN_TYPES_OFFSET .. offset + types.DEV_FAN_TYPES_OFFSET + 4]);

        // Use first fan type as device type name
        const actual_dev_type = if (device_info.fan_num > 0) device_info.fan_types[0] else device_info.dev_type;
        device_info.dev_type_name = try types.getDeviceTypeName(allocator, actual_dev_type);

        device_info.cmd_seq = response[offset + types.DEV_CMD_SEQ_OFFSET];

        try devices_list.append(allocator, device_info);
        offset += types.DEVICE_ENTRY_SIZE;
    }

    return devices_list.toOwnedSlice(allocator);
}
