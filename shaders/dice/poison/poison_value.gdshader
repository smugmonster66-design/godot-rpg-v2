shader_type canvas_item;

// Poison element value - sickly glowing text
uniform vec4 text_color : source_color = vec4(0.4, 0.85, 0.25, 1.0);
uniform vec4 glow_color : source_color = vec4(0.6, 1.0, 0.3, 1.0);
uniform float pulse_speed : hint_range(0.5, 2.0) = 1.0;
uniform float sickness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	
	// Sickly pulsing (irregular, uncomfortable)
	float pulse1 = sin(TIME * pulse_speed * 1.0) * 0.5 + 0.5;
	float pulse2 = sin(TIME * pulse_speed * 1.7 + 1.0) * 0.5 + 0.5;
	float pulse = pulse1 * 0.7 + pulse2 * 0.3;
	
	// Slight color shift (sickly)
	vec3 color = text_color.rgb;
	color.r += sin(TIME * 0.5) * sickness * 0.1;
	color.b -= cos(TIME * 0.7) * sickness * 0.05;
	
	// Glow intensity
	color = mix(color, glow_color.rgb, pulse * 0.3);
	
	// Outer glow
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = 2.0 / tex_size;
	float outer = 0.0;
	outer += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a;
	outer += texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a;
	outer += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a;
	outer += texture(TEXTURE, UV - vec2(0.0, pixel.y)).a;
	outer = clamp(outer - alpha * 4.0, 0.0, 1.0);
	
	color += glow_color.rgb * outer * pulse * 0.4;
	
	COLOR = vec4(color, alpha);
}
