// usb_context.odin
// Global USB context management for thread-safe libusb access

package main

import "core:c"
import "core:sync"

// Global USB context
global_usb_ctx: rawptr = nil
usb_init_mutex: sync.Mutex
usb_ref_count: int = 0

// Initialize or get reference to global USB context
get_usb_context :: proc() -> (ctx: rawptr, err: bool) {
	sync.mutex_lock(&usb_init_mutex)
	defer sync.mutex_unlock(&usb_init_mutex)

	if global_usb_ctx == nil {
		ret := libusb_init(&global_usb_ctx)
		if ret != LIBUSB_SUCCESS {
			return nil, true
		}
	}

	usb_ref_count += 1
	return global_usb_ctx, false
}

// Release reference to global USB context
release_usb_context :: proc() {
	sync.mutex_lock(&usb_init_mutex)
	defer sync.mutex_unlock(&usb_init_mutex)

	usb_ref_count -= 1
	if usb_ref_count <= 0 && global_usb_ctx != nil {
		libusb_exit(global_usb_ctx)
		global_usb_ctx = nil
		usb_ref_count = 0
	}
}
