// ui_devices_panel.odin
// Devices panel management and IPC communication

package main

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"

// Initial device poll timeout callback
on_initial_poll :: proc "c" (user_data: rawptr) -> c.bool {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	// Poll devices from service
	poll_devices_from_service(state)

	// Rebuild device list
	rebuild_device_list(state)

	// Return false to run only once
	return false
}

// Build the device panel
build_device_panel :: proc(state: ^App_State) -> GtkWidget {
	box := auto_cast gtk_box_new(.VERTICAL, 12)
	gtk_widget_set_margin_start(box, 12)
	gtk_widget_set_margin_end(box, 12)
	gtk_widget_set_margin_top(box, 12)
	gtk_widget_set_margin_bottom(box, 12)

	// Header with title and select all button
	header_box := auto_cast gtk_box_new(.HORIZONTAL, 12)
	gtk_box_append(auto_cast box, header_box)

	// Title
	title := auto_cast gtk_label_new("Devices")
	gtk_label_set_markup(auto_cast title, "<span size='14000' weight='bold'>Devices</span>")
	gtk_label_set_xalign(auto_cast title, 0.0)
	gtk_widget_set_hexpand(title, true)
	gtk_box_append(auto_cast header_box, title)

	// Select All button
	select_all_btn := auto_cast gtk_button_new_with_label("Select All")
	gtk_widget_add_css_class(select_all_btn, "flat")
	g_signal_connect_data(
		select_all_btn,
		"clicked",
		auto_cast on_select_all_clicked,
		state,
		nil,
		0,
	)
	gtk_box_append(auto_cast header_box, select_all_btn)

	// Scrolled window for devices
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)
	gtk_widget_set_vexpand(scrolled, true)
	gtk_box_append(auto_cast box, scrolled)

	// Device list
	device_list := auto_cast gtk_box_new(.VERTICAL, 6)
	gtk_scrolled_window_set_child(auto_cast scrolled, device_list)

	// Store reference to device list for later updates
	state.device_list_box = auto_cast device_list

	// Add device cards
	rebuild_device_list(state)

	return box
}

// Rebuild device list from current state.devices
rebuild_device_list :: proc(state: ^App_State) {
	if state.device_list_box == nil {
		return
	}

	// Remove all children
	child := gtk_widget_get_first_child(auto_cast state.device_list_box)
	for child != nil {
		next_child := gtk_widget_get_next_sibling(child)
		gtk_box_remove(state.device_list_box, child)
		child = next_child
	}

	// Clear toggle buttons and selection arrays
	clear(&state.device_toggle_buttons)
	clear(&state.selected_devices)

	// Add new device cards
	device_idx := 0
	for device in state.devices {
		if device.rx_type == 255 do continue

		card := build_device_card(device, state, device_idx)
		gtk_box_append(state.device_list_box, card)

		append(&state.selected_devices, false)
		device_idx += 1
	}
}

// Select all button handler
on_select_all_clicked :: proc "c" (button: GtkButton, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	// Set batch mode flag to prevent individual identify calls
	state.batch_selecting = true

	// Build list of valid devices to identify
	devices_to_identify := make([dynamic]Device, 0, len(state.devices))
	defer delete(devices_to_identify)

	for device in state.devices {
		if device.rx_type == 255 do continue
		append(&devices_to_identify, device)
	}

	// Send identify requests for all devices at once (single IPC call)
	if len(devices_to_identify) > 0 {
		fmt.printfln("Identifying %d device(s)", len(devices_to_identify))
		send_identify_requests(devices_to_identify[:])
	}

	// Then toggle all devices on
	for toggle_btn in state.device_toggle_buttons {
		gtk_toggle_button_set_active(toggle_btn, true)
	}

	// Clear batch mode flag
	state.batch_selecting = false

	fmt.println("Selected all devices")
}

// Poll devices from service via socket
poll_devices_from_service :: proc(state: ^App_State) {
	// Get socket path
	socket_path, path_err := get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		return
	}

	// Connect to service (reconnect each time since service closes after each request)
	client, connect_err := connect_to_server(socket_path)
	defer close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		return
	}

	// Send Get_Devices request
	request := IPC_Message {
		type    = .Get_Devices,
		payload = "",
	}

	send_err := send_message(client.socket_fd, request)
	if send_err != .None {
		log_warn("Failed to send Get_Devices request: %v", send_err)
		return
	}

	// Receive response
	response, recv_err := receive_message(client.socket_fd)
	if recv_err != .None {
		log_warn("Failed to receive devices response: %v", recv_err)
		return
	}
	defer delete(response.payload)

	if response.type != .Devices_Response {
		log_warn("Unexpected response type: %v", response.type)
		return
	}

	// Parse JSON response
	// Convert string payload to byte slice
	payload_bytes := transmute([]u8)response.payload

	log_debug("Received payload (%d bytes): %s", len(payload_bytes), response.payload)

	cached_devices: []Device_Cache_Entry
	unmarshal_err := json.unmarshal(payload_bytes, &cached_devices)
	if unmarshal_err != nil {
		log_warn("Failed to unmarshal devices: %v", unmarshal_err)
		log_debug("Payload was: %s", response.payload)
		return
	}
	defer delete(cached_devices)

	// Convert to UI Device format
	delete(state.devices)
	state.devices = make([dynamic]Device)

	for cached_dev in cached_devices {
		// Calculate LED count based on fan types
		led_count := 0
		fan_count := int(cached_dev.fan_num)

		// Check each fan type to determine LEDs per fan
		for i in 0 ..< fan_count {
			fan_type := cached_dev.fan_types[i]

			// Determine LEDs for this fan based on its type
			if fan_type >= 20 && fan_type <= 26 {
				// SL v3 fans (20-26): 40 LEDs each
				led_count += 40
			} else if fan_type == 28 {
				// TL v2 fans: 26 LEDs each
				led_count += 26
			} else if fan_type == 65 {
				// LC217 LCD controller: 96 LEDs (240x240 display)
				led_count += 96
			} else {
				// Default fallback based on rx_type
				if cached_dev.rx_type == 1 {
					led_count += 40
				} else if cached_dev.rx_type == 2 || cached_dev.rx_type == 3 {
					led_count += 26
				}
			}
		}

		device := Device {
			mac_str       = cached_dev.mac_str,
			rx_type       = cached_dev.rx_type,
			channel       = cached_dev.channel,
			bound         = cached_dev.bound_to_us,
			led_count     = led_count,
			fan_count     = fan_count,
			dev_type_name = cached_dev.dev_type_name,
			fan_types     = cached_dev.fan_types,
			has_lcd       = cached_dev.has_lcd,
		}

		append(&state.devices, device)
	}

	log_info("Loaded %d devices from service", len(state.devices))
}

// Send identify requests for multiple devices to service
send_identify_requests :: proc(devices: []Device) {
	if len(devices) == 0 do return

	// Get socket path
	socket_path, path_err := get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		return
	}

	// Connect to service
	client, connect_err := connect_to_server(socket_path)
	defer close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		return
	}

	// Build identify request with all devices
	device_infos := make([dynamic]Identify_Device_Info, 0, len(devices))
	defer delete(device_infos)

	for device in devices {
		append(&device_infos, Identify_Device_Info{
			mac_str = device.mac_str,
			rx_type = device.rx_type,
			channel = device.channel,
		})
	}

	identify_req := Identify_Request{
		devices = device_infos[:],
	}

	// Marshal to JSON
	json_data, marshal_err := json.marshal(identify_req)
	if marshal_err != nil {
		log_warn("Failed to marshal identify request: %v", marshal_err)
		return
	}
	defer delete(json_data)

	// Send Identify_Device request
	request := IPC_Message{
		type = .Identify_Device,
		payload = string(json_data),
	}

	send_err := send_message(client.socket_fd, request)
	if send_err != .None {
		log_warn("Failed to send Identify_Device request: %v", send_err)
		return
	}

	log_debug("Identify request sent for %d device(s)", len(devices))
}

// Send identify request to service (single device convenience wrapper)
send_identify_request :: proc(device: Device) {
	devices := []Device{device}
	send_identify_requests(devices)
}
