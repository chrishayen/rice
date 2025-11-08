package main

import "core:math"
import "core:math/rand"

// Generate static color LED data
generate_static_color :: proc(num_leds: int, r: u8, g: u8, b: u8, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3, allocator)

	for i in 0..<num_leds {
		rgb_data[i * 3] = r
		rgb_data[i * 3 + 1] = g
		rgb_data[i * 3 + 2] = b
	}

	return rgb_data
}

// Generate static color from hex string (RRGGBB)
generate_static_color_hex :: proc(num_leds: int, color_hex: string, allocator := context.allocator) -> []u8 {
	if len(color_hex) != 6 {
		return nil
	}

	r := parse_hex_byte(color_hex[0:2])
	g := parse_hex_byte(color_hex[2:4])
	b := parse_hex_byte(color_hex[4:6])

	return generate_static_color(num_leds, r, g, b, allocator)
}

// Parse 2-character hex string to byte
parse_hex_byte :: proc(hex: string) -> u8 {
	if len(hex) != 2 {
		return 0
	}

	h1 := hex_char_to_int(hex[0])
	h2 := hex_char_to_int(hex[1])
	return u8(h1 * 16 + h2)
}

hex_char_to_int :: proc(c: u8) -> int {
	switch c {
	case '0'..='9': return int(c - '0')
	case 'a'..='f': return int(c - 'a' + 10)
	case 'A'..='F': return int(c - 'A' + 10)
	case: return 0
	}
}

// HSV to RGB conversion - must match Python colorsys exactly for hardware compatibility
hsv_to_rgb :: proc{hsv_to_rgb_f32, hsv_to_rgb_f64}

hsv_to_rgb_f32 :: proc(h: f32, s: f32, v: f32) -> (r: u8, g: u8, b: u8) {
	return hsv_to_rgb_f64(f64(h), f64(s), f64(v))
}

hsv_to_rgb_f64 :: proc(h64: f64, s64: f64, v64: f64) -> (r: u8, g: u8, b: u8) {
	// Use f64 for better precision to match Python's colorsys exactly

	if s64 == 0 {
		val := u8(v64 * 255.0)
		return val, val, val
	}

	// Match Python's algorithm exactly: i = int(h*6.0); f = (h*6.0) - i
	h_times_6 := h64 * 6.0
	i := int(h_times_6)  // Truncate to int like Python
	f := h_times_6 - f64(i)
	i = i % 6

	p := v64 * (1.0 - s64)
	q := v64 * (1.0 - s64 * f)
	t := v64 * (1.0 - s64 * (1.0 - f))

	// Use truncation like Python's int() to match exactly
	to_u8 :: #force_inline proc(val: f64) -> u8 {
		result := int(val * 255.0)  // Truncate like Python's int()
		return u8(max(0, min(255, result)))
	}

	switch i {
	case 0:
		return to_u8(v64), to_u8(t), to_u8(p)
	case 1:
		return to_u8(q), to_u8(v64), to_u8(p)
	case 2:
		return to_u8(p), to_u8(v64), to_u8(t)
	case 3:
		return to_u8(p), to_u8(q), to_u8(v64)
	case 4:
		return to_u8(t), to_u8(p), to_u8(v64)
	case:
		return to_u8(v64), to_u8(p), to_u8(q)
	}
}

// Generate rainbow gradient LED data
generate_rainbow :: proc(num_leds: int, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3, allocator)
	// Use f64 throughout to match Python's float precision exactly
	brightness_factor := f64(brightness) / 100.0

	for i in 0..<num_leds {
		hue := f64(i) / f64(num_leds)
		// Use f64 overload to match Python exactly
		r, g, b := hsv_to_rgb_f64(hue, 1.0, brightness_factor)
		rgb_data[i * 3] = r
		rgb_data[i * 3 + 1] = g
		rgb_data[i * 3 + 2] = b
	}

	return rgb_data
}

// Generate alternating pattern LED data
generate_alternating :: proc(num_leds: int, color1: [3]u8, color2: [3]u8, offset: int = 0, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3, allocator)

	for i in 0..<num_leds {
		color := (i + offset) % 2 == 0 ? color1 : color2
		rgb_data[i * 3] = color[0]
		rgb_data[i * 3 + 1] = color[1]
		rgb_data[i * 3 + 2] = color[2]
	}

	return rgb_data
}

// Generate multi-frame alternating spin animation
generate_alternating_spin :: proc(num_leds: int, color1: [3]u8, color2: [3]u8, num_frames: int = 60, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for frame in 0..<num_frames {
		offset := frame * num_leds * 3
		for i in 0..<num_leds {
			color := (i + frame) % 2 == 0 ? color1 : color2
			rgb_data[offset + i * 3] = color[0]
			rgb_data[offset + i * 3 + 1] = color[1]
			rgb_data[offset + i * 3 + 2] = color[2]
		}
	}

	return rgb_data
}

// Generate rainbow morph animation (morphing rainbow colors) - must match sl_led.py exactly
generate_rainbow_morph :: proc(num_leds: int, num_frames: int = 127, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	all_frames := make([dynamic]u8, 0, num_leds * 3 * 255, context.temp_allocator)

	r, g, b: int = 255, 0, 0

	for i in 0..<255 {
		r_bright := (r * brightness_val) >> 8
		g_bright := (g * brightness_val) >> 8
		b_bright := (b * brightness_val) >> 8

		if i < 85 {
			r -= 3
			g += 3
			b = 0
		} else if i < 170 {
			r = 0
			g -= 3
			b += 3
		} else {
			r += 3
			g = 0
			b -= 3
		}

		r = clamp(r, 0, 255)
		g = clamp(g, 0, 255)
		b = clamp(b, 0, 255)

		for _ in 0..<num_leds {
			append(&all_frames, u8(r_bright))
			append(&all_frames, u8(g_bright))
			append(&all_frames, u8(b_bright))
		}
	}

	// Resample to requested number of frames - must match Python exactly
	for frame_idx in 0..<num_frames {
		src_frame := int(f64(frame_idx) * 255.0 / f64(num_frames))
		src_offset := src_frame * num_leds * 3
		dst_offset := frame_idx * num_leds * 3
		copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
	}

	return rgb_data
}

// Generate breathing effect (fade in/out through colors) - PORTED FROM sl_led.py lines 974-1019
generate_breathing :: proc(num_leds: int, num_frames: int = 680, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	// Define colors for breathing effect - EXACT from Python
	colors := [4][3]int{
		{170, 0, 255},     // Purple-magenta
		{0, 215, 255},     // Cyan
		{0, 255, 0},       // Green
		{255, 0, 128},     // Pink-red
	}

	all_frames := make([dynamic]u8, 0, num_leds * 3 * num_frames, allocator)
	defer delete(all_frames)

	for color_idx in 0..<4 {
		r_base := colors[color_idx][0]
		g_base := colors[color_idx][1]
		b_base := colors[color_idx][2]

		// Two directions: fade in (0), fade out (1)
		for direction in 0..<2 {
			for step in 0..<85 {
				// Calculate brightness step using same logic as Python
				brightness_step := (step * 3) & 0xFF
				if direction == 1 {
					brightness_step = 255 - brightness_step
				}

				// Apply brightness step using >> 8
				r := (r_base * brightness_step) >> 8
				g := (g_base * brightness_step) >> 8
				b := (b_base * brightness_step) >> 8

				// Apply overall brightness using >> 8
				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				// Same color for all LEDs in this frame
				for _ in 0..<num_leds {
					append(&all_frames, u8(r_final))
					append(&all_frames, u8(g_final))
					append(&all_frames, u8(b_final))
				}
			}
		}
	}

	// Total frames generated: 4 colors * 2 directions * 85 steps = 680
	rgb_data := make([]u8, len(all_frames), allocator)
	copy(rgb_data, all_frames[:])
	return rgb_data
}

// Generate runway lights animation - PORTED FROM sl_led.py lines 1021-1074
generate_runway :: proc(num_leds: int, num_frames: int = 180, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	colors := [2][3]int{
		{255, 0, 0},  // Red
		{0, 0, 255},  // Blue
	}

	light_width := max(1, num_leds / 8)

	all_frames := make([dynamic]u8, 0, num_leds * 3 * (num_leds + light_width) * 2, allocator)
	defer delete(all_frames)

	// Two directions: forward (0), reverse (1)
	for direction in 0..<2 {
		for pos in 0..<(num_leds + light_width) {
			for led_idx in 0..<num_leds {
				// Reverse LED index for backward direction
				actual_idx := led_idx if direction == 0 else (num_leds - led_idx - 1)

				// Determine which color to use (background or lit)
				color_idx := 0
				if actual_idx <= pos && actual_idx + light_width > pos {
					color_idx = 1
				}

				r := colors[color_idx][0]
				g := colors[color_idx][1]
				b := colors[color_idx][2]

				// Apply brightness using >> 8
				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				append(&all_frames, u8(r_final))
				append(&all_frames, u8(g_final))
				append(&all_frames, u8(b_final))
			}
		}
	}

	// Resample if needed
	total_generated := (num_leds + light_width) * 2
	if total_generated != num_frames {
		step := f64(total_generated) / f64(num_frames)
		rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

		for i in 0..<num_frames {
			src_frame := int(f64(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}

		return rgb_data
	}

	// No resampling needed
	rgb_data := make([]u8, len(all_frames), allocator)
	copy(rgb_data, all_frames[:])
	return rgb_data
}

// Generate meteor trail animation - PORTED FROM sl_led.py lines 1076-1138
generate_meteor :: proc(num_leds: int, num_frames: int = 360, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	// Define meteor colors - EXACT from Python
	colors := [4][3]int{
		{0, 217, 255},  // Cyan (NOTE: 217, not 255!)
		{0, 0, 255},    // Blue
		{255, 0, 0},    // Red
		{0, 255, 0},    // Green
	}

	// Discrete trail brightness values - EXACT from Python
	trail_brightness := [12]int{6, 8, 16, 24, 32, 48, 64, 96, 120, 150, 200, 255}
	trail_length := len(trail_brightness)

	// Generate all frames for all colors
	all_frames := make([dynamic]u8, 0, num_leds * 3 * (num_leds + trail_length) * 4, allocator)
	defer delete(all_frames)

	for color_idx in 0..<4 {
		r_base := colors[color_idx][0]
		g_base := colors[color_idx][1]
		b_base := colors[color_idx][2]

		for pos in 0..<(num_leds + trail_length) {
			for led_idx in 0..<num_leds {
				r, g, b := 0, 0, 0

				// Check if LED is in trail
				if led_idx <= pos && led_idx + trail_length > pos {
					trail_pos := pos - led_idx
					if trail_pos < trail_length {
						trail_bright := trail_brightness[trail_pos]
						// Use >> 8 bit shift like Python
						r = (r_base * trail_bright) >> 8
						g = (g_base * trail_bright) >> 8
						b = (b_base * trail_bright) >> 8
					}
				}

				// Apply overall brightness using >> 8
				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				append(&all_frames, u8(r_final))
				append(&all_frames, u8(g_final))
				append(&all_frames, u8(b_final))
			}
		}
	}

	// Resample if needed (same logic as Python)
	total_generated := (num_leds + trail_length) * 4
	if total_generated != num_frames {
		step := f64(total_generated) / f64(num_frames)
		rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

		for i in 0..<num_frames {
			src_frame := int(f64(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}

		return rgb_data
	}

	// No resampling needed
	rgb_data := make([]u8, len(all_frames), allocator)
	copy(rgb_data, all_frames[:])
	return rgb_data
}

// Generate color cycle animation - must match Python exactly
// Generate color cycle animation - PORTED FROM sl_led.py lines 1140-1199
generate_color_cycle :: proc(num_leds: int, num_frames: int = 40, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	// Define colors - EXACT from Python
	colors := [3][3]int{
		{0, 0, 255},      // Blue
		{255, 0, 0},      // Red
		{255, 255, 0},    // Yellow
	}

	// Pattern array - EXACT from Python (0 = off, 1/2/3 = color indices)
	pattern := [40]int{
		1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 2, 2, 2, 2, 2, 0,
		0, 0, 0, 0, 0, 0, 0, 3, 3, 3,
		3, 3, 0, 0, 0, 0, 0, 0, 0, 0,
	}

	all_frames := make([dynamic]u8, 0, num_leds * 3 * 40, allocator)
	defer delete(all_frames)

	// Generate 40 frames (full rotation)
	for rotation in 0..<40 {
		for led_idx in 0..<num_leds {
			pattern_idx := (led_idx + rotation) % 40
			color_num := pattern[pattern_idx]

			r, g, b := 0, 0, 0
			if color_num != 0 {
				r = colors[color_num - 1][0]
				g = colors[color_num - 1][1]
				b = colors[color_num - 1][2]
			}

			// Apply brightness using >> 8
			r_final := (r * brightness_val) >> 8
			g_final := (g * brightness_val) >> 8
			b_final := (b * brightness_val) >> 8

			append(&all_frames, u8(r_final))
			append(&all_frames, u8(g_final))
			append(&all_frames, u8(b_final))
		}
	}

	// Resample if needed
	if len(all_frames) == num_frames * num_leds * 3 {
		rgb_data := make([]u8, len(all_frames), allocator)
		copy(rgb_data, all_frames[:])
		return rgb_data
	}

	step := 40.0 / f64(num_frames)
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for i in 0..<num_frames {
		src_frame := int(f64(i) * step)
		src_offset := src_frame * num_leds * 3
		dst_offset := i * num_leds * 3
		copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
	}

	return rgb_data
}

// Generate cover cycle animation - must match Python exactly
generate_cover_cycle :: proc(num_leds: int, num_frames: int = 160, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	for frame in 0..<num_frames {
		// Determine fill progress
		fill_progress: f64
		filling_color: [3]f64
		background_color: [3]f64

		if frame < 80 {
			// Red filling from start
			fill_progress = f64(frame) / 80.0
			filling_color = {255, 0, 0}  // Red
			background_color = {0, 0, 0}
		} else {
			// Blue filling from start
			fill_progress = f64(frame - 80) / 80.0
			filling_color = {0, 0, 255}  // Blue
			background_color = {255, 0, 0}  // Red background
		}

		fill_limit := int(f64(num_leds) * fill_progress)

		offset := frame * num_leds * 3
		for i in 0..<num_leds {
			r, g, b: u8
			if i < fill_limit {
				r = u8(filling_color[0] * max_brightness)
				g = u8(filling_color[1] * max_brightness)
				b = u8(filling_color[2] * max_brightness)
			} else {
				r = u8(background_color[0] * max_brightness)
				g = u8(background_color[1] * max_brightness)
				b = u8(background_color[2] * max_brightness)
			}

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}

// Generate wave animation - must match Python exactly
// Generate wave animation - PORTED FROM sl_led.py lines 1254-1307
generate_wave :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	color := [3]int{255, 0, 0}  // Red

	// Wave brightness pattern - EXACT from Python
	wave_pattern := [16]int{0, 8, 16, 32, 64, 128, 168, 255, 168, 128, 64, 32, 16, 8, 0, 0}
	wave_len := len(wave_pattern)

	all_frames := make([dynamic]u8, 0, num_leds * 3 * wave_len * 5, allocator)
	defer delete(all_frames)

	// Generate 5 full cycles (wave_len * 5 = 16 * 5 = 80 frames)
	for _ in 0..<5 {
		for rotation in 0..<wave_len {
			for led_idx in 0..<num_leds {
				pattern_idx := (led_idx + rotation) % wave_len
				wave_bright := wave_pattern[pattern_idx]

				// Apply wave brightness using >> 8
				r := (color[0] * wave_bright) >> 8
				g := (color[1] * wave_bright) >> 8
				b := (color[2] * wave_bright) >> 8

				// Apply overall brightness using >> 8
				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				append(&all_frames, u8(r_final))
				append(&all_frames, u8(g_final))
				append(&all_frames, u8(b_final))
			}
		}
	}

	// Resample if needed
	total_generated := wave_len * 5
	if total_generated == num_frames {
		rgb_data := make([]u8, len(all_frames), allocator)
		copy(rgb_data, all_frames[:])
		return rgb_data
	}

	step := f64(total_generated) / f64(num_frames)
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for i in 0..<num_frames {
		src_frame := int(f64(i) * step)
		src_offset := src_frame * num_leds * 3
		dst_offset := i * num_leds * 3
		copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
	}

	return rgb_data
}

// Generate meteor shower animation (multiple meteors) - PORTED FROM sl_led.py lines 1309-1390
generate_meteor_shower :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	// Define colors - EXACT from Python
	colors := [4][3]int{
		{0, 217, 255},  // Cyan (NOTE: 217, not 255!)
		{0, 0, 255},    // Blue
		{255, 0, 0},    // Red
		{0, 255, 0},    // Green
	}

	// Meteor brightness pattern - EXACT from Python
	meteor_pattern := [80]int{
		255, 192, 168, 128, 64, 32, 24, 16, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		255, 192, 168, 128, 64, 32, 24, 16, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		255, 192, 168, 128, 64, 32, 24, 16, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		255, 192, 168, 128, 64, 32, 24, 16, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}

	// Color pattern - EXACT from Python (0 = off, 1-4 = color indices)
	color_pattern := [80]int{
		1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		2, 2, 2, 2, 2, 2, 2, 2, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		3, 3, 3, 3, 3, 3, 3, 3, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		4, 4, 4, 4, 4, 4, 4, 4, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}

	pattern_len := len(meteor_pattern)
	all_frames := make([dynamic]u8, 0, num_leds * 3 * pattern_len, allocator)
	defer delete(all_frames)

	// Generate frames based on rotating pattern
	for rotation in 0..<pattern_len {
		for led_idx in 0..<num_leds {
			pattern_idx := (led_idx + rotation) % pattern_len
			color_num := color_pattern[pattern_idx]

			r, g, b := 0, 0, 0
			if color_num != 0 {
				meteor_bright := meteor_pattern[pattern_idx]
				r_base := colors[color_num - 1][0]
				g_base := colors[color_num - 1][1]
				b_base := colors[color_num - 1][2]

				// Apply meteor brightness using >> 8
				r = (r_base * meteor_bright) >> 8
				g = (g_base * meteor_bright) >> 8
				b = (b_base * meteor_bright) >> 8
			}

			// Apply overall brightness using >> 8
			r_final := (r * brightness_val) >> 8
			g_final := (g * brightness_val) >> 8
			b_final := (b * brightness_val) >> 8

			append(&all_frames, u8(r_final))
			append(&all_frames, u8(g_final))
			append(&all_frames, u8(b_final))
		}
	}

	// Resample if needed
	if pattern_len == num_frames {
		rgb_data := make([]u8, len(all_frames), allocator)
		copy(rgb_data, all_frames[:])
		return rgb_data
	}

	step := f64(pattern_len) / f64(num_frames)
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for i in 0..<num_frames {
		src_frame := int(f64(i) * step)
		src_offset := src_frame * num_leds * 3
		dst_offset := i * num_leds * 3
		copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
	}

	return rgb_data
}

// Generate twinkle animation (twinkling stars) - Simplified deterministic random
// NOTE: Does not exactly match Python's MT19937, but produces similar visual effect
generate_twinkle :: proc(num_leds: int, num_frames: int = 200, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := int(f64(brightness) * 2.55)

	colors := [4][3]int{
		{255, 0, 0},      // Red
		{0, 0, 255},      // Blue
		{0, 255, 0},      // Green
		{255, 255, 0},    // Yellow
	}

	intensities := [7]int{80, 105, 130, 160, 190, 220, 255}

	all_frames := make([dynamic]u8, 0, num_leds * 3 * num_frames, allocator)
	defer delete(all_frames)

	// Simple hash-based deterministic random (good enough for visual effect)
	hash :: proc(seed: int) -> int {
		x := seed
		x = ((x >> 16) ~ x) * 0x45d9f3b
		x = ((x >> 16) ~ x) * 0x45d9f3b
		x = (x >> 16) ~ x
		return x
	}

	for frame_idx in 0..<num_frames {
		for led_idx in 0..<num_leds {
			seed_val := (frame_idx * 174 + led_idx * 7) % 1000

			r, g, b := 0, 0, 0

			// 15% chance of lighting
			h1 := hash(seed_val * 13)
			if (h1 & 0xFFFF) < 9830 {  // ~15% of 0xFFFF
				h2 := hash(seed_val * 17)
				h3 := hash(seed_val * 19)

				color_idx := (h2 & 0x7FFFFFFF) % 4
				intensity := intensities[(h3 & 0x7FFFFFFF) % 7]

				r_base := colors[color_idx][0]
				g_base := colors[color_idx][1]
				b_base := colors[color_idx][2]

				r = (r_base * intensity) >> 8
				g = (g_base * intensity) >> 8
				b = (b_base * intensity) >> 8
			}

			r_final := (r * brightness_val) >> 8
			g_final := (g * brightness_val) >> 8
			b_final := (b * brightness_val) >> 8

			append(&all_frames, u8(r_final))
			append(&all_frames, u8(g_final))
			append(&all_frames, u8(b_final))
		}
	}

	rgb_data := make([]u8, len(all_frames), allocator)
	copy(rgb_data, all_frames[:])
	return rgb_data
}
