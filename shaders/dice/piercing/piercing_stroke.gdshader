shader_type canvas_item;

// Piercing element stroke - thin razor edges with gleaming points
uniform vec4 edge_color : source_color = vec4(0.7, 0.72, 0.75, 1.0);
uniform vec4 gleam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_sharpness : hint_range(1.0, 8.0) = 4.0;
uniform float gleam_speed : hint_range(0.5, 3.0) = 1.2;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sharp edge highlight pattern
	float edge_angle = UV.x * 0.7 + UV.y * 0.3;
	float sharp_edge = pow(abs(sin(edge_angle * 3.14159 * edge_sharpness)), 6.0);
	
	// Traveling gleam point (faster, more erratic than slashing)
	float gleam_pos = fract(TIME * gleam_speed * 0.4);
	float gleam_dist = abs(edge_angle - gleam_pos);
	float gleam = smoothstep(0.08, 0.0, gleam_dist) * 0.8;
	
	// Secondary gleam for more "sparkle"
	float gleam_pos2 = fract(TIME * gleam_speed * 0.6 + 0.5);
	float gleam_dist2 = abs((1.0 - edge_angle) - gleam_pos2);
	float gleam2 = smoothstep(0.06, 0.0, gleam_dist2) * 0.5;
	
	// Combine
	vec3 base = edge_color.rgb * tex_color.rgb;
	base += gleam_color.rgb * sharp_edge * 0.2;
	base += gleam_color.rgb * (gleam + gleam2);
	
	COLOR = vec4(base, tex_color.a);
}
