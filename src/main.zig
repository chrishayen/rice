const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const ui = @import("ui.zig");

const c = gtk.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize GTK
    const app = c.adw_application_new("dev.shotgun.rice", c.G_APPLICATION_DEFAULT_FLAGS);
    defer c.g_object_unref(app);

    // Connect activate signal
    _ = c.g_signal_connect_data(
        app,
        "activate",
        @as(c.GCallback, @ptrCast(&onActivate)),
        @ptrCast(@alignCast(@constCast(&allocator))),
        null,
        0,
    );

    // Run the application
    const status = c.g_application_run(@as(*c.GApplication, @ptrCast(app)), 0, null);
    std.process.exit(@intCast(status));
}

fn onActivate(app: *gtk.AdwApplication, user_data: ?*anyopaque) callconv(.c) void {
    const allocator_ptr = @as(*std.mem.Allocator, @ptrCast(@alignCast(user_data.?)));
    ui.createMainWindow(app, allocator_ptr.*) catch |err| {
        std.debug.print("Failed to create main window: {}\n", .{err});
    };
}
