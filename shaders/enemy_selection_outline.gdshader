// res://shaders/enemy_selection_outline.gdshader

shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.2, 1.0);

uniform float outline_width : hint_range(0.0, 10.0) = 3.0;

uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

uniform float pulse_min : hint_range(0.0, 1.0) = 0.4;

uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

uniform bool enabled = false;

void fragment() {

    vec4 tex_color = texture(TEXTURE, UV);



    // Calculate pulse factor

    float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;

    float alpha_mult = mix(pulse_min, pulse_max, pulse);



    // Sample neighboring pixels for outline

    vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));

    float outline_alpha = 0.0;



    // Check surrounding pixels

    for (float x = -outline_width; x <= outline_width; x += 1.0) {

        for (float y = -outline_width; y <= outline_width; y += 1.0) {

            if (x != 0.0 || y != 0.0) {

                vec2 offset = vec2(x, y) * pixel_size;

                float neighbor_alpha = texture(TEXTURE, UV + offset).a;

                outline_alpha = max(outline_alpha, neighbor_alpha);

            }

        }

    }



    // Determine final color

    // If disabled, just use texture

    // If enabled and current pixel is transparent but neighbors aren't, draw outline

    // Otherwise use texture



    float is_outline_pixel = step(0.1, outline_alpha) * step(tex_color.a, 0.1);

    float use_outline = float(enabled) * is_outline_pixel;



    vec4 outline_result = vec4(outline_color.rgb, outline_color.a * alpha_mult);

    COLOR = mix(tex_color, outline_result, use_outline);

}