// res://shaders/enemy_turn_border_glow.gdshader
// Soft pulsing gold border glow for enemy turn indicator.
// Applied directly to the BackgroundFrame NinePatchRect.
// The glow fans inward from each edge, brightening the existing texture.

shader_type canvas_item;

/// Gold glow color
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);

/// How far the glow extends inward (in UV space, 0–0.5)
uniform float border_width : hint_range(0.01, 0.4) = 0.12;

/// Softness of the inner glow falloff — larger = more gradual fade
uniform float glow_softness : hint_range(0.005, 0.15) = 0.04;

/// How much to brighten the underlying texture at the glow peak
uniform float glow_intensity : hint_range(0.5, 4.0) = 2.2;

/// Pulse oscillation speed
uniform float pulse_speed : hint_range(0.0, 6.0) = 1.8;

/// Minimum pulse brightness (0 = fully off at trough, 1 = no pulse)
uniform float pulse_min : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distance from the nearest edge (0.0 = at edge, 0.5 = dead center)
	float d_left   = UV.x;
	float d_right  = 1.0 - UV.x;
	float d_top    = UV.y;
	float d_bottom = 1.0 - UV.y;
	float d_edge   = min(min(d_left, d_right), min(d_top, d_bottom));

	// Glow mask: 1.0 at the edge, smoothly fades to 0 inward
	float raw_mask = 1.0 - smoothstep(0.0, border_width, d_edge);
	// Apply softness for a more organic falloff
	float glow_mask = pow(raw_mask, 1.0 + glow_softness * 20.0);

	// Pulse — ranges from pulse_min to 1.0
	float pulse = mix(pulse_min, 1.0, (sin(TIME * pulse_speed) + 1.0) * 0.5);

	float strength = glow_mask * pulse;

	// Blend: push the texture toward glow_color, boosting brightness at peak
	vec3 brightened = tex.rgb + glow_color.rgb * (glow_intensity - 1.0) * strength * glow_color.a;
	vec3 result = mix(tex.rgb, brightened, strength * glow_color.a);

	// Alpha: preserve texture alpha, allow glow to expand into fully transparent pixels
	float out_alpha = max(tex.a, glow_mask * pulse * glow_color.a);

	COLOR = vec4(result, out_alpha);
}
