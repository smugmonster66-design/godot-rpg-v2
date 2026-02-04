shader_type canvas_item;

// Shadow element - dark void with swirling shadows
uniform vec4 void_color : source_color = vec4(0.05, 0.02, 0.08, 1.0);
uniform vec4 shadow_mid : source_color = vec4(0.15, 0.08, 0.2, 1.0);
uniform vec4 shadow_purple : source_color = vec4(0.3, 0.15, 0.4, 1.0);
uniform float swirl_speed : hint_range(0.2, 1.0) = 0.4;
uniform float darkness : hint_range(0.0, 1.0) = 0.85;

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
	
	// Swirling shadow tendrils
	vec2 swirl_uv = UV - vec2(0.5);
	float angle = atan(swirl_uv.y, swirl_uv.x);
	float dist = length(swirl_uv);
	
	// Rotating distortion
	angle += TIME * swirl_speed + dist * 2.0;
	vec2 distorted = vec2(cos(angle), sin(angle)) * dist + vec2(0.5);
	
	// Shadow layers
	float shadow1 = noise(distorted * 5.0 + vec2(TIME * 0.1, 0.0));
	float shadow2 = noise(distorted * 10.0 - vec2(0.0, TIME * 0.15));
	float shadow3 = noise(UV * 20.0 + vec2(TIME * 0.05, TIME * 0.08));
	
	float shadows = shadow1 * 0.5 + shadow2 * 0.3 + shadow3 * 0.2;
	
	// Deep void at center
	float void_depth = smoothstep(0.5, 0.1, dist);
	
	// Color gradient
	vec3 color = mix(shadow_mid.rgb, void_color.rgb, void_depth);
	color = mix(color, shadow_purple.rgb, shadows * 0.4);
	
	// Occasional purple gleam from the depths
	float gleam = smoothstep(0.7, 0.8, shadow1 * shadow2);
	color += shadow_purple.rgb * gleam * 0.3;
	
	// Apply darkness
	color = mix(tex_color.rgb * shadow_mid.rgb * 0.3, color, darkness);
	
	COLOR = vec4(color, tex_color.a);
}
