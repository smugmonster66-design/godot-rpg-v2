shader_type canvas_item;

// Poison element stroke - dripping corroded edges
uniform vec4 corrode_color : source_color = vec4(0.15, 0.35, 0.1, 1.0);
uniform vec4 drip_color : source_color = vec4(0.3, 0.7, 0.15, 1.0);
uniform float drip_speed : hint_range(0.3, 1.5) = 0.7;
uniform float corrode_amount : hint_range(0.0, 1.0) = 0.6;

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
	
	// Dripping effect (flows downward)
	vec2 drip_uv = UV;
	drip_uv.y -= TIME * drip_speed * 0.2;
	float drip = noise(drip_uv * vec2(15.0, 5.0));
	drip = smoothstep(0.5, 0.7, drip) * (1.0 - UV.y);  // More drips at top
	
	// Corrosion pattern
	float corrode = noise(UV * 12.0 + vec2(1.3, 2.7));
	corrode = smoothstep(0.3, 0.6, corrode) * corrode_amount;
	
	// Base corroded color
	vec3 color = corrode_color.rgb;
	
	// Add corrosion variation
	color = mix(color, color * 0.5, corrode);
	
	// Add drips
	color = mix(color, drip_color.rgb, drip);
	
	// Slight glow on drips
	color += drip_color.rgb * drip * 0.3;
	
	COLOR = vec4(color * tex_color.rgb, tex_color.a);
}
