// portrait_frame_glow.gdshader - Animated rarity glow for portrait frame
// Apply to FrontPanel's ShaderMaterial
// The frame texture itself glows with the rarity color
shader_type canvas_item;

// Rarity color (set from RarityColors resource)
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 0.0 = no glow (common/no items), 1.0 = maximum glow
// Scale this based on (count_of_highest_rarity / total_slots)
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;

// How strongly the rarity color tints the frame (vs original frame color)
uniform float color_strength : hint_range(0.0, 1.0) = 0.6;

// Additive bloom on top of tint
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.8;

// Pulse animation
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.2;

// Secondary slower shimmer wave for visual richness
uniform float shimmer_speed : hint_range(0.0, 3.0) = 0.4;
uniform float shimmer_amount : hint_range(0.0, 0.3) = 0.1;

// Outer glow radius (bleeds outward from frame edges)
uniform float outer_glow_size : hint_range(0.0, 8.0) = 3.0;
uniform float outer_glow_strength : hint_range(0.0, 1.5) = 0.5;

void fragment() {
	vec4 frame = texture(TEXTURE, UV);

	// No glow at zero intensity - render frame normally
	if (glow_intensity <= 0.001) {
		COLOR = frame;
		return;
	}

	// Dual-wave pulse for organic feel
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float shimmer = 1.0 + sin(TIME * shimmer_speed + UV.x * 3.14 + UV.y * 2.0) * shimmer_amount;
	float anim = pulse * shimmer;

	// Effective intensity with animation
	float eff = glow_intensity * anim;

	// Tint the frame toward rarity color
	vec3 tinted = mix(frame.rgb, glow_color.rgb * frame.rgb, color_strength * eff);

	// Add bloom (additive light on bright areas of the frame)
	float frame_brightness = dot(frame.rgb, vec3(0.299, 0.587, 0.114));
	vec3 bloom = glow_color.rgb * bloom_strength * eff * frame_brightness;
	tinted += bloom;

	// Outer glow: sample neighbors for alpha to create bleed effect
	float outer = 0.0;
	if (outer_glow_size > 0.0 && frame.a < 0.5) {
		vec2 tex_size = vec2(textureSize(TEXTURE, 0));
		vec2 pixel = 1.0 / tex_size;

		for (float x = -outer_glow_size; x <= outer_glow_size; x += 1.0) {
			for (float y = -outer_glow_size; y <= outer_glow_size; y += 1.0) {
				float dist = length(vec2(x, y));
				if (dist > outer_glow_size) continue;

				vec2 sample_uv = UV + vec2(x, y) * pixel;
				if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) continue;

				float neighbor_alpha = texture(TEXTURE, sample_uv).a;
				float falloff = 1.0 - (dist / outer_glow_size);
				outer = max(outer, neighbor_alpha * falloff * falloff);
			}
		}
		outer *= outer_glow_strength * eff;
	}

	// Final composite
	// Frame pixels: tinted + bloom
	// Transparent pixels near frame: outer glow
	vec3 final_color = mix(glow_color.rgb * outer, tinted, frame.a);
	float final_alpha = max(frame.a, outer * glow_color.a);

	COLOR = vec4(final_color, final_alpha);
}
