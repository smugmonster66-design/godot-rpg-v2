// res://shaders/selection_indicator.gdshader
// Animated rectangular border with a sweeping highlight that travels the perimeter.
shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 3.0;
uniform float sweep_speed : hint_range(0.0, 3.0) = 0.8;
uniform float sweep_length : hint_range(0.05, 0.5) = 0.15;
uniform float sweep_brightness : hint_range(1.0, 4.0) = 2.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.12;
uniform float corner_radius : hint_range(0.0, 20.0) = 4.0;
uniform vec2 rect_size = vec2(100.0, 100.0);

void fragment() {
	vec2 size_px = rect_size;
	vec2 pos = UV * size_px;

	// Signed distance to rounded rect edge
	vec2 half_size = size_px * 0.5;
	vec2 d = abs(pos - half_size) - (half_size - vec2(corner_radius));
	float dist_outside = length(max(d, 0.0)) - corner_radius;
	float dist_inside = min(max(d.x, d.y), 0.0) - corner_radius;
	float sdf = dist_outside + dist_inside;

		// Border mask: 1.0 on the border ring, 0.0 elsewhere
	float outer = smoothstep(1.0, 0.0, sdf);
	float inner = smoothstep(0.0, -1.0, sdf + border_width);
	float border_mask = outer * (1.0 - inner);


	// Perimeter position (0..1 traveling clockwise from top-left)
	float perimeter = 2.0 * (size_px.x + size_px.y);
	float p = 0.0;

	// Top edge: left to right
	if (pos.y <= border_width && pos.x >= 0.0) {
		p = pos.x;
	}
	// Right edge: top to bottom
	else if (pos.x >= size_px.x - border_width) {
		p = size_px.x + pos.y;
	}
	// Bottom edge: right to left
	else if (pos.y >= size_px.y - border_width) {
		p = size_px.x + size_px.y + (size_px.x - pos.x);
	}
	// Left edge: bottom to top
	else {
		p = 2.0 * size_px.x + size_px.y + (size_px.y - pos.y);
	}

	float norm_p = p / perimeter;

	// Sweep: a bright highlight traveling the perimeter
	float sweep_pos = fract(TIME * sweep_speed);
	float sweep_dist = min(abs(norm_p - sweep_pos), min(abs(norm_p - sweep_pos + 1.0), abs(norm_p - sweep_pos - 1.0)));
	float sweep = smoothstep(sweep_length, 0.0, sweep_dist);

	// Base pulse
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	// Combine
	float brightness = pulse + sweep * (sweep_brightness - 1.0);
	vec3 color = border_color.rgb * brightness;
	float alpha = border_mask * border_color.a * pulse;

	COLOR = vec4(color, alpha);
}
