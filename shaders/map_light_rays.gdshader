shader_type canvas_item;

// Procedural god rays / volumetric light effect for the map.
// Renders diagonal bands of light that fade from the light source edge.
// Pure math — no texture lookups, very cheap on mobile.

// Direction light comes FROM (normalized). Rays emanate from this edge of the screen.
uniform vec2 light_direction = vec2(-0.707, -0.707);
// Ray tint color. Alpha controls base transparency of the ray bands.
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.8, 0.3);
// Intensity multiplier.
uniform float energy : hint_range(0.0, 2.0) = 0.5;
// Number of ray bands across the screen.
uniform float ray_density : hint_range(1.0, 20.0) = 6.0;
// Softness of ray band edges (0 = sharp stripes, 1 = very soft).
uniform float ray_softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 dir = normalize(light_direction);
	vec2 perp = vec2(-dir.y, dir.x);

	// How far along the light direction (0 near source edge, 1 at opposite edge)
	float along = dot(UV - vec2(0.5), dir) + 0.5;
	// Position on the perpendicular axis (drives the stripe pattern)
	float across = dot(UV, perp);

	// Two overlapping sine waves for organic-looking ray bands, slowly drifting
	float t = TIME * 0.02;
	float pattern = sin((across + t) * ray_density * TAU) * 0.5 + 0.5;
	pattern *= sin((across * 1.7 + t * 0.7) * ray_density * 0.6 * TAU) * 0.5 + 0.5;

	// Soften stripe edges
	pattern = smoothstep(0.5 - ray_softness * 0.5, 0.5 + ray_softness * 0.5, pattern);

	// Fade: strongest near the light source edge, fading across the screen
	float fade = smoothstep(1.2, -0.2, along);

	float intensity = pattern * fade * energy;
	COLOR = vec4(ray_color.rgb, ray_color.a * intensity);
}
