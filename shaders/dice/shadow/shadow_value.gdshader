shader_type canvas_item;

// Shadow element value - ghostly fading text
uniform vec4 text_color : source_color = vec4(0.5, 0.35, 0.6, 1.0);
uniform vec4 ghost_color : source_color = vec4(0.3, 0.2, 0.4, 1.0);
uniform float fade_speed : hint_range(0.3, 1.5) = 0.7;
uniform float ghostly : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	
	// Ghostly fade in/out
	float fade = sin(TIME * fade_speed) * 0.5 + 0.5;
	fade = 0.6 + fade * 0.4;  // Never fully fade
	
	// Slight position jitter (unsettling)
	vec2 jitter_uv = UV;
	jitter_uv.x += sin(TIME * 3.0 + UV.y * 10.0) * ghostly * 0.01;
	
	// Sample with jitter
	float jittered_alpha = texture(TEXTURE, jitter_uv).a;
	alpha = mix(alpha, jittered_alpha, ghostly * 0.5);
	
	// Color
	vec3 color = mix(ghost_color.rgb, text_color.rgb, fade);
	
	// Ethereal glow
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.5 / tex_size;
	float glow = 0.0;
	glow += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a;
	glow += texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a;
	glow += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a;
	glow += texture(TEXTURE, UV - vec2(0.0, pixel.y)).a;
	glow = clamp(glow - alpha * 4.0, 0.0, 1.0);
	
	color += text_color.rgb * glow * 0.3 * fade;
	
	COLOR = vec4(color, alpha * fade);
}
