// rarity_border.gdshader - Outline glow shader for item rarity
shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Size and shape
uniform float glow_radius : hint_range(1.0, 80.0) = 4.0;
uniform float glow_softness : hint_range(0.1, 4.0) = 2.0; // Falloff curve power: higher = sharper edge, lower = softer spread
uniform float glow_width : hint_range(0.0, 1.0) = 0.6; // How far inward the glow reaches (0 = edge only, 1 = full radius)

// Intensity
uniform float glow_strength : hint_range(0.0, 5.0) = 1.5;
uniform float glow_blend : hint_range(0.0, 1.0) = 0.6; // Tint vs additive mix (0 = pure additive, 1 = pure tint)
uniform float glow_saturation : hint_range(0.0, 2.0) = 1.0; // Color intensity of the glow

// Animation
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;

	// Adaptive step size — keeps sample count manageable at large radii
	float step_size = 1.0;
	if (glow_radius > 40.0) {
		step_size = 3.0;
	} else if (glow_radius > 15.0) {
		step_size = 2.0;
	}

	// Find nearest transparent pixel within radius
	float min_dist_to_edge = glow_radius + 1.0;
	bool found_edge = false;

	for (float x = -glow_radius; x <= glow_radius; x += step_size) {
		for (float y = -glow_radius; y <= glow_radius; y += step_size) {
			// ... (keep existing loop body unchanged)
		}
	}

	// Fallback to rect edge distance for fully opaque textures
	if (!found_edge) {
		vec2 edge_dist = min(UV, 1.0 - UV) * tex_size;
		min_dist_to_edge = min(edge_dist.x, edge_dist.y);
		min_dist_to_edge = clamp(min_dist_to_edge, 0.0, glow_radius);
	}

	// Edge factor with configurable width and softness
	float effective_radius = glow_radius * glow_width;
	float edge_factor = 1.0 - clamp(min_dist_to_edge / max(effective_radius, 0.001), 0.0, 1.0);
	edge_factor = pow(edge_factor, 1.0 / glow_softness); // Softness curve

	// Pulse
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float glow = edge_factor * glow_strength * pulse;

	// Apply saturation to glow color
	float luminance = dot(border_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 glow_color = mix(vec3(luminance), border_color.rgb, glow_saturation);

	// Blend: tint vs additive controlled by glow_blend
	vec3 tinted = mix(tex_color.rgb, glow_color, glow * glow_blend);
	vec3 additive = tex_color.rgb + glow_color * glow * (1.0 - glow_blend);
	vec3 final_color = mix(additive, tinted, glow_blend);

	COLOR = vec4(final_color, tex_color.a);
}