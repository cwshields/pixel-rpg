shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
uniform int steps : hint_range(2, 8) = 3;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = dot(uv, uv);
	float alpha = 1.0 - dist;
	alpha = clamp(alpha, 0.0, 1.0);
	alpha = floor(alpha * float(steps) + 0.5) / float(steps);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * alpha);
}
