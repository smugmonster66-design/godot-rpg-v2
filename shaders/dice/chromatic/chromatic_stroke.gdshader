shader_type canvas_item;

// Chromatic stroke — prismatic border blending ember, frost, and arc effects
// Cycles between the three element stroke styles with animated transitions

// Fire stroke colors
uniform vec4 ember_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform vec4 ash_color : source_color = vec4(0.3, 0.15, 0.1, 1.0);

// Ice stroke colors
uniform vec4 frost_color : source_color = vec4(0.7, 0.85, 0.95, 1.0);
uniform vec4 crystal_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);

// Shock stroke colors
uniform vec4 storm_base : source_color = vec4(0.1, 0.14, 0.28, 1.0);
uniform vec4 arc_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec4 spark_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

// Animation
uniform float cycle_speed : hint_range(0.05, 0.5) = 0.15;
uniform float blend_softness : hint_range(1.0, 8.0) = 3.0;

// ── Noise ──

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

// ── Element stroke generators ──

vec3 ember_stroke(vec2 uv) {
	float ember_noise = noise(uv * 8.0);
	float pulse = sin(TIME * 2.0 + ember_noise * 6.28) * 0.5 + 0.5;
	float heat = noise(uv * 15.0 + vec2(TIME * 0.3, -TIME * 0.2));
	float glow = heat * pulse * 0.8;
	vec3 col = mix(ash_color.rgb, ember_color.rgb, glow);
	float bright = smoothstep(0.7, 0.9, heat * pulse);
	col += vec3(1.0, 0.8, 0.4) * bright * 0.5;
	return col;
}

vec3 frost_stroke(vec2 uv) {
	float crystal1 = noise(uv * 20.0);
	float crystal2 = noise(uv * 40.0 + vec2(5.0, 3.0));
	float crystals = max(
		smoothstep(0.6, 0.7, crystal1),
		smoothstep(0.65, 0.75, crystal2) * 0.7
	);
	float frost = noise(uv * 12.0);
	frost = smoothstep(0.3, 0.6, frost) * 0.7;
	vec3 col = frost_color.rgb;
	col = mix(col, col * 0.8, frost);
	col = mix(col, crystal_color.rgb, crystals * 0.6);
	// Sparkle
	float sparkle = noise(uv * 50.0);
	sparkle = step(0.92, sparkle);
	float twinkle = sin(TIME * 2.0 + hash(floor(uv * 50.0)) * 6.28) * 0.5 + 0.5;
	col += crystal_color.rgb * sparkle * twinkle * 0.5;
	return col;
}

vec3 arc_stroke(vec2 uv) {
	float arc_noise = noise(uv * 10.0 + vec2(TIME * 4.0, 0.0));
	float arc = smoothstep(0.55, 0.65, arc_noise) * 0.8;
	vec3 col = storm_base.rgb;
	col = mix(col, arc_color.rgb, arc);
	// Sparks
	float spark = noise(uv * 30.0 + TIME * 3.0);
	spark = step(0.9, spark);
	float flicker = step(0.5, hash(vec2(floor(TIME * 8.0), floor(uv.x * 20.0))));
	col += spark_color.rgb * spark * flicker * 0.6;
	return col;
}

// ── Main ──

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Rotating sector determines element blend
	vec2 center = UV - vec2(0.5);
	float angle = atan(center.y, center.x);
	float rotating_offset = TIME * cycle_speed * 6.28318;
	float norm_angle = fract((angle + 3.14159) / 6.28318 + rotating_offset / 6.28318);

	// Organic boundary distortion
	float boundary_noise = noise(UV * 5.0 + vec2(TIME * 0.15, -TIME * 0.1)) * 0.1;
	norm_angle = fract(norm_angle + boundary_noise);

	// Three-way blend weights
	float w_fire  = smoothstep(0.0, 1.0 / blend_softness, 0.333 - abs(norm_angle - 0.167));
	float w_ice   = smoothstep(0.0, 1.0 / blend_softness, 0.333 - abs(norm_angle - 0.5));
	float w_shock = smoothstep(0.0, 1.0 / blend_softness, 0.333 - abs(norm_angle - 0.833));
	// Wrap-around for fire
	w_fire += smoothstep(0.0, 1.0 / blend_softness, 0.333 - abs(norm_angle - 1.167));

	float total_w = w_fire + w_ice + w_shock + 0.001;
	w_fire /= total_w;
	w_ice /= total_w;
	w_shock /= total_w;

	// Sample each element's stroke
	vec3 c_ember = ember_stroke(UV);
	vec3 c_frost = frost_stroke(UV);
	vec3 c_arc = arc_stroke(UV);

	vec3 color = c_ember * w_fire + c_frost * w_ice + c_arc * w_shock;

	// Prismatic highlight at boundaries
	float boundary = 1.0 - max(w_fire, max(w_ice, w_shock));
	float shimmer = sin(TIME * 3.0 + length(center) * 15.0) * 0.5 + 0.5;
	color += vec3(1.0, 0.95, 0.9) * boundary * shimmer * 0.3;

	COLOR = vec4(color * tex_color.rgb, tex_color.a);
}
