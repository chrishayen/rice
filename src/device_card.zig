const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const mock_data = @import("mock_data.zig");
const ui = @import("ui.zig");

const c = gtk.c;

const DeviceCardData = struct {
    app_state: *ui.AppState,
    device_index: usize,
};

pub fn createDeviceCard(device: *const mock_data.Device, index: usize, app_state: *ui.AppState) *gtk.GtkToggleButton {
    // Create toggle button for the card
    const toggle_button = c.gtk_toggle_button_new();
    c.gtk_widget_add_css_class(@ptrCast(toggle_button), "card");

    // Create vertical box for card content
    const card_box = c.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 4);
    c.gtk_widget_set_margin_start(@ptrCast(card_box), 12);
    c.gtk_widget_set_margin_end(@ptrCast(card_box), 12);
    c.gtk_widget_set_margin_top(@ptrCast(card_box), 12);
    c.gtk_widget_set_margin_bottom(@ptrCast(card_box), 12);

    // Device name (bold)
    const name_label = c.gtk_label_new(null);
    const name_markup = std.fmt.allocPrint(app_state.allocator, "<b>{s}</b>\x00", .{device.name}) catch unreachable;
    defer app_state.allocator.free(name_markup);
    c.gtk_label_set_markup(@ptrCast(name_label), @ptrCast(name_markup.ptr));
    c.gtk_widget_set_halign(@ptrCast(name_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(card_box), @as(*gtk.GtkWidget, @ptrCast(name_label)));

    // MAC address
    const mac_label = c.gtk_label_new(device.mac_address.ptr);
    c.gtk_widget_add_css_class(@ptrCast(mac_label), "dim-label");
    c.gtk_widget_set_halign(@ptrCast(mac_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(card_box), @as(*gtk.GtkWidget, @ptrCast(mac_label)));

    // Info box (fans, LEDs, channel)
    const info_box = c.gtk_box_new(gtk.GTK_ORIENTATION_HORIZONTAL, 12);

    const fans_text = std.fmt.allocPrint(app_state.allocator, "Fans: {d}\x00", .{device.fan_count}) catch unreachable;
    defer app_state.allocator.free(fans_text);
    const fans_label = c.gtk_label_new(@ptrCast(fans_text.ptr));
    c.gtk_widget_add_css_class(@ptrCast(fans_label), "dim-label");
    c.gtk_box_append(@ptrCast(info_box), @as(*gtk.GtkWidget, @ptrCast(fans_label)));

    const leds_text = std.fmt.allocPrint(app_state.allocator, "LEDs: {d}\x00", .{device.led_count}) catch unreachable;
    defer app_state.allocator.free(leds_text);
    const leds_label = c.gtk_label_new(@ptrCast(leds_text.ptr));
    c.gtk_widget_add_css_class(@ptrCast(leds_label), "dim-label");
    c.gtk_box_append(@ptrCast(info_box), @as(*gtk.GtkWidget, @ptrCast(leds_label)));

    const channel_text = std.fmt.allocPrint(app_state.allocator, "Ch: {d}\x00", .{device.channel}) catch unreachable;
    defer app_state.allocator.free(channel_text);
    const channel_label = c.gtk_label_new(@ptrCast(channel_text.ptr));
    c.gtk_widget_add_css_class(@ptrCast(channel_label), "dim-label");
    c.gtk_box_append(@ptrCast(info_box), @as(*gtk.GtkWidget, @ptrCast(channel_label)));

    c.gtk_widget_set_halign(@ptrCast(info_box), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(card_box), @as(*gtk.GtkWidget, @ptrCast(info_box)));

    // Binding status
    const binding_text = if (device.is_bound) "Bound" else "Not Bound";
    const binding_label = c.gtk_label_new(binding_text);
    c.gtk_widget_add_css_class(@ptrCast(binding_label), "dim-label");
    if (device.is_bound) {
        c.gtk_widget_add_css_class(@ptrCast(binding_label), "success");
    } else {
        c.gtk_widget_add_css_class(@ptrCast(binding_label), "warning");
    }
    c.gtk_widget_set_halign(@ptrCast(binding_label), c.GTK_ALIGN_START);
    c.gtk_box_append(@ptrCast(card_box), @as(*gtk.GtkWidget, @ptrCast(binding_label)));

    // Set card content
    c.gtk_button_set_child(@as(*gtk.GtkButton, @ptrCast(toggle_button)), @as(*gtk.GtkWidget, @ptrCast(card_box)));

    // Store callback data
    const callback_data = app_state.allocator.create(DeviceCardData) catch unreachable;
    callback_data.* = DeviceCardData{
        .app_state = app_state,
        .device_index = index,
    };

    // Connect toggle signal
    _ = c.g_signal_connect_data(
        toggle_button,
        "toggled",
        @as(c.GCallback, @ptrCast(&onDeviceToggled)),
        callback_data,
        null,
        0,
    );

    return @ptrCast(toggle_button);
}

fn onDeviceToggled(toggle_button: *gtk.GtkToggleButton, user_data: ?*anyopaque) callconv(.c) void {
    const data = @as(*DeviceCardData, @ptrCast(@alignCast(user_data.?)));
    const is_active = c.gtk_toggle_button_get_active(@ptrCast(toggle_button)) != 0;

    data.app_state.selected_devices[data.device_index] = is_active;
    std.debug.print("Device {} toggled: {}\n", .{ data.device_index, is_active });
}
