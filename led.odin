package main

import "core:fmt"
import "core:mem"
import "core:c"
import "core:time"
import "core:slice"

import tuz "libs/tinyuz"

// USB Device IDs for SL wireless controllers
VENDOR_ID :: 0x0416
PRODUCT_ID_TX :: 0x8040  // RF Transmitter (for sending commands, querying master)
PRODUCT_ID_RX :: 0x8041  // RF Receiver (for querying devices)

// USB Commands
CMD_QUERY_DEVICES :: 0x10    // Query all RF devices (bound and unbound)
CMD_QUERY_MASTER :: 0x11     // Query master controller info
CMD_RF_SEND :: 0x12          // Send RF command

// RF Subcommands (used with CMD_RF_SEND)
SUBCMD_BIND :: 0x10
SUBCMD_IDENTIFY :: 0x12
SUBCMD_SAVE_CONFIG :: 0x15
SUBCMD_STATUS :: 0x14
SUBCMD_LED_EFFECT :: 0x20

// Packet sizes
USB_PACKET_SIZE :: 64
RF_PACKET_SIZE :: 240
DEVICE_ENTRY_SIZE :: 42

// Device entry offsets (in 42-byte device record)
DEV_MAC_OFFSET :: 0
DEV_MASTER_MAC_OFFSET :: 6
DEV_CHANNEL_OFFSET :: 12
DEV_RX_TYPE_OFFSET :: 13
DEV_TIMESTAMP_OFFSET :: 14
DEV_TYPE_OFFSET :: 18
DEV_FAN_NUM_OFFSET :: 19
DEV_EFFECT_OFFSET :: 20
DEV_FAN_TYPES_OFFSET :: 24
DEV_FAN_SPEEDS_OFFSET :: 28
DEV_FAN_PWM_OFFSET :: 36
DEV_CMD_SEQ_OFFSET :: 40
DEV_TYPE_VALIDATION_OFFSET :: 41

// RF Channel Constants
DEFAULT_CHANNEL :: 8
VALID_CHANNELS := [12]u8{1, 7, 11, 15, 17, 21, 25, 29, 31, 33, 35, 39}

// Device Type Constants
Device_Type :: enum u8 {
	ALL = 0,
	Strimer = 1,
	WaterBlock = 10,
	WaterBlock2 = 11,
	SLV3Fan = 20,         // SL v3 wireless fans (40 LEDs each)
	SLV3Fan_21 = 21,
	SLV3Fan_22 = 22,
	SLV3Fan_23 = 23,
	SLV3Fan_24 = 24,
	SLV3Fan_25 = 25,
	SLV3Fan_26 = 26,
	TLV2Fan = 28,         // TL v2 wireless fans (26 LEDs each)
	SLINF = 36,
	RL120 = 40,
	CLV1 = 41,
	LC217 = 65,           // LCD controller
	Led88 = 88,
	OpenRgbDev = 99,
}

// LED Device Handle
LED_Device :: struct {
	ctx: rawptr,              // libusb context
	rf_sender: rawptr,        // USB device handle for transmitter (0x8040)
	rf_receiver: rawptr,      // USB device handle for receiver (0x8041)
	ep_out_tx: u8,            // TX endpoint out
	ep_in_tx: u8,             // TX endpoint in
	ep_out_rx: u8,            // RX endpoint out
	ep_in_rx: u8,             // RX endpoint in
	master_mac: [6]u8,        // Master controller MAC address
	active_channel: u8,       // Active RF channel
	time_tmos: u32,           // Timestamp value
	sys_clock: u32,           // System clock in ms
	fw_version: u16,          // Firmware version
	cmd_seq: u8,              // Command sequence counter (increments with each packet)
}

// RF Device Info
RF_Device_Info :: struct {
	mac: [6]u8,
	mac_str: string,
	master_mac: [6]u8,
	master_mac_str: string,
	channel: u8,
	rx_type: u8,
	timestamp: u32,
	dev_type: u8,
	dev_type_name: string,
	fan_num: u8,
	fan_types: [4]u8,
	cmd_seq: u8,
	bound_to_us: bool,
	is_unbound: bool,
}

// Error types
LED_Error :: enum {
	None,
	Device_Not_Found,
	USB_Init_Failed,
	USB_Open_Failed,
	USB_Claim_Interface_Failed,
	USB_Transfer_Failed,
	Kernel_Driver_Error,
	Endpoint_Not_Found,
	Query_Failed,
	Send_Failed,
	Compression_Failed,
	Invalid_MAC,
}

// Get device type name
get_device_type_name :: proc(dev_type: u8) -> string {
	switch Device_Type(dev_type) {
	case .ALL: return "ALL"
	case .Strimer: return "Strimer"
	case .WaterBlock: return "WaterBlock"
	case .WaterBlock2: return "WaterBlock2"
	case .SLV3Fan: return "SLV3Fan"
	case .SLV3Fan_21: return "SLV3Fan_21"
	case .SLV3Fan_22: return "SLV3Fan_22"
	case .SLV3Fan_23: return "SLV3Fan_23"
	case .SLV3Fan_24: return "SLV3Fan_24"
	case .SLV3Fan_25: return "SLV3Fan_25"
	case .SLV3Fan_26: return "SLV3Fan_26"
	case .TLV2Fan: return "TLV2Fan"
	case .SLINF: return "SLINF"
	case .RL120: return "RL120"
	case .CLV1: return "CLV1"
	case .LC217: return "LC217"
	case .Led88: return "Led88"
	case .OpenRgbDev: return "OpenRgbDev"
	case: return fmt.tprintf("Unknown(%d)", dev_type)
	}
}

// Query master device on specified channel via RF Transmitter
query_master_device :: proc(dev: ^LED_Device, channel: u8) -> bool {
	query: [USB_PACKET_SIZE]u8
	query[0] = CMD_QUERY_MASTER
	query[1] = channel

	bytes_transferred: c.int
	ret := libusb_bulk_transfer(
		dev.rf_sender,
		dev.ep_out_tx,
		raw_data(query[:]),
		USB_PACKET_SIZE,
		&bytes_transferred,
		500, // 500ms timeout
	)

	if ret != LIBUSB_SUCCESS {
		return false
	}

	response: [USB_PACKET_SIZE]u8
	ret = libusb_bulk_transfer(
		dev.rf_sender,
		dev.ep_in_tx,
		raw_data(response[:]),
		USB_PACKET_SIZE,
		&bytes_transferred,
		500,
	)

	if ret != LIBUSB_SUCCESS || response[0] != CMD_QUERY_MASTER {
		return false
	}

	// Parse and store values
	copy(dev.master_mac[:], response[1:7])

	// Bytes 7-10: 32-bit timestamp value (actual time in ms = value * 0.625)
	dev.time_tmos = u32(response[7]) << 24 | u32(response[8]) << 16 | u32(response[9]) << 8 | u32(response[10])
	dev.sys_clock = u32(f32(dev.time_tmos) * 0.625)

	// Bytes 11-12: Firmware version (2 bytes)
	dev.fw_version = u16(response[11]) << 8 | u16(response[12])

	return true
}

// Query all RF devices (both bound and unbound) via RF Receiver
query_devices :: proc(dev: ^LED_Device, allocator := context.allocator) -> (devices: []RF_Device_Info, err: LED_Error) {
	query: [USB_PACKET_SIZE]u8
	query[0] = CMD_QUERY_DEVICES
	query[1] = 1  // page

	bytes_transferred: c.int
	ret := libusb_bulk_transfer(
		dev.rf_receiver,
		dev.ep_out_rx,
		raw_data(query[:]),
		USB_PACKET_SIZE,
		&bytes_transferred,
		15000, // 15 second timeout
	)

	if ret != LIBUSB_SUCCESS {
		return nil, .USB_Transfer_Failed
	}

	// Read more data to handle multiple devices
	response := make([]u8, USB_PACKET_SIZE * 4, allocator)
	defer delete(response, allocator)

	ret = libusb_bulk_transfer(
		dev.rf_receiver,
		dev.ep_in_rx,
		raw_data(response),
		c.int(len(response)),
		&bytes_transferred,
		15000,
	)

	if ret != LIBUSB_SUCCESS || len(response) < 4 || response[0] != CMD_QUERY_DEVICES {
		return nil, .Query_Failed
	}

	num_devices := response[1]
	if num_devices == 0 {
		return nil, .None
	}

	devices_list := make([dynamic]RF_Device_Info, 0, int(num_devices), allocator)
	offset := 4  // Device entries start at byte 4

	for i in 0..<int(num_devices) {
		if offset + DEVICE_ENTRY_SIZE > len(response) {
			break
		}

		// Check validation byte - must be 28 (0x1C) for valid entry
		if response[offset + DEV_TYPE_VALIDATION_OFFSET] != 28 {
			offset += DEVICE_ENTRY_SIZE
			continue
		}

		device_info: RF_Device_Info

		// Parse MAC addresses
		copy(device_info.mac[:], response[offset + DEV_MAC_OFFSET:offset + DEV_MAC_OFFSET + 6])
		copy(device_info.master_mac[:], response[offset + DEV_MASTER_MAC_OFFSET:offset + DEV_MASTER_MAC_OFFSET + 6])

		// Format MAC strings
		device_info.mac_str = fmt.tprintf("%02x:%02x:%02x:%02x:%02x:%02x",
			device_info.mac[0], device_info.mac[1], device_info.mac[2],
			device_info.mac[3], device_info.mac[4], device_info.mac[5])
		device_info.master_mac_str = fmt.tprintf("%02x:%02x:%02x:%02x:%02x:%02x",
			device_info.master_mac[0], device_info.master_mac[1], device_info.master_mac[2],
			device_info.master_mac[3], device_info.master_mac[4], device_info.master_mac[5])

		// Parse timestamp
		ts_offset := offset + DEV_TIMESTAMP_OFFSET
		device_info.timestamp = u32(response[ts_offset]) << 24 | u32(response[ts_offset + 1]) << 16 |
		                        u32(response[ts_offset + 2]) << 8 | u32(response[ts_offset + 3])

		// Check if bound to us
		device_info.bound_to_us = slice.equal(device_info.master_mac[:], dev.master_mac[:])
		device_info.is_unbound = slice.all_of_proc(device_info.master_mac[:], proc(b: u8) -> bool { return b == 0 })

		device_info.channel = response[offset + DEV_CHANNEL_OFFSET]
		device_info.rx_type = response[offset + DEV_RX_TYPE_OFFSET]
		device_info.dev_type = response[offset + DEV_TYPE_OFFSET]
		device_info.fan_num = response[offset + DEV_FAN_NUM_OFFSET]
		copy(device_info.fan_types[:], response[offset + DEV_FAN_TYPES_OFFSET:offset + DEV_FAN_TYPES_OFFSET + 4])

		// Use first fan type as device type name (dev_type field is often 0/ALL)
		// The actual device types are in the fan_types array
		actual_dev_type := device_info.fan_types[0] if device_info.fan_num > 0 else device_info.dev_type
		device_info.dev_type_name = get_device_type_name(actual_dev_type)

		device_info.cmd_seq = response[offset + DEV_CMD_SEQ_OFFSET]

		append(&devices_list, device_info)
		offset += DEVICE_ENTRY_SIZE
	}

	return devices_list[:], .None
}

// Split 240-byte RF packet into 4 USB packets
split_rf_to_usb :: proc(rf_data: []u8, channel: u8, rx_type: u8, allocator := context.allocator) -> (packets: [][USB_PACKET_SIZE]u8, err: LED_Error) {
	if len(rf_data) != RF_PACKET_SIZE {
		return nil, .Send_Failed
	}

	packets_list := make([dynamic][USB_PACKET_SIZE]u8, 0, 4, allocator)
	seq: u8 = 0

	for i := 0; i < RF_PACKET_SIZE; i += 60 {
		chunk_end := min(i + 60, RF_PACKET_SIZE)
		chunk := rf_data[i:chunk_end]

		// USB packet structure: [0x10, seq, channel, rx_type, ...60 bytes RF data]
		packet: [USB_PACKET_SIZE]u8
		packet[0] = 0x10
		packet[1] = seq
		packet[2] = channel
		packet[3] = rx_type
		copy(packet[4:], chunk)

		append(&packets_list, packet)
		seq += 1
	}

	return packets_list[:], .None
}

// Send a complete RF packet via USB TX device
send_rf_packet :: proc(dev: ^LED_Device, rf_data: []u8, channel: u8, rx_type: u8, delay_ms: f32 = 1.0) -> LED_Error {
	packets, err := split_rf_to_usb(rf_data, channel, rx_type)
	if err != .None {
		return err
	}
	defer delete(packets)

	for &packet in packets {
		bytes_transferred: c.int
		ret := libusb_bulk_transfer(
			dev.rf_sender,
			dev.ep_out_tx,
			raw_data(packet[:]),
			USB_PACKET_SIZE,
			&bytes_transferred,
			5000, // 5 second timeout
		)

		if ret != LIBUSB_SUCCESS {
			return .USB_Transfer_Failed
		}

		if delay_ms > 0 {
			time.sleep(time.Duration(delay_ms * 1_000_000)) // Convert to nanoseconds
		}
	}

	return .None
}

// Build bind/unbind RF packet
build_bind_packet :: proc(device_mac: [6]u8, master_mac: [6]u8, rx_type: u8, channel: u8, sequence: u8 = 1, pwm: [4]u8 = {99, 99, 99, 99}) -> [RF_PACKET_SIZE]u8 {
	packet: [RF_PACKET_SIZE]u8
	packet[0] = CMD_RF_SEND
	packet[1] = SUBCMD_BIND
	for i in 0..<6 {
		packet[2 + i] = device_mac[i]
		packet[8 + i] = master_mac[i]
	}
	packet[14] = rx_type
	packet[15] = channel
	packet[16] = sequence
	for i in 0..<4 {
		packet[17 + i] = pwm[i]
	}
	return packet
}

// Build identify command RF packet (turns LEDs yellow)
build_identify_packet :: proc(device_mac: [6]u8, master_mac: [6]u8, rx_type: u8, channel: u8, cmd_seq: u8 = 1) -> [RF_PACKET_SIZE]u8 {
	packet: [RF_PACKET_SIZE]u8
	packet[0] = CMD_RF_SEND
	packet[1] = SUBCMD_IDENTIFY
	for i in 0..<6 {
		packet[2 + i] = device_mac[i]
		packet[8 + i] = master_mac[i]
	}
	packet[14] = rx_type
	packet[15] = channel
	packet[16] = 0x00  // Device index
	packet[17] = cmd_seq
	return packet
}

// Build SaveConfig RF packet to persist effects to device flash
build_save_config_packet :: proc(master_mac: [6]u8) -> [RF_PACKET_SIZE]u8 {
	packet: [RF_PACKET_SIZE]u8
	packet[0] = CMD_RF_SEND
	packet[1] = SUBCMD_SAVE_CONFIG
	// Broadcast MAC
	packet[2] = 0xFF
	packet[3] = 0xFF
	packet[4] = 0xFF
	packet[5] = 0xFF
	packet[6] = 0xFF
	packet[7] = 0xFF
	for i in 0..<6 {
		packet[8 + i] = master_mac[i]
	}
	packet[14] = 0xFF  // rx_type broadcast
	packet[15] = 0x00
	packet[16] = 0x00
	return packet
}

// Build LED effect RF packets (metadata + data packets)
build_led_effect_packets :: proc(
	compressed_data: []u8,
	led_count: u8,
	device_mac: [6]u8,
	master_mac: [6]u8,
	total_frame: u16 = 1,
	effect_index: Maybe([4]u8) = nil,
	allocator := context.allocator,
) -> (packets: [][RF_PACKET_SIZE]u8, err: LED_Error) {
	// Generate timestamp for effect_index if not provided
	effect_idx: [4]u8
	if idx, ok := effect_index.?; ok {
		effect_idx = idx
	} else {
		timestamp := u32(time.now()._nsec / 1_000_000) // Convert to milliseconds
		effect_idx[0] = u8((timestamp >> 24) & 0xFF)
		effect_idx[1] = u8((timestamp >> 16) & 0xFF)
		effect_idx[2] = u8((timestamp >> 8) & 0xFF)
		effect_idx[3] = u8(timestamp & 0xFF)
	}

	// Calculate number of data packets needed (220 bytes per packet)
	lzo_rgb_rf_valid_len := 220
	total_pk_num := (len(compressed_data) + lzo_rgb_rf_valid_len - 1) / lzo_rgb_rf_valid_len

	packets_list := make([dynamic][RF_PACKET_SIZE]u8, 0, total_pk_num + 1, allocator)

	// Metadata packet (packet_idx=0)
	metadata: [RF_PACKET_SIZE]u8
	metadata[0] = CMD_RF_SEND
	metadata[1] = SUBCMD_LED_EFFECT
	for i in 0..<6 {
		metadata[2 + i] = device_mac[i]
		metadata[8 + i] = master_mac[i]
	}
	for i in 0..<4 {
		metadata[14 + i] = effect_idx[i]
	}
	metadata[18] = 0  // packet_idx
	metadata[19] = u8(total_pk_num + 1)  // total packets including metadata

	// Compressed data length (big-endian)
	compressed_len := u32(len(compressed_data))
	metadata[20] = u8((compressed_len >> 24) & 0xFF)
	metadata[21] = u8((compressed_len >> 16) & 0xFF)
	metadata[22] = u8((compressed_len >> 8) & 0xFF)
	metadata[23] = u8(compressed_len & 0xFF)

	// Total frames (big-endian)
	metadata[25] = u8((total_frame >> 8) & 0xFF)
	metadata[26] = u8(total_frame & 0xFF)
	metadata[27] = led_count

	// Set interval based on whether it's an animation or static
	interval: u16 = total_frame > 1 ? 100 : 20
	metadata[32] = u8((interval >> 8) & 0xFF)
	metadata[33] = u8(interval & 0xFF)
	metadata[34] = 0  // interval fractional part
	metadata[35] = u8((interval >> 8) & 0xFF)
	metadata[36] = u8(interval & 0xFF)
	metadata[37] = 1  // isOuterMatchMax
	metadata[38] = 0  // total_sub_frame high byte
	metadata[39] = 1  // total_sub_frame low byte

	append(&packets_list, metadata)

	// Data packets
	offset := 0
	for packet_idx in 1..=total_pk_num {
		data_pkt: [RF_PACKET_SIZE]u8
		data_pkt[0] = CMD_RF_SEND
		data_pkt[1] = SUBCMD_LED_EFFECT
		for i in 0..<6 {
			data_pkt[2 + i] = device_mac[i]
			data_pkt[8 + i] = master_mac[i]
		}
		for i in 0..<4 {
			data_pkt[14 + i] = effect_idx[i]
		}
		data_pkt[18] = u8(packet_idx)
		data_pkt[19] = u8(total_pk_num + 1)

		chunk_size := min(lzo_rgb_rf_valid_len, len(compressed_data) - offset)
		copy(data_pkt[20:20+chunk_size], compressed_data[offset:offset+chunk_size])
		offset += lzo_rgb_rf_valid_len

		append(&packets_list, data_pkt)
	}

	return packets_list[:], .None
}

// Get next command sequence number and increment
get_next_cmd_seq :: proc(dev: ^LED_Device) -> u8 {
	seq := dev.cmd_seq
	dev.cmd_seq += 1
	if dev.cmd_seq == 0 {
		dev.cmd_seq = 1
	}
	return seq
}

// Identify device (flashes LEDs yellow)
identify_device :: proc(dev: ^LED_Device, device_mac: [6]u8, rx_type: u8, channel: u8) -> LED_Error {
	// Send identify multiple times for reliability (like L-Connect)
	for attempt in 0..<10 {
		for try_rx_type in 1..=3 {
			seq := get_next_cmd_seq(dev)
			rf_packet := build_identify_packet(device_mac, dev.master_mac, u8(try_rx_type), channel, seq)
			err := send_rf_packet(dev, rf_packet[:], channel, u8(try_rx_type), delay_ms = 0.5)
			if err != .None {
				return err
			}
		}
		time.sleep(100 * time.Millisecond)
	}

	return .None
}

// Device info for batch identify
Device_Identify_Info :: struct {
	device_mac: [6]u8,
	rx_type: u8,
	channel: u8,
}

// Identify multiple devices simultaneously by interleaving packets
identify_devices_batch :: proc(dev: ^LED_Device, devices: []Device_Identify_Info) -> LED_Error {
	if len(devices) == 0 do return .None

	// Send identify packets for all devices in round-robin fashion
	for attempt in 0..<10 {
		for device in devices {
			for try_rx_type in 1..=3 {
				seq := get_next_cmd_seq(dev)
				rf_packet := build_identify_packet(device.device_mac, dev.master_mac, u8(try_rx_type), device.channel, seq)
				err := send_rf_packet(dev, rf_packet[:], device.channel, u8(try_rx_type), delay_ms = 0.5)
				if err != .None {
					return err
				}
			}
		}
		time.sleep(100 * time.Millisecond)
	}

	return .None
}

// Bind device to controller
bind_device :: proc(
	dev: ^LED_Device,
	device_mac: [6]u8,
	target_rx_type: u8,          // NEW rx_type to assign to device
	target_channel: u8,          // Master's channel (NEW channel for device)
	device_current_channel: u8,  // Device's CURRENT channel (where to send packet)
	device_current_rx_type: u8,  // Device's CURRENT rx_type (how to send packet)
) -> LED_Error {
	// Bind packet structure (from slv3.decompiled.cs:93163-93177 + 89081-89097):
	// - Packet byte 14 (target_rx_type) = NEW rx_type for device
	// - Packet byte 15 (target_channel) = Master's channel
	// - Packet byte 16 (sequence) = non-zero (bind)
	// BUT: Packet is sent ON device's CURRENT channel and rx_type

	// Send bind command multiple times for reliability
	for attempt in 0..<5 {
		// Build packet with TARGET rx_type and channel in the packet
		rf_packet := build_bind_packet(device_mac, dev.master_mac, target_rx_type, target_channel, sequence = 1)
		// Send on device's CURRENT rx_type and channel so it can receive!
		err := send_rf_packet(dev, rf_packet[:], device_current_channel, device_current_rx_type, delay_ms = 0.5)
		if err != .None {
			return err
		}
		time.sleep(100 * time.Millisecond)
	}

	return .None
}

// Unbind device from controller
unbind_device :: proc(dev: ^LED_Device, device_mac: [6]u8, rx_type: u8, channel: u8) -> LED_Error {
	// Unbind packet structure (from slv3.decompiled.cs:93179-93187):
	// - Packet byte 14 (target_rx_type) = 0
	// - Packet byte 8-13 (target_master_mac) = 00:00:00:00:00:00
	// - Packet byte 16 (sequence) = 0
	// BUT: Packet is sent ON device's CURRENT channel and rx_type (slv3:95925)

	empty_mac := [6]u8{0, 0, 0, 0, 0, 0}

	// Send unbind command multiple times for reliability
	for attempt in 0..<5 {
		// Build packet with empty_mac, rx_type=0, sequence=0
		rf_packet := build_bind_packet(device_mac, empty_mac, 0, channel, sequence = 0)
		// Send on device's CURRENT rx_type, not target rx_type
		err := send_rf_packet(dev, rf_packet[:], channel, rx_type, delay_ms = 0.5)
		if err != .None {
			return err
		}
		time.sleep(20 * time.Millisecond)
	}

	return .None
}

// Set LED effect on device
set_led_effect :: proc(
	dev: ^LED_Device,
	device_info: RF_Device_Info,
	rgb_data: []u8,
	total_frame: u16 = 1,
	allocator := context.allocator,
) -> LED_Error {
	// Determine LED count based on fan types
	leds_per_fan: int = 40  // Default SL
	for fan_type in device_info.fan_types {
		if fan_type >= 28 {
			leds_per_fan = 26  // TL fans
			break
		}
	}
	total_leds := u8(leds_per_fan * int(device_info.fan_num))

	// Compress RGB data
	compressed := make([]u8, len(rgb_data) * 2, allocator)  // Allocate enough space
	defer delete(compressed, allocator)

	compressed_size, result := tuz.compress_mem(rgb_data, compressed)
	if result != .STREAM_END {
		return .Compression_Failed
	}

	// Build LED effect packets
	rf_packets, err := build_led_effect_packets(
		compressed[:compressed_size],
		total_leds,
		device_info.mac,
		dev.master_mac,
		total_frame,
		allocator = allocator,
	)
	if err != .None {
		return err
	}
	defer delete(rf_packets, allocator)

	// Send metadata packet 4 times with 20ms delays
	for _ in 0..<4 {
		send_err := send_rf_packet(dev, rf_packets[0][:], device_info.channel, device_info.rx_type, delay_ms = 0.5)
		if send_err != .None {
			return send_err
		}
		time.sleep(20 * time.Millisecond)
	}

	// Send data packets once each
	for &data_packet in rf_packets[1:] {
		send_err := send_rf_packet(dev, data_packet[:], device_info.channel, device_info.rx_type, delay_ms = 0.5)
		if send_err != .None {
			return send_err
		}
	}

	return .None
}

// Save configuration to flash
save_config :: proc(dev: ^LED_Device, channel: u8) -> LED_Error {
	save_packet := build_save_config_packet(dev.master_mac)

	for i in 0..<3 {
		err := send_rf_packet(dev, save_packet[:], channel, 0xFF, delay_ms = 0.5)
		if err != .None {
			return err
		}
		if i < 2 {
			time.sleep(200 * time.Millisecond)
		}
	}

	return .None
}

// Initialize LED device
init_led_device :: proc(allocator := context.allocator) -> (dev: LED_Device, err: LED_Error) {
	// Initialize libusb
	ret := libusb_init(&dev.ctx)
	if ret != LIBUSB_SUCCESS {
		return dev, .USB_Init_Failed
	}

	// Get device list
	device_list: ^rawptr
	device_count := libusb_get_device_list(dev.ctx, &device_list)
	if device_count < 0 {
		libusb_exit(dev.ctx)
		return dev, .USB_Init_Failed
	}
	defer libusb_free_device_list(device_list, 1)

	// Find and open both TX and RX devices
	found_tx := false
	found_rx := false

	for i in 0..<device_count {
		device := mem.ptr_offset(device_list, i)^

		desc: Device_Descriptor
		ret = libusb_get_device_descriptor(device, &desc)
		if ret != LIBUSB_SUCCESS {
			continue
		}

		if desc.idVendor != VENDOR_ID {
			continue
		}

		// Check for TX device
		if desc.idProduct == PRODUCT_ID_TX && !found_tx {
			ret = libusb_open(device, &dev.rf_sender)
			if ret != LIBUSB_SUCCESS {
				continue
			}

			// Detach kernel driver if active
			if libusb_kernel_driver_active(dev.rf_sender, 0) == 1 {
				libusb_detach_kernel_driver(dev.rf_sender, 0)
			}

			// Set configuration and claim interface
			libusb_set_configuration(dev.rf_sender, 1)
			ret = libusb_claim_interface(dev.rf_sender, 0)
			if ret != LIBUSB_SUCCESS {
				libusb_close(dev.rf_sender)
				continue
			}

			dev.ep_out_tx = 0x01
			dev.ep_in_tx = 0x81
			found_tx = true
		}

		// Check for RX device
		if desc.idProduct == PRODUCT_ID_RX && !found_rx {
			ret = libusb_open(device, &dev.rf_receiver)
			if ret != LIBUSB_SUCCESS {
				continue
			}

			// Detach kernel driver if active
			if libusb_kernel_driver_active(dev.rf_receiver, 0) == 1 {
				libusb_detach_kernel_driver(dev.rf_receiver, 0)
			}

			// Set configuration and claim interface
			libusb_set_configuration(dev.rf_receiver, 1)
			ret = libusb_claim_interface(dev.rf_receiver, 0)
			if ret != LIBUSB_SUCCESS {
				libusb_close(dev.rf_receiver)
				continue
			}

			dev.ep_out_rx = 0x01
			dev.ep_in_rx = 0x81
			found_rx = true
		}

		if found_tx && found_rx {
			break
		}
	}

	if !found_tx || !found_rx {
		cleanup_led_device(&dev)
		return dev, .Device_Not_Found
	}

	// Try to query master device on different channels
	channels_to_try := make([]u8, 1 + len(VALID_CHANNELS), allocator)
	defer delete(channels_to_try, allocator)
	channels_to_try[0] = DEFAULT_CHANNEL
	copy(channels_to_try[1:], VALID_CHANNELS[:])

	for channel in channels_to_try {
		if query_master_device(&dev, channel) {
			dev.active_channel = channel
			dev.cmd_seq = 1  // Initialize command sequence counter
			fmt.printf("LED Device initialized\n")
			fmt.printf("  Master MAC: %02x:%02x:%02x:%02x:%02x:%02x\n",
				dev.master_mac[0], dev.master_mac[1], dev.master_mac[2],
				dev.master_mac[3], dev.master_mac[4], dev.master_mac[5])
			fmt.printf("  Channel: %d\n", dev.active_channel)
			fmt.printf("  Firmware Version: 0x%04x\n", dev.fw_version)
			return dev, .None
		}
	}

	cleanup_led_device(&dev)
	return dev, .Query_Failed
}

// Cleanup LED device
cleanup_led_device :: proc(dev: ^LED_Device) {
	if dev.rf_sender != nil {
		libusb_release_interface(dev.rf_sender, 0)
		libusb_close(dev.rf_sender)
		dev.rf_sender = nil
	}
	if dev.rf_receiver != nil {
		libusb_release_interface(dev.rf_receiver, 0)
		libusb_close(dev.rf_receiver)
		dev.rf_receiver = nil
	}
	if dev.ctx != nil {
		libusb_exit(dev.ctx)
		dev.ctx = nil
	}
}
