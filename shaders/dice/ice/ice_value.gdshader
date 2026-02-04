shader_type canvas_item;

// Ice element value - frozen text with frost shimmer
uniform vec4 text_color : source_color = vec4(0.8, 0.92, 1.0, 1.0);
uniform vec4 frost_color : source_color = vec4(0.6, 0.8, 0.95, 1.0);
uniform float shimmer_speed : hint_range(0.3, 1.5) = 0.6;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	
	// Slow icy shimmer
	float shimmer = sin(TIME * shimmer_speed + UV.x * 8.0) * 0.5 + 0.5;
	shimmer *= sin(TIME * shimmer_speed * 0.7 + UV.y * 6.0) * 0.5 + 0.5;
	
	// Color with shimmer
	vec3 color = mix(frost_color.rgb, text_color.rgb, 0.6 + shimmer * 0.4);
	
	// Icy highlight
	float highlight = smoothstep(0.3, 0.7, UV.x + (1.0 - UV.y) * 0.3);
	color += vec3(0.1) * highlight;
	
	COLOR = vec4(color, alpha);
}
