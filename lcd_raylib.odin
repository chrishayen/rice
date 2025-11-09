// lcd_raylib.odin
// Raylib-based LCD frame processing

package main

import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

// Raylib LCD processor state
LCD_Raylib_Processor :: struct {
	render_texture: rl.RenderTexture2D,
	initialized:    bool,
	width:          i32,
	height:         i32,
}

// Initialize raylib for LCD processing (headless mode)
init_lcd_raylib_processor :: proc(width: i32 = 400, height: i32 = 400) -> (processor: LCD_Raylib_Processor, ok: bool) {
	processor.width = width
	processor.height = height

	// Initialize raylib in headless mode (no window)
	rl.SetTraceLogLevel(.NONE)  // Disable raylib logging
	rl.SetConfigFlags({.WINDOW_HIDDEN})
	rl.InitWindow(width, height, "LCD Processor")
	rl.SetTargetFPS(60)

	if !rl.IsWindowReady() {
		fmt.println("Failed to initialize raylib window")
		return {}, false
	}

	// Create render texture for off-screen rendering
	processor.render_texture = rl.LoadRenderTexture(width, height)
	if processor.render_texture.id == 0 {
		fmt.println("Failed to create render texture")
		rl.CloseWindow()
		return {}, false
	}

	processor.initialized = true
	fmt.printfln("Raylib LCD processor initialized: %dx%d", width, height)
	return processor, true
}

// Cleanup raylib processor
cleanup_lcd_raylib_processor :: proc(processor: ^LCD_Raylib_Processor) {
	if !processor.initialized do return

	rl.UnloadRenderTexture(processor.render_texture)
	rl.CloseWindow()
	processor.initialized = false
}

// Process JPEG through raylib with transforms
process_lcd_frame_raylib :: proc(
	processor: ^LCD_Raylib_Processor,
	input_jpeg: []u8,
	transform: LCD_Transform,
	frame_number: int,
	allocator := context.allocator,
) -> (output_jpeg: []u8, ok: bool) {
	if !processor.initialized {
		fmt.println("Raylib processor not initialized")
		return nil, false
	}

	// Decode JPEG using stbi
	width, height, channels: c.int
	pixels := stbi.load_from_memory(
		raw_data(input_jpeg),
		c.int(len(input_jpeg)),
		&width,
		&height,
		&channels,
		4, // Force RGBA for raylib
	)
	if pixels == nil {
		fmt.println("Failed to decode JPEG")
		return nil, false
	}
	defer stbi.image_free(pixels)

	// Create raylib image from pixel data
	image := rl.Image{
		data = pixels,
		width = width,
		height = height,
		mipmaps = 1,
		format = .UNCOMPRESSED_R8G8B8A8,
	}

	// Load texture from image
	texture := rl.LoadTextureFromImage(image)
	defer rl.UnloadTexture(texture)

	// Begin frame - required even in headless mode for proper OpenGL state management
	rl.BeginDrawing()

	// Begin rendering to texture
	rl.BeginTextureMode(processor.render_texture)

	rl.ClearBackground(rl.BLACK)

	// Calculate transform parameters
	rotation := transform.rotate_degrees
	if transform.rotation_speed != 0 {
		// Animated rotation
		rotation += transform.rotation_speed * f32(frame_number)
		if transform.rotation_direction == .CCW {
			rotation = -rotation
		}
	}

	// Calculate zoom
	zoom := f32(1.0)
	if transform.zoom_percent > 0 {
		// Zoom in by reducing the source rect
		zoom = 1.0 + (transform.zoom_percent / 100.0)
	}

	// Source rectangle (what part of the texture to draw)
	src_rect := rl.Rectangle{
		x = 0,
		y = 0,
		width = f32(texture.width),
		height = f32(texture.height),
	}

	// Apply horizontal flip if needed
	if transform.flip_horizontal {
		src_rect.width = -src_rect.width
	}

	// Destination rectangle (where to draw on screen)
	dest_rect := rl.Rectangle{
		x = f32(processor.width) / 2,
		y = f32(processor.height) / 2,
		width = f32(processor.width) * zoom,
		height = f32(processor.height) * zoom,
	}

	// Draw texture with transforms
	origin := rl.Vector2{
		dest_rect.width / 2,
		dest_rect.height / 2,
	}

	rl.DrawTexturePro(
		texture,
		src_rect,
		dest_rect,
		origin,
		rotation,
		rl.WHITE,
	)

	// End texture mode before ending drawing
	rl.EndTextureMode()

	// End frame - flushes OpenGL commands and updates state
	rl.EndDrawing()

	// Read pixels from render texture
	rendered_image := rl.LoadImageFromTexture(processor.render_texture.texture)
	defer rl.UnloadImage(rendered_image)

	// Flip vertically (OpenGL textures are upside down)
	rl.ImageFlipVertical(&rendered_image)

	// Convert to RGB (remove alpha channel for JPEG)
	rl.ImageFormat(&rendered_image, .UNCOMPRESSED_R8G8B8)

	// Encode to JPEG using stbi_write
	jpeg_data: []u8

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
		rendered_image.width,
		rendered_image.height,
		3, // RGB
		rendered_image.data,
		90, // Quality (higher for better LCD quality)
	)

	if ret == 0 {
		delete(wctx.data)
		fmt.println("Failed to encode JPEG")
		return nil, false
	}

	return wctx.data[:], true
}
