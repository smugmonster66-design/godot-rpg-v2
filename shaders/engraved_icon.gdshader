shader_type canvas_item;

uniform float engrave_depth : hint_range(0.5, 4.0) = 1.5;
uniform float bevel_softness : hint_range(0.0, 1.0) = 0.4;
uniform float edge_strength : hint_range(0.1, 1.0) = 0.55;
uniform float base_opacity : hint_range(0.0, 1.0) = 0.75;
uniform vec4 engrave_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 light_angle = vec2(1.0, -1.0);

// Rank fill
uniform float fill_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fill_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D fill_texture : filter_linear;
uniform bool has_fill_texture = false;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Category glow outline
uniform vec4 glow_color : source_color = vec4(0.5, 0.5, 0.8, 1.0);
uniform float glow_radius : hint_range(0.0, 20.0) = 0.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float glow_softness : hint_range(0.5, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.7;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 light_dir = normalize(light_angle);

	float icon_alpha = texture(TEXTURE, UV).a;

	// --- Glow outline on transparent pixels near the icon edge ---
	if (icon_alpha <= 0.1 && glow_radius > 0.0) {
		float min_dist = glow_radius + 1.0;

		for (float x = -20.0; x <= 20.0; x += 1.0) {
			for (float y = -20.0; y <= 20.0; y += 1.0) {
				float dist = length(vec2(x, y));
				if (dist <= glow_radius && dist < min_dist) {
					vec2 sample_uv = UV + vec2(x, y) * ps;
					if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0
					 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
						if (texture(TEXTURE, sample_uv).a > 0.5) {
							min_dist = dist;
						}
					}
				}
			}
		}

		float glow = 0.0;
		if (min_dist <= glow_radius) {
			glow = 1.0 - pow(min_dist / glow_radius, glow_softness);
			float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed) + 1.0) * 0.5);
			glow *= pulse * glow_intensity;
		}

		COLOR = vec4(glow_color.rgb, glow * glow_color.a);
	} else {
		// --- Engraving on opaque icon pixels ---

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

		// Base color with bevel depth shading
		vec3 result = engrave_color.rgb;
		result += vec3(clamp(edge * 0.3, 0.0, 0.15));

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

		// Alpha: fully opaque where icon exists, bevel extends for anti-aliased edges
		float bevel_reach = max(
			max(inner_shadow, inner_highlight),
			max(outer_shadow, outer_highlight)
		);
		float influence = max(icon_alpha, bevel_reach * base_opacity);

		COLOR = vec4(result, influence);
	}
}