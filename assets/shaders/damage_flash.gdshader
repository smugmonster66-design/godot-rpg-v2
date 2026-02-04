shader_type canvas_item;

// Flash color (typically white or red for damage)
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Flash intensity: 0.0 = normal, 1.0 = fully flash_color
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

// Optional: preserve original alpha (set false for solid color flash)
uniform bool preserve_alpha = true;

// Optional: additive mode (brightens instead of replacing)
uniform bool additive_mode = false;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	
	if (additive_mode) {
		// Additive: adds flash color on top (good for glow/highlight)
		vec3 flash = original.rgb + (flash_color.rgb * flash_intensity);
		COLOR = vec4(flash, original.a);
	} else {
		// Replace: lerps toward flash color (good for solid hit flash)
		vec3 flash = mix(original.rgb, flash_color.rgb, flash_intensity);
		
		if (preserve_alpha) {
			COLOR = vec4(flash, original.a);
		} else {
			float alpha = mix(original.a, flash_color.a, flash_intensity);
			COLOR = vec4(flash, alpha);
		}
	}
}
