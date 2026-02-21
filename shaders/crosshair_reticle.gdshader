shader_type canvas_item;

uniform vec4 reticle_color : source_color = vec4(0.9, 0.15, 0.1, 0.85);
uniform float ring_radius : hint_range(0.1, 0.48) = 0.35;
uniform float ring_thickness : hint_range(0.005, 0.05) = 0.02;
uniform float crosshair_length : hint_range(0.05, 0.3) = 0.12;
uniform float crosshair_thickness : hint_range(0.005, 0.03) = 0.015;
uniform float gap_radius : hint_range(0.0, 0.2) = 0.08;
uniform float rotation_speed : hint_range(0.0, 3.0) = 0.8;
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.5;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    // Center UV to -0.5..0.5
    vec2 uv = UV - 0.5;

    // Aspect correction (square crosshair even in non-square rect)
    vec2 ratio = vec2(1.0);
    if (TEXTURE_PIXEL_SIZE.x < TEXTURE_PIXEL_SIZE.y) {
        ratio.y = TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y;
    } else {
        ratio.x = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
    }
    uv *= ratio;

    // Rotate
    float angle = TIME * rotation_speed;
    float cs = cos(angle);
    float sn = sin(angle);
    uv = vec2(uv.x * cs - uv.y * sn, uv.x * sn + uv.y * cs);

    float dist = length(uv);

    // Pulse alpha
    float pulse = mix(pulse_min, 1.0, (sin(TIME * pulse_speed) + 1.0) * 0.5);

    // Ring
    float ring_sdf = abs(dist - ring_radius) - ring_thickness;
    float ring = 1.0 - smoothstep(0.0, 0.008, ring_sdf);

    // Cross lines (4 arms from gap outward)
    float arm_outer = ring_radius + crosshair_length;
    float in_arm_x = step(gap_radius, abs(uv.x)) * step(abs(uv.x), arm_outer) * step(abs(uv.y), crosshair_thickness);
    float in_arm_y = step(gap_radius, abs(uv.y)) * step(abs(uv.y), arm_outer) * step(abs(uv.x), crosshair_thickness);
    float arms = max(in_arm_x, in_arm_y);

    // Small center dot
    float dot = 1.0 - smoothstep(0.0, 0.015, dist - 0.012);

    float mask = max(max(ring, arms), dot);

    COLOR = vec4(reticle_color.rgb, mask * reticle_color.a * pulse);
}