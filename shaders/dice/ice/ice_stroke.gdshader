shader_type canvas_item;

// Ice element stroke - frost-rimmed edges with crystals
uniform vec4 frost_color : source_color = vec4(0.7, 0.85, 0.95, 1.0);
uniform vec4 crystal_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float frost_density : hint_range(0.0, 1.0) = 0.7;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.5;

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
	
	// Jagged frost crystals pattern
	float crystal1 = noise(UV * 20.0);
	float crystal2 = noise(UV * 40.0 + vec2(5.0, 3.0));
	float crystals = max(
		smoothstep(0.6, 0.7, crystal1),
		smoothstep(0.65, 0.75, crystal2) * 0.7
	);
	
	// Frost base
	float frost = noise(UV * 12.0);
	frost = smoothstep(0.3, 0.6, frost) * frost_density;
	
	// Base color
	vec3 color = frost_color.rgb * tex_color.rgb;
	
	// Add frost variation
	color = mix(color, color * 0.8, frost);
	
	// Crystal highlights
	color = mix(color, crystal_color.rgb, crystals * 0.6);
	
	// Sparkle points (slow twinkle)
	float sparkle = noise(UV * 50.0);
	sparkle = step(0.92, sparkle);
	float twinkle = sin(TIME * 2.0 + hash(floor(UV * 50.0)) * 6.28) * 0.5 + 0.5;
	color += crystal_color.rgb * sparkle * twinkle * sparkle_intensity;
	
	COLOR = vec4(color, tex_color.a);
}
