// main.odin
// Entry point for Lian Li Fan Control
// Runs as either a service (--server) or GTK UI
package main

import "core:fmt"
import "core:os"

main :: proc() {
	args := os.args[1:]

	run_as_server := false
	debug_mode := false

	// Parse command line arguments
	for arg in args {
		if arg == "--server" {
			run_as_server = true
		}
		if arg == "--debug" {
			debug_mode = true
		}
		if arg == "--help" || arg == "-h" {
			print_usage()
			return
		}
	}

	// Initialize logger
	if debug_mode {
		init_logger(.DEBUG, show_timestamps = true)
	} else {
		init_logger(.INFO, show_timestamps = true)
	}

	if run_as_server {
		run_service()
		return
	}

	run_ui()
}

print_usage :: proc() {
	fmt.println("Lian Li Fan Control")
	fmt.println()
	fmt.println("Usage:")
	fmt.println("  rice              Run GTK UI (default)")
	fmt.println("  rice --server     Run as background service")
	fmt.println("  rice --debug      Enable debug logging")
	fmt.println("  rice --help       Show this help message")
	fmt.println()
	fmt.println("Examples:")
	fmt.println("  rice --server --debug   Run service with debug output")
	fmt.println()
}
