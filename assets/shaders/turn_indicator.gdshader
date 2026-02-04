shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float glow_width : hint_range(1.0, 20.0) = 6.0;
uniform float spin_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform int num_segments : hint_range(1, 8) = 4;
uniform float segment_gap : hint_range(0.0, 0.5) = 0.15;
uniform bool is_circle = false;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.1;

float rounded_box_sdf(vec2 p, vec2 size, float radius) {
	vec2 q = abs(p) - size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float circle_sdf(vec2 p, float radius) {
	return length(p) - radius;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float time = TIME * spin_speed;

	// Calculate distance from edge
	float dist;
	if (is_circle) {
		dist = circle_sdf(uv, 0.85);
	} else {
		dist = rounded_box_sdf(uv, vec2(0.9, 0.9), corner_radius);
	}

	// Create outline band - only visible near the edge
	float edge = 1.0 - smoothstep(0.0, glow_width * 0.01, abs(dist));

	// Calculate angle for spinning segments
	float angle = atan(uv.y, uv.x);
	float normalized_angle = (angle + PI) / TAU;
	float spinning_angle = fract(normalized_angle + time / TAU);

	// Create segments
	float segment_size = 1.0 / float(num_segments);
	float segment_progress = mod(spinning_angle, segment_size) / segment_size;
	float segment_mask = smoothstep(0.0, 0.1, segment_progress) * smoothstep(segment_gap, segment_gap + 0.1, 1.0 - segment_progress);

	// Pulse effect
	float pulse = 1.0 - pulse_intensity + sin(TIME * pulse_speed) * pulse_intensity;

	// Combine for main glow
	float glow = edge * segment_mask * pulse;

	// Add soft outer glow (only outside the shape)
	float outer_glow = max(0.0, 1.0 - smoothstep(0.0, glow_width * 0.03, dist)) * 0.5 * segment_mask * pulse;

	// Final glow amount
	float final_glow = glow + outer_glow;

	// Output - ONLY the glow, transparent everywhere else
	COLOR = vec4(glow_color.rgb, final_glow * glow_color.a);
}