const std = @import("std");

pub const c = @cImport({
    @cInclude("libusb-1.0/libusb.h");
});

pub const DeviceDescriptor = c.libusb_device_descriptor;

// libusb error codes
pub const LIBUSB_SUCCESS = c.LIBUSB_SUCCESS;
pub const LIBUSB_ERROR_IO = c.LIBUSB_ERROR_IO;
pub const LIBUSB_ERROR_INVALID_PARAM = c.LIBUSB_ERROR_INVALID_PARAM;
pub const LIBUSB_ERROR_ACCESS = c.LIBUSB_ERROR_ACCESS;
pub const LIBUSB_ERROR_NO_DEVICE = c.LIBUSB_ERROR_NO_DEVICE;
pub const LIBUSB_ERROR_NOT_FOUND = c.LIBUSB_ERROR_NOT_FOUND;
pub const LIBUSB_ERROR_BUSY = c.LIBUSB_ERROR_BUSY;
pub const LIBUSB_ERROR_TIMEOUT = c.LIBUSB_ERROR_TIMEOUT;

// USB endpoint constants
pub const LIBUSB_ENDPOINT_IN = c.LIBUSB_ENDPOINT_IN;
pub const LIBUSB_ENDPOINT_OUT = c.LIBUSB_ENDPOINT_OUT;

// Convenience wrappers
pub const init = c.libusb_init;
pub const exit = c.libusb_exit;
pub const getDeviceList = c.libusb_get_device_list;
pub const freeDeviceList = c.libusb_free_device_list;
pub const getBusNumber = c.libusb_get_bus_number;
pub const getDeviceAddress = c.libusb_get_device_address;
pub const getDeviceDescriptor = c.libusb_get_device_descriptor;
pub const open = c.libusb_open;
pub const close = c.libusb_close;
pub const kernelDriverActive = c.libusb_kernel_driver_active;
pub const detachKernelDriver = c.libusb_detach_kernel_driver;
pub const setConfiguration = c.libusb_set_configuration;
pub const claimInterface = c.libusb_claim_interface;
pub const releaseInterface = c.libusb_release_interface;
pub const bulkTransfer = c.libusb_bulk_transfer;
