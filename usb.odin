package main

import "core:c"
import "core:strings"

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
	libusb_get_string_descriptor_ascii :: proc(handle: rawptr, desc_index: u8, data: [^]u8, length: c.int) -> c.int ---
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

// Get USB serial number from device
// Returns empty string on failure
get_usb_serial_number :: proc(device: rawptr, handle: rawptr, allocator := context.allocator) -> string {
	// Get device descriptor to find serial number index
	desc: Device_Descriptor
	ret := libusb_get_device_descriptor(device, &desc)
	if ret != LIBUSB_SUCCESS {
		return ""
	}

	// Check if device has a serial number
	if desc.iSerialNumber == 0 {
		return ""
	}

	// Read serial number string
	buffer: [256]u8
	length := libusb_get_string_descriptor_ascii(handle, desc.iSerialNumber, raw_data(buffer[:]), 256)
	if length < 0 {
		return ""
	}

	// Convert to Odin string
	return strings.clone_from_bytes(buffer[:length], allocator)
}

