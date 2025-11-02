const std = @import("std");
const gtk = @import("gtk_bindings.zig");
const ui = @import("ui.zig");
const service = @import("service.zig");

const c = gtk.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var run_as_server = false;
    var debug_mode = false;

    _ = args.skip(); // skip program name
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--server")) {
            run_as_server = true;
        } else if (std.mem.eql(u8, arg, "--debug")) {
            debug_mode = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        }
    }

    // Set log level
    if (debug_mode) {
        // Zig logging is controlled via build options or pub const std_options
        std.log.info("Debug mode enabled", .{});
    }

    if (run_as_server) {
        try service.runService(allocator);
        return;
    }

    // Run UI
    runUi(allocator);
}

fn runUi(allocator: std.mem.Allocator) void {
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

fn printUsage() void {
    std.debug.print("Lian Li Fan Control\n\n", .{});
    std.debug.print("Usage:\n", .{});
    std.debug.print("  rice              Run GTK UI (default)\n", .{});
    std.debug.print("  rice --server     Run as background service\n", .{});
    std.debug.print("  rice --debug      Enable debug logging\n", .{});
    std.debug.print("  rice --help       Show this help message\n\n", .{});
    std.debug.print("Examples:\n", .{});
    std.debug.print("  rice --server --debug   Run service with debug output\n\n", .{});
}
