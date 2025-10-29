// fan_layout.odin
// Physical LED layout definitions for different fan models

package main

import "core:math"

// LED section types within a fan
LED_Section :: enum {
	Left_Edge,             // Vertical strip on left side
	Right_Edge,            // Vertical strip on right side
	Top_Left_Diagonal,     // Diagonal from top-left toward center
	Top_Center,            // Horizontal strip at top center
	Top_Right_Diagonal,    // Diagonal from top-right toward center
	Bottom_Left_Diagonal,  // Diagonal from bottom-left toward center
	Bottom_Center,         // Horizontal strip at bottom center
	Bottom_Right_Diagonal, // Diagonal from bottom-right toward center
}

// Physical position of an LED
LED_Position :: struct {
	x:       f64, // Normalized coordinates [-1, 1] relative to fan center
	y:       f64,
	section: LED_Section,
	angle:   f64, // Angle in radians for ring LEDs
	radius:  f64, // Normalized radius [0, 1]
}

// SL 120 fan layout
// Based on actual fan observation with LED position diagram:
// - Left vertical edge: 8 LEDs
// - Right vertical edge: 8 LEDs
// - Four diagonal strips: 3 LEDs each (12 total)
// - Top center strip: 6 LEDs (between top diagonals)
// - Bottom center strip: 6 LEDs (between bottom diagonals)
// - Total: 8 + 8 + 3 + 6 + 3 + 3 + 6 + 3 = 40 LEDs

SL_120_LED_COUNT :: 40
SL_120_LEFT_EDGE_LED_COUNT :: 8      // LEDs on left vertical edge
SL_120_RIGHT_EDGE_LED_COUNT :: 8     // LEDs on right vertical edge
SL_120_DIAGONAL_LED_COUNT :: 3       // LEDs per diagonal segment
SL_120_CENTER_LED_COUNT :: 6         // LEDs in center strips (top and bottom)

// Generate LED layout for SL 120 fan
// Returns array of LED positions in the order they appear in the data stream
generate_sl_120_layout :: proc() -> [SL_120_LED_COUNT]LED_Position {
	layout: [SL_120_LED_COUNT]LED_Position
	idx := 0

	// Pattern layout:
	// |/  \|
	// ||  ||
	// |\  /|

	EDGE_X :: 0.85 // X position for vertical edges
	EDGE_Y_START :: -0.85
	EDGE_Y_END :: 0.85

	// Left vertical edge (8 LEDs)
	for i in 0 ..< SL_120_LEFT_EDGE_LED_COUNT {
		t := f64(i) / f64(SL_120_LEFT_EDGE_LED_COUNT - 1)
		y := EDGE_Y_START + t * (EDGE_Y_END - EDGE_Y_START)

		layout[idx] = LED_Position{
			x = -EDGE_X,
			y = y,
			section = .Left_Edge,
			angle = math.PI / 2, // Vertical orientation
			radius = math.sqrt(EDGE_X * EDGE_X + y * y),
		}
		idx += 1
	}

	// Right vertical edge (8 LEDs)
	for i in 0 ..< SL_120_RIGHT_EDGE_LED_COUNT {
		t := f64(i) / f64(SL_120_RIGHT_EDGE_LED_COUNT - 1)
		y := EDGE_Y_START + t * (EDGE_Y_END - EDGE_Y_START)

		layout[idx] = LED_Position{
			x = EDGE_X,
			y = y,
			section = .Right_Edge,
			angle = math.PI / 2, // Vertical orientation
			radius = math.sqrt(EDGE_X * EDGE_X + y * y),
		}
		idx += 1
	}

	// Diagonal positions
	DIAG_OUTER :: 0.65  // Where diagonals meet the edges
	DIAG_INNER :: 0.20  // Where diagonals get close to center
	DIAG_Y_TOP :: -0.65
	DIAG_Y_BOTTOM :: 0.65

	// Top-left diagonal: / shape from left edge toward center
	for i in 0 ..< SL_120_DIAGONAL_LED_COUNT {
		t := f64(i) / f64(SL_120_DIAGONAL_LED_COUNT - 1)
		x := -DIAG_OUTER + t * (DIAG_INNER - (-DIAG_OUTER))
		y := DIAG_Y_TOP + t * (-0.1 - DIAG_Y_TOP)  // Angles upward toward center

		layout[idx] = LED_Position{
			x = x,
			y = y,
			section = .Top_Left_Diagonal,
			angle = math.atan2(f64(-0.1 - DIAG_Y_TOP), f64(DIAG_INNER - (-DIAG_OUTER))),
			radius = math.sqrt(x * x + y * y),
		}
		idx += 1
	}

	// Top center strip: horizontal strip between the two top diagonals (6 LEDs)
	TOP_CENTER_Y :: -0.5
	for i in 0 ..< SL_120_CENTER_LED_COUNT {
		t := f64(i) / f64(SL_120_CENTER_LED_COUNT - 1)
		x := -0.4 + t * 0.8 // From -0.4 to 0.4

		layout[idx] = LED_Position{
			x = x,
			y = TOP_CENTER_Y,
			section = .Top_Center,
			angle = 0, // Horizontal orientation
			radius = math.sqrt(x * x + TOP_CENTER_Y * TOP_CENTER_Y),
		}
		idx += 1
	}

	// Top-right diagonal: \ shape from right edge toward center
	for i in 0 ..< SL_120_DIAGONAL_LED_COUNT {
		t := f64(i) / f64(SL_120_DIAGONAL_LED_COUNT - 1)
		x := DIAG_OUTER - t * (DIAG_OUTER - DIAG_INNER)
		y := DIAG_Y_TOP + t * (-0.1 - DIAG_Y_TOP)  // Angles upward toward center

		layout[idx] = LED_Position{
			x = x,
			y = y,
			section = .Top_Right_Diagonal,
			angle = math.atan2(f64(-0.1 - DIAG_Y_TOP), f64(DIAG_INNER - DIAG_OUTER)),
			radius = math.sqrt(x * x + y * y),
		}
		idx += 1
	}

	// Bottom-left diagonal: \ shape from left edge toward center
	for i in 0 ..< SL_120_DIAGONAL_LED_COUNT {
		t := f64(i) / f64(SL_120_DIAGONAL_LED_COUNT - 1)
		x := -DIAG_OUTER + t * (DIAG_INNER - (-DIAG_OUTER))
		y := DIAG_Y_BOTTOM - t * (DIAG_Y_BOTTOM - 0.1)  // Angles downward toward center

		layout[idx] = LED_Position{
			x = x,
			y = y,
			section = .Bottom_Left_Diagonal,
			angle = math.atan2(f64(0.1 - DIAG_Y_BOTTOM), f64(DIAG_INNER - (-DIAG_OUTER))),
			radius = math.sqrt(x * x + y * y),
		}
		idx += 1
	}

	// Bottom center strip: horizontal strip between the two bottom diagonals (6 LEDs)
	BOTTOM_CENTER_Y :: 0.5
	for i in 0 ..< SL_120_CENTER_LED_COUNT {
		t := f64(i) / f64(SL_120_CENTER_LED_COUNT - 1)
		x := -0.4 + t * 0.8 // From -0.4 to 0.4

		layout[idx] = LED_Position{
			x = x,
			y = BOTTOM_CENTER_Y,
			section = .Bottom_Center,
			angle = 0, // Horizontal orientation
			radius = math.sqrt(x * x + BOTTOM_CENTER_Y * BOTTOM_CENTER_Y),
		}
		idx += 1
	}

	// Bottom-right diagonal: / shape from right edge toward center
	for i in 0 ..< SL_120_DIAGONAL_LED_COUNT {
		t := f64(i) / f64(SL_120_DIAGONAL_LED_COUNT - 1)
		x := DIAG_OUTER - t * (DIAG_OUTER - DIAG_INNER)
		y := DIAG_Y_BOTTOM - t * (DIAG_Y_BOTTOM - 0.1)  // Angles downward toward center

		layout[idx] = LED_Position{
			x = x,
			y = y,
			section = .Bottom_Right_Diagonal,
			angle = math.atan2(f64(0.1 - DIAG_Y_BOTTOM), f64(DIAG_INNER - DIAG_OUTER)),
			radius = math.sqrt(x * x + y * y),
		}
		idx += 1
	}

	return layout
}

// TL fan layout (simpler, 26 LEDs in a circle)
TL_LED_COUNT :: 26

generate_tl_layout :: proc() -> [TL_LED_COUNT]LED_Position {
	layout: [TL_LED_COUNT]LED_Position
	RING_RADIUS :: 0.9

	for i in 0 ..< TL_LED_COUNT {
		angle := f64(i) / f64(TL_LED_COUNT) * 2.0 * math.PI - math.PI / 2.0
		layout[i] = LED_Position{
			x = RING_RADIUS * math.cos(angle),
			y = RING_RADIUS * math.sin(angle),
			section = .Left_Edge, // Default to left edge for TL fans
			angle = angle,
			radius = RING_RADIUS,
		}
	}

	return layout
}
