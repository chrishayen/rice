package main

import "core:testing"
import "core:fmt"

@(test)
test_generate_lcd_header :: proc(t: ^testing.T) {
	// Test header generation with a known JPEG size
	jpeg_size: u32 = 50000
	header, ok := generate_lcd_header(jpeg_size)

	testing.expect(t, ok, "Header generation should succeed")
	testing.expect(t, len(header) == HEADER_SIZE, "Header should be exactly 512 bytes")

	// Header should be encrypted (not all zeros)
	all_zeros := true
	for b in header {
		if b != 0 {
			all_zeros = false
			break
		}
	}
	testing.expect(t, !all_zeros, "Header should be encrypted (not all zeros)")
}

@(test)
test_build_lcd_frame :: proc(t: ^testing.T) {
	// Create a small test JPEG (just some dummy data)
	test_jpeg := make([]u8, 1000)
	defer delete(test_jpeg)

	// Fill with some test data
	for i in 0..<len(test_jpeg) {
		test_jpeg[i] = u8(i % 256)
	}

	frame, err := build_lcd_frame(test_jpeg)
	defer if frame != nil do delete(frame)

	testing.expect(t, err == .None, "Frame build should succeed")
	testing.expect(t, len(frame) == FRAME_SIZE, "Frame should be exactly 102400 bytes")

	// Verify JPEG data is present in frame after header
	jpeg_matches := true
	for i in 0..<len(test_jpeg) {
		if frame[HEADER_SIZE + i] != test_jpeg[i] {
			jpeg_matches = false
			break
		}
	}
	testing.expect(t, jpeg_matches, "JPEG data should be present in frame")
}

@(test)
test_build_lcd_frame_too_large :: proc(t: ^testing.T) {
	// Create a JPEG that's too large
	too_large_jpeg := make([]u8, MAX_JPEG_SIZE + 1)
	defer delete(too_large_jpeg)

	frame, err := build_lcd_frame(too_large_jpeg)
	defer if frame != nil do delete(frame)

	testing.expect(t, err == .Invalid_JPEG_Size, "Should fail with Invalid_JPEG_Size error")
	testing.expect(t, frame == nil, "Frame should be nil on error")
}

@(test)
test_build_lcd_command :: proc(t: ^testing.T) {
	// Test brightness command
	packet, ok := build_lcd_command(.Brightness, 50)

	testing.expect(t, ok, "Command build should succeed")
	testing.expect(t, len(packet) == HEADER_SIZE, "Command packet should be 512 bytes")

	// Packet should be encrypted (not all zeros)
	all_zeros := true
	for b in packet {
		if b != 0 {
			all_zeros = false
			break
		}
	}
	testing.expect(t, !all_zeros, "Command packet should be encrypted")
}

@(test)
test_lcd_constants :: proc(t: ^testing.T) {
	testing.expect(t, LCD_WIDTH == 400, "LCD width should be 400")
	testing.expect(t, LCD_HEIGHT == 400, "LCD height should be 400")
	testing.expect(t, FRAME_SIZE == 102400, "Frame size should be 102400 bytes")
	testing.expect(t, HEADER_SIZE == 512, "Header size should be 512 bytes")
	testing.expect(t, MAX_JPEG_SIZE == FRAME_SIZE - HEADER_SIZE, "Max JPEG size calculation")
}

@(test)
test_get_timestamp_ms :: proc(t: ^testing.T) {
	ts1 := get_timestamp_ms()
	ts2 := get_timestamp_ms()

	// Timestamps should be non-zero
	testing.expect(t, ts1 > 0, "Timestamp should be non-zero")

	// Second timestamp should be >= first (time moves forward)
	testing.expect(t, ts2 >= ts1, "Time should move forward")
}
