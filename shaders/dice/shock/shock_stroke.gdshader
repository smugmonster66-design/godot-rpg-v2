shader_type canvas_item;

// Shock element stroke — dark storm edges with flickering arc highlights
uniform vec4 storm_base : source_color = vec4(0.10, 0.14, 0.28, 1.0);
uniform vec4 arc_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec4 spark_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float arc_speed : hint_range(1.0, 8.0) = 4.0;
uniform float arc_intensity : hint_range(0.0, 1.0) = 0.8;

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

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Dark storm base for the stroke
	float cloud = noise(UV * 8.0 + vec2(TIME * 0.15, TIME * 0.1));
	vec3 base = mix(storm_base.rgb * 0.7, storm_base.rgb, cloud);
	base *= tex_color.rgb;

	// Travelling arc segments — sharp crackles that move along the stroke
	float time_step = floor(TIME * arc_speed);
	float time_frac = fract(TIME * arc_speed);

	// Two arc channels at different seeds
	float arc_seed1 = hash(vec2(time_step, 0.0));
	float arc_seed2 = hash(vec2(time_step + 0.5, 7.0));

	// Arc 1: travels along Y
	float arc_pos1 = arc_seed1;
	float arc1 = smoothstep(0.12, 0.0, abs(fract(UV.y * 4.0 + arc_seed1 * 3.0) - time_frac));
	arc1 *= step(0.7, hash(vec2(time_step, UV.x * 8.0))); // sparse

	// Arc 2: travels along X
	float arc_pos2 = arc_seed2;
	float arc2 = smoothstep(0.12, 0.0, abs(fract(UV.x * 4.0 + arc_seed2 * 3.0) - time_frac));
	arc2 *= step(0.7, hash(vec2(time_step + 0.5, UV.y * 8.0)));

	float arcs = max(arc1, arc2);

	// Brief flash envelope so arcs appear and vanish
	float flash = smoothstep(0.0, 0.1, time_frac) * smoothstep(0.6, 0.2, time_frac);
	arcs *= flash;

	// Subtle ambient glow pulse
	float glow = sin(TIME * arc_speed * 0.4 + UV.x * 6.0 + UV.y * 5.0) * 0.5 + 0.5;
	glow *= 0.15;

	// Combine
	vec3 color = base;
	color = mix(color, arc_color.rgb, glow * arc_intensity);
	color = mix(color, spark_color.rgb, arcs * arc_intensity);

	COLOR = vec4(color, tex_color.a);
}
