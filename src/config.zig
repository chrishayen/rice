const std = @import("std");

pub const ConfigError = error{
    CreateDirFailed,
    GetHomeFailed,
    InvalidPath,
};

pub fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return ConfigError.GetHomeFailed;

    const config_dir = try std.fs.path.join(allocator, &.{ home, ".config", "rice" });
    return config_dir;
}

pub fn getSocketPath(allocator: std.mem.Allocator) ![]const u8 {
    const config_dir = try getConfigDir(allocator);
    defer allocator.free(config_dir);

    const socket_path = try std.fs.path.join(allocator, &.{ config_dir, "rice.sock" });
    return socket_path;
}

pub fn initConfigDir(allocator: std.mem.Allocator) !void {
    const config_dir = try getConfigDir(allocator);
    defer allocator.free(config_dir);

    std.fs.makeDirAbsolute(config_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            return ConfigError.CreateDirFailed;
        }
    };
}

pub fn cleanupSocket(allocator: std.mem.Allocator) bool {
    const socket_path = getSocketPath(allocator) catch return false;
    defer allocator.free(socket_path);

    std.fs.deleteFileAbsolute(socket_path) catch |err| {
        if (err != error.FileNotFound) {
            return false;
        }
    };

    return true;
}
