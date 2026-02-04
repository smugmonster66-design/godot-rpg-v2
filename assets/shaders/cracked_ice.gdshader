shader_type canvas_item;

// Ice color settings
uniform vec4 ice_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.3;
uniform float glow_pulse_speed : hint_range(0.0, 5.0) = 1.5;

// Crack settings
uniform float crack_scale : hint_range(1.0, 20.0) = 8.0;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float crack_sharpness : hint_range(1.0, 10.0) = 4.0;
uniform vec4 crack_color : source_color = vec4(0.2, 0.4, 0.6, 1.0);

// Shimmer settings
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.15;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 2.0;

// Random function
vec2 random2(vec2 p) {
	return fract(sin(vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	)) * 43758.5453);
}

// Voronoi pattern for cracks
float voronoi(vec2 uv) {
	vec2 i_st = floor(uv);
	vec2 f_st = fract(uv);
	
	float min_dist = 1.0;
	float second_min_dist = 1.0;
	
	// Check neighboring cells
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = random2(i_st + neighbor);
			vec2 diff = neighbor + point - f_st;
			float dist = length(diff);
			
			if (dist < min_dist) {
				second_min_dist = min_dist;
				min_dist = dist;
			} else if (dist < second_min_dist) {
				second_min_dist = dist;
			}
		}
	}
	
	// Edge detection - difference between closest and second closest
	return second_min_dist - min_dist;
}

// Multi-layered cracks
float cracks(vec2 uv, float scale) {
	float crack1 = voronoi(uv * scale);
	float crack2 = voronoi(uv * scale * 1.7 + vec2(5.3, 3.7));
	float crack3 = voronoi(uv * scale * 0.5 + vec2(2.1, 8.4));
	
	// Combine layers with different weights
	float combined = crack1 * 0.5 + crack2 * 0.35 + crack3 * 0.15;
	
	// Sharpen the cracks
	return pow(combined, 1.0 / crack_sharpness);
}

void fragment() {
	vec2 uv = UV;
	
	// Sample original texture
	vec4 tex_color = texture(TEXTURE, uv);
	
	// Generate crack pattern
	float crack_pattern = cracks(uv, crack_scale);
	
	// Create sharp crack lines (lower values = crack lines)
	float crack_lines = smoothstep(0.0, 0.15, crack_pattern);
	
	// Ice base with texture
	vec3 ice_base = mix(tex_color.rgb, ice_color.rgb, 0.4);
	
	// Add cracks - darken along crack lines
	vec3 cracked = mix(crack_color.rgb, ice_base, crack_lines);
	cracked = mix(ice_base, cracked, crack_intensity);
	
	// Animated glow pulse
	float pulse = sin(TIME * glow_pulse_speed) * 0.5 + 0.5;
	float glow = glow_strength * (0.7 + 0.3 * pulse);
	
	// Apply glow - stronger in non-crack areas
	vec3 glowing = cracked + glow_color.rgb * glow * crack_lines;
	
	// Shimmer effect - subtle sparkles
	float shimmer_time = TIME * shimmer_speed;
	float shimmer = sin(uv.x * 30.0 + shimmer_time) * sin(uv.y * 30.0 - shimmer_time * 0.7);
	shimmer = max(0.0, shimmer) * shimmer_strength * crack_lines;
	glowing += vec3(shimmer);
	
	// Fresnel-like edge glow (brighter at edges)
	vec2 center_dist = abs(uv - vec2(0.5));
	float edge_glow = max(center_dist.x, center_dist.y) * 2.0;
	edge_glow = pow(edge_glow, 2.0) * glow * 0.5;
	glowing += glow_color.rgb * edge_glow;
	
	COLOR = vec4(glowing, tex_color.a);
}
