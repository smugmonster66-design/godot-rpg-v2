shader_type canvas_item;

// Endpoint masking
uniform float line_length = 100.0;
uniform float mask_start = 64.0;
uniform float mask_end = 64.0;
uniform float fade_width : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	float dist_from_start = UV.x * line_length;
	float dist_from_end = (1.0 - UV.x) * line_length;

	float start_mask = smoothstep(mask_start - fade_width, mask_start, dist_from_start);
	float end_mask = smoothstep(mask_end - fade_width, mask_end, dist_from_end);

	// COLOR comes from vertex color (Line2D default_color)
	COLOR.a *= start_mask * end_mask;
}
