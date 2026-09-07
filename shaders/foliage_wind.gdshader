shader_type canvas_item;
render_mode blend_mix;

// Reusable wind sway for vegetation — grass tiles, bushes, crop sprites,
// tree canopies. Attach a ShaderMaterial using this shader to a
// TileMapLayer or a Sprite2D. See shaders/README.md.
//
// The bottom edge of each image (trunk / stem base) is pinned; only the
// top edge moves, and the GPU shears the sprite linearly between them.
//
// wind_direction / wind_strength are project shader-globals (see
// project.godot [shader_globals]) so every foliage material shares one
// wind field. Tune them in Project Settings > Shader Globals, or drive
// them at runtime from a weather system with
// RenderingServer.global_shader_parameter_set("wind_strength", x).

// World-space push direction. Need not be unit length; its magnitude
// scales the effect per axis (a little Y makes the motion less flat).
global uniform vec2 wind_direction;
// Global multiplier. 0.0 = dead calm. A weather system can ramp this.
global uniform float wind_strength;

// Peak horizontal offset at the top edge, in pixels, at wind_strength = 1.
uniform float sway_strength : hint_range(0.0, 8.0) = 1.5;
// Base oscillation rate.
uniform float sway_speed : hint_range(0.0, 10.0) = 1.6;
// Slow amplitude swell ("gusts") layered over the base oscillation.
uniform float gust_speed : hint_range(0.0, 4.0) = 0.35;
// Round the offset to whole pixels — matches the project's nearest
// texture filter and avoids sub-pixel shimmer. Turn off for smooth motion.
uniform bool pixel_snap = true;
// Flip if a sprite/tileset ends up swaying from its bottom instead of its
// top (its vertex winding differs from the assumed order below).
uniform bool invert_pivot = false;

// Vertical position within each quad, keyed by VERTEX_ID: 0.0 on the top
// edge, 1.0 on the bottom edge. This works even for batched TileMapLayer
// tiles, where UV is atlas-space and can't tell you where you are inside a
// tile. Assumed canvas-quad winding: 0=top-left, 1=bottom-left,
// 2=bottom-right, 3=top-right.
const float quad_v[4] = {0.0, 1.0, 1.0, 0.0};

void vertex() {
	float v = quad_v[VERTEX_ID % 4];
	if (invert_pivot) {
		v = 1.0 - v;
	}
	// 1.0 on the top edge, 0.0 on the pinned bottom edge.
	float bend = 1.0 - v;

	// World position gives each sprite / each tile its own phase, so
	// neighbouring foliage doesn't sway in lockstep.
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float phase = dot(world, vec2(0.035, 0.021));

	float gust = 0.65 + 0.35 * sin(TIME * gust_speed + phase * 0.5);
	float wave = sin(TIME * sway_speed + phase)
	           + 0.3 * sin(TIME * sway_speed * 2.7 + phase * 1.7);

	vec2 offset = wind_direction * (wave * gust * sway_strength * wind_strength * bend);
	if (pixel_snap) {
		offset = round(offset);
	}
	VERTEX += offset;
}
