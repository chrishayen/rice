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

// Generate breathing effect (fade in/out through colors) - must match Python exactly
generate_breathing :: proc(num_leds: int, num_frames: int = 680, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	// Define colors for breathing effect - MUST match Python exactly
	colors := [4][3]f64{
		{255, 0, 255},    // Magenta
		{0, 255, 255},    // Cyan
		{0, 255, 0},      // Green
		{255, 192, 203},  // Pink
	}

	for frame in 0..<num_frames {
		// Calculate breathing intensity - MUST match Python exactly
		cycle_pos := f64(frame % 170) / 170.0
		intensity: f64
		if cycle_pos <= 0.5 {
			intensity = cycle_pos * 2
		} else {
			intensity = 2 - (cycle_pos * 2)
		}

		// Select color based on which quarter of animation we're in
		color_index := (frame / 170) % len(colors)
		color := colors[color_index]

		offset := frame * num_leds * 3
		for _ in 0..<num_leds {
			r := u8(color[0] * intensity * max_brightness)
			g := u8(color[1] * intensity * max_brightness)
			b := u8(color[2] * intensity * max_brightness)
			rgb_data[offset] = r
			rgb_data[offset + 1] = g
			rgb_data[offset + 2] = b
			offset += 3
		}
	}

	return rgb_data
}

// Generate runway lights animation - must match Python exactly
generate_runway :: proc(num_leds: int, num_frames: int = 180, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	for frame in 0..<num_frames {
		// Determine direction (ping-pong)
		position: f64
		if frame < 90 {
			position = f64(frame) / 90.0 * f64(num_leds)
		} else {
			position = (2.0 - f64(frame) / 90.0) * f64(num_leds)
		}

		offset := frame * num_leds * 3
		for i in 0..<num_leds {
			distance := math.abs(f64(i) - position)
			r, g, b: u8 = 0, 0, 0

			if distance < 3 {
				intensity := 1.0 - (distance / 3.0)
				if frame < 90 {
					// Red direction
					r = u8(255 * intensity * max_brightness)
					g = 0
					b = 0
				} else {
					// Blue direction
					r = 0
					g = 0
					b = u8(255 * intensity * max_brightness)
				}
			}

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}

// Generate meteor trail animation - must match Python exactly
generate_meteor :: proc(num_leds: int, num_frames: int = 360, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	// Define meteor colors
	colors := [4][3]f64{
		{0, 255, 255},  // Cyan
		{0, 0, 255},    // Blue
		{255, 0, 0},    // Red
		{0, 255, 0},    // Green
	}

	for frame in 0..<num_frames {
		// Select color based on which quarter of animation
		color_index := (frame / 90) % len(colors)
		color := colors[color_index]

		// Calculate meteor position
		position := f64(frame % 90) / 90.0 * f64(num_leds + 10) - 5

		offset := frame * num_leds * 3
		for i in 0..<num_leds {
			distance := position - f64(i)
			r, g, b: u8 = 0, 0, 0

			if distance > 0 && distance <= 10 {
				// Trail effect
				intensity := 1.0 - (distance / 10.0)
				r = u8(color[0] * intensity * max_brightness)
				g = u8(color[1] * intensity * max_brightness)
				b = u8(color[2] * intensity * max_brightness)
			} else if distance <= 0 && distance > -2 {
				// Head of meteor (brighter)
				r = u8(color[0] * max_brightness)
				g = u8(color[1] * max_brightness)
				b = u8(color[2] * max_brightness)
			}

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}

// Generate color cycle animation - must match Python exactly
generate_color_cycle :: proc(num_leds: int, num_frames: int = 40, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	// Define colors to cycle through
	colors := [3][3]f64{
		{0, 0, 255},    // Blue
		{255, 0, 0},    // Red
		{255, 255, 0},  // Yellow
	}

	for frame in 0..<num_frames {
		// Determine which color transition
		transition_length := num_frames / len(colors)
		color_index := frame / transition_length
		transition_progress := f64(frame % transition_length) / f64(transition_length)

		current_color: [3]f64
		next_color: [3]f64

		if color_index >= len(colors) - 1 {
			// Last color to first color
			current_color = colors[len(colors) - 1]
			next_color = colors[0]
		} else {
			current_color = colors[color_index]
			next_color = colors[color_index + 1]
		}

		// Interpolate between colors
		r := u8((current_color[0] * (1 - transition_progress) + next_color[0] * transition_progress) * max_brightness)
		g := u8((current_color[1] * (1 - transition_progress) + next_color[1] * transition_progress) * max_brightness)
		b := u8((current_color[2] * (1 - transition_progress) + next_color[2] * transition_progress) * max_brightness)

		offset := frame * num_leds * 3
		for _ in 0..<num_leds {
			rgb_data[offset] = r
			rgb_data[offset + 1] = g
			rgb_data[offset + 2] = b
			offset += 3
		}
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
generate_wave :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	PI :: math.PI

	for frame in 0..<num_frames {
		// Calculate wave phase
		phase := (f64(frame) / f64(num_frames)) * 2 * PI

		offset := frame * num_leds * 3
		for i in 0..<num_leds {
			// Calculate wave intensity at this position
			wave_position := (f64(i) / f64(num_leds)) * 2 * PI
			intensity := (math.sin(wave_position + phase) + 1) / 2

			// Red wave
			r := u8(255 * intensity * max_brightness)
			g := u8(0)
			b := u8(0)

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}

// Generate meteor shower animation (multiple meteors) - must match Python exactly
Meteor :: struct {
	position: f64,
	speed: f64,
	color: [3]f64,
}

generate_meteor_shower :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	// Define multiple meteors with different positions and speeds
	meteors := [4]Meteor{
		{position = 0, speed = 1.0, color = {255, 0, 0}},      // Red
		{position = 15, speed = 0.8, color = {0, 0, 255}},     // Blue
		{position = 30, speed = 1.2, color = {0, 255, 0}},     // Green
		{position = 45, speed = 0.9, color = {255, 255, 0}},   // Yellow
	}

	for frame in 0..<num_frames {
		offset := frame * num_leds * 3

		for i in 0..<num_leds {
			r, g, b: u8 = 0, 0, 0

			// Check each meteor
			for meteor in meteors {
				meteor_pos := math.mod(meteor.position + f64(frame) * meteor.speed, f64(num_leds + 20)) - 10
				distance := meteor_pos - f64(i)

				if distance > 0 && distance <= 8 {
					// Trail
					intensity := 1.0 - (distance / 8.0)
					r = max(r, u8(meteor.color[0] * intensity * max_brightness))
					g = max(g, u8(meteor.color[1] * intensity * max_brightness))
					b = max(b, u8(meteor.color[2] * intensity * max_brightness))
				} else if distance <= 0 && distance > -2 {
					// Head
					r = max(r, u8(meteor.color[0] * max_brightness))
					g = max(g, u8(meteor.color[1] * max_brightness))
					b = max(b, u8(meteor.color[2] * max_brightness))
				}
			}

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}

// Generate twinkle animation (twinkling stars) - must match Python exactly
Twinkle :: struct {
	led: int,
	start_frame: int,
	duration: int,
	color: [3]f64,
}

generate_twinkle :: proc(num_leds: int, num_frames: int = 200, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	max_brightness := f64(brightness) / 100.0

	colors := [4][3]f64{
		{255, 0, 0},    // Red
		{0, 0, 255},    // Blue
		{0, 255, 0},    // Green
		{255, 255, 0},  // Yellow
	}

	// Hardcoded twinkle pattern matching Python random.seed(42)
	// This ensures exact byte-for-byte hardware compatibility
	twinkles := [30]Twinkle{
		{led = 7, start_frame = 6, duration = 14, color = colors[1]},
		{led = 14, start_frame = 35, duration = 11, color = colors[0]},
		{led = 37, start_frame = 108, duration = 10, color = colors[0]},
		{led = 5, start_frame = 55, duration = 13, color = colors[0]},
		{led = 35, start_frame = 50, duration = 20, color = colors[3]},
		{led = 14, start_frame = 114, duration = 19, color = colors[2]},
		{led = 0, start_frame = 40, duration = 16, color = colors[2]},
		{led = 17, start_frame = 39, duration = 13, color = colors[2]},
		{led = 6, start_frame = 23, duration = 16, color = colors[0]},
		{led = 22, start_frame = 88, duration = 19, color = colors[2]},
		{led = 2, start_frame = 117, duration = 18, color = colors[0]},
		{led = 24, start_frame = 20, duration = 18, color = colors[2]},
		{led = 39, start_frame = 92, duration = 19, color = colors[1]},
		{led = 4, start_frame = 11, duration = 20, color = colors[1]},
		{led = 18, start_frame = 20, duration = 13, color = colors[0]},
		{led = 24, start_frame = 71, duration = 17, color = colors[2]},
		{led = 10, start_frame = 94, duration = 15, color = colors[1]},
		{led = 17, start_frame = 179, duration = 20, color = colors[0]},
		{led = 38, start_frame = 162, duration = 12, color = colors[1]},
		{led = 10, start_frame = 118, duration = 16, color = colors[2]},
		{led = 35, start_frame = 56, duration = 20, color = colors[2]},
		{led = 3, start_frame = 58, duration = 10, color = colors[2]},
		{led = 25, start_frame = 68, duration = 11, color = colors[1]},
		{led = 36, start_frame = 80, duration = 13, color = colors[3]},
		{led = 25, start_frame = 164, duration = 17, color = colors[1]},
		{led = 16, start_frame = 35, duration = 13, color = colors[2]},
		{led = 37, start_frame = 109, duration = 19, color = colors[3]},
		{led = 23, start_frame = 56, duration = 12, color = colors[3]},
		{led = 5, start_frame = 12, duration = 11, color = colors[1]},
		{led = 10, start_frame = 174, duration = 16, color = colors[0]},
	}

	for frame in 0..<num_frames {
		offset := frame * num_leds * 3

		for i in 0..<num_leds {
			r, g, b: u8 = 0, 0, 0

			// Check if this LED should twinkle in this frame
			for twinkle in twinkles {
				if twinkle.led == i {
					if frame >= twinkle.start_frame && frame < twinkle.start_frame + twinkle.duration {
						// Calculate twinkle intensity
						progress := f64(frame - twinkle.start_frame) / f64(twinkle.duration)
						intensity: f64
						if progress < 0.5 {
							intensity = progress * 2
						} else {
							intensity = 2 - (progress * 2)
						}

						r = max(r, u8(twinkle.color[0] * intensity * max_brightness))
						g = max(g, u8(twinkle.color[1] * intensity * max_brightness))
						b = max(b, u8(twinkle.color[2] * intensity * max_brightness))
					}
				}
			}

			rgb_data[offset + i * 3] = r
			rgb_data[offset + i * 3 + 1] = g
			rgb_data[offset + i * 3 + 2] = b
		}
	}

	return rgb_data
}
