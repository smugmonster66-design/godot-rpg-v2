shader_type canvas_item;

// Siphon affix - parasitic tendrils reaching toward left neighbor
// Toxic green-black base with animated noise tendrils biased leftward
uniform vec4 tendril_color : source_color = vec4(0.3, 0.85, 0.2, 1.0);
uniform vec4 siphon_mid : source_color = vec4(0.1, 0.35, 0.08, 1.0);
uniform vec4 siphon_dark : source_color = vec4(0.03, 0.08, 0.02, 1.0);
uniform float tendril_speed : hint_range(0.3, 2.0) = 0.7;
uniform float tendril_intensity : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for organic tendril shapes
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.2;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Bias UV leftward — tendrils reach toward left edge
	vec2 reach_uv = UV;
	reach_uv.x += TIME * tendril_speed * 0.15; // scroll left over time

	// Primary tendril layer: stretched horizontally for directional feel
	vec2 tendril_uv = vec2(reach_uv.x * 3.0, reach_uv.y * 6.0);
	float tendrils1 = fbm(tendril_uv + vec2(-TIME * tendril_speed * 0.3, 0.0));

	// Secondary layer: finer detail, slightly different scroll
	vec2 fine_uv = vec2(reach_uv.x * 5.0, reach_uv.y * 10.0);
	float tendrils2 = fbm(fine_uv + vec2(-TIME * tendril_speed * 0.5, TIME * 0.1));

	// Combine: sharp tendril edges via smoothstep thresholding
	float tendril_mask = smoothstep(0.42, 0.58, tendrils1);
	float fine_mask = smoothstep(0.48, 0.6, tendrils2);
	float combined = max(tendril_mask, fine_mask * 0.6);

	// Left-edge intensity: tendrils are stronger near the left side
	float left_bias = smoothstep(0.8, 0.0, UV.x);
	// Also present in center but weaker
	float center_presence = smoothstep(0.0, 0.5, UV.x) * 0.4;
	float directional = left_bias + center_presence;

	combined *= directional;

	// Pulsing: tendrils throb like a heartbeat
	float pulse = sin(TIME * 2.5) * 0.5 + 0.5;
	float slow_pulse = sin(TIME * 1.2) * 0.5 + 0.5;
	combined *= 0.7 + 0.3 * pulse;

	// Base color: dark sickly background
	vec3 base = mix(siphon_dark.rgb, siphon_mid.rgb, noise(UV * 4.0 + TIME * 0.05));

	// Tendril color with bright tips
	vec3 tendril_col = mix(siphon_mid.rgb, tendril_color.rgb, combined);

	// Final composite
	vec3 color = mix(base, tendril_col, combined * tendril_intensity);

	// Bright vein cores: the thinnest part of tendrils glows brightest
	float core = smoothstep(0.55, 0.65, tendrils1) * left_bias;
	color += tendril_color.rgb * core * 0.4 * (0.8 + 0.2 * pulse);

	// Subtle ambient throb on the whole surface
	color += siphon_mid.rgb * slow_pulse * 0.08;

	// Blend with original texture
	color = mix(tex_color.rgb * siphon_dark.rgb * 0.5, color, tendril_intensity);

	COLOR = vec4(color, tex_color.a);
}
