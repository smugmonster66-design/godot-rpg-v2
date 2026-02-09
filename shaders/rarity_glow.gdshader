// res://shaders/rarity_glow.gdshader
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float glow_softness : hint_range(0.1, 5.0) = 1.5;
uniform float glow_width : hint_range(0.0, 1) = 0.15;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	// Distance from nearest edge (0 at edge, 0.5 at center)
	vec2 edge_dist = min(UV, 1.0 - UV);
	float dist = min(edge_dist.x, edge_dist.y);

	// Glow fades from edge inward over glow_width fraction of the rect
	float glow = 1.0 - smoothstep(0.0, glow_width, pow(dist / glow_width, 1.0 / glow_softness));

	// Pulse
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	glow *= pulse;

	COLOR = vec4(glow_color.rgb, glow * glow_alpha);
}