@tool
extends EditorScript

## Run this once in Godot (Script > Run) to create the siphon scatter preset.
## After running, the .tres file will exist and siphon_roll_visual.tres can reference it.

func _run():
	var preset = ScatterConvergePreset.new()
	
	# Particles
	preset.particle_count = 8
	preset.particle_size = Vector2(22, 22)
	
	# Scatter Phase
	preset.scatter_duration = 0.15
	preset.scatter_radius_min = 20.0
	preset.scatter_radius_max = 50.0
	preset.scatter_spread_deg = 100.0
	
	# Directional Bias
	preset.directional_bias = 0.5
	
	# Hang Phase
	preset.hang_duration = 0.1
	preset.hang_drift = 2.0
	preset.hang_breathe = 0.08
	
	# Converge Phase
	preset.converge_duration = 0.25
	preset.converge_stagger = 0.02
	preset.converge_shrink = 0.4
	preset.converge_spin_accel = 1.5
	
	# Trails
	preset.trails_enabled = true
	preset.trail_count = 2
	preset.trail_interval = 0.05
	preset.trail_fade_duration = 0.1
	
	# Impact Flash
	preset.impact_flash_enabled = true
	preset.impact_flash_scale = 1.3
	preset.impact_flash_duration = 0.12
	
	# Base Shape
	preset.base_shape_enabled = true
	preset.base_shape_opacity = 0.6
	
	# Additive Blend
	preset.additive_blend = true
	
	# Impact Threshold
	preset.impact_threshold = 0.7
	
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("res://resources/effects")
	
	var err = ResourceSaver.save(preset, "res://resources/effects/siphon_scatter_preset.tres")
	if err == OK:
		print("✅ Siphon scatter preset saved to res://resources/effects/siphon_scatter_preset.tres")
	else:
		print("❌ Failed to save preset: error %d" % err)
