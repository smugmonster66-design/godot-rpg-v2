shader_type canvas_item;

// Atmospheric lighting overlay for the map.
// Rendered on a full-map ColorRect. Outputs a tinted semi-transparent color
// that darkens the map, with circular light cutouts and vignette.

uniform vec4 ambient_color : source_color = vec4(0.15, 0.1, 0.2, 0.6);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.4;

// Up to 8 point lights (mobile-friendly uniform count).
// Positions and radii are in UV space (0..1 relative to the overlay rect).
uniform int light_count : hint_range(0, 8) = 0;
uniform vec2 light_positions[8];
uniform vec3 light_colors[8];      // RGB only
uniform float light_energies[8];
uniform float light_radii[8];

void fragment() {
	float darkness = ambient_color.a;
	vec3 tint = ambient_color.rgb;

	// Subtract each light's contribution from the darkness
	for (int i = 0; i < 8; i++) {
		if (i >= light_count) break;
		float dist = distance(UV, light_positions[i]);
		float falloff = 1.0 - smoothstep(0.0, light_radii[i], dist);
		float contribution = falloff * light_energies[i];
		darkness -= contribution;
		// Blend light color into the tint where the light reaches
		tint = mix(tint, light_colors[i], falloff * contribution * 0.5);
	}

	// Screen-edge vignette
	float vignette_dist = distance(UV, vec2(0.5));
	darkness += smoothstep(vignette_softness, vignette_softness + vignette_strength, vignette_dist);

	darkness = clamp(darkness, 0.0, 1.0);
	COLOR = vec4(tint, darkness);
}
