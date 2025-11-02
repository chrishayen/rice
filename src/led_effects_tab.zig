const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const ui = @import("ui.zig");
const device_cache = @import("device_cache.zig");
const ipc_client = @import("ipc_client.zig");

const c = gtk.c;

const ApplyThreadData = struct {
    ipc: *ipc_client.IpcClient,
    devices: []device_cache.DeviceCacheEntry,
    effect_name: []const u8,
    color1: [3]u8,
    color2: [3]u8,
    brightness: u8,
    allocator: std.mem.Allocator,
};

const EFFECT_NAMES = [_][]const u8{
    "Static",
    "Rainbow",
    "Breathing",
    "Alternating",
    "Wave",
    "Swirl",
    "Chase",
    "Bounce",
    "Stack",
    "Comet",
    "Gradient",
    "Pulse",
};

pub fn createLEDEffectsTab(app_state: *ui.AppState) *gtk.GtkBox {
    // Create main horizontal box (preview | controls)
    const main_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 0);

    // Create left panel (preview)
    const preview_panel = createPreviewPanel(app_state);
    c.gtk_widget_set_size_request(@ptrCast(preview_panel), 400, -1);
    c.gtk_box_append(@ptrCast(main_box), @as(*gtk.GtkWidget, @ptrCast(preview_panel)));

    // Create right panel (controls)
    const controls_panel = createControlsPanel(app_state);
    c.gtk_widget_set_hexpand(@ptrCast(controls_panel), 1);
    c.gtk_box_append(@ptrCast(main_box), @as(*gtk.GtkWidget, @ptrCast(controls_panel)));

    return @ptrCast(main_box);
}

fn createPreviewPanel(app_state: *ui.AppState) *gtk.GtkBox {
    const panel_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 0);
    c.gtk_widget_add_css_class(@ptrCast(panel_box), "background");

    // Create frame for preview
    const frame = c.gtk_frame_new(null);
    c.gtk_widget_set_margin_start(@ptrCast(frame), 12);
    c.gtk_widget_set_margin_end(@ptrCast(frame), 12);
    c.gtk_widget_set_margin_top(@ptrCast(frame), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(frame), 12);
    c.gtk_widget_set_vexpand(@ptrCast(frame), 1);

    // Create drawing area for preview
    const drawing_area = c.gtk_drawing_area_new();
    c.gtk_widget_set_vexpand(@ptrCast(drawing_area), 1);
    c.gtk_widget_set_hexpand(@ptrCast(drawing_area), 1);
    app_state.preview_area = @ptrCast(drawing_area);

    // Set draw function
    c.gtk_drawing_area_set_draw_func(
        @ptrCast(drawing_area),
        @ptrCast(&drawPreview),
        app_state,
        null,
    );

    // Add drag gesture for rotation
    const drag_gesture = c.gtk_gesture_drag_new();
    _ = c.g_signal_connect_data(
        drag_gesture,
        "drag-update",
        @as(c.GCallback, @ptrCast(&onDragUpdate)),
        app_state,
        null,
        0,
    );
    c.gtk_widget_add_controller(@ptrCast(drawing_area), @as(*c.GtkEventController, @ptrCast(drag_gesture)));

    c.gtk_frame_set_child(@ptrCast(frame), @as(*gtk.GtkWidget, @ptrCast(drawing_area)));
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(frame)));

    return @ptrCast(panel_box);
}

fn createControlsPanel(app_state: *ui.AppState) *gtk.GtkBox {
    const panel_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 12);
    c.gtk_widget_set_margin_start(@ptrCast(panel_box), 12);
    c.gtk_widget_set_margin_end(@ptrCast(panel_box), 12);
    c.gtk_widget_set_margin_top(@ptrCast(panel_box), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(panel_box), 12);

    // Effect selector section
    const effect_label = c.gtk_label_new(null);
    c.gtk_label_set_markup(@ptrCast(effect_label), "<b>Effect</b>");
    c.gtk_widget_set_halign(@ptrCast(effect_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(effect_label)));

    // Create string list for effects
    const string_list = c.gtk_string_list_new(null);
    for (EFFECT_NAMES) |name| {
        const name_with_null = std.fmt.allocPrint(app_state.allocator, "{s}\x00", .{name}) catch unreachable;
        defer app_state.allocator.free(name_with_null);
        c.gtk_string_list_append(@ptrCast(string_list), @ptrCast(name_with_null.ptr));
    }

    const effect_dropdown = c.gtk_drop_down_new(@ptrCast(string_list), null);
    app_state.effect_dropdown = @ptrCast(effect_dropdown);
    _ = c.g_signal_connect_data(
        effect_dropdown,
        "notify::selected",
        @as(c.GCallback, @ptrCast(&onEffectChanged)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(effect_dropdown)));

    // Color pickers section
    const colors_label = c.gtk_label_new(null);
    c.gtk_label_set_markup(@ptrCast(colors_label), "<b>Colors</b>");
    c.gtk_widget_set_halign(@ptrCast(colors_label), c.GTK_ALIGN_START);
    c.gtk_widget_set_margin_top(@ptrCast(colors_label), 12);
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(colors_label)));

    // Primary color
    const color1_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 8);
    const color1_label = c.gtk_label_new("Primary:");
    c.gtk_widget_set_hexpand(@ptrCast(color1_label), 1);
    c.gtk_widget_set_halign(@ptrCast(color1_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(color1_box), @as(*gtk.GtkWidget, @ptrCast(color1_label)));

    const color1_button = c.gtk_color_button_new_with_rgba(&app_state.color1);
    app_state.color1_button = @ptrCast(color1_button);
    _ = c.g_signal_connect_data(
        color1_button,
        "color-set",
        @as(c.GCallback, @ptrCast(&onColor1Changed)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(color1_box), @as(*gtk.GtkWidget, @ptrCast(color1_button)));
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(color1_box)));

    // Secondary color
    const color2_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 8);
    const color2_label = c.gtk_label_new("Secondary:");
    c.gtk_widget_set_hexpand(@ptrCast(color2_label), 1);
    c.gtk_widget_set_halign(@ptrCast(color2_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(color2_box), @as(*gtk.GtkWidget, @ptrCast(color2_label)));

    const color2_button = c.gtk_color_button_new_with_rgba(&app_state.color2);
    app_state.color2_button = @ptrCast(color2_button);
    _ = c.g_signal_connect_data(
        color2_button,
        "color-set",
        @as(c.GCallback, @ptrCast(&onColor2Changed)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(color2_box), @as(*gtk.GtkWidget, @ptrCast(color2_button)));
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(color2_box)));

    // Brightness slider
    const brightness_label = c.gtk_label_new(null);
    c.gtk_label_set_markup(@ptrCast(brightness_label), "<b>Brightness</b>");
    c.gtk_widget_set_halign(@ptrCast(brightness_label), c.GTK_ALIGN_START);
    c.gtk_widget_set_margin_top(@ptrCast(brightness_label), 12);
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(brightness_label)));

    const brightness_scale = c.gtk_scale_new_with_range(gtk.GTK_ORIENTATION_HORIZONTAL, 0, 100, 1);
    app_state.brightness_scale = @ptrCast(brightness_scale);
    c.gtk_range_set_value(@as(*c.GtkRange, @ptrCast(brightness_scale)), app_state.brightness);
    c.gtk_scale_set_draw_value(@ptrCast(brightness_scale), 1);
    c.gtk_scale_set_value_pos(@ptrCast(brightness_scale), c.GTK_POS_RIGHT);
    _ = c.g_signal_connect_data(
        brightness_scale,
        "value-changed",
        @as(c.GCallback, @ptrCast(&onBrightnessChanged)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(brightness_scale)));

    // Add spacer
    const spacer = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 0);
    c.gtk_widget_set_vexpand(@ptrCast(spacer), 1);
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(spacer)));

    // Action buttons
    const button_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 8);
    c.gtk_widget_set_halign(@ptrCast(button_box), c.GTK_ALIGN_END);

    const preview_button = c.gtk_button_new_with_label("Preview");
    c.gtk_box_append(@ptrCast(button_box), @as(*gtk.GtkWidget, @ptrCast(preview_button)));

    const apply_button = c.gtk_button_new_with_label("Apply");
    c.gtk_widget_add_css_class(@ptrCast(apply_button), "suggested-action");
    _ = c.g_signal_connect_data(
        apply_button,
        "clicked",
        @as(c.GCallback, @ptrCast(&onApplyClicked)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(button_box), @as(*gtk.GtkWidget, @ptrCast(apply_button)));

    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(button_box)));

    // Initially update visibility based on selected effect
    updateEffectOptionsVisibility(app_state);

    return @ptrCast(panel_box);
}

fn drawPreview(
    drawing_area: *gtk.GtkDrawingArea,
    cr: *gtk.cairo_t,
    width: c_int,
    height: c_int,
    user_data: ?*anyopaque,
) callconv(.c) void {
    _ = drawing_area;
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));
    _ = app_state;

    // Set background
    c.cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
    c.cairo_paint(cr);

    // Draw simple placeholder circle for now
    const center_x = @as(f64, @floatFromInt(width)) / 2.0;
    const center_y = @as(f64, @floatFromInt(height)) / 2.0;
    const radius = @min(center_x, center_y) * 0.6;

    c.cairo_set_source_rgb(cr, 0.3, 0.3, 0.3);
    c.cairo_arc(cr, center_x, center_y, radius, 0, 2 * std.math.pi);
    c.cairo_fill(cr);

    // Draw text
    c.cairo_set_source_rgb(cr, 0.7, 0.7, 0.7);
    c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
    c.cairo_set_font_size(cr, 14);

    const text = "3D Preview (Coming Soon)";
    var extents: c.cairo_text_extents_t = undefined;
    c.cairo_text_extents(cr, text, &extents);
    c.cairo_move_to(cr, center_x - extents.width / 2, center_y + extents.height / 2);
    c.cairo_show_text(cr, text);
}

fn onDragUpdate(
    gesture: *gtk.GtkGestureDrag,
    offset_x: f64,
    offset_y: f64,
    user_data: ?*anyopaque,
) callconv(.c) void {
    _ = gesture;
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));

    // Update rotation based on drag
    app_state.rotation_y += offset_x * 0.01;
    app_state.rotation_x += offset_y * 0.01;

    // Redraw preview
    if (app_state.preview_area) |preview_area| {
        c.gtk_widget_queue_draw(@ptrCast(preview_area));
    }
}

fn onEffectChanged(dropdown: *gtk.GtkDropDown, _: *c.GParamSpec, user_data: ?*anyopaque) callconv(.c) void {
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));
    app_state.selected_effect = @intCast(c.gtk_drop_down_get_selected(@ptrCast(dropdown)));
    updateEffectOptionsVisibility(app_state);
}

fn onColor1Changed(color_button: *gtk.GtkColorButton, user_data: ?*anyopaque) callconv(.c) void {
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));
    c.gtk_color_chooser_get_rgba(@as(*c.GtkColorChooser, @ptrCast(color_button)), &app_state.color1);
}

fn onColor2Changed(color_button: *gtk.GtkColorButton, user_data: ?*anyopaque) callconv(.c) void {
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));
    c.gtk_color_chooser_get_rgba(@as(*c.GtkColorChooser, @ptrCast(color_button)), &app_state.color2);
}

fn onBrightnessChanged(scale: *gtk.GtkScale, user_data: ?*anyopaque) callconv(.c) void {
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));
    app_state.brightness = c.gtk_range_get_value(@as(*c.GtkRange, @ptrCast(scale)));
}

fn onApplyClicked(button: *gtk.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
    _ = button;
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));

    // Collect selected devices
    var selected_devices: std.ArrayList(device_cache.DeviceCacheEntry) = .{};
    defer selected_devices.deinit(app_state.allocator);

    for (app_state.devices, 0..) |device, i| {
        if (i < app_state.selected_devices.items.len and app_state.selected_devices.items[i]) {
            selected_devices.append(app_state.allocator, device) catch continue;
        }
    }

    if (selected_devices.items.len == 0) {
        std.log.warn("No devices selected", .{});
        return;
    }

    // Get effect name
    const effect_name = EFFECT_NAMES[@intCast(app_state.selected_effect)];

    // Convert colors
    const color1 = [3]u8{
        @intFromFloat(app_state.color1.red * 255.0),
        @intFromFloat(app_state.color1.green * 255.0),
        @intFromFloat(app_state.color1.blue * 255.0),
    };
    const color2 = [3]u8{
        @intFromFloat(app_state.color2.red * 255.0),
        @intFromFloat(app_state.color2.green * 255.0),
        @intFromFloat(app_state.color2.blue * 255.0),
    };
    const brightness: u8 = @intFromFloat(app_state.brightness);

    // Spawn thread to apply effect
    const thread_data = app_state.allocator.create(ApplyThreadData) catch {
        std.log.warn("Failed to allocate memory for apply thread", .{});
        return;
    };

    thread_data.* = ApplyThreadData{
        .ipc = &app_state.ipc,
        .devices = selected_devices.toOwnedSlice(app_state.allocator) catch {
            app_state.allocator.destroy(thread_data);
            return;
        },
        .effect_name = effect_name,
        .color1 = color1,
        .color2 = color2,
        .brightness = brightness,
        .allocator = app_state.allocator,
    };

    const thread = std.Thread.spawn(.{}, applyEffectThread, .{thread_data}) catch |err| {
        std.log.warn("Failed to spawn apply thread: {}", .{err});
        app_state.allocator.free(thread_data.devices);
        app_state.allocator.destroy(thread_data);
        return;
    };
    thread.detach();

    std.log.info("Applying effect '{s}' to {} devices", .{ effect_name, thread_data.devices.len });
}

fn applyEffectThread(thread_data: *ApplyThreadData) void {
    defer {
        thread_data.allocator.free(thread_data.devices);
        thread_data.allocator.destroy(thread_data);
    }

    thread_data.ipc.setEffect(
        thread_data.devices,
        thread_data.effect_name,
        thread_data.color1,
        thread_data.color2,
        thread_data.brightness,
    ) catch |err| {
        std.log.warn("Failed to apply effect: {}", .{err});
    };
}

fn updateEffectOptionsVisibility(app_state: *ui.AppState) void {
    const effect_name = EFFECT_NAMES[@intCast(app_state.selected_effect)];

    // Determine which options are needed for this effect
    const needs_color1 = std.mem.eql(u8, effect_name, "Static") or
        std.mem.eql(u8, effect_name, "Alternating") or
        std.mem.eql(u8, effect_name, "Breathing");

    const needs_color2 = std.mem.eql(u8, effect_name, "Alternating");

    const needs_brightness = std.mem.eql(u8, effect_name, "Rainbow") or
        std.mem.eql(u8, effect_name, "Breathing");

    // Show/hide widgets based on effect requirements
    if (app_state.color1_button) |btn| {
        if (needs_color1) {
            c.gtk_widget_show(@as(*gtk.GtkWidget, @ptrCast(@alignCast(btn))));
        } else {
            c.gtk_widget_hide(@as(*gtk.GtkWidget, @ptrCast(@alignCast(btn))));
        }
    }

    if (app_state.color2_button) |btn| {
        if (needs_color2) {
            c.gtk_widget_show(@as(*gtk.GtkWidget, @ptrCast(@alignCast(btn))));
        } else {
            c.gtk_widget_hide(@as(*gtk.GtkWidget, @ptrCast(@alignCast(btn))));
        }
    }

    if (app_state.brightness_scale) |scale| {
        if (needs_brightness) {
            c.gtk_widget_show(@as(*gtk.GtkWidget, @ptrCast(@alignCast(scale))));
        } else {
            c.gtk_widget_hide(@as(*gtk.GtkWidget, @ptrCast(@alignCast(scale))));
        }
    }
}
