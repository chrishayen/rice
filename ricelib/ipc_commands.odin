// ipc_commands.odin
// IPC protocol definitions for service-UI communication
package ricelib

// Message types for IPC communication
Message_Type :: enum {
	// Client -> Service
	Get_Devices,
	Set_Effect,
	Get_Status,
	Identify_Device,
	Ping,

	// Service -> Client
	Devices_Response,
	Status_Response,
	Effect_Applied,
	Identify_Success,
	Pong,
	Error,
}

// IPC Message structure
IPC_Message :: struct {
	type:    Message_Type,
	payload: string, // JSON-encoded payload
}

Device_Info :: struct {
	mac_str:       string,
	dev_type_name: string,
	channel:       u8,
	bound_to_us:   bool,
	fan_num:       u8,
	rx_type:       u8,
	led_count:     int,
}

Effect_Request :: struct {
	effect_name: string,
	color1:      [3]u8,
	color2:      [3]u8,
	brightness:  u8,
}

Identify_Request :: struct {
	mac_str: string,
	rx_type: u8,
	channel: u8,
}

Status_Info :: struct {
	running:         bool,
	master_mac:      [6]u8,
	active_channel:  u8,
	fw_version:      u16,
	device_count:    int,
}
