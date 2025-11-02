const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const mock_data = @import("mock_data.zig");
const device_panel = @import("device_panel.zig");
const led_effects_tab = @import("led_effects_tab.zig");
const ipc_client = @import("ipc_client.zig");
const device_cache = @import("device_cache.zig");

const c = gtk.c;

pub const AppState = struct {
    allocator: std.mem.Allocator,
    window: *gtk.AdwApplicationWindow,
    devices: []device_cache.DeviceCacheEntry,
    selected_devices: std.ArrayList(bool),
    ipc: ipc_client.IpcClient,

    // UI widget references
    device_list_box: ?*gtk.GtkBox,
    preview_area: ?*gtk.GtkDrawingArea,
    effect_dropdown: ?*gtk.GtkDropDown,
    color1_button: ?*gtk.GtkColorButton,
    color2_button: ?*gtk.GtkColorButton,
    brightness_scale: ?*gtk.GtkScale,

    // State
    selected_effect: i32,
    brightness: f64,
    color1: gtk.GdkRGBA,
    color2: gtk.GdkRGBA,

    // Rendering state
    rotation_x: f64,
    rotation_y: f64,
};

pub fn createMainWindow(app: *gtk.AdwApplication, allocator: std.mem.Allocator) !void {
    // Create main application window
    const window = c.adw_application_window_new(@as(*gtk.GtkApplication, @ptrCast(app)));
    c.gtk_window_set_title(@as(*gtk.GtkWindow, @ptrCast(window)), "Rice Studio Beta");
    c.gtk_window_set_default_size(@as(*gtk.GtkWindow, @ptrCast(window)), 1200, 700);

    // Initialize IPC client
    var ipc = try ipc_client.IpcClient.init(allocator);
    errdefer ipc.deinit();

    // Try to get devices from service, fall back to empty list if service not running
    const devices = ipc.getDevices() catch |err| blk: {
        std.log.warn("Failed to connect to service: {}", .{err});
        std.log.info("Starting with empty device list. Start the service with 'rice --server'", .{});
        break :blk try allocator.alloc(device_cache.DeviceCacheEntry, 0);
    };

    var selected_devices: std.ArrayList(bool) = .{};
    try selected_devices.resize(allocator, devices.len);
    for (selected_devices.items) |*sel| {
        sel.* = false;
    }

    // Initialize app state
    const app_state = try allocator.create(AppState);
    app_state.* = AppState{
        .allocator = allocator,
        .window = @ptrCast(window),
        .devices = devices,
        .selected_devices = selected_devices,
        .ipc = ipc,
        .device_list_box = null,
        .preview_area = null,
        .effect_dropdown = null,
        .color1_button = null,
        .color2_button = null,
        .brightness_scale = null,
        .selected_effect = 0,
        .brightness = 100.0,
        .color1 = gtk.GdkRGBA{ .red = 1.0, .green = 0.0, .blue = 0.0, .alpha = 1.0 },
        .color2 = gtk.GdkRGBA{ .red = 0.0, .green = 0.0, .blue = 1.0, .alpha = 1.0 },
        .rotation_x = 0.0,
        .rotation_y = 0.0,
    };

    // Create main vertical box
    const main_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 0);

    // Create header bar
    const header_bar = c.adw_header_bar_new();

    // Create window title
    const window_title = c.adw_window_title_new("Rice Studio Beta", "");
    c.adw_header_bar_set_title_widget(@ptrCast(header_bar), @as(*gtk.GtkWidget, @ptrCast(window_title)));

    // Create refresh button
    const refresh_button = c.gtk_button_new_with_label("Refresh Devices");
    c.adw_header_bar_pack_end(@ptrCast(header_bar), @as(*gtk.GtkWidget, @ptrCast(refresh_button)));

    // Add header bar to main box
    c.gtk_box_append(@ptrCast(main_box), @as(*gtk.GtkWidget, @ptrCast(header_bar)));

    // Create horizontal paned container
    const paned = c.gtk_paned_new(gtk.GTK_ORIENTATION_HORIZONTAL);
    c.gtk_widget_set_hexpand(@ptrCast(paned), 1);
    c.gtk_widget_set_vexpand(@ptrCast(paned), 1);

    // Create left panel (device list)
    const left_panel = device_panel.createDevicePanel(app_state);
    c.gtk_paned_set_start_child(@ptrCast(paned), @as(*gtk.GtkWidget, @ptrCast(left_panel)));
    c.gtk_paned_set_resize_start_child(@ptrCast(paned), 0);
    c.gtk_widget_set_size_request(@as(*gtk.GtkWidget, @ptrCast(left_panel)), 300, -1);

    // Create right panel (tabs)
    const right_panel = createTabView(app_state);
    c.gtk_paned_set_end_child(@ptrCast(paned), @as(*gtk.GtkWidget, @ptrCast(@alignCast(right_panel))));

    // Add paned to main box
    c.gtk_box_append(@ptrCast(main_box), @as(*gtk.GtkWidget, @ptrCast(paned)));

    // Set window content
    c.adw_application_window_set_content(@ptrCast(window), @as(*gtk.GtkWidget, @ptrCast(main_box)));

    // Show window
    c.gtk_window_present(@as(*gtk.GtkWindow, @ptrCast(window)));

    // Schedule identify devices to run asynchronously after UI is shown
    if (devices.len > 0) {
        _ = c.g_idle_add(@ptrCast(&identifyDevicesIdle), app_state);
    }
}

fn identifyDevicesIdle(user_data: ?*anyopaque) callconv(.c) c.gboolean {
    const app_state = @as(*AppState, @ptrCast(@alignCast(user_data.?)));

    // Spawn a thread to avoid blocking the UI
    const thread = std.Thread.spawn(.{}, identifyDevicesThread, .{app_state}) catch |err| {
        std.log.warn("Failed to spawn identify thread: {}", .{err});
        return 0;
    };
    thread.detach();

    return 0; // Return 0 to remove the idle callback
}

fn identifyDevicesThread(app_state: *AppState) void {
    app_state.ipc.identifyDevices(app_state.devices) catch |err| {
        std.log.warn("Failed to identify devices: {}", .{err});
    };
}

fn createTabView(app_state: *AppState) *c.GtkNotebook {
    // Create notebook (simple tabs without close buttons)
    const notebook = c.gtk_notebook_new();
    c.gtk_widget_set_vexpand(@ptrCast(@alignCast(notebook)), 1);

    // Create LED Effects tab
    const led_tab_content = led_effects_tab.createLEDEffectsTab(app_state);
    const led_label = c.gtk_label_new("LED Effects");
    _ = c.gtk_notebook_append_page(
        @ptrCast(notebook),
        @as(*gtk.GtkWidget, @ptrCast(led_tab_content)),
        @as(*gtk.GtkWidget, @ptrCast(led_label)),
    );

    // Create LCD Display tab (placeholder)
    const lcd_content = c.gtk_label_new("LCD Display - Coming Soon");
    c.gtk_widget_set_vexpand(@ptrCast(lcd_content), 1);
    c.gtk_widget_set_hexpand(@ptrCast(lcd_content), 1);
    const lcd_label = c.gtk_label_new("LCD Display");
    _ = c.gtk_notebook_append_page(
        @ptrCast(notebook),
        @as(*gtk.GtkWidget, @ptrCast(lcd_content)),
        @as(*gtk.GtkWidget, @ptrCast(lcd_label)),
    );

    // Create Settings tab (placeholder)
    const settings_group = c.adw_preferences_group_new();
    c.adw_preferences_group_set_title(@ptrCast(settings_group), "Channel Configuration");
    c.adw_preferences_group_set_description(@ptrCast(settings_group), "Configure device channels and preferences");
    c.gtk_widget_set_margin_start(@ptrCast(settings_group), 12);
    c.gtk_widget_set_margin_end(@ptrCast(settings_group), 12);
    c.gtk_widget_set_margin_top(@ptrCast(settings_group), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(settings_group), 12);

    const settings_scroll = c.gtk_scrolled_window_new();
    c.gtk_scrolled_window_set_child(@ptrCast(settings_scroll), @as(*gtk.GtkWidget, @ptrCast(settings_group)));
    c.gtk_widget_set_vexpand(@ptrCast(settings_scroll), 1);

    const settings_label = c.gtk_label_new("Settings");
    _ = c.gtk_notebook_append_page(
        @ptrCast(notebook),
        @as(*gtk.GtkWidget, @ptrCast(settings_scroll)),
        @as(*gtk.GtkWidget, @ptrCast(settings_label)),
    );

    return @ptrCast(notebook);
}
