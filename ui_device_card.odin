// ui_device_card.odin
// Device card rendering and interaction

package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"

// Get user-friendly device name from technical type name and LCD flag
get_friendly_device_name :: proc(dev_type_name: string, has_lcd: bool) -> string {
	// Check for specific types first
	if dev_type_name == "LC217" {
		return "Lian Li SL 120 LCD"
	}
	if dev_type_name == "TLV2Fan" {
		return "Lian Li TL"
	}
	if dev_type_name == "RL120" {
		return "Lian Li RL 120"
	}
	if dev_type_name == "SLINF" {
		return "Lian Li SL Infinity"
	}
	if dev_type_name == "Strimer" {
		return "Lian Li Strimer"
	}
	if dev_type_name == "WaterBlock" || dev_type_name == "WaterBlock2" {
		return "Lian Li Water Block"
	}

	// Check for SLV3Fan variants (SLV3Fan, SLV3Fan_21, etc.)
	if strings.has_prefix(dev_type_name, "SLV3Fan") {
		if has_lcd {
			return "Lian Li SL 120 LCD"
		}
		return "Lian Li SL 120"
	}

	// Default: return original name
	return dev_type_name
}

// Build a device card widget
build_device_card :: proc(device: Device, state: ^App_State, device_idx: int) -> GtkWidget {
	// Create a toggle button so the device card is selectable
	button := auto_cast gtk_toggle_button_new()
	gtk_widget_add_css_class(button, "card")
	gtk_widget_set_margin_top(button, 3)
	gtk_widget_set_margin_bottom(button, 3)

	// Store the toggle button
	append(&state.device_toggle_buttons, auto_cast button)

	// Connect toggle handler
	toggle_data := new(int)
	toggle_data^ = device_idx
	g_signal_connect_data(button, "toggled", auto_cast on_device_toggled, toggle_data, nil, 0)

	// Main vertical layout
	main_box := auto_cast gtk_box_new(.VERTICAL, 8)
	gtk_widget_set_margin_start(main_box, 12)
	gtk_widget_set_margin_end(main_box, 12)
	gtk_widget_set_margin_top(main_box, 12)
	gtk_widget_set_margin_bottom(main_box, 12)
	gtk_button_set_child(auto_cast button, main_box)

	// Header row: Device type name + MAC address
	header_box := auto_cast gtk_box_new(.HORIZONTAL, 6)
	gtk_box_append(auto_cast main_box, header_box)

	// Device type name (bold) - map technical name to user-friendly product name
	friendly_name := get_friendly_device_name(device.dev_type_name, device.has_lcd)
	name_cstr := strings.clone_to_cstring(friendly_name)
	defer delete(name_cstr)
	name_label := auto_cast gtk_label_new(name_cstr)
	gtk_label_set_markup(
		auto_cast name_label,
		fmt.ctprintf("<span weight='bold' size='11000'>%s</span>", name_cstr),
	)
	gtk_label_set_xalign(auto_cast name_label, 0.0)
	gtk_widget_set_hexpand(name_label, true)
	gtk_box_append(auto_cast header_box, name_label)

	// MAC address (smaller, gray)
	mac_cstr := strings.clone_to_cstring(device.mac_str)
	defer delete(mac_cstr)
	mac_label := auto_cast gtk_label_new(mac_cstr)
	gtk_label_set_markup(
		auto_cast mac_label,
		fmt.ctprintf("<span size='9000' foreground='#666'>%s</span>", mac_cstr),
	)
	gtk_box_append(auto_cast header_box, mac_label)

	// Visual info row: Fan and LED counts
	visual_box := auto_cast gtk_box_new(.HORIZONTAL, 12)
	gtk_box_append(auto_cast main_box, visual_box)

	// Fan count
	fan_label := auto_cast gtk_label_new(
		fmt.ctprintf("%d Fan%s", device.fan_count, device.fan_count == 1 ? "" : "s"),
	)
	gtk_label_set_markup(
		auto_cast fan_label,
		fmt.ctprintf("<span size='9000'>%d Fan%s</span>", device.fan_count, device.fan_count == 1 ? "" : "s"),
	)
	gtk_label_set_xalign(auto_cast fan_label, 0.0)
	gtk_box_append(auto_cast visual_box, fan_label)

	// LED count
	led_label := auto_cast gtk_label_new(
		fmt.ctprintf("%d LEDs", device.led_count),
	)
	gtk_label_set_markup(
		auto_cast led_label,
		fmt.ctprintf("<span size='9000'>%d LEDs</span>", device.led_count),
	)
	gtk_label_set_xalign(auto_cast led_label, 0.0)
	gtk_widget_set_hexpand(led_label, true)
	gtk_box_append(auto_cast visual_box, led_label)

	// Info row: Channel + Binding status
	info_box := auto_cast gtk_box_new(.HORIZONTAL, 8)
	gtk_box_append(auto_cast main_box, info_box)

	// Channel
	channel_label := auto_cast gtk_label_new(
		fmt.ctprintf("Ch %d", device.channel),
	)
	gtk_label_set_markup(
		auto_cast channel_label,
		fmt.ctprintf("<span size='9000'>Ch %d</span>", device.channel),
	)
	gtk_label_set_xalign(auto_cast channel_label, 0.0)
	gtk_widget_set_hexpand(channel_label, true)
	gtk_box_append(auto_cast info_box, channel_label)

	// Binding status (color-coded)
	status_text: cstring = device.bound ? "Bound" : "Unbound"
	status_label := auto_cast gtk_label_new(status_text)
	gtk_label_set_markup(
		auto_cast status_label,
		fmt.ctprintf(
			"<span size='9000' weight='bold' foreground='%s'>%s</span>",
			device.bound ? "#26a269" : "#e5a50a",
			status_text,
		),
	)
	gtk_box_append(auto_cast info_box, status_label)

	return button
}

// Device toggle handler
on_device_toggled :: proc "c" (button: GtkToggleButton, user_data: rawptr) {
	context = runtime.default_context()
	state := global_state
	if state == nil do return

	device_idx := cast(^int)user_data
	if device_idx^ >= 0 && device_idx^ < len(state.selected_devices) {
		is_active := gtk_toggle_button_get_active(button)
		state.selected_devices[device_idx^] = bool(is_active)

		if is_active {
			fmt.printfln("Selected device %d", device_idx^)

			// Only send identify if not in batch mode
			if !state.batch_selecting && device_idx^ < len(state.devices) {
				device := state.devices[device_idx^]
				fmt.printfln("Identifying device: %s", device.mac_str)
				send_identify_request(device)
			}
		} else {
			fmt.printfln("Deselected device %d", device_idx^)
		}
	}
}

