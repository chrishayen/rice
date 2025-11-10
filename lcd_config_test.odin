package main

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

// Helper to clean up LCD config file
cleanup_lcd_config :: proc() {
	init_config_dir()
	path, err := get_lcd_config_path()
	if err == .None {
		defer delete(path)
		os.remove(path)
	}
}

// Test LCD config path generation
@(test)
test_get_lcd_config_path :: proc(t: ^testing.T) {
	path, err := get_lcd_config_path()
	defer delete(path)

	testing.expect(t, err == .None, "Getting config path should succeed")
	testing.expect(t, len(path) > 0, "Path should not be empty")
	testing.expect(t, strings.contains(path, "lcd_config.json"), "Path should contain lcd_config.json")
}

// Test LCD config load when file doesn't exist
@(test)
test_load_lcd_config_nonexistent :: proc(t: ^testing.T) {
	cleanup_lcd_config()

	// Verify file doesn't exist
	path, path_err := get_lcd_config_path()
	defer delete(path)
	testing.expect(t, path_err == .None, "Getting config path should succeed")
	file_exists := os.exists(path)
	testing.expect(t, !file_exists, "Config file should not exist after cleanup")

	config, err := load_lcd_config()
	defer {
		if config.devices != nil {
			for device in config.devices {
				delete(device.serial_number)
				for fan in device.fans {
					delete(fan.frames_dir)
				}
				delete(device.fans)
			}
			delete(config.devices)
		}
	}

	testing.expect(t, err == .None, "Loading nonexistent config should return empty config")
	// In Odin, devices could be nil or an empty slice - both are valid for empty config
	device_count := config.devices == nil ? 0 : len(config.devices)
	testing.expect(t, device_count == 0, "Devices should be empty")
	testing.expect(t, config.updated_at > 0, "Timestamp should be set")
}

// Test LCD config save and load roundtrip
@(test)
test_lcd_config_save_and_load :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	// Create a test config
	test_config := LCD_Config{
		devices = make([]LCD_Device_Config, 1),
		updated_at = 0,
	}
	test_config.devices[0] = LCD_Device_Config{
		serial_number = strings.clone("49a498b9431f0e66"),
		fans = make([]LCD_Fan_Config, 1),
	}
	test_config.devices[0].fans[0] = LCD_Fan_Config{
		fan_index = 0,
		transform = LCD_Transform{zoom_percent = 50.0},
		frames_dir = strings.clone("/test/path"),
	}

	// Save the config
	save_err := save_lcd_config(test_config)

	// Clean up the test config
	for device in test_config.devices {
		delete(device.serial_number)
		for fan in device.fans {
			delete(fan.frames_dir)
		}
		delete(device.fans)
	}
	delete(test_config.devices)

	testing.expect(t, save_err == .None, "Saving config should succeed")

	// Load it back
	loaded_config, load_err := load_lcd_config()
	defer {
		for device in loaded_config.devices {
			delete(device.serial_number)
			for fan in device.fans {
				delete(fan.frames_dir)
			}
			delete(device.fans)
		}
		delete(loaded_config.devices)
	}

	testing.expect(t, load_err == .None, "Loading config should succeed")
	testing.expect(t, len(loaded_config.devices) == 1, "Should have one device")
	testing.expect(t, loaded_config.devices[0].serial_number == "49a498b9431f0e66", "Serial number should match")
	testing.expect(t, len(loaded_config.devices[0].fans) == 1, "Should have one fan")
	testing.expect(t, loaded_config.devices[0].fans[0].transform.zoom_percent == 50.0, "Zoom should match")
	testing.expect(t, loaded_config.devices[0].fans[0].frames_dir == "/test/path", "Frames dir should match")
}

// Test get LCD fan transform with nonexistent device
@(test)
test_get_lcd_fan_transform_nonexistent :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	transform, err := get_lcd_fan_transform("00:00:00:00:00:00", 0)

	testing.expect(t, err == .None, "Getting nonexistent transform should return default")
	testing.expect(t, transform.zoom_percent == 35.0, "Should return default zoom")
}

// Test update LCD fan transform creates new device
@(test)
test_update_lcd_fan_transform_new_device :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	test_mac := "11:22:33:44:55:66"
	test_transform := LCD_Transform{
		zoom_percent = 60.0,
		rotate_degrees = 90.0,
		flip_horizontal = true,
	}

	err := update_lcd_fan_transform(test_mac, 0, test_transform)
	testing.expect(t, err == .None, "Updating transform should succeed")

	// Verify it was saved
	loaded_transform, load_err := get_lcd_fan_transform(test_mac, 0)
	testing.expect(t, load_err == .None, "Loading transform should succeed")
	testing.expect(t, loaded_transform.zoom_percent == 60.0, "Zoom should match")
	testing.expect(t, loaded_transform.rotate_degrees == 90.0, "Rotation should match")
	testing.expect(t, loaded_transform.flip_horizontal == true, "Flip should match")
}

// Test update LCD fan transform updates existing device
@(test)
test_update_lcd_fan_transform_existing_device :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	test_mac := "22:33:44:55:66:77"

	// Create initial transform
	initial_transform := LCD_Transform{zoom_percent = 40.0}
	err1 := update_lcd_fan_transform(test_mac, 0, initial_transform)
	testing.expect(t, err1 == .None, "Initial update should succeed")

	// Update the transform
	updated_transform := LCD_Transform{zoom_percent = 70.0}
	err2 := update_lcd_fan_transform(test_mac, 0, updated_transform)
	testing.expect(t, err2 == .None, "Second update should succeed")

	// Verify the update
	loaded_transform, load_err := get_lcd_fan_transform(test_mac, 0)
	testing.expect(t, load_err == .None, "Loading transform should succeed")
	testing.expect(t, loaded_transform.zoom_percent == 70.0, "Zoom should be updated")
}

// Test multiple fans per device
@(test)
test_multiple_fans_per_device :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	test_mac := "33:44:55:66:77:88"

	// Add transforms for multiple fans
	transform0 := LCD_Transform{zoom_percent = 30.0}
	transform1 := LCD_Transform{zoom_percent = 40.0}
	transform2 := LCD_Transform{zoom_percent = 50.0}

	err0 := update_lcd_fan_transform(test_mac, 0, transform0)
	err1 := update_lcd_fan_transform(test_mac, 1, transform1)
	err2 := update_lcd_fan_transform(test_mac, 2, transform2)

	testing.expect(t, err0 == .None, "Fan 0 update should succeed")
	testing.expect(t, err1 == .None, "Fan 1 update should succeed")
	testing.expect(t, err2 == .None, "Fan 2 update should succeed")

	// Verify all fans
	loaded0, _ := get_lcd_fan_transform(test_mac, 0)
	loaded1, _ := get_lcd_fan_transform(test_mac, 1)
	loaded2, _ := get_lcd_fan_transform(test_mac, 2)

	testing.expect(t, loaded0.zoom_percent == 30.0, "Fan 0 zoom should match")
	testing.expect(t, loaded1.zoom_percent == 40.0, "Fan 1 zoom should match")
	testing.expect(t, loaded2.zoom_percent == 50.0, "Fan 2 zoom should match")
}

// Test get LCD fan frames dir with nonexistent device
@(test)
test_get_lcd_fan_frames_dir_nonexistent :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	frames_dir, err := get_lcd_fan_frames_dir("00:00:00:00:00:00", 0)
	defer delete(frames_dir)

	testing.expect(t, err == .None, "Getting nonexistent frames dir should succeed")
	testing.expect(t, frames_dir == "", "Should return empty string")
}

// Test update LCD fan frames dir
@(test)
test_update_lcd_fan_frames_dir :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	test_mac := "44:55:66:77:88:99"
	test_path := "/home/user/frames/animation1"

	err := update_lcd_fan_frames_dir(test_mac, 0, test_path)
	testing.expect(t, err == .None, "Updating frames dir should succeed")

	// Verify it was saved
	loaded_path, load_err := get_lcd_fan_frames_dir(test_mac, 0)
	defer delete(loaded_path)

	testing.expect(t, load_err == .None, "Loading frames dir should succeed")
	testing.expect(t, loaded_path == test_path, "Frames dir should match")
}

// Test update frames dir for existing device with transform
@(test)
test_update_frames_dir_with_existing_transform :: proc(t: ^testing.T) {
	cleanup_lcd_config()
	test_mac := "55:66:77:88:99:aa"

	// First set a transform
	transform := LCD_Transform{zoom_percent = 45.0}
	err1 := update_lcd_fan_transform(test_mac, 0, transform)
	testing.expect(t, err1 == .None, "Setting transform should succeed")

	// Then set frames dir
	test_path := "/home/user/frames/animation2"
	err2 := update_lcd_fan_frames_dir(test_mac, 0, test_path)
	testing.expect(t, err2 == .None, "Setting frames dir should succeed")

	// Verify both are preserved
	loaded_transform, _ := get_lcd_fan_transform(test_mac, 0)
	loaded_path, _ := get_lcd_fan_frames_dir(test_mac, 0)
	defer delete(loaded_path)

	testing.expect(t, loaded_transform.zoom_percent == 45.0, "Transform should be preserved")
	testing.expect(t, loaded_path == test_path, "Frames dir should be set")
}

// Test LCD config error enum values
@(test)
test_lcd_config_error_enum :: proc(t: ^testing.T) {
	testing.expect(t, LCD_Config_Error.None != LCD_Config_Error.Save_Failed, "Error types should be distinct")
	testing.expect(t, LCD_Config_Error.Load_Failed != LCD_Config_Error.Marshal_Failed, "Error types should be distinct")
	testing.expect(t, LCD_Config_Error.Unmarshal_Failed != LCD_Config_Error.Path_Error, "Error types should be distinct")
}

// Test LCD fan config marshaling
@(test)
test_lcd_fan_config_marshal :: proc(t: ^testing.T) {
	fan_config := LCD_Fan_Config{
		fan_index = 2,
		transform = LCD_Transform{zoom_percent = 55.0},
		frames_dir = "/test/frames",
	}

	json_data, err := json.marshal(fan_config)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling fan config should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test LCD device config marshaling
@(test)
test_lcd_device_config_marshal :: proc(t: ^testing.T) {
	device_config := LCD_Device_Config{
		serial_number = "49a498b9431f0e66",
		fans = make([]LCD_Fan_Config, 1),
	}
	device_config.fans[0] = LCD_Fan_Config{
		fan_index = 0,
		transform = LCD_Transform{zoom_percent = 35.0},
		frames_dir = "/test",
	}
	defer delete(device_config.fans)

	json_data, err := json.marshal(device_config)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling device config should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")
}

// Test full LCD config marshaling
@(test)
test_full_lcd_config_marshal :: proc(t: ^testing.T) {
	config := LCD_Config{
		devices = make([]LCD_Device_Config, 1),
		updated_at = 1234567890,
	}
	config.devices[0] = LCD_Device_Config{
		serial_number = "49a498b9431f0e66",
		fans = make([]LCD_Fan_Config, 1),
	}
	config.devices[0].fans[0] = LCD_Fan_Config{
		fan_index = 0,
		transform = LCD_Transform{zoom_percent = 35.0},
		frames_dir = "/test",
	}
	defer {
		for device in config.devices {
			delete(device.fans)
		}
		delete(config.devices)
	}

	json_data, err := json.marshal(config)
	defer delete(json_data)

	testing.expect(t, err == nil, "Marshaling full config should succeed")
	testing.expect(t, len(json_data) > 0, "JSON data should not be empty")

	// Verify unmarshal
	unmarshaled: LCD_Config
	unmarshal_err := json.unmarshal(json_data, &unmarshaled)
	defer {
		for device in unmarshaled.devices {
			delete(device.serial_number)
			for fan in device.fans {
				delete(fan.frames_dir)
			}
			delete(device.fans)
		}
		delete(unmarshaled.devices)
	}

	testing.expect(t, unmarshal_err == nil, "Unmarshaling should succeed")
	testing.expect(t, unmarshaled.updated_at == 1234567890, "Timestamp should match")
	testing.expect(t, len(unmarshaled.devices) == 1, "Should have one device")
}
