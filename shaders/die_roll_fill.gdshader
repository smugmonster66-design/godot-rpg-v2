shader_type canvas_item;
// =============================================================================
// DIE ROLL — FILL LAYER
// =============================================================================
// Pseudo-3D rolling effect for greyscale die fill textures.
// Derives surface normals from greyscale luminance and applies dynamic lighting.
//
// USAGE:
//   Assign to fill_texture.material on DieObjectBase.
//   Animate rotation_angle via tween to trigger the roll effect.
//   When rotation_angle == vec2(0), output is identical to a standard
//   color-tinted greyscale sample (no visual change from base appearance).
//
// NOTE ON COLOR:
//   color_tint replaces modulate for die color so specular highlights stay
//   white/clean. Set node modulate to WHITE when this shader is active.
// =============================================================================

#include "res://shaders/includes/roll_warp.gdshaderinc"

// ---------------------------------------------------------------------------
// FILL-SPECIFIC UNIFORMS
// ---------------------------------------------------------------------------
group_uniforms color;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

group_uniforms lighting;
uniform vec3 light_direction = vec3(0.3, -0.5, 1.0);
uniform float normal_strength : hint_range(0.0, 3.0) = 1.2;
uniform float ambient : hint_range(0.0, 1.0) = 0.3;
uniform float specular_power : hint_range(2.0, 128.0) = 32.0;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

// ---------------------------------------------------------------------------
// FRAGMENT
// ---------------------------------------------------------------------------
void fragment() {
	vec2 warped_uv = apply_roll_warp(UV);

	// Check bounds and transparency
	bool out_of_bounds = (warped_uv.x < 0.0 || warped_uv.x > 1.0 ||
	                      warped_uv.y < 0.0 || warped_uv.y > 1.0);

	vec4 tex = texture(TEXTURE, warped_uv);
	bool is_visible = !out_of_bounds && tex.a >= 0.01;

	if (is_visible) {
		// Greyscale fill: r == g == b, luminance is height
		float height = tex.r;

		// Derive surface normals via Sobel on greyscale
		vec2 texel = TEXTURE_PIXEL_SIZE;
		float h_left  = texture(TEXTURE, warped_uv + vec2(-texel.x, 0.0)).r;
		float h_right = texture(TEXTURE, warped_uv + vec2( texel.x, 0.0)).r;
		float h_up    = texture(TEXTURE, warped_uv + vec2(0.0, -texel.y)).r;
		float h_down  = texture(TEXTURE, warped_uv + vec2(0.0,  texel.y)).r;

		vec3 normal = normalize(vec3(
			(h_left - h_right) * normal_strength,
			(h_up - h_down) * normal_strength,
			1.0
		));

		// Lighting setup
		vec3 light_dir = normalize(light_direction);
		vec3 view_dir = vec3(0.0, 0.0, 1.0);

		// Diffuse (Lambert)
		float diffuse = max(dot(normal, light_dir), 0.0);

		// Specular (Blinn-Phong)
		vec3 half_dir = normalize(light_dir + view_dir);
		float spec = pow(max(dot(normal, half_dir), 0.0), specular_power) * specular_intensity;

		// Rim / Fresnel
		float rim_factor = 1.0 - max(dot(normal, view_dir), 0.0);
		float rim = pow(rim_factor, rim_power) * rim_intensity;

		// Composite lighting
		float total_light = ambient + diffuse * (1.0 - ambient);
		vec3 base_color = color_tint.rgb * height;
		vec3 final_color = min(base_color * total_light + vec3(spec + rim), vec3(1.0));

		COLOR = vec4(final_color, tex.a * color_tint.a);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
