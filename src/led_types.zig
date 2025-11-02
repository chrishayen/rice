const std = @import("std");

// USB Device IDs for SL wireless controllers
pub const VENDOR_ID: u16 = 0x0416;
pub const PRODUCT_ID_TX: u16 = 0x8040; // RF Transmitter
pub const PRODUCT_ID_RX: u16 = 0x8041; // RF Receiver

// USB Commands
pub const CMD_QUERY_DEVICES: u8 = 0x10;
pub const CMD_QUERY_MASTER: u8 = 0x11;
pub const CMD_RF_SEND: u8 = 0x12;

// RF Subcommands
pub const SUBCMD_BIND: u8 = 0x10;
pub const SUBCMD_IDENTIFY: u8 = 0x12;
pub const SUBCMD_STATUS: u8 = 0x14;
pub const SUBCMD_SAVE_CONFIG: u8 = 0x15;
pub const SUBCMD_LED_EFFECT: u8 = 0x20;

// Packet sizes
pub const USB_PACKET_SIZE: usize = 64;
pub const RF_PACKET_SIZE: usize = 240;
pub const DEVICE_ENTRY_SIZE: usize = 42;

// Device entry offsets (in 42-byte device record)
pub const DEV_MAC_OFFSET: usize = 0;
pub const DEV_MASTER_MAC_OFFSET: usize = 6;
pub const DEV_CHANNEL_OFFSET: usize = 12;
pub const DEV_RX_TYPE_OFFSET: usize = 13;
pub const DEV_TIMESTAMP_OFFSET: usize = 14;
pub const DEV_TYPE_OFFSET: usize = 18;
pub const DEV_FAN_NUM_OFFSET: usize = 19;
pub const DEV_EFFECT_OFFSET: usize = 20;
pub const DEV_FAN_TYPES_OFFSET: usize = 24;
pub const DEV_FAN_SPEEDS_OFFSET: usize = 28;
pub const DEV_FAN_PWM_OFFSET: usize = 36;
pub const DEV_CMD_SEQ_OFFSET: usize = 40;
pub const DEV_TYPE_VALIDATION_OFFSET: usize = 41;

// RF Channel Constants
pub const DEFAULT_CHANNEL: u8 = 8;
pub const VALID_CHANNELS = [_]u8{ 1, 7, 11, 15, 17, 21, 25, 29, 31, 33, 35, 39 };

// Device Type Constants
pub const DeviceType = enum(u8) {
    all = 0,
    strimer = 1,
    water_block = 10,
    water_block2 = 11,
    slv3_fan = 20, // SL v3 wireless fans (40 LEDs each)
    slv3_fan_21 = 21,
    slv3_fan_22 = 22,
    slv3_fan_23 = 23,
    slv3_fan_24 = 24,
    slv3_fan_25 = 25,
    slv3_fan_26 = 26,
    tlv2_fan = 28, // TL v2 wireless fans (26 LEDs each)
    slinf = 36,
    rl120 = 40,
    clv1 = 41,
    lc217 = 65, // LCD controller
    led88 = 88,
    open_rgb_dev = 99,
    _,
};

pub fn getDeviceTypeName(allocator: std.mem.Allocator, dev_type: u8) ![]const u8 {
    return switch (@as(DeviceType, @enumFromInt(dev_type))) {
        .all => try allocator.dupe(u8, "ALL"),
        .strimer => try allocator.dupe(u8, "Strimer"),
        .water_block => try allocator.dupe(u8, "WaterBlock"),
        .water_block2 => try allocator.dupe(u8, "WaterBlock2"),
        .slv3_fan => try allocator.dupe(u8, "SLV3Fan"),
        .slv3_fan_21 => try allocator.dupe(u8, "SLV3Fan_21"),
        .slv3_fan_22 => try allocator.dupe(u8, "SLV3Fan_22"),
        .slv3_fan_23 => try allocator.dupe(u8, "SLV3Fan_23"),
        .slv3_fan_24 => try allocator.dupe(u8, "SLV3Fan_24"),
        .slv3_fan_25 => try allocator.dupe(u8, "SLV3Fan_25"),
        .slv3_fan_26 => try allocator.dupe(u8, "SLV3Fan_26"),
        .tlv2_fan => try allocator.dupe(u8, "TLV2Fan"),
        .slinf => try allocator.dupe(u8, "SLINF"),
        .rl120 => try allocator.dupe(u8, "RL120"),
        .clv1 => try allocator.dupe(u8, "CLV1"),
        .lc217 => try allocator.dupe(u8, "LC217"),
        .led88 => try allocator.dupe(u8, "Led88"),
        .open_rgb_dev => try allocator.dupe(u8, "OpenRgbDev"),
        _ => try std.fmt.allocPrint(allocator, "Unknown({d})", .{dev_type}),
    };
}

const usb = @import("usb.zig");

// LED Device Handle
pub const LedDevice = struct {
    ctx: ?*usb.c.struct_libusb_context, // libusb context
    rf_sender: ?*usb.c.struct_libusb_device_handle, // USB device handle for transmitter
    rf_receiver: ?*usb.c.struct_libusb_device_handle, // USB device handle for receiver
    ep_out_tx: u8,
    ep_in_tx: u8,
    ep_out_rx: u8,
    ep_in_rx: u8,
    master_mac: [6]u8,
    active_channel: u8,
    time_tmos: u32,
    sys_clock: u32,
    fw_version: u16,
    cmd_seq: u8,
};

// RF Device Info
pub const RfDeviceInfo = struct {
    mac: [6]u8,
    mac_str: []const u8,
    master_mac: [6]u8,
    master_mac_str: []const u8,
    channel: u8,
    rx_type: u8,
    timestamp: u32,
    dev_type: u8,
    dev_type_name: []const u8,
    fan_num: u8,
    fan_types: [4]u8,
    cmd_seq: u8,
    bound_to_us: bool,
    is_unbound: bool,
};

// Device info for batch identify
pub const DeviceIdentifyInfo = struct {
    device_mac: [6]u8,
    rx_type: u8,
    channel: u8,
};

// Error types
pub const LedError = error{
    DeviceNotFound,
    UsbInitFailed,
    UsbOpenFailed,
    UsbClaimInterfaceFailed,
    UsbTransferFailed,
    KernelDriverError,
    EndpointNotFound,
    QueryFailed,
    SendFailed,
    CompressionFailed,
    InvalidMac,
};
