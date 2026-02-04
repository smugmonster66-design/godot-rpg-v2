shader_type canvas_item;

// Blunt element stroke - beveled heavy edges
uniform vec4 edge_color : source_color = vec4(0.35, 0.35, 0.38, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.55, 0.55, 0.58, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform float bevel_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec2 light_direction = vec2(-0.7, -0.7);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;
	
	float center = tex_color.a;
	vec2 light_dir = normalize(light_direction);
	
	// Sample in light direction and opposite for bevel
	float sample_light = texture(TEXTURE, UV + pixel * light_dir * 2.0).a;
	float sample_shadow = texture(TEXTURE, UV - pixel * light_dir * 2.0).a;
	
	// Bevel calculation
	float highlight = max(0.0, center - sample_light) * bevel_strength;
	float shadow = max(0.0, center - sample_shadow) * bevel_strength;
	
	// Base edge color
	vec3 base = edge_color.rgb * tex_color.rgb;
	
	// Apply bevel lighting
	base = mix(base, highlight_color.rgb * tex_color.rgb, highlight * 0.7);
	base = mix(base, shadow_color.rgb * tex_color.rgb, shadow * 0.5);
	
	COLOR = vec4(base, tex_color.a);
}
