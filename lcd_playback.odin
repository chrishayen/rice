// lcd_playback.odin
// LCD video playback thread management

package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:thread"
import "core:time"

// LCD playback state for a single device
LCD_Playback_State :: struct {
	device:        LCD_Device,
	frames_dir:    string,
	frame_paths:   [dynamic]string,
	current_frame: int,
	fps:           f32,
	loop:          bool,
	transform:     LCD_Transform,
	running:       bool,
	thread:        ^thread.Thread,
}

// Create a new playback state
create_lcd_playback :: proc(bus: int, address: int, frames_dir: string, fps: f32 = 20.0, loop: bool = true, transform: LCD_Transform = {}, allocator := context.allocator) -> (^LCD_Playback_State, LCD_Error) {
	state := new(LCD_Playback_State, allocator)

	// Initialize LCD device
	device, err := init_lcd_device(bus, address)
	if err != .None {
		free(state, allocator)
		return nil, err
	}

	state.device = device
	state.frames_dir = strings.clone(frames_dir, allocator)
	state.fps = fps
	state.loop = loop
	state.transform = transform
	state.running = false
	state.current_frame = 0

	// Enumerate frame files
	err2 := enumerate_frames(state, allocator)
	if err2 != .None {
		cleanup_lcd_device(&state.device)
		delete(state.frames_dir, allocator)
		free(state, allocator)
		return nil, err2
	}

	fmt.printfln("LCD Playback initialized: %d frames, %.1f fps", len(state.frame_paths), fps)

	return state, .None
}

// Enumerate all frame files in the directory
enumerate_frames :: proc(state: ^LCD_Playback_State, allocator := context.allocator) -> LCD_Error {
	// Read directory
	dir_handle, err := os.open(state.frames_dir)
	if err != os.ERROR_NONE {
		fmt.printfln("Error opening frames directory: %v", err)
		return .Device_Not_Found
	}
	defer os.close(dir_handle)

	file_infos, read_err := os.read_dir(dir_handle, -1, allocator)
	if read_err != os.ERROR_NONE {
		fmt.printfln("Error reading frames directory: %v", read_err)
		return .Device_Not_Found
	}
	defer delete(file_infos, allocator)

	// Collect .jpg files
	state.frame_paths = make([dynamic]string, 0, len(file_infos), allocator)

	for info in file_infos {
		if info.is_dir do continue

		// Check if it's a JPEG file
		ext := filepath.ext(info.name)
		if ext != ".jpg" && ext != ".jpeg" do continue

		// Build full path
		full_path := filepath.join({state.frames_dir, info.name}, allocator)
		append(&state.frame_paths, full_path)
	}

	// Sort frame paths alphabetically
	slice.sort(state.frame_paths[:])

	if len(state.frame_paths) == 0 {
		fmt.println("No JPEG frames found in directory")
		return .Device_Not_Found
	}

	return .None
}

// Playback thread function
lcd_playback_thread :: proc(data: rawptr) {
	state := cast(^LCD_Playback_State)data
	context = runtime.default_context()

	fmt.printfln("LCD playback thread started: %d frames at %.1f fps", len(state.frame_paths), state.fps)

	frame_delay := time.Duration(1.0 / f64(state.fps) * f64(time.Second))
	frame_count := 0
	start_time := time.now()

	for state.running {
		// Get current frame path
		frame_path := state.frame_paths[state.current_frame]

		// Load frame file
		frame_data, ok := os.read_entire_file(frame_path, context.allocator)
		if !ok {
			fmt.printfln("Error loading frame: %s", frame_path)
			time.sleep(frame_delay)
			continue
		}
		defer delete(frame_data, context.allocator)

		// Process image with transforms if needed
		final_frame_data := frame_data
		needs_processing := state.transform.zoom_percent > 0 ||
		                    state.transform.rotate_degrees != 0 ||
		                    state.transform.rotation_speed != 0 ||
		                    state.transform.flip_horizontal

		if needs_processing {
			processed, proc_ok := process_lcd_image(frame_data, state.transform, state.current_frame, context.allocator)
			if proc_ok {
				defer delete(processed, context.allocator)
				final_frame_data = processed
			} else {
				fmt.printfln("Error processing frame %d, using original", state.current_frame)
			}
		}

		// Send frame to LCD
		send_err := send_lcd_frame(&state.device, final_frame_data)
		if send_err != .None {
			fmt.printfln("Error sending frame %d: %v", state.current_frame, send_err)
		} else if state.current_frame < 5 {
			fmt.printfln("Successfully sent frame %d (%d bytes)", state.current_frame, len(frame_data))
		}

		// Advance to next frame
		state.current_frame += 1
		if state.current_frame >= len(state.frame_paths) {
			if state.loop {
				state.current_frame = 0
			} else {
				break
			}
		}

		// Stats every second
		frame_count += 1
		if frame_count % int(state.fps) == 0 {
			elapsed := time.since(start_time)
			actual_fps := f64(frame_count) / time.duration_seconds(elapsed)
			fmt.printfln("LCD playback: frame %d/%d, actual FPS: %.1f",
				state.current_frame, len(state.frame_paths), actual_fps)
		}

		// Sleep for frame delay
		time.sleep(frame_delay)
	}

	fmt.println("LCD playback thread stopped")
}

// Start playback
start_lcd_playback :: proc(state: ^LCD_Playback_State) {
	if state.running do return

	state.running = true
	state.current_frame = 0

	state.thread = thread.create_and_start_with_data(state, lcd_playback_thread)
}

// Stop playback
stop_lcd_playback_state :: proc(state: ^LCD_Playback_State) {
	if !state.running do return

	state.running = false

	if state.thread != nil {
		thread.join(state.thread)
		thread.destroy(state.thread)
		state.thread = nil
	}
}

// Cleanup playback state
destroy_lcd_playback :: proc(state: ^LCD_Playback_State, allocator := context.allocator) {
	stop_lcd_playback_state(state)

	cleanup_lcd_device(&state.device)

	delete(state.frames_dir, allocator)

	for path in state.frame_paths {
		delete(path, allocator)
	}
	delete(state.frame_paths)

	free(state, allocator)
}
