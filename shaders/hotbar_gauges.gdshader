shader_type canvas_item;
render_mode blend_mix;

// Erases the health / stamina / mana fills that are painted into
// assets/UI/Hotbar-UI-final.png as those pools drain, leaving the frame,
// slot cells, gauntlets and the gold orb ring untouched. hud.gd feeds the
// three *_fill uniforms a 0..1 ratio (current / max) via
// set_shader_parameter(); the texture itself is never modified.
//
// All regions below are in SOURCE-TEXTURE PIXELS (the art is 256x41) and
// only need re-measuring if the bar art is redrawn. See shaders/README.md.

// 0.0 = fully drained, 1.0 = full.
uniform float health_fill  : hint_range(0.0, 1.0) = 1.0;
uniform float stamina_fill : hint_range(0.0, 1.0) = 1.0;
uniform float mana_fill    : hint_range(0.0, 1.0) = 1.0;

// How dark a drained pixel goes: 0.0 = near-black, 1.0 = untouched.
// A little residual colour reads as an empty channel rather than a
// punched-through hole to whatever is behind the HUD.
uniform float empty_dim : hint_range(0.0, 1.0) = 0.16;

// Background tint shown where a gauge has drained — the "empty socket"
// colour behind the fill. source_color gives a proper picker + sRGB
// handling in the Inspector so these can be dialled in live.
uniform vec4 empty_health  : source_color = vec4(0.17, 0.05, 0.06, 1.0);
uniform vec4 empty_stamina : source_color = vec4(0.05, 0.14, 0.07, 1.0);
uniform vec4 empty_mana    : source_color = vec4(0.05, 0.08, 0.17, 1.0);
// How much of the painted pixel still ghosts through the empty tint, so
// hatching / gradient detail isn't completely lost.
uniform float empty_detail : hint_range(0.0, 1.0) = 0.2;

// Size of one drain-edge step, in source-art texels. 1.0 = the mask
// snaps to the art's native pixel grid (so the diagonal edge stairsteps
// in whole HUD pixels, not sub-pixels); 2.0 = chunkier 2px steps.
const float MASK_PIXEL = 1.0;

// Health bar: horizontal band left of the orb. x = (outer edge, inner
// edge); "emptying toward the centre" means the outer tip empties first
// and the last sliver sits against the orb.
const vec2 HEALTH_X = vec2(62.0, 118.0);
const vec2 HEALTH_Y = vec2(10.0, 18.0);
// Lean of the draining edge, px of x per px of y off the band centre, so
// the receding edge follows the art's bevelled end-cap instead of cutting
// a vertical line through the gold. + = the top of the band recedes last.
const float HEALTH_SLOPE = 1.0;

// Stamina bar: mirror image, right of the orb (outer edge is the higher x).
const vec2 STAMINA_X = vec2(190.0, 134.0);
const vec2 STAMINA_Y = vec2(9.0, 19.0);
// Mirrored, so the slant leans the opposite way.
const float STAMINA_SLOPE = -1.0;

// Mana orb: circular fill whose surface falls straight down as it drains.
const vec2 MANA_X = vec2(110.0, 143.0);
const vec2 MANA_TOP_BOTTOM = vec2(11.0, 38.0);

// Loose hue tests so the hatched/gradient fill pixels all count, while the
// gold ring, dark frame and skin tones do not. The extra `c.g < 0.45` on
// red keeps amber/gold end-cap pixels (green ~0.5-0.7) out of the mask.
bool is_reddish(vec3 c)  { return c.r - c.g > 0.30 && c.r - c.b > 0.25 && c.g < 0.45 && c.r > 0.30; }
bool is_greenish(vec3 c) { return c.g - c.r > 0.15 && c.g - c.b > 0.12 && c.g > 0.30; }
bool is_bluish(vec3 c)   { return c.b - c.r > 0.10 && c.b - c.g > 0.05 && c.b > 0.12; }

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE; // UV -> source pixel coords
	// Same coords quantised to the art's texel grid. All the region / edge
	// tests below use this so the diagonal drain edge steps in whole HUD
	// pixels; the texture sample itself still uses the real UV.
	vec2 tpx = (floor(px / MASK_PIXEL) + 0.5) * MASK_PIXEL;
	float drained = 0.0;
	vec3 empty_col = vec3(0.0); // background tint for the drained pixel, set per gauge

	// Health: frac runs 0 at the outer tip to 1 at the orb; the outer tip
	// drains first, so hide anything past the remaining fill. The sheared x
	// (sx) tilts the drain edge so it tracks the bevelled end-cap.
	if (tpx.x >= min(HEALTH_X.x, HEALTH_X.y) && tpx.x <= max(HEALTH_X.x, HEALTH_X.y)
			&& tpx.y >= HEALTH_Y.x && tpx.y <= HEALTH_Y.y && is_reddish(col.rgb)) {
		float mid_y = (HEALTH_Y.x + HEALTH_Y.y) * 0.5;
		float sx = tpx.x + HEALTH_SLOPE * (tpx.y - mid_y);
		float frac = clamp((sx - HEALTH_X.x) / (HEALTH_X.y - HEALTH_X.x), 0.0, 1.0);
		if (frac < 1.0 - health_fill) {
			float shade = mix(0.78, 1.0, frac);                              // darker toward the outer/empty end
			float rim = smoothstep(0.06, 0.0, abs(frac - (1.0 - health_fill))); // faint highlight at the fill edge
			drained = 1.0;
			empty_col = empty_health.rgb * shade + rim * 0.15;
		}
	}

	// Stamina: same, mirrored about the orb.
	if (tpx.x >= min(STAMINA_X.x, STAMINA_X.y) && tpx.x <= max(STAMINA_X.x, STAMINA_X.y)
			&& tpx.y >= STAMINA_Y.x && tpx.y <= STAMINA_Y.y && is_greenish(col.rgb)) {
		float mid_y = (STAMINA_Y.x + STAMINA_Y.y) * 0.5;
		float sx = tpx.x + STAMINA_SLOPE * (tpx.y - mid_y);
		float frac = clamp((sx - STAMINA_X.x) / (STAMINA_X.y - STAMINA_X.x), 0.0, 1.0);
		if (frac < 1.0 - stamina_fill) {
			float shade = mix(0.78, 1.0, frac);
			float rim = smoothstep(0.06, 0.0, abs(frac - (1.0 - stamina_fill)));
			drained = 1.0;
			empty_col = empty_stamina.rgb * shade + rim * 0.15;
		}
	}

	// Mana: surface sits at the top when full, at the bottom when empty;
	// hide any blue pixel above it.
	if (tpx.x >= MANA_X.x && tpx.x <= MANA_X.y && is_bluish(col.rgb)) {
		float surface = mix(MANA_TOP_BOTTOM.x, MANA_TOP_BOTTOM.y, 1.0 - mana_fill);
		if (tpx.y < surface) {
			float mfrac = clamp((tpx.y - MANA_TOP_BOTTOM.x) / (MANA_TOP_BOTTOM.y - MANA_TOP_BOTTOM.x), 0.0, 1.0);
			float shade = mix(0.78, 1.0, mfrac);          // darker toward the top of the orb
			float rim = smoothstep(1.5, 0.0, surface - tpx.y); // highlight just above the water line
			drained = 1.0;
			empty_col = empty_mana.rgb * shade + rim * 0.15;
		}
	}

	// Empty pixels become the gauge's background tint, with `empty_detail`
	// of the dimmed original left in so the painted texture still ghosts.
	vec3 bg = mix(empty_col, col.rgb * empty_dim, empty_detail);
	col.rgb = mix(col.rgb, bg, drained);
	COLOR = col;
}
