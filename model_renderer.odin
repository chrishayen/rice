// model_renderer.odin
// 3D model loading and rendering for preview area

package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

// 3D vector
Vec3 :: struct {
	x, y, z: f64,
}

// Triangle face (indices into vertex array)
Face :: struct {
	v1, v2, v3: int,
}

// 3D Model data
Model :: struct {
	vertices: [dynamic]Vec3,
	faces:    [dynamic]Face,
	// Computed bounds for centering
	min:      Vec3,
	max:      Vec3,
	center:   Vec3,
}

// Camera/view state
View_State :: struct {
	rotation_x: f64,
	rotation_y: f64,
	zoom:       f64,
}

// Parse OBJ file
parse_obj_file :: proc(filepath: string) -> (Model, bool) {
	model := Model {
		vertices = make([dynamic]Vec3),
		faces    = make([dynamic]Face),
	}

	data, ok := os.read_entire_file(filepath)
	if !ok {
		log_error("Failed to read OBJ file: %s", filepath)
		return model, false
	}
	defer delete(data)

	content := string(data)
	lines := strings.split_lines(content)
	defer delete(lines)

	min := Vec3{math.F64_MAX, math.F64_MAX, math.F64_MAX}
	max := Vec3{-math.F64_MAX, -math.F64_MAX, -math.F64_MAX}

	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 || trimmed[0] == '#' {
			continue
		}

		parts := strings.split(trimmed, " ")
		defer delete(parts)

		if len(parts) == 0 {
			continue
		}

		switch parts[0] {
		case "v":
			// Vertex: v x y z
			if len(parts) >= 4 {
				x, x_ok := strconv.parse_f64(parts[1])
				y, y_ok := strconv.parse_f64(parts[2])
				z, z_ok := strconv.parse_f64(parts[3])

				if x_ok && y_ok && z_ok {
					v := Vec3{x, y, z}
					append(&model.vertices, v)

					// Update bounds
					min.x = math.min(min.x, x)
					min.y = math.min(min.y, y)
					min.z = math.min(min.z, z)
					max.x = math.max(max.x, x)
					max.y = math.max(max.y, y)
					max.z = math.max(max.z, z)
				}
			}

		case "f":
			// Face: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
			if len(parts) >= 4 {
				// Parse first vertex index
				v1_parts := strings.split(parts[1], "/")
				v2_parts := strings.split(parts[2], "/")
				v3_parts := strings.split(parts[3], "/")

				v1, v1_ok := strconv.parse_int(v1_parts[0])
				v2, v2_ok := strconv.parse_int(v2_parts[0])
				v3, v3_ok := strconv.parse_int(v3_parts[0])

				delete(v1_parts)
				delete(v2_parts)
				delete(v3_parts)

				if v1_ok && v2_ok && v3_ok {
					// OBJ indices are 1-based, convert to 0-based
					face := Face {
						v1 = v1 - 1,
						v2 = v2 - 1,
						v3 = v3 - 1,
					}
					append(&model.faces, face)
				}
			}
		}
	}

	// Compute center and bounds
	model.min = min
	model.max = max
	model.center = Vec3 {
		x = (min.x + max.x) / 2,
		y = (min.y + max.y) / 2,
		z = (min.z + max.z) / 2,
	}

	log_info("Loaded OBJ: %d vertices, %d faces", len(model.vertices), len(model.faces))
	log_debug("Bounds: min=(%.2f, %.2f, %.2f) max=(%.2f, %.2f, %.2f)", min.x, min.y, min.z, max.x, max.y, max.z)

	return model, true
}

// Free model memory
free_model :: proc(model: ^Model) {
	delete(model.vertices)
	delete(model.faces)
}

// Matrix operations for 3D transformations
Matrix3x3 :: struct {
	m: [9]f64,
}

// Create rotation matrix around X axis
rotation_matrix_x :: proc(angle: f64) -> Matrix3x3 {
	c := math.cos(angle)
	s := math.sin(angle)

	return Matrix3x3{m = {
		1, 0, 0,
		0, c, -s,
		0, s, c,
	}}
}

// Create rotation matrix around Y axis
rotation_matrix_y :: proc(angle: f64) -> Matrix3x3 {
	c := math.cos(angle)
	s := math.sin(angle)

	return Matrix3x3{m = {
		c, 0, s,
		0, 1, 0,
		-s, 0, c,
	}}
}

// Multiply matrix by vector
mul_matrix_vec :: proc(m: Matrix3x3, v: Vec3) -> Vec3 {
	return Vec3 {
		x = m.m[0] * v.x + m.m[1] * v.y + m.m[2] * v.z,
		y = m.m[3] * v.x + m.m[4] * v.y + m.m[5] * v.z,
		z = m.m[6] * v.x + m.m[7] * v.y + m.m[8] * v.z,
	}
}

// Multiply two matrices
mul_matrix :: proc(a, b: Matrix3x3) -> Matrix3x3 {
	result: Matrix3x3

	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			sum := 0.0
			for k in 0 ..< 3 {
				sum += a.m[i * 3 + k] * b.m[k * 3 + j]
			}
			result.m[i * 3 + j] = sum
		}
	}

	return result
}

// Project 3D point to 2D screen coordinates
// Uses orthographic projection for simplicity
project_point :: proc(v: Vec3, view: View_State, width, height: f64) -> (x, y: f64, z_depth: f64) {
	// Center the model
	centered := v

	// Apply rotation
	rot_x := rotation_matrix_x(view.rotation_x)
	rot_y := rotation_matrix_y(view.rotation_y)
	rotation := mul_matrix(rot_y, rot_x)

	rotated := mul_matrix_vec(rotation, centered)

	// Apply zoom and project to screen
	scale := view.zoom
	x = rotated.x * scale + width / 2
	y = rotated.y * scale + height / 2
	z_depth = rotated.z

	return x, y, z_depth
}

// Triangle with depth for sorting
Triangle_3D :: struct {
	v1, v2, v3: struct {
		x, y: f64,
	},
	avg_depth:  f64,
	normal_z:   f64,
}

// Render the 3D model using Cairo
render_model :: proc(cr: cairo_t, model: ^Model, view: View_State, width, height: c.int) {
	w := f64(width)
	h := f64(height)

	// Clear background
	cairo_set_source_rgb(cr, 0.15, 0.15, 0.15)
	cairo_paint(cr)

	if len(model.vertices) == 0 {
		// Show loading message
		cairo_set_source_rgb(cr, 0.5, 0.5, 0.5)
		cairo_select_font_face(cr, "Inter", 0, 0)
		cairo_set_font_size(cr, 16)
		cairo_move_to(cr, w / 2 - 60, h / 2)
		cairo_show_text(cr, "No model loaded")
		return
	}

	// Compute model size for auto-scaling
	size_x := model.max.x - model.min.x
	size_y := model.max.y - model.min.y
	size_z := model.max.z - model.min.z
	max_size := math.max(size_x, math.max(size_y, size_z))

	// Auto-scale to fit in viewport
	auto_scale := math.min(w, h) / (max_size * 1.2) // 1.2 for some padding

	// Create view with auto-scaling
	scaled_view := view
	scaled_view.zoom *= auto_scale

	// Transform all vertices first
	transformed_vertices := make([dynamic]struct {
		x, y, depth: f64,
	}, len(model.vertices))
	defer delete(transformed_vertices)

	for v, i in model.vertices {
		// Center the vertex
		centered := Vec3 {
			x = v.x - model.center.x,
			y = v.y - model.center.y,
			z = v.z - model.center.z,
		}
		x, y, depth := project_point(centered, scaled_view, w, h)
		transformed_vertices[i] = {x, y, depth}
	}

	// Build list of triangles with depth for sorting
	// Use LOD: skip some triangles if there are too many for interactive performance
	skip_step := 1
	target_triangles :: 15000 // Target triangle count for smooth rendering
	if len(model.faces) > target_triangles * 2 {
		skip_step = len(model.faces) / target_triangles
	}

	triangles := make([dynamic]Triangle_3D, 0, len(model.faces) / skip_step)
	defer delete(triangles)

	for face, idx in model.faces {
		// LOD: Skip some faces if we have too many
		if skip_step > 1 && idx % skip_step != 0 {
			continue
		}
		// Check bounds
		if face.v1 < 0 || face.v1 >= len(transformed_vertices) ||
		   face.v2 < 0 || face.v2 >= len(transformed_vertices) ||
		   face.v3 < 0 || face.v3 >= len(transformed_vertices) {
			continue
		}

		v1 := transformed_vertices[face.v1]
		v2 := transformed_vertices[face.v2]
		v3 := transformed_vertices[face.v3]

		// Backface culling based on winding order
		edge1_x := v2.x - v1.x
		edge1_y := v2.y - v1.y
		edge2_x := v3.x - v1.x
		edge2_y := v3.y - v1.y

		cross := edge1_x * edge2_y - edge1_y * edge2_x

		// Only include front-facing triangles
		if cross > 0 {
			avg_depth := (v1.depth + v2.depth + v3.depth) / 3.0

			tri := Triangle_3D {
				v1        = {v1.x, v1.y},
				v2        = {v2.x, v2.y},
				v3        = {v3.x, v3.y},
				avg_depth = avg_depth,
				normal_z  = cross, // Use cross product as simple lighting
			}
			append(&triangles, tri)
		}
	}

	// Sort triangles back-to-front (painter's algorithm)
	// Use Odin's built-in sort which is much faster than bubble sort
	slice.sort_by(triangles[:], proc(a, b: Triangle_3D) -> bool {
		return a.avg_depth < b.avg_depth
	})

	// Draw triangles with simple shading
	// Batch similar colors to reduce Cairo state changes
	for tri in triangles {
		// Simple lighting based on normal
		light := math.abs(tri.normal_z)
		max_light := 10000.0
		normalized_light := math.clamp(light / max_light, 0.0, 1.0)

		// Base color with lighting
		base_brightness := 0.3
		brightness := base_brightness + normalized_light * 0.5

		// Color - light gray with shading
		r := 0.7 * brightness
		g := 0.7 * brightness
		b := 0.75 * brightness

		// Fill triangle
		cairo_set_source_rgb(cr, r, g, b)
		cairo_move_to(cr, tri.v1.x, tri.v1.y)
		cairo_line_to(cr, tri.v2.x, tri.v2.y)
		cairo_line_to(cr, tri.v3.x, tri.v3.y)
		cairo_close_path(cr)
		cairo_fill(cr)
	}

	log_debug("Drew %d triangles", len(triangles))
}
