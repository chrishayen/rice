// ipc.odin
// Unix domain socket transport for IPC
package main

import "core:os"
import "core:c"
import "core:strings"

// POSIX socket bindings
foreign import libc "system:c"

AF_UNIX :: 1
SOCK_STREAM :: 1

sockaddr_un :: struct #packed {
	sun_family: c.ushort,
	sun_path:   [108]c.char,
}

@(default_calling_convention="c")
foreign libc {
	socket :: proc(domain: c.int, type: c.int, protocol: c.int) -> c.int ---
	bind :: proc(sockfd: c.int, addr: ^sockaddr_un, addrlen: c.uint) -> c.int ---
	listen :: proc(sockfd: c.int, backlog: c.int) -> c.int ---
	accept :: proc(sockfd: c.int, addr: ^sockaddr_un, addrlen: ^c.uint) -> c.int ---
	connect :: proc(sockfd: c.int, addr: ^sockaddr_un, addrlen: c.uint) -> c.int ---
	send :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int) -> c.ssize_t ---
	recv :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int) -> c.ssize_t ---
	close :: proc(fd: c.int) -> c.int ---
	fcntl :: proc(fd: c.int, cmd: c.int, #c_vararg args: ..any) -> c.int ---

	// epoll functions
	epoll_create1 :: proc(flags: c.int) -> c.int ---
	epoll_ctl :: proc(epfd: c.int, op: c.int, fd: c.int, event: ^epoll_event) -> c.int ---
	epoll_wait :: proc(epfd: c.int, events: [^]epoll_event, maxevents: c.int, timeout: c.int) -> c.int ---
}

// fcntl constants
F_GETFL :: 3
F_SETFL :: 4
O_NONBLOCK :: 2048

// epoll constants
EPOLL_CLOEXEC :: 0x80000
EPOLL_CTL_ADD :: 1
EPOLL_CTL_DEL :: 2
EPOLL_CTL_MOD :: 3
EPOLLIN :: 0x001
EPOLLOUT :: 0x004
EPOLLERR :: 0x008
EPOLLHUP :: 0x010
EPOLLET :: 1 << 31

// epoll_event structure
epoll_event :: struct #packed {
	events: u32,
	data:   epoll_data,
}

epoll_data :: struct #raw_union {
	ptr: rawptr,
	fd:  c.int,
	u32: u32,
	u64: u64,
}

Socket_Error :: enum {
	None,
	Create_Failed,
	Bind_Failed,
	Listen_Failed,
	Accept_Failed,
	Connect_Failed,
	Send_Failed,
	Receive_Failed,
	Parse_Failed,
	Socket_Path_Error,
	Path_Too_Long,
}

// Socket server for service
Socket_Server :: struct {
	socket_fd:   c.int,
	socket_path: string,
	running:     bool,
}

// Socket client for UI
Socket_Client :: struct {
	socket_fd:   c.int,
	socket_path: string,
	connected:   bool,
}

// Create and bind socket server
create_socket_server :: proc(socket_path: string) -> (Socket_Server, Socket_Error) {
	server := Socket_Server{
		socket_path = strings.clone(socket_path),
		running = false,
	}

	// Create Unix domain socket
	sock_fd := socket(AF_UNIX, SOCK_STREAM, 0)
	if sock_fd < 0 {
		return server, .Create_Failed
	}

	server.socket_fd = sock_fd

	// Prepare socket address
	addr: sockaddr_un
	addr.sun_family = AF_UNIX

	// Copy path to sun_path
	path_cstr := strings.clone_to_cstring(socket_path)
	defer delete(path_cstr)

	path_len := len(socket_path)
	if path_len >= len(addr.sun_path) {
		close(sock_fd)
		return server, .Path_Too_Long
	}

	for i in 0..<path_len {
		addr.sun_path[i] = c.char(socket_path[i])
	}
	addr.sun_path[path_len] = 0

	// Bind socket
	addr_len := c.uint(size_of(c.ushort) + path_len + 1)
	if bind(sock_fd, &addr, addr_len) < 0 {
		close(sock_fd)
		return server, .Bind_Failed
	}

	// Listen for connections
	if listen(sock_fd, 5) < 0 {
		close(sock_fd)
		return server, .Listen_Failed
	}

	server.running = true

	// Set socket to non-blocking mode
	flags := fcntl(sock_fd, F_GETFL, 0)
	fcntl(sock_fd, F_SETFL, flags | O_NONBLOCK)

	return server, .None
}

// Accept client connection (non-blocking placeholder)
accept_connection :: proc(server: ^Socket_Server) -> (c.int, Socket_Error) {
	if !server.running {
		return -1, .Accept_Failed
	}

	client_fd := accept(server.socket_fd, nil, nil)
	if client_fd < 0 {
		return -1, .Accept_Failed
	}

	return client_fd, .None
}

// Connect to socket server
connect_to_server :: proc(socket_path: string) -> (Socket_Client, Socket_Error) {
	client := Socket_Client{
		socket_path = strings.clone(socket_path),
		connected = false,
	}

	// Create Unix domain socket
	sock_fd := socket(AF_UNIX, SOCK_STREAM, 0)
	if sock_fd < 0 {
		return client, .Create_Failed
	}

	client.socket_fd = sock_fd

	// Prepare socket address
	addr: sockaddr_un
	addr.sun_family = AF_UNIX

	// Copy path to sun_path
	path_cstr := strings.clone_to_cstring(socket_path)
	defer delete(path_cstr)

	path_len := len(socket_path)
	if path_len >= len(addr.sun_path) {
		close(sock_fd)
		return client, .Path_Too_Long
	}

	for i in 0..<path_len {
		addr.sun_path[i] = c.char(socket_path[i])
	}
	addr.sun_path[path_len] = 0

	// Connect to server
	addr_len := c.uint(size_of(c.ushort) + path_len + 1)
	if connect(sock_fd, &addr, addr_len) < 0 {
		close(sock_fd)
		return client, .Connect_Failed
	}

	client.connected = true
	return client, .None
}

// Send message to server/client
send_message :: proc(socket_fd: c.int, msg: IPC_Message) -> Socket_Error {
	// Simple protocol: send message type (4 bytes) + payload length (4 bytes) + payload
	msg_type := u32(msg.type)
	payload_len := u32(len(msg.payload))

	// Send message type
	if send(socket_fd, &msg_type, size_of(u32), 0) < 0 {
		return .Send_Failed
	}

	// Send payload length
	if send(socket_fd, &payload_len, size_of(u32), 0) < 0 {
		return .Send_Failed
	}

	// Send payload if not empty
	if payload_len > 0 {
		payload_cstr := strings.clone_to_cstring(msg.payload)
		defer delete(payload_cstr)

		if send(socket_fd, rawptr(payload_cstr), c.size_t(payload_len), 0) < 0 {
			return .Send_Failed
		}
	}

	return .None
}

// Receive message from socket
receive_message :: proc(socket_fd: c.int) -> (IPC_Message, Socket_Error) {
	msg: IPC_Message

	// Receive message type
	msg_type: u32
	if recv(socket_fd, &msg_type, size_of(u32), 0) <= 0 {
		return msg, .Receive_Failed
	}
	msg.type = Message_Type(msg_type)

	// Receive payload length
	payload_len: u32
	if recv(socket_fd, &payload_len, size_of(u32), 0) <= 0 {
		return msg, .Receive_Failed
	}

	// Receive payload if not empty
	if payload_len > 0 {
		payload_buf := make([]byte, payload_len)

		if recv(socket_fd, raw_data(payload_buf), c.size_t(payload_len), 0) <= 0 {
			delete(payload_buf)
			return msg, .Receive_Failed
		}

		// Convert to string and clone to avoid pointing to deleted memory
		msg.payload = strings.clone(string(payload_buf))
		delete(payload_buf)
	}

	return msg, .None
}

// Close socket server
close_server :: proc(server: ^Socket_Server) {
	if server.socket_fd >= 0 {
		close(server.socket_fd)
	}
	server.running = false

	// Clean up socket file
	if os.exists(server.socket_path) {
		os.remove(server.socket_path)
	}

	delete(server.socket_path)
}

// Close socket client
close_client :: proc(client: ^Socket_Client) {
	if client.socket_fd >= 0 {
		close(client.socket_fd)
	}
	client.connected = false
	delete(client.socket_path)
}
