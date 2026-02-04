shader_type canvas_item;

// Slashing Stroke - Razor-sharp edge effect
uniform vec4 edge_color : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform vec4 sharp_highlight : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_sharpness : hint_range(1.0, 10.0) = 6.0;
uniform float glint_speed : hint_range(0.5, 3.0) = 1.5;
uniform float glint_intensity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sharp edge highlight along diagonal
	float edge_angle = (UV.x + UV.y) * 0.5;
	float sharp_edge = pow(abs(sin(edge_angle * 3.14159 * edge_sharpness)), 8.0);
	
	// Moving glint
	float glint_pos = fract(TIME * glint_speed * 0.3);
	float glint_dist = abs(edge_angle - glint_pos);
	float glint = smoothstep(0.1, 0.0, glint_dist) * glint_intensity;
	
	// Base edge coloring
	vec3 final_rgb = edge_color.rgb * tex_color.rgb;
	
	// Add sharp highlight
	final_rgb += sharp_highlight.rgb * sharp_edge * 0.3;
	
	// Add moving glint
	final_rgb += sharp_highlight.rgb * glint;
	
	COLOR = vec4(final_rgb, tex_color.a);
}
