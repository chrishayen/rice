// ui.odin
// Lian Li Fan Control GUI - GTK4 + libadwaita version in Odin
// Modern GNOME design with Adwaita widgets

package main

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
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
GtkGestureClick :: distinct rawptr
GtkGestureSingle :: distinct rawptr
GtkEventController :: distinct rawptr
GdkEventSequence :: distinct rawptr
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

GdkRGBA :: struct #packed {
	red:   f32,
	green: f32,
	blue:  f32,
	alpha: f32,
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

GtkPropagationPhase :: enum c.int {
	NONE    = 0,
	CAPTURE = 1,
	BUBBLE  = 2,
	TARGET  = 3,
}

GtkEventSequenceState :: enum c.int {
	NONE    = 0,
	CLAIMED = 1,
	DENIED  = 2,
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
	gtk_widget_set_visible :: proc(widget: GtkWidget, visible: c.bool) ---
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
	gtk_drop_down_set_model :: proc(dropdown: GtkDropDown, model: rawptr) ---

	gtk_gesture_drag_new :: proc() -> GtkGesture ---
	gtk_gesture_click_new :: proc() -> GtkGestureClick ---
	gtk_gesture_single_set_button :: proc(gesture: GtkGestureSingle, button: c.uint) ---
	gtk_gesture_single_get_current_sequence :: proc(gesture: GtkGestureSingle) -> GdkEventSequence ---
	gtk_gesture_set_state :: proc(gesture: GtkGesture, sequence: GdkEventSequence, state: GtkEventSequenceState) -> c.bool ---
	gtk_widget_add_controller :: proc(widget: GtkWidget, controller: rawptr) ---
	gtk_event_controller_set_propagation_phase :: proc(controller: rawptr, phase: GtkPropagationPhase) ---
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

GSignalMatchType :: enum c.uint {
	ID          = 1 << 0,
	DETAIL      = 1 << 1,
	CLOSURE     = 1 << 2,
	FUNC        = 1 << 3,
	DATA        = 1 << 4,
	UNBLOCKED   = 1 << 5,
}

@(default_calling_convention = "c")
foreign gobject {
	g_signal_connect_data :: proc(instance: rawptr, detailed_signal: cstring, c_handler: rawptr, data: rawptr, destroy_data: rawptr, connect_flags: c.int) -> c.ulong ---
	g_signal_handlers_block_matched :: proc(instance: rawptr, mask: c.uint, signal_id: c.uint, detail: c.uint, closure: rawptr, func: rawptr, data: rawptr) -> c.uint ---
	g_signal_handlers_unblock_matched :: proc(instance: rawptr, mask: c.uint, signal_id: c.uint, detail: c.uint, closure: rawptr, func: rawptr, data: rawptr) -> c.uint ---
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
	color1_row:            GtkWidget, // Color picker row for primary color
	color2_row:            GtkWidget, // Color picker row for secondary color
	effect_dropdown:       GtkDropDown,
	device_list_box:       GtkBox,
	device_toggle_buttons: [dynamic]GtkToggleButton,
	bind_buttons:          [dynamic]GtkWidget, // Bind buttons shown below selected unbound devices
	unbind_buttons:        [dynamic]GtkWidget, // Unbind buttons shown below selected bound devices

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

	// LCD display controls
	lcd_fan_dropdown:      GtkDropDown,
	lcd_preview_area:      GtkDrawingArea,
	selected_lcd_device:   int,  // Index into devices array, -1 if none selected
	selected_lcd_fan:      int,  // Fan index within the device, -1 if none selected
	usb_lcd_devices:       [dynamic]USB_LCD_Device,  // USB LCD devices indexed by rx_type
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

// USB LCD device info (indexed by rx_type / lcd_group)
USB_LCD_Device :: struct {
	bus:     int,
	address: int,
	index:   int,  // Enumeration order / lcd_group index
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
	{"Breathing", "Fade in/out breathing effect", false, false},
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
	state.color1 = GdkRGBA{red = 1.0, green = 0.0, blue = 0.0, alpha = 1.0}
	state.color2 = GdkRGBA{red = 0.0, green = 0.0, blue = 1.0, alpha = 1.0}
	state.brightness = 100.0
	state.devices = make([dynamic]Device)
	state.selected_devices = make([dynamic]bool)
	state.device_toggle_buttons = make([dynamic]GtkToggleButton)
	state.bind_buttons = make([dynamic]GtkWidget)
	state.unbind_buttons = make([dynamic]GtkWidget)
	state.selected_lcd_device = -1
	state.selected_lcd_fan = -1
	state.usb_lcd_devices = make([dynamic]USB_LCD_Device)

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

			// Update visibility of options based on selected effect
			update_effect_options_visibility(state)
		}, nil, nil, 0)

	// Color controls
	color_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast color_group, "Colors")
	gtk_box_append(auto_cast box, color_group)

	// Color 1 row
	state.color1_row = auto_cast adw_action_row_new()
	adw_preferences_row_set_title(auto_cast state.color1_row, "Primary Color")
	state.color1_button = auto_cast gtk_color_button_new()
	gtk_color_chooser_set_rgba(state.color1_button, &state.color1)
	adw_action_row_add_suffix(auto_cast state.color1_row, auto_cast state.color1_button)
	adw_preferences_group_add(auto_cast color_group, state.color1_row)

	// Color 2 row
	state.color2_row = auto_cast adw_action_row_new()
	adw_preferences_row_set_title(auto_cast state.color2_row, "Secondary Color")
	state.color2_button = auto_cast gtk_color_button_new()
	gtk_color_chooser_set_rgba(state.color2_button, &state.color2)
	adw_action_row_add_suffix(auto_cast state.color2_row, auto_cast state.color2_button)
	adw_preferences_group_add(auto_cast color_group, state.color2_row)

	// Set initial visibility based on default effect
	update_effect_options_visibility(state)

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
	gtk_event_controller_set_propagation_phase(drag_gesture, .TARGET) // GTK_PHASE_TARGET
	g_signal_connect_data(drag_gesture, "drag-begin", auto_cast on_drag_begin, state, nil, 0)
	g_signal_connect_data(drag_gesture, "drag-update", auto_cast on_drag_update, state, nil, 0)
	gtk_widget_add_controller(auto_cast state.preview_area, drag_gesture)

	return scrolled
}

build_lcd_page :: proc(state: ^App_State) -> GtkWidget {
	paned := auto_cast gtk_paned_new(.HORIZONTAL)

	// Left: preview
	preview := build_lcd_preview_panel(state)
	gtk_paned_set_start_child(auto_cast paned, preview)
	gtk_paned_set_resize_start_child(auto_cast paned, true)
	gtk_paned_set_shrink_start_child(auto_cast paned, true)

	// Right: controls
	controls := build_lcd_controls(state)
	gtk_paned_set_end_child(auto_cast paned, controls)
	gtk_paned_set_resize_end_child(auto_cast paned, false)
	gtk_paned_set_shrink_end_child(auto_cast paned, false)

	gtk_paned_set_position(auto_cast paned, 600)

	return paned
}

build_lcd_preview_panel :: proc(state: ^App_State) -> GtkWidget {
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)

	box := auto_cast gtk_box_new(.VERTICAL, 12)
	gtk_widget_set_margin_start(box, 20)
	gtk_widget_set_margin_end(box, 20)
	gtk_widget_set_margin_top(box, 20)
	gtk_widget_set_margin_bottom(box, 20)
	gtk_scrolled_window_set_child(auto_cast scrolled, box)

	title := auto_cast gtk_label_new("LCD Preview")
	gtk_label_set_markup(auto_cast title, "<span size='13000' weight='bold'>LCD Preview</span>")
	gtk_label_set_xalign(auto_cast title, 0.0)
	gtk_box_append(auto_cast box, title)

	// Frame for preview
	frame := auto_cast gtk_frame_new(nil)
	gtk_widget_set_vexpand(frame, true)
	gtk_box_append(auto_cast box, frame)

	// Drawing area for LCD preview (400x400 to match actual LCD resolution)
	state.lcd_preview_area = auto_cast gtk_drawing_area_new()
	gtk_drawing_area_set_content_width(state.lcd_preview_area, 400)
	gtk_drawing_area_set_content_height(state.lcd_preview_area, 400)
	gtk_drawing_area_set_draw_func(state.lcd_preview_area, draw_lcd_preview, state, nil)
	gtk_frame_set_child(auto_cast frame, auto_cast state.lcd_preview_area)

	return scrolled
}

build_lcd_controls :: proc(state: ^App_State) -> GtkWidget {
	scrolled := auto_cast gtk_scrolled_window_new()
	gtk_scrolled_window_set_policy(auto_cast scrolled, .NEVER, .AUTOMATIC)

	box := auto_cast gtk_box_new(.VERTICAL, 24)
	gtk_widget_set_margin_start(box, 20)
	gtk_widget_set_margin_end(box, 20)
	gtk_widget_set_margin_top(box, 20)
	gtk_widget_set_margin_bottom(box, 20)
	gtk_scrolled_window_set_child(auto_cast scrolled, box)

	// LCD Fan Selection group
	fan_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast fan_group, "LCD Fan Selection")
	adw_preferences_group_set_description(auto_cast fan_group, "Select which LCD fan to configure")
	gtk_box_append(auto_cast box, fan_group)

	// LCD fan selector row
	fan_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(fan_row, "Target LCD Fan")
	fan_list := gtk_string_list_new(nil)
	gtk_string_list_append(fan_list, "Select an LCD fan...")
	state.lcd_fan_dropdown = auto_cast gtk_drop_down_new(fan_list, nil)
	gtk_drop_down_set_selected(state.lcd_fan_dropdown, 0)
	gtk_widget_set_size_request(auto_cast state.lcd_fan_dropdown, 300, -1)
	adw_action_row_add_suffix(auto_cast fan_row, auto_cast state.lcd_fan_dropdown)
	adw_preferences_group_add(auto_cast fan_group, fan_row)

	// Connect signal for dropdown selection changes
	g_signal_connect_data(state.lcd_fan_dropdown, "notify::selected", auto_cast on_lcd_fan_selected, state, nil, 0)

	// Populate LCD fan list (will be updated when devices are loaded via rebuild_device_list)
	// Initial call happens after devices are loaded by on_initial_poll

	// Video Source group
	source_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast source_group, "Video Source")
	adw_preferences_group_set_description(auto_cast source_group, "Select frames directory for video playback")
	gtk_box_append(auto_cast box, source_group)

	// Frames directory row
	frames_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(frames_row, "Frames Directory")
	adw_action_row_set_subtitle(auto_cast frames_row, "No directory selected")

	browse_btn := auto_cast gtk_button_new_with_label("Browse...")
	adw_action_row_add_suffix(auto_cast frames_row, browse_btn)
	adw_preferences_group_add(auto_cast source_group, frames_row)

	// Playback Settings group
	playback_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast playback_group, "Playback Settings")
	gtk_box_append(auto_cast box, playback_group)

	// FPS row
	fps_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(fps_row, "Frames Per Second")
	fps_scale := auto_cast gtk_scale_new_with_range(.HORIZONTAL, 1, 60, 1)
	gtk_range_set_value(fps_scale, 10)
	gtk_scale_set_digits(auto_cast fps_scale, 0)
	gtk_scale_set_draw_value(auto_cast fps_scale, true)
	gtk_widget_set_hexpand(auto_cast fps_scale, true)
	gtk_widget_set_size_request(auto_cast fps_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast fps_row, auto_cast fps_scale)
	adw_preferences_group_add(auto_cast playback_group, fps_row)

	// Loop option row
	loop_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(loop_row, "Loop Playback")
	adw_action_row_set_subtitle(auto_cast loop_row, "Repeat video continuously")
	loop_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast loop_switch, false)
	adw_action_row_add_suffix(auto_cast loop_row, loop_switch)
	adw_action_row_set_activatable_widget(auto_cast loop_row, loop_switch)
	adw_preferences_group_add(auto_cast playback_group, loop_row)

	// Random start row
	random_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(random_row, "Random Start")
	adw_action_row_set_subtitle(auto_cast random_row, "Begin at random frame")
	random_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast random_switch, false)
	adw_action_row_add_suffix(auto_cast random_row, random_switch)
	adw_action_row_set_activatable_widget(auto_cast random_row, random_switch)
	adw_preferences_group_add(auto_cast playback_group, random_row)

	// Transform Options group
	transform_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast transform_group, "Transform Options")
	gtk_box_append(auto_cast box, transform_group)

	// Zoom row
	zoom_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(zoom_row, "Zoom (Center Crop)")
	zoom_scale := auto_cast gtk_scale_new_with_range(.HORIZONTAL, 0, 90, 1)
	gtk_range_set_value(zoom_scale, 0)
	gtk_scale_set_digits(auto_cast zoom_scale, 0)
	gtk_scale_set_draw_value(auto_cast zoom_scale, true)
	gtk_widget_set_hexpand(auto_cast zoom_scale, true)
	gtk_widget_set_size_request(auto_cast zoom_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast zoom_row, auto_cast zoom_scale)
	adw_preferences_group_add(auto_cast transform_group, zoom_row)

	// Rotation row
	rotation_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(rotation_row, "Rotation (degrees)")
	rotation_scale := auto_cast gtk_scale_new_with_range(.HORIZONTAL, 0, 360, 1)
	gtk_range_set_value(rotation_scale, 0)
	gtk_scale_set_digits(auto_cast rotation_scale, 0)
	gtk_scale_set_draw_value(auto_cast rotation_scale, true)
	gtk_widget_set_hexpand(auto_cast rotation_scale, true)
	gtk_widget_set_size_request(auto_cast rotation_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast rotation_row, auto_cast rotation_scale)
	adw_preferences_group_add(auto_cast transform_group, rotation_row)

	// Rotation speed row
	rot_speed_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(rot_speed_row, "Rotation Speed (deg/frame)")
	rot_speed_scale := auto_cast gtk_scale_new_with_range(.HORIZONTAL, 0, 10, 0.1)
	gtk_range_set_value(rot_speed_scale, 0)
	gtk_scale_set_digits(auto_cast rot_speed_scale, 1)
	gtk_scale_set_draw_value(auto_cast rot_speed_scale, true)
	gtk_widget_set_hexpand(auto_cast rot_speed_scale, true)
	gtk_widget_set_size_request(auto_cast rot_speed_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast rot_speed_row, auto_cast rot_speed_scale)
	adw_preferences_group_add(auto_cast transform_group, rot_speed_row)

	// Rotation direction row
	rot_dir_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(rot_dir_row, "Rotation Direction")
	rot_dir_list := gtk_string_list_new(nil)
	gtk_string_list_append(rot_dir_list, "Counter-Clockwise")
	gtk_string_list_append(rot_dir_list, "Clockwise")
	rot_dir_dropdown := auto_cast gtk_drop_down_new(rot_dir_list, nil)
	gtk_drop_down_set_selected(auto_cast rot_dir_dropdown, 0)
	adw_action_row_add_suffix(auto_cast rot_dir_row, auto_cast rot_dir_dropdown)
	adw_preferences_group_add(auto_cast transform_group, rot_dir_row)

	// Flip horizontal row
	flip_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(flip_row, "Flip Horizontal")
	flip_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast flip_switch, false)
	adw_action_row_add_suffix(auto_cast flip_row, flip_switch)
	adw_action_row_set_activatable_widget(auto_cast flip_row, flip_switch)
	adw_preferences_group_add(auto_cast transform_group, flip_row)

	// Overlay Options group
	overlay_group := auto_cast adw_preferences_group_new()
	adw_preferences_group_set_title(auto_cast overlay_group, "Overlay Options")
	gtk_box_append(auto_cast box, overlay_group)

	// Overlay type row
	overlay_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(overlay_row, "Overlay Type")
	overlay_list := gtk_string_list_new(nil)
	gtk_string_list_append(overlay_list, "None")
	gtk_string_list_append(overlay_list, "CPU Usage")
	gtk_string_list_append(overlay_list, "GPU Usage")
	gtk_string_list_append(overlay_list, "Memory Usage")
	gtk_string_list_append(overlay_list, "CPU Temperature")
	gtk_string_list_append(overlay_list, "Time")
	gtk_string_list_append(overlay_list, "FPS Counter")
	overlay_dropdown := auto_cast gtk_drop_down_new(overlay_list, nil)
	gtk_drop_down_set_selected(auto_cast overlay_dropdown, 0)
	adw_action_row_add_suffix(auto_cast overlay_row, auto_cast overlay_dropdown)
	adw_preferences_group_add(auto_cast overlay_group, overlay_row)

	// Colorful text row
	colorful_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(colorful_row, "Colorful Text")
	adw_action_row_set_subtitle(auto_cast colorful_row, "Use colored text (green/yellow/red)")
	colorful_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast colorful_switch, false)
	adw_action_row_add_suffix(auto_cast colorful_row, colorful_switch)
	adw_action_row_set_activatable_widget(auto_cast colorful_row, colorful_switch)
	adw_preferences_group_add(auto_cast overlay_group, colorful_row)

	// Dark bar row
	darkbar_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(darkbar_row, "Dark Bar Background")
	adw_action_row_set_subtitle(auto_cast darkbar_row, "Add dark translucent bar behind text")
	darkbar_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast darkbar_switch, false)
	adw_action_row_add_suffix(auto_cast darkbar_row, darkbar_switch)
	adw_action_row_set_activatable_widget(auto_cast darkbar_row, darkbar_switch)
	adw_preferences_group_add(auto_cast overlay_group, darkbar_row)

	// Bedtime hour row (for time overlay)
	bedtime_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(bedtime_row, "Bedtime Hour (24h)")
	adw_action_row_set_subtitle(auto_cast bedtime_row, "For time overlay color zones")
	bedtime_scale := auto_cast gtk_scale_new_with_range(.HORIZONTAL, 0, 23, 1)
	gtk_range_set_value(bedtime_scale, 22)
	gtk_scale_set_digits(auto_cast bedtime_scale, 0)
	gtk_scale_set_draw_value(auto_cast bedtime_scale, true)
	gtk_widget_set_hexpand(auto_cast bedtime_scale, true)
	gtk_widget_set_size_request(auto_cast bedtime_scale, 200, -1)
	adw_action_row_add_suffix(auto_cast bedtime_row, auto_cast bedtime_scale)
	adw_preferences_group_add(auto_cast overlay_group, bedtime_row)

	// Show volume row
	volume_row := auto_cast adw_action_row_new()
	adw_preferences_row_set_title(volume_row, "Show Volume Changes")
	adw_action_row_set_subtitle(auto_cast volume_row, "Display volume bar on changes")
	volume_switch := auto_cast gtk_check_button_new()
	gtk_check_button_set_active(auto_cast volume_switch, false)
	adw_action_row_add_suffix(auto_cast volume_row, volume_switch)
	adw_action_row_set_activatable_widget(auto_cast volume_row, volume_switch)
	adw_preferences_group_add(auto_cast overlay_group, volume_row)

	// Action buttons
	button_box := auto_cast gtk_box_new(.HORIZONTAL, 12)
	gtk_widget_set_halign(button_box, .CENTER)
	gtk_widget_set_margin_top(button_box, 20)
	gtk_box_append(auto_cast box, button_box)

	play_btn := auto_cast gtk_button_new_with_label("Play Video")
	gtk_widget_add_css_class(play_btn, "suggested-action")
	gtk_widget_add_css_class(play_btn, "pill")
	gtk_widget_set_size_request(play_btn, 150, 48)
	gtk_box_append(auto_cast button_box, play_btn)

	stop_btn := auto_cast gtk_button_new_with_label("Stop")
	gtk_widget_add_css_class(stop_btn, "destructive-action")
	gtk_widget_add_css_class(stop_btn, "pill")
	gtk_widget_set_size_request(stop_btn, 150, 48)
	gtk_box_append(auto_cast button_box, stop_btn)

	return scrolled
}

// Drawing function for LCD preview
draw_lcd_preview :: proc "c" (
	area: GtkDrawingArea,
	cr: cairo_t,
	width, height: c.int,
	user_data: rawptr,
) {
	context = runtime.default_context()

	state := cast(^App_State)user_data

	// Background - dark to simulate LCD screen
	cairo_set_source_rgb(cr, 0.05, 0.05, 0.05)
	cairo_paint(cr)

	// Determine state and show appropriate message
	text: cstring
	subtitle: cstring = nil

	// Check if we have any devices loaded
	if len(state.devices) == 0 {
		// State 1: No devices loaded yet
		text = "No devices detected"
		subtitle = "Click 'Refresh Devices' to scan for fans"
		cairo_set_source_rgb(cr, 0.6, 0.4, 0.4)  // Reddish tint
	} else {
		// Check if we have any LCD fans available
		has_lcd_fans := false
		for device in state.devices {
			if device.has_lcd {
				has_lcd_fans = true
				break
			}
		}

		if !has_lcd_fans {
			// State 2: Devices loaded but none have LCD
			text = "No LCD fans available"
			subtitle = "Connect SL 120 LCD fans to use this feature"
			cairo_set_source_rgb(cr, 0.6, 0.5, 0.3)  // Yellowish tint
		} else if state.selected_lcd_device == -1 {
			// State 3: LCD fans available but none selected
			text = "No LCD fan selected"
			subtitle = "Choose a fan from the dropdown above"
			cairo_set_source_rgb(cr, 0.5, 0.5, 0.5)  // Gray
		} else {
			// State 4: LCD fan selected, ready for video
			text = "Ready to play"
			subtitle = "Select a video source and click Play"
			cairo_set_source_rgb(cr, 0.3, 0.6, 0.3)  // Greenish tint
		}
	}

	// Draw main message
	cairo_select_font_face(cr, "Inter", 0, 0)
	cairo_set_font_size(cr, 16)

	extents: cairo_text_extents_t
	cairo_text_extents(cr, text, &extents)

	x := (c.double(width) - extents.width) / 2
	y := c.double(height) / 2 - 10

	cairo_move_to(cr, x, y)
	cairo_show_text(cr, text)

	// Draw subtitle if present
	if subtitle != nil {
		cairo_set_font_size(cr, 12)
		cairo_set_source_rgb(cr, 0.4, 0.4, 0.4)

		cairo_text_extents(cr, subtitle, &extents)
		sub_x := (c.double(width) - extents.width) / 2
		sub_y := c.double(height) / 2 + 15

		cairo_move_to(cr, sub_x, sub_y)
		cairo_show_text(cr, subtitle)
	}

	// If a fan is selected, show device info at top
	if state.selected_lcd_device >= 0 && state.selected_lcd_device < len(state.devices) {
		device := state.devices[state.selected_lcd_device]

		cairo_set_font_size(cr, 12)
		cairo_set_source_rgb(cr, 0.6, 0.6, 0.6)

		// Show device and fan info at top
		info_text := fmt.tprintf("Device: %s | Fan: %d", device.mac_str, state.selected_lcd_fan)
		info_cstr := strings.clone_to_cstring(info_text)
		defer delete(info_cstr)

		cairo_text_extents(cr, info_cstr, &extents)
		info_x := (c.double(width) - extents.width) / 2
		cairo_move_to(cr, info_x, 30)
		cairo_show_text(cr, info_cstr)

		// Show USB mapping info
		if usb_dev, ok := get_usb_lcd_device(state, device.rx_type); ok {
			usb_text := fmt.tprintf("USB Bus:Address = %d:%d", usb_dev.bus, usb_dev.address)
			usb_cstr := strings.clone_to_cstring(usb_text)
			defer delete(usb_cstr)

			cairo_text_extents(cr, usb_cstr, &extents)
			usb_x := (c.double(width) - extents.width) / 2
			cairo_move_to(cr, usb_x, 50)
			cairo_show_text(cr, usb_cstr)
		}
	}

	// Draw LCD screen border to show 400x400 area
	cairo_set_source_rgba(cr, 0.3, 0.3, 0.3, 0.5)
	cairo_set_line_width(cr, 2)
	cairo_move_to(cr, 0, 0)
	cairo_line_to(cr, c.double(width), 0)
	cairo_line_to(cr, c.double(width), c.double(height))
	cairo_line_to(cr, 0, c.double(height))
	cairo_close_path(cr)
	cairo_stroke(cr)
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

// Update visibility of effect options based on selected effect
update_effect_options_visibility :: proc(state: ^App_State) {
	if state.selected_effect < 0 || state.selected_effect >= len(EFFECTS) {
		return
	}

	effect := EFFECTS[state.selected_effect]

	// Show/hide color pickers based on effect requirements
	gtk_widget_set_visible(state.color1_row, effect.has_color1)
	gtk_widget_set_visible(state.color2_row, effect.has_color2)
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

	// Get current settings
	effect_name := EFFECTS[state.selected_effect].name
	state.brightness = gtk_range_get_value(state.brightness_scale)
	gtk_color_chooser_get_rgba(state.color1_button, &state.color1)
	gtk_color_chooser_get_rgba(state.color2_button, &state.color2)

	// Get selected devices (only bound devices)
	selected_devices := make([dynamic]Device, 0, len(state.devices))
	defer delete(selected_devices)

	for device, idx in state.devices {
		if idx < len(state.selected_devices) && state.selected_devices[idx] && device.bound {
			append(&selected_devices, device)
		}
	}

	if len(selected_devices) == 0 {
		log_warn("No bound devices selected to apply effect")
		fmt.printfln("Please select at least one bound device")
		return
	}

	fmt.printfln("Applying effect '%s' to %d device(s)", effect_name, len(selected_devices))

	// Send effect request to service
	send_effect_request(selected_devices[:], state.selected_effect, state.color1, state.color2, state.brightness)
}

// LCD fan selection callback
on_lcd_fan_selected :: proc "c" (dropdown: GtkDropDown, pspec: rawptr, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	selected := int(gtk_drop_down_get_selected(dropdown))

	// Index 0 is always the placeholder "Select an LCD fan..."
	if selected == 0 {
		state.selected_lcd_device = -1
		state.selected_lcd_fan = -1
		gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
		return
	}

	// Calculate which device and fan based on selection (accounting for placeholder at index 0)
	// Only count fans that actually have LCD screens (types 24 or 25)
	// Index 1 = first LCD fan, index 2 = second LCD fan, etc.
	lcd_fan_count := 1  // Start at 1 because 0 is placeholder
	for device, dev_idx in state.devices {
		if !device.has_lcd do continue

		for fan_idx in 0..<device.fan_count {
			fan_type := device.fan_types[fan_idx]

			// Only count fans with LCD capability
			if fan_type != 24 && fan_type != 25 {
				continue
			}

			if lcd_fan_count == selected {
				state.selected_lcd_device = dev_idx
				state.selected_lcd_fan = fan_idx
				fmt.printfln("Selected LCD fan: Device %d (MAC: %s, rx_type: %d), Fan %d",
					dev_idx, device.mac_str, device.rx_type, fan_idx)

				// Redraw LCD preview
				gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
				return
			}
			lcd_fan_count += 1
		}
	}

	// If we get here, selection index was invalid - reset
	state.selected_lcd_device = -1
	state.selected_lcd_fan = -1
	gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
}

// Get USB LCD device by rx_type (lcd_group index)
get_usb_lcd_device :: proc(state: ^App_State, rx_type: u8) -> (USB_LCD_Device, bool) {
	// rx_type is the lcd_group index
	index := int(rx_type)

	// Check if we have a device at this index
	if index < 0 || index >= len(state.usb_lcd_devices) {
		return {}, false
	}

	return state.usb_lcd_devices[index], true
}

// Enumerate USB LCD devices and store by index
enumerate_usb_lcd_devices :: proc(state: ^App_State) {
	clear(&state.usb_lcd_devices)

	// Initialize libusb
	ctx: rawptr
	ret := libusb_init(&ctx)
	if ret != LIBUSB_SUCCESS {
		fmt.println("Failed to initialize libusb for LCD enumeration")
		return
	}
	defer libusb_exit(ctx)

	// Get device list
	device_list: ^rawptr
	device_count := libusb_get_device_list(ctx, &device_list)
	if device_count < 0 {
		fmt.println("Failed to get USB device list")
		return
	}
	defer libusb_free_device_list(device_list, 1)

	// Enumerate all LCD devices (VID 0x1cbe, PID 0x0005)
	index := 0
	for i in 0..<device_count {
		device := mem.ptr_offset(device_list, i)^

		// Get device descriptor
		desc: Device_Descriptor
		ret = libusb_get_device_descriptor(device, &desc)
		if ret != LIBUSB_SUCCESS {
			continue
		}

		// Check if this is an LCD device
		if desc.idVendor != VID_WIRED || desc.idProduct != PID_WIRED {
			continue
		}

		// Get bus and address
		bus := int(libusb_get_bus_number(device))
		address := int(libusb_get_device_address(device))

		// Store this LCD device with its enumeration index
		lcd_dev := USB_LCD_Device {
			bus = bus,
			address = address,
			index = index,
		}
		append(&state.usb_lcd_devices, lcd_dev)

		fmt.printfln("Found USB LCD device: index=%d, bus=%d, address=%d", index, bus, address)
		index += 1
	}

	fmt.printfln("Total USB LCD devices found: %d", len(state.usb_lcd_devices))
}

// Update LCD fan dropdown list
update_lcd_fan_list :: proc(state: ^App_State) {
	if state.lcd_fan_dropdown == nil {
		return
	}

	// Create new string list
	fan_list := gtk_string_list_new(nil)

	// Always add a placeholder as first entry
	gtk_string_list_append(fan_list, "Select an LCD fan...")

	// Add LCD fans from devices
	for device, dev_idx in state.devices {
		if !device.has_lcd do continue

		// Add only fans that actually have LCD screens (types 24 or 25)
		for fan_idx in 0..<device.fan_count {
			fan_type := device.fan_types[fan_idx]

			// Only add if this specific fan has LCD capability
			if fan_type != 24 && fan_type != 25 {
				continue
			}

			// Format: "Device XX:XX:XX - Fan N (USB rx_type)"
			mac_short := device.mac_str[len(device.mac_str)-8:] if len(device.mac_str) >= 8 else device.mac_str
			label := fmt.aprintf("Device %s - Fan %d (USB %d)", mac_short, fan_idx, device.rx_type)
			defer delete(label)

			label_cstr := strings.clone_to_cstring(label)
			defer delete(label_cstr)

			gtk_string_list_append(fan_list, label_cstr)
		}
	}

	// Update dropdown model
	gtk_drop_down_set_model(state.lcd_fan_dropdown, fan_list)

	// Reset to placeholder
	gtk_drop_down_set_selected(state.lcd_fan_dropdown, 0)
	state.selected_lcd_device = -1
	state.selected_lcd_fan = -1
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

	brightness := int(state.brightness)

	// Generate based on effect using actual generator functions
	rgb_data: []u8
	defer delete(rgb_data)

	switch state.selected_effect {
	case 0: // Static Color
		r := u8(f64(state.color1.red) * 255 * state.brightness / 100)
		g := u8(f64(state.color1.green) * 255 * state.brightness / 100)
		b := u8(f64(state.color1.blue) * 255 * state.brightness / 100)
		rgb_data = generate_static_color(total_leds, r, g, b)

	case 1: // Rainbow
		rgb_data = generate_rainbow(total_leds, brightness)

	case 2: // Alternating
		c1 := [3]u8{
			u8(f64(state.color1.red) * 255 * state.brightness / 100),
			u8(f64(state.color1.green) * 255 * state.brightness / 100),
			u8(f64(state.color1.blue) * 255 * state.brightness / 100),
		}
		c2 := [3]u8{
			u8(f64(state.color2.red) * 255 * state.brightness / 100),
			u8(f64(state.color2.green) * 255 * state.brightness / 100),
			u8(f64(state.color2.blue) * 255 * state.brightness / 100),
		}
		rgb_data = generate_alternating(total_leds, c1, c2)

	case 3: // Alternating Spin (use frame 0)
		c1 := [3]u8{
			u8(f64(state.color1.red) * 255 * state.brightness / 100),
			u8(f64(state.color1.green) * 255 * state.brightness / 100),
			u8(f64(state.color1.blue) * 255 * state.brightness / 100),
		}
		c2 := [3]u8{
			u8(f64(state.color2.red) * 255 * state.brightness / 100),
			u8(f64(state.color2.green) * 255 * state.brightness / 100),
			u8(f64(state.color2.blue) * 255 * state.brightness / 100),
		}
		full_data := generate_alternating_spin(total_leds, c1, c2, 60)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 4: // Rainbow Morph (use frame 0)
		full_data := generate_rainbow_morph(total_leds, 127, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 5: // Breathing (use frame 0)
		full_data := generate_breathing(total_leds, 680, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 6: // Runway (use frame 0)
		full_data := generate_runway(total_leds, 180, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 7: // Meteor (use frame 0)
		full_data := generate_meteor(total_leds, 360, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 8: // Color Cycle (use frame 0)
		full_data := generate_color_cycle(total_leds, 40, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 9: // Wave (use frame 0)
		full_data := generate_wave(total_leds, 80, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 10: // Meteor Shower (use frame 0)
		full_data := generate_meteor_shower(total_leds, 80, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case 11: // Twinkle (use frame 0)
		full_data := generate_twinkle(total_leds, 200, brightness)
		defer delete(full_data)
		// Extract first frame
		rgb_data = make([]u8, total_leds * 3)
		copy(rgb_data, full_data[0:total_leds * 3])

	case:
		// Default to dim
		rgb_data = generate_static_color(total_leds, 26, 26, 26)
	}

	// Convert flat RGB array to [dynamic][3]u8
	for i in 0 ..< total_leds {
		state.led_colors[i] = {
			rgb_data[i * 3],
			rgb_data[i * 3 + 1],
			rgb_data[i * 3 + 2],
		}
	}
}

// Send effect request to service
send_effect_request :: proc(devices: []Device, effect_idx: int, color1: GdkRGBA, color2: GdkRGBA, brightness: f64) {
	if len(devices) == 0 do return

	// Get socket path
	socket_path, path_err := get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		return
	}

	// Connect to service
	client, connect_err := connect_to_server(socket_path)
	defer close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		fmt.printfln("Error: Could not connect to service. Is the service running?")
		return
	}

	// Build effect request
	device_infos := make([dynamic]Effect_Device_Info, 0, len(devices))
	defer delete(device_infos)

	for device in devices {
		append(&device_infos, Effect_Device_Info{
			mac_str = device.mac_str,
			rx_type = device.rx_type,
			channel = device.channel,
			led_count = device.led_count,
		})
	}

	// Convert colors to u8
	// For Static Color, Alternating, and Alternating Spin, apply brightness to the colors
	// (Python's generate_static_color doesn't take brightness parameter)
	brightness_factor := (effect_idx == 0 || effect_idx == 2 || effect_idx == 3) ? brightness / 100.0 : 1.0

	c1 := [3]u8{
		u8(f64(color1.red) * 255 * brightness_factor),
		u8(f64(color1.green) * 255 * brightness_factor),
		u8(f64(color1.blue) * 255 * brightness_factor),
	}
	c2 := [3]u8{
		u8(f64(color2.red) * 255 * brightness_factor),
		u8(f64(color2.green) * 255 * brightness_factor),
		u8(f64(color2.blue) * 255 * brightness_factor),
	}

	effect_req := Effect_Request{
		effect_name = EFFECTS[effect_idx].name,
		color1 = c1,
		color2 = c2,
		brightness = u8(brightness),
		devices = device_infos[:],
	}

	// Marshal to JSON
	json_data, marshal_err := json.marshal(effect_req)
	if marshal_err != nil {
		log_warn("Failed to marshal effect request: %v", marshal_err)
		return
	}
	defer delete(json_data)

	// Send Set_Effect request
	request := IPC_Message{
		type = .Set_Effect,
		payload = string(json_data),
	}

	send_err := send_message(client.socket_fd, request)
	if send_err != .None {
		log_warn("Failed to send Set_Effect request: %v", send_err)
		return
	}

	log_debug("Effect request sent for %d device(s), waiting for response...", len(devices))

	// Wait for success response
	response, recv_err := receive_message(client.socket_fd)
	if recv_err != .None {
		log_warn("Failed to receive Effect_Applied response: %v", recv_err)
		return
	}
	defer delete(response.payload)

	if response.type == .Effect_Applied {
		log_info("Effect applied successfully to %d device(s)", len(devices))
		fmt.printfln("Effect applied successfully!")
	} else {
		log_warn("Unexpected response type: %v", response.type)
		fmt.printfln("Error: Unexpected response from service")
	}
}


