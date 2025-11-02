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
GtkGesture :: distinct rawptr
GtkGestureDrag :: distinct rawptr
GdkModifierType :: distinct c.uint

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
	gtk_widget_get_first_child :: proc(widget: GtkWidget) -> GtkWidget ---
	gtk_widget_get_next_sibling :: proc(widget: GtkWidget) -> GtkWidget ---

	gtk_button_set_child :: proc(button: GtkButton, child: GtkWidget) ---

	gtk_box_remove :: proc(box: GtkBox, child: GtkWidget) ---

	gtk_window_set_default_size :: proc(window: GtkWindow, width, height: c.int) ---
	gtk_native_get_surface :: proc(native: rawptr) -> GdkSurface ---

	gtk_string_list_new :: proc(strings: ^cstring) -> GtkStringList ---
	gtk_string_list_append :: proc(list: GtkStringList, string: cstring) ---
	gtk_drop_down_new :: proc(model: rawptr, expression: rawptr) -> GtkWidget ---
	gtk_drop_down_set_selected :: proc(dropdown: GtkDropDown, position: c.uint) ---
	gtk_drop_down_get_selected :: proc(dropdown: GtkDropDown) -> c.uint ---

	gtk_gesture_drag_new :: proc() -> GtkGesture ---
	gtk_widget_add_controller :: proc(widget: GtkWidget, controller: rawptr) ---
	gtk_event_controller_set_propagation_phase :: proc(controller: rawptr, phase: c.int) ---
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
	cairo_save :: proc(cr: cairo_t) ---
	cairo_restore :: proc(cr: cairo_t) ---
	cairo_translate :: proc(cr: cairo_t, tx, ty: c.double) ---
	cairo_rotate :: proc(cr: cairo_t, angle: c.double) ---
	cairo_scale :: proc(cr: cairo_t, sx, sy: c.double) ---
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

	// 3D model rendering
	model:                 Model,
	view:                  View_State,
	model_loaded:          bool,

	// Mouse drag state for 3D rotation
	drag_start_x:          f64,
	drag_start_y:          f64,
	drag_start_rot_x:      f64,
	drag_start_rot_y:      f64,

	// Flag to prevent individual identify during batch operations
	batch_selecting:       bool,
}

Device :: struct {
	mac_str:       string,
	rx_type:       u8,
	channel:       u8,
	bound:         bool,
	led_count:     int,
	fan_count:     int,
	dev_type_name: string,
	fan_types:     [4]u8,
	has_lcd:       bool,
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

	// Initialize 3D view
	state.view = View_State {
		rotation_x = 0.3,
		rotation_y = 0.5,
		zoom       = 1.0,
	}

	// Load 3D model
	model, ok := parse_obj_file("sl120-finally.obj")
	if ok {
		state.model = model
		state.model_loaded = true
		log_info("3D model loaded successfully")
	} else {
		log_warn("Failed to load 3D model")
		state.model_loaded = false
	}

	// Create Adwaita application
	app := adw_application_new("dev.shotgun.rice", 0)
	g_signal_connect_data(app, "activate", auto_cast on_activate, state, nil, 0)

	status := g_application_run(auto_cast app, 0, nil)

	// Cleanup
	delete(state.led_colors)
	delete(state.devices)
	delete(state.selected_devices)
	delete(state.device_toggle_buttons)
	if state.model_loaded {
		free_model(&state.model)
	}
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
	gtk_paned_set_resize_start_child(auto_cast paned, true)
	gtk_paned_set_shrink_start_child(auto_cast paned, true)

	// Right: controls
	controls := build_effect_controls(state)
	gtk_paned_set_end_child(auto_cast paned, controls)
	gtk_paned_set_resize_end_child(auto_cast paned, false)
	gtk_paned_set_shrink_end_child(auto_cast paned, false)

	gtk_paned_set_position(auto_cast paned, 400)

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
	gtk_drawing_area_set_content_width(state.preview_area, 300)
	gtk_drawing_area_set_content_height(state.preview_area, 300)
	gtk_drawing_area_set_draw_func(state.preview_area, draw_preview, state, nil)
	gtk_frame_set_child(auto_cast frame, auto_cast state.preview_area)

	// Add drag gesture for 3D rotation
	drag_gesture := gtk_gesture_drag_new()
	gtk_event_controller_set_propagation_phase(drag_gesture, 3) // GTK_PHASE_BUBBLE
	g_signal_connect_data(drag_gesture, "drag-begin", auto_cast on_drag_begin, state, nil, 0)
	g_signal_connect_data(drag_gesture, "drag-update", auto_cast on_drag_update, state, nil, 0)
	gtk_widget_add_controller(auto_cast state.preview_area, drag_gesture)

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

	// Render the 3D model if loaded
	if state.model_loaded {
		render_model(cr, &state.model, state.view, width, height)
		return
	}

	// Fallback: original 2D fan visualization
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

			// Get the fan type for this specific fan
			fan_type := device.fan_types[fan]

			draw_fan_circle(
				cr,
				center_x,
				center_y,
				leds_per_fan,
				led_offset,
				state,
				fan_type,
			)

			led_offset += leds_per_fan
			fan_idx += 1
		}
	}
}

draw_fan_circle :: proc(
	cr: cairo_t,
	center_x, center_y: f64,
	num_leds, led_offset: int,
	state: ^App_State,
	fan_type: u8,
) {
	FAN_SIZE :: 70.0 // Size of the fan visualization
	FAN_INNER_RADIUS :: 18.0
	LED_RADIUS :: 4.0

	// Determine if this is an SL or TL fan
	is_sl := fan_type >= 20 && fan_type <= 26
	is_tl := fan_type == 28

	if is_sl {
		// Draw SL 120 fan with square frame
		FRAME_SIZE :: FAN_SIZE

		// Draw filled square background (dark grey)
		half := FRAME_SIZE / 2
		cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 1.0)
		cairo_move_to(cr, center_x - half, center_y - half)
		cairo_line_to(cr, center_x + half, center_y - half)
		cairo_line_to(cr, center_x + half, center_y + half)
		cairo_line_to(cr, center_x - half, center_y + half)
		cairo_close_path(cr)
		cairo_fill(cr)

		// Draw center circle for fan motor (dark)
		FAN_CENTER_RADIUS :: 25.0
		cairo_set_source_rgba(cr, 0.2, 0.2, 0.2, 1.0)
		cairo_arc(cr, center_x, center_y, FAN_CENTER_RADIUS, 0, 2 * math.PI)
		cairo_fill(cr)

		// Draw center circle border
		cairo_set_source_rgba(cr, 0.3, 0.3, 0.3, 1.0)
		cairo_set_line_width(cr, 1.0)
		cairo_arc(cr, center_x, center_y, FAN_CENTER_RADIUS, 0, 2 * math.PI)
		cairo_stroke(cr)

		// Draw LEDs using layout
		if num_leds == SL_120_LED_COUNT {
			layout := generate_sl_120_layout()

			for i in 0 ..< num_leds {
				pos := layout[i]
				led_x := center_x + pos.x * FAN_SIZE
				led_y := center_y + pos.y * FAN_SIZE

				// Get LED color
				color_idx := led_offset + i
				r, g, b: f64 = 0.05, 0.05, 0.05

				if color_idx >= 0 && color_idx < len(state.led_colors) {
					r = f64(state.led_colors[color_idx].r) / 255.0
					g = f64(state.led_colors[color_idx].g) / 255.0
					b = f64(state.led_colors[color_idx].b) / 255.0
				}

				// Calculate angle for LED strip orientation
				// Use the angle stored in the LED position
				led_angle := pos.angle

				// LED bar dimensions - make them larger to look like strips
				BAR_LENGTH :: 12.0
				BAR_WIDTH :: 4.0

				// Draw LED glow (larger ellipse)
				if r > 0.1 || g > 0.1 || b > 0.1 {
					cairo_save(cr)
					cairo_translate(cr, led_x, led_y)
					cairo_rotate(cr, led_angle - math.PI / 2)

					// Glow ellipse
					cairo_set_source_rgba(cr, r, g, b, 0.4)
					cairo_scale(cr, BAR_LENGTH * 1.5, BAR_WIDTH * 2.0)
					cairo_arc(cr, 0, 0, 1, 0, 2 * math.PI)
					cairo_fill(cr)

					cairo_restore(cr)
				}

				// Draw LED bar core
				cairo_save(cr)
				cairo_translate(cr, led_x, led_y)
				cairo_rotate(cr, led_angle - math.PI / 2)

				cairo_set_source_rgb(cr, r, g, b)
				// Draw rounded rectangle
				half_len := BAR_LENGTH / 2
				half_width := BAR_WIDTH / 2
				cairo_move_to(cr, -half_len, -half_width)
				cairo_line_to(cr, half_len, -half_width)
				cairo_line_to(cr, half_len, half_width)
				cairo_line_to(cr, -half_len, half_width)
				cairo_close_path(cr)
				cairo_fill(cr)

				cairo_restore(cr)
			}
		}

	} else if is_tl {
		// Draw TL fan with simple circle
		FAN_OUTER_RADIUS :: FAN_SIZE

		// Draw outer circle
		cairo_set_source_rgba(cr, 0.25, 0.25, 0.25, 0.8)
		cairo_arc(cr, center_x, center_y, FAN_OUTER_RADIUS, 0, 2 * math.PI)
		cairo_fill(cr)

		// Draw inner circle
		cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 0.9)
		cairo_arc(cr, center_x, center_y, FAN_INNER_RADIUS, 0, 2 * math.PI)
		cairo_fill(cr)

		// Draw fan blades
		BLADE_COUNT :: 9
		cairo_set_source_rgba(cr, 0.2, 0.2, 0.2, 0.6)
		cairo_set_line_width(cr, 3)
		for i in 0 ..< BLADE_COUNT {
			angle := f64(i) / f64(BLADE_COUNT) * 2.0 * math.PI
			x1 := center_x + FAN_INNER_RADIUS * math.cos(angle)
			y1 := center_y + FAN_INNER_RADIUS * math.sin(angle)
			x2 := center_x + (FAN_OUTER_RADIUS - 8) * math.cos(angle + 0.15)
			y2 := center_y + (FAN_OUTER_RADIUS - 8) * math.sin(angle + 0.15)
			cairo_move_to(cr, x1, y1)
			cairo_line_to(cr, x2, y2)
			cairo_stroke(cr)
		}

		// Draw LEDs using layout
		if num_leds == TL_LED_COUNT {
			layout := generate_tl_layout()

			for i in 0 ..< num_leds {
				pos := layout[i]
				led_x := center_x + pos.x * FAN_SIZE
				led_y := center_y + pos.y * FAN_SIZE

				// Get LED color
				color_idx := led_offset + i
				r, g, b: f64 = 0.1, 0.1, 0.1

				if color_idx >= 0 && color_idx < len(state.led_colors) {
					r = f64(state.led_colors[color_idx].r) / 255.0
					g = f64(state.led_colors[color_idx].g) / 255.0
					b = f64(state.led_colors[color_idx].b) / 255.0
				}

				// Draw LED glow
				if r > 0.1 || g > 0.1 || b > 0.1 {
					cairo_set_source_rgba(cr, r, g, b, 0.4)
					cairo_arc(cr, led_x, led_y, LED_RADIUS * 2.5, 0, 2 * math.PI)
					cairo_fill(cr)
				}

				// Draw LED core
				cairo_set_source_rgb(cr, r, g, b)
				cairo_arc(cr, led_x, led_y, LED_RADIUS, 0, 2 * math.PI)
				cairo_fill(cr)
			}
		}
	} else {
		// Fallback: generic circle for unknown types
		FAN_OUTER_RADIUS :: FAN_SIZE
		LED_RING_RADIUS :: FAN_SIZE * 0.85

		// Draw outer circle
		cairo_set_source_rgba(cr, 0.25, 0.25, 0.25, 0.8)
		cairo_arc(cr, center_x, center_y, FAN_OUTER_RADIUS, 0, 2 * math.PI)
		cairo_fill(cr)

		// Draw inner circle
		cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 0.9)
		cairo_arc(cr, center_x, center_y, FAN_INNER_RADIUS, 0, 2 * math.PI)
		cairo_fill(cr)

		// Draw LEDs in a circle
		if num_leds > 0 {
			for i in 0 ..< num_leds {
				angle := f64(i) / f64(num_leds) * 2.0 * math.PI - math.PI / 2.0
				led_x := center_x + LED_RING_RADIUS * math.cos(angle)
				led_y := center_y + LED_RING_RADIUS * math.sin(angle)

				color_idx := led_offset + i
				r, g, b: f64 = 0.1, 0.1, 0.1

				if color_idx >= 0 && color_idx < len(state.led_colors) {
					r = f64(state.led_colors[color_idx].r) / 255.0
					g = f64(state.led_colors[color_idx].g) / 255.0
					b = f64(state.led_colors[color_idx].b) / 255.0
				}

				if r > 0.1 || g > 0.1 || b > 0.1 {
					cairo_set_source_rgba(cr, r, g, b, 0.4)
					cairo_arc(cr, led_x, led_y, LED_RADIUS * 2.5, 0, 2 * math.PI)
					cairo_fill(cr)
				}

				cairo_set_source_rgb(cr, r, g, b)
				cairo_arc(cr, led_x, led_y, LED_RADIUS, 0, 2 * math.PI)
				cairo_fill(cr)
			}
		}
	}

	// Draw label based on fan_type
	type_label: cstring
	if fan_type >= 20 && fan_type <= 26 {
		type_label = "SL"
	} else if fan_type == 28 {
		type_label = "TL"
	} else if fan_type == 65 {
		type_label = "LCD"
	} else {
		type_label = "?"
	}

	cairo_set_source_rgb(cr, 0.7, 0.7, 0.7)
	cairo_select_font_face(cr, "Inter", 0, 1)
	cairo_set_font_size(cr, 11)

	extents: cairo_text_extents_t
	cairo_text_extents(cr, type_label, &extents)
	cairo_move_to(cr, center_x - extents.width / 2, center_y + extents.height / 2)
	cairo_show_text(cr, type_label)
}

// Callbacks
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

// 3D view drag callbacks
on_drag_begin :: proc "c" (gesture: GtkGestureDrag, start_x, start_y: c.double, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	if !state.model_loaded {
		return
	}

	state.drag_start_x = f64(start_x)
	state.drag_start_y = f64(start_y)
	state.drag_start_rot_x = state.view.rotation_x
	state.drag_start_rot_y = state.view.rotation_y
}

on_drag_update :: proc "c" (gesture: GtkGestureDrag, offset_x, offset_y: c.double, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	if !state.model_loaded {
		return
	}

	// Update rotation based on drag
	sensitivity :: 0.01
	state.view.rotation_x = state.drag_start_rot_x + f64(offset_y) * sensitivity
	state.view.rotation_y = state.drag_start_rot_y + f64(offset_x) * sensitivity

	// Redraw the preview
	gtk_widget_queue_draw(auto_cast state.preview_area)
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
			hue := f32(i) / f32(total_leds)
			r, g, b := hsv_to_rgb(hue, 1.0, f32(state.brightness / 100.0))
			state.led_colors[i] = {r, g, b}
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


