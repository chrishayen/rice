// config.odin
// Configuration and directory management
package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:encoding/json"

Config_Error :: enum {
	None,
	Create_Dir_Failed,
	Get_Home_Failed,
	Invalid_Path,
	Load_Failed,
	Save_Failed,
}

// Application settings
App_Settings :: struct {
	lcd_device_bus:     int,
	lcd_device_address: int,
}

// Get config directory path
get_config_dir :: proc() -> (string, Config_Error) {
	home := os.get_env("HOME")
	if home == "" {
		return "", .Get_Home_Failed
	}

	config_dir := filepath.join({home, ".config", "rice"})
	return config_dir, .None
}

// Get socket path
get_socket_path :: proc() -> (string, Config_Error) {
	config_dir, err := get_config_dir()
	if err != .None {
		return "", err
	}

	socket_path := filepath.join({config_dir, "rice.sock"})
	return socket_path, .None
}

// Initialize config directory (create if doesn't exist)
init_config_dir :: proc() -> Config_Error {
	config_dir, err := get_config_dir()
	defer delete(config_dir)

	if err != .None {
		return err
	}

	// Check if directory exists
	if !os.is_dir(config_dir) {
		// Create directory with proper permissions (0755)
		err := os.make_directory(config_dir, 0o755)
		if err != nil {
			return .Create_Dir_Failed
		}
	}

	return .None
}

// Clean up socket file if it exists
cleanup_socket :: proc() -> bool {
	socket_path, err := get_socket_path()
	defer delete(socket_path)

	if err != .None {
		return false
	}

	// Remove socket file if it exists
	if os.exists(socket_path) {
		remove_err := os.remove(socket_path)
		return remove_err == nil
	}

	return true
}

// Get settings file path
get_settings_path :: proc() -> (string, Config_Error) {
	config_dir, err := get_config_dir()
	if err != .None {
		return "", err
	}
	defer delete(config_dir)

	settings_path := filepath.join({config_dir, "settings.json"})
	return settings_path, .None
}

// Load application settings
load_settings :: proc() -> (App_Settings, Config_Error) {
	settings_path, path_err := get_settings_path()
	defer delete(settings_path)

	if path_err != .None {
		return {}, path_err
	}

	// Return default settings if file doesn't exist
	if !os.exists(settings_path) {
		// Default: auto-detect first LCD device (bus=0, address=0)
		return App_Settings{lcd_device_bus = 0, lcd_device_address = 0}, .None
	}

	// Read file
	json_data, read_ok := os.read_entire_file(settings_path)
	if !read_ok {
		return {}, .Load_Failed
	}
	defer delete(json_data)

	// Unmarshal JSON
	settings: App_Settings
	unmarshal_err := json.unmarshal(json_data, &settings)
	if unmarshal_err != nil {
		return {}, .Load_Failed
	}

	return settings, .None
}

// Save application settings
save_settings :: proc(settings: App_Settings) -> Config_Error {
	settings_path, path_err := get_settings_path()
	defer delete(settings_path)

	if path_err != .None {
		return path_err
	}

	// Marshal to JSON
	json_data, marshal_err := json.marshal(settings, {pretty = true})
	if marshal_err != nil {
		return .Save_Failed
	}
	defer delete(json_data)

	// Write to file
	write_ok := os.write_entire_file(settings_path, json_data)
	if !write_ok {
		return .Save_Failed
	}

	return .None
}
