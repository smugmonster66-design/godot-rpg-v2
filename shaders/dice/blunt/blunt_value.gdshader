shader_type canvas_item;

// Blunt element value - beveled grey text
uniform vec4 text_color : source_color = vec4(0.55, 0.55, 0.58, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.75, 0.75, 0.78, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.2, 0.2, 0.22, 1.0);
uniform float bevel_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec2 light_direction = vec2(-0.7, -0.7);

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;
	
	float center = texture(TEXTURE, UV).a;
	vec2 light_dir = normalize(light_direction);
	
	// Sample in light direction and opposite for bevel
	float sample_light = texture(TEXTURE, UV + pixel * light_dir * 2.0).a;
	float sample_shadow = texture(TEXTURE, UV - pixel * light_dir * 2.0).a;
	
	// Bevel calculation
	float highlight = max(0.0, center - sample_light) * bevel_strength;
	float shadow = max(0.0, center - sample_shadow) * bevel_strength;
	
	// Base text color
	vec3 base = text_color.rgb;
	
	// Apply bevel lighting
	base = mix(base, highlight_color.rgb, highlight * 0.7);
	base = mix(base, shadow_color.rgb, shadow * 0.5);
	
	COLOR = vec4(base, center);
}
