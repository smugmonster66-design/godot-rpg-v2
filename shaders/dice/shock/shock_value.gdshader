shader_type canvas_item;

// Shock element value — light blue text with electric flicker
uniform vec4 text_color : source_color = vec4(0.6, 0.82, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float flicker_speed : hint_range(2.0, 10.0) = 6.0;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a;

	// Erratic flicker — on most frames, occasional bright flash
	float flicker_time = floor(TIME * flicker_speed);
	float flicker = hash(flicker_time);
	flicker = step(0.3, flicker);

	// Brightness pulse
	float pulse = sin(TIME * flicker_speed * 0.3) * 0.2 + 0.8;

	// Color with flicker
	vec3 color = mix(text_color.rgb * 0.7, flash_color.rgb, flicker * pulse);

	// Outline glow
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 1.0 / tex_size;
	float outline = 0.0;
	outline += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a;
	outline += texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a;
	outline += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a;
	outline += texture(TEXTURE, UV - vec2(0.0, pixel.y)).a;
	outline = clamp(outline - alpha * 4.0, 0.0, 1.0);

	color += text_color.rgb * outline * 0.3 * flicker;

	COLOR = vec4(color, alpha);
}
