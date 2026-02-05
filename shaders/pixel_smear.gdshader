shader_type canvas_item;

// Pixel Smear - Softens pixel art edges for a cartoony look
// Preserves original colors and alpha, just smooths the boundaries

// How much to smooth (0.0 = crisp pixels, 1.0 = full smear)
uniform float smear_amount : hint_range(0.0, 1.0) = 0.6;
// Spread radius in texels (higher = softer/wider smear)
uniform float spread : hint_range(0.5, 3.0) = 1.0;
// Size of a single frame in pixels (NOT the full atlas)
uniform vec2 sprite_size = vec2(64.0, 64.0);

void fragment() {
	// Use the frame size, not the atlas size
	vec2 tex_size = sprite_size;
	vec2 texel = 1.0 / tex_size;

	// Convert UV to texel-space position
	vec2 pixel_pos = UV * tex_size;

	// Fractional position within the current texel (0-1)
	vec2 f = fract(pixel_pos);

	// Smoothstep the fractional part for soft transitions at edges
	// This is the key trick: instead of hard nearest-neighbor snapping,
	// we ease between neighboring texels at the boundaries
	vec2 smooth_f = smoothstep(0.5 - spread * 0.5, 0.5 + spread * 0.5, f);

	// Blend between original sharp UV and smoothed UV
	vec2 snapped = (floor(pixel_pos) + 0.5) * texel;  // pixel center (nearest)
	vec2 smeared = (floor(pixel_pos) + smooth_f) * texel;  // smoothed position

	// Mix based on smear_amount (0 = original pixel art, 1 = full cartoon smooth)
	vec2 final_uv = mix(snapped, smeared, smear_amount);

	// Sample 4 nearest texels and bilinear blend using our smoothed fraction
	vec2 base = (floor(pixel_pos) + 0.5) * texel;
	vec4 tl = texture(TEXTURE, base);
	vec4 tr = texture(TEXTURE, base + vec2(texel.x, 0.0));
	vec4 bl = texture(TEXTURE, base + vec2(0.0, texel.y));
	vec4 br = texture(TEXTURE, base + texel);

	// Use the smoothed fraction for blending
	vec2 blend_f = mix(vec2(0.5), smooth_f, smear_amount);
	vec4 top = mix(tl, tr, blend_f.x);
	vec4 bottom = mix(bl, br, blend_f.x);
	vec4 smeared_color = mix(top, bottom, blend_f.y);

	// For alpha: use the smeared result so edges soften naturally
	// For color: the bilinear blend already preserves the palette
	// in flat regions (all 4 neighbors are the same color = no change)
	COLOR = smeared_color;
}
