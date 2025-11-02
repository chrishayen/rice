const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const ui = @import("ui.zig");
const device_card = @import("device_card.zig");

const c = gtk.c;

pub fn createDevicePanel(app_state: *ui.AppState) *gtk.GtkBox {
    // Create main vertical box for device panel
    const panel_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 0);
    c.gtk_widget_add_css_class(@ptrCast(panel_box), "background");

    // Create header with title and "Select All" button
    const header_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 8);
    c.gtk_widget_set_margin_start(@ptrCast(header_box), 12);
    c.gtk_widget_set_margin_end(@ptrCast(header_box), 12);
    c.gtk_widget_set_margin_top(@ptrCast(header_box), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(header_box), 12);

    // Create "Devices" title
    const title_label = c.gtk_label_new(null);
    c.gtk_label_set_markup(@ptrCast(title_label), "<b>Devices</b>");
    c.gtk_widget_set_halign(@ptrCast(title_label), c.GTK_ALIGN_START);
    c.gtk_widget_set_hexpand(@ptrCast(title_label), 1);
    c.gtk_box_append(@ptrCast(header_box), @as(*gtk.GtkWidget, @ptrCast(title_label)));

    // Create "Select All" button
    const select_all_button = c.gtk_button_new_with_label("Select All");
    c.gtk_widget_add_css_class(@ptrCast(select_all_button), "pill");
    c.gtk_widget_add_css_class(@ptrCast(select_all_button), "suggested-action");
    _ = c.g_signal_connect_data(
        select_all_button,
        "clicked",
        @as(c.GCallback, @ptrCast(&onSelectAllClicked)),
        app_state,
        null,
        0,
    );
    c.gtk_box_append(@ptrCast(header_box), @as(*gtk.GtkWidget, @ptrCast(select_all_button)));

    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(header_box)));

    // Create scrolled window for device list
    const scrolled_window = c.gtk_scrolled_window_new();
    c.gtk_widget_set_vexpand(@ptrCast(scrolled_window), 1);
    c.gtk_scrolled_window_set_policy(
        @ptrCast(scrolled_window),
        c.GTK_POLICY_NEVER,
        c.GTK_POLICY_AUTOMATIC,
    );

    // Create vertical box for device cards
    const device_list_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 8);
    c.gtk_widget_set_margin_start(@ptrCast(device_list_box), 12);
    c.gtk_widget_set_margin_end(@ptrCast(device_list_box), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(device_list_box), 12);
    app_state.device_list_box = @ptrCast(device_list_box);

    // Add device cards
    for (app_state.devices, 0..) |device, i| {
        const card = device_card.createDeviceCard(&device, @intCast(i), app_state);
        c.gtk_box_append(@ptrCast(device_list_box), @as(*gtk.GtkWidget, @ptrCast(card)));
    }

    c.gtk_scrolled_window_set_child(@ptrCast(scrolled_window), @as(*gtk.GtkWidget, @ptrCast(device_list_box)));
    c.gtk_box_append(@ptrCast(panel_box), @as(*gtk.GtkWidget, @ptrCast(scrolled_window)));

    return @ptrCast(panel_box);
}

fn onSelectAllClicked(button: *gtk.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
    _ = button;
    const app_state = @as(*ui.AppState, @ptrCast(@alignCast(user_data.?)));

    // Toggle all devices
    const all_selected = blk: {
        for (app_state.selected_devices) |selected| {
            if (!selected) break :blk false;
        }
        break :blk true;
    };

    // Set all to opposite of current state
    for (&app_state.selected_devices) |*selected| {
        selected.* = !all_selected;
    }

    // Update UI - would need to refresh device cards here
    // For now, just print status
    std.debug.print("Select all toggled: all_selected={}\n", .{!all_selected});
}
