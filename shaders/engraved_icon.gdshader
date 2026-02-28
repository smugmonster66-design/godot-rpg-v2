shader_type canvas_item;

uniform sampler2D surface_texture : filter_linear;

uniform float engrave_depth : hint_range(0.5, 4.0) = 1.5;
uniform float bevel_softness : hint_range(0.0, 1.0) = 0.4;
uniform float edge_strength : hint_range(0.1, 1.0) = 0.55;
uniform float recess_darkness : hint_range(0.6, 1.0) = 0.85;
uniform float recess_tint_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 recess_tint : source_color = vec4(0.05, 0.03, 0.01, 1.0);
uniform vec2 light_angle = vec2(1.0, -1.0);

// // Rank fill
uniform float fill_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fill_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D fill_texture : filter_linear;
uniform bool has_fill_texture = false;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 light_dir = normalize(light_angle);

	float icon_alpha = texture(TEXTURE, UV).a;

	// Inner bevel
	float inner_offset = engrave_depth;
	float inner_shadow = texture(TEXTURE, UV - light_dir * ps * inner_offset).a;
	float inner_highlight = texture(TEXTURE, UV + light_dir * ps * inner_offset).a;
	float inner_edge = inner_highlight - inner_shadow;

	// Outer bevel
	float outer_offset = engrave_depth * 2.0;
	float outer_shadow = texture(TEXTURE, UV - light_dir * ps * outer_offset).a;
	float outer_highlight = texture(TEXTURE, UV + light_dir * ps * outer_offset).a;
	float outer_edge = outer_highlight - outer_shadow;

	float edge = inner_edge * edge_strength + outer_edge * edge_strength * bevel_softness * 0.5;

	// Surface texture bleed
	vec3 surface = texture(surface_texture, UV).rgb;
	vec3 recessed_surface = surface * recess_darkness;
	recessed_surface = mix(recessed_surface, recess_tint.rgb, recess_tint_strength);

	vec3 result = mix(surface, recessed_surface, icon_alpha);
	result += vec3(edge);

	// Rank fill: sweep bottom-to-top within the carved area
    float fill_mask = step(1.0 - fill_progress, UV.y) * icon_alpha;
    float fill_edge = smoothstep(1.0 - fill_progress - 0.05, 1.0 - fill_progress, UV.y) * icon_alpha;

    vec3 fill_sample = fill_color.rgb;
    if (has_fill_texture) {
        fill_sample = texture(fill_texture, UV).rgb;
    }
    result = mix(result, fill_sample, fill_mask * fill_intensity);
    result += vec3(fill_edge * fill_intensity * 0.3);

	result = clamp(result, 0.0, 1.0);

	// Transparency: visible where icon or bevel reaches
	float influence = max(icon_alpha, max(
		max(inner_shadow, inner_highlight),
		max(outer_shadow, outer_highlight)
	));

	COLOR = vec4(result, influence);
}