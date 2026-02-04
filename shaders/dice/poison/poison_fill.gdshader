shader_type canvas_item;

// Poison element - bubbling toxic liquid
uniform vec4 poison_dark : source_color = vec4(0.1, 0.3, 0.1, 1.0);
uniform vec4 poison_mid : source_color = vec4(0.2, 0.6, 0.15, 1.0);
uniform vec4 poison_bright : source_color = vec4(0.5, 0.9, 0.2, 1.0);
uniform float bubble_speed : hint_range(0.5, 2.0) = 1.0;
uniform float toxicity : hint_range(0.0, 1.0) = 0.8;

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
	
	// Bubbling liquid surface
	vec2 bubble_uv = UV;
	bubble_uv.y += TIME * bubble_speed * 0.15;
	
	float bubble1 = noise(bubble_uv * 10.0);
	float bubble2 = noise(bubble_uv * 20.0 + vec2(3.7, 2.1));
	
	// Create bubble shapes
	float bubbles = smoothstep(0.55, 0.65, bubble1);
	bubbles += smoothstep(0.6, 0.7, bubble2) * 0.5;
	
	// Swirling toxic base
	vec2 swirl_uv = UV;
	swirl_uv += vec2(sin(TIME * 0.3 + UV.y * 3.0), cos(TIME * 0.4 + UV.x * 3.0)) * 0.03;
	float swirl = noise(swirl_uv * 6.0 + vec2(TIME * 0.1, 0.0));
	
	// Base color gradient
	vec3 color = mix(poison_dark.rgb, poison_mid.rgb, swirl);
	
	// Add bubble highlights
	color = mix(color, poison_bright.rgb, bubbles * 0.6);
	
	// Toxic glow from center
	float glow_dist = length(UV - vec2(0.5));
	float glow = smoothstep(0.5, 0.2, glow_dist);
	color += poison_bright.rgb * glow * 0.2;
	
	// Apply toxicity
	color = mix(tex_color.rgb * poison_mid.rgb * 0.5, color, toxicity);
	
	COLOR = vec4(color, tex_color.a);
}
