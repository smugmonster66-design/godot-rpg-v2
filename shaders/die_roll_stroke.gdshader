shader_type canvas_item;
// =============================================================================
// DIE ROLL — STROKE LAYER
// =============================================================================
// Pseudo-3D rolling effect for die stroke textures.
// Modulates stroke thickness/opacity based on which edges face toward/away
// from the virtual camera during a tilt.
//
// THREE MODES:
//   PNG mode (default) — works with current rasterized strokes.
//   SDF mode (use_sdf = true) — single-channel signed distance field.
//   MSDF mode (use_msdf = true) — 3-channel MSDF from msdfgen.
//
// USAGE:
//   Assign to stroke_texture.material on DieObjectBase.
//   Keep rotation_angle in sync with the fill shader (same include).
// =============================================================================

#include "res://shaders/includes/roll_warp.gdshaderinc"

// ---------------------------------------------------------------------------
// STROKE APPEARANCE
// ---------------------------------------------------------------------------
group_uniforms stroke;
uniform vec4 stroke_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float thickness_modulation : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_modulation : hint_range(0.0, 1.0) = 0.3;

// ---------------------------------------------------------------------------
// SDF / MSDF SETTINGS
// ---------------------------------------------------------------------------
group_uniforms sdf;
uniform bool use_sdf = false;
uniform bool use_msdf = false;
uniform float sdf_base_width : hint_range(0.002, 0.08) = 0.025;
uniform float sdf_threshold : hint_range(0.3, 0.7) = 0.5;

// ---------------------------------------------------------------------------
// EDGE GLOW
// ---------------------------------------------------------------------------
group_uniforms edge_glow;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float glow_width : hint_range(0.0, 0.1) = 0.03;

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------
float msdf_median(vec3 s) {
	return max(min(s.r, s.g), min(max(s.r, s.g), s.b));
}

float compute_facing(vec2 warped_uv, vec2 rot) {
	vec2 center = warped_uv - 0.5;
	float center_len = length(center);
	if (center_len < 0.001) {
		return 0.0;
	}
	vec2 rot_dir = vec2(sin(rot.y), sin(rot.x));
	float rot_len = length(rot_dir);
	if (rot_len < 0.001) {
		return 0.0;
	}
	return dot(center / center_len, rot_dir / rot_len);
}

// ---------------------------------------------------------------------------
// FRAGMENT
// ---------------------------------------------------------------------------
void fragment() {
	vec2 warped_uv = apply_roll_warp(UV);

	bool out_of_bounds = (warped_uv.x < 0.0 || warped_uv.x > 1.0 ||
	                      warped_uv.y < 0.0 || warped_uv.y > 1.0);

	if (out_of_bounds) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);

	} else if (use_msdf) {
		// =================================================================
		// MSDF MODE
		// =================================================================
		float facing = compute_facing(warped_uv, rotation_angle);
		float facing_01 = facing * 0.5 + 0.5;

		vec3 sdf_sample = texture(TEXTURE, warped_uv).rgb;
		float dist = msdf_median(sdf_sample);

		float width = sdf_base_width * mix(1.0 - thickness_modulation,
		                                    1.0 + thickness_modulation,
		                                    facing_01);
		float edge_dist = abs(dist - sdf_threshold);
		float aa = fwidth(dist);
		float stroke_alpha = 1.0 - smoothstep(width - aa, width + aa, edge_dist);

		float alpha_factor = mix(1.0 - alpha_modulation, 1.0, facing_01);
		stroke_alpha *= alpha_factor;

		float glow_alpha = 0.0;
		if (glow_intensity > 0.0) {
			float glow_dist = width + glow_width;
			glow_alpha = (1.0 - smoothstep(width, glow_dist, edge_dist));
			glow_alpha *= glow_intensity * facing_01;
		}

		vec4 stroke_out = vec4(stroke_color.rgb, stroke_alpha * stroke_color.a);
		vec4 glow_out = vec4(glow_color.rgb, glow_alpha * glow_color.a);
		vec3 combined_rgb = mix(glow_out.rgb, stroke_out.rgb, stroke_out.a);
		float combined_a = stroke_out.a + glow_out.a * (1.0 - stroke_out.a);

		COLOR = vec4(combined_rgb, combined_a);

	} else if (use_sdf) {
		// =================================================================
		// SINGLE-CHANNEL SDF MODE
		// =================================================================
		float facing = compute_facing(warped_uv, rotation_angle);
		float facing_01 = facing * 0.5 + 0.5;

		float dist = texture(TEXTURE, warped_uv).r;

		float width = sdf_base_width * mix(1.0 - thickness_modulation,
		                                    1.0 + thickness_modulation,
		                                    facing_01);
		float edge_dist = abs(dist - sdf_threshold);
		float aa = fwidth(dist);
		float stroke_alpha = 1.0 - smoothstep(width - aa, width + aa, edge_dist);

		float alpha_factor = mix(1.0 - alpha_modulation, 1.0, facing_01);
		stroke_alpha *= alpha_factor;

		float glow_alpha = 0.0;
		if (glow_intensity > 0.0) {
			float glow_dist = width + glow_width;
			glow_alpha = (1.0 - smoothstep(width, glow_dist, edge_dist));
			glow_alpha *= glow_intensity * facing_01;
		}

		vec4 stroke_out = vec4(stroke_color.rgb, stroke_alpha * stroke_color.a);
		vec4 glow_out = vec4(glow_color.rgb, glow_alpha * glow_color.a);
		vec3 combined_rgb = mix(glow_out.rgb, stroke_out.rgb, stroke_out.a);
		float combined_a = stroke_out.a + glow_out.a * (1.0 - stroke_out.a);

		COLOR = vec4(combined_rgb, combined_a);

	} else {
		// =================================================================
		// PNG MODE (default — works with current rasterized strokes)
		// =================================================================
		vec4 tex = texture(TEXTURE, warped_uv);

		if (tex.a < 0.01) {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		} else {
			float facing = compute_facing(warped_uv, rotation_angle);
			float facing_01 = facing * 0.5 + 0.5;

			float base_alpha = tex.a;

			// Neighbor spread for approaching edges (dilation approximation)
			float spread_amount = thickness_modulation * 0.5 * max(facing, 0.0);
			if (spread_amount > 0.01) {
				vec2 texel = TEXTURE_PIXEL_SIZE;
				float neighbor_max = base_alpha;
				neighbor_max = max(neighbor_max, texture(TEXTURE, warped_uv + vec2(-texel.x, 0.0)).a);
				neighbor_max = max(neighbor_max, texture(TEXTURE, warped_uv + vec2( texel.x, 0.0)).a);
				neighbor_max = max(neighbor_max, texture(TEXTURE, warped_uv + vec2(0.0, -texel.y)).a);
				neighbor_max = max(neighbor_max, texture(TEXTURE, warped_uv + vec2(0.0,  texel.y)).a);
				base_alpha = mix(base_alpha, neighbor_max, spread_amount);
			}

			// Alpha modulation — receding fades, approaching strengthens
			float alpha_factor = mix(1.0 - alpha_modulation, 1.0 + alpha_modulation * 0.3, facing_01);
			float final_alpha = clamp(base_alpha * alpha_factor, 0.0, 1.0);

			vec3 out_color = mix(tex.rgb, stroke_color.rgb, stroke_color.a);

			// Edge glow on approaching edges
			if (glow_intensity > 0.0 && facing > 0.0) {
				float glow_factor = facing * glow_intensity * base_alpha;
				out_color = mix(out_color, glow_color.rgb, glow_factor);
			}

			COLOR = vec4(out_color, final_alpha * stroke_color.a);
		}
	}
}
