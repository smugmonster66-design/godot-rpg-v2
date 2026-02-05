shader_type canvas_item;

// Cartoon Smooth - Gaussian blur to round out pixel edges
// Use WITH texture_filter = Linear on the node for best results

// Blur radius in pixels (0.0 = off, 1.0 = subtle, 2.0+ = very smooth)
uniform float blur_radius : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 offset = ps * blur_radius;

	// 9-tap Gaussian kernel (approximation)
	// Weights: center = 4, edges = 2, corners = 1, total = 16
	vec4 color = texture(TEXTURE, UV) * 4.0;

	color += texture(TEXTURE, UV + vec2(-offset.x, 0.0)) * 2.0;
	color += texture(TEXTURE, UV + vec2( offset.x, 0.0)) * 2.0;
	color += texture(TEXTURE, UV + vec2(0.0, -offset.y)) * 2.0;
	color += texture(TEXTURE, UV + vec2(0.0,  offset.y)) * 2.0;

	color += texture(TEXTURE, UV + vec2(-offset.x, -offset.y));
	color += texture(TEXTURE, UV + vec2( offset.x, -offset.y));
	color += texture(TEXTURE, UV + vec2(-offset.x,  offset.y));
	color += texture(TEXTURE, UV + vec2( offset.x,  offset.y));

	COLOR = color / 16.0;
}
