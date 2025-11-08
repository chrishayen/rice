package main

import "core:testing"
import "core:fmt"
import "core:os"
import "core:bytes"
import "core:path/filepath"

// Test that verifies Odin LED effects produce identical output to Python implementations
@(test)
test_compare_all_effects_with_python :: proc(t: ^testing.T) {
	test_dir := "led_test_data"
	num_leds := 40

	// Test static colors
	test_static_effect(t, test_dir, "static_red", generate_static_color_hex(num_leds, "FF0000"))
	test_static_effect(t, test_dir, "static_green", generate_static_color_hex(num_leds, "00FF00"))
	test_static_effect(t, test_dir, "static_blue", generate_static_color_hex(num_leds, "0000FF"))
	test_static_effect(t, test_dir, "static_white", generate_static_color_hex(num_leds, "FFFFFF"))

	// Test rainbow
	test_static_effect(t, test_dir, "rainbow_100", generate_rainbow(num_leds, brightness = 100))
	test_static_effect(t, test_dir, "rainbow_50", generate_rainbow(num_leds, brightness = 50))

	// Test alternating patterns
	test_alternating_red_blue(t, test_dir, num_leds)
	test_alternating_green_yellow(t, test_dir, num_leds)

	// Test animated effects
	test_alternating_spin_effect(t, test_dir, num_leds)
	test_rainbow_morph_effect(t, test_dir, num_leds)
	test_breathing_effect(t, test_dir, num_leds)
	test_runway_effect(t, test_dir, num_leds)
	test_meteor_effect(t, test_dir, num_leds)
	test_color_cycle_effect(t, test_dir, num_leds)
	test_cover_cycle_effect(t, test_dir, num_leds)
	test_wave_effect(t, test_dir, num_leds)
	test_meteor_shower_effect(t, test_dir, num_leds)
	test_twinkle_effect(t, test_dir, num_leds)
}

// Helper function to test static effects
test_static_effect :: proc(t: ^testing.T, test_dir: string, name: string, odin_data: []u8) {
	defer delete(odin_data)

	python_data := load_python_output(t, test_dir, name)
	defer delete(python_data)

	if len(odin_data) != len(python_data) {
		fmt.eprintf("%s: Size mismatch - Odin: %d bytes, Python: %d bytes\n",
			name, len(odin_data), len(python_data))
		testing.fail(t)
		return
	}

	if !bytes.equal(odin_data, python_data) {
		// Find first difference for debugging
		for i in 0..<len(odin_data) {
			if odin_data[i] != python_data[i] {
				fmt.eprintf("%s: First difference at byte %d - Odin: 0x%02X, Python: 0x%02X\n",
					name, i, odin_data[i], python_data[i])
				// Show context around the difference
				start := max(0, i - 3)
				end := min(len(odin_data), i + 4)
				fmt.eprintf("  Context: Odin   = %02X\n", odin_data[start:end])
				fmt.eprintf("  Context: Python = %02X\n", python_data[start:end])
				testing.fail(t)
				break
			}
		}
	} else {
		fmt.printf("✓ %s: %d bytes match exactly\n", name, len(odin_data))
	}
}

// Test alternating red/blue pattern
test_alternating_red_blue :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	color1 := [3]u8{255, 0, 0}  // Red
	color2 := [3]u8{0, 0, 255}  // Blue
	odin_data := generate_alternating(num_leds, color1, color2)
	test_static_effect(t, test_dir, "alternating_red_blue", odin_data)
}

// Test alternating green/yellow pattern
test_alternating_green_yellow :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	color1 := [3]u8{0, 255, 0}    // Green
	color2 := [3]u8{255, 255, 0}  // Yellow
	odin_data := generate_alternating(num_leds, color1, color2)
	test_static_effect(t, test_dir, "alternating_green_yellow", odin_data)
}

// Test alternating spin animation
test_alternating_spin_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	color1 := [3]u8{255, 0, 0}  // Red
	color2 := [3]u8{0, 0, 255}  // Blue
	num_frames := 60
	odin_data := generate_alternating_spin(num_leds, color1, color2, num_frames)
	test_static_effect(t, test_dir, "alternating_spin", odin_data)
}

// Test rainbow morph animation
test_rainbow_morph_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 127
	odin_data := generate_rainbow_morph(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "rainbow_morph", odin_data)
}

// Test breathing animation
test_breathing_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 680
	odin_data := generate_breathing(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "breathing", odin_data)
}

// Test runway animation
test_runway_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 180
	odin_data := generate_runway(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "runway", odin_data)
}

// Test meteor animation
test_meteor_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 360
	odin_data := generate_meteor(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "meteor", odin_data)
}

// Test color cycle animation
test_color_cycle_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 40
	odin_data := generate_color_cycle(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "color_cycle", odin_data)
}

// Test cover cycle animation
test_cover_cycle_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 160
	odin_data := generate_cover_cycle(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "cover_cycle", odin_data)
}

// Test wave animation
test_wave_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 80
	odin_data := generate_wave(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "wave", odin_data)
}

// Test meteor shower animation
test_meteor_shower_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 80
	odin_data := generate_meteor_shower(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "meteor_shower", odin_data)
}

// Test twinkle animation
test_twinkle_effect :: proc(t: ^testing.T, test_dir: string, num_leds: int) {
	num_frames := 200
	odin_data := generate_twinkle(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "twinkle", odin_data)
}

// Helper function to load Python output from file
load_python_output :: proc(t: ^testing.T, test_dir: string, name: string) -> []u8 {
	filename := filepath.join({test_dir, fmt.aprintf("%s.bin", name)})
	defer delete(filename)

	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.eprintf("Failed to load Python output file: %s\n", filename)
		testing.fail(t)
		return make([]u8, 0)
	}

	return data
}

// Individual effect tests for detailed debugging
@(test)
test_static_red_comparison :: proc(t: ^testing.T) {
	num_leds := 40
	test_dir := "led_test_data"
	odin_data := generate_static_color_hex(num_leds, "FF0000")
	test_static_effect(t, test_dir, "static_red", odin_data)
}

@(test)
test_rainbow_comparison :: proc(t: ^testing.T) {
	num_leds := 40
	test_dir := "led_test_data"
	odin_data := generate_rainbow(num_leds, brightness = 100)
	test_static_effect(t, test_dir, "rainbow_100", odin_data)
}

@(test)
test_breathing_comparison :: proc(t: ^testing.T) {
	num_leds := 40
	test_dir := "led_test_data"
	num_frames := 680
	odin_data := generate_breathing(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "breathing", odin_data)
}

@(test)
test_twinkle_comparison :: proc(t: ^testing.T) {
	num_leds := 40
	test_dir := "led_test_data"
	num_frames := 200
	odin_data := generate_twinkle(num_leds, num_frames, brightness = 100)
	test_static_effect(t, test_dir, "twinkle", odin_data)
}

// Utility test to verify Python test data exists
@(test)
test_python_data_exists :: proc(t: ^testing.T) {
	test_dir := "led_test_data"
	required_files := []string{
		"static_red.bin",
		"static_green.bin",
		"static_blue.bin",
		"static_white.bin",
		"rainbow_100.bin",
		"rainbow_50.bin",
		"alternating_red_blue.bin",
		"alternating_green_yellow.bin",
		"alternating_spin.bin",
		"rainbow_morph.bin",
		"breathing.bin",
		"runway.bin",
		"meteor.bin",
		"color_cycle.bin",
		"cover_cycle.bin",
		"wave.bin",
		"meteor_shower.bin",
		"twinkle.bin",
	}

	for file in required_files {
		path := filepath.join({test_dir, file})
		defer delete(path)
		if !os.exists(path) {
			fmt.eprintf("Missing Python test data file: %s\n", path)
			testing.fail(t)
		} else {
			info, err := os.stat(path)
			if err == 0 {
				fmt.printf("Found %s (%d bytes)\n", file, info.size)
			}
		}
	}
}