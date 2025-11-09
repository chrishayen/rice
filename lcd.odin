package main

import "core:fmt"
import "core:mem"
import "core:c"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"

import des "libs/des"

// USB Device IDs for Lian Li SL-LCD wired controller
VID_WIRED :: 0x1cbe
PID_WIRED :: 0x0005

// LCD Display Constants
LCD_WIDTH :: 400
LCD_HEIGHT :: 400
FRAME_SIZE :: 102400  // Exact size required per frame
HEADER_SIZE :: 512
MAX_JPEG_SIZE :: FRAME_SIZE - HEADER_SIZE  // 101888 bytes

// DES encryption key - MUST be provided via -define flag at compile time
// Must be exactly 8 bytes for DES encryption
// Example: odin build . -define:DES_KEY="mykey123"
DES_KEY_STR :: #config(DES_KEY, "")

#assert(len(DES_KEY_STR) == 8, "DES_KEY must be provided via -define:DES_KEY=\"yourkey\" and must be exactly 8 bytes")

DES_KEY := [8]u8{
	DES_KEY_STR[0],
	DES_KEY_STR[1],
	DES_KEY_STR[2],
	DES_KEY_STR[3],
	DES_KEY_STR[4],
	DES_KEY_STR[5],
	DES_KEY_STR[6],
	DES_KEY_STR[7],
}

DES_IV := [8]u8{
	DES_KEY_STR[0],
	DES_KEY_STR[1],
	DES_KEY_STR[2],
	DES_KEY_STR[3],
	DES_KEY_STR[4],
	DES_KEY_STR[5],
	DES_KEY_STR[6],
	DES_KEY_STR[7],
}

// LCD Command Codes
LCD_Command :: enum u8 {
	Rotate     = 1,
	Brightness = 2,
	H264       = 13,
	JPEG       = 101,
	PNG        = 102,
	Stop_Play  = 120,
}

// LCD Device Handle
LCD_Device :: struct {
	ctx: rawptr,          // libusb context
	usb_handle: rawptr,   // libusb device handle
	ep_out: u8,           // OUT endpoint address
	ep_in: u8,            // IN endpoint address
	start_time_ms: u64,
}

// Error types
LCD_Error :: enum {
	None,
	Device_Not_Found,
	USB_Init_Failed,
	USB_Open_Failed,
	USB_Claim_Interface_Failed,
	USB_Transfer_Failed,
	Kernel_Driver_Error,
	Endpoint_Not_Found,
	Send_Failed,
	Invalid_Frame_Size,
	Encryption_Failed,
	Invalid_JPEG_Size,
}

// Generate timestamp in milliseconds
get_timestamp_ms :: proc() -> u32 {
	now := time.now()
	duration := time.since(time.Time{})
	ms := i64(time.duration_milliseconds(duration))
	return u32(ms)
}

// Generate encrypted LCD header matching Python protocol exactly
generate_lcd_header :: proc(jpeg_size: u32, command: LCD_Command = .JPEG, allocator := context.allocator) -> (header: [HEADER_SIZE]u8, ok: bool) {
	// Python uses 504-byte plaintext buffer
	plaintext: [504]u8

	// Byte 0: Command
	plaintext[0] = u8(command)

	// Bytes 2-3: Magic bytes
	plaintext[2] = 0x1a
	plaintext[3] = 0x6d

	// Bytes 4-7: Timestamp (little-endian)
	ts := get_timestamp_ms()
	plaintext[4] = u8(ts & 0xFF)
	plaintext[5] = u8((ts >> 8) & 0xFF)
	plaintext[6] = u8((ts >> 16) & 0xFF)
	plaintext[7] = u8((ts >> 24) & 0xFF)

	// Bytes 8-11: Image size (big-endian)
	plaintext[8] = u8((jpeg_size >> 24) & 0xFF)
	plaintext[9] = u8((jpeg_size >> 16) & 0xFF)
	plaintext[10] = u8((jpeg_size >> 8) & 0xFF)
	plaintext[11] = u8(jpeg_size & 0xFF)

	// Bytes 12-503: zeros (already initialized)

	// Pad to 512 bytes using PKCS7 padding (504 bytes + 8 bytes padding = 512)
	padded := des.pkcs7_pad(plaintext[:], des.DES_BLOCK_SIZE, allocator)
	defer delete(padded, allocator)

	// Encrypt with DES-CBC (encrypts all 512 bytes)
	encrypted := make([]u8, len(padded), allocator)
	defer delete(encrypted, allocator)

	des.des_cbc_encrypt(padded, encrypted, DES_KEY[:], DES_IV[:])

	// Copy encrypted 512-byte header to result
	copy(header[:], encrypted)

	return header, true
}

// Build complete frame (header + JPEG) - exactly 102,400 bytes like Python
build_lcd_frame :: proc(jpeg_data: []u8, allocator := context.allocator) -> (frame: []u8, err: LCD_Error) {
	// Check if JPEG data is too large
	if len(jpeg_data) > MAX_JPEG_SIZE {
		return nil, .Invalid_JPEG_Size
	}

	// Generate header
	header, ok := generate_lcd_header(u32(len(jpeg_data)))
	if !ok {
		return nil, .Encryption_Failed
	}

	// Allocate exactly FRAME_SIZE (102,400 bytes)
	frame = make([]u8, FRAME_SIZE, allocator)

	// Copy header (512 bytes)
	copy(frame[0:HEADER_SIZE], header[:])

	// Copy JPEG data (up to MAX_JPEG_SIZE = 101,888 bytes)
	copy(frame[HEADER_SIZE:HEADER_SIZE + len(jpeg_data)], jpeg_data)

	// Remaining bytes are already zero-initialized

	return frame, .None
}

// Send frame to LCD device
send_lcd_frame :: proc(dev: ^LCD_Device, jpeg_data: []u8) -> LCD_Error {
	frame, err := build_lcd_frame(jpeg_data)
	if err != .None {
		return err
	}
	defer delete(frame)

	// Send via USB bulk transfer
	bytes_transferred: c.int
	ret := libusb_bulk_transfer(
		dev.usb_handle,
		dev.ep_out,
		raw_data(frame),
		c.int(len(frame)),
		&bytes_transferred,
		5000, // 5 second timeout
	)

	if ret != LIBUSB_SUCCESS {
		return .USB_Transfer_Failed
	}

	if bytes_transferred != c.int(len(frame)) {
		return .Send_Failed
	}

	// Try to read response to drain buffer (ignore timeout errors)
	response_buf: [512]u8
	libusb_bulk_transfer(
		dev.usb_handle,
		dev.ep_in,
		raw_data(response_buf[:]),
		512,
		&bytes_transferred,
		1000, // 1 second timeout
	)

	return .None
}

// Build LCD command packet (for brightness, rotation, stop, etc.)
build_lcd_command :: proc(command: LCD_Command, value: u8 = 0, allocator := context.allocator) -> (packet: [HEADER_SIZE]u8, ok: bool) {
	// Manual header structure (plaintext)
	plaintext: [504]u8

	// Byte 0: Command
	plaintext[0] = u8(command)

	// Bytes 2-3: Magic bytes
	plaintext[2] = 0x1a
	plaintext[3] = 0x6d

	// Bytes 4-7: Timestamp (little-endian)
	ts := get_timestamp_ms()
	plaintext[4] = u8(ts & 0xFF)
	plaintext[5] = u8((ts >> 8) & 0xFF)
	plaintext[6] = u8((ts >> 16) & 0xFF)
	plaintext[7] = u8((ts >> 24) & 0xFF)

	// Byte 8: Command value (brightness level, rotation, etc.)
	plaintext[8] = value

	// TODO: Enable DES encryption when des library is available
	// Pad to 512 bytes using PKCS7
	// padded := des.pkcs7_pad(plaintext[:], des.DES_BLOCK_SIZE, allocator)
	// defer delete(padded, allocator)

	// Encrypt with DES-CBC
	// encrypted := make([]u8, len(padded), allocator)
	// defer delete(encrypted, allocator)

	// des.des_cbc_encrypt(padded, encrypted, DES_KEY[:], DES_IV[:])

	// Copy to output packet
	// copy(packet[:], encrypted)

	// Temporary: Return unencrypted packet (padded with zeros to 512 bytes)
	copy(packet[:len(plaintext)], plaintext[:])

	return packet, true
}

// Set LCD brightness (0-100)
set_lcd_brightness :: proc(dev: ^LCD_Device, level: u8) -> LCD_Error {
	packet, ok := build_lcd_command(.Brightness, level)
	if !ok {
		return .Encryption_Failed
	}

	// TODO: Send via USB
	// usb_bulk_write(dev.usb_handle, dev.ep_out, packet[:], HEADER_SIZE, 2000)

	return .None
}

// Set LCD rotation (0-3)
set_lcd_rotation :: proc(dev: ^LCD_Device, rotation: u8) -> LCD_Error {
	packet, ok := build_lcd_command(.Rotate, rotation & 0x03)
	if !ok {
		return .Encryption_Failed
	}

	// TODO: Send via USB
	// usb_bulk_write(dev.usb_handle, dev.ep_out, packet[:], HEADER_SIZE, 2000)

	return .None
}

// Stop video playback
stop_lcd_playback :: proc(dev: ^LCD_Device) -> LCD_Error {
	packet, ok := build_lcd_command(.Stop_Play, 0)
	if !ok {
		return .Encryption_Failed
	}

	// TODO: Send via USB
	// usb_bulk_write(dev.usb_handle, dev.ep_out, packet[:], HEADER_SIZE, 2000)

	return .None
}

// Initialize LCD device
// If bus and device_addr are both 0, finds the first LCD device
init_lcd_device :: proc(bus: int, device_addr: int) -> (dev: LCD_Device, err: LCD_Error) {
	// Use shared USB context
	ctx, ctx_err := get_usb_context()
	if ctx_err {
		return dev, .USB_Init_Failed
	}
	dev.ctx = ctx

	// Get device list
	device_list: ^rawptr
	device_count := libusb_get_device_list(dev.ctx, &device_list)
	if device_count < 0 {
		release_usb_context()
		return dev, .USB_Init_Failed
	}
	defer libusb_free_device_list(device_list, 1)

	// Find matching device
	find_any := (bus == 0 && device_addr == 0)
	found := false
	for i in 0..<device_count {
		device := mem.ptr_offset(device_list, i)^

		// Check VID/PID first
		desc: Device_Descriptor
		ret := libusb_get_device_descriptor(device, &desc)
		if ret != LIBUSB_SUCCESS {
			continue
		}

		if desc.idVendor != VID_WIRED || desc.idProduct != PID_WIRED {
			continue
		}

		// Check bus and address if specified
		if !find_any {
			dev_bus := libusb_get_bus_number(device)
			dev_addr := libusb_get_device_address(device)

			if int(dev_bus) != bus || int(dev_addr) != device_addr {
				continue
			}
		}

		// Open device
		ret = libusb_open(device, &dev.usb_handle)
		if ret != LIBUSB_SUCCESS {
			release_usb_context()
			return dev, .USB_Open_Failed
		}

		found = true
		break
	}

	if !found {
		release_usb_context()
		return dev, .Device_Not_Found
	}

	// Detach kernel driver if active
	if libusb_kernel_driver_active(dev.usb_handle, 0) == 1 {
		ret := libusb_detach_kernel_driver(dev.usb_handle, 0)
		if ret != LIBUSB_SUCCESS {
			libusb_close(dev.usb_handle)
			release_usb_context()
			return dev, .Kernel_Driver_Error
		}
	}

	// Set configuration
	ret := libusb_set_configuration(dev.usb_handle, 1)
	if ret != LIBUSB_SUCCESS {
		libusb_close(dev.usb_handle)
		release_usb_context()
		return dev, .USB_Claim_Interface_Failed
	}

	// Claim interface
	ret = libusb_claim_interface(dev.usb_handle, 0)
	if ret != LIBUSB_SUCCESS {
		libusb_close(dev.usb_handle)
		release_usb_context()
		return dev, .USB_Claim_Interface_Failed
	}

	// Set endpoints (found from pyusb code - endpoint 1 OUT, endpoint 0x81 IN)
	dev.ep_out = 0x01
	dev.ep_in = 0x81
	dev.start_time_ms = u64(get_timestamp_ms())

	fmt.printf("LCD Device initialized\n")
	fmt.printf("  VID: 0x%04x, PID: 0x%04x\n", VID_WIRED, PID_WIRED)
	fmt.printf("  Bus: %d, Address: %d\n", bus, device_addr)

	return dev, .None
}

// Cleanup LCD device
cleanup_lcd_device :: proc(dev: ^LCD_Device) {
	if dev.usb_handle != nil {
		// Release interface
		libusb_release_interface(dev.usb_handle, 0)
		// Close device
		libusb_close(dev.usb_handle)
		dev.usb_handle = nil
	}
	if dev.ctx != nil {
		// Release shared USB context reference
		release_usb_context()
		dev.ctx = nil
	}
}
