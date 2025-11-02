// LED module - Re-exports all LED-related functionality
pub const types = @import("led_types.zig");
pub const device = @import("led_device.zig");
pub const protocol = @import("led_protocol.zig");
pub const operations = @import("led_operations.zig");

// Re-export commonly used types and functions
pub const LedDevice = types.LedDevice;
pub const RfDeviceInfo = types.RfDeviceInfo;
pub const DeviceIdentifyInfo = types.DeviceIdentifyInfo;
pub const LedError = types.LedError;

pub const initLedDevice = device.initLedDevice;
pub const cleanupLedDevice = device.cleanupLedDevice;
pub const queryDevices = device.queryDevices;

pub const identifyDevice = operations.identifyDevice;
pub const identifyDevicesBatch = operations.identifyDevicesBatch;
pub const bindDevice = operations.bindDevice;
pub const unbindDevice = operations.unbindDevice;
pub const setLedEffect = operations.setLedEffect;
pub const saveConfig = operations.saveConfig;
