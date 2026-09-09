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

// Health bar: horizontal band left of the orb. x = (outer edge, inner
// edge); "emptying toward the centre" means the outer tip empties first
// and the last sliver sits against the orb.
const vec2 HEALTH_X = vec2(62.0, 118.0);
const vec2 HEALTH_Y = vec2(9.0, 19.0);

// Stamina bar: mirror image, right of the orb (outer edge is the higher x).
const vec2 STAMINA_X = vec2(190.0, 134.0);
const vec2 STAMINA_Y = vec2(9.0, 19.0);

// Mana orb: circular fill whose surface falls straight down as it drains.
const vec2 MANA_X = vec2(110.0, 143.0);
const vec2 MANA_TOP_BOTTOM = vec2(11.0, 38.0);

// Loose hue tests so the hatched/gradient fill pixels all count, while the
// gold ring, dark frame and skin tones do not.
bool is_reddish(vec3 c)  { return c.r - c.g > 0.20 && c.r - c.b > 0.20 && c.r > 0.30; }
bool is_greenish(vec3 c) { return c.g - c.r > 0.15 && c.g - c.b > 0.12 && c.g > 0.30; }
bool is_bluish(vec3 c)   { return c.b - c.r > 0.10 && c.b - c.g > 0.05 && c.b > 0.12; }

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE; // UV -> source pixel coords
	float drained = 0.0;

	// Health: frac runs 0 at the outer tip to 1 at the orb; the outer tip
	// drains first, so hide anything past the remaining fill.
	if (px.x >= min(HEALTH_X.x, HEALTH_X.y) && px.x <= max(HEALTH_X.x, HEALTH_X.y)
			&& px.y >= HEALTH_Y.x && px.y <= HEALTH_Y.y && is_reddish(col.rgb)) {
		float frac = clamp((px.x - HEALTH_X.x) / (HEALTH_X.y - HEALTH_X.x), 0.0, 1.0);
		if (frac < 1.0 - health_fill) drained = 1.0;
	}

	// Stamina: same, mirrored about the orb.
	if (px.x >= min(STAMINA_X.x, STAMINA_X.y) && px.x <= max(STAMINA_X.x, STAMINA_X.y)
			&& px.y >= STAMINA_Y.x && px.y <= STAMINA_Y.y && is_greenish(col.rgb)) {
		float frac = clamp((px.x - STAMINA_X.x) / (STAMINA_X.y - STAMINA_X.x), 0.0, 1.0);
		if (frac < 1.0 - stamina_fill) drained = 1.0;
	}

	// Mana: surface sits at the top when full, at the bottom when empty;
	// hide any blue pixel above it.
	if (px.x >= MANA_X.x && px.x <= MANA_X.y && is_bluish(col.rgb)) {
		float surface = mix(MANA_TOP_BOTTOM.x, MANA_TOP_BOTTOM.y, 1.0 - mana_fill);
		if (px.y < surface) drained = 1.0;
	}

	col.rgb = mix(col.rgb, col.rgb * empty_dim, drained);
	COLOR = col;
}
