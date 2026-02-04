shader_type canvas_item;

// Ice element - frozen crystalline surface
uniform vec4 ice_deep : source_color = vec4(0.15, 0.3, 0.5, 1.0);
uniform vec4 ice_mid : source_color = vec4(0.4, 0.7, 0.9, 1.0);
uniform vec4 ice_bright : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float crystal_scale : hint_range(1.0, 10.0) = 5.0;
uniform float frost_intensity : hint_range(0.0, 1.0) = 0.8;

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

// Crystalline/faceted pattern
float crystal(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash(i + neighbor) * vec2(0.5) + vec2(0.25);
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Crystalline structure
	float cryst = crystal(UV * crystal_scale);
	float facet = smoothstep(0.0, 0.3, cryst);
	
	// Frost pattern overlay
	float frost1 = noise(UV * 15.0);
	float frost2 = noise(UV * 30.0 + vec2(2.3, 1.7));
	float frost = frost1 * 0.6 + frost2 * 0.4;
	frost = smoothstep(0.3, 0.7, frost);
	
	// Color based on depth and frost
	vec3 color = mix(ice_deep.rgb, ice_mid.rgb, facet);
	color = mix(color, ice_bright.rgb, frost * 0.5);
	
	// Subtle shimmer (very slow)
	float shimmer = sin(TIME * 0.5 + UV.x * 10.0 + UV.y * 8.0) * 0.5 + 0.5;
	shimmer *= smoothstep(0.6, 0.8, frost);
	color += ice_bright.rgb * shimmer * 0.15;
	
	// Apply intensity
	color = mix(tex_color.rgb * ice_mid.rgb * 0.6, color, frost_intensity);
	
	COLOR = vec4(color, tex_color.a);
}
