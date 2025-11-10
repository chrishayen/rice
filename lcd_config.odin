// lcd_config.odin
// LCD animation configuration (separate from device cache)
package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

LCD_Config_Error :: enum {
	None,
	Save_Failed,
	Load_Failed,
	Marshal_Failed,
	Unmarshal_Failed,
	Path_Error,
}

// Per-fan LCD animation settings
LCD_Fan_Config :: struct {
	fan_index:  int,
	transform:  LCD_Transform,
	frames_dir: string, // Path to frames directory for this fan
}

// Per-device LCD configuration
LCD_Device_Config :: struct {
	serial_number: string,  // USB serial number for device identification
	fans:          []LCD_Fan_Config,
}

// Top-level LCD configuration
LCD_Config :: struct {
	devices:    []LCD_Device_Config,
	updated_at: i64, // Unix timestamp
}

// Get LCD config file path
get_lcd_config_path :: proc() -> (string, LCD_Config_Error) {
	config_dir, err := get_config_dir()
	if err != .None {
		return "", .Path_Error
	}
	defer delete(config_dir)

	config_path := filepath.join({config_dir, "lcd_config.json"})
	return config_path, .None
}

// Load LCD configuration
load_lcd_config :: proc(allocator := context.allocator) -> (LCD_Config, LCD_Config_Error) {
	config_path, path_err := get_lcd_config_path()
	defer delete(config_path)

	if path_err != .None {
		return {}, path_err
	}

	// Return empty config if file doesn't exist
	if !os.exists(config_path) {
		return LCD_Config{
			devices = make([]LCD_Device_Config, 0, allocator),
			updated_at = time.to_unix_seconds(time.now()),
		}, .None
	}

	// Read file
	json_data, read_ok := os.read_entire_file(config_path)
	if !read_ok {
		return {}, .Load_Failed
	}
	defer delete(json_data)

	// Unmarshal JSON
	config: LCD_Config
	unmarshal_err := json.unmarshal(json_data, &config, allocator = allocator)
	if unmarshal_err != nil {
		return {}, .Unmarshal_Failed
	}

	return config, .None
}

// Save LCD configuration
save_lcd_config :: proc(config: LCD_Config) -> LCD_Config_Error {
	config_path, path_err := get_lcd_config_path()
	defer delete(config_path)

	if path_err != .None {
		return path_err
	}

	// Update timestamp
	config := config
	config.updated_at = time.to_unix_seconds(time.now())

	// Marshal to JSON
	json_data, marshal_err := json.marshal(config, {pretty = true})
	if marshal_err != nil {
		return .Marshal_Failed
	}
	defer delete(json_data)

	// Write to file
	write_err := os.write_entire_file(config_path, json_data)
	if !write_err {
		return .Save_Failed
	}

	return .None
}

// Get LCD transform for specific device and fan
get_lcd_fan_transform :: proc(serial_number: string, fan_index: int) -> (LCD_Transform, LCD_Config_Error) {
	config, load_err := load_lcd_config()
	defer {
		for device in config.devices {
			delete(device.serial_number)
			delete(device.fans)
		}
		delete(config.devices)
	}

	if load_err != .None {
		return {}, load_err
	}

	// Find device
	for device in config.devices {
		if device.serial_number == serial_number {
			// Find fan
			for fan in device.fans {
				if fan.fan_index == fan_index {
					return fan.transform, .None
				}
			}
		}
	}

	// Return default if not found
	return LCD_Transform{zoom_percent = 35.0}, .None
}

// Update LCD transform for specific device and fan
update_lcd_fan_transform :: proc(serial_number: string, fan_index: int, transform: LCD_Transform) -> LCD_Config_Error {
	config, load_err := load_lcd_config()
	defer {
		for device in config.devices {
			delete(device.serial_number)
			for fan in device.fans {
				delete(fan.frames_dir)
			}
			delete(device.fans)
		}
		delete(config.devices)
	}

	if load_err != .None {
		return load_err
	}

	// Find or create device
	device_idx := -1
	for device, idx in config.devices {
		if device.serial_number == serial_number {
			device_idx = idx
			break
		}
	}

	// Create new config for saving
	new_devices := make([dynamic]LCD_Device_Config, 0, len(config.devices))
	defer delete(new_devices)

	if device_idx == -1 {
		// Add new device
		for device in config.devices {
			// Clone fans array with cloned strings
			cloned_fans := make([]LCD_Fan_Config, len(device.fans))
			for fan, i in device.fans {
				cloned_fans[i] = LCD_Fan_Config{
					fan_index = fan.fan_index,
					transform = fan.transform,
					frames_dir = strings.clone(fan.frames_dir),
				}
			}
			new_device := LCD_Device_Config{
				serial_number = strings.clone(device.serial_number),
				fans = cloned_fans,
			}
			append(&new_devices, new_device)
		}

		// Create new device with this fan
		new_device := LCD_Device_Config{
			serial_number = strings.clone(serial_number),
			fans = make([]LCD_Fan_Config, 1),
		}
		new_device.fans[0] = LCD_Fan_Config{
			fan_index = fan_index,
			transform = transform,
			frames_dir = "",
		}
		append(&new_devices, new_device)
	} else {
		// Update existing device
		for device, idx in config.devices {
			if idx == device_idx {
				// Find or add fan
				fan_idx := -1
				for fan, f_idx in device.fans {
					if fan.fan_index == fan_index {
						fan_idx = f_idx
						break
					}
				}

				if fan_idx == -1 {
					// Add new fan - clone existing fans and add new one
					new_fans := make([]LCD_Fan_Config, len(device.fans) + 1)
					for fan, i in device.fans {
						new_fans[i] = LCD_Fan_Config{
							fan_index = fan.fan_index,
							transform = fan.transform,
							frames_dir = strings.clone(fan.frames_dir),
						}
					}
					new_fans[len(device.fans)] = LCD_Fan_Config{
						fan_index = fan_index,
						transform = transform,
						frames_dir = "",
					}
					new_device := LCD_Device_Config{
						serial_number = strings.clone(device.serial_number),
						fans = new_fans,
					}
					append(&new_devices, new_device)
				} else {
					// Update existing fan - clone all fans and update the target one
					new_fans := make([]LCD_Fan_Config, len(device.fans))
					for fan, i in device.fans {
						if i == fan_idx {
							new_fans[i] = LCD_Fan_Config{
								fan_index = fan.fan_index,
								transform = transform,
								frames_dir = strings.clone(fan.frames_dir),
							}
						} else {
							new_fans[i] = LCD_Fan_Config{
								fan_index = fan.fan_index,
								transform = fan.transform,
								frames_dir = strings.clone(fan.frames_dir),
							}
						}
					}
					new_device := LCD_Device_Config{
						serial_number = strings.clone(device.serial_number),
						fans = new_fans,
					}
					append(&new_devices, new_device)
				}
			} else {
				// Clone other devices
				cloned_fans := make([]LCD_Fan_Config, len(device.fans))
				for fan, i in device.fans {
					cloned_fans[i] = LCD_Fan_Config{
						fan_index = fan.fan_index,
						transform = fan.transform,
						frames_dir = strings.clone(fan.frames_dir),
					}
				}
				new_device := LCD_Device_Config{
					serial_number = strings.clone(device.serial_number),
					fans = cloned_fans,
				}
				append(&new_devices, new_device)
			}
		}
	}

	// Save updated config
	new_config := LCD_Config{
		devices = new_devices[:],
		updated_at = time.to_unix_seconds(time.now()),
	}

	return save_lcd_config(new_config)
}

// Get LCD frames directory for specific device and fan
get_lcd_fan_frames_dir :: proc(serial_number: string, fan_index: int) -> (string, LCD_Config_Error) {
	config, load_err := load_lcd_config()
	defer {
		for device in config.devices {
			delete(device.serial_number)
			for fan in device.fans {
				delete(fan.frames_dir)
			}
			delete(device.fans)
		}
		delete(config.devices)
	}

	if load_err != .None {
		return "", load_err
	}

	// Find device
	for device in config.devices {
		if device.serial_number == serial_number {
			// Find fan
			for fan in device.fans {
				if fan.fan_index == fan_index {
					return fan.frames_dir, .None
				}
			}
		}
	}

	// Return empty if not found
	return "", .None
}

// Update LCD frames directory for specific device and fan
update_lcd_fan_frames_dir :: proc(serial_number: string, fan_index: int, frames_dir: string) -> LCD_Config_Error {
	config, load_err := load_lcd_config()
	defer {
		for device in config.devices {
			delete(device.serial_number)
			for fan in device.fans {
				delete(fan.frames_dir)
			}
			delete(device.fans)
		}
		delete(config.devices)
	}

	if load_err != .None {
		return load_err
	}

	// Find or create device
	device_idx := -1
	for device, idx in config.devices {
		if device.serial_number == serial_number {
			device_idx = idx
			break
		}
	}

	// Create new config for saving
	new_devices := make([dynamic]LCD_Device_Config, 0, len(config.devices))
	defer delete(new_devices)

	if device_idx == -1 {
		// Add new device
		for device in config.devices {
			// Clone fans array with cloned strings
			cloned_fans := make([]LCD_Fan_Config, len(device.fans))
			for fan, i in device.fans {
				cloned_fans[i] = LCD_Fan_Config{
					fan_index = fan.fan_index,
					transform = fan.transform,
					frames_dir = strings.clone(fan.frames_dir),
				}
			}
			new_device := LCD_Device_Config{
				serial_number = strings.clone(device.serial_number),
				fans = cloned_fans,
			}
			append(&new_devices, new_device)
		}

		// Create new device with this fan
		new_device := LCD_Device_Config{
			serial_number = strings.clone(serial_number),
			fans = make([]LCD_Fan_Config, 1),
		}
		new_device.fans[0] = LCD_Fan_Config{
			fan_index = fan_index,
			transform = LCD_Transform{zoom_percent = 35.0},
			frames_dir = strings.clone(frames_dir),
		}
		append(&new_devices, new_device)
	} else {
		// Update existing device
		for device, idx in config.devices {
			if idx == device_idx {
				// Find or add fan
				fan_idx := -1
				for fan, f_idx in device.fans {
					if fan.fan_index == fan_index {
						fan_idx = f_idx
						break
					}
				}

				if fan_idx == -1 {
					// Add new fan - clone existing fans and add new one
					new_fans := make([]LCD_Fan_Config, len(device.fans) + 1)
					for fan, i in device.fans {
						new_fans[i] = LCD_Fan_Config{
							fan_index = fan.fan_index,
							transform = fan.transform,
							frames_dir = strings.clone(fan.frames_dir),
						}
					}
					new_fans[len(device.fans)] = LCD_Fan_Config{
						fan_index = fan_index,
						transform = LCD_Transform{zoom_percent = 35.0},
						frames_dir = strings.clone(frames_dir),
					}
					new_device := LCD_Device_Config{
						serial_number = strings.clone(device.serial_number),
						fans = new_fans,
					}
					append(&new_devices, new_device)
				} else {
					// Update existing fan - clone all fans and update the target one
					new_fans := make([]LCD_Fan_Config, len(device.fans))
					for fan, i in device.fans {
						if i == fan_idx {
							new_fans[i] = LCD_Fan_Config{
								fan_index = fan.fan_index,
								transform = fan.transform,
								frames_dir = strings.clone(frames_dir),
							}
						} else {
							new_fans[i] = LCD_Fan_Config{
								fan_index = fan.fan_index,
								transform = fan.transform,
								frames_dir = strings.clone(fan.frames_dir),
							}
						}
					}
					new_device := LCD_Device_Config{
						serial_number = strings.clone(device.serial_number),
						fans = new_fans,
					}
					append(&new_devices, new_device)
				}
			} else {
				// Clone other devices
				cloned_fans := make([]LCD_Fan_Config, len(device.fans))
				for fan, i in device.fans {
					cloned_fans[i] = LCD_Fan_Config{
						fan_index = fan.fan_index,
						transform = fan.transform,
						frames_dir = strings.clone(fan.frames_dir),
					}
				}
				new_device := LCD_Device_Config{
					serial_number = strings.clone(device.serial_number),
					fans = cloned_fans,
				}
				append(&new_devices, new_device)
			}
		}
	}

	// Save updated config
	new_config := LCD_Config{
		devices = new_devices[:],
		updated_at = time.to_unix_seconds(time.now()),
	}

	return save_lcd_config(new_config)
}
