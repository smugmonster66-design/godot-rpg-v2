shader_type canvas_item;

// Frost glow shader for value labels
// Creates a glowing light blue-white effect with outer glow

uniform vec4 text_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.6, 0.85, 1.0, 0.8);
uniform float glow_size : hint_range(0.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	
	// Pulsing glow intensity
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	
	// Sample surrounding pixels for glow
	float glow = 0.0;
	float pixel_size = 1.0 / 64.0; // Approximate for label size
	
	for (float x = -glow_size; x <= glow_size; x += 1.0) {
		for (float y = -glow_size; y <= glow_size; y += 1.0) {
			float dist = length(vec2(x, y));
			if (dist <= glow_size) {
				vec2 offset = vec2(x, y) * pixel_size;
				float sample_alpha = texture(TEXTURE, UV + offset).a;
				float falloff = 1.0 - (dist / glow_size);
				glow += sample_alpha * falloff * falloff;
			}
		}
	}
	
	// Normalize glow
	glow = clamp(glow / (glow_size * 2.0), 0.0, 1.0) * glow_intensity * pulse;
	
	// Combine: glow behind, bright text on top
	vec4 glow_layer = glow_color * glow;
	vec4 text_layer = text_color * original.a;
	
	// Blend glow and text
	COLOR = mix(glow_layer, text_layer, original.a);
	COLOR.a = max(glow * glow_color.a, original.a);
}
