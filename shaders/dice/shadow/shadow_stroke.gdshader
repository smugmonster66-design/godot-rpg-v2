shader_type canvas_item;

// Shadow element stroke - smoky dissolving edges
uniform vec4 smoke_color : source_color = vec4(0.2, 0.12, 0.25, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.4, 0.25, 0.5, 1.0);
uniform float smoke_speed : hint_range(0.2, 1.0) = 0.5;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.4;

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
	
	// Smoky wisps rising
	vec2 smoke_uv = UV;
	smoke_uv.y -= TIME * smoke_speed * 0.1;
	smoke_uv.x += sin(UV.y * 5.0 + TIME * 0.5) * 0.05;
	
	float smoke = noise(smoke_uv * 12.0);
	float wisps = noise(smoke_uv * 25.0 + vec2(TIME * 0.2, 0.0));
	
	// Dissolve pattern
	float dissolve = noise(UV * 15.0 + vec2(3.0, 7.0));
	dissolve = smoothstep(dissolve_amount, dissolve_amount + 0.3, dissolve);
	
	// Base color
	vec3 color = smoke_color.rgb;
	
	// Add wispy highlights
	color = mix(color, wisp_color.rgb, smoothstep(0.5, 0.7, wisps) * 0.5);
	
	// Darken dissolved areas
	color *= 0.7 + dissolve * 0.3;
	
	// Apply to texture with some transparency variation
	color *= tex_color.rgb;
	float alpha = tex_color.a * (0.8 + dissolve * 0.2);
	
	COLOR = vec4(color, alpha);
}
