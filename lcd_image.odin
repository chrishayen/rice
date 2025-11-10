// lcd_image.odin
// Image processing for LCD frames using native stb libraries

package main

import "core:c"
import "core:mem"
import "core:math"
import stbi "vendor:stb/image"

LCD_Rotation_Direction :: enum {
	CCW,
	CW,
}

LCD_Transform :: struct {
	zoom_percent:       f32,  // 0-90, crop center and scale up
	rotate_degrees:     f32,  // Static rotation (not implemented yet)
	flip_horizontal:    bool, // Horizontal flip (not implemented yet)
	rotation_speed:     f32,  // Degrees to rotate per frame (animated, not implemented yet)
	rotation_direction: LCD_Rotation_Direction,
}

// Manual image rotation using nearest neighbor sampling
// Returns new image data that must be freed by caller
rotate_image_90 :: proc(pixels: []u8, width, height, channels: int, times: int, allocator := context.allocator) -> []u8 {
	if times == 0 {
		result := make([]u8, len(pixels), allocator)
		copy(result, pixels)
		return result
	}

	// Rotate 90 degrees clockwise once
	new_width := height
	new_height := width
	new_pixels := make([]u8, new_width * new_height * channels, allocator)

	for y in 0..<height {
		for x in 0..<width {
			src_idx := (y * width + x) * channels
			// Rotate 90 clockwise: (x, y) -> (height - 1 - y, x)
			dst_x := height - 1 - y
			dst_y := x
			dst_idx := (dst_y * new_width + dst_x) * channels

			for c in 0..<channels {
				new_pixels[dst_idx + c] = pixels[src_idx + c]
			}
		}
	}

	// Recursively rotate remaining times
	if times > 1 {
		result := rotate_image_90(new_pixels, new_width, new_height, channels, times - 1, allocator)
		delete(new_pixels, allocator)
		return result
	}

	return new_pixels
}

// Manual horizontal flip
flip_image_horizontal :: proc(pixels: []u8, width, height, channels: int, allocator := context.allocator) -> []u8 {
	result := make([]u8, len(pixels), allocator)

	for y in 0..<height {
		for x in 0..<width {
			src_idx := (y * width + x) * channels
			dst_x := width - 1 - x
			dst_idx := (y * width + dst_x) * channels

			for c in 0..<channels {
				result[dst_idx + c] = pixels[src_idx + c]
			}
		}
	}

	return result
}

// Process LCD image with transforms
process_lcd_image :: proc(
	input_jpeg: []u8,
	transform: LCD_Transform,
	frame_number: int,
	allocator := context.allocator,
) -> (output_jpeg: []u8, ok: bool) {

	// Decode JPEG
	width, height, channels: c.int
	pixels := stbi.load_from_memory(
		raw_data(input_jpeg),
		c.int(len(input_jpeg)),
		&width,
		&height,
		&channels,
		3, // Force RGB
	)
	if pixels == nil {
		return nil, false
	}
	defer stbi.image_free(pixels)

	final_pixels := pixels
	final_width := width
	final_height := height
	needs_free := false

	// Apply zoom (center crop + resize)
	if transform.zoom_percent > 0 {
		zoom_factor := 1.0 - (transform.zoom_percent / 100.0)
		crop_w := c.int(f32(width) * zoom_factor)
		crop_h := c.int(f32(height) * zoom_factor)

		// Center crop offsets
		offset_x := (width - crop_w) / 2
		offset_y := (height - crop_h) / 2

		// Extract cropped region
		cropped := make([]u8, int(crop_w * crop_h * 3), allocator)
		for y in 0..<crop_h {
			for x in 0..<crop_w {
				src_idx := int(((y + offset_y) * width + (x + offset_x)) * 3)
				dst_idx := int((y * crop_w + x) * 3)
				cropped[dst_idx + 0] = pixels[src_idx + 0]
				cropped[dst_idx + 1] = pixels[src_idx + 1]
				cropped[dst_idx + 2] = pixels[src_idx + 2]
			}
		}

		// Resize back to original dimensions
		resized := make([]u8, int(width * height * 3), allocator)
		ret := stbi.resize_uint8(
			raw_data(cropped), crop_w, crop_h, 0,
			raw_data(resized), width, height, 0,
			3,
		)
		delete(cropped, allocator)

		if ret == 0 {
			delete(resized, allocator)
			return nil, false
		}

		if needs_free {
			delete_slice(final_pixels, final_width, final_height, 3, allocator)
		}

		final_pixels = raw_data(resized)
		needs_free = true
	}

	// TODO: Apply rotation
	// TODO: Apply flip

	// Encode back to JPEG
	jpeg_data: []u8
	jpeg_len: int

	Write_Context :: struct {
		data: [dynamic]u8,
	}

	write_callback :: proc "c" (ctx: rawptr, data: rawptr, size: c.int) {
		context = runtime_default_context()
		wctx := cast(^Write_Context)ctx
		old_len := len(wctx.data)
		resize(&wctx.data, old_len + int(size))
		mem.copy(&wctx.data[old_len], data, int(size))
	}

	wctx := Write_Context{
		data = make([dynamic]u8, allocator),
	}

	ret := stbi.write_jpg_to_func(
		write_callback,
		&wctx,
		final_width,
		final_height,
		3,
		final_pixels,
		85, // Quality
	)

	if ret == 0 {
		delete(wctx.data)
		if needs_free {
			delete_slice(final_pixels, final_width, final_height, 3, allocator)
		}
		return nil, false
	}

	jpeg_data = wctx.data[:]

	if needs_free {
		delete_slice(final_pixels, final_width, final_height, 3, allocator)
	}

	return jpeg_data, true
}

// Helper to delete slice-like pixel data
delete_slice :: proc(pixels: [^]u8, width, height, channels: c.int, allocator: mem.Allocator) {
	if pixels != nil {
		slice := ([^]u8)(pixels)[:width * height * channels]
		delete(slice, allocator)
	}
}

// Import runtime context for C callback
import "base:runtime"
runtime_default_context :: proc() -> runtime.Context {
	return runtime.default_context()
}
