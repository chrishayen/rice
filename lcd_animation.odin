// lcd_animation.odin
// Shared LCD animation frame management and sequencing

package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

// Frame list for LCD animations
LCD_Frame_List :: struct {
	frames_dir:  string,
	frame_paths: [dynamic]string,
}

// Animation sequencer for frame advancement
LCD_Animation_Sequencer :: struct {
	current_frame: int,
	total_frames:  int,
	loop:          bool,
}

// Enumerate all JPEG frames in a directory
enumerate_lcd_frames :: proc(
	frames_dir: string,
	allocator := context.allocator,
) -> (
	list: LCD_Frame_List,
	ok: bool,
) {
	// Read directory
	dir_handle, err := os.open(frames_dir)
	if err != os.ERROR_NONE {
		fmt.printfln("Error opening frames directory: %v", err)
		return {}, false
	}
	defer os.close(dir_handle)

	file_infos, read_err := os.read_dir(dir_handle, -1, allocator)
	if read_err != os.ERROR_NONE {
		fmt.printfln("Error reading frames directory: %v", read_err)
		return {}, false
	}
	defer delete(file_infos, allocator)

	// Collect .jpg files
	list.frame_paths = make([dynamic]string, 0, len(file_infos), allocator)

	for info in file_infos {
		if info.is_dir do continue

		// Check if it's a JPEG file
		ext := filepath.ext(info.name)
		if ext != ".jpg" && ext != ".jpeg" do continue

		// Build full path
		full_path := filepath.join({frames_dir, info.name}, allocator)
		append(&list.frame_paths, full_path)
	}

	// Sort frame paths alphabetically
	slice.sort(list.frame_paths[:])

	if len(list.frame_paths) == 0 {
		fmt.println("No JPEG frames found in directory")
		delete(list.frame_paths)
		return {}, false
	}

	list.frames_dir = strings.clone(frames_dir, allocator)

	return list, true
}

// Cleanup frame list
destroy_frame_list :: proc(list: ^LCD_Frame_List, allocator := context.allocator) {
	if list == nil do return

	if list.frames_dir != "" {
		delete(list.frames_dir, allocator)
	}

	// Clean up frame paths - safe to call on zero-initialized or empty dynamic arrays
	for path in list.frame_paths {
		delete(path, allocator)
	}
	if cap(list.frame_paths) > 0 {
		delete(list.frame_paths)
	}
}

// Initialize animation sequencer
init_sequencer :: proc(total_frames: int, loop: bool) -> LCD_Animation_Sequencer {
	return LCD_Animation_Sequencer{
		current_frame = 0,
		total_frames = total_frames,
		loop = loop,
	}
}

// Advance to next frame
// Returns: (frame_index, should_continue)
advance_frame :: proc(seq: ^LCD_Animation_Sequencer) -> (int, bool) {
	current := seq.current_frame

	seq.current_frame += 1
	if seq.current_frame >= seq.total_frames {
		if seq.loop {
			seq.current_frame = 0
		} else {
			return current, false  // Last frame, stop playback
		}
	}

	return current, true
}

// Reset sequencer to beginning
reset_sequencer :: proc(seq: ^LCD_Animation_Sequencer) {
	seq.current_frame = 0
}

// Load frame data from frame list
load_animation_frame :: proc(
	frame_list: ^LCD_Frame_List,
	frame_idx: int,
	allocator := context.allocator,
) -> (
	data: []u8,
	ok: bool,
) {
	if frame_idx < 0 || frame_idx >= len(frame_list.frame_paths) {
		return nil, false
	}

	frame_path := frame_list.frame_paths[frame_idx]
	return os.read_entire_file(frame_path, allocator)
}
