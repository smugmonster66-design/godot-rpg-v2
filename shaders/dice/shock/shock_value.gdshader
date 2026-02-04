shader_type canvas_item;

// Shock element value - flickering electric text
uniform vec4 text_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform float flicker_speed : hint_range(2.0, 10.0) = 6.0;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	
	// Erratic flicker
	float flicker_time = floor(TIME * flicker_speed);
	float flicker = hash(flicker_time);
	flicker = step(0.3, flicker);  // On most of the time, occasional flicker
	
	// Brightness pulse
	float pulse = sin(TIME * flicker_speed * 0.3) * 0.2 + 0.8;
	
	// Color with flicker
	vec3 color = mix(text_color.rgb * 0.6, flash_color.rgb, flicker * pulse);
	
	// Add slight outline glow
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
