# res://editor_scripts/fix_create_reactions.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# FIX SCRIPT: The original create_reactive_animation_presets.gd silently
# aborted when assigning plain Arrays to typed Array[ReactionCondition]
# properties. This script loads the already-created conditions and presets
# from disk and wires them into the 14 reaction .tres files using .assign()
# to satisfy Godot 4.x typed array requirements.
#
# SAFE TO RE-RUN: Overwrites existing reaction files.
@tool
extends EditorScript

const PRESET_DIR := "res://resources/effects/micro_presets/"
const REACTION_DIR := "res://resources/effects/reactions/"
const CONDITION_DIR := "res://resources/effects/conditions/"

# Preload scripts to avoid class_name resolution issues in @tool EditorScript
var _reaction_script = load("res://resources/data/animation_reaction.gd")
var _condition_script = load("res://resources/data/reaction_condition.gd")
var _combat_event_script = load("res://scripts/combat/combat_event.gd")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(REACTION_DIR)

	print("🔧 Fix: Creating reaction .tres files...")
	print("   (Loading existing conditions and presets from disk)")

	# ================================================================
	# LOAD CONDITIONS
	# ================================================================
	var cond_delta_positive = _load_or_warn(CONDITION_DIR + "delta_positive.tres")
	var cond_delta_negative = _load_or_warn(CONDITION_DIR + "delta_negative.tres")
	var _cond_is_crit = _load_or_warn(CONDITION_DIR + "is_crit.tres")
	var _cond_big_hit = _load_or_warn(CONDITION_DIR + "big_hit.tres")

	# ================================================================
	# LOAD PRESETS
	# ================================================================
	var die_grow = _load_or_warn(PRESET_DIR + "die_value_grew.tres")
	var die_shrink = _load_or_warn(PRESET_DIR + "die_value_shrunk.tres")
	var damage_hit = _load_or_warn(PRESET_DIR + "damage_dealt.tres")
	var crit_hit = _load_or_warn(PRESET_DIR + "crit_hit.tres")
	var heal = _load_or_warn(PRESET_DIR + "heal_applied.tres")
	var status_applied = _load_or_warn(PRESET_DIR + "status_applied.tres")
	var status_tick = _load_or_warn(PRESET_DIR + "status_tick.tres")
	var shield = _load_or_warn(PRESET_DIR + "shield_gained.tres")
	var shield_break = _load_or_warn(PRESET_DIR + "shield_broken.tres")
	var die_consumed = _load_or_warn(PRESET_DIR + "die_consumed.tres")
	var die_created = _load_or_warn(PRESET_DIR + "die_created.tres")
	var enemy_died = _load_or_warn(PRESET_DIR + "enemy_died.tres")
	var mana_gain = _load_or_warn(PRESET_DIR + "mana_gained.tres")
	var mana_spent = _load_or_warn(PRESET_DIR + "mana_spent.tres")

	# Bail if any critical resources are missing
	if not die_grow or not cond_delta_positive:
		print("❌ Missing presets or conditions. Run create_reactive_animation_presets.gd first.")
		return

	# ================================================================
	# REACTIONS — using .assign() for typed Array[ReactionCondition]
	# ================================================================
	var counter := 0

	# --- Die value grew ---
	var r_die_grow = _reaction_script.new()
	r_die_grow.event_type = _get_event_type("DIE_VALUE_CHANGED")
	r_die_grow.conditions.assign([cond_delta_positive])
	r_die_grow.animation_preset = die_grow
	r_die_grow.priority = 10
	if _save(r_die_grow, REACTION_DIR + "die_value_grew.tres"):
		counter += 1

	# --- Die value shrunk ---
	var r_die_shrink = _reaction_script.new()
	r_die_shrink.event_type = _get_event_type("DIE_VALUE_CHANGED")
	r_die_shrink.conditions.assign([cond_delta_negative])
	r_die_shrink.animation_preset = die_shrink
	r_die_shrink.priority = 10
	if _save(r_die_shrink, REACTION_DIR + "die_value_shrunk.tres"):
		counter += 1

	# --- Damage dealt ---
	var r_damage = _reaction_script.new()
	r_damage.event_type = _get_event_type("DAMAGE_DEALT")
	r_damage.animation_preset = damage_hit
	r_damage.priority = 10
	if _save(r_damage, REACTION_DIR + "damage_dealt.tres"):
		counter += 1

	# --- Critical hit (layers on top of damage_dealt) ---
	var r_crit = _reaction_script.new()
	r_crit.event_type = _get_event_type("CRIT_LANDED")
	r_crit.animation_preset = crit_hit
	r_crit.priority = 20
	if _save(r_crit, REACTION_DIR + "crit_landed.tres"):
		counter += 1

	# --- Heal applied ---
	var r_heal = _reaction_script.new()
	r_heal.event_type = _get_event_type("HEAL_APPLIED")
	r_heal.animation_preset = heal
	r_heal.priority = 10
	if _save(r_heal, REACTION_DIR + "heal_applied.tres"):
		counter += 1

	# --- Status applied ---
	var r_status = _reaction_script.new()
	r_status.event_type = _get_event_type("STATUS_APPLIED")
	r_status.animation_preset = status_applied
	r_status.priority = 5
	if _save(r_status, REACTION_DIR + "status_applied.tres"):
		counter += 1

	# --- Status ticked ---
	var r_tick = _reaction_script.new()
	r_tick.event_type = _get_event_type("STATUS_TICKED")
	r_tick.animation_preset = status_tick
	r_tick.priority = 5
	if _save(r_tick, REACTION_DIR + "status_ticked.tres"):
		counter += 1

	# --- Shield gained ---
	var r_shield = _reaction_script.new()
	r_shield.event_type = _get_event_type("SHIELD_GAINED")
	r_shield.animation_preset = shield
	r_shield.priority = 10
	if _save(r_shield, REACTION_DIR + "shield_gained.tres"):
		counter += 1

	# --- Shield broken ---
	var r_shield_break = _reaction_script.new()
	r_shield_break.event_type = _get_event_type("SHIELD_BROKEN")
	r_shield_break.animation_preset = shield_break
	r_shield_break.priority = 15
	if _save(r_shield_break, REACTION_DIR + "shield_broken.tres"):
		counter += 1

	# --- Die consumed ---
	var r_consumed = _reaction_script.new()
	r_consumed.event_type = _get_event_type("DIE_CONSUMED")
	r_consumed.animation_preset = die_consumed
	r_consumed.priority = 5
	if _save(r_consumed, REACTION_DIR + "die_consumed.tres"):
		counter += 1

	# --- Die created (mana pull) ---
	var r_created = _reaction_script.new()
	r_created.event_type = _get_event_type("DIE_CREATED")
	r_created.animation_preset = die_created
	r_created.priority = 10
	if _save(r_created, REACTION_DIR + "die_created.tres"):
		counter += 1

	# --- Enemy died ---
	var r_enemy_died = _reaction_script.new()
	r_enemy_died.event_type = _get_event_type("ENEMY_DIED")
	r_enemy_died.animation_preset = enemy_died
	r_enemy_died.priority = 20
	if _save(r_enemy_died, REACTION_DIR + "enemy_died.tres"):
		counter += 1

	# --- Mana gained (delta > 0) ---
	var r_mana_gain = _reaction_script.new()
	r_mana_gain.event_type = _get_event_type("MANA_CHANGED")
	r_mana_gain.conditions.assign([cond_delta_positive])
	r_mana_gain.animation_preset = mana_gain
	r_mana_gain.priority = 5
	if _save(r_mana_gain, REACTION_DIR + "mana_gained.tres"):
		counter += 1

	# --- Mana spent (delta < 0) ---
	var r_mana_spent = _reaction_script.new()
	r_mana_spent.event_type = _get_event_type("MANA_CHANGED")
	r_mana_spent.conditions.assign([cond_delta_negative])
	r_mana_spent.animation_preset = mana_spent
	r_mana_spent.priority = 5
	if _save(r_mana_spent, REACTION_DIR + "mana_spent.tres"):
		counter += 1

	# ================================================================
	# SUMMARY
	# ================================================================
	print("")
	if counter == 14:
		print("✅ All 14 reaction .tres files created successfully!")
	else:
		print("⚠️ Created %d/14 reactions. Check errors above." % counter)
	print("   📁 %s" % REACTION_DIR)
	print("")
	print("ReactiveAnimator should now initialize with 14 reactions.")
	print("Enter combat and check for: ✅ ReactiveAnimator initialized with 14 reactions")


# ============================================================================
# HELPERS
# ============================================================================

func _get_event_type(type_name: String) -> int:
	"""Resolve CombatEvent.Type enum value by name.
	Uses the loaded script to avoid class_name resolution issues."""
	var type_enum = _combat_event_script.get("Type")
	if type_enum and type_enum.has(type_name):
		return type_enum[type_name]
	# Fallback: manual lookup from the enum order in combat_event.gd
	var fallback := {
		"DIE_VALUE_CHANGED": 0,
		"DIE_CONSUMED": 1,
		"DIE_CREATED": 2,
		"DIE_LOCKED": 3,
		"DIE_UNLOCKED": 4,
		"DIE_DESTROYED": 5,
		"DIE_ROLLED": 6,
		"DAMAGE_DEALT": 7,
		"HEAL_APPLIED": 8,
		"CRIT_LANDED": 9,
		"OVERKILL": 10,
		"MISS": 11,
		"RESIST_TRIGGERED": 12,
		"STATUS_APPLIED": 13,
		"STATUS_TICKED": 14,
		"STATUS_REMOVED": 15,
		"STATUS_STACKS_CHANGED": 16,
		"SHIELD_GAINED": 17,
		"SHIELD_BROKEN": 18,
		"SHIELD_CONSUMED": 19,
		"MANA_CHANGED": 20,
		"MANA_DEPLETED": 21,
		"CHARGE_USED": 22,
		"CHARGE_RESTORED": 23,
		"ENEMY_DIED": 24,
		"PLAYER_DIED": 25,
		"ENEMY_SPAWNED": 26,
		"TURN_STARTED": 27,
		"TURN_ENDED": 28,
		"ROUND_STARTED": 29,
		"ACTION_CONFIRMED": 30,
		"COMBAT_STARTED": 31,
		"COMBAT_ENDED": 32,
		"AFFIX_TRIGGERED": 33,
		"THRESHOLD_REACHED": 34,
		"ELEMENT_COMBO": 35,
		"BATTLEFIELD_EFFECT": 36,
	}
	if fallback.has(type_name):
		print("    ℹ️ Using fallback enum value for %s = %d" % [type_name, fallback[type_name]])
		return fallback[type_name]
	push_error("Unknown CombatEvent.Type: %s" % type_name)
	return 0


func _load_or_warn(path: String) -> Resource:
	"""Load a resource or print a warning."""
	if not ResourceLoader.exists(path):
		print("  ⚠️ Missing: %s" % path)
		return null
	var res = load(path)
	if res:
		print("  ✓ Loaded: %s" % path)
	else:
		print("  ⚠️ Failed to load: %s" % path)
	return res


func _save(resource: Resource, path: String) -> bool:
	"""Save a resource and report success/failure."""
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		print("  💾 %s" % path)
		return true
	else:
		print("  ❌ Save failed: %s (error %d)" % [path, err])
		return false
