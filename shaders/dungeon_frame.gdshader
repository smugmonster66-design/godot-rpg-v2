// res://shaders/dungeon_frame.gdshader
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.1, 0.08, 0.15, 1.0);
uniform vec4 accent_color : source_color = vec4(0.2, 0.1, 0.3, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float accent_blend : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // tex.a = the gradient (1.0 at edges, 0.0 at center)
    
    // Mix fog and accent based on vertical position (top = accent, bottom = fog)
    vec4 tint = mix(fog_color, accent_color, UV.y * accent_blend);
    
    COLOR = vec4(tint.rgb, tex.a * intensity);
}