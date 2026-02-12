# res://editor_scripts/create_reactive_animation_presets.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Creates starter MicroAnimationPreset + AnimationReaction .tres files
# for the most common combat events. These serve as a working baseline
# you can tune in the inspector.
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
@tool
extends EditorScript

const PRESET_DIR := "res://resources/effects/micro_presets/"
const REACTION_DIR := "res://resources/effects/reactions/"
const CONDITION_DIR := "res://resources/effects/conditions/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PRESET_DIR)
	DirAccess.make_dir_recursive_absolute(REACTION_DIR)
	DirAccess.make_dir_recursive_absolute(CONDITION_DIR)

	print("🎬 Creating reactive animation presets...")

	# ================================================================
	# CONDITIONS
	# ================================================================

	# delta > 0 (value increased)
	var cond_delta_positive = ReactionCondition.new()
	cond_delta_positive.key = "delta"
	cond_delta_positive.operator = ReactionCondition.Operator.GREATER_THAN
	cond_delta_positive.compare_number = 0
	_save(cond_delta_positive, CONDITION_DIR + "delta_positive.tres")

	# delta < 0 (value decreased)
	var cond_delta_negative = ReactionCondition.new()
	cond_delta_negative.key = "delta"
	cond_delta_negative.operator = ReactionCondition.Operator.LESS_THAN
	cond_delta_negative.compare_number = 0
	_save(cond_delta_negative, CONDITION_DIR + "delta_negative.tres")

	# is_crit == true
	var cond_is_crit = ReactionCondition.new()
	cond_is_crit.key = "is_crit"
	cond_is_crit.operator = ReactionCondition.Operator.IS_TRUE
	_save(cond_is_crit, CONDITION_DIR + "is_crit.tres")

	# amount >= 10 (big hit)
	var cond_big_hit = ReactionCondition.new()
	cond_big_hit.key = "amount"
	cond_big_hit.operator = ReactionCondition.Operator.GREATER_EQUAL
	cond_big_hit.compare_number = 10
	_save(cond_big_hit, CONDITION_DIR + "big_hit.tres")

	# ================================================================
	# PRESETS
	# ================================================================

	# --- Die value grew: green flash + scale pop + "+N" label ---
	var die_grow = MicroAnimationPreset.new()
	die_grow.scale_enabled = true
	die_grow.scale_peak = Vector2(1.3, 1.3)
	die_grow.scale_out_duration = 0.08
	die_grow.scale_in_duration = 0.18
	die_grow.scale_trans = Tween.TRANS_BACK
	die_grow.flash_enabled = true
	die_grow.flash_color = Color(0.5, 1.5, 0.5)  # Green
	die_grow.flash_in_duration = 0.06
	die_grow.flash_out_duration = 0.2
	die_grow.label_enabled = true
	die_grow.label_color = Color(0.4, 1.0, 0.4)
	die_grow.label_font_size = 20
	die_grow.label_rise_distance = 35.0
	die_grow.label_duration = 0.6
	_save(die_grow, PRESET_DIR + "die_value_grew.tres")

	# --- Die value shrunk: red flash + slight shrink + "-N" label ---
	var die_shrink = MicroAnimationPreset.new()
	die_shrink.scale_enabled = true
	die_shrink.scale_peak = Vector2(0.85, 0.85)
	die_shrink.scale_out_duration = 0.06
	die_shrink.scale_in_duration = 0.2
	die_shrink.scale_trans = Tween.TRANS_BACK
	die_shrink.flash_enabled = true
	die_shrink.flash_color = Color(1.5, 0.4, 0.4)  # Red
	die_shrink.flash_in_duration = 0.06
	die_shrink.flash_out_duration = 0.2
	die_shrink.label_enabled = true
	die_shrink.label_color = Color(1.0, 0.3, 0.3)
	die_shrink.label_font_size = 18
	die_shrink.label_rise_distance = 30.0
	die_shrink.label_duration = 0.5
	_save(die_shrink, PRESET_DIR + "die_value_shrunk.tres")

	# --- Damage dealt: red flash + shake + floating damage number ---
	var damage_hit = MicroAnimationPreset.new()
	damage_hit.flash_enabled = true
	damage_hit.flash_color = Color(1.6, 0.3, 0.3)  # Bright red
	damage_hit.flash_in_duration = 0.04
	damage_hit.flash_out_duration = 0.25
	damage_hit.shake_enabled = true
	damage_hit.shake_intensity = 3.0
	damage_hit.shake_duration = 0.15
	damage_hit.shake_count = 4
	damage_hit.shake_decay = true
	damage_hit.label_enabled = true
	damage_hit.label_color = Color(1.0, 0.2, 0.2)
	damage_hit.label_font_size = 26
	damage_hit.label_bold = true
	damage_hit.label_rise_distance = 45.0
	damage_hit.label_duration = 0.8
	damage_hit.label_scatter_x = 10.0
	_save(damage_hit, PRESET_DIR + "damage_dealt.tres")

	# --- Critical hit: BIG scale pop + screen shake + bright flash ---
	var crit_hit = MicroAnimationPreset.new()
	crit_hit.scale_enabled = true
	crit_hit.scale_peak = Vector2(1.4, 1.4)
	crit_hit.scale_out_duration = 0.06
	crit_hit.scale_in_duration = 0.25
	crit_hit.scale_trans = Tween.TRANS_BACK
	crit_hit.flash_enabled = true
	crit_hit.flash_color = Color(2.0, 1.8, 0.3)  # Bright gold
	crit_hit.flash_in_duration = 0.04
	crit_hit.flash_out_duration = 0.3
	crit_hit.screen_shake_enabled = true
	crit_hit.screen_shake_intensity = 8.0
	crit_hit.screen_shake_duration = 0.2
	crit_hit.label_enabled = true
	crit_hit.label_text = "CRIT!"
	crit_hit.label_color = Color(1.0, 0.9, 0.2)
	crit_hit.label_font_size = 32
	crit_hit.label_bold = true
	crit_hit.label_rise_distance = 55.0
	crit_hit.label_duration = 1.0
	crit_hit.label_start_scale = 1.4
	crit_hit.label_end_scale = 0.9
	_save(crit_hit, PRESET_DIR + "crit_hit.tres")

	# --- Heal applied: green flash + floating heal number ---
	var heal = MicroAnimationPreset.new()
	heal.flash_enabled = true
	heal.flash_color = Color(0.3, 1.5, 0.5)  # Green
	heal.flash_in_duration = 0.06
	heal.flash_out_duration = 0.3
	heal.label_enabled = true
	heal.label_color = Color(0.3, 1.0, 0.4)
	heal.label_font_size = 24
	heal.label_rise_distance = 40.0
	heal.label_duration = 0.7
	_save(heal, PRESET_DIR + "heal_applied.tres")

	# --- Status applied: purple flash + scale pop ---
	var status_applied = MicroAnimationPreset.new()
	status_applied.scale_enabled = true
	status_applied.scale_peak = Vector2(1.15, 1.15)
	status_applied.scale_out_duration = 0.08
	status_applied.scale_in_duration = 0.15
	status_applied.flash_enabled = true
	status_applied.flash_color = Color(1.2, 0.5, 1.5)  # Purple
	status_applied.flash_in_duration = 0.06
	status_applied.flash_out_duration = 0.25
	status_applied.label_enabled = true
	status_applied.label_color = Color(0.9, 0.6, 1.0)
	status_applied.label_font_size = 18
	status_applied.label_rise_distance = 30.0
	status_applied.label_duration = 0.8
	_save(status_applied, PRESET_DIR + "status_applied.tres")

	# --- Status ticked (DoT damage): subtle red flash + small number ---
	var status_tick = MicroAnimationPreset.new()
	status_tick.flash_enabled = true
	status_tick.flash_color = Color(1.3, 0.6, 0.3)  # Orange-red
	status_tick.flash_in_duration = 0.08
	status_tick.flash_out_duration = 0.2
	status_tick.label_enabled = true
	status_tick.label_color = Color(1.0, 0.5, 0.2)
	status_tick.label_font_size = 18
	status_tick.label_rise_distance = 25.0
	status_tick.label_duration = 0.5
	_save(status_tick, PRESET_DIR + "status_ticked.tres")

	# --- Shield gained: blue flash + scale pop ---
	var shield = MicroAnimationPreset.new()
	shield.scale_enabled = true
	shield.scale_peak = Vector2(1.2, 1.2)
	shield.scale_out_duration = 0.1
	shield.scale_in_duration = 0.2
	shield.flash_enabled = true
	shield.flash_color = Color(0.5, 0.8, 1.5)  # Blue
	shield.flash_in_duration = 0.08
	shield.flash_out_duration = 0.3
	shield.label_enabled = true
	shield.label_color = Color(0.5, 0.8, 1.0)
	shield.label_font_size = 22
	shield.label_rise_distance = 35.0
	shield.label_duration = 0.6
	_save(shield, PRESET_DIR + "shield_gained.tres")

	# --- Shield broken: shake + bright flash ---
	var shield_break = MicroAnimationPreset.new()
	shield_break.shake_enabled = true
	shield_break.shake_intensity = 5.0
	shield_break.shake_duration = 0.2
	shield_break.shake_count = 6
	shield_break.flash_enabled = true
	shield_break.flash_color = Color(0.8, 1.2, 1.8)  # Bright blue-white
	shield_break.flash_in_duration = 0.04
	shield_break.flash_out_duration = 0.3
	shield_break.label_enabled = true
	shield_break.label_text = "BROKEN!"
	shield_break.label_color = Color(0.6, 0.9, 1.0)
	shield_break.label_font_size = 22
	shield_break.label_bold = true
	shield_break.label_rise_distance = 40.0
	shield_break.label_duration = 0.8
	_save(shield_break, PRESET_DIR + "shield_broken.tres")

	# --- Die consumed: fade + shrink (subtle) ---
	var die_consumed = MicroAnimationPreset.new()
	die_consumed.scale_enabled = true
	die_consumed.scale_peak = Vector2(0.9, 0.9)
	die_consumed.scale_out_duration = 0.1
	die_consumed.scale_in_duration = 0.0  # Don't bounce back
	die_consumed.flash_enabled = true
	die_consumed.flash_color = Color(0.7, 0.7, 0.7)  # Dim
	die_consumed.flash_in_duration = 0.1
	die_consumed.flash_out_duration = 0.0
	_save(die_consumed, PRESET_DIR + "die_consumed.tres")

	# --- Die created (mana pull): bright pop-in ---
	var die_created = MicroAnimationPreset.new()
	die_created.scale_enabled = true
	die_created.scale_peak = Vector2(1.4, 1.4)
	die_created.scale_out_duration = 0.05
	die_created.scale_in_duration = 0.2
	die_created.scale_trans = Tween.TRANS_BACK
	die_created.flash_enabled = true
	die_created.flash_color = Color(0.6, 0.8, 1.8)  # Mana blue
	die_created.flash_in_duration = 0.05
	die_created.flash_out_duration = 0.25
	_save(die_created, PRESET_DIR + "die_created.tres")

	# --- Enemy died: big shake + flash ---
	var enemy_died = MicroAnimationPreset.new()
	enemy_died.shake_enabled = true
	enemy_died.shake_intensity = 6.0
	enemy_died.shake_duration = 0.25
	enemy_died.shake_count = 8
	enemy_died.flash_enabled = true
	enemy_died.flash_color = Color(2.0, 2.0, 2.0)  # White-out
	enemy_died.flash_in_duration = 0.04
	enemy_died.flash_out_duration = 0.4
	enemy_died.screen_shake_enabled = true
	enemy_died.screen_shake_intensity = 5.0
	enemy_died.screen_shake_duration = 0.15
	_save(enemy_died, PRESET_DIR + "enemy_died.tres")

	# --- Mana gained: blue pulse ---
	var mana_gain = MicroAnimationPreset.new()
	mana_gain.scale_enabled = true
	mana_gain.scale_peak = Vector2(1.15, 1.15)
	mana_gain.scale_out_duration = 0.08
	mana_gain.scale_in_duration = 0.15
	mana_gain.flash_enabled = true
	mana_gain.flash_color = Color(0.4, 0.6, 1.6)  # Blue
	mana_gain.flash_in_duration = 0.06
	mana_gain.flash_out_duration = 0.2
	mana_gain.label_enabled = true
	mana_gain.label_color = Color(0.4, 0.6, 1.0)
	mana_gain.label_font_size = 18
	mana_gain.label_rise_distance = 25.0
	mana_gain.label_duration = 0.5
	_save(mana_gain, PRESET_DIR + "mana_gained.tres")

	# --- Mana spent: subtle dim ---
	var mana_spent = MicroAnimationPreset.new()
	mana_spent.flash_enabled = true
	mana_spent.flash_color = Color(0.5, 0.5, 0.8)
	mana_spent.flash_in_duration = 0.06
	mana_spent.flash_out_duration = 0.15
	_save(mana_spent, PRESET_DIR + "mana_spent.tres")

	# ================================================================
	# REACTIONS (wiring events → presets + conditions)
	# ================================================================

	# Die value grew
	var r_die_grow = AnimationReaction.new()
	r_die_grow.event_type = CombatEvent.Type.DIE_VALUE_CHANGED
	r_die_grow.conditions = [cond_delta_positive]
	r_die_grow.animation_preset = die_grow
	r_die_grow.priority = 10
	_save(r_die_grow, REACTION_DIR + "die_value_grew.tres")

	# Die value shrunk
	var r_die_shrink = AnimationReaction.new()
	r_die_shrink.event_type = CombatEvent.Type.DIE_VALUE_CHANGED
	r_die_shrink.conditions = [cond_delta_negative]
	r_die_shrink.animation_preset = die_shrink
	r_die_shrink.priority = 10
	_save(r_die_shrink, REACTION_DIR + "die_value_shrunk.tres")

	# Damage dealt
	var r_damage = AnimationReaction.new()
	r_damage.event_type = CombatEvent.Type.DAMAGE_DEALT
	r_damage.animation_preset = damage_hit
	r_damage.priority = 10
	_save(r_damage, REACTION_DIR + "damage_dealt.tres")

	# Critical hit (layers ON TOP of damage_dealt)
	var r_crit = AnimationReaction.new()
	r_crit.event_type = CombatEvent.Type.CRIT_LANDED
	r_crit.animation_preset = crit_hit
	r_crit.priority = 20  # Higher than damage so it plays first visually
	_save(r_crit, REACTION_DIR + "crit_landed.tres")

	# Heal
	var r_heal = AnimationReaction.new()
	r_heal.event_type = CombatEvent.Type.HEAL_APPLIED
	r_heal.animation_preset = heal
	r_heal.priority = 10
	_save(r_heal, REACTION_DIR + "heal_applied.tres")

	# Status applied
	var r_status = AnimationReaction.new()
	r_status.event_type = CombatEvent.Type.STATUS_APPLIED
	r_status.animation_preset = status_applied
	r_status.priority = 5
	_save(r_status, REACTION_DIR + "status_applied.tres")

	# Status ticked
	var r_tick = AnimationReaction.new()
	r_tick.event_type = CombatEvent.Type.STATUS_TICKED
	r_tick.animation_preset = status_tick
	r_tick.priority = 5
	_save(r_tick, REACTION_DIR + "status_ticked.tres")

	# Shield gained
	var r_shield = AnimationReaction.new()
	r_shield.event_type = CombatEvent.Type.SHIELD_GAINED
	r_shield.animation_preset = shield
	r_shield.priority = 10
	_save(r_shield, REACTION_DIR + "shield_gained.tres")

	# Shield broken
	var r_shield_break = AnimationReaction.new()
	r_shield_break.event_type = CombatEvent.Type.SHIELD_BROKEN
	r_shield_break.animation_preset = shield_break
	r_shield_break.priority = 15
	_save(r_shield_break, REACTION_DIR + "shield_broken.tres")

	# Die consumed
	var r_consumed = AnimationReaction.new()
	r_consumed.event_type = CombatEvent.Type.DIE_CONSUMED
	r_consumed.animation_preset = die_consumed
	r_consumed.priority = 5
	_save(r_consumed, REACTION_DIR + "die_consumed.tres")

	# Die created (mana pull)
	var r_created = AnimationReaction.new()
	r_created.event_type = CombatEvent.Type.DIE_CREATED
	r_created.animation_preset = die_created
	r_created.priority = 10
	_save(r_created, REACTION_DIR + "die_created.tres")

	# Enemy died
	var r_enemy_died = AnimationReaction.new()
	r_enemy_died.event_type = CombatEvent.Type.ENEMY_DIED
	r_enemy_died.animation_preset = enemy_died
	r_enemy_died.priority = 20
	_save(r_enemy_died, REACTION_DIR + "enemy_died.tres")

	# Mana gained (delta > 0)
	var r_mana_gain = AnimationReaction.new()
	r_mana_gain.event_type = CombatEvent.Type.MANA_CHANGED
	r_mana_gain.conditions = [cond_delta_positive]
	r_mana_gain.animation_preset = mana_gain
	r_mana_gain.priority = 5
	_save(r_mana_gain, REACTION_DIR + "mana_gained.tres")

	# Mana spent (delta < 0)
	var r_mana_spent = AnimationReaction.new()
	r_mana_spent.event_type = CombatEvent.Type.MANA_CHANGED
	r_mana_spent.conditions = [cond_delta_negative]
	r_mana_spent.animation_preset = mana_spent
	r_mana_spent.priority = 5
	_save(r_mana_spent, REACTION_DIR + "mana_spent.tres")

	# ================================================================
	# SUMMARY
	# ================================================================
	print("")
	print("✅ Reactive animation presets created!")
	print("   📁 %s — %d presets" % [PRESET_DIR, 14])
	print("   📁 %s — %d reactions" % [REACTION_DIR, 14])
	print("   📁 %s — %d conditions" % [CONDITION_DIR, 4])
	print("")
	print("Next steps:")
	print("  1. Copy script files to their res:// locations (see integration guide)")
	print("  2. Add CombatEventBus as child of CombatManager")
	print("  3. Add ReactiveAnimator as child of CombatUI")
	print("  4. Drag reaction .tres files into ReactiveAnimator's reactions array")
	print("  5. Wire emit calls into game systems (see guide)")


func _save(resource: Resource, path: String) -> void:
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		print("  💾 %s" % path)
	else:
		print("  ❌ Save failed: %s (error %d)" % [path, err])
