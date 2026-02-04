shader_type canvas_item;

// Wave distortion settings
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 20.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.0;

// Water tint settings
uniform vec4 tint_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.015;

// Sine wave distortion (makes the texture wavy)
uniform float sine_amplitude : hint_range(0.0, 0.1) = 0.03;
uniform float sine_frequency : hint_range(0.0, 30.0) = 10.0;
uniform float sine_speed : hint_range(0.0, 10.0) = 2.0;
uniform bool sine_horizontal = true;
uniform bool sine_vertical = false;

void fragment() {
	vec2 uv = UV;
	float time = TIME * wave_speed;
	
	// Sine wave distortion - makes the texture itself wavy
	float sine_time = TIME * sine_speed;
	if (sine_horizontal) {
		// Horizontal waves: offset X based on Y position
		uv.x += sin(uv.y * sine_frequency + sine_time) * sine_amplitude;
	}
	if (sine_vertical) {
		// Vertical waves: offset Y based on X position
		uv.y += sin(uv.x * sine_frequency + sine_time * 0.8) * sine_amplitude;
	}
	
	// Water ripple distortion
	float wave_x = sin(uv.y * wave_frequency + time) * wave_amplitude;
	float wave_y = cos(uv.x * wave_frequency + time * 0.8) * wave_amplitude;
	
	// Secondary smaller ripples
	float ripple = sin(uv.x * wave_frequency * 2.0 + time * 1.5) * distortion_strength;
	ripple += cos(uv.y * wave_frequency * 2.0 + time * 1.2) * distortion_strength;
	
	// Apply all distortions
	vec2 distorted_uv = uv + vec2(wave_x + ripple, wave_y + ripple * 0.5);
	
	// Clamp UV to prevent sampling outside texture
	distorted_uv = clamp(distorted_uv, 0.0, 1.0);
	
	// Sample texture with distorted UVs
	vec4 tex_color = texture(TEXTURE, distorted_uv);
	
	// Apply water tint
	vec3 tinted = mix(tex_color.rgb, tint_color.rgb, tint_strength);
	
	// Add subtle shimmer
	float shimmer = sin(time * 2.0 + uv.x * 10.0 + uv.y * 10.0) * 0.05 + 0.95;
	tinted *= shimmer;
	
	COLOR = vec4(tinted, tex_color.a);
}