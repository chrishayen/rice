// service.odin
// Fan Control Service - Runs as a daemon/service
package main

import "core:c"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import rl "ricelib"

Service_State :: struct {
	led_device:            rl.LED_Device,
	socket_server:         rl.Socket_Server,
	running:               bool,
	poll_interval_seconds: int,
	devices_cache:         [dynamic]rl.RF_Device_Info,
	devices_mutex:         sync.Mutex,
	master_poll_thread:    ^thread.Thread,
	device_query_thread:   ^thread.Thread,
	epoll_fd:              c.int,
}

run_service :: proc() {
	log_info("Starting Fan Control Service...")
	log_debug("Service mode activated")

	// Initialize config directory
	log_debug("Initializing config directory...")
	config_err := rl.init_config_dir()
	if config_err != .None {
		log_error("Failed to initialize config directory: %v", config_err)
		os.exit(1)
	}

	config_dir, _ := rl.get_config_dir()
	defer delete(config_dir)
	log_info("Config directory: %s", config_dir)

	// Get socket path
	socket_path, socket_err := rl.get_socket_path()
	defer delete(socket_path)

	if socket_err != .None {
		log_error("Failed to get socket path: %v", socket_err)
		os.exit(1)
	}

	log_info("Socket path: %s", socket_path)

	// Clean up old socket file if it exists
	if !rl.cleanup_socket() {
		log_warn("Failed to clean up old socket file")
	}

	state: Service_State
	state.running = true
	state.poll_interval_seconds = 10
	state.devices_cache = make([dynamic]rl.RF_Device_Info)
	defer delete(state.devices_cache)

	// Initialize LED device
	led_dev, err := rl.init_led_device()
	if err != .None {
		log_error("Failed to initialize LED device: %v", err)
		log_error("Make sure USB devices are connected and you have proper permissions")
		log_debug("Exiting with error code 1")
		os.exit(1)
	}
	defer rl.cleanup_led_device(&state.led_device)

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
	server, server_err := rl.create_socket_server(socket_path)
	if server_err != .None {
		log_error("Failed to create socket server: %v", server_err)
		os.exit(1)
	}
	defer rl.close_server(&state.socket_server)

	state.socket_server = server
	log_info("Socket server listening on %s", socket_path)

	// Create epoll instance
	log_debug("Creating epoll instance...")
	state.epoll_fd = rl.epoll_create1(rl.EPOLL_CLOEXEC)
	if state.epoll_fd < 0 {
		log_error("Failed to create epoll instance")
		os.exit(1)
	}
	defer rl.close(state.epoll_fd)

	// Add server socket to epoll
	event: rl.epoll_event
	event.events = rl.EPOLLIN
	event.data.fd = state.socket_server.socket_fd
	if rl.epoll_ctl(state.epoll_fd, rl.EPOLL_CTL_ADD, state.socket_server.socket_fd, &event) < 0 {
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

	log_info("Service initialized successfully")
	log_info("Press Ctrl+C to stop")
	log_debug("Poll interval: %d seconds", state.poll_interval_seconds)

	// Main service loop - use epoll to wait for connections
	MAX_EVENTS :: 10
	events: [MAX_EVENTS]rl.epoll_event

	for state.running {
		// Wait for events (timeout 1 second to check running flag)
		num_events := rl.epoll_wait(state.epoll_fd, &events[0], MAX_EVENTS, 1000)

		if num_events < 0 {
			log_warn("epoll_wait error")
			continue
		}

		// Process events
		for i in 0 ..< num_events {
			if events[i].data.fd == state.socket_server.socket_fd {
				// Server socket ready - accept connection
				client_fd, accept_err := rl.accept_connection(&state.socket_server)
				if accept_err == .None {
					log_info("Client connected")

					// Handle the request
					handle_socket_message(client_fd, &state)

					// Close client connection
					rl.close(client_fd)
					log_debug("Client disconnected")
				}
			}
		}
	}

	log_info("Service stopped")
	log_debug("Cleanup complete")

	// Wait for threads to finish
	if state.master_poll_thread != nil {
		thread.destroy(state.master_poll_thread)
	}
	if state.device_query_thread != nil {
		thread.destroy(state.device_query_thread)
	}
}

// Master polling thread - queries master device every 1 second (like L-Connect)
master_polling_thread :: proc(data: rawptr) {
	state := cast(^Service_State)data

	log_debug("Master polling thread started")

	for state.running {
		// Query master device to keep it alive and get updated clock
		if rl.query_master_device(&state.led_device, state.led_device.active_channel) {
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

// Device query thread - queries devices periodically and updates cache
device_query_thread :: proc(data: rawptr) {
	state := cast(^Service_State)data

	log_debug("Device query thread started")

	for state.running {
		log_debug("Querying devices...")

		// Query devices
		devices, query_err := rl.query_devices(&state.led_device)
		if query_err == .None {
			log_info("Found %d devices:", len(devices))

			// Lock mutex to update cache
			sync.mutex_lock(&state.devices_mutex)
			{
				// Update cache - copy devices to cache
				clear(&state.devices_cache)
				for device in devices {
					append(&state.devices_cache, device)
				}
			}
			sync.mutex_unlock(&state.devices_mutex)

			// Save to JSON cache
			cache_err := rl.save_device_cache(devices[:])
			if cache_err != .None {
				log_warn("Failed to save device cache: %v", cache_err)
			} else {
				log_debug("Device cache saved to JSON")
			}

			for device, idx in devices {
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
			log_warn("Failed to query devices: %v", query_err)
		}

		// Sleep for poll interval
		time.sleep(time.Duration(state.poll_interval_seconds) * time.Second)
	}

	log_debug("Device query thread stopped")
}

// Handle socket message from client
handle_socket_message :: proc(client_fd: c.int, state: ^Service_State) {
	// Receive message
	msg, recv_err := rl.receive_message(client_fd)
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
		cached_devices, cache_err := rl.load_device_cache()
		defer delete(cached_devices)

		if cache_err != .None {
			log_warn("Failed to load device cache: %v", cache_err)

			// Send error response
			error_msg := rl.IPC_Message {
				type    = .Error,
				payload = "Failed to load device cache",
			}
			rl.send_message(client_fd, error_msg)
			return
		}

		// Marshal devices to JSON
		json_data, marshal_err := json.marshal(cached_devices)
		if marshal_err != nil {
			log_warn("Failed to marshal devices: %v", marshal_err)

			error_msg := rl.IPC_Message {
				type    = .Error,
				payload = "Failed to marshal devices",
			}
			rl.send_message(client_fd, error_msg)
			return
		}
		defer delete(json_data)

		log_debug("Marshaled JSON (%d bytes): %s", len(json_data), string(json_data))

		// Send response
		response := rl.IPC_Message {
			type    = .Devices_Response,
			payload = string(json_data),
		}

		send_err := rl.send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send devices response: %v", send_err)
		} else {
			log_debug("Sent %d devices to client", len(cached_devices))
		}

		// Build list of devices to identify
		devices_to_identify := make([dynamic]rl.Device_Identify_Info, 0, len(cached_devices))
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

			append(&devices_to_identify, rl.Device_Identify_Info{
				device_mac = device_mac,
				rx_type = device.rx_type,
				channel = device.channel,
			})
		}

		// Identify all devices simultaneously
		if len(devices_to_identify) > 0 {
			log_info("Identifying %d devices simultaneously...", len(devices_to_identify))
			identify_err := rl.identify_devices_batch(&state.led_device, devices_to_identify[:])
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

		status := rl.Status_Info {
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
		response := rl.IPC_Message {
			type    = .Status_Response,
			payload = string(json_data),
		}

		send_err := rl.send_message(client_fd, response)
		if send_err != .None {
			log_warn("Failed to send status response: %v", send_err)
		} else {
			log_debug("Sent status to client")
		}

	case .Identify_Device:
		log_debug("Handling Identify_Device request")

		// Parse identify request from JSON
		identify_req: rl.Identify_Request
		payload_bytes := transmute([]u8)msg.payload
		unmarshal_err := json.unmarshal(payload_bytes, &identify_req)
		if unmarshal_err != nil {
			log_warn("Failed to unmarshal identify request: %v", unmarshal_err)
			return
		}
		defer delete(identify_req.devices)

		log_info("Identifying %d device(s)", len(identify_req.devices))

		// Build batch identify list
		devices_to_identify := make([dynamic]rl.Device_Identify_Info, 0, len(identify_req.devices))
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

			append(&devices_to_identify, rl.Device_Identify_Info{
				device_mac = device_mac,
				rx_type = device_info.rx_type,
				channel = device_info.channel,
			})
		}

		// Identify all devices simultaneously using batch method
		if len(devices_to_identify) > 0 {
			log_info("Identifying %d devices simultaneously...", len(devices_to_identify))
			identify_err := rl.identify_devices_batch(&state.led_device, devices_to_identify[:])
			if identify_err != .None {
				log_warn("Failed to identify devices: %v", identify_err)
			} else {
				log_info("All devices identified successfully")
			}
		}

		// No response - this is fire-and-forget

	case .Ping:
		log_debug("Handling Ping request")

		response := rl.IPC_Message {
			type    = .Pong,
			payload = "",
		}

		rl.send_message(client_fd, response)

	case:
		log_warn("Unknown message type: %v", msg.type)
	}
}

