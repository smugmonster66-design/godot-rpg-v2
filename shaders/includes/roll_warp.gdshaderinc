// res://shaders/includes/roll_warp.gdshaderinc
// Shared perspective warp for pseudo-3D die rolling.
// Include in any canvas_item shader and call apply_roll_warp(UV).
// When rotation_angle == vec2(0), returns UV unchanged (zero cost path).

group_uniforms roll;
uniform vec2 rotation_angle = vec2(0.0, 0.0);
uniform float tilt_strength : hint_range(0.0, 1.0) = 0.5;

vec2 apply_roll_warp(vec2 uv) {
	vec2 center = uv - 0.5;
	float warp_x = 1.0 + center.y * sin(rotation_angle.x) * tilt_strength;
	float warp_y = 1.0 + center.x * sin(rotation_angle.y) * tilt_strength;
	warp_x = max(warp_x, 0.01);
	warp_y = max(warp_y, 0.01);
	return vec2(center.x / warp_x, center.y / warp_y) + 0.5;
}
