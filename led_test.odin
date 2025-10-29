package main

import "core:testing"
import "core:fmt"

@(test)
test_static_color :: proc(t: ^testing.T) {
	num_leds := 40
	rgb_data := generate_static_color(num_leds, 255, 0, 0)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3, "RGB data should be num_leds * 3 bytes")

	// Check that all LEDs are red (255, 0, 0)
	for i in 0..<num_leds {
		testing.expect(t, rgb_data[i * 3] == 255, "Red channel should be 255")
		testing.expect(t, rgb_data[i * 3 + 1] == 0, "Green channel should be 0")
		testing.expect(t, rgb_data[i * 3 + 2] == 0, "Blue channel should be 0")
	}
}

@(test)
test_static_color_hex :: proc(t: ^testing.T) {
	num_leds := 40
	rgb_data := generate_static_color_hex(num_leds, "FF0000")
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3, "RGB data should be num_leds * 3 bytes")

	// Check that all LEDs are red
	for i in 0..<num_leds {
		testing.expect(t, rgb_data[i * 3] == 255, "Red channel should be 255")
		testing.expect(t, rgb_data[i * 3 + 1] == 0, "Green channel should be 0")
		testing.expect(t, rgb_data[i * 3 + 2] == 0, "Blue channel should be 0")
	}
}

@(test)
test_rainbow :: proc(t: ^testing.T) {
	num_leds := 40
	rgb_data := generate_rainbow(num_leds, brightness = 100)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3, "RGB data should be num_leds * 3 bytes")

	// Check that we have variation in colors (not all the same)
	first_r := rgb_data[0]
	first_g := rgb_data[1]
	first_b := rgb_data[2]

	last_r := rgb_data[(num_leds - 1) * 3]
	last_g := rgb_data[(num_leds - 1) * 3 + 1]
	last_b := rgb_data[(num_leds - 1) * 3 + 2]

	has_variation := first_r != last_r || first_g != last_g || first_b != last_b
	testing.expect(t, has_variation, "Rainbow should have color variation")
}

@(test)
test_alternating :: proc(t: ^testing.T) {
	num_leds := 40
	color1 := [3]u8{255, 0, 0}
	color2 := [3]u8{0, 0, 255}
	rgb_data := generate_alternating(num_leds, color1, color2)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3, "RGB data should be num_leds * 3 bytes")

	// Check alternating pattern
	for i in 0..<num_leds {
		expected_color := i % 2 == 0 ? color1 : color2
		testing.expect(t, rgb_data[i * 3] == expected_color[0], "Red channel should match")
		testing.expect(t, rgb_data[i * 3 + 1] == expected_color[1], "Green channel should match")
		testing.expect(t, rgb_data[i * 3 + 2] == expected_color[2], "Blue channel should match")
	}
}

@(test)
test_alternating_spin :: proc(t: ^testing.T) {
	num_leds := 40
	num_frames := 60
	color1 := [3]u8{255, 0, 0}
	color2 := [3]u8{0, 0, 255}
	rgb_data := generate_alternating_spin(num_leds, color1, color2, num_frames)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3 * num_frames, "RGB data should be num_leds * 3 * num_frames bytes")

	// Check that frames are different (pattern rotates)
	frame1_led0_r := rgb_data[0]
	frame2_led0_r := rgb_data[num_leds * 3]

	// Due to rotation, these should differ
	testing.expect(t, frame1_led0_r != frame2_led0_r, "Frames should differ due to rotation")
}

@(test)
test_parse_hex_byte :: proc(t: ^testing.T) {
	testing.expect(t, parse_hex_byte("00") == 0, "00 should parse to 0")
	testing.expect(t, parse_hex_byte("FF") == 255, "FF should parse to 255")
	testing.expect(t, parse_hex_byte("ff") == 255, "ff should parse to 255")
	testing.expect(t, parse_hex_byte("80") == 128, "80 should parse to 128")
	testing.expect(t, parse_hex_byte("A5") == 165, "A5 should parse to 165")
}

@(test)
test_build_bind_packet :: proc(t: ^testing.T) {
	device_mac := [6]u8{0x5e, 0x1c, 0x7f, 0x72, 0xab, 0x3c}
	master_mac := [6]u8{0x11, 0x22, 0x33, 0x44, 0x55, 0x66}
	rx_type := u8(1)
	channel := u8(8)
	sequence := u8(1)

	packet := build_bind_packet(device_mac, master_mac, rx_type, channel, sequence)

	testing.expect(t, len(packet) == RF_PACKET_SIZE, "Packet should be RF_PACKET_SIZE bytes")
	testing.expect(t, packet[0] == CMD_RF_SEND, "First byte should be CMD_RF_SEND")
	testing.expect(t, packet[1] == SUBCMD_BIND, "Second byte should be SUBCMD_BIND")

	// Check device MAC
	for i in 0..<6 {
		testing.expect(t, packet[2 + i] == device_mac[i], "Device MAC should match")
	}

	// Check master MAC
	for i in 0..<6 {
		testing.expect(t, packet[8 + i] == master_mac[i], "Master MAC should match")
	}

	testing.expect(t, packet[14] == rx_type, "RX type should match")
	testing.expect(t, packet[15] == channel, "Channel should match")
	testing.expect(t, packet[16] == sequence, "Sequence should match")
}

@(test)
test_build_identify_packet :: proc(t: ^testing.T) {
	device_mac := [6]u8{0x5e, 0x1c, 0x7f, 0x72, 0xab, 0x3c}
	master_mac := [6]u8{0x11, 0x22, 0x33, 0x44, 0x55, 0x66}
	rx_type := u8(1)
	channel := u8(8)
	cmd_seq := u8(1)

	packet := build_identify_packet(device_mac, master_mac, rx_type, channel, cmd_seq)

	testing.expect(t, len(packet) == RF_PACKET_SIZE, "Packet should be RF_PACKET_SIZE bytes")
	testing.expect(t, packet[0] == CMD_RF_SEND, "First byte should be CMD_RF_SEND")
	testing.expect(t, packet[1] == SUBCMD_IDENTIFY, "Second byte should be SUBCMD_IDENTIFY")

	// Check device MAC
	for i in 0..<6 {
		testing.expect(t, packet[2 + i] == device_mac[i], "Device MAC should match")
	}

	// Check master MAC
	for i in 0..<6 {
		testing.expect(t, packet[8 + i] == master_mac[i], "Master MAC should match")
	}

	testing.expect(t, packet[14] == rx_type, "RX type should match")
	testing.expect(t, packet[15] == channel, "Channel should match")
	testing.expect(t, packet[17] == cmd_seq, "Command sequence should match")
}

@(test)
test_build_save_config_packet :: proc(t: ^testing.T) {
	master_mac := [6]u8{0x11, 0x22, 0x33, 0x44, 0x55, 0x66}

	packet := build_save_config_packet(master_mac)

	testing.expect(t, len(packet) == RF_PACKET_SIZE, "Packet should be RF_PACKET_SIZE bytes")
	testing.expect(t, packet[0] == CMD_RF_SEND, "First byte should be CMD_RF_SEND")
	testing.expect(t, packet[1] == SUBCMD_SAVE_CONFIG, "Second byte should be SUBCMD_SAVE_CONFIG")

	// Check broadcast MAC (all 0xFF)
	for i in 0..<6 {
		testing.expect(t, packet[2 + i] == 0xFF, "Device MAC should be broadcast (0xFF)")
	}

	// Check master MAC
	for i in 0..<6 {
		testing.expect(t, packet[8 + i] == master_mac[i], "Master MAC should match")
	}

	testing.expect(t, packet[14] == 0xFF, "RX type should be broadcast (0xFF)")
}

@(test)
test_split_rf_to_usb :: proc(t: ^testing.T) {
	rf_data := make([]u8, RF_PACKET_SIZE)
	defer delete(rf_data)

	// Fill with test data
	for i in 0..<RF_PACKET_SIZE {
		rf_data[i] = u8(i % 256)
	}

	channel := u8(8)
	rx_type := u8(1)

	packets, err := split_rf_to_usb(rf_data, channel, rx_type)
	defer delete(packets)

	testing.expect(t, err == .None, "Should not return an error")
	testing.expect(t, len(packets) == 4, "Should produce 4 USB packets")

	for packet in packets {
		testing.expect(t, len(packet) == USB_PACKET_SIZE, "Each packet should be USB_PACKET_SIZE bytes")
		testing.expect(t, packet[0] == 0x10, "First byte should be 0x10")
		testing.expect(t, packet[2] == channel, "Channel should match")
		testing.expect(t, packet[3] == rx_type, "RX type should match")
	}

	// Check sequence numbers
	testing.expect(t, packets[0][1] == 0, "First packet sequence should be 0")
	testing.expect(t, packets[1][1] == 1, "Second packet sequence should be 1")
	testing.expect(t, packets[2][1] == 2, "Third packet sequence should be 2")
	testing.expect(t, packets[3][1] == 3, "Fourth packet sequence should be 3")
}

@(test)
test_get_device_type_name :: proc(t: ^testing.T) {
	testing.expect(t, get_device_type_name(0) == "ALL", "Type 0 should be ALL")
	testing.expect(t, get_device_type_name(20) == "SLV3Fan", "Type 20 should be SLV3Fan")
	testing.expect(t, get_device_type_name(28) == "TLV2Fan", "Type 28 should be TLV2Fan")
	testing.expect(t, get_device_type_name(65) == "LC217", "Type 65 should be LC217")
}

@(test)
test_breathing_frames :: proc(t: ^testing.T) {
	num_leds := 40
	num_frames := 680
	rgb_data := generate_breathing(num_leds, num_frames, brightness = 100)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3 * num_frames, "RGB data should be num_leds * 3 * num_frames bytes")

	// Verify frames exist and have some variation
	// Compare frames further apart (frame 0 vs frame 40) to see breathing effect
	frame1_led0_r := rgb_data[0]
	frame40_led0_r := rgb_data[40 * num_leds * 3]

	// Frames should differ (breathing effect)
	testing.expect(t, frame1_led0_r != frame40_led0_r, "Frames should differ in breathing effect")
}

@(test)
test_color_cycle :: proc(t: ^testing.T) {
	num_leds := 40
	num_frames := 40
	rgb_data := generate_color_cycle(num_leds, num_frames, brightness = 100)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3 * num_frames, "RGB data should be num_leds * 3 * num_frames bytes")
}

@(test)
test_meteor :: proc(t: ^testing.T) {
	num_leds := 40
	num_frames := 360
	rgb_data := generate_meteor(num_leds, num_frames, brightness = 100)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3 * num_frames, "RGB data should be num_leds * 3 * num_frames bytes")
}

@(test)
test_twinkle :: proc(t: ^testing.T) {
	num_leds := 40
	num_frames := 200
	rgb_data := generate_twinkle(num_leds, num_frames, brightness = 100)
	defer delete(rgb_data)

	testing.expect(t, len(rgb_data) == num_leds * 3 * num_frames, "RGB data should be num_leds * 3 * num_frames bytes")
}
