shader_type canvas_item;

// Chromatic element — prismatic blend of fire, ice, and shock
// Shifts between three elemental zones with animated boundaries

// Fire palette
uniform vec4 fire_core : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 fire_mid : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 fire_edge : source_color = vec4(0.8, 0.2, 0.05, 1.0);

// Ice palette
uniform vec4 ice_deep : source_color = vec4(0.15, 0.3, 0.5, 1.0);
uniform vec4 ice_mid : source_color = vec4(0.4, 0.7, 0.9, 1.0);
uniform vec4 ice_bright : source_color = vec4(0.85, 0.95, 1.0, 1.0);

// Shock palette
uniform vec4 shock_dark : source_color = vec4(0.06, 0.08, 0.18, 1.0);
uniform vec4 shock_mid : source_color = vec4(0.12, 0.16, 0.30, 1.0);
uniform vec4 shock_bolt : source_color = vec4(0.55, 0.78, 1.0, 1.0);

// Animation
uniform float rotation_speed : hint_range(0.05, 0.5) = 0.15;
uniform float blend_sharpness : hint_range(1.0, 8.0) = 3.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.6;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

// ── Element color generators ──

vec3 fire_color(vec2 uv) {
	vec2 flame_uv = uv;
	flame_uv.y -= TIME * 1.2 * 0.3;
	float flame = noise(flame_uv * 6.0) * 0.5 + noise(flame_uv * 12.0 + vec2(TIME * 0.5, 0.0)) * 0.3 + noise(flame_uv * 24.0 - vec2(0.0, TIME * 0.8)) * 0.2;
	float rise = 1.0 - uv.y;
	flame *= rise * 0.5 + 0.5;
	vec3 col;
	if (flame > 0.6) {
		col = mix(fire_mid.rgb, fire_core.rgb, (flame - 0.6) / 0.4);
	} else if (flame > 0.3) {
		col = mix(fire_edge.rgb, fire_mid.rgb, (flame - 0.3) / 0.3);
	} else {
		col = fire_edge.rgb * (flame / 0.3 * 0.5 + 0.5);
	}
	return col;
}

vec3 ice_color(vec2 uv) {
	// Crystalline Voronoi
	vec2 cell_uv = uv * 5.0;
	vec2 i = floor(cell_uv);
	vec2 f = fract(cell_uv);
	float min_d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash(i + neighbor) * vec2(0.5) + vec2(0.25);
			float d = length(neighbor + point - f);
			min_d = min(min_d, d);
		}
	}
	float facet = smoothstep(0.0, 0.3, min_d);
	float frost = noise(uv * 15.0) * 0.6 + noise(uv * 30.0 + vec2(2.3, 1.7)) * 0.4;
	frost = smoothstep(0.3, 0.7, frost);
	vec3 col = mix(ice_deep.rgb, ice_mid.rgb, facet);
	col = mix(col, ice_bright.rgb, frost * 0.5);
	float shimmer = sin(TIME * 0.5 + uv.x * 10.0 + uv.y * 8.0) * 0.5 + 0.5;
	col += ice_bright.rgb * shimmer * smoothstep(0.6, 0.8, frost) * 0.15;
	return col;
}

vec3 shock_color(vec2 uv) {
	vec2 cloud_uv = uv * vec2(3.0, 2.5) + vec2(TIME * 0.1, TIME * 0.04);
	float clouds = fbm(cloud_uv);
	float detail = fbm(cloud_uv * 2.0 + vec2(3.7, 1.2));
	float cloud_val = clouds * 0.6 + detail * 0.4;
	vec3 sky = mix(shock_dark.rgb, shock_mid.rgb, cloud_val);

	// Mini bolt flash
	float bolt_time = TIME * 2.5;
	float slot = floor(bolt_time);
	float frac_t = fract(bolt_time);
	float flash = smoothstep(0.0, 0.04, frac_t) * smoothstep(0.2, 0.08, frac_t);
	float seed_v = slot * 17.3;
	float bolt_x = 0.3 + hash(vec2(seed_v, 1.0)) * 0.4;
	float dist = abs(uv.x - bolt_x);
	float bolt_glow = smoothstep(0.08, 0.0, dist) * flash;
	sky += shock_bolt.rgb * bolt_glow * 1.2;
	sky += shock_bolt.rgb * flash * 0.1; // ambient flash

	return sky;
}

// ── Main ──

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Rotating angle determines which element dominates
	vec2 center = UV - vec2(0.5);
	float angle = atan(center.y, center.x); // -PI to PI
	float rotating_offset = TIME * rotation_speed * 6.28318;

	// Normalize angle to 0–1 with rotation
	float norm_angle = fract((angle + 3.14159) / 6.28318 + rotating_offset / 6.28318);

	// Distort the boundary with noise for organic feel
	float boundary_noise = noise(UV * 4.0 + vec2(TIME * 0.2, -TIME * 0.15)) * 0.12;
	norm_angle = fract(norm_angle + boundary_noise);

	// Three-way blend weights using smooth triangle waves
	// Each element gets a 120° wedge with soft falloff
	float w_fire  = smoothstep(0.0, 1.0 / blend_sharpness, 0.333 - abs(norm_angle - 0.167));
	float w_ice   = smoothstep(0.0, 1.0 / blend_sharpness, 0.333 - abs(norm_angle - 0.5));
	float w_shock = smoothstep(0.0, 1.0 / blend_sharpness, 0.333 - abs(norm_angle - 0.833));

	// Handle wrap-around for fire (near 0.0 / 1.0)
	w_fire += smoothstep(0.0, 1.0 / blend_sharpness, 0.333 - abs(norm_angle - 1.167));
	w_fire += smoothstep(0.0, 1.0 / blend_sharpness, 0.333 - abs(norm_angle + 0.167 - 0.167));

	// Normalize
	float total_w = w_fire + w_ice + w_shock + 0.001;
	w_fire /= total_w;
	w_ice /= total_w;
	w_shock /= total_w;

	// Sample each element
	vec3 c_fire = fire_color(UV);
	vec3 c_ice = ice_color(UV);
	vec3 c_shock = shock_color(UV);

	// Blend
	vec3 color = c_fire * w_fire + c_ice * w_ice + c_shock * w_shock;

	// Prismatic shimmer along the boundaries
	float boundary = 1.0 - max(w_fire, max(w_ice, w_shock));
	float shimmer = sin(TIME * 2.0 + length(center) * 20.0) * 0.5 + 0.5;
	color += vec3(0.9, 0.95, 1.0) * boundary * shimmer * shimmer_intensity * 0.5;

	// Central prismatic core glow
	float core_dist = length(center);
	float core_pulse = sin(TIME * 1.5) * 0.3 + 0.7;
	float core_glow = smoothstep(0.35, 0.05, core_dist) * 0.25 * core_pulse;
	color += vec3(0.9, 0.85, 1.0) * core_glow;

	COLOR = vec4(color, tex_color.a);
}
