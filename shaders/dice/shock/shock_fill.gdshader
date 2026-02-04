shader_type canvas_item;

// Shock element - electric field with crackling energy
uniform vec4 electric_core : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform vec4 electric_mid : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform vec4 electric_edge : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform float crackle_speed : hint_range(1.0, 5.0) = 3.0;
uniform float energy_intensity : hint_range(0.0, 1.0) = 0.8;

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
	
	// Fast-changing electric noise
	float time_offset = floor(TIME * crackle_speed) * 0.1;
	float electric1 = noise(UV * 8.0 + vec2(time_offset, 0.0));
	float electric2 = noise(UV * 16.0 + vec2(0.0, time_offset * 1.3));
	
	// Lightning bolt pattern (sharp threshold)
	float bolt = noise(UV * 4.0 + vec2(time_offset * 2.0, time_offset));
	bolt = smoothstep(0.6, 0.65, bolt);
	
	// Energy field base
	float energy = electric1 * 0.6 + electric2 * 0.4;
	
	// Color based on energy intensity
	vec3 color = mix(electric_edge.rgb, electric_mid.rgb, energy);
	color = mix(color, electric_core.rgb, bolt);
	
	// Pulsing core
	float pulse = sin(TIME * crackle_speed * 2.0) * 0.3 + 0.7;
	float core_dist = length(UV - vec2(0.5));
	float core = smoothstep(0.4, 0.1, core_dist) * pulse;
	color = mix(color, electric_core.rgb, core * 0.5);
	
	// Apply intensity
	color = mix(tex_color.rgb * electric_mid.rgb, color, energy_intensity);
	
	COLOR = vec4(color, tex_color.a);
}
