// portrait_mask.gdshader - Masks portrait sprite to fit frame shape
// Apply to PortraitTexture's ShaderMaterial
// Supports swappable mask texture and grayscale for death/KO state
shader_type canvas_item;

// Mask: white = visible, black/transparent = hidden
// Should match the inner cutout of the portrait frame
uniform sampler2D mask_texture : hint_default_white;

// 0.0 = full color, 1.0 = fully grayscale (for death/KO)
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.0;

// Optional desaturation tint when KO'd (dark overlay)
uniform vec4 ko_tint : source_color = vec4(0.15, 0.1, 0.15, 1.0);
uniform float ko_tint_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 portrait = texture(TEXTURE, UV);
	float mask = texture(mask_texture, UV).a;

	// Grayscale conversion using luminance weights
	float luminance = dot(portrait.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(luminance);

	// Blend between color and grayscale
	vec3 color = mix(portrait.rgb, gray, grayscale_amount);

	// Apply KO tint on top of grayscale
	color = mix(color, ko_tint.rgb, grayscale_amount * ko_tint_strength);

	COLOR = vec4(color, portrait.a * mask);
}
