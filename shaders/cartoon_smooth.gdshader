shader_type canvas_item;

uniform float smoothness : hint_range(0.0, 1.0) = 0.9;
uniform float blur_passes : hint_range(1.0, 3.0) = 2.0;

void fragment() {
    vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
    vec4 original = texture(TEXTURE, UV);
    
    // Multi-pass blur for maximum smoothness
    vec4 blurred = vec4(0.0);
    int radius = int(blur_passes);
    int samples = 0;
    
    for(int x = -radius; x <= radius; x++) {
        for(int y = -radius; y <= radius; y++) {
            vec2 offset = vec2(float(x), float(y)) * texel_size;
            blurred += texture(TEXTURE, UV + offset);
            samples++;
        }
    }
    blurred /= float(samples);
    
    // Mix between original and blurred
    COLOR = mix(original, blurred, smoothness);
}