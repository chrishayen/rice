// device_cache.odin
// Device cache management (save/load devices to JSON)
package main

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"
import "core:time"

Device_Cache_Error :: enum {
	None,
	Save_Failed,
	Load_Failed,
	Marshal_Failed,
	Unmarshal_Failed,
	Path_Error,
}

// JSON-serializable device info
Device_Cache_Entry :: struct {
	mac_str:       string,
	dev_type_name: string,
	channel:       u8,
	bound_to_us:   bool,
	fan_num:       u8,
	rx_type:       u8,
	timestamp:     u32,
	fan_types:     [4]u8,
	has_lcd:       bool,
}

Device_Cache :: struct {
	devices:    []Device_Cache_Entry,
	updated_at: i64, // Unix timestamp
}

// Get device cache file path
get_device_cache_path :: proc() -> (string, Device_Cache_Error) {
	config_dir, err := get_config_dir()
	if err != .None {
		return "", .Path_Error
	}
	defer delete(config_dir)

	cache_path := filepath.join({config_dir, "devices.json"})
	return cache_path, .None
}

// Convert RF_Device_Info to cache entry
device_to_cache_entry :: proc(device: RF_Device_Info) -> Device_Cache_Entry {
	// Detect if device has LCD by checking fan_types array
	// Types 24 and 25 are SL 120 fans with LCD screens
	has_lcd := false
	for i in 0 ..< int(device.fan_num) {
		fan_type := device.fan_types[i]
		if fan_type == 24 || fan_type == 25 {
			has_lcd = true
			break
		}
	}

	return Device_Cache_Entry{
		mac_str       = device.mac_str,
		dev_type_name = device.dev_type_name,
		channel       = device.channel,
		bound_to_us   = device.bound_to_us,
		fan_num       = device.fan_num,
		rx_type       = device.rx_type,
		timestamp     = device.timestamp,
		fan_types     = device.fan_types,
		has_lcd       = has_lcd,
	}
}

// Save devices to cache file
save_device_cache :: proc(devices: []RF_Device_Info) -> Device_Cache_Error {
	cache_path, path_err := get_device_cache_path()
	defer delete(cache_path)

	if path_err != .None {
		return .Path_Error
	}

	// Convert devices to cache entries
	cache_entries := make([]Device_Cache_Entry, len(devices))
	defer delete(cache_entries)

	for device, i in devices {
		cache_entries[i] = device_to_cache_entry(device)
	}

	// Create cache structure
	cache := Device_Cache{
		devices    = cache_entries,
		updated_at = time.to_unix_seconds(time.now()),
	}

	// Marshal to JSON
	json_data, marshal_err := json.marshal(cache, {pretty = true})
	if marshal_err != nil {
		return .Marshal_Failed
	}
	defer delete(json_data)

	// Write to file
	write_err := os.write_entire_file(cache_path, json_data)
	if !write_err {
		return .Save_Failed
	}

	return .None
}

// Load devices from cache file
load_device_cache :: proc() -> ([]Device_Cache_Entry, Device_Cache_Error) {
	cache_path, path_err := get_device_cache_path()
	defer delete(cache_path)

	if path_err != .None {
		return nil, .Path_Error
	}

	// Check if file exists
	if !os.exists(cache_path) {
		// Return empty array if cache doesn't exist
		return make([]Device_Cache_Entry, 0), .None
	}

	// Read file
	json_data, read_ok := os.read_entire_file(cache_path)
	if !read_ok {
		return nil, .Load_Failed
	}
	defer delete(json_data)

	// Unmarshal JSON
	cache: Device_Cache
	unmarshal_err := json.unmarshal(json_data, &cache)
	if unmarshal_err != nil {
		return nil, .Unmarshal_Failed
	}

	return cache.devices, .None
}
