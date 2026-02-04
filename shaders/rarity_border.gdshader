// rarity_border.gdshader - Animated border shader for item rarity
shader_type canvas_item;

// Rarity color from script
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Border properties
uniform float border_width : hint_range(0.0, 0.5) = 0.05;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	// Get UV coordinates
	vec2 uv = UV;
	
	// Calculate distance from edge
	vec2 edge_distance = min(uv, 1.0 - uv);
	float min_distance = min(edge_distance.x, edge_distance.y);
	
	// Create border mask
	float border = smoothstep(border_width - 0.01, border_width, min_distance);
	
	// Pulsing glow effect
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float glow = (1.0 - border) * glow_strength * pulse;
	
	// Get original texture color
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Mix border color with original
	vec3 final_color = mix(border_color.rgb * (1.0 + glow), tex_color.rgb, border);
	float final_alpha = max(tex_color.a, (1.0 - border) * border_color.a);
	
	COLOR = vec4(final_color, final_alpha);
}
