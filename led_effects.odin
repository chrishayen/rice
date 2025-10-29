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

// HSV to RGB conversion
hsv_to_rgb :: proc(h: f32, s: f32, v: f32) -> (r: u8, g: u8, b: u8) {
	if s == 0 {
		val := u8(v * 255)
		return val, val, val
	}

	h_sector := h * 6.0
	sector := int(math.floor(h_sector))
	frac := h_sector - f32(sector)

	p := v * (1.0 - s)
	q := v * (1.0 - s * frac)
	t := v * (1.0 - s * (1.0 - frac))

	switch sector {
	case 0:
		return u8(v * 255), u8(t * 255), u8(p * 255)
	case 1:
		return u8(q * 255), u8(v * 255), u8(p * 255)
	case 2:
		return u8(p * 255), u8(v * 255), u8(t * 255)
	case 3:
		return u8(p * 255), u8(q * 255), u8(v * 255)
	case 4:
		return u8(t * 255), u8(p * 255), u8(v * 255)
	case:
		return u8(v * 255), u8(p * 255), u8(q * 255)
	}
}

// Generate rainbow gradient LED data
generate_rainbow :: proc(num_leds: int, brightness: int = 100, allocator := context.allocator) -> []u8 {
	rgb_data := make([]u8, num_leds * 3, allocator)
	brightness_factor := f32(brightness) / 100.0

	for i in 0..<num_leds {
		hue := f32(i) / f32(num_leds)
		r, g, b := hsv_to_rgb(hue, 1.0, brightness_factor)
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

// Generate rainbow morph animation (morphing rainbow colors)
generate_rainbow_morph :: proc(num_leds: int, num_frames: int = 127, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100
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

	// Resample to num_frames
	for k in 0..<num_frames {
		frame_idx := k * 2
		offset := k * num_leds * 3
		for _ in 0..<num_leds {
			rgb_data[offset] = all_frames[frame_idx * num_leds * 3]
			rgb_data[offset + 1] = all_frames[frame_idx * num_leds * 3 + 1]
			rgb_data[offset + 2] = all_frames[frame_idx * num_leds * 3 + 2]
			offset += 3
		}
	}

	return rgb_data
}

// Generate breathing effect (fade in/out through colors)
generate_breathing :: proc(num_leds: int, num_frames: int = 680, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	colors := [4][3]int{
		{170, 0, 255},
		{0, 215, 255},
		{0, 255, 0},
		{255, 0, 128},
	}

	frame_idx := 0

	for color_idx in 0..<4 {
		r_base := colors[color_idx][0]
		g_base := colors[color_idx][1]
		b_base := colors[color_idx][2]

		for direction in 0..<2 {
			for step in 0..<85 {
				brightness_step := (step * 3) & 0xFF
				if direction == 1 {
					brightness_step = 255 - brightness_step
				}

				r := (r_base * brightness_step) >> 8
				g := (g_base * brightness_step) >> 8
				b := (b_base * brightness_step) >> 8

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				offset := frame_idx * num_leds * 3
				for _ in 0..<num_leds {
					rgb_data[offset] = u8(r_final)
					rgb_data[offset + 1] = u8(g_final)
					rgb_data[offset + 2] = u8(b_final)
					offset += 3
				}

				frame_idx += 1
			}
		}
	}

	return rgb_data
}

// Generate runway lights animation
generate_runway :: proc(num_leds: int, num_frames: int = 180, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [2][3]int{
		{255, 0, 0},
		{0, 0, 255},
	}

	light_width := max(1, num_leds / 8)
	total_generated := (num_leds + light_width) * 2

	all_frames := make([]u8, total_generated * num_leds * 3, context.temp_allocator)

	frame_idx := 0

	for direction in 0..<2 {
		for pos in 0..<(num_leds + light_width) {
			offset := frame_idx * num_leds * 3
			for led_idx in 0..<num_leds {
				actual_idx := direction == 0 ? led_idx : (num_leds - led_idx - 1)

				color_idx := 0
				if actual_idx <= pos && actual_idx + light_width > pos {
					color_idx = 1
				}

				r := colors[color_idx][0]
				g := colors[color_idx][1]
				b := colors[color_idx][2]

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				all_frames[offset + led_idx * 3] = u8(r_final)
				all_frames[offset + led_idx * 3 + 1] = u8(g_final)
				all_frames[offset + led_idx * 3 + 2] = u8(b_final)
			}
			frame_idx += 1
		}
	}

	// Resample if needed
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	if total_generated != num_frames {
		step := f32(total_generated) / f32(num_frames)
		for i in 0..<num_frames {
			src_frame := int(f32(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}
	} else {
		copy(rgb_data, all_frames)
	}

	return rgb_data
}

// Generate meteor trail animation
generate_meteor :: proc(num_leds: int, num_frames: int = 360, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [4][3]int{
		{0, 217, 255},
		{0, 0, 255},
		{255, 0, 0},
		{0, 255, 0},
	}

	trail_brightness := [12]int{6, 8, 16, 24, 32, 48, 64, 96, 120, 150, 200, 255}
	trail_length := len(trail_brightness)

	total_generated := (num_leds + trail_length) * 4
	all_frames := make([]u8, total_generated * num_leds * 3, context.temp_allocator)

	frame_idx := 0

	for color_idx in 0..<4 {
		r_base := colors[color_idx][0]
		g_base := colors[color_idx][1]
		b_base := colors[color_idx][2]

		for pos in 0..<(num_leds + trail_length) {
			offset := frame_idx * num_leds * 3
			for led_idx in 0..<num_leds {
				r, g, b := 0, 0, 0

				if led_idx <= pos && led_idx + trail_length > pos {
					trail_pos := pos - led_idx
					if trail_pos < trail_length {
						trail_bright := trail_brightness[trail_pos]
						r = (r_base * trail_bright) >> 8
						g = (g_base * trail_bright) >> 8
						b = (b_base * trail_bright) >> 8
					}
				}

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				all_frames[offset + led_idx * 3] = u8(r_final)
				all_frames[offset + led_idx * 3 + 1] = u8(g_final)
				all_frames[offset + led_idx * 3 + 2] = u8(b_final)
			}
			frame_idx += 1
		}
	}

	// Resample if needed
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	if total_generated != num_frames {
		step := f32(total_generated) / f32(num_frames)
		for i in 0..<num_frames {
			src_frame := int(f32(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}
	} else {
		copy(rgb_data, all_frames)
	}

	return rgb_data
}

// Generate color cycle animation
generate_color_cycle :: proc(num_leds: int, num_frames: int = 40, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [3][3]int{
		{0, 0, 255},
		{255, 0, 0},
		{255, 255, 0},
	}

	pattern := [40]int{
		1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 2, 2, 2, 2, 2, 0,
		0, 0, 0, 0, 0, 0, 0, 3, 3, 3,
		3, 3, 0, 0, 0, 0, 0, 0, 0, 0,
	}

	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for rotation in 0..<num_frames {
		offset := rotation * num_leds * 3
		for led_idx in 0..<num_leds {
			pattern_idx := (led_idx + rotation) % 40
			color_num := pattern[pattern_idx]

			r, g, b := 0, 0, 0
			if color_num > 0 {
				r = colors[color_num - 1][0]
				g = colors[color_num - 1][1]
				b = colors[color_num - 1][2]
			}

			r_final := (r * brightness_val) >> 8
			g_final := (g * brightness_val) >> 8
			b_final := (b * brightness_val) >> 8

			rgb_data[offset + led_idx * 3] = u8(r_final)
			rgb_data[offset + led_idx * 3 + 1] = u8(g_final)
			rgb_data[offset + led_idx * 3 + 2] = u8(b_final)
		}
	}

	return rgb_data
}

// Generate cover cycle animation
generate_cover_cycle :: proc(num_leds: int, num_frames: int = 160, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [2][3]int{
		{255, 0, 0},
		{0, 0, 255},
	}

	total_generated := num_leds * 2
	all_frames := make([]u8, total_generated * num_leds * 3, context.temp_allocator)

	frame_idx := 0

	for color_start in 0..<2 {
		for pos in 0..<num_leds {
			offset := frame_idx * num_leds * 3
			for led_idx in 0..<num_leds {
				color_idx := color_start
				if led_idx <= pos {
					color_idx = 1 - color_idx
				}

				r := colors[color_idx][0]
				g := colors[color_idx][1]
				b := colors[color_idx][2]

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				all_frames[offset + led_idx * 3] = u8(r_final)
				all_frames[offset + led_idx * 3 + 1] = u8(g_final)
				all_frames[offset + led_idx * 3 + 2] = u8(b_final)
			}
			frame_idx += 1
		}
	}

	// Resample if needed
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	if total_generated != num_frames {
		step := f32(total_generated) / f32(num_frames)
		for i in 0..<num_frames {
			src_frame := int(f32(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}
	} else {
		copy(rgb_data, all_frames)
	}

	return rgb_data
}

// Generate wave animation
generate_wave :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	color := [3]int{255, 0, 0}

	wave_pattern := [16]int{0, 8, 16, 32, 64, 128, 168, 255, 168, 128, 64, 32, 16, 8, 0, 0}
	wave_len := len(wave_pattern)

	total_generated := wave_len * 5
	all_frames := make([]u8, total_generated * num_leds * 3, context.temp_allocator)

	frame_idx := 0

	for _ in 0..<5 {
		for rotation in 0..<wave_len {
			offset := frame_idx * num_leds * 3
			for led_idx in 0..<num_leds {
				pattern_idx := (led_idx + rotation) % wave_len
				wave_bright := wave_pattern[pattern_idx]

				r := (color[0] * wave_bright) >> 8
				g := (color[1] * wave_bright) >> 8
				b := (color[2] * wave_bright) >> 8

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				all_frames[offset + led_idx * 3] = u8(r_final)
				all_frames[offset + led_idx * 3 + 1] = u8(g_final)
				all_frames[offset + led_idx * 3 + 2] = u8(b_final)
			}
			frame_idx += 1
		}
	}

	// Resample if needed
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)
	if total_generated != num_frames {
		step := f32(total_generated) / f32(num_frames)
		for i in 0..<num_frames {
			src_frame := int(f32(i) * step)
			src_offset := src_frame * num_leds * 3
			dst_offset := i * num_leds * 3
			copy(rgb_data[dst_offset:dst_offset + num_leds * 3], all_frames[src_offset:src_offset + num_leds * 3])
		}
	} else {
		copy(rgb_data, all_frames)
	}

	return rgb_data
}

// Generate meteor shower animation (multiple meteors)
generate_meteor_shower :: proc(num_leds: int, num_frames: int = 80, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [4][3]int{
		{0, 217, 255},
		{0, 0, 255},
		{255, 0, 0},
		{0, 255, 0},
	}

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
	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	for rotation in 0..<num_frames {
		offset := rotation * num_leds * 3
		for led_idx in 0..<num_leds {
			pattern_idx := (led_idx + rotation) % pattern_len
			color_num := color_pattern[pattern_idx]

			r, g, b := 0, 0, 0
			if color_num > 0 {
				meteor_bright := meteor_pattern[pattern_idx]
				r_base := colors[color_num - 1][0]
				g_base := colors[color_num - 1][1]
				b_base := colors[color_num - 1][2]
				r = (r_base * meteor_bright) >> 8
				g = (g_base * meteor_bright) >> 8
				b = (b_base * meteor_bright) >> 8
			}

			r_final := (r * brightness_val) >> 8
			g_final := (g * brightness_val) >> 8
			b_final := (b * brightness_val) >> 8

			rgb_data[offset + led_idx * 3] = u8(r_final)
			rgb_data[offset + led_idx * 3 + 1] = u8(g_final)
			rgb_data[offset + led_idx * 3 + 2] = u8(b_final)
		}
	}

	return rgb_data
}

// Generate twinkle animation (twinkling stars)
generate_twinkle :: proc(num_leds: int, num_frames: int = 200, brightness: int = 100, allocator := context.allocator) -> []u8 {
	brightness_val := brightness * 255 / 100

	colors := [4][3]int{
		{255, 0, 0},
		{0, 0, 255},
		{0, 255, 0},
		{255, 255, 0},
	}

	intensities := [7]int{80, 105, 130, 160, 190, 220, 255}

	rgb_data := make([]u8, num_leds * 3 * num_frames, allocator)

	// Use deterministic pseudo-random generation
	for frame_idx in 0..<num_frames {
		offset := frame_idx * num_leds * 3
		for led_idx in 0..<num_leds {
			seed_val := (frame_idx * 174 + led_idx * 7) % 1000

			// Simple pseudo-random based on seed
			rand_val := (seed_val * 1103515245 + 12345) % 1000

			if rand_val < 150 {  // 15% chance
				color_idx := (rand_val * 7) % 4
				intensity_idx := (rand_val * 13) % 7
				intensity := intensities[intensity_idx]

				r_base := colors[color_idx][0]
				g_base := colors[color_idx][1]
				b_base := colors[color_idx][2]

				r := (r_base * intensity) >> 8
				g := (g_base * intensity) >> 8
				b := (b_base * intensity) >> 8

				r_final := (r * brightness_val) >> 8
				g_final := (g * brightness_val) >> 8
				b_final := (b * brightness_val) >> 8

				rgb_data[offset + led_idx * 3] = u8(r_final)
				rgb_data[offset + led_idx * 3 + 1] = u8(g_final)
				rgb_data[offset + led_idx * 3 + 2] = u8(b_final)
			} else {
				rgb_data[offset + led_idx * 3] = 0
				rgb_data[offset + led_idx * 3 + 1] = 0
				rgb_data[offset + led_idx * 3 + 2] = 0
			}
		}
	}

	return rgb_data
}
