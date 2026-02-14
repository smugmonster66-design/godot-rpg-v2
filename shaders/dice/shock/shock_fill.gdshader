shader_type canvas_item;

// Shock element — dark storm clouds with crackling lightning bolts
uniform vec4 cloud_dark : source_color = vec4(0.06, 0.08, 0.18, 1.0);
uniform vec4 cloud_mid : source_color = vec4(0.12, 0.16, 0.30, 1.0);
uniform vec4 bolt_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec4 bolt_core : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float cloud_speed : hint_range(0.1, 1.0) = 0.25;
uniform float bolt_rate : hint_range(0.1, 8.0) = 3.5;
uniform float bolt_brightness : hint_range(0.5, 2.0) = 1.4;
uniform float cloud_intensity : hint_range(0.0, 1.0) = 0.85;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

// ── Lightning bolt generator ──
// Returns glow intensity at UV for a bolt that fires at a given time seed.
// The bolt traces a jagged vertical path using stepped noise for X-offsets.

float bolt(vec2 uv, float time_seed, float x_origin) {
	float intensity = 0.0;
	float x = x_origin;
	float thickness = 0.012;

	// Walk down the surface in segments
	for (int i = 0; i < 18; i++) {
		float seg_y = float(i) / 18.0;
		float seg_y_next = float(i + 1) / 18.0;

		// Jag the x position at each segment
		float jag = (hash(vec2(time_seed + float(i) * 7.3, float(i) * 3.1)) - 0.5) * 0.14;
		float x_next = x + jag;

		// Check if this UV point is near the line segment
		if (uv.y >= seg_y && uv.y < seg_y_next) {
			float t = (uv.y - seg_y) / (seg_y_next - seg_y);
			float line_x = mix(x, x_next, t);
			float dist = abs(uv.x - line_x);

			// Core (bright white-blue)
			intensity += smoothstep(thickness, 0.0, dist) * 1.0;
			// Glow halo
			intensity += smoothstep(thickness * 5.0, 0.0, dist) * 0.35;
		}

		x = x_next;
	}

	return intensity;
}

// ── Branch bolt (shorter, thinner) ──

float branch(vec2 uv, float time_seed, float x_origin, float y_start, float y_end, float dx_bias) {
	float intensity = 0.0;
	float x = x_origin;
	float thickness = 0.007;
	int steps = 8;

	for (int i = 0; i < 8; i++) {
		float seg_y = mix(y_start, y_end, float(i) / float(steps));
		float seg_y_next = mix(y_start, y_end, float(i + 1) / float(steps));

		float jag = (hash(vec2(time_seed + float(i) * 13.7, float(i) * 5.3)) - 0.5) * 0.08 + dx_bias * 0.03;
		float x_next = x + jag;

		if (uv.y >= min(seg_y, seg_y_next) && uv.y < max(seg_y, seg_y_next) + 0.001) {
			float t = clamp((uv.y - seg_y) / (seg_y_next - seg_y + 0.001), 0.0, 1.0);
			float line_x = mix(x, x_next, t);
			float dist = abs(uv.x - line_x);
			intensity += smoothstep(thickness, 0.0, dist) * 0.7;
			intensity += smoothstep(thickness * 4.0, 0.0, dist) * 0.2;
		}
		x = x_next;
	}
	return intensity;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// ── Storm cloud base ──
	vec2 cloud_uv = UV * vec2(3.0, 2.5);
	cloud_uv += vec2(TIME * cloud_speed * 0.4, TIME * cloud_speed * 0.15);

	float clouds = fbm(cloud_uv);
	float cloud_detail = fbm(cloud_uv * 2.0 + vec2(3.7, 1.2));

	// Darker clouds with lighter wisps
	float cloud_val = clouds * 0.6 + cloud_detail * 0.4;
	vec3 sky = mix(cloud_dark.rgb, cloud_mid.rgb, cloud_val);

	// Subtle darker pockets for depth
	float pocket = fbm(cloud_uv * 1.5 - vec2(TIME * 0.05, 0.0));
	sky = mix(sky, cloud_dark.rgb * 0.7, smoothstep(0.35, 0.55, pocket) * 0.4);

	// ── Lightning bolts ──
	// Two bolt slots that fire at staggered intervals.
	// Each bolt is visible for a brief flash then gone.

	float bolt_time = TIME * bolt_rate;
	float total_bolt = 0.0;

	// Bolt A
	float slot_a = floor(bolt_time);
	float frac_a = fract(bolt_time);
	float flash_a = smoothstep(0.0, 0.04, frac_a) * smoothstep(0.25, 0.08, frac_a); // brief flash envelope
	if (flash_a > 0.01) {
		float seed_a = slot_a * 17.3;
		float origin_a = 0.3 + hash(vec2(seed_a, 1.0)) * 0.4; // x origin: 0.3–0.7
		total_bolt += bolt(UV, seed_a, origin_a) * flash_a;
		// Branch
		float branch_y = 0.25 + hash(vec2(seed_a, 2.0)) * 0.35;
		float branch_x = origin_a + (hash(vec2(seed_a, 3.0)) - 0.5) * 0.12;
		float branch_dir = sign(hash(vec2(seed_a, 4.0)) - 0.5);
		total_bolt += branch(UV, seed_a + 100.0, branch_x, branch_y, branch_y + 0.2, branch_dir) * flash_a;
	}

	// Bolt B (offset by half period)
	float slot_b = floor(bolt_time + 0.5);
	float frac_b = fract(bolt_time + 0.5);
	float flash_b = smoothstep(0.0, 0.04, frac_b) * smoothstep(0.25, 0.08, frac_b);
	if (flash_b > 0.01) {
		float seed_b = slot_b * 31.7 + 5.0;
		float origin_b = 0.25 + hash(vec2(seed_b, 1.0)) * 0.5;
		total_bolt += bolt(UV, seed_b, origin_b) * flash_b;
	}

	// Color the bolt: core is near-white, falloff is light blue
	vec3 bolt_col = mix(bolt_color.rgb, bolt_core.rgb, clamp(total_bolt, 0.0, 1.0));
	vec3 final_col = sky + bolt_col * total_bolt * bolt_brightness;

	// Ambient illumination flash — clouds briefly light up when a bolt fires
	float ambient_flash = max(flash_a, flash_b) * 0.15;
	final_col += bolt_color.rgb * ambient_flash;

	// Mix with texture
	final_col = mix(tex_color.rgb * cloud_mid.rgb * 0.4, final_col, cloud_intensity);

	COLOR = vec4(final_col, tex_color.a);
}
