// res://shaders/status_icon.gdshader
// Applies a flat tint color to a white-on-transparent status icon,
// plus a crisp black outline that grows outward from the icon edge.
//
// Usage:
//   - Attach as ShaderMaterial to the icon's TextureRect
//   - Set tint_color per-icon to ThemeManager.get_status_color(status_id)
//   - outline_width of 1.5 recommended for 48×48 icons; scale up for larger

shader_type canvas_item;

/// The color to tint the white icon pixels. Set this per-instance at runtime.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

/// How many pixels outward to extend the black outline.
/// 1.5 = single-pixel border. 2.0–3.0 for larger icons.
uniform float outline_width : hint_range(0.5, 4.0, 0.5) = 1.5;

/// Outline color — black by default. Override if you need a different edge color.
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

/// Alpha threshold — pixels below this are treated as transparent.
/// Raise slightly (e.g. 0.1) if your icons have anti-aliased edges with
/// partial alpha that bleeds into the outline zone.
uniform float alpha_threshold : hint_range(0.0, 0.5, 0.01) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a > alpha_threshold) {
		// ── Icon pixel ──
		// Source icons are white-on-transparent, so tex.rgb ≈ (1,1,1).
		// Multiplying by tint_color.rgb replaces white with the status color.
		// Preserve the icon's own alpha (handles soft anti-aliased edges).
		COLOR = vec4(tint_color.rgb * tex.rgb, tex.a * tint_color.a);
	} else {
		// ── Empty pixel — check for nearby icon pixels to draw outline ──
		float max_neighbor_alpha = 0.0;
		vec2 ps = TEXTURE_PIXEL_SIZE;

		// Sample a square kernel of radius outline_width around this pixel.
		// No distance rejection — every pixel in the box is checked so the
		// outline hugs the exact shape silhouette including sharp corners.
		float r = ceil(outline_width);
		for (float dx = -r; dx <= r; dx += 1.0) {
			for (float dy = -r; dy <= r; dy += 1.0) {
				if (dx == 0.0 && dy == 0.0) { continue; }
				float neighbor_a = texture(TEXTURE, UV + vec2(dx, dy) * ps).a;
				max_neighbor_alpha = max(max_neighbor_alpha, neighbor_a);
			}
		}

		if (max_neighbor_alpha > alpha_threshold) {
			// This transparent pixel is adjacent to the icon — draw the outline.
			COLOR = vec4(outline_color.rgb, outline_color.a);
		} else {
			// Fully empty — stay transparent.
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
}
