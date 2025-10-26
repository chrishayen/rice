// config.odin
// Configuration and directory management
package ricelib

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

Config_Error :: enum {
	None,
	Create_Dir_Failed,
	Get_Home_Failed,
	Invalid_Path,
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
