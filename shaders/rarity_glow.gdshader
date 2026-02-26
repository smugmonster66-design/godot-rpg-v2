// res://shaders/rarity_glow.gdshader
// Sprite-outline glow shader for rarity aura.
// Applied to a padded TextureRect behind the target. Uses a source_texture
// uniform (the actual sprite) with UV remapping so the glow hugs the sprite
// edges and radiates outward into the padding area.
shader_type canvas_item;

uniform sampler2D source_texture : filter_linear;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float glow_radius : hint_range(1.0, 40.0) = 10.0;
uniform float glow_softness : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

// Sizing uniforms — set by RarityGlowHelper
uniform vec2 source_size;   // pixel size of the target (sprite area)
uniform vec2 rect_size;     // pixel size of this glow rect (target + padding)

void fragment() {
	// --- Remap UVs: glow rect space → source texture space ---
	vec2 padding_uv = (rect_size - source_size) / (2.0 * rect_size);
	vec2 inner_scale = source_size / rect_size;
	vec2 source_uv = (UV - padding_uv) / inner_scale;

	// Is this pixel inside the source sprite bounds?
	bool in_source = source_uv.x >= 0.0 && source_uv.x <= 1.0
	              && source_uv.y >= 0.0 && source_uv.y <= 1.0;

	// Sample source alpha at current position
	float current_alpha = 0.0;
	if (in_source) {
		current_alpha = texture(source_texture, source_uv).a;
	}

	float final_alpha = 0.0;

	// Only compute glow on transparent pixels
	if (current_alpha <= 0.1) {
		// Work in pixel units relative to the glow rect
		vec2 pixel = 1.0 / rect_size;

		// Adaptive step size
		float step_size = 1.0;
		if (glow_radius > 30.0) {
			step_size = 3.0;
		} else if (glow_radius > 15.0) {
			step_size = 2.0;
		}

		float min_dist = glow_radius + 1.0;

		for (float x = -glow_radius; x <= glow_radius; x += step_size) {
			for (float y = -glow_radius; y <= glow_radius; y += step_size) {
				float dist = length(vec2(x, y));
				if (dist <= glow_radius && dist < min_dist) {
					// Offset in glow rect UV, then remap to source UV
					vec2 sample_glow_uv = UV + vec2(x, y) * pixel;
					vec2 sample_src_uv = (sample_glow_uv - padding_uv) / inner_scale;

					if (sample_src_uv.x >= 0.0 && sample_src_uv.x <= 1.0
					 && sample_src_uv.y >= 0.0 && sample_src_uv.y <= 1.0) {
						if (texture(source_texture, sample_src_uv).a > 0.5) {
							min_dist = dist;
						}
					}
				}
			}
		}

		if (min_dist <= glow_radius) {
			float glow = 1.0 - pow(min_dist / glow_radius, glow_softness);
			float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
			glow *= pulse;
			final_alpha = glow * glow_alpha;
		}
	}

	COLOR = vec4(glow_color.rgb, final_alpha);
}
