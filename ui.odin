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
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import stbi "vendor:stb/image"

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
GListModel :: distinct rawptr
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
cairo_surface_t :: distinct rawptr

cairo_format_t :: enum c.int {
	INVALID   = -1,
	ARGB32    = 0,
	RGB24     = 1,
	A8        = 2,
	A1        = 3,
	RGB16_565 = 4,
	RGB30     = 5,
}

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
	gtk_string_list_remove :: proc(list: GtkStringList, position: c.uint) ---
	gtk_drop_down_new :: proc(model: rawptr, expression: rawptr) -> GtkWidget ---
	gtk_drop_down_set_selected :: proc(dropdown: GtkDropDown, position: c.uint) ---
	gtk_drop_down_get_selected :: proc(dropdown: GtkDropDown) -> c.uint ---
	gtk_drop_down_set_model :: proc(dropdown: GtkDropDown, model: rawptr) ---
	gtk_drop_down_get_model :: proc(dropdown: GtkDropDown) -> GListModel ---

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
	g_list_model_get_n_items :: proc(list: GListModel) -> c.uint ---
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
	cairo_clip :: proc(cr: cairo_t) ---
	cairo_translate :: proc(cr: cairo_t, tx, ty: c.double) ---
	cairo_rotate :: proc(cr: cairo_t, angle: c.double) ---
	cairo_scale :: proc(cr: cairo_t, sx, sy: c.double) ---

	// Surface functions
	cairo_image_surface_create_for_data :: proc(data: rawptr, format: cairo_format_t, width, height, stride: c.int) -> cairo_surface_t ---
	cairo_surface_destroy :: proc(surface: cairo_surface_t) ---
	cairo_set_source_surface :: proc(cr: cairo_t, surface: cairo_surface_t, x, y: c.double) ---
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
	led_devices:           [dynamic]UI_LED_Device,  // LED/RF devices
	lcd_devices:           [dynamic]UI_LCD_Device,  // LCD/USB devices
	devices:               [dynamic]Device,         // Old unified list (to be removed)
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
	lcd_fan_dropdown:         GtkDropDown,
	lcd_frames_dropdown:      GtkDropDown,
	lcd_frames_row:           AdwActionRow,  // Row containing frames selection, for updating subtitle
	lcd_preview_area:         GtkDrawingArea,
	selected_lcd_device:      string,  // Serial number of selected LCD device, "" if none selected
	selected_lcd_fan:         int,     // Fan index within the device, -1 if none selected
	available_frame_sequences: [dynamic]string,  // List of discovered frame sequences
	usb_lcd_devices:          [dynamic]USB_LCD_Device,  // USB LCD devices indexed by rx_type

	// LCD preview rendering
	lcd_raylib_processor:   LCD_Raylib_Processor,  // Raylib processor for preview
	lcd_preview_surface:    cairo_surface_t,        // Cairo surface for rendering to GTK
	lcd_preview_frame:      []u8,                   // Current preview frame (JPEG data)
	lcd_preview_transform:  LCD_Transform,          // Current transform settings

	// LCD preview playback
	lcd_preview_frames:    LCD_Frame_List,          // Frame list from shared module
	lcd_preview_sequencer: LCD_Animation_Sequencer, // Frame sequencing from shared module
	lcd_preview_timer_id:  c.uint,                  // GTK timer ID for playback
	lcd_preview_playing:   bool,                    // Whether preview is playing
	lcd_preview_fps:       f32,                     // Playback FPS
}

// UI LED Device (RF-based, identified by MAC address)
UI_LED_Device :: struct {
	mac_str:       string,
	rx_type:       u8,
	channel:       u8,
	bound:         bool,
	led_count:     int,
	fan_count:     int,
	dev_type_name: string,
}

// UI LCD Device (USB-based, identified by serial number)
UI_LCD_Device :: struct {
	serial_number: string,
	fan_count:     int,
	fan_types:     [4]u8,
	friendly_name: string,
}

// Old unified Device struct (to be removed after migration)
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
	state.selected_lcd_device = ""
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

	// Initialize raylib processor for LCD preview
	lcd_processor, lcd_ok := init_lcd_raylib_processor(LCD_WIDTH, LCD_HEIGHT)
	if lcd_ok {
		state.lcd_raylib_processor = lcd_processor
		fmt.println("LCD raylib processor initialized for preview")
	} else {
		fmt.println("Warning: Failed to initialize raylib processor for LCD preview")
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
	if state.lcd_raylib_processor.initialized {
		cleanup_lcd_raylib_processor(&state.lcd_raylib_processor)
	}
	if state.lcd_preview_frame != nil {
		delete(state.lcd_preview_frame)
	}
	if state.lcd_preview_surface != nil {
		cairo_surface_destroy(state.lcd_preview_surface)
	}
	// Stop preview playback
	stop_lcd_preview_playback(state)
	// Cleanup preview frame list
	destroy_frame_list(&state.lcd_preview_frames)
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

	// Show window - add close handler to stop preview
	on_window_close :: proc "c" (window: rawptr, user_data: rawptr) -> c.bool {
		context = runtime.default_context()
		state := cast(^App_State)user_data
		stop_lcd_preview_playback(state)
		return false // Allow window to close
	}

	g_signal_connect_data(
		window,
		"close-request",
		auto_cast on_window_close,
		state,
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
	gtk_widget_set_size_request(frame, 400, 400)  // Fixed 400x400 size
	gtk_widget_set_vexpand(frame, false)
	gtk_widget_set_hexpand(frame, false)
	gtk_widget_set_halign(frame, .CENTER)
	gtk_widget_set_valign(frame, .START)
	gtk_box_append(auto_cast box, frame)

	// Drawing area for LCD preview (400x400 to match actual LCD resolution)
	state.lcd_preview_area = auto_cast gtk_drawing_area_new()
	gtk_drawing_area_set_content_width(state.lcd_preview_area, 400)
	gtk_drawing_area_set_content_height(state.lcd_preview_area, 400)
	gtk_widget_set_size_request(auto_cast state.lcd_preview_area, 400, 400)
	gtk_widget_set_hexpand(auto_cast state.lcd_preview_area, false)
	gtk_widget_set_vexpand(auto_cast state.lcd_preview_area, false)
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
	adw_preferences_group_set_description(auto_cast source_group, "Select frame sequence for video playback")
	gtk_box_append(auto_cast box, source_group)

	// Frame sequence selection row
	state.lcd_frames_row = auto_cast adw_action_row_new()
	adw_preferences_row_set_title(state.lcd_frames_row, "Frame Sequence")
	adw_action_row_set_subtitle(state.lcd_frames_row, "No sequence selected")

	// Create dropdown for frame sequences
	frames_list := gtk_string_list_new(nil)
	gtk_string_list_append(frames_list, "Select a sequence...")
	state.lcd_frames_dropdown = auto_cast gtk_drop_down_new(frames_list, nil)
	gtk_drop_down_set_selected(state.lcd_frames_dropdown, 0)
	gtk_widget_set_size_request(auto_cast state.lcd_frames_dropdown, 300, -1)
	adw_action_row_add_suffix(state.lcd_frames_row, auto_cast state.lcd_frames_dropdown)
	adw_preferences_group_add(auto_cast source_group, auto_cast state.lcd_frames_row)

	// Connect signal for dropdown selection changes
	g_signal_connect_data(state.lcd_frames_dropdown, "notify::selected", auto_cast on_lcd_frames_selected, state, nil, 0)

	// Populate frame sequences list (will be updated when LCD tab is shown)
	populate_lcd_frame_sequences(state)

	// Action button
	button_box := auto_cast gtk_box_new(.HORIZONTAL, 12)
	gtk_widget_set_halign(button_box, .CENTER)
	gtk_widget_set_margin_top(button_box, 20)
	gtk_box_append(auto_cast box, button_box)

	apply_btn := auto_cast gtk_button_new_with_label("Apply to Device")
	gtk_widget_add_css_class(apply_btn, "suggested-action")
	gtk_widget_add_css_class(apply_btn, "pill")
	gtk_widget_set_size_request(apply_btn, 150, 48)
	g_signal_connect_data(apply_btn, "clicked", auto_cast on_lcd_apply_clicked, state, nil, 0)
	gtk_box_append(auto_cast button_box, apply_btn)

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
	extents: cairo_text_extents_t

	// Fixed LCD display dimensions
	LCD_SIZE :: 400.0
	center_x := LCD_SIZE / 2.0
	center_y := LCD_SIZE / 2.0
	radius := LCD_SIZE / 2.0

	// Clear background
	cairo_set_source_rgb(cr, 0.0, 0.0, 0.0)
	cairo_paint(cr)

	// If we have a preview frame and raylib processor, draw it
	if state.lcd_preview_frame != nil && state.lcd_raylib_processor.initialized && state.lcd_preview_surface != nil {
		// Draw black circular background for LCD
		cairo_arc(cr, center_x, center_y, radius, 0, 2 * 3.14159265359)
		cairo_set_source_rgb(cr, 0.05, 0.05, 0.05)
		cairo_fill(cr)

		// Save cairo state for clipping
		cairo_save(cr)

		// Create circular clipping path
		cairo_arc(cr, center_x, center_y, radius, 0, 2 * 3.14159265359)
		cairo_clip(cr)

		// Draw the cached surface
		cairo_set_source_surface(cr, state.lcd_preview_surface, 0, 0)
		cairo_paint(cr)

		// Restore cairo state
		cairo_restore(cr)
	} else {
		// No preview - show status message
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
			} else if state.selected_lcd_device == "" {
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
	}

	// If a fan is selected, show device info at top
	if state.selected_lcd_device != "" {
		cairo_set_font_size(cr, 12)
		cairo_set_source_rgb(cr, 0.6, 0.6, 0.6)

		// Show device serial number and fan info at top
		info_text := fmt.tprintf("Device: %s | Fan: %d", state.selected_lcd_device, state.selected_lcd_fan)
		info_cstr := strings.clone_to_cstring(info_text)
		defer delete(info_cstr)

		cairo_text_extents(cr, info_cstr, &extents)
		info_x := (c.double(width) - extents.width) / 2
		cairo_move_to(cr, info_x, 30)
		cairo_show_text(cr, info_cstr)
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

// Scan for available frame sequences in ~/.config/rice/lcd_frames/
populate_lcd_frame_sequences :: proc(state: ^App_State) {
	// Clear existing sequences
	for seq in state.available_frame_sequences {
		delete(seq)
	}
	clear(&state.available_frame_sequences)

	// Get config directory
	config_dir, err := get_config_dir()
	if err != .None {
		fmt.eprintln("Failed to get config directory for frame sequences")
		return
	}
	defer delete(config_dir)

	frames_base_dir := fmt.aprintf("%s/lcd_frames", config_dir)
	defer delete(frames_base_dir)

	// Check if the base directory exists
	if !os.exists(frames_base_dir) {
		fmt.eprintfln("LCD frames directory does not exist: %s", frames_base_dir)
		return
	}

	// Read directory contents
	handle, open_err := os.open(frames_base_dir)
	if open_err != 0 {
		fmt.eprintfln("Failed to open LCD frames directory: %s", frames_base_dir)
		return
	}
	defer os.close(handle)

	file_infos, read_err := os.read_dir(handle, -1)
	if read_err != 0 {
		fmt.eprintfln("Failed to read LCD frames directory")
		return
	}
	defer os.file_info_slice_delete(file_infos)

	// Find subdirectories
	for info in file_infos {
		if info.is_dir {
			// IMPORTANT: Must clone the string because filepath.base returns a slice
			// into info.fullpath, which will be freed when file_infos is deleted
			sequence_name := strings.clone(filepath.base(info.fullpath))
			append(&state.available_frame_sequences, sequence_name)
		}
	}

	// Update the dropdown list
	if state.lcd_frames_dropdown != nil {
		// Get the model
		model := gtk_drop_down_get_model(state.lcd_frames_dropdown)
		string_list := cast(GtkStringList)model

		// Clear existing items (except the placeholder)
		n_items := g_list_model_get_n_items(model)
		for i := n_items - 1; i > 0; i -= 1 {
			gtk_string_list_remove(string_list, c.uint(i))
		}

		// Add discovered sequences
		for seq in state.available_frame_sequences {
			cstr := strings.clone_to_cstring(seq)
			defer delete(cstr)
			gtk_string_list_append(string_list, cstr)
		}
	}

	fmt.printfln("Found %d frame sequences", len(state.available_frame_sequences))
}

// Update LCD frames dropdown to match a given path
update_lcd_frames_dropdown_from_path :: proc(state: ^App_State, frames_dir: string) {
	if state.lcd_frames_dropdown == nil do return

	// Extract sequence name from path (last component after lcd_frames/)
	// Expected format: /path/to/.config/rice/lcd_frames/sequence_name
	sequence_name := filepath.base(frames_dir)

	// Find the sequence in our list
	found_idx := -1
	for seq, idx in state.available_frame_sequences {
		if seq == sequence_name {
			found_idx = idx
			break
		}
	}

	if found_idx >= 0 {
		// Set dropdown to this sequence (add 1 for placeholder at index 0)
		gtk_drop_down_set_selected(state.lcd_frames_dropdown, c.uint(found_idx + 1))

		// Update subtitle
		cstr := strings.clone_to_cstring(sequence_name)
		defer delete(cstr)
		adw_action_row_set_subtitle(state.lcd_frames_row, cstr)
	}
}

// Load LCD preview from saved configuration
load_lcd_preview_from_config :: proc(state: ^App_State, settings: App_Settings) {
	// Load transform from LCD config for selected device and fan
	transform := LCD_Transform{zoom_percent = 35.0} // Default
	if state.selected_lcd_device != "" && state.selected_lcd_fan >= 0 {
		fan_transform, err := get_lcd_fan_transform(state.selected_lcd_device, state.selected_lcd_fan)
		if err == .None {
			transform = fan_transform
		}
	}

	state.lcd_preview_transform = transform

	// Try to load frames from saved config
	if state.selected_lcd_device != "" && state.selected_lcd_fan >= 0 {
		frames_dir, dir_err := get_lcd_fan_frames_dir(state.selected_lcd_device, state.selected_lcd_fan)
		defer delete(frames_dir)

		if dir_err == .None && frames_dir != "" {
			// Load frame list from saved directory
			if load_preview_frames_list(state, frames_dir) {
				// Start playback at 20 FPS
				start_lcd_preview_playback(state, 20.0)
				fmt.printfln("Loaded frames from saved config: %s", frames_dir)

				// Update the UI to show which sequence is selected
				update_lcd_frames_dropdown_from_path(state, frames_dir)
			}
		} else {
			fmt.printfln("No frames directory saved for device %s fan %d", state.selected_lcd_device, state.selected_lcd_fan)
		}
	}
}

// Update LCD preview with a new frame and transform
update_lcd_preview :: proc(state: ^App_State, jpeg_data: []u8, transform: LCD_Transform) {
	if !state.lcd_raylib_processor.initialized do return

	// Process frame with raylib
	processed, ok := process_lcd_frame_raylib(
		&state.lcd_raylib_processor,
		jpeg_data,
		transform,
		0, // frame number (not animated in preview)
	)
	if !ok do return
	defer delete(processed)

	// Decode processed JPEG to create Cairo surface
	width, height, channels: c.int
	pixels := stbi.load_from_memory(
		raw_data(processed),
		c.int(len(processed)),
		&width,
		&height,
		&channels,
		4, // Force RGBA
	)
	if pixels == nil do return
	defer stbi.image_free(pixels)

	// Convert RGBA to Cairo's ARGB32 format (BGRA byte order on little-endian)
	pixel_data := ([^]u8)(pixels)[:width * height * 4]
	cairo_data := make([]u8, width * height * 4)

	for i in 0..<(width * height) {
		r := pixel_data[i*4 + 0]
		g := pixel_data[i*4 + 1]
		b := pixel_data[i*4 + 2]
		a := pixel_data[i*4 + 3]

		// Cairo ARGB32 format is actually BGRA in memory on little-endian
		// Premultiply alpha
		af := f32(a) / 255.0
		cairo_data[i*4 + 0] = u8(f32(b) * af)  // B
		cairo_data[i*4 + 1] = u8(f32(g) * af)  // G
		cairo_data[i*4 + 2] = u8(f32(r) * af)  // R
		cairo_data[i*4 + 3] = a                 // A
	}

	// Create Cairo surface from pixel data
	if state.lcd_preview_surface != nil {
		cairo_surface_destroy(state.lcd_preview_surface)
	}

	state.lcd_preview_surface = cairo_image_surface_create_for_data(
		raw_data(cairo_data),
		.ARGB32,
		width,
		height,
		width * 4, // stride
	)

	// Store the frame and cairo data
	if state.lcd_preview_frame != nil {
		delete(state.lcd_preview_frame)
	}
	state.lcd_preview_frame = cairo_data
	state.lcd_preview_transform = transform

	// Redraw preview
	if state.lcd_preview_area != nil {
		gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
	}
}

// Load list of preview frames from directory (using shared module)
load_preview_frames_list :: proc(state: ^App_State, frames_dir: string) -> bool {
	// Clear existing frame list
	destroy_frame_list(&state.lcd_preview_frames)

	// Enumerate frames using shared module
	frames, ok := enumerate_lcd_frames(frames_dir)
	if !ok do return false

	state.lcd_preview_frames = frames
	return true
}

// Timer callback for preview playback
lcd_preview_timer_callback :: proc "c" (user_data: rawptr) -> c.bool {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	if !state.lcd_preview_playing || len(state.lcd_preview_frames.frame_paths) == 0 || state.lcd_preview_area == nil {
		return false // Stop timer
	}

	// Get current frame and advance sequencer
	frame_idx, should_continue := advance_frame(&state.lcd_preview_sequencer)
	if !should_continue do return false // Playback ended (non-looping)

	// Load current frame using shared module
	frame_data, ok := load_animation_frame(&state.lcd_preview_frames, frame_idx)
	if ok {
		update_lcd_preview(state, frame_data, state.lcd_preview_transform)
		delete(frame_data)
	}

	return true // Continue timer
}

// Start LCD preview playback
start_lcd_preview_playback :: proc(state: ^App_State, fps: f32 = 20.0) {
	if state.lcd_preview_playing do return
	if len(state.lcd_preview_frames.frame_paths) == 0 do return

	state.lcd_preview_playing = true
	state.lcd_preview_fps = fps

	// Initialize sequencer with looping enabled
	state.lcd_preview_sequencer = init_sequencer(len(state.lcd_preview_frames.frame_paths), loop = true)

	// Calculate interval in milliseconds
	interval := c.uint(1000.0 / fps)

	// Start timer
	state.lcd_preview_timer_id = g_timeout_add(interval, auto_cast lcd_preview_timer_callback, state)
}

// Stop LCD preview playback
stop_lcd_preview_playback :: proc(state: ^App_State) {
	if !state.lcd_preview_playing do return

	state.lcd_preview_playing = false

	// Remove timer
	if state.lcd_preview_timer_id != 0 {
		foreign glib {
			g_source_remove :: proc(tag: c.uint) -> c.bool ---
		}
		g_source_remove(state.lcd_preview_timer_id)
		state.lcd_preview_timer_id = 0
	}
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
		state.selected_lcd_device = ""
		state.selected_lcd_fan = -1
		// Stop preview playback when deselecting
		stop_lcd_preview_playback(state)
		gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
		return
	}

	// Calculate which LCD device and fan based on selection (accounting for placeholder at index 0)
	// Index 1 = first LCD fan (device 0, fan 0), index 2 = second LCD fan, etc.
	lcd_fan_count := 1  // Start at 1 because 0 is placeholder
	for lcd_device in state.lcd_devices {
		for fan_idx in 0..<lcd_device.fan_count {
			if lcd_fan_count == selected {
				state.selected_lcd_device = lcd_device.serial_number
				state.selected_lcd_fan = fan_idx
				fmt.printfln("Selected LCD fan: SN=%s, Fan %d",
					lcd_device.serial_number, fan_idx)

				// Stop any existing preview playback
				stop_lcd_preview_playback(state)

				// Load preview from saved configuration
				settings, settings_err := load_settings()
				if settings_err == .None {
					load_lcd_preview_from_config(state, settings)
				}

				// Redraw LCD preview
				gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
				return
			}
			lcd_fan_count += 1
		}
	}

	// If we get here, selection index was invalid - reset
	state.selected_lcd_device = ""
	state.selected_lcd_fan = -1
	gtk_widget_queue_draw(auto_cast state.lcd_preview_area)
}

// Handler for frame sequence selection
on_lcd_frames_selected :: proc "c" (dropdown: GtkDropDown, pspec: rawptr, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	selected := int(gtk_drop_down_get_selected(dropdown))

	// Index 0 is the placeholder "Select a sequence..."
	if selected == 0 || selected > len(state.available_frame_sequences) {
		adw_action_row_set_subtitle(state.lcd_frames_row, "No sequence selected")
		return
	}

	// Get selected sequence name (accounting for placeholder at index 0)
	sequence_name := state.available_frame_sequences[selected - 1]

	// Update subtitle to show selected sequence
	cstr := strings.clone_to_cstring(sequence_name)
	defer delete(cstr)
	adw_action_row_set_subtitle(state.lcd_frames_row, cstr)

	// Get config directory and build full path
	config_dir, err := get_config_dir()
	if err != .None {
		fmt.eprintln("Failed to get config directory")
		return
	}
	defer delete(config_dir)

	frames_dir := fmt.aprintf("%s/lcd_frames/%s", config_dir, sequence_name)
	defer delete(frames_dir)

	// Load frames and update preview
	if load_preview_frames_list(state, frames_dir) {
		// Start playback at 20 FPS to preview the frames
		start_lcd_preview_playback(state, 20.0)
		fmt.printfln("Loaded frame sequence: %s", sequence_name)
	} else {
		fmt.eprintfln("Failed to load frames from: %s", frames_dir)
	}
}

// Handler for Apply button - saves config and starts playback on device
on_lcd_apply_clicked :: proc "c" (button: GtkButton, user_data: rawptr) {
	context = runtime.default_context()
	state := cast(^App_State)user_data

	// Check if we have a selected LCD fan
	if state.selected_lcd_device == "" || state.selected_lcd_fan < 0 {
		fmt.eprintln("No LCD fan selected")
		return
	}

	// Check if we have a selected frame sequence
	selected_idx := int(gtk_drop_down_get_selected(state.lcd_frames_dropdown))
	if selected_idx == 0 || selected_idx > len(state.available_frame_sequences) {
		fmt.eprintln("No frame sequence selected")
		return
	}

	sequence_name := state.available_frame_sequences[selected_idx - 1]

	// Get config directory and build full path
	config_dir, err := get_config_dir()
	if err != .None {
		fmt.eprintln("Failed to get config directory")
		return
	}
	defer delete(config_dir)

	frames_dir := fmt.aprintf("%s/lcd_frames/%s", config_dir, sequence_name)
	defer delete(frames_dir)

	// Save frames directory to config for this device/fan (using serial number)
	save_err := update_lcd_fan_frames_dir(state.selected_lcd_device, state.selected_lcd_fan, frames_dir)
	if save_err != .None {
		fmt.eprintfln("Failed to save LCD frames directory to config: %v", save_err)
		return
	}

	fmt.printfln("Saved frames directory for device %s fan %d: %s",
		state.selected_lcd_device, state.selected_lcd_fan, frames_dir)

	// Send IPC command to service to start playback on the actual device
	fmt.printfln("Sending LCD playback command to service...")
	success := send_start_lcd_playback_request(
		state.selected_lcd_device,  // Serial number
		state.selected_lcd_fan,
		frames_dir,
		20.0, // FPS
		state.lcd_preview_transform, // Use current transform settings
	)

	if success {
		fmt.printfln("Successfully applied LCD configuration to device")
	} else {
		fmt.eprintfln("Failed to start LCD playback on device (check that service is running)")
	}
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

// Enumerate USB LCD devices independently using serial numbers
enumerate_usb_lcd_devices :: proc(state: ^App_State) {
	clear(&state.lcd_devices)

	// Load device cache to know which fans have LCD screens
	cached_devices, cache_err := load_device_cache()
	if cache_err != .None {
		fmt.printfln("Warning: Failed to load device cache for LCD enumeration: %v", cache_err)
	}
	defer {
		for dev in cached_devices {
			delete(dev.mac_str)
			delete(dev.dev_type_name)
			delete(dev.usb_serial_number)
		}
		delete(cached_devices)
	}

	// Build map of (usb_serial_number) -> fan_types array
	serial_to_fans := make(map[string][4]u8)
	defer delete(serial_to_fans)

	for cached_dev in cached_devices {
		if cached_dev.usb_serial_number != "" {
			serial_to_fans[cached_dev.usb_serial_number] = cached_dev.fan_types
		}
	}

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

		// Open device to read serial number
		usb_handle: rawptr
		ret = libusb_open(device, &usb_handle)
		if ret != LIBUSB_SUCCESS {
			fmt.printfln("Warning: Failed to open LCD device (bus %d, addr %d)",
				libusb_get_bus_number(device), libusb_get_device_address(device))
			continue
		}
		defer libusb_close(usb_handle)

		// Read serial number
		serial_number := get_usb_serial_number(device, usb_handle)
		if serial_number == "" {
			fmt.printfln("Warning: Failed to read serial number from LCD device (bus %d, addr %d)",
				libusb_get_bus_number(device), libusb_get_device_address(device))
			continue
		}

		// Get fan types from cache (if available)
		fan_types, has_cache := serial_to_fans[serial_number]
		if !has_cache {
			// No cache data - assume all 4 fan positions might have LCD
			// User will need to run the service to populate the cache for filtering
			fmt.printfln("Warning: No cache data for LCD device SN=%s, showing all fan positions", serial_number)
			fan_types = {0, 0, 0, 0}  // Unknown - will show all in dropdown and filter there
		}

		// Create friendly name (last 8 chars of serial or full serial if shorter)
		friendly_name := serial_number
		if len(serial_number) > 8 {
			friendly_name = fmt.aprintf("LCD %s", serial_number[len(serial_number)-8:])
		} else {
			friendly_name = fmt.aprintf("LCD %s", serial_number)
		}

		lcd_dev := UI_LCD_Device {
			serial_number = serial_number,
			fan_count = 4,  // Maximum possible (we filter in dropdown)
			fan_types = fan_types,  // Actual fan types from cache
			friendly_name = friendly_name,
		}
		append(&state.lcd_devices, lcd_dev)

		fmt.printfln("Found USB LCD device: SN=%s", serial_number)
	}

	fmt.printfln("Total USB LCD devices found: %d", len(state.lcd_devices))
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

	// Add LCD fans from LCD devices (only fans that have LCD screens)
	for lcd_device in state.lcd_devices {
		// Check each fan position
		for fan_idx in 0..<4 {
			fan_type := lcd_device.fan_types[fan_idx]

			// If fan types are unknown (0), show all fan positions
			// Otherwise only add fans with LCD capability (types 24 or 25)
			if fan_type != 0 && fan_type != 24 && fan_type != 25 {
				continue
			}

			// Format: "LCD XXXXXXXX - Fan N"
			label := fmt.aprintf("%s - Fan %d", lcd_device.friendly_name, fan_idx)
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
	state.selected_lcd_device = ""
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

// TODO: Update to take serial_number once UI can map MAC to serial number
send_start_lcd_playback_request :: proc(serial_number: string, fan_index: int, frames_dir: string, fps: f32, transform: LCD_Transform) -> bool {
	// Get socket path
	socket_path, path_err := get_socket_path()
	defer delete(socket_path)

	if path_err != .None {
		log_warn("Failed to get socket path: %v", path_err)
		fmt.eprintfln("Error: Could not get socket path")
		return false
	}

	// Connect to service
	client, connect_err := connect_to_server(socket_path)
	defer close_client(&client)

	if connect_err != .None {
		log_warn("Failed to connect to service: %v (is service running?)", connect_err)
		fmt.eprintfln("Error: Could not connect to service. Is the service running?")
		return false
	}

	// Build LCD playback request
	lcd_req := Start_LCD_Playback_Request{
		serial_number = serial_number,
		fan_index = fan_index,
		frames_dir = frames_dir,
		fps = fps,
		transform = transform,
	}

	// Marshal to JSON
	json_data, marshal_err := json.marshal(lcd_req)
	if marshal_err != nil {
		log_warn("Failed to marshal LCD playback request: %v", marshal_err)
		fmt.eprintfln("Error: Failed to create request")
		return false
	}
	defer delete(json_data)

	// Send Start_LCD_Playback request
	request := IPC_Message{
		type = .Start_LCD_Playback,
		payload = string(json_data),
	}

	send_err := send_message(client.socket_fd, request)
	if send_err != .None {
		log_warn("Failed to send Start_LCD_Playback request: %v", send_err)
		fmt.eprintfln("Error: Failed to send request to service")
		return false
	}

	log_debug("LCD playback request sent, waiting for response...")

	// Wait for success response
	response, recv_err := receive_message(client.socket_fd)
	if recv_err != .None {
		log_warn("Failed to receive LCD_Playback_Started response: %v", recv_err)
		fmt.eprintfln("Error: Failed to receive response from service")
		return false
	}
	defer delete(response.payload)

	if response.type == .LCD_Playback_Started {
		log_info("LCD playback started successfully: %s", response.payload)
		fmt.printfln("LCD playback started successfully: %s", response.payload)
		return true
	} else if response.type == .Error {
		log_warn("LCD playback start failed: %s", response.payload)
		fmt.eprintfln("Error starting LCD playback: %s", response.payload)
		return false
	} else {
		log_warn("Unexpected response type: %v", response.type)
		fmt.eprintfln("Error: Unexpected response from service")
		return false
	}
}


