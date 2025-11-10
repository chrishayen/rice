// lcd_playback.odin
// LCD video playback thread management

package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:sync/chan"
import "core:thread"
import "core:time"

// LCD playback state for a single device
LCD_Playback_State :: struct {
	device:           ^LCD_Device,             // Reference to device (owned by service, not playback)
	frames:           LCD_Frame_List,          // Frame list from shared module
	sequencer:        LCD_Animation_Sequencer, // Frame sequencing from shared module
	fps:              f32,
	transform:        LCD_Transform,
	running:          bool,
	thread:           ^thread.Thread,
	raylib_processor: LCD_Raylib_Processor,  // Raylib image processor
	use_raylib:       bool,                   // Whether to use raylib processing
	stop_chan:        chan.Chan(bool),        // Channel for signaling thread to stop
}

// Create a new playback state (device is already open and managed by service)
create_lcd_playback :: proc(device: ^LCD_Device, frames_dir: string, fps: f32 = 20.0, loop: bool = true, transform: LCD_Transform = {}, allocator := context.allocator) -> (^LCD_Playback_State, LCD_Error) {
	state := new(LCD_Playback_State, allocator)

	// Create stop channel for signaling thread shutdown
	stop_chan, chan_err := chan.create(chan.Chan(bool), allocator)
	if chan_err != .None {
		free(state, allocator)
		return nil, .Device_Not_Found
	}
	state.stop_chan = stop_chan

	// Store reference to device (owned by service, not this playback)
	state.device = device
	state.fps = fps
	state.transform = transform
	state.running = false

	// Enumerate frame files using shared module
	frames, frames_ok := enumerate_lcd_frames(frames_dir, allocator)
	if !frames_ok {
		chan.destroy(stop_chan)
		free(state, allocator)
		return nil, .Device_Not_Found
	}
	state.frames = frames

	// Initialize sequencer
	state.sequencer = init_sequencer(len(state.frames.frame_paths), loop)

	// Check if transforms are needed - raylib will be initialized in playback thread
	state.use_raylib = transform.zoom_percent > 0 ||
	                   transform.rotate_degrees != 0 ||
	                   transform.rotation_speed != 0 ||
	                   transform.flip_horizontal

	if state.use_raylib {
		fmt.println("LCD transforms enabled (raylib will initialize in playback thread)")
	}

	fmt.printfln("LCD Playback initialized: %d frames, %.1f fps", len(state.frames.frame_paths), fps)

	return state, .None
}
// Playback thread function
lcd_playback_thread :: proc(data: rawptr) {
	state := cast(^LCD_Playback_State)data
	context = runtime.default_context()

	fmt.printfln("LCD playback thread started: %d frames at %.1f fps", len(state.frames.frame_paths), state.fps)

	// Initialize raylib processor in this thread if needed
	if state.use_raylib {
		processor, proc_ok := init_lcd_raylib_processor(LCD_WIDTH, LCD_HEIGHT)
		if !proc_ok {
			fmt.println("Warning: Failed to initialize raylib processor in playback thread, transforms will be disabled")
			state.use_raylib = false
		} else {
			state.raylib_processor = processor
			fmt.println("Raylib processor initialized in playback thread")
		}
	}
	defer if state.use_raylib do cleanup_lcd_raylib_processor(&state.raylib_processor)

	frame_delay := time.Duration(1.0 / f64(state.fps) * f64(time.Second))
	frame_count := 0
	start_time := time.now()

	for state.running {
		// Check for stop signal (non-blocking)
		_, should_stop := chan.try_recv(state.stop_chan)
		if should_stop {
			fmt.println("Stop signal received, exiting playback thread")
			break
		}

		// Get current frame and advance sequencer
		frame_idx, should_continue := advance_frame(&state.sequencer)
		if !should_continue do break // Playback ended (non-looping)

		// Load frame file using shared module
		frame_data, ok := load_animation_frame(&state.frames, frame_idx, context.allocator)
		if !ok {
			fmt.printfln("Error loading frame %d", frame_idx)
			time.sleep(frame_delay)
			continue
		}
		defer delete(frame_data, context.allocator)

		// Process image with transforms if needed
		final_frame_data := frame_data

		if state.use_raylib {
			// Use raylib for processing
			processed, proc_ok := process_lcd_frame_raylib(
				&state.raylib_processor,
				frame_data,
				state.transform,
				frame_idx,
				context.allocator,
			)
			if proc_ok {
				defer delete(processed, context.allocator)
				final_frame_data = processed
			} else {
				fmt.printfln("Error processing frame %d with raylib, using original", frame_idx)
			}
		}

		// Send frame to LCD
		send_err := send_lcd_frame(state.device, final_frame_data)
		if send_err != .None {
			fmt.printfln("Error sending frame %d: %v", frame_idx, send_err)
		} else if frame_idx < 5 {
			fmt.printfln("Successfully sent frame %d (%d bytes)", frame_idx, len(frame_data))
		}

		// Stats every second
		frame_count += 1
		if frame_count % int(state.fps) == 0 {
			elapsed := time.since(start_time)
			actual_fps := f64(frame_count) / time.duration_seconds(elapsed)
			fmt.printfln("LCD playback: frame %d/%d, actual FPS: %.1f",
				frame_idx, len(state.frames.frame_paths), actual_fps)
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
	reset_sequencer(&state.sequencer)

	state.thread = thread.create_and_start_with_data(state, lcd_playback_thread)
}

// Stop playback
stop_lcd_playback_state :: proc(state: ^LCD_Playback_State) {
	if !state.running do return

	state.running = false

	// Send stop signal via channel for immediate shutdown
	chan.send(state.stop_chan, true)

	if state.thread != nil {
		thread.join(state.thread)
		thread.destroy(state.thread)
		state.thread = nil
	}
}

// Cleanup playback state
// NOTE: Device is NOT cleaned up here - it's owned by the service
destroy_lcd_playback :: proc(state: ^LCD_Playback_State, allocator := context.allocator) {
	stop_lcd_playback_state(state)

	// Raylib processor cleanup is handled in thread defer

	// NOTE: Device is owned by service, not playback - don't cleanup here

	// Cleanup frame list using shared module
	destroy_frame_list(&state.frames, allocator)

	// Destroy stop channel
	chan.destroy(state.stop_chan)

	free(state, allocator)
}
