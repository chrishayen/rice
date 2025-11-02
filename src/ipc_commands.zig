const std = @import("std");

pub const MessageType = enum(u32) {
    // Client -> Service
    get_devices,
    set_effect,
    get_status,
    identify_device,
    ping,

    // Service -> Client
    devices_response,
    status_response,
    effect_applied,
    identify_success,
    pong,
    err,
};

pub const IpcMessage = struct {
    type: MessageType,
    payload: []const u8, // JSON-encoded payload
};

pub const DeviceInfo = struct {
    mac_str: []const u8,
    dev_type_name: []const u8,
    channel: u8,
    bound_to_us: bool,
    fan_num: u8,
    rx_type: u8,
    led_count: i32,
};

pub const EffectRequest = struct {
    effect_name: []const u8,
    color1: [3]u8,
    color2: [3]u8,
    brightness: u8,
};

pub const IdentifyRequest = struct {
    devices: []IdentifyDeviceInfo,
};

pub const IdentifyDeviceInfo = struct {
    mac_str: []const u8,
    rx_type: u8,
    channel: u8,
};

pub const StatusInfo = struct {
    running: bool,
    master_mac: [6]u8,
    active_channel: u8,
    fw_version: u16,
    device_count: i32,
};
