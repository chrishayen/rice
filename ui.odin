// ui.odin
// Lian Li Fan Control GUI - GTK4 + libadwaita version in Odin
// Modern GNOME design with Adwaita widgets

package main

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:strings"
import rl "ricelib"

// GTK4 + libadwaita bindings
foreign import gtk "system:gtk-4"
foreign import adw "system:adwaita-1"
foreign import glib "system:glib-2.0"
foreign import gio "system:gio-2.0"
foreign import gobject "system:gobject-2.0"
foreign import cairo "system:cairo"

// GTK types
GtkWidget :: distinct rawptr
GtkApplication :: distinct rawptr
GtkWindow :: distinct rawptr
GdkSurface :: distinct rawptr
GtkBox :: distinct rawptr
GtkPaned :: distinct rawptr
GtkLabel :: distinct rawptr
GtkButton :: distinct rawptr
GtkToggleButton :: distinct rawptr
GtkScale :: distinct rawptr
GtkAdjustment :: distinct rawptr
GtkDrawingArea :: distinct rawptr
GtkColorButton :: distinct rawptr
GtkCheckButton :: distinct rawptr
GtkFrame :: distinct rawptr
GtkScrolledWindow :: distinct rawptr
GtkDropDown :: distinct rawptr
GtkStringList :: distinct rawptr
GApplication :: distinct rawptr

// Adwaita types
AdwApplication :: distinct rawptr
AdwApplicationWindow :: distinct rawptr
AdwHeaderBar :: distinct rawptr
AdwPreferencesGroup :: distinct rawptr
AdwActionRow :: distinct rawptr
AdwTabView :: distinct rawptr
AdwTabBar :: distinct rawptr
AdwTabPage :: distinct rawptr

GdkRGBA :: struct {
	red:   c.double,
	green: c.double,
	blue:  c.double,
	alpha: c.double,
}
cairo_t :: distinct rawptr

GtkOrientation :: enum c.int {
	HORIZONTAL = 0,
	VERTICAL   = 1,
}

GtkAlign :: enum c.int {
	FILL   = 0,
	START  = 1,
	END    = 2,
	CENTER = 3,
}

GtkPolicyType :: enum c.int {
	ALWAYS    = 0,
	AUTOMATIC = 1,
	NEVER     = 2,
}

// GTK functions
@(default_calling_convention = "c")
foreign gtk {
	gtk_init :: proc() ---

	gtk_box_new :: proc(orientation: GtkOrientation, spacing: c.int) -> GtkWidget ---
	gtk_box_append :: proc(box: GtkBox, child: GtkWidget) ---
	gtk_box_prepend :: proc(box: GtkBox, child: GtkWidget) ---
	gtk_box_set_homogeneous :: proc(box: GtkBox, homogeneous: c.bool) ---

	gtk_paned_new :: proc(orientation: GtkOrientation) -> GtkWidget ---
	gtk_paned_set_start_child :: proc(paned: GtkPaned, child: GtkWidget) ---
	gtk_paned_set_end_child :: proc(paned: GtkPaned, child: GtkWidget) ---
	gtk_paned_set_position :: proc(paned: GtkPaned, position: c.int) ---
	gtk_paned_set_resize_start_child :: proc(paned: GtkPaned, resize: c.bool) ---
	gtk_paned_set_shrink_start_child :: proc(paned: GtkPaned, shrink: c.bool) ---
	gtk_paned_set_resize_end_child :: proc(paned: GtkPaned, resize: c.bool) ---
	gtk_paned_set_shrink_end_child :: proc(paned: GtkPaned, shrink: c.bool) ---

	gtk_label_new :: proc(text: cstring) -> GtkWidget ---
	gtk_label_set_markup :: proc(label: GtkLabel, markup: cstring) ---
	gtk_label_set_xalign :: proc(label: GtkLabel, xalign: c.float) ---
	gtk_label_set_wrap :: proc(label: GtkLabel, wrap: c.bool) ---

	gtk_button_new_with_label :: proc(label: cstring) -> GtkWidget ---

	gtk_toggle_button_new :: proc() -> GtkWidget ---
	gtk_toggle_button_set_active :: proc(button: GtkToggleButton, is_active: c.bool) ---
	gtk_toggle_button_get_active :: proc(button: GtkToggleButton) -> c.bool ---

	gtk_scale_new_with_range :: proc(orientation: GtkOrientation, min, max, step: c.double) -> GtkWidget ---
	gtk_scale_set_digits :: proc(scale: GtkScale, digits: c.int) ---
	gtk_scale_set_draw_value :: proc(scale: GtkScale, draw_value: c.bool) ---
	gtk_range_get_value :: proc(range: rawptr) -> c.double ---
	gtk_range_set_value :: proc(range: rawptr, value: c.double) ---

	gtk_color_button_new :: proc() -> GtkWidget ---
	gtk_color_chooser_get_rgba :: proc(chooser: rawptr, color: ^GdkRGBA) ---
	gtk_color_chooser_set_rgba :: proc(chooser: rawptr, color: ^GdkRGBA) ---

	gtk_check_button_new :: proc() -> GtkWidget ---
	gtk_check_button_set_group :: proc(check: GtkCheckButton, group: GtkCheckButton) ---
	gtk_check_button_set_active :: proc(check: GtkCheckButton, active: c.bool) ---
	gtk_check_button_get_active :: proc(check: GtkCheckButton) -> c.bool ---

	gtk_drawing_area_new :: proc() -> GtkWidget ---
	gtk_drawing_area_set_content_width :: proc(area: GtkDrawingArea, width: c.int) ---
	gtk_drawing_area_set_content_height :: proc(area: GtkDrawingArea, height: c.int) ---
	gtk_drawing_area_set_draw_func :: proc(area: GtkDrawingArea, draw_func: proc "c" (area: GtkDrawingArea, cr: cairo_t, width, height: c.int, user_data: rawptr), user_data: rawptr, destroy: rawptr) ---

	gtk_frame_new :: proc(label: cstring) -> GtkWidget ---
	gtk_frame_set_child :: proc(frame: GtkFrame, child: GtkWidget) ---

	gtk_scrolled_window_new :: proc() -> GtkWidget ---
	gtk_scrolled_window_set_child :: proc(scrolled: GtkScrolledWindow, child: GtkWidget) ---
	gtk_scrolled_window_set_policy :: proc(scrolled: GtkScrolledWindow, hpolicy, vpolicy: GtkPolicyType) ---

	gtk_widget_set_margin_start :: proc(widget: GtkWidget, margin: c.int) ---
	gtk_widget_set_margin_end :: proc(widget: GtkWidget, margin: c.int) ---
	gtk_widget_set_margin_top :: proc(widget: GtkWidget, margin: c.int) ---
	gtk_widget_set_margin_bottom :: proc(widget: GtkWidget, margin: c.int) ---
	gtk_widget_set_hexpand :: proc(widget: GtkWidget, expand: c.bool) ---
	gtk_widget_set_vexpand :: proc(widget: GtkWidget, expand: c.bool) ---
	gtk_widget_set_halign :: proc(widget: GtkWidget, align: GtkAlign) ---
	gtk_widget_set_valign :: proc(widget: GtkWidget, align: GtkAlign) ---
	gtk_widget_set_size_request :: proc(widget: GtkWidget, width, height: c.int) ---
	gtk_widget_queue_draw :: proc(widget: GtkWidget) ---
	gtk_widget_add_css_class :: proc(widget: GtkWidget, css_class: cstring) ---

	gtk_window_set_default_size :: proc(window: GtkWindow, width, height: c.int) ---
	gtk_native_get_surface :: proc(native: rawptr) -> GdkSurface ---

	gtk_string_list_new :: proc(strings: ^cstring) -> GtkStringList ---
	gtk_string_list_append :: proc(list: GtkStringList, string: cstring) ---
	gtk_drop_down_new :: proc(model: rawptr, expression: rawptr) -> GtkWidget ---
	gtk_drop_down_set_selected :: proc(dropdown: GtkDropDown, position: c.uint) ---
	gtk_drop_down_get_selected :: proc(dropdown: GtkDropDown) -> c.uint ---
}

// Adwaita functions
@(default_calling_convention = "c")
foreign adw {
	adw_application_new :: proc(app_id: cstring, flags: c.int) -> AdwApplication ---
	adw_application_window_new :: proc(app: AdwApplication) -> GtkWidget ---
	adw_application_window_set_content :: proc(window: AdwApplicationWindow, content: GtkWidget) ---
	adw_window_title_new :: proc(title: cstring, subtitle: cstring) -> GtkWidget ---

	adw_header_bar_new :: proc() -> GtkWidget ---
	adw_header_bar_pack_start :: proc(header: AdwHeaderBar, child: GtkWidget) ---
	adw_header_bar_pack_end :: proc(header: AdwHeaderBar, child: GtkWidget) ---
	adw_header_bar_set_title_widget :: proc(header: AdwHeaderBar, widget: GtkWidget) ---

	adw_preferences_group_new :: proc() -> GtkWidget ---
	adw_preferences_group_set_title :: proc(group: AdwPreferencesGroup, title: cstring) ---
	adw_preferences_group_set_description :: proc(group: AdwPreferencesGroup, description: cstring) ---
	adw_preferences_group_add :: proc(group: AdwPreferencesGroup, child: GtkWidget) ---

	adw_action_row_new :: proc() -> GtkWidget ---
	adw_action_row_add_suffix :: proc(row: AdwActionRow, widget: GtkWidget) ---
	adw_action_row_add_prefix :: proc(row: AdwActionRow, widget: GtkWidget) ---
	adw_action_row_set_activatable_widget :: proc(row: AdwActionRow, widget: GtkWidget) ---
	adw_action_row_set_subtitle :: proc(row: AdwActionRow, subtitle: cstring) ---

	// Title/subtitle for action rows come from PreferencesRow (parent class)
	adw_preferences_row_set_title :: proc(row: rawptr, title: cstring) ---

	adw_tab_view_new :: proc() -> GtkWidget ---
	adw_tab_view_append :: proc(view: AdwTabView, child: GtkWidget) -> AdwTabPage ---
	adw_tab_view_get_page :: proc(view: AdwTabView, child: GtkWidget) -> AdwTabPage ---

	adw_tab_bar_new :: proc() -> GtkWidget ---
	adw_tab_bar_set_view :: proc(bar: AdwTabBar, view: AdwTabView) ---

	adw_tab_page_set_title :: proc(page: AdwTabPage, title: cstring) ---
	adw_tab_page_set_icon :: proc(page: AdwTabPage, icon: rawptr) ---
}

// GIO functions
@(default_calling_convention = "c")
foreign gio {
	g_application_run :: proc(app: GApplication, argc: c.int, argv: rawptr) -> c.int ---
}

@(default_calling_convention = "c")
foreign gobject {
	g_signal_connect_data :: proc(instance: rawptr, detailed_signal: cstring, c_handler: rawptr, data: rawptr, destroy_data: rawptr, connect_flags: c.int) -> c.ulong ---
	g_object_unref :: proc(object: rawptr) ---
}

@(default_calling_convention = "c")
foreign glib {
	g_timeout_add :: proc(interval: c.uint, function: rawptr, data: rawptr) -> c.uint ---
}

// Cairo functions
@(default_calling_convention = "c")
foreign cairo {
	cairo_set_source_rgb :: proc(cr: cairo_t, r, g, b: c.double) ---
	cairo_set_source_rgba :: proc(cr: cairo_t, r, g, b, a: c.double) ---
	cairo_paint :: proc(cr: cairo_t) ---
	cairo_arc :: proc(cr: cairo_t, xc, yc, radius, angle1, angle2: c.double) ---
	cairo_fill :: proc(cr: cairo_t) ---
	cairo_stroke :: proc(cr: cairo_t) ---
	cairo_move_to :: proc(cr: cairo_t, x, y: c.double) ---
	cairo_line_to :: proc(cr: cairo_t, x, y: c.double) ---
	cairo_close_path :: proc(cr: cairo_t) ---
	cairo_set_line_width :: proc(cr: cairo_t, width: c.double) ---
	cairo_select_font_face :: proc(cr: cairo_t, family: cstring, slant, weight: c.int) ---
	cairo_set_font_size :: proc(cr: cairo_t, size: c.double) ---
	cairo_show_text :: proc(cr: cairo_t, text: cstring) ---
	cairo_text_extents :: proc(cr: cairo_t, text: cstring, extents: ^cairo_text_extents_t) ---
}

cairo_text_extents_t :: struct {
	x_bearing: c.double,
	y_bearing: c.double,
	width:     c.double,
	height:    c.double,
	x_advance: c.double,
	y_advance: c.double,
}

// Application state
App_State :: struct {
	window:                AdwApplicationWindow,
	selected_effect:       int,
	color1:                GdkRGBA,
	color2:                GdkRGBA,
	brightness:            f64,

	// Widgets
	preview_area:          GtkDrawingArea,
	brightness_scale:      GtkScale,
	color1_button:         GtkColorButton,
	color2_button:         GtkColorButton,
	effect_dropdown:       GtkDropDown,
	device_list_box:       GtkBox,
	device_toggle_buttons: [dynamic]GtkToggleButton,

	// Preview data
	led_colors:            [dynamic][3]u8,
	devices:               [dynamic]Device,
	selected_devices:      [dynamic]bool,

	// Flag to prevent individual identify during batch operations
	batch_selecting:       bool,
}

Device :: struct {
	mac_str:   string,
	rx_type:   u8,
	channel:   u8,
	bound:     bool,
	led_count: int,
	fan_count: int,
}

Effect_Info :: struct {
	name:        string,
	description: string,
	has_color1:  bool,
	has_color2:  bool,
}

EFFECTS := [?]Effect_Info {
	{"Static Color", "Solid color on all LEDs", true, false},
	{"Rainbow", "Static rainbow gradient", false, false},
	{"Alternating", "Two colors alternating", true, true},
	{"Alternating Spin", "Rotating alternating pattern", true, true},
	{"Rainbow Morph", "Morphing rainbow animation", false, false},
	{"Breathing", "Fade in/out breathing effect", true, false},
	{"Runway", "Sequential runway animation", false, false},
	{"Meteor", "Meteor trail animation", false, false},
	{"Color Cycle", "Cycle through colors", false, false},
	{"Wave", "Wave pattern animation", false, false},
	{"Meteor Shower", "Multiple meteors", false, false},
	{"Twinkle", "Random twinkling stars", false, false},
}

global_state: ^App_State

run_ui :: proc() {
	gtk_init()

	state := new(App_State)
	defer free(state)

	global_state = state

	// Initialize state
	state.selected_effect = 0
	state.color1 = {1.0, 0.0, 0.0, 1.0}
	state.color2 = {0.0, 0.0, 1.0, 1.0}
	state.brightness = 100.0
	state.devices = make([dynamic]Device)
	state.selected_devices = make([dynamic]bool)
	state.device_toggle_buttons = make([dynamic]GtkToggleButton)

	// Create Adwaita application
	app := adw_application_new("dev.shotgun.rice", 0)
	g_signal_connect_data(app, "activate", auto_cast on_activate, state, nil, 0)

	status := g_application_run(auto_cast app, 0, nil)

	// Cleanup
	delete(state.led_colors)
	delete(state.devices)
	delete(state.selected_devices)
	delete(state.device_toggle_buttons)
}

on_activate :: proc "c" (app: AdwApplication, user_data: rawptr) {
	context = runtime.default_context()

	state := cast(^App_State)user_data

	// Create window
	window := auto_cast adw_application_window_new(app)
	state.window = auto_cast window

	// Set default size instead of size request for better floating window behavior
	gtk_window_set_default_size(auto_cast window, 1200, 800)

	// Main container
	main_box := auto_cast gtk_box_new(.VERTICAL, 0)

	// Header bar
	header := auto_cast adw_header_bar_new()
	gtk_box_prepend(auto_cast main_box, header)

	// Set window title
	title_widget := adw_window_title_new("Rice Studio Beta", "")
	adw_header_bar_set_title_widget(auto_cast header, title_widget)

	// Refresh button
	refresh_btn := auto_cast gtk_button_new_with_label("Refresh Devices")
	g_signal_connect_data(refresh_btn, "clicked", auto_cast on_refresh_clicked, state, nil, 0)
	adw_header_bar_pack_start(auto_cast header, refresh_btn)

	// Create paned layout (sidebar + content)
	paned := auto_cast gtk_paned_new(.HORIZONTAL)
	gtk_widget_set_vexpand(paned, true)
	gtk_box_append(auto_cast main_box, paned)

	// Left side - device list
	device_panel := build_device_panel(state)
	gtk_paned_set_start_child(auto_cast paned, device_panel)
	gtk_paned_set_resize_start_child(auto_cast paned, false)
	gtk_paned_set_shrink_start_child(auto_cast paned, false)

	// Right side - tabs
	tab_container := build_tabs(state)
	gtk_paned_set_end_child(auto_cast paned, tab_container)

	gtk_paned_set_position(auto_cast paned, 300)

	// Set content
	adw_application_window_set_content(auto_cast window, main_box)

	// Show window
	g_signal_connect_data(
		window,
		"close-request",
		auto_cast proc "c" () -> c.bool {return false},
		nil,
		nil,
		0,
	)

	// Manual show
	foreign gtk {
		gtk_widget_show :: proc(widget: GtkWidget) ---
	}
	gtk_widget_show(window)

	// Schedule initial device poll after UI is shown (500ms delay to avoid blocking startup)
	g_timeout_add(500, auto_cast on_initial_poll, state)
}

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

	// Clear existing children
	foreign gtk {
		gtk_widget_get_first_child :: proc(widget: GtkWidget) -> GtkWidget ---
		gtk_widget_get_next_sibling :: proc(widget: GtkWidget) -> GtkWidget ---
		gtk_box_remove :: proc(box: GtkBox, child: GtkWidget) ---
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

build_device_card :: proc(device: Device, state: ^App_State, device_idx: int) -> GtkWidget {
	// Create a toggle button so the device card is selectable
	foreign gtk {
		gtk_button_set_child :: proc(button: GtkButton, child: GtkWidget) ---
	}

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

	box := auto_cast gtk_box_new(.VERTICAL, 6)
	gtk_widget_set_margin_start(box, 12)
	gtk_widget_set_margin_end(box, 12)
	gtk_widget_set_margin_top(box, 12)
	gtk_widget_set_margin_bottom(box, 12)
	gtk_button_set_child(auto_cast button, box)

	// MAC address
	mac_cstr := strings.clone_to_cstring(device.mac_str)
	defer delete(mac_cstr)
	mac_label := auto_cast gtk_label_new(mac_cstr)
	gtk_label_set_markup(
		auto_cast mac_label,
		fmt.ctprintf("<span weight='bold' size='12000'>%s</span>", mac_cstr),
	)
	gtk_label_set_xalign(auto_cast mac_label, 0.0)
	gtk_box_append(auto_cast box, mac_label)

	// Type info
	type_name: cstring
	switch device.rx_type {
	case 1:
		type_name = "SL-LCD"
	case 2:
		type_name = "TL"
	case 3:
		type_name = "TL3"
	case:
		type_name = "Unknown"
	}

	info_label := auto_cast gtk_label_new(
		fmt.ctprintf("%s • Channel %d", type_name, device.channel),
	)
	gtk_label_set_markup(
		auto_cast info_label,
		fmt.ctprintf("<span size='10000'>%s • Channel %d</span>", type_name, device.channel),
	)
	gtk_label_set_xalign(auto_cast info_label, 0.0)
	gtk_box_append(auto_cast box, info_label)

	// Status
	status_color := device.bound ? "success" : "warning"
	status_text: cstring = device.bound ? "Bound" : "Unbound"
	status_label := auto_cast gtk_label_new(status_text)
	gtk_label_set_markup(
		auto_cast status_label,
		fmt.ctprintf(
			"<span size='10000' foreground='%s'>%s</span>",
			device.bound ? "#26a269" : "#e5a50a",
			status_text,
		),
	)
	gtk_label_set_xalign(auto_cast status_label, 0.0)
	gtk_box_append(auto_cast box, status_label)

	return button
}

build_tabs :: proc(state: ^App_State) -> GtkWidget {
	container := auto_cast gtk_box_new(.VERTICAL, 0)

	// Tab view
	tab_view := auto_cast adw_tab_view_new()
	gtk_widget_set_vexpand(tab_view, true)

	// Tab bar
	tab_bar := auto_cast adw_tab_bar_new()
	adw_tab_bar_set_view(auto_cast tab_bar, auto_cast tab_view)
	gtk_box_append(auto_cast container, tab_bar)
	gtk_box_append(auto_cast container, tab_view)

	// LED Effects tab
	led_page := build_led_effects_page(state)
	led_tab := adw_tab_view_append(auto_cast tab_view, led_page)
	adw_tab_page_set_title(led_tab, "LED Effects")

	// LCD tab
	lcd_page := build_lcd_page(state)
	lcd_tab := adw_tab_view_append(auto_cast tab_view, lcd_page)
	adw_tab_page_set_title(lcd_tab, "LCD Display")

	// Settings tab
	settings_page := build_settings_page(state)
	settings_tab := adw_tab_view_append(auto_cast tab_view, settings_page)
	adw_tab_page_set_title(settings_tab, "Settings")

	return container
}

build_led_effects_page :: proc(state: ^App_State) -> GtkWidget {
	paned := auto_cast gtk_paned_new(.HORIZONTAL)

	// Left: preview
	preview := build_preview_panel(state)
	gtk_paned_set_start_child(auto_cast paned, preview)

	// Right: controls
	controls := build_effect_controls(state)
	gtk_paned_set_end_child(auto_cast paned, controls)
	gtk_paned_set_resize_end_child(auto_cast paned, false)
	gtk_paned_set_shrink_end_child(auto_cast paned, false)

	gtk_paned_set_position(auto_cast paned, 800)

	return paned
}

build_effect_controls :: proc(state: ^App_State) -> GtkWidget {
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)

	box := auto_cast gtk_box_new(.VERTICAL, 24)
	gtk_widget_set_margin_start(box, 20)
	gtk_widget_set_margin_end(box, 20)
	gtk_widget_set_margin_top(box, 20)
	gtk_widget_set_margin_bottom(box, 20)
	gtk_scrolled_window_set_child(auto_cast scrolled, box)

	// Effect selector group
	effect_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast effect_group, "Effect")
	adw_preferences_group_set_description(auto_cast effect_group, "Choose an LED animation effect")
	gtk_box_append(auto_cast box, effect_group)

	// Effect selector row
	effect_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(effect_row, "LED Effect")

	// Create string list for dropdown
	string_list := gtk_string_list_new(nil)
	for effect in EFFECTS {
		name_cstr := strings.clone_to_cstring(effect.name)
		defer delete(name_cstr)
		gtk_string_list_append(string_list, name_cstr)
	}

	// Create dropdown
	state.effect_dropdown = auto_cast gtk_drop_down_new(string_list, nil)
	gtk_drop_down_set_selected(state.effect_dropdown, 0)
	adw_action_row_add_suffix(auto_cast effect_row, auto_cast state.effect_dropdown)
	adw_preferences_group_add(auto_cast effect_group, effect_row)

	// Connect signal for dropdown
	g_signal_connect_data(state.effect_dropdown, "notify::selected", auto_cast proc "c" (dropdown: GtkDropDown, pspec: rawptr, user_data: rawptr) {
			context = runtime.default_context()
			state := global_state
			if state == nil do return

			selected := gtk_drop_down_get_selected(dropdown)
			state.selected_effect = int(selected)
		}, nil, nil, 0)

	// Color controls
	color_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast color_group, "Colors")
	gtk_box_append(auto_cast box, color_group)

	// Color 1 row
	color1_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(color1_row, "Primary Color")
	state.color1_button = auto_cast gtk_color_button_new()
	gtk_color_chooser_set_rgba(state.color1_button, &state.color1)
	adw_action_row_add_suffix(auto_cast color1_row, auto_cast state.color1_button)
	adw_preferences_group_add(auto_cast color_group, color1_row)

	// Color 2 row
	color2_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(color2_row, "Secondary Color")
	state.color2_button = auto_cast gtk_color_button_new()
	gtk_color_chooser_set_rgba(state.color2_button, &state.color2)
	adw_action_row_add_suffix(auto_cast color2_row, auto_cast state.color2_button)
	adw_preferences_group_add(auto_cast color_group, color2_row)

	// Brightness control
	brightness_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast brightness_group, "Brightness")
	gtk_box_append(auto_cast box, brightness_group)

	brightness_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(brightness_row, "LED Brightness")

	state.brightness_scale = auto_cast gtk_scale_new_with_range(.HORIZONTAL, 0, 100, 1)
	gtk_range_set_value(state.brightness_scale, state.brightness)
	gtk_scale_set_digits(state.brightness_scale, 0)
	gtk_scale_set_draw_value(state.brightness_scale, true)
	gtk_widget_set_hexpand(auto_cast state.brightness_scale, true)
	gtk_widget_set_size_request(auto_cast state.brightness_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast brightness_row, auto_cast state.brightness_scale)

	adw_preferences_group_add(auto_cast brightness_group, brightness_row)

	// Action buttons
	button_box := auto_cast gtk_box_new(.HORIZONTAL, 12)
	gtk_widget_set_halign(button_box, .CENTER)
	gtk_widget_set_margin_top(button_box, 20)
	gtk_box_append(auto_cast box, button_box)

	preview_btn := auto_cast gtk_button_new_with_label("Preview")
	gtk_widget_add_css_class(preview_btn, "pill")
	gtk_widget_set_size_request(preview_btn, 150, 48)
	g_signal_connect_data(preview_btn, "clicked", auto_cast on_preview_clicked, state, nil, 0)
	gtk_box_append(auto_cast button_box, preview_btn)

	apply_btn := auto_cast gtk_button_new_with_label("Apply to Fans")
	gtk_widget_add_css_class(apply_btn, "suggested-action")
	gtk_widget_add_css_class(apply_btn, "pill")
	gtk_widget_set_size_request(apply_btn, 150, 48)
	g_signal_connect_data(apply_btn, "clicked", auto_cast on_apply_clicked, state, nil, 0)
	gtk_box_append(auto_cast button_box, apply_btn)

	return scrolled
}

build_preview_panel :: proc(state: ^App_State) -> GtkWidget {
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)

	box := auto_cast gtk_box_new(.VERTICAL, 12)
	gtk_widget_set_margin_start(box, 20)
	gtk_widget_set_margin_end(box, 20)
	gtk_widget_set_margin_top(box, 20)
	gtk_widget_set_margin_bottom(box, 20)
	gtk_scrolled_window_set_child(auto_cast scrolled, box)

	title := auto_cast gtk_label_new("Effect Preview")
	gtk_label_set_markup(auto_cast title, "<span size='13000' weight='bold'>Effect Preview</span>")
	gtk_label_set_xalign(auto_cast title, 0.0)
	gtk_box_append(auto_cast box, title)

	// Frame for preview
	frame := auto_cast gtk_frame_new(nil)
	gtk_widget_set_vexpand(frame, true)
	gtk_box_append(auto_cast box, frame)

	// Drawing area
	state.preview_area = auto_cast gtk_drawing_area_new()
	gtk_drawing_area_set_content_width(state.preview_area, 600)
	gtk_drawing_area_set_content_height(state.preview_area, 400)
	gtk_drawing_area_set_draw_func(state.preview_area, draw_preview, state, nil)
	gtk_frame_set_child(auto_cast frame, auto_cast state.preview_area)

	return scrolled
}

build_lcd_page :: proc(state: ^App_State) -> GtkWidget {
	box := auto_cast gtk_box_new(.VERTICAL, 20)
	gtk_widget_set_margin_start(box, 40)
	gtk_widget_set_margin_top(box, 40)

	title := auto_cast gtk_label_new("LCD Display Control")
	gtk_label_set_markup(
		auto_cast title,
		"<span size='18000' weight='bold'>LCD Display Control</span>",
	)
	gtk_box_append(auto_cast box, title)

	desc := auto_cast gtk_label_new("(Coming soon)")
	gtk_widget_add_css_class(desc, "dim-label")
	gtk_box_append(auto_cast box, desc)

	return box
}

build_settings_page :: proc(state: ^App_State) -> GtkWidget {
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)

	box := auto_cast gtk_box_new(.VERTICAL, 20)
	gtk_widget_set_margin_start(box, 40)
	gtk_widget_set_margin_end(box, 40)
	gtk_widget_set_margin_top(box, 40)
	gtk_widget_set_margin_bottom(box, 40)
	gtk_scrolled_window_set_child(auto_cast scrolled, box)

	// Channel settings
	channel_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast channel_group, "RF Channel")
	adw_preferences_group_set_description(
		auto_cast channel_group,
		"Configure the wireless RF channel",
	)
	gtk_box_append(auto_cast box, channel_group)

	channel_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(channel_row, "Channel")
	adw_action_row_set_subtitle(auto_cast channel_row, "Current: 39")
	adw_preferences_group_add(auto_cast channel_group, channel_row)

	return scrolled
}

// Drawing function for preview
draw_preview :: proc "c" (
	area: GtkDrawingArea,
	cr: cairo_t,
	width, height: c.int,
	user_data: rawptr,
) {
	context = runtime.default_context()

	state := cast(^App_State)user_data

	// Background
	cairo_set_source_rgb(cr, 0.1, 0.1, 0.1)
	cairo_paint(cr)

	if len(state.devices) == 0 {
		// Show message
		cairo_set_source_rgb(cr, 0.5, 0.5, 0.5)
		cairo_select_font_face(cr, "Inter", 0, 0)
		cairo_set_font_size(cr, 16)
		cairo_move_to(cr, c.double(width) / 2 - 80, c.double(height) / 2)
		cairo_show_text(cr, "No devices configured")
		return
	}

	// Calculate layout
	total_fans := 0
	for device in state.devices {
		total_fans += device.fan_count
	}

	if total_fans == 0 do return

	cols := min(3, total_fans)
	rows := (total_fans + cols - 1) / cols

	fan_width := f64(width) / f64(cols)
	fan_height := f64(height) / f64(rows)

	led_offset := 0
	fan_idx := 0

	for device in state.devices {
		for fan in 0 ..< device.fan_count {
			row := fan_idx / cols
			col := fan_idx % cols

			center_x := f64(col) * fan_width + fan_width / 2
			center_y := f64(row) * fan_height + fan_height / 2

			leds_per_fan := device.led_count / device.fan_count

			draw_fan_hexagon(
				cr,
				center_x,
				center_y,
				leds_per_fan,
				led_offset,
				state,
				device.rx_type,
			)

			led_offset += leds_per_fan
			fan_idx += 1
		}
	}
}

draw_fan_hexagon :: proc(
	cr: cairo_t,
	center_x, center_y: f64,
	num_leds, led_offset: int,
	state: ^App_State,
	rx_type: u8,
) {
	FAN_RADIUS :: 60.0
	LED_RADIUS :: 4.0

	// Draw hexagon outline
	for i in 0 ..< 6 {
		angle1 := f64(i) / 6.0 * 2.0 * math.PI - math.PI / 2.0
		angle2 := f64(i + 1) / 6.0 * 2.0 * math.PI - math.PI / 2.0

		x1 := center_x + FAN_RADIUS * math.cos(angle1)
		y1 := center_y + FAN_RADIUS * math.sin(angle1)
		x2 := center_x + FAN_RADIUS * math.cos(angle2)
		y2 := center_y + FAN_RADIUS * math.sin(angle2)

		cairo_move_to(cr, x1, y1)
		cairo_line_to(cr, x2, y2)
	}

	cairo_set_source_rgba(cr, 0.3, 0.3, 0.3, 0.5)
	cairo_set_line_width(cr, 2)
	cairo_stroke(cr)

	// Draw LEDs
	leds_per_edge := f64(num_leds) / 6.0

	for edge in 0 ..< 6 {
		angle1 := f64(edge) / 6.0 * 2.0 * math.PI - math.PI / 2.0
		angle2 := f64(edge + 1) / 6.0 * 2.0 * math.PI - math.PI / 2.0

		p1x := center_x + FAN_RADIUS * math.cos(angle1)
		p1y := center_y + FAN_RADIUS * math.sin(angle1)
		p2x := center_x + FAN_RADIUS * math.cos(angle2)
		p2y := center_y + FAN_RADIUS * math.sin(angle2)

		edge_start_led := int(f64(edge) * leds_per_edge)
		edge_end_led := int(f64(edge + 1) * leds_per_edge)
		edge_led_count := edge_end_led - edge_start_led

		for i in 0 ..< edge_led_count {
			t := (f64(i) + 0.5) / f64(edge_led_count)

			led_x := p1x + t * (p2x - p1x)
			led_y := p1y + t * (p2y - p1y)

			led_idx := edge_start_led + i
			if led_idx >= num_leds do break

			// Get LED color
			color_idx := led_offset + led_idx
			r, g, b: f64 = 0.1, 0.1, 0.1

			if color_idx >= 0 && color_idx < len(state.led_colors) {
				r = f64(state.led_colors[color_idx].r) / 255.0
				g = f64(state.led_colors[color_idx].g) / 255.0
				b = f64(state.led_colors[color_idx].b) / 255.0
			}

			// Draw LED
			cairo_set_source_rgb(cr, r, g, b)
			cairo_arc(cr, led_x, led_y, LED_RADIUS, 0, 2 * math.PI)
			cairo_fill(cr)

			// Draw glow
			if r > 0.1 || g > 0.1 || b > 0.1 {
				cairo_set_source_rgba(cr, r, g, b, 0.3)
				cairo_arc(cr, led_x, led_y, LED_RADIUS * 2, 0, 2 * math.PI)
				cairo_fill(cr)
			}
		}
	}

	// Draw label
	type_label: cstring
	switch rx_type {
	case 1:
		type_label = "SL"
	case 2:
		type_label = "TL"
	case 3:
		type_label = "TL3"
	case:
		type_label = "?"
	}

	cairo_set_source_rgb(cr, 0.7, 0.7, 0.7)
	cairo_select_font_face(cr, "Inter", 0, 1) // BOLD - Inter font for modern look
	cairo_set_font_size(cr, 12)

	extents: cairo_text_extents_t
	cairo_text_extents(cr, type_label, &extents)
	cairo_move_to(cr, center_x - extents.width / 2, center_y + extents.height / 2)
	cairo_show_text(cr, type_label)
}

// Callbacks
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

on_refresh_clicked :: proc "c" (button: GtkButton, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data
	fmt.println("Refreshing devices...")

	// Poll devices from service
	poll_devices_from_service(state)

	// Rebuild device list with new data
	rebuild_device_list(state)

	fmt.printfln("Loaded %d devices from service", len(state.devices))
}

on_preview_clicked :: proc "c" (button: GtkButton, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	// Get current brightness
	state.brightness = gtk_range_get_value(state.brightness_scale)

	// Get colors
	gtk_color_chooser_get_rgba(state.color1_button, &state.color1)
	gtk_color_chooser_get_rgba(state.color2_button, &state.color2)

	// Generate preview
	generate_preview(state)

	// Redraw
	gtk_widget_queue_draw(auto_cast state.preview_area)
}

on_apply_clicked :: proc "c" (button: GtkButton, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	fmt.printfln("Applying effect: %s", EFFECTS[state.selected_effect].name)
	// TODO: Call Python sl_led
}

// Effect generation
generate_preview :: proc(state: ^App_State) {
	total_leds := 0
	for device in state.devices {
		total_leds += device.led_count
	}

	if total_leds == 0 do return

	// Resize LED buffer
	delete(state.led_colors)
	state.led_colors = make([dynamic][3]u8, total_leds)

	// Generate based on effect
	switch state.selected_effect {
	case 0:
		// Static
		r := u8(state.color1.red * 255 * state.brightness / 100)
		g := u8(state.color1.green * 255 * state.brightness / 100)
		b := u8(state.color1.blue * 255 * state.brightness / 100)

		for i in 0 ..< total_leds {
			state.led_colors[i] = {r, g, b}
		}

	case 1:
		// Rainbow
		for i in 0 ..< total_leds {
			hue := f64(i) / f64(total_leds)
			color := hsv_to_rgb(hue, 1.0, state.brightness / 100.0)
			state.led_colors[i] = color
		}

	case 2:
		// Alternating
		for i in 0 ..< total_leds {
			if i % 2 == 0 {
				r := u8(state.color1.red * 255 * state.brightness / 100)
				g := u8(state.color1.green * 255 * state.brightness / 100)
				b := u8(state.color1.blue * 255 * state.brightness / 100)
				state.led_colors[i] = {r, g, b}
			} else {
				r := u8(state.color2.red * 255 * state.brightness / 100)
				g := u8(state.color2.green * 255 * state.brightness / 100)
				b := u8(state.color2.blue * 255 * state.brightness / 100)
				state.led_colors[i] = {r, g, b}
			}
		}

	case:
		// Default to dim
		for i in 0 ..< total_leds {
			state.led_colors[i] = {26, 26, 26}
		}
	}
}

hsv_to_rgb :: proc(h, s, v: f64) -> [3]u8 {
	c := v * s
	x := c * (1.0 - abs(math.mod(h * 6.0, 2.0) - 1.0))
	m := v - c

	r, g, b: f64

	h6 := h * 6.0
	if h6 < 1.0 {
		r, g, b = c, x, 0
	} else if h6 < 2.0 {
		r, g, b = x, c, 0
	} else if h6 < 3.0 {
		r, g, b = 0, c, x
	} else if h6 < 4.0 {
		r, g, b = 0, x, c
	} else if h6 < 5.0 {
		r, g, b = x, 0, c
	} else {
		r, g, b = c, 0, x
	}

	return {u8((r + m) * 255), u8((g + m) * 255), u8((b + m) * 255)}
}

// Poll devices from service via socket
poll_devices_from_service :: proc(state: ^App_State) {
	// Get socket path
	socket_path, path_err := rl.get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		return
	}

	// Connect to service (reconnect each time since service closes after each request)
	client, connect_err := rl.connect_to_server(socket_path)
	defer rl.close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		return
	}

	// Send Get_Devices request
	request := rl.IPC_Message {
		type    = .Get_Devices,
		payload = "",
	}

	send_err := rl.send_message(client.socket_fd, request)
	if send_err != .None {
		log_warn("Failed to send Get_Devices request: %v", send_err)
		return
	}

	// Receive response
	response, recv_err := rl.receive_message(client.socket_fd)
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

	cached_devices: []rl.Device_Cache_Entry
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
		// Calculate LED count based on fan type
		led_count := 0
		if cached_dev.rx_type == 1 {
			// SL fans: 40 LEDs per fan
			led_count = int(cached_dev.fan_num) * 40
		} else if cached_dev.rx_type == 2 || cached_dev.rx_type == 3 {
			// TL fans: 26 LEDs per fan
			led_count = int(cached_dev.fan_num) * 26
		}

		device := Device {
			mac_str   = cached_dev.mac_str,
			rx_type   = cached_dev.rx_type,
			channel   = cached_dev.channel,
			bound     = cached_dev.bound_to_us,
			led_count = led_count,
			fan_count = int(cached_dev.fan_num),
		}

		append(&state.devices, device)
	}

	log_info("Loaded %d devices from service", len(state.devices))
}

// Send identify requests for multiple devices to service
send_identify_requests :: proc(devices: []Device) {
	if len(devices) == 0 do return

	// Get socket path
	socket_path, path_err := rl.get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		return
	}

	// Connect to service
	client, connect_err := rl.connect_to_server(socket_path)
	defer rl.close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		return
	}

	// Build identify request with all devices
	device_infos := make([dynamic]rl.Identify_Device_Info, 0, len(devices))
	defer delete(device_infos)

	for device in devices {
		append(&device_infos, rl.Identify_Device_Info{
			mac_str = device.mac_str,
			rx_type = device.rx_type,
			channel = device.channel,
		})
	}

	identify_req := rl.Identify_Request{
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
	request := rl.IPC_Message{
		type = .Identify_Device,
		payload = string(json_data),
	}

	send_err := rl.send_message(client.socket_fd, request)
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

