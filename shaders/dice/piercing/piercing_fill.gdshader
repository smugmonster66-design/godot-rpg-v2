shader_type canvas_item;

// Piercing element - polished silver with sharp directional highlights
uniform vec4 silver_base : source_color = vec4(0.85, 0.85, 0.88, 1.0);
uniform vec4 silver_dark : source_color = vec4(0.5, 0.52, 0.55, 1.0);
uniform float sharpness : hint_range(1.0, 10.0) = 5.0;
uniform float gleam_intensity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sharp directional gradient (diagonal from top-left)
	float diagonal = (UV.x + (1.0 - UV.y)) * 0.5;
	
	// Create sharp faceted look with multiple angles
	float facet1 = pow(abs(sin(diagonal * 3.14159 * sharpness)), 4.0);
	float facet2 = pow(abs(sin((UV.x * 2.0 - UV.y) * 3.14159 * sharpness * 0.7)), 4.0);
	float facets = max(facet1, facet2 * 0.6);
	
	// Base silver with gradient
	vec3 base = mix(silver_dark.rgb, silver_base.rgb, diagonal);
	
	// Add sharp faceted highlights
	base += vec3(0.2) * facets * gleam_intensity;
	
	// Point highlight - simulates light catching a sharp tip
	vec2 tip = vec2(0.7, 0.3);
	float point_dist = length(UV - tip);
	float point_gleam = smoothstep(0.15, 0.0, point_dist) * gleam_intensity;
	base += vec3(0.4) * point_gleam;
	
	// Subtle blue-ish reflection (cold metal)
	base += vec3(-0.02, 0.0, 0.03) * (1.0 - diagonal);
	
	COLOR = vec4(base * tex_color.rgb, tex_color.a);
}
