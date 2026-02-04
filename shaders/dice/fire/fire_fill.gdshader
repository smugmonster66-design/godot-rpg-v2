shader_type canvas_item;

// Fire element - flickering flames with heat distortion
uniform vec4 fire_core : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 fire_mid : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 fire_edge : source_color = vec4(0.8, 0.2, 0.05, 1.0);
uniform float flame_speed : hint_range(0.5, 3.0) = 1.5;
uniform float flame_intensity : hint_range(0.0, 1.0) = 0.8;

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
	
	// Animated flame turbulence
	vec2 flame_uv = UV;
	flame_uv.y -= TIME * flame_speed * 0.3;
	
	float flame1 = noise(flame_uv * 6.0);
	float flame2 = noise(flame_uv * 12.0 + vec2(TIME * 0.5, 0.0));
	float flame3 = noise(flame_uv * 24.0 - vec2(0.0, TIME * 0.8));
	
	float flame = flame1 * 0.5 + flame2 * 0.3 + flame3 * 0.2;
	
	// Flame rises from bottom
	float rise = 1.0 - UV.y;
	flame *= rise * 0.5 + 0.5;
	
	// Color gradient based on flame intensity
	vec3 color;
	if (flame > 0.6) {
		color = mix(fire_mid.rgb, fire_core.rgb, (flame - 0.6) / 0.4);
	} else if (flame > 0.3) {
		color = mix(fire_edge.rgb, fire_mid.rgb, (flame - 0.3) / 0.3);
	} else {
		color = fire_edge.rgb * (flame / 0.3 * 0.5 + 0.5);
	}
	
	// Apply intensity
	color = mix(tex_color.rgb * vec3(0.8, 0.4, 0.2), color, flame_intensity);
	
	// Hot core glow
	float core_dist = length(UV - vec2(0.5, 0.6));
	float core_glow = smoothstep(0.4, 0.1, core_dist) * 0.3;
	color += fire_core.rgb * core_glow;
	
	COLOR = vec4(color, tex_color.a);
}
