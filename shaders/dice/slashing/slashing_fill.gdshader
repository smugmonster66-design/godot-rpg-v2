shader_type canvas_item;

// Slashing Fill - Shiny steel effect preserving base luminance
uniform vec4 steel_color : source_color = vec4(0.75, 0.78, 0.82, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float metallic_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sweep_speed : hint_range(0.1, 2.0) = 0.8;
uniform float sweep_width : hint_range(0.05, 0.3) = 0.12;
uniform float reflection_intensity : hint_range(0.0, 0.5) = 0.25;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Extract luminance from original texture
	float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Create steel base using luminance
	vec3 steel_base = steel_color.rgb * (luminance * 0.6 + 0.4);
	
	// Metallic reflection based on UV angle
	float angle_reflection = sin(UV.x * 3.14159 * 2.0 + UV.y * 1.5) * 0.5 + 0.5;
	angle_reflection *= metallic_strength * luminance;
	
	// Diagonal sweep highlight
	float diagonal = UV.x + UV.y;
	float sweep_pos = fract(TIME * sweep_speed * 0.25);
	float sweep = smoothstep(sweep_pos - sweep_width, sweep_pos, diagonal) - 
	              smoothstep(sweep_pos, sweep_pos + sweep_width, diagonal);
	sweep *= reflection_intensity;
	
	// Subtle gradient for depth
	float vertical_grad = 1.0 - UV.y * 0.15;
	
	// Combine
	vec3 final_rgb = steel_base * vertical_grad;
	final_rgb += vec3(angle_reflection * 0.2);
	final_rgb += highlight_color.rgb * sweep;
	
	COLOR = vec4(final_rgb, tex_color.a);
}
