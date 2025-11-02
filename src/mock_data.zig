// Mock device data for UI testing
const std = @import("std");

pub const DeviceType = enum {
    SL120,
    SL120_LCD,
    TL,
};

pub const Device = struct {
    name: []const u8,
    mac_address: []const u8,
    fan_count: u32,
    led_count: u32,
    channel: u8,
    is_bound: bool,
    device_type: DeviceType,
};

pub fn getMockDevices() [3]Device {
    return [_]Device{
        Device{
            .name = "Front Intake Fans",
            .mac_address = "AA:BB:CC:DD:EE:01",
            .fan_count = 3,
            .led_count = 120, // 3 * 40 LEDs per SL120
            .channel = 1,
            .is_bound = true,
            .device_type = .SL120_LCD,
        },
        Device{
            .name = "Top Exhaust Fans",
            .mac_address = "AA:BB:CC:DD:EE:02",
            .fan_count = 2,
            .led_count = 80, // 2 * 40 LEDs per SL120
            .channel = 2,
            .is_bound = true,
            .device_type = .SL120,
        },
        Device{
            .name = "Rear Fan",
            .mac_address = "AA:BB:CC:DD:EE:03",
            .fan_count = 1,
            .led_count = 40, // 1 * 40 LEDs per SL120
            .channel = 3,
            .is_bound = false,
            .device_type = .SL120,
        },
    };
}
