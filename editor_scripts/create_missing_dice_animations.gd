# res://editor_scripts/create_missing_dice_animations.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Creates the 3 missing animation presets + reactions for dice affixes:
#   - DIE_LOCKED
#   - DIE_ROLLED
#   - DIE_DESTROYED
@tool
extends EditorScript

const PRESET_DIR := "res://resources/effects/micro_presets/"
const REACTION_DIR := "res://resources/effects/reactions/"

func _run() -> void:
	print("🎬 Creating missing dice animation presets...")
	
	# Load required scripts
	var preset_script = load("res://resources/data/micro_animation_preset.gd")
	var reaction_script = load("res://resources/data/animation_reaction.gd")
	var event_script = load("res://scripts/combat/combat_event.gd")
	
	if not preset_script or not reaction_script or not event_script:
		print("❌ Failed to load required scripts")
		return
	
	# ================================================================
	# PRESETS
	# ================================================================
	
	# --- Die locked: golden flash + slight shrink ---
	var die_locked = preset_script.new()
	die_locked.scale_enabled = true
	die_locked.scale_peak = Vector2(0.95, 0.95)
	die_locked.scale_out_duration = 0.08
	die_locked.scale_in_duration = 0.15
	die_locked.flash_enabled = true
	die_locked.flash_color = Color(1.0, 0.9, 0.3)  # Golden
	die_locked.flash_in_duration = 0.06
	die_locked.flash_out_duration = 0.25
	_save(die_locked, PRESET_DIR + "die_locked.tres")
	
	# --- Die rolled: spin effect + bright flash ---
	var die_rolled = preset_script.new()
	die_rolled.scale_enabled = true
	die_rolled.scale_peak = Vector2(1.15, 1.15)
	die_rolled.scale_out_duration = 0.1
	die_rolled.scale_in_duration = 0.2
	die_rolled.flash_enabled = true
	die_rolled.flash_color = Color(1.2, 1.2, 1.5)  # Bright white-blue
	die_rolled.flash_in_duration = 0.05
	die_rolled.flash_out_duration = 0.2
	_save(die_rolled, PRESET_DIR + "die_rolled.tres")
	
	# --- Die destroyed: shrink to zero + fade ---
	var die_destroyed = preset_script.new()
	die_destroyed.scale_enabled = true
	die_destroyed.scale_peak = Vector2(0.0, 0.0)
	die_destroyed.scale_out_duration = 0.0
	die_destroyed.scale_in_duration = 0.35
	die_destroyed.scale_ease = Tween.EASE_IN
	die_destroyed.scale_trans = Tween.TRANS_BACK
	die_destroyed.flash_enabled = true
	die_destroyed.flash_color = Color(0.0, 0.0, 0.0, 0.0)  # Fade to black
	die_destroyed.flash_in_duration = 0.35
	die_destroyed.screen_shake_enabled = true
	die_destroyed.screen_shake_intensity = 2.0
	die_destroyed.screen_shake_duration = 0.15
	_save(die_destroyed, PRESET_DIR + "die_destroyed.tres")
	
	# ================================================================
	# REACTIONS
	# ================================================================
	
	var Type = event_script.get("Type")
	if not Type:
		print("❌ Failed to get CombatEvent.Type enum")
		return
	
	# DIE_LOCKED reaction
	var r_locked = reaction_script.new()
	r_locked.event_type = Type.DIE_LOCKED
	r_locked.animation_preset = die_locked
	r_locked.priority = 10
	_save(r_locked, REACTION_DIR + "die_locked.tres")
	
	# DIE_ROLLED reaction
	var r_rolled = reaction_script.new()
	r_rolled.event_type = Type.DIE_ROLLED
	r_rolled.animation_preset = die_rolled
	r_rolled.priority = 10
	_save(r_rolled, REACTION_DIR + "die_rolled.tres")
	
	# DIE_DESTROYED reaction
	var r_destroyed = reaction_script.new()
	r_destroyed.event_type = Type.DIE_DESTROYED
	r_destroyed.animation_preset = die_destroyed
	r_destroyed.priority = 15
	_save(r_destroyed, REACTION_DIR + "die_destroyed.tres")
	
	print("")
	print("✅ Created 3 presets and 3 reactions!")
	print("   📁 Presets: %s" % PRESET_DIR)
	print("   📁 Reactions: %s" % REACTION_DIR)
	print("")
	print("Next step: Load these reactions in ReactiveAnimator (CombatUI or scene)")


func _save(resource: Resource, path: String):
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		print("  💾 %s" % path)
	else:
		print("  ❌ Save failed: %s (error %d)" % [path, err])
