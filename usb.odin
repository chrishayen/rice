package main

import "core:c"

// Foreign imports for libusb
foreign import libusb "system:usb-1.0"

@(default_calling_convention="c")
foreign libusb {
	libusb_init :: proc(ctx: ^rawptr) -> c.int ---
	libusb_exit :: proc(ctx: rawptr) ---
	libusb_get_device_list :: proc(ctx: rawptr, list: ^^rawptr) -> c.ssize_t ---
	libusb_free_device_list :: proc(list: ^rawptr, unref_devices: c.int) ---
	libusb_get_bus_number :: proc(dev: rawptr) -> u8 ---
	libusb_get_device_address :: proc(dev: rawptr) -> u8 ---
	libusb_get_device_descriptor :: proc(dev: rawptr, desc: ^Device_Descriptor) -> c.int ---
	libusb_open :: proc(dev: rawptr, handle: ^rawptr) -> c.int ---
	libusb_close :: proc(handle: rawptr) ---
	libusb_kernel_driver_active :: proc(handle: rawptr, interface_number: c.int) -> c.int ---
	libusb_detach_kernel_driver :: proc(handle: rawptr, interface_number: c.int) -> c.int ---
	libusb_set_configuration :: proc(handle: rawptr, configuration: c.int) -> c.int ---
	libusb_claim_interface :: proc(handle: rawptr, interface_number: c.int) -> c.int ---
	libusb_release_interface :: proc(handle: rawptr, interface_number: c.int) ---
	libusb_bulk_transfer :: proc(handle: rawptr, endpoint: u8, data: [^]u8, length: c.int, transferred: ^c.int, timeout: c.uint) -> c.int ---
}

// libusb types
Device_Descriptor :: struct {
	bLength: u8,
	bDescriptorType: u8,
	bcdUSB: u16,
	bDeviceClass: u8,
	bDeviceSubClass: u8,
	bDeviceProtocol: u8,
	bMaxPacketSize0: u8,
	idVendor: u16,
	idProduct: u16,
	bcdDevice: u16,
	iManufacturer: u8,
	iProduct: u8,
	iSerialNumber: u8,
	bNumConfigurations: u8,
}

// libusb error codes
LIBUSB_SUCCESS :: 0
LIBUSB_ERROR_IO :: -1
LIBUSB_ERROR_INVALID_PARAM :: -2
LIBUSB_ERROR_ACCESS :: -3
LIBUSB_ERROR_NO_DEVICE :: -4
LIBUSB_ERROR_NOT_FOUND :: -5
LIBUSB_ERROR_BUSY :: -6
LIBUSB_ERROR_TIMEOUT :: -7

// USB endpoint constants
LIBUSB_ENDPOINT_IN :: 0x80
LIBUSB_ENDPOINT_OUT :: 0x00
