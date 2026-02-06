shader_type canvas_item;

// Siphon affix stroke - subtle creeping desaturation with green vein highlights
// Much subtler than the fill; the stroke looks "infected" at the edges
uniform vec4 vein_color : source_color = vec4(0.25, 0.7, 0.15, 1.0);
uniform vec4 tarnish_color : source_color = vec4(0.12, 0.18, 0.1, 1.0);
uniform float creep_speed : hint_range(0.2, 1.5) = 0.5;
uniform float infection : hint_range(0.0, 1.0) = 0.6;

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

	// Creeping vein noise along the stroke
	vec2 creep_uv = UV * vec2(4.0, 8.0);
	creep_uv.x -= TIME * creep_speed * 0.2;
	float vein = noise(creep_uv);
	float vein_fine = noise(creep_uv * 2.5 + vec2(TIME * 0.1, 0.0));

	// Thin vein lines
	float vein_mask = smoothstep(0.52, 0.62, vein) * 0.7;
	vein_mask += smoothstep(0.56, 0.64, vein_fine) * 0.3;

	// Pulse sync with fill shader heartbeat
	float pulse = sin(TIME * 2.5) * 0.5 + 0.5;
	vein_mask *= 0.6 + 0.4 * pulse;

	// Tarnish: overall desaturation toward sickly green-grey
	vec3 grey = vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 tarnished = mix(grey, tarnish_color.rgb, 0.5);
	vec3 base = mix(tex_color.rgb, tarnished, infection * 0.6);

	// Overlay vein highlights
	base = mix(base, vein_color.rgb, vein_mask * infection * 0.5);

	COLOR = vec4(base, tex_color.a);
}
