shader_type canvas_item;

// Directional drop shadow for map elements. Applied to a CanvasGroup whose
// fit_margin provides extra space around the children for the shadow to render.
// TEXTURE is the pre-rendered children, so no vertex expansion needed.

// Direction light comes FROM (normalized). Shadow is cast in the opposite direction.
uniform vec2 shadow_direction = vec2(-0.707, -0.707);
// Shadow offset distance in rendered-texture pixels.
uniform float shadow_offset_px = 6.0;
// Shadow darkness (0 = invisible, 1 = fully opaque black).
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.4;
// Blur radius in rendered-texture pixels. 0 = hard edge.
uniform float shadow_softness_px : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Shadow sample offset in UV space
	vec2 offset = normalize(-shadow_direction) * TEXTURE_PIXEL_SIZE * shadow_offset_px;

	// Sample shadow alpha (5-tap blur when softness > 0, single tap otherwise)
	float s = 0.0;
	if (shadow_softness_px > 0.1) {
		vec2 blur = TEXTURE_PIXEL_SIZE * shadow_softness_px;
		s += texture(TEXTURE, UV - offset).a;
		s += texture(TEXTURE, UV - offset + vec2(blur.x, 0.0)).a;
		s += texture(TEXTURE, UV - offset - vec2(blur.x, 0.0)).a;
		s += texture(TEXTURE, UV - offset + vec2(0.0, blur.y)).a;
		s += texture(TEXTURE, UV - offset - vec2(0.0, blur.y)).a;
		s *= 0.2;
	} else {
		s = texture(TEXTURE, UV - offset).a;
	}
	s *= shadow_opacity;

	// Alpha-composite: shadow (black) behind sprite
	float out_a = sprite.a + s * (1.0 - sprite.a);
	vec3 out_rgb = (sprite.rgb * sprite.a) / max(out_a, 0.001);
	COLOR = vec4(out_rgb, out_a);
}
