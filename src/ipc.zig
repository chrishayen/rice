const std = @import("std");
const ipc_commands = @import("ipc_commands.zig");

pub const SocketError = error{
    CreateFailed,
    BindFailed,
    ListenFailed,
    AcceptFailed,
    ConnectFailed,
    SendFailed,
    ReceiveFailed,
    ParseFailed,
    SocketPathError,
    PathTooLong,
};

pub const SocketServer = struct {
    socket_fd: std.posix.socket_t,
    socket_path: []const u8,
    running: bool,
    allocator: std.mem.Allocator,
};

pub const SocketClient = struct {
    socket_fd: std.posix.socket_t,
    socket_path: []const u8,
    connected: bool,
    allocator: std.mem.Allocator,
};

pub fn createSocketServer(socket_path: []const u8, allocator: std.mem.Allocator) !SocketServer {
    const sock_fd = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    errdefer std.posix.close(sock_fd);

    var addr = std.net.Address.initUnix(socket_path) catch {
        return SocketError.PathTooLong;
    };

    try std.posix.bind(sock_fd, &addr.any, addr.getOsSockLen());
    try std.posix.listen(sock_fd, 5);

    // Set non-blocking
    const flags = try std.posix.fcntl(sock_fd, std.posix.F.GETFL, 0);
    const nonblock_flags = std.os.linux.O{ .NONBLOCK = true };
    _ = try std.posix.fcntl(sock_fd, std.posix.F.SETFL, flags | @as(u32, @bitCast(nonblock_flags)));

    return SocketServer{
        .socket_fd = sock_fd,
        .socket_path = try allocator.dupe(u8, socket_path),
        .running = true,
        .allocator = allocator,
    };
}

pub fn acceptConnection(server: *SocketServer) !std.posix.socket_t {
    if (!server.running) {
        return SocketError.AcceptFailed;
    }

    var addr: std.posix.sockaddr.un = undefined;
    var addr_len: std.posix.socklen_t = @sizeOf(@TypeOf(addr));

    const client_fd = std.posix.accept(server.socket_fd, @ptrCast(&addr), &addr_len, 0) catch {
        return SocketError.AcceptFailed;
    };

    return client_fd;
}

pub fn connectToServer(socket_path: []const u8, allocator: std.mem.Allocator) !SocketClient {
    const sock_fd = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    errdefer std.posix.close(sock_fd);

    var addr = std.net.Address.initUnix(socket_path) catch {
        return SocketError.PathTooLong;
    };

    try std.posix.connect(sock_fd, &addr.any, addr.getOsSockLen());

    return SocketClient{
        .socket_fd = sock_fd,
        .socket_path = try allocator.dupe(u8, socket_path),
        .connected = true,
        .allocator = allocator,
    };
}

pub fn sendMessage(socket_fd: std.posix.socket_t, msg: ipc_commands.IpcMessage) !void {
    const msg_type: u32 = @intFromEnum(msg.type);
    const payload_len: u32 = @intCast(msg.payload.len);

    // Send message type
    _ = try std.posix.send(socket_fd, std.mem.asBytes(&msg_type), 0);

    // Send payload length
    _ = try std.posix.send(socket_fd, std.mem.asBytes(&payload_len), 0);

    // Send payload if not empty
    if (payload_len > 0) {
        _ = try std.posix.send(socket_fd, msg.payload, 0);
    }
}

pub fn receiveMessage(socket_fd: std.posix.socket_t, allocator: std.mem.Allocator) !ipc_commands.IpcMessage {
    // Receive message type
    var msg_type: u32 = undefined;
    const type_bytes = try std.posix.recv(socket_fd, std.mem.asBytes(&msg_type), 0);
    if (type_bytes != @sizeOf(u32)) {
        return SocketError.ReceiveFailed;
    }

    // Receive payload length
    var payload_len: u32 = undefined;
    const len_bytes = try std.posix.recv(socket_fd, std.mem.asBytes(&payload_len), 0);
    if (len_bytes != @sizeOf(u32)) {
        return SocketError.ReceiveFailed;
    }

    // Receive payload if not empty
    var payload: []const u8 = "";
    if (payload_len > 0) {
        const payload_buf = try allocator.alloc(u8, payload_len);
        errdefer allocator.free(payload_buf);

        const recv_bytes = try std.posix.recv(socket_fd, payload_buf, 0);
        if (recv_bytes != payload_len) {
            allocator.free(payload_buf);
            return SocketError.ReceiveFailed;
        }

        payload = payload_buf;
    }

    return ipc_commands.IpcMessage{
        .type = @enumFromInt(msg_type),
        .payload = payload,
    };
}

pub fn closeServer(server: *SocketServer) void {
    if (server.running) {
        std.posix.close(server.socket_fd);
        server.running = false;

        // Clean up socket file
        std.fs.deleteFileAbsolute(server.socket_path) catch {};
    }
    server.allocator.free(server.socket_path);
}

pub fn closeClient(client: *SocketClient) void {
    if (client.connected) {
        std.posix.close(client.socket_fd);
        client.connected = false;
    }
    client.allocator.free(client.socket_path);
}
