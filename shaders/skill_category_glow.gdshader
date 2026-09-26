// res://shaders/skill_category_glow.gdshader
// Glow outline that hugs the icon silhouette edges.
// Applied as next_pass on the engraved_icon material so it renders
// on top of the dark engraving. Receives the same TEXTURE (icon alpha).
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.5, 0.5, 0.8, 1.0);
uniform float glow_radius : hint_range(1.0, 10.0) = 4.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float glow_softness : hint_range(0.5, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.7;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float current_alpha = texture(TEXTURE, UV).a;
	float glow = 0.0;

	// Only draw glow on transparent pixels (outside the icon)
	if (current_alpha <= 0.1) {
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float min_dist = glow_radius + 1.0;

		// Fixed loop bounds (max radius = 10), skip pixels beyond actual radius
		for (float x = -10.0; x <= 10.0; x += 1.0) {
			for (float y = -10.0; y <= 10.0; y += 1.0) {
				float dist = length(vec2(x, y));
				if (dist <= glow_radius && dist < min_dist) {
					vec2 sample_uv = UV + vec2(x, y) * pixel;
					if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0
					 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
						if (texture(TEXTURE, sample_uv).a > 0.5) {
							min_dist = dist;
						}
					}
				}
			}
		}

		if (min_dist <= glow_radius) {
			glow = 1.0 - pow(min_dist / glow_radius, glow_softness);

			// Pulsing animation
			float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed) + 1.0) * 0.5);
			glow *= pulse * glow_intensity;
		}
	}

	COLOR = vec4(glow_color.rgb, glow * glow_color.a);
}
