const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const ui = @import("ui.zig");

const c = gtk.c;

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
    c.gtk_box_append(@ptrCast(button_box), @as(*gtk.GtkWidget, @ptrCast(apply_button)));

    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(button_box)));

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
