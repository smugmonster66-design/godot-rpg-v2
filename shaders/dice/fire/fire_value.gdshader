shader_type canvas_item;

// Fire element value - glowing hot text
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float glow_pulse : hint_range(0.5, 3.0) = 1.5;
uniform float heat_intensity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	
	// Pulsing heat glow
	float pulse = sin(TIME * glow_pulse) * 0.3 + 0.7;
	
	// Color shifts between hot white-yellow and orange
	vec3 color = mix(warm_color.rgb, hot_color.rgb, pulse * heat_intensity);
	
	// Inner glow (brighter at center of text)
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;
	
	float neighbors = 0.0;
	neighbors += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a;
	neighbors += texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a;
	neighbors += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a;
	neighbors += texture(TEXTURE, UV - vec2(0.0, pixel.y)).a;
	
	float edge = 1.0 - (neighbors / 4.0);
	color = mix(color, hot_color.rgb, (1.0 - edge) * 0.3);
	
	COLOR = vec4(color, alpha);
}
