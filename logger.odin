// logger.odin
// Simple logger with log levels
package main

import "core:fmt"
import "core:time"
import "core:os"

Log_Level :: enum {
	DEBUG,
	INFO,
	WARN,
	ERROR,
}

Logger :: struct {
	level: Log_Level,
	show_timestamps: bool,
}

global_logger: Logger

init_logger :: proc(level: Log_Level = .INFO, show_timestamps := true) {
	global_logger.level = level
	global_logger.show_timestamps = show_timestamps
}

get_timestamp :: proc() -> string {
	now := time.now()
	h, m, s := time.clock(now)
	return fmt.tprintf("%02d:%02d:%02d", h, m, s)
}

get_level_prefix :: proc(level: Log_Level) -> string {
	switch level {
	case .DEBUG: return "[DEBUG]"
	case .INFO:  return "[INFO] "
	case .WARN:  return "[WARN] "
	case .ERROR: return "[ERROR]"
	}
	return "[?????]"
}

should_log :: proc(level: Log_Level) -> bool {
	return level >= global_logger.level
}

log_debug :: proc(format: string, args: ..any) {
	if !should_log(.DEBUG) {
		return
	}

	if global_logger.show_timestamps {
		fmt.printf("%s %s ", get_timestamp(), get_level_prefix(.DEBUG))
	} else {
		fmt.printf("%s ", get_level_prefix(.DEBUG))
	}
	fmt.printf(format, ..args)
	fmt.println()
}

log_info :: proc(format: string, args: ..any) {
	if !should_log(.INFO) {
		return
	}

	if global_logger.show_timestamps {
		fmt.printf("%s %s ", get_timestamp(), get_level_prefix(.INFO))
	} else {
		fmt.printf("%s ", get_level_prefix(.INFO))
	}
	fmt.printf(format, ..args)
	fmt.println()
}

log_warn :: proc(format: string, args: ..any) {
	if !should_log(.WARN) {
		return
	}

	if global_logger.show_timestamps {
		fmt.eprintf("%s %s ", get_timestamp(), get_level_prefix(.WARN))
	} else {
		fmt.eprintf("%s ", get_level_prefix(.WARN))
	}
	fmt.eprintf(format, ..args)
	fmt.eprintln()
}

log_error :: proc(format: string, args: ..any) {
	if !should_log(.ERROR) {
		return
	}

	if global_logger.show_timestamps {
		fmt.eprintf("%s %s ", get_timestamp(), get_level_prefix(.ERROR))
	} else {
		fmt.eprintf("%s ", get_level_prefix(.ERROR))
	}
	fmt.eprintf(format, ..args)
	fmt.eprintln()
}
