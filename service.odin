// service.odin
// Fan Control Service - Runs as a daemon/service
package main

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import tuz "libs/tinyuz"

Device_Packet_Info :: struct {
	channel:     u8,
	rx_type:     u8,
	mac_str:     string,  // Deep copied for logging
	rf_packets:  [][240]u8,
	total_frame: u16,
}

Service_State :: struct {
	led_device:            LED_Device,
	socket_server:         Socket_Server,
	running:               bool,
	poll_interval_seconds: int,
	devices_cache:         [dynamic]RF_Device_Info,
	devices_mutex:         sync.Mutex,
	master_poll_thread:    ^thread.Thread,
	device_query_thread:   ^thread.Thread,
	effect_broadcast_thread: ^thread.Thread,
	epoll_fd:              c.int,
	// Current effect packets for continuous broadcast
	current_effect_packets: [dynamic]Device_Packet_Info,
	effect_packets_mutex:  sync.Mutex,
	// LCD playback
	lcd_playback:          ^LCD_Playback_State,
}

run_service :: proc() {
	log_info("Starting Fan Control Service...")
	log_debug("Service mode activated")

	// Initialize config directory
	log_debug("Initializing config directory...")
	config_err := init_config_dir()
	if config_err != .None {
		log_error("Failed to initialize config directory: %v", config_err)
		os.exit(1)
	}

	config_dir, _ := get_config_dir()
	defer delete(config_dir)
	log_info("Config directory: %s", config_dir)

	// Get socket path
	socket_path, socket_err := get_socket_path()
	defer delete(socket_path)

	if socket_err != .None {
		log_error("Failed to get socket path: %v", socket_err)
		os.exit(1)
	}

	log_info("Socket path: %s", socket_path)

	// Clean up old socket file if it exists
	if !cleanup_socket() {
		log_warn("Failed to clean up old socket file")
	}

	state: Service_State
	state.running = true
	state.poll_interval_seconds = 10
	state.devices_cache = make([dynamic]RF_Device_Info)
	defer delete(state.devices_cache)

	// Initialize LED device
	led_dev, err := init_led_device()
	if err != .None {
		log_error("Failed to initialize LED device: %v", err)
		log_error("Make sure USB devices are connected and you have proper permissions")
		log_debug("Exiting with error code 1")
		os.exit(1)
	}
	defer cleanup_led_device(&state.led_device)

	state.led_device = led_dev
	log_info("LED device initialized successfully")
	log_debug(
		"Master MAC: %02x:%02x:%02x:%02x:%02x:%02x",
		state.led_device.master_mac[0],
		state.led_device.master_mac[1],
		state.led_device.master_mac[2],
		state.led_device.master_mac[3],
		state.led_device.master_mac[4],
		state.led_device.master_mac[5],
	)
	log_debug("Active channel: %d", state.led_device.active_channel)
	log_debug("Firmware version: 0x%04x", state.led_device.fw_version)

	// Create socket server
	log_info("Creating socket server...")
	server, server_err := create_socket_server(socket_path)
	if server_err != .None {
		log_error("Failed to create socket server: %v", server_err)
		os.exit(1)
	}
	defer close_server(&state.socket_server)

	state.socket_server = server
	log_info("Socket server listening on %s", socket_path)

	// Create epoll instance
	log_debug("Creating epoll instance...")
	state.epoll_fd = epoll_create1(EPOLL_CLOEXEC)
	if state.epoll_fd < 0 {
		log_error("Failed to create epoll instance")
		os.exit(1)
	}
	defer close(state.epoll_fd)

	// Add server socket to epoll
	event: epoll_event
	event.events = EPOLLIN
	event.data.fd = state.socket_server.socket_fd
	if epoll_ctl(state.epoll_fd, EPOLL_CTL_ADD, state.socket_server.socket_fd, &event) < 0 {
		log_error("Failed to add socket to epoll")
		os.exit(1)
	}
	log_debug("Socket added to epoll")

	// Start master polling thread (queries master every 1 second like L-Connect)
	log_debug("Starting master polling thread...")
	state.master_poll_thread = thread.create_and_start_with_data(&state, master_polling_thread)

	// Start device query thread
	log_debug("Starting device query thread...")
	state.device_query_thread = thread.create_and_start_with_data(&state, device_query_thread)

	// Start effect broadcast thread
	log_debug("Starting effect broadcast thread...")
	state.effect_broadcast_thread = thread.create_and_start_with_data(&state, effect_broadcast_thread)

	// Initialize LCD playback (hardcoded test for first LCD device)
	log_debug("Initializing LCD playback...")
	init_lcd_playback_test(&state)

	log_info("Service initialized successfully")
	log_info("Press Ctrl+C to stop")
	log_debug("Poll interval: %d seconds", state.poll_interval_seconds)

	// Main service loop - use epoll to wait for connections
	MAX_EVENTS :: 10
	events: [MAX_EVENTS]epoll_event

	for state.running {
		// Wait for events (timeout 1 second to check running flag)
		num_events := epoll_wait(state.epoll_fd, &events[0], MAX_EVENTS, 1000)

		if num_events < 0 {
			log_warn("epoll_wait error")
			continue
		}

		// Process events
		for i in 0 ..< num_events {
			if events[i].data.fd == state.socket_server.socket_fd {
				// Server socket ready - accept connection
				client_fd, accept_err := accept_connection(&state.socket_server)
				if accept_err == .None {
					log_info("Client connected")

					// Handle the request
					handle_socket_message(client_fd, &state)

					// Close client connection
					close(client_fd)
					log_debug("Client disconnected")
				}
			}
		}
	}

	log_info("Service stopped")
	log_debug("Cleanup complete")

	// Cleanup LCD playback
	if state.lcd_playback != nil {
		log_debug("Stopping LCD playback...")
		destroy_lcd_playback(state.lcd_playback)
	}

	// Wait for threads to finish
	if state.master_poll_thread != nil {
		thread.destroy(state.master_poll_thread)
	}
	if state.device_query_thread != nil {
		thread.destroy(state.device_query_thread)
	}
	if state.effect_broadcast_thread != nil {
		thread.destroy(state.effect_broadcast_thread)
	}
}

// Master polling thread - queries master device every 1 second (like L-Connect)
master_polling_thread :: proc(data: rawptr) {
	state := cast(^Service_State)data

	log_debug("Master polling thread started")

	for state.running {
		// Query master device to keep it alive and get updated clock
		if query_master_device(&state.led_device, state.led_device.active_channel) {
			log_debug(
				"Master poll: MAC=%02x:%02x:%02x:%02x:%02x:%02x, Clock=%dms, FW=0x%04x",
				state.led_device.master_mac[0],
				state.led_device.master_mac[1],
				state.led_device.master_mac[2],
				state.led_device.master_mac[3],
				state.led_device.master_mac[4],
				state.led_device.master_mac[5],
				state.led_device.sys_clock,
				state.led_device.fw_version,
			)
		} else {
			log_warn("Failed to query master device")
		}

		// Sleep for 1 second
		time.sleep(1 * time.Second)
	}

	log_debug("Master polling thread stopped")
}

// Update device cache immediately (called after bind/unbind operations)
refresh_device_cache :: proc(state: ^Service_State) {
	log_debug("Refreshing device cache...")

	// Query devices
	MAX_QUERY_ATTEMPTS :: 5
	all_devices := make(map[string]RF_Device_Info)
	defer delete(all_devices)

	for attempt in 0..<MAX_QUERY_ATTEMPTS {
		devices, query_err := query_devices(&state.led_device)
		if query_err == .None {
			// Deduplicate devices by MAC address
			for device in devices {
				if device.rx_type != 255 {  // Skip master
					all_devices[device.mac_str] = device
				}
			}
		}

		// If we found devices, we can stop early
		if len(all_devices) > 0 {
			log_debug("Found devices on attempt %d/%d", attempt + 1, MAX_QUERY_ATTEMPTS)
			break
		}

		// Small delay between attempts
		time.sleep(100 * time.Millisecond)
	}

	// Convert map to slice for cache
	if len(all_devices) > 0 {
		devices_slice := make([dynamic]RF_Device_Info, 0, len(all_devices))
		defer delete(devices_slice)

		for _, device in all_devices {
			append(&devices_slice, device)
		}

		log_debug("Updating cache with %d devices", len(devices_slice))

		// Lock mutex to update cache
		sync.mutex_lock(&state.devices_mutex)
		{
			// Update cache - copy devices to cache
			clear(&state.devices_cache)
			for device in devices_slice {
				append(&state.devices_cache, device)
			}
		}
		sync.mutex_unlock(&state.devices_mutex)

		// Save to JSON cache
		cache_err := save_device_cache(devices_slice[:])
		if cache_err != .None {
			log_warn("Failed to save device cache: %v", cache_err)
		} else {
			log_debug("Device cache refreshed and saved")
		}
	}
}

// Device query thread - queries devices periodically and updates cache
device_query_thread :: proc(data: rawptr) {
	state := cast(^Service_State)data

	log_debug("Device query thread started")

	for state.running {
		log_debug("Querying devices...")

		// Try multiple times to catch devices as they transmit (like Python implementation)
		// Devices only appear when they're actively transmitting status
		MAX_QUERY_ATTEMPTS :: 10
		all_devices := make(map[string]RF_Device_Info)
		defer delete(all_devices)

		for attempt in 0..<MAX_QUERY_ATTEMPTS {
			devices, query_err := query_devices(&state.led_device)
			if query_err == .None {
				// Deduplicate devices by MAC address
				for device in devices {
					if device.rx_type != 255 {  // Skip master
						all_devices[device.mac_str] = device
					}
				}
			}

			// If we found devices, we can stop early
			if len(all_devices) > 0 {
				log_debug("Found devices on attempt %d/%d", attempt + 1, MAX_QUERY_ATTEMPTS)
				break
			}

			// Small delay between attempts
			time.sleep(100 * time.Millisecond)
		}

		// Convert map to slice for cache
		if len(all_devices) > 0 {
			devices_slice := make([dynamic]RF_Device_Info, 0, len(all_devices))
			defer delete(devices_slice)

			for _, device in all_devices {
				append(&devices_slice, device)
			}

			log_info("Found %d devices:", len(devices_slice))

			// Lock mutex to update cache
			sync.mutex_lock(&state.devices_mutex)
			{
				// Update cache - copy devices to cache
				clear(&state.devices_cache)
				for device in devices_slice {
					append(&state.devices_cache, device)
				}
			}
			sync.mutex_unlock(&state.devices_mutex)

			// Save to JSON cache
			cache_err := save_device_cache(devices_slice[:])
			if cache_err != .None {
				log_warn("Failed to save device cache: %v", cache_err)
			} else {
				log_debug("Device cache saved to JSON")
			}

			for device, idx in devices_slice {
				log_info(
					"  [%d] %s (%s) on channel %d - Bound: %v",
					idx + 1,
					device.mac_str,
					device.dev_type_name,
					device.channel,
					device.bound_to_us,
				)

				log_debug("    Device details:")
				log_debug("      RX Type: %d", device.rx_type)
				log_debug("      Fan count: %d", device.fan_num)
				log_debug("      Timestamp: %d", device.timestamp)
				log_debug(
					"      Fan types: [%d, %d, %d, %d]",
					device.fan_types[0],
					device.fan_types[1],
					device.fan_types[2],
					device.fan_types[3],
				)
				log_debug("      Command sequence: %d", device.cmd_seq)
				log_debug("      Master MAC: %s", device.master_mac_str)
			}
		} else {
			log_warn("Failed to find any devices after %d attempts", MAX_QUERY_ATTEMPTS)
		}

		// Sleep for poll interval
		time.sleep(time.Duration(state.poll_interval_seconds) * time.Second)
	}

	log_debug("Device query thread stopped")
}

// Effect broadcast thread - continuously sends current effect (like L-Connect)
effect_broadcast_thread :: proc(data: rawptr) {
	state := cast(^Service_State)data

	log_debug("Effect broadcast thread started")

	iteration := 0
	for state.running {
		// Get current effect packets (with mutex)
		sync.lock(&state.effect_packets_mutex)
		has_packets := len(state.current_effect_packets) > 0

		if has_packets {
			// Make a copy of packets to send
			packets_to_send := make([dynamic]Device_Packet_Info, len(state.current_effect_packets))
			defer delete(packets_to_send)

			for dp, i in state.current_effect_packets {
				// Deep copy packets
				rf_packets_copy := make([][240]u8, len(dp.rf_packets))
				for pkt, j in dp.rf_packets {
					rf_packets_copy[j] = pkt
				}

				packets_to_send[i] = Device_Packet_Info{
					channel = dp.channel,
					rx_type = dp.rx_type,
					mac_str = strings.clone(dp.mac_str),  // Deep copy string
					rf_packets = rf_packets_copy,
					total_frame = dp.total_frame,
				}
			}
			sync.unlock(&state.effect_packets_mutex)

			// Send packets to all devices
			for &dp in packets_to_send {
				// Send metadata packet 4 times with 20ms delays
				for _ in 0..<4 {
					send_rf_packet(&state.led_device, dp.rf_packets[0][:], dp.channel, dp.rx_type, delay_ms = 0.5)
					time.sleep(20 * time.Millisecond)
				}

				// Send data packets once each
				for &data_packet in dp.rf_packets[1:] {
					send_rf_packet(&state.led_device, data_packet[:], dp.channel, dp.rx_type, delay_ms = 0.5)
				}

				// Clean up deep copied data
				delete(dp.mac_str)
				delete(dp.rf_packets)
			}

			iteration += 1
			if iteration % 10 == 0 {
				log_debug("Effect broadcast: sent %d iterations", iteration)
			}
		} else {
			sync.unlock(&state.effect_packets_mutex)
		}

		// Sleep 100ms between iterations (matches Python line 1881)
		time.sleep(100 * time.Millisecond)
	}

	log_debug("Effect broadcast thread stopped")
}

// Handle socket message from client
handle_socket_message :: proc(client_fd: c.int, state: ^Service_State) {
	// Receive message
	msg, recv_err := receive_message(client_fd)
	if recv_err != .None {
		log_warn("Failed to receive message: %v", recv_err)
		return
	}
	defer delete(msg.payload)

	log_debug("Received message type: %v", msg.type)

	// Handle message based on type
	#partial switch msg.type {
	case .Get_Devices:
		log_debug("Handling Get_Devices request")

		// Load from cache
		cached_devices, cache_err := load_device_cache()
		defer delete(cached_devices)

		if cache_err != .None {
			log_warn("Failed to load device cache: %v", cache_err)

			// Send error response
			error_msg := IPC_Message {
				type    = .Error,
				payload = "Failed to load device cache",
			}
			send_message(client_fd, error_msg)
			return
		}

		// Marshal devices to JSON
		json_data, marshal_err := json.marshal(cached_devices)
		if marshal_err != nil {
			log_warn("Failed to marshal devices: %v", marshal_err)

			error_msg := IPC_Message {
				type    = .Error,
				payload = "Failed to marshal devices",
			}
			send_message(client_fd, error_msg)
			return
		}
		defer delete(json_data)

		log_debug("Marshaled JSON (%d bytes): %s", len(json_data), string(json_data))

		// Send response
		response := IPC_Message {
			type    = .Devices_Response,
			payload = string(json_data),
		}

		send_err := send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send devices response: %v", send_err)
		} else {
			log_debug("Sent %d devices to client", len(cached_devices))
		}

		// Build list of devices to identify
		devices_to_identify := make([dynamic]Device_Identify_Info, 0, len(cached_devices))
		defer delete(devices_to_identify)

		for device in cached_devices {
			if device.rx_type == 255 do continue

			// Parse MAC address string
			mac_parts := strings.split(device.mac_str, ":")
			defer delete(mac_parts)

			if len(mac_parts) != 6 {
				log_warn("Invalid MAC address format: %s", device.mac_str)
				continue
			}

			device_mac: [6]u8
			parse_failed := false
			for part, i in mac_parts {
				val, ok := strconv.parse_u64_of_base(part, 16)
				if !ok {
					log_warn("Invalid MAC address byte: %s", part)
					parse_failed = true
					break
				}
				device_mac[i] = u8(val)
			}

			if parse_failed do continue

			append(&devices_to_identify, Device_Identify_Info{
				device_mac = device_mac,
				rx_type = device.rx_type,
				channel = device.channel,
			})
		}

		// Identify all devices simultaneously
		if len(devices_to_identify) > 0 {
			log_info("Identifying %d devices simultaneously...", len(devices_to_identify))
			identify_err := identify_devices_batch(&state.led_device, devices_to_identify[:])
			if identify_err != .None {
				log_warn("Failed to identify devices: %v", identify_err)
			} else {
				log_info("All devices identified successfully")
			}
		}

	case .Get_Status:
		log_debug("Handling Get_Status request")

		// Build status info (lock mutex to read device count)
		sync.mutex_lock(&state.devices_mutex)
		device_count := len(state.devices_cache)
		sync.mutex_unlock(&state.devices_mutex)

		status := Status_Info {
			running        = state.running,
			master_mac     = state.led_device.master_mac,
			active_channel = state.led_device.active_channel,
			fw_version     = state.led_device.fw_version,
			device_count   = device_count,
		}

		// Marshal to JSON
		json_data, marshal_err := json.marshal(status)
		if marshal_err != nil {
			log_warn("Failed to marshal status: %v", marshal_err)
			return
		}
		defer delete(json_data)

		// Send response
		response := IPC_Message {
			type    = .Status_Response,
			payload = string(json_data),
		}

		send_err := send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send status response: %v", send_err)
		} else {
			log_debug("Sent status to client")
		}

	case .Identify_Device:
		log_debug("Handling Identify_Device request")

		// Parse identify request from JSON
		identify_req: Identify_Request
		payload_bytes := transmute([]u8)msg.payload
		unmarshal_err := json.unmarshal(payload_bytes, &identify_req)
		if unmarshal_err != nil {
			log_warn("Failed to unmarshal identify request: %v", unmarshal_err)
			return
		}
		defer delete(identify_req.devices)

		log_info("Identifying %d device(s)", len(identify_req.devices))

		// Build batch identify list
		devices_to_identify := make([dynamic]Device_Identify_Info, 0, len(identify_req.devices))
		defer delete(devices_to_identify)

		for device_info in identify_req.devices {
			log_info(
				"Identifying device: %s (rx_type=%d, channel=%d)",
				device_info.mac_str,
				device_info.rx_type,
				device_info.channel,
			)

			// Parse MAC address
			mac_parts := strings.split(device_info.mac_str, ":")
			defer delete(mac_parts)

			if len(mac_parts) != 6 {
				log_warn("Invalid MAC address format: %s", device_info.mac_str)
				continue
			}

			device_mac: [6]u8
			for part, i in mac_parts {
				val, ok := strconv.parse_u64_of_base(part, 16)
				if !ok {
					log_warn("Invalid MAC address byte: %s", part)
					continue
				}
				device_mac[i] = u8(val)
			}

			append(&devices_to_identify, Device_Identify_Info{
				device_mac = device_mac,
				rx_type = device_info.rx_type,
				channel = device_info.channel,
			})
		}

		// Identify all devices simultaneously using batch method
		if len(devices_to_identify) > 0 {
			log_info("Identifying %d devices simultaneously...", len(devices_to_identify))
			identify_err := identify_devices_batch(&state.led_device, devices_to_identify[:])
			if identify_err != .None {
				log_warn("Failed to identify devices: %v", identify_err)
			} else {
				log_info("All devices identified successfully")
			}
		}

		// No response - this is fire-and-forget

	case .Bind_Device:
		log_debug("Handling Bind_Device request")

		// Parse bind request from JSON
		bind_req: Bind_Request
		payload_bytes := transmute([]u8)msg.payload
		unmarshal_err := json.unmarshal(payload_bytes, &bind_req)
		if unmarshal_err != nil {
			log_warn("Failed to unmarshal bind request: %v", unmarshal_err)
			return
		}
		defer delete(bind_req.devices)

		log_info("Binding %d device(s)", len(bind_req.devices))

		// Bind each device
		success_count := 0
		for device_info in bind_req.devices {
			log_info(
				"Binding device: %s (target_rx_type=%d, target_channel=%d, current_rx_type=%d, current_channel=%d)",
				device_info.mac_str,
				device_info.target_rx_type,
				device_info.target_channel,
				device_info.device_current_rx_type,
				device_info.device_current_channel,
			)

			// Parse MAC address
			mac_parts := strings.split(device_info.mac_str, ":")
			defer delete(mac_parts)

			if len(mac_parts) != 6 {
				log_warn("Invalid MAC address format: %s", device_info.mac_str)
				continue
			}

			device_mac: [6]u8
			parse_ok := true
			for part, i in mac_parts {
				val, ok := strconv.parse_u64_of_base(part, 16)
				if !ok {
					log_warn("Invalid MAC address byte: %s", part)
					parse_ok = false
					break
				}
				device_mac[i] = u8(val)
			}

			if !parse_ok do continue

			// Bind the device
			bind_err := bind_device(
				&state.led_device,
				device_mac,
				device_info.target_rx_type,
				device_info.target_channel,
				device_info.device_current_channel,
				device_info.device_current_rx_type,
			)
			if bind_err != .None {
				log_warn("Failed to bind device %s: %v", device_info.mac_str, bind_err)
			} else {
				log_info("Device %s bound successfully", device_info.mac_str)
				success_count += 1
			}
		}

		// Refresh device cache to reflect new bind status
		refresh_device_cache(state)

		// Send success response
		response := IPC_Message {
			type    = .Bind_Success,
			payload = fmt.tprintf("%d", success_count),
		}

		send_err := send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send Bind_Success response: %v", send_err)
		}

	case .Unbind_Device:
		log_debug("Handling Unbind_Device request")

		// Parse unbind request from JSON
		unbind_req: Unbind_Request
		payload_bytes := transmute([]u8)msg.payload
		unmarshal_err := json.unmarshal(payload_bytes, &unbind_req)
		if unmarshal_err != nil {
			log_warn("Failed to unmarshal unbind request: %v", unmarshal_err)
			return
		}
		defer delete(unbind_req.devices)

		log_info("Unbinding %d device(s)", len(unbind_req.devices))

		// Unbind each device
		success_count := 0
		for device_info in unbind_req.devices {
			log_info(
				"Unbinding device: %s (rx_type=%d, channel=%d)",
				device_info.mac_str,
				device_info.rx_type,
				device_info.channel,
			)

			// Parse MAC address
			mac_parts := strings.split(device_info.mac_str, ":")
			defer delete(mac_parts)

			if len(mac_parts) != 6 {
				log_warn("Invalid MAC address format: %s", device_info.mac_str)
				continue
			}

			device_mac: [6]u8
			parse_ok := true
			for part, i in mac_parts {
				val, ok := strconv.parse_u64_of_base(part, 16)
				if !ok {
					log_warn("Invalid MAC address byte: %s", part)
					parse_ok = false
					break
				}
				device_mac[i] = u8(val)
			}

			if !parse_ok do continue

			// Unbind the device
			unbind_err := unbind_device(&state.led_device, device_mac, device_info.rx_type, device_info.channel)
			if unbind_err != .None {
				log_warn("Failed to unbind device %s: %v", device_info.mac_str, unbind_err)
			} else {
				log_info("Device %s unbound successfully", device_info.mac_str)
				success_count += 1
			}
		}

		// Refresh device cache to reflect new bind status
		refresh_device_cache(state)

		// Send success response
		response := IPC_Message {
			type    = .Unbind_Success,
			payload = fmt.tprintf("%d", success_count),
		}

		send_err := send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send Unbind_Success response: %v", send_err)
		}

	case .Set_Effect:
		log_debug("Handling Set_Effect request")

		// Parse effect request from JSON
		effect_req: Effect_Request
		payload_bytes := transmute([]u8)msg.payload
		unmarshal_err := json.unmarshal(payload_bytes, &effect_req)
		if unmarshal_err != nil {
			log_warn("Failed to unmarshal effect request: %v", unmarshal_err)
			return
		}
		defer delete(effect_req.devices)

		log_info("Applying effect '%s' to %d device(s)", effect_req.effect_name, len(effect_req.devices))

		// Prepare packets for all devices (first loop - matches Python lines 1704-1821)
		device_packets := make([dynamic]Device_Packet_Info)
		// Note: device_packets ownership is transferred to state.current_effect_packets, so no defer delete

		brightness := int(effect_req.brightness)

		for device_info in effect_req.devices {
			log_info(
				"Preparing effect for device: %s (rx_type=%d, channel=%d, led_count=%d)",
				device_info.mac_str,
				device_info.rx_type,
				device_info.channel,
				device_info.led_count,
			)

			// Find device in cache to get full RF_Device_Info
			sync.mutex_lock(&state.devices_mutex)
			device_rf_info: RF_Device_Info
			device_found := false
			for cached_device in state.devices_cache {
				if cached_device.mac_str == device_info.mac_str {
					device_rf_info = cached_device
					device_found = true
					break
				}
			}
			sync.mutex_unlock(&state.devices_mutex)

			if !device_found {
				log_warn("Device %s not found in cache", device_info.mac_str)
				continue
			}

			// Calculate total LEDs based on fan_types (matches Python line 1725-1726)
			leds_per_fan: int = 40
			for fan_type in device_rf_info.fan_types {
				if fan_type >= 28 {
					leds_per_fan = 26
					break
				}
			}
			total_leds := leds_per_fan * int(device_rf_info.fan_num)

			log_info("  Device %s: %d fans, %d LEDs", device_info.mac_str, device_rf_info.fan_num, total_leds)

			// Generate effect data based on effect name
			rgb_data: []u8
			defer delete(rgb_data)

			switch effect_req.effect_name {
			case "Static Color":
				rgb_data = generate_static_color(total_leds, effect_req.color1[0], effect_req.color1[1], effect_req.color1[2])

			case "Rainbow":
				rgb_data = generate_rainbow(total_leds, brightness)

			case "Alternating":
				rgb_data = generate_alternating(total_leds, effect_req.color1, effect_req.color2)

			case "Alternating Spin":
				rgb_data = generate_alternating_spin(total_leds, effect_req.color1, effect_req.color2, 60)

			case "Rainbow Morph":
				rgb_data = generate_rainbow_morph(total_leds, 127, brightness)

			case "Breathing":
				rgb_data = generate_breathing(total_leds, 680, brightness)

			case "Runway":
				rgb_data = generate_runway(total_leds, 180, brightness)

			case "Meteor":
				rgb_data = generate_meteor(total_leds, 360, brightness)

			case "Color Cycle":
				rgb_data = generate_color_cycle(total_leds, 40, brightness)

			case "Wave":
				rgb_data = generate_wave(total_leds, 80, brightness)

			case "Meteor Shower":
				rgb_data = generate_meteor_shower(total_leds, 80, brightness)

			case "Twinkle":
				rgb_data = generate_twinkle(total_leds, 200, brightness)

			case:
				log_warn("Unknown effect: %s", effect_req.effect_name)
				continue
			}

			// Calculate total frames for animated effects
			total_frames: u16 = 1
			switch effect_req.effect_name {
			case "Alternating Spin":
				total_frames = 60
			case "Rainbow Morph":
				total_frames = 127
			case "Breathing":
				total_frames = 680
			case "Runway":
				total_frames = 180
			case "Meteor":
				total_frames = 360
			case "Color Cycle":
				total_frames = 40
			case "Wave":
				total_frames = 80
			case "Meteor Shower":
				total_frames = 80
			case "Twinkle":
				total_frames = 200
			}

			// Compress and build packets
			compressed := make([]u8, len(rgb_data) * 2)
			defer delete(compressed)

			compressed_size, compress_result := tuz.compress_mem(rgb_data, compressed)
			if compress_result != .OK {
				log_warn("Failed to compress RGB data for device %s", device_info.mac_str)
				continue
			}

			rf_packets, err := build_led_effect_packets(
				compressed[:compressed_size],
				u8(total_leds),
				device_rf_info.mac,
				state.led_device.master_mac,
				total_frames,
			)
			if err != .None {
				log_warn("Failed to build packets for device %s: %v", device_info.mac_str, err)
				continue
			}

			append(&device_packets, Device_Packet_Info{
				channel = device_rf_info.channel,
				rx_type = device_rf_info.rx_type,
				mac_str = strings.clone(device_rf_info.mac_str),  // Deep copy to avoid dangling pointer
				rf_packets = rf_packets,
				total_frame = total_frames,
			})

			log_info("Built %d packets for device %s (total_frame=%d)", len(rf_packets), device_info.mac_str, total_frames)
		}

		// Send effect to all devices (second loop - matches Python lines 1827-1838)
		log_info("Sending effect to %d device(s)...", len(device_packets))
		success_count := 0

		for &dp in device_packets {
			// Send metadata packet 4 times with 20ms delays
			for _ in 0..<4 {
				send_err := send_rf_packet(&state.led_device, dp.rf_packets[0][:], dp.channel, dp.rx_type, delay_ms = 0.5)
				if send_err != .None {
					log_warn("Failed to send metadata packet to device %s: %v", dp.mac_str, send_err)
					break
				}
				time.sleep(20 * time.Millisecond)
			}

			// Send data packets once each
			for &data_packet in dp.rf_packets[1:] {
				send_err := send_rf_packet(&state.led_device, data_packet[:], dp.channel, dp.rx_type, delay_ms = 0.5)
				if send_err != .None {
					log_warn("Failed to send data packet to device %s: %v", dp.mac_str, send_err)
					break
				}
			}

			log_info("Effect sent to device %s", dp.mac_str)
			success_count += 1
		}

		// Store packets for continuous broadcast (matches Python lines 1857-1881)
		log_info("Storing effect packets for continuous broadcast...")
		sync.lock(&state.effect_packets_mutex)

		// Clear old packets
		for &old_dp in state.current_effect_packets {
			delete(old_dp.mac_str)  // Free cloned string
			delete(old_dp.rf_packets)
		}
		delete(state.current_effect_packets)

		// Store new packets
		state.current_effect_packets = device_packets
		sync.unlock(&state.effect_packets_mutex)

		// Send success response
		response := IPC_Message {
			type    = .Effect_Applied,
			payload = fmt.tprintf("%d", success_count),
		}

		send_err := send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send Effect_Applied response: %v", send_err)
		}

	case .Ping:
		log_debug("Handling Ping request")

		response := IPC_Message {
			type    = .Pong,
			payload = "",
		}

		send_message(client_fd, response)

	case:
		log_warn("Unknown message type: %v", msg.type)
	}
}

// Initialize LCD playback test (hardcoded for first LCD device)
init_lcd_playback_test :: proc(state: ^Service_State) {
	// Wait a moment for devices to be discovered
	time.sleep(2 * time.Second)

	// Load device cache to get LCD devices
	cache, err := load_device_cache()
	if err != .None {
		log_warn("Could not load device cache for LCD initialization: %v", err)
		return
	}
	defer {
		for entry in cache {
			delete(entry.mac_str)
			delete(entry.dev_type_name)
		}
		delete(cache)
	}

	// Get config directory path for frames
	config_dir, config_err := get_config_dir()
	if config_err != .None {
		log_warn("Could not get config directory: %v", config_err)
		return
	}
	defer delete(config_dir)

	frames_dir := fmt.aprintf("%s/lcd_frames/bad_apple", config_dir)
	defer delete(frames_dir)

	// Load settings to get LCD device configuration
	settings, settings_err := load_settings()
	if settings_err != .None {
		log_warn("Failed to load settings, using auto-detect: %v", settings_err)
		settings = App_Settings{
			lcd_device_bus = 0,
			lcd_device_address = 0,
		}
	}

	// Find first LCD device in cache to get MAC and load transform
	transform := LCD_Transform{zoom_percent = 35.0} // Default
	for entry in cache {
		if entry.has_lcd {
			device_transform, transform_err := get_device_transform(entry.mac_str)
			if transform_err == .None {
				transform = device_transform
				log_info("Loaded LCD transform for device %s", entry.mac_str)
			}
			break // Use first LCD device found
		}
	}

	log_info("Using LCD device: bus=%d, address=%d", settings.lcd_device_bus, settings.lcd_device_address)
	log_info("Using LCD transform: zoom=%.1f%%, rotation=%.1f deg, rotation_speed=%.1f deg/s",
		transform.zoom_percent,
		transform.rotate_degrees,
		transform.rotation_speed)

	// Create LCD playback state (load from configuration)
	playback, lcd_err := create_lcd_playback(settings.lcd_device_bus, settings.lcd_device_address, frames_dir, fps = 20.0, loop = true, transform = transform)
	if lcd_err != .None {
		log_error("Failed to create LCD playback: %v", lcd_err)
		return
	}

	state.lcd_playback = playback
	log_info("LCD playback initialized: %d frames at %.1f fps", len(playback.frames.frame_paths), playback.fps)

	// Start playback
	start_lcd_playback(playback)
	log_info("LCD playback started!")
}

