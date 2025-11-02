const std = @import("std");
const usb = @import("usb.zig");
const des = @import("des");

// USB Device IDs for Lian Li SL-LCD wired controller
pub const VID_WIRED: u16 = 0x1cbe;
pub const PID_WIRED: u16 = 0x0005;

// LCD Display Constants
pub const LCD_WIDTH: u32 = 400;
pub const LCD_HEIGHT: u32 = 400;
pub const FRAME_SIZE: usize = 102400;
pub const HEADER_SIZE: usize = 512;
pub const MAX_JPEG_SIZE: usize = FRAME_SIZE - HEADER_SIZE; // 101888 bytes

// DES encryption key - to be set at runtime from build options
var DES_KEY: [8]u8 = undefined;
var DES_IV: [8]u8 = undefined;
var key_initialized = false;

pub fn initDesKey(key: *const [8]u8) void {
    @memcpy(&DES_KEY, key);
    @memcpy(&DES_IV, key);
    key_initialized = true;
}

// LCD Command Codes
pub const LcdCommand = enum(u8) {
    rotate = 1,
    brightness = 2,
    h264 = 13,
    jpeg = 101,
    png = 102,
    stop_play = 120,
};

// LCD Device Handle
pub const LcdDevice = struct {
    ctx: ?*anyopaque,
    usb_handle: ?*anyopaque,
    ep_out: u8,
    ep_in: u8,
    start_time_ms: u64,
};

// Error types
pub const LcdError = error{
    DeviceNotFound,
    UsbInitFailed,
    UsbOpenFailed,
    UsbClaimInterfaceFailed,
    UsbTransferFailed,
    KernelDriverError,
    EndpointNotFound,
    SendFailed,
    InvalidFrameSize,
    EncryptionFailed,
    InvalidJpegSize,
    KeyNotInitialized,
};

fn getTimestampMs() u32 {
    return @intCast(std.time.milliTimestamp());
}

fn generateLcdHeader(jpeg_size: u32, command: LcdCommand, allocator: std.mem.Allocator) ![ HEADER_SIZE]u8 {
    if (!key_initialized) {
        return LcdError.KeyNotInitialized;
    }

    // Manual header structure (plaintext)
    var plaintext: [504]u8 = [_]u8{0} ** 504;

    // Byte 0: Command
    plaintext[0] = @intFromEnum(command);

    // Bytes 2-3: Magic bytes
    plaintext[2] = 0x1a;
    plaintext[3] = 0x6d;

    // Bytes 4-7: Timestamp (little-endian)
    const ts = getTimestampMs();
    plaintext[4] = @intCast(ts & 0xFF);
    plaintext[5] = @intCast((ts >> 8) & 0xFF);
    plaintext[6] = @intCast((ts >> 16) & 0xFF);
    plaintext[7] = @intCast((ts >> 24) & 0xFF);

    // Bytes 8-11: Image size (big-endian)
    plaintext[8] = @intCast((jpeg_size >> 24) & 0xFF);
    plaintext[9] = @intCast((jpeg_size >> 16) & 0xFF);
    plaintext[10] = @intCast((jpeg_size >> 8) & 0xFF);
    plaintext[11] = @intCast(jpeg_size & 0xFF);

    // Pad to 512 bytes using PKCS7
    const padded = try des.pkcs7Pad(&plaintext, des.DES_BLOCK_SIZE, allocator);
    defer allocator.free(padded);

    // Encrypt with DES-CBC
    const encrypted = try allocator.alloc(u8, padded.len);
    defer allocator.free(encrypted);

    try des.desCbcEncrypt(padded, encrypted, &DES_KEY, &DES_IV);

    // Copy to output header
    var header: [HEADER_SIZE]u8 = [_]u8{0} ** HEADER_SIZE;
    @memcpy(&header, encrypted);

    return header;
}

fn buildLcdFrame(jpeg_data: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (jpeg_data.len > MAX_JPEG_SIZE) {
        return LcdError.InvalidJpegSize;
    }

    // Generate header
    const header = try generateLcdHeader(@intCast(jpeg_data.len), .jpeg, allocator);

    // Allocate frame
    const frame = try allocator.alloc(u8, FRAME_SIZE);
    errdefer allocator.free(frame);

    // Initialize to zeros
    @memset(frame, 0);

    // Copy header
    @memcpy(frame[0..HEADER_SIZE], &header);

    // Copy JPEG data
    @memcpy(frame[HEADER_SIZE .. HEADER_SIZE + jpeg_data.len], jpeg_data);

    // Verify size
    if (frame.len != FRAME_SIZE) {
        return LcdError.InvalidFrameSize;
    }

    return frame;
}

pub fn sendLcdFrame(dev: *LcdDevice, jpeg_data: []const u8, allocator: std.mem.Allocator) !void {
    const frame = try buildLcdFrame(jpeg_data, allocator);
    defer allocator.free(frame);

    // Send via USB bulk transfer
    var bytes_transferred: c_int = 0;
    const ret = usb.bulkTransfer(
        dev.usb_handle,
        dev.ep_out,
        @ptrCast(frame.ptr),
        @intCast(frame.len),
        &bytes_transferred,
        5000,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return LcdError.UsbTransferFailed;
    }

    if (bytes_transferred != FRAME_SIZE) {
        return LcdError.SendFailed;
    }

    // Try to read response to drain buffer (ignore timeout errors)
    var response_buf: [512]u8 = undefined;
    _ = usb.bulkTransfer(
        dev.usb_handle,
        dev.ep_in,
        &response_buf,
        512,
        &bytes_transferred,
        1000,
    );
}

fn buildLcdCommand(command: LcdCommand, value: u8, allocator: std.mem.Allocator) ![HEADER_SIZE]u8 {
    if (!key_initialized) {
        return LcdError.KeyNotInitialized;
    }

    // Manual header structure (plaintext)
    var plaintext: [504]u8 = [_]u8{0} ** 504;

    // Byte 0: Command
    plaintext[0] = @intFromEnum(command);

    // Bytes 2-3: Magic bytes
    plaintext[2] = 0x1a;
    plaintext[3] = 0x6d;

    // Bytes 4-7: Timestamp (little-endian)
    const ts = getTimestampMs();
    plaintext[4] = @intCast(ts & 0xFF);
    plaintext[5] = @intCast((ts >> 8) & 0xFF);
    plaintext[6] = @intCast((ts >> 16) & 0xFF);
    plaintext[7] = @intCast((ts >> 24) & 0xFF);

    // Byte 8: Command value
    plaintext[8] = value;

    // Pad to 512 bytes using PKCS7
    const padded = try des.pkcs7Pad(&plaintext, des.DES_BLOCK_SIZE, allocator);
    defer allocator.free(padded);

    // Encrypt with DES-CBC
    const encrypted = try allocator.alloc(u8, padded.len);
    defer allocator.free(encrypted);

    try des.desCbcEncrypt(padded, encrypted, &DES_KEY, &DES_IV);

    // Copy to output packet
    var packet: [HEADER_SIZE]u8 = [_]u8{0} ** HEADER_SIZE;
    @memcpy(&packet, encrypted);

    return packet;
}

pub fn setLcdBrightness(dev: *LcdDevice, level: u8, allocator: std.mem.Allocator) !void {
    const packet = try buildLcdCommand(.brightness, level, allocator);

    var bytes_transferred: c_int = 0;
    const ret = usb.bulkTransfer(
        dev.usb_handle,
        dev.ep_out,
        @ptrCast(&packet),
        HEADER_SIZE,
        &bytes_transferred,
        2000,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return LcdError.UsbTransferFailed;
    }
}

pub fn setLcdRotation(dev: *LcdDevice, rotation: u8, allocator: std.mem.Allocator) !void {
    const packet = try buildLcdCommand(.rotate, rotation & 0x03, allocator);

    var bytes_transferred: c_int = 0;
    const ret = usb.bulkTransfer(
        dev.usb_handle,
        dev.ep_out,
        @ptrCast(&packet),
        HEADER_SIZE,
        &bytes_transferred,
        2000,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return LcdError.UsbTransferFailed;
    }
}

pub fn stopLcdPlayback(dev: *LcdDevice, allocator: std.mem.Allocator) !void {
    const packet = try buildLcdCommand(.stop_play, 0, allocator);

    var bytes_transferred: c_int = 0;
    const ret = usb.bulkTransfer(
        dev.usb_handle,
        dev.ep_out,
        @ptrCast(&packet),
        HEADER_SIZE,
        &bytes_transferred,
        2000,
    );

    if (ret != usb.LIBUSB_SUCCESS) {
        return LcdError.UsbTransferFailed;
    }
}

pub fn initLcdDevice(bus: i32, device_addr: i32) !LcdDevice {
    var dev = LcdDevice{
        .ctx = null,
        .usb_handle = null,
        .ep_out = 0,
        .ep_in = 0,
        .start_time_ms = 0,
    };

    // Initialize libusb
    var ret = usb.init(&dev.ctx);
    if (ret != usb.LIBUSB_SUCCESS) {
        return LcdError.UsbInitFailed;
    }
    errdefer usb.exit(dev.ctx);

    // Get device list
    var device_list: [*c]?*anyopaque = undefined;
    const device_count = usb.getDeviceList(dev.ctx, &device_list);
    if (device_count < 0) {
        return LcdError.UsbInitFailed;
    }
    defer usb.freeDeviceList(device_list, 1);

    // Find matching device
    var found = false;
    var i: usize = 0;
    while (i < device_count) : (i += 1) {
        const device = device_list[i];

        // Check bus and address
        const dev_bus = usb.getBusNumber(device);
        const dev_addr = usb.getDeviceAddress(device);

        if (dev_bus != bus or dev_addr != device_addr) {
            continue;
        }

        // Check VID/PID
        var desc: usb.DeviceDescriptor = undefined;
        ret = usb.getDeviceDescriptor(device, &desc);
        if (ret != usb.LIBUSB_SUCCESS) {
            continue;
        }

        if (desc.idVendor != VID_WIRED or desc.idProduct != PID_WIRED) {
            continue;
        }

        // Open device
        ret = usb.open(device, &dev.usb_handle);
        if (ret != usb.LIBUSB_SUCCESS) {
            return LcdError.UsbOpenFailed;
        }

        found = true;
        break;
    }

    if (!found) {
        return LcdError.DeviceNotFound;
    }

    // Detach kernel driver if active
    if (usb.kernelDriverActive(dev.usb_handle, 0) == 1) {
        ret = usb.detachKernelDriver(dev.usb_handle, 0);
        if (ret != usb.LIBUSB_SUCCESS) {
            usb.close(dev.usb_handle);
            return LcdError.KernelDriverError;
        }
    }

    // Set configuration
    ret = usb.setConfiguration(dev.usb_handle, 1);
    if (ret != usb.LIBUSB_SUCCESS) {
        usb.close(dev.usb_handle);
        return LcdError.UsbClaimInterfaceFailed;
    }

    // Claim interface
    ret = usb.claimInterface(dev.usb_handle, 0);
    if (ret != usb.LIBUSB_SUCCESS) {
        usb.close(dev.usb_handle);
        return LcdError.UsbClaimInterfaceFailed;
    }

    // Set endpoints
    dev.ep_out = 0x01;
    dev.ep_in = 0x81;
    dev.start_time_ms = @intCast(std.time.milliTimestamp());

    std.log.info("LCD Device initialized", .{});
    std.log.info("  VID: 0x{x:0>4}, PID: 0x{x:0>4}", .{ VID_WIRED, PID_WIRED });
    std.log.info("  Bus: {d}, Address: {d}", .{ bus, device_addr });

    return dev;
}

pub fn cleanupLcdDevice(dev: *LcdDevice) void {
    if (dev.usb_handle) |handle| {
        usb.releaseInterface(handle, 0);
        usb.close(handle);
        dev.usb_handle = null;
    }
    if (dev.ctx) |ctx| {
        usb.exit(ctx);
        dev.ctx = null;
    }
}
