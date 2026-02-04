shader_type canvas_item;

// Piercing element value - crisp silver text with metallic sheen
uniform vec4 text_color : source_color = vec4(0.9, 0.9, 0.95, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.4, 0.42, 0.45, 1.0);
uniform float sheen_intensity : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;
	
	float center = texture(TEXTURE, UV).a;
	
	// Sharp inset shadow (very slight)
	float shadow_sample = texture(TEXTURE, UV + pixel * vec2(0.5, 0.5)).a;
	float inset = max(0.0, center - shadow_sample) * 0.3;
	
	// Diagonal metallic sheen
	float sheen = smoothstep(0.2, 0.8, UV.x + (1.0 - UV.y) * 0.5);
	sheen = pow(sheen, 2.0) * sheen_intensity;
	
	// Base color with sheen
	vec3 base = mix(shadow_color.rgb, text_color.rgb, 0.7 + sheen * 0.3);
	base += vec3(0.15) * sheen;
	base -= vec3(0.1) * inset;
	
	COLOR = vec4(base, center);
}
