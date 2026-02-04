shader_type canvas_item;

// Fire element stroke - burning ember edges with animated glow
uniform vec4 ember_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform vec4 ash_color : source_color = vec4(0.3, 0.15, 0.1, 1.0);
uniform float pulse_speed : hint_range(0.5, 3.0) = 2.0;
uniform float ember_intensity : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Ember pulse - different points glow at different times
	float ember_noise = noise(UV * 8.0);
	float pulse = sin(TIME * pulse_speed + ember_noise * 6.28) * 0.5 + 0.5;
	
	// Crawling heat pattern
	float heat = noise(UV * 15.0 + vec2(TIME * 0.3, -TIME * 0.2));
	
	// Mix ash and ember based on heat and pulse
	float glow = heat * pulse * ember_intensity;
	vec3 color = mix(ash_color.rgb, ember_color.rgb, glow);
	
	// Add bright spots
	float bright = smoothstep(0.7, 0.9, heat * pulse);
	color += vec3(1.0, 0.8, 0.4) * bright * 0.5;
	
	COLOR = vec4(color * tex_color.rgb, tex_color.a);
}
