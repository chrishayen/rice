package main

import "core:testing"
import "core:encoding/json"

// Test IPC_Message marshaling
@(test)
test_ipc_message_marshal :: proc(t: ^testing.T) {
	msg := IPC_Message{
		type = .Ping,
		payload = "test",
	}

	json_data, err := json.marshal(msg)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test IPC_Message unmarshaling
@(test)
test_ipc_message_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"type":7,"payload":"test"}`

	msg: IPC_Message
	err := json.unmarshal(transmute([]u8)json_str, &msg)
	defer delete(msg.payload)

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, msg.type == .Ping, "Message type should be Ping")
	testing.expect(t, msg.payload == "test", "Payload should match")
}

// Test Effect_Request marshaling
@(test)
test_effect_request_marshal :: proc(t: ^testing.T) {
	devices := []Effect_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8, led_count = 120},
	}

	req := Effect_Request{
		effect_name = "Static Color",
		color1 = {255, 0, 0},
		color2 = {0, 0, 255},
		brightness = 100,
		devices = devices,
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Effect_Request unmarshaling
@(test)
test_effect_request_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"effect_name":"Rainbow","color1":[255,0,0],"color2":[0,0,255],"brightness":80,"devices":[{"mac_str":"aa:bb:cc:dd:ee:ff","rx_type":1,"channel":8,"led_count":120}]}`

	req: Effect_Request
	err := json.unmarshal(transmute([]u8)json_str, &req)
	defer {
		delete(req.effect_name)
		for dev in req.devices {
			delete(dev.mac_str)
		}
		delete(req.devices)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, req.effect_name == "Rainbow", "Effect name should match")
	testing.expect(t, req.brightness == 80, "Brightness should match")
	testing.expect(t, len(req.devices) == 1, "Should have one device")
}

// Test Identify_Request marshaling
@(test)
test_identify_request_marshal :: proc(t: ^testing.T) {
	devices := []Identify_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8},
	}

	req := Identify_Request{devices = devices}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Bind_Request marshaling
@(test)
test_bind_request_marshal :: proc(t: ^testing.T) {
	devices := []Bind_Device_Info{
		{
			mac_str = "aa:bb:cc:dd:ee:ff",
			target_rx_type = 2,
			target_channel = 8,
			device_current_channel = 8,
			device_current_rx_type = 1,
		},
	}

	req := Bind_Request{devices = devices}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Unbind_Request marshaling
@(test)
test_unbind_request_marshal :: proc(t: ^testing.T) {
	devices := []Unbind_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8},
	}

	req := Unbind_Request{devices = devices}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Start_LCD_Playback_Request marshaling
@(test)
test_lcd_playback_request_marshal :: proc(t: ^testing.T) {
	transform := LCD_Transform{
		zoom_percent = 35.0,
		rotate_degrees = 0.0,
		flip_horizontal = false,
		rotation_speed = 0.0,
		rotation_direction = .CCW,
	}

	req := Start_LCD_Playback_Request{
		serial_number = "49a498b9431f0e66",
		fan_index = 0,
		frames_dir = "/home/user/.config/rice/lcd_frames/bad_apple",
		fps = 20.0,
		transform = transform,
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Start_LCD_Playback_Request unmarshaling
@(test)
test_lcd_playback_request_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"serial_number":"49a498b9431f0e66","fan_index":0,"frames_dir":"/path/to/frames","fps":20.0,"transform":{"zoom_percent":35.0,"rotate_degrees":0.0,"flip_horizontal":false,"rotation_speed":0.0,"rotation_direction":0}}`

	req: Start_LCD_Playback_Request
	err := json.unmarshal(transmute([]u8)json_str, &req)
	defer {
		delete(req.serial_number)
		delete(req.frames_dir)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, req.serial_number == "49a498b9431f0e66", "Serial number should match")
	testing.expect(t, req.fan_index == 0, "Fan index should match")
	testing.expect(t, req.fps == 20.0, "FPS should match")
	testing.expect(t, req.transform.zoom_percent == 35.0, "Zoom should match")
}

// Test LCD_Transform marshaling with enum
@(test)
test_lcd_transform_marshal :: proc(t: ^testing.T) {
	transform := LCD_Transform{
		zoom_percent = 50.0,
		rotate_degrees = 90.0,
		flip_horizontal = true,
		rotation_speed = 1.5,
		rotation_direction = .CW,
	}

	json_data, err := json.marshal(transform)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test LCD_Transform unmarshaling with enum
@(test)
test_lcd_transform_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"zoom_percent":50.0,"rotate_degrees":90.0,"flip_horizontal":true,"rotation_speed":1.5,"rotation_direction":1}`

	transform: LCD_Transform
	err := json.unmarshal(transmute([]u8)json_str, &transform)

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, transform.zoom_percent == 50.0, "Zoom should match")
	testing.expect(t, transform.rotation_direction == .CW, "Direction should be CW")
}

// Test Status_Info marshaling
@(test)
test_status_info_marshal :: proc(t: ^testing.T) {
	status := Status_Info{
		running = true,
		master_mac = {0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff},
		active_channel = 8,
		fw_version = 0x0100,
		device_count = 3,
	}

	json_data, err := json.marshal(status)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test Device_Info marshaling
@(test)
test_device_info_marshal :: proc(t: ^testing.T) {
	device := Device_Info{
		mac_str = "aa:bb:cc:dd:ee:ff",
		dev_type_name = "SLV3Fan_25",
		channel = 8,
		bound_to_us = true,
		fan_num = 4,
		rx_type = 1,
		led_count = 120,
	}

	json_data, err := json.marshal(device)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test empty payload message
@(test)
test_empty_payload_message :: proc(t: ^testing.T) {
	msg := IPC_Message{
		type = .Ping,
		payload = "",
	}

	json_data, err := json.marshal(msg)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling empty payload should succeed")

	// Unmarshal it back
	unmarshaled: IPC_Message
	err2 := json.unmarshal(json_data, &unmarshaled)
	defer delete(unmarshaled.payload)

	testing.expect(t, err2 == nil, "Unmarshaling should succeed")
	testing.expect(t, unmarshaled.type == .Ping, "Type should match")
}

// Test message type enum values
@(test)
test_message_type_enum :: proc(t: ^testing.T) {
	// Ensure message types are distinct
	testing.expect(t, Message_Type.Get_Devices != Message_Type.Set_Effect, "Message types should be distinct")
	testing.expect(t, Message_Type.Ping != Message_Type.Pong, "Ping and Pong should be different")
	testing.expect(t, Message_Type.Start_LCD_Playback != Message_Type.LCD_Playback_Started, "LCD types should be different")
}

// Test Identify_Request unmarshaling
@(test)
test_identify_request_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"devices":[{"mac_str":"aa:bb:cc:dd:ee:ff","rx_type":1,"channel":8}]}`

	req: Identify_Request
	err := json.unmarshal(transmute([]u8)json_str, &req)
	defer {
		for dev in req.devices {
			delete(dev.mac_str)
		}
		delete(req.devices)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, len(req.devices) == 1, "Should have one device")
	testing.expect(t, req.devices[0].mac_str == "aa:bb:cc:dd:ee:ff", "MAC should match")
	testing.expect(t, req.devices[0].rx_type == 1, "RX type should match")
	testing.expect(t, req.devices[0].channel == 8, "Channel should match")
}

// Test Bind_Request unmarshaling
@(test)
test_bind_request_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"devices":[{"mac_str":"aa:bb:cc:dd:ee:ff","target_rx_type":2,"target_channel":8,"device_current_channel":8,"device_current_rx_type":1}]}`

	req: Bind_Request
	err := json.unmarshal(transmute([]u8)json_str, &req)
	defer {
		for dev in req.devices {
			delete(dev.mac_str)
		}
		delete(req.devices)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, len(req.devices) == 1, "Should have one device")
	testing.expect(t, req.devices[0].target_rx_type == 2, "Target RX type should match")
	testing.expect(t, req.devices[0].target_channel == 8, "Target channel should match")
}

// Test Unbind_Request unmarshaling
@(test)
test_unbind_request_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"devices":[{"mac_str":"aa:bb:cc:dd:ee:ff","rx_type":1,"channel":8}]}`

	req: Unbind_Request
	err := json.unmarshal(transmute([]u8)json_str, &req)
	defer {
		for dev in req.devices {
			delete(dev.mac_str)
		}
		delete(req.devices)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, len(req.devices) == 1, "Should have one device")
	testing.expect(t, req.devices[0].mac_str == "aa:bb:cc:dd:ee:ff", "MAC should match")
}

// Test Device_Info unmarshaling
@(test)
test_device_info_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"mac_str":"aa:bb:cc:dd:ee:ff","dev_type_name":"SLV3Fan_25","channel":8,"bound_to_us":true,"fan_num":4,"rx_type":1,"led_count":120}`

	device: Device_Info
	err := json.unmarshal(transmute([]u8)json_str, &device)
	defer {
		delete(device.mac_str)
		delete(device.dev_type_name)
	}

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, device.mac_str == "aa:bb:cc:dd:ee:ff", "MAC should match")
	testing.expect(t, device.dev_type_name == "SLV3Fan_25", "Device type should match")
	testing.expect(t, device.channel == 8, "Channel should match")
	testing.expect(t, device.bound_to_us == true, "Bound status should match")
	testing.expect(t, device.fan_num == 4, "Fan number should match")
	testing.expect(t, device.led_count == 120, "LED count should match")
}

// Test Status_Info unmarshaling
@(test)
test_status_info_unmarshal :: proc(t: ^testing.T) {
	json_str := `{"running":true,"master_mac":[170,187,204,221,238,255],"active_channel":8,"fw_version":256,"device_count":3}`

	status: Status_Info
	err := json.unmarshal(transmute([]u8)json_str, &status)

	testing.expect(t, err == nil, "Unmarshaling should succeed")
	testing.expect(t, status.running == true, "Running status should match")
	testing.expect(t, status.master_mac[0] == 0xaa, "MAC byte 0 should match")
	testing.expect(t, status.master_mac[5] == 0xff, "MAC byte 5 should match")
	testing.expect(t, status.active_channel == 8, "Active channel should match")
	testing.expect(t, status.fw_version == 0x0100, "Firmware version should match")
	testing.expect(t, status.device_count == 3, "Device count should match")
}

// Test multiple devices in Effect_Request
@(test)
test_effect_request_multiple_devices :: proc(t: ^testing.T) {
	devices := []Effect_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8, led_count = 120},
		{mac_str = "11:22:33:44:55:66", rx_type = 2, channel = 9, led_count = 60},
	}

	req := Effect_Request{
		effect_name = "Rainbow",
		color1 = {255, 128, 0},
		color2 = {0, 128, 255},
		brightness = 75,
		devices = devices,
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling should succeed")

	// Unmarshal back
	unmarshaled: Effect_Request
	err2 := json.unmarshal(json_data, &unmarshaled)
	defer {
		delete(unmarshaled.effect_name)
		for dev in unmarshaled.devices {
			delete(dev.mac_str)
		}
		delete(unmarshaled.devices)
	}

	testing.expect(t, err2 == nil, "Unmarshaling should succeed")
	testing.expect(t, len(unmarshaled.devices) == 2, "Should have two devices")
	testing.expect(t, unmarshaled.devices[1].led_count == 60, "Second device LED count should match")
}

// Test LCD rotation directions
@(test)
test_lcd_rotation_direction :: proc(t: ^testing.T) {
	testing.expect(t, LCD_Rotation_Direction.CCW != LCD_Rotation_Direction.CW, "Rotation directions should be distinct")

	// Test CCW (0)
	transform_ccw := LCD_Transform{rotation_direction = .CCW}
	json_ccw, err := json.marshal(transform_ccw)
	defer delete(json_ccw)
	testing.expect(t, err == nil, "CCW marshaling should succeed")

	// Test CW (1)
	transform_cw := LCD_Transform{rotation_direction = .CW}
	json_cw, err2 := json.marshal(transform_cw)
	defer delete(json_cw)
	testing.expect(t, err2 == nil, "CW marshaling should succeed")
}

// Test default LCD transform values
@(test)
test_lcd_transform_defaults :: proc(t: ^testing.T) {
	transform := LCD_Transform{zoom_percent = 35.0}

	testing.expect(t, transform.zoom_percent == 35.0, "Zoom should be 35")
	testing.expect(t, transform.rotate_degrees == 0.0, "Rotate degrees should default to 0")
	testing.expect(t, transform.flip_horizontal == false, "Flip should default to false")
	testing.expect(t, transform.rotation_speed == 0.0, "Rotation speed should default to 0")
	testing.expect(t, transform.rotation_direction == .CCW, "Direction should default to CCW")
}

// Test zero brightness in Effect_Request
@(test)
test_effect_request_zero_brightness :: proc(t: ^testing.T) {
	devices := []Effect_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8, led_count = 120},
	}

	req := Effect_Request{
		effect_name = "Off",
		color1 = {0, 0, 0},
		color2 = {0, 0, 0},
		brightness = 0,
		devices = devices,
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling zero brightness should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test max brightness in Effect_Request
@(test)
test_effect_request_max_brightness :: proc(t: ^testing.T) {
	devices := []Effect_Device_Info{
		{mac_str = "aa:bb:cc:dd:ee:ff", rx_type = 1, channel = 8, led_count = 120},
	}

	req := Effect_Request{
		effect_name = "Static Color",
		color1 = {255, 255, 255},
		color2 = {255, 255, 255},
		brightness = 255,
		devices = devices,
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling max brightness should succeed")

	unmarshaled: Effect_Request
	err2 := json.unmarshal(json_data, &unmarshaled)
	defer {
		delete(unmarshaled.effect_name)
		for dev in unmarshaled.devices {
			delete(dev.mac_str)
		}
		delete(unmarshaled.devices)
	}

	testing.expect(t, err2 == nil, "Unmarshaling should succeed")
	testing.expect(t, unmarshaled.brightness == 255, "Brightness should be 255")
}

// Test empty devices array
@(test)
test_effect_request_empty_devices :: proc(t: ^testing.T) {
	req := Effect_Request{
		effect_name = "Static Color",
		color1 = {255, 0, 0},
		color2 = {0, 0, 255},
		brightness = 100,
		devices = []Effect_Device_Info{},
	}

	json_data, err := json.marshal(req)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling empty devices should succeed")

	unmarshaled: Effect_Request
	err2 := json.unmarshal(json_data, &unmarshaled)
	defer {
		delete(unmarshaled.effect_name)
		delete(unmarshaled.devices)
	}

	testing.expect(t, err2 == nil, "Unmarshaling should succeed")
	testing.expect(t, len(unmarshaled.devices) == 0, "Devices should be empty")
}

// Test all message types can be marshaled
@(test)
test_all_message_types :: proc(t: ^testing.T) {
	message_types := []Message_Type{
		.Get_Devices, .Set_Effect, .Get_Status, .Identify_Device,
		.Bind_Device, .Unbind_Device, .Start_LCD_Playback, .Ping,
		.Devices_Response, .Status_Response, .Effect_Applied,
		.Identify_Success, .Bind_Success, .Unbind_Success,
		.LCD_Playback_Started, .Pong, .Error,
	}

	for msg_type in message_types {
		msg := IPC_Message{
			type = msg_type,
			payload = "test",
		}

		json_data, err := json.marshal(msg)
		defer delete(json_data)

		testing.expect(t, err == nil, "Marshaling should succeed for all message types")
		testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
	}
}
