shader_type canvas_item;

// Shock element stroke - crackling arcs along edges
uniform vec4 arc_color : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform vec4 spark_color : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform float arc_speed : hint_range(1.0, 6.0) = 4.0;
uniform float arc_intensity : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Fast random arcs
	float time_step = floor(TIME * arc_speed);
	float arc_seed = hash(vec2(time_step, UV.x * 10.0));
	float arc_seed2 = hash(vec2(time_step + 0.5, UV.y * 10.0));
	
	// Arc pattern along edge
	float arc1 = step(0.85, arc_seed) * step(0.3, fract(UV.y * 5.0 + arc_seed));
	float arc2 = step(0.85, arc_seed2) * step(0.3, fract(UV.x * 5.0 + arc_seed2));
	float arcs = max(arc1, arc2);
	
	// Continuous glow
	float glow = sin(TIME * arc_speed * 0.5 + UV.x * 10.0) * 0.5 + 0.5;
	glow *= sin(TIME * arc_speed * 0.7 + UV.y * 8.0) * 0.5 + 0.5;
	
	// Combine
	vec3 color = arc_color.rgb * tex_color.rgb;
	color = mix(color, spark_color.rgb, arcs * arc_intensity);
	color += arc_color.rgb * glow * 0.2;
	
	COLOR = vec4(color, tex_color.a);
}
