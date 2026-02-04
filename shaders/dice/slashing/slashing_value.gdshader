shader_type canvas_item;

// Slashing Value - Engraved metal text effect
uniform vec4 engrave_color : source_color = vec4(0.25, 0.27, 0.3, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.6, 0.62, 0.65, 1.0);
uniform float depth : hint_range(0.0, 1.0) = 0.6;
uniform vec2 light_direction = vec2(-0.5, -0.7);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sample neighboring pixels for edge detection
	vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
	
	float left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a;
	float right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;
	float top = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a;
	float bottom = texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
	
	// Calculate edge normals
	float dx = right - left;
	float dy = bottom - top;
	
	// Dot product with light direction for bevel effect
	vec2 normal = normalize(vec2(dx, dy) + 0.001);
	vec2 light_dir = normalize(light_direction);
	float bevel = dot(normal, light_dir) * depth;
	
	// Shadow on top-left edges, highlight on bottom-right
	float shadow_amount = max(0.0, -bevel);
	float highlight_amount = max(0.0, bevel);
	
	// Base engraved color
	vec3 final_rgb = engrave_color.rgb;
	
	// Apply shadow and highlight
	final_rgb = mix(final_rgb, shadow_color.rgb, shadow_amount * 0.7);
	final_rgb = mix(final_rgb, highlight_color.rgb, highlight_amount * 0.4);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
