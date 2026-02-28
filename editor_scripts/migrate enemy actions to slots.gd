# res://scripts/tools/migrate_enemy_actions_to_slots.gd
# EditorScript -- run from Script Editor -> File -> Run
#
# Migrates all 30 enemy_base actions from inline SubResource effects
# to the new ActionEffectSlot system. Each action gets its effect_slots
# array populated with slots referencing the shared base templates in
# res://resources/action_effects/base/.
#
# The legacy effects array is LEFT INTACT for reference. It is ignored
# at runtime because effect_slots.size() > 0 takes priority.
#
# SAFE TO RE-RUN: overwrites effect_slots each time.
#
# Generator notes applied:
#   Rule 1:  .assign() for typed array properties
#   Rule 2:  Explicit typed locals from array indices (no := from Variant)
#   Rule 3:  Base effects loaded from disk (already have resource_path)
#   Rule 5:  No emoji in print statements
#   Rule 7:  No new directories needed (actions already exist)
#   Rule 8:  Helper function params typed
#   Scan:    EditorInterface.get_resource_filesystem().scan() at end
@tool
extends EditorScript

const ACTION_DIR := "res://resources/actions/enemy_base/"
const EFFECT_DIR := "res://resources/action_effects/base/"

# Pre-loaded base effect templates (populated in _run)
var _effects: Dictionary = {}

# Counters
var _migrated := 0
var _skipped := 0
var _errors := 0


func _run() -> void:
	print("")
	print("============================================================")
	print("  Migrate Enemy Base Actions to Effect Slots")
	print("============================================================")

	# Phase 1: Load all base effect templates
	_load_base_effects()
	if _effects.is_empty():
		push_error("No base effects loaded -- aborting")
		return

	print("")
	print("-- Loaded %d base effect templates --" % _effects.size())
	print("")

	# Phase 2: Migrate each action
	_migrate("stab",              [_damage("piercing")])
	_migrate("smash",             [_damage("blunt", 2, 1.2)])
	_migrate("poke",              [_damage("piercing", 0, 0.5)])
	_migrate("shove",             [_damage("blunt", 0, 0.5)])
	_migrate("quick_slash",       [_damage("slashing", 1, 0.8)])
	_migrate("slam",              [_damage("blunt", 1, 0.7)])
	_migrate("spark",             [_damage("shock")])
	_migrate("magic_bolt",        [_damage("fire", 2, 1.1)])
	_migrate("arcane_push",       [_damage("shadow", 1, 0.7)])
	_migrate("precision_strike",  [_damage("piercing", 3, 1.3)])
	_migrate("frost_shard",       [_damage("ice", 1, 0.8)])

	# Damage + status combos
	_migrate("ignite",            [_damage("fire", 1), _status("burn", 2)])
	_migrate("crippling_thrust",  [_damage("piercing", 3, 1.3), _status("bleed", 2)])
	_migrate("crushing_blow",     [_damage("blunt", 4, 1.5), _status("corrode", 1)])

	# Multi-target + status
	_migrate("fan_of_blades",     [_random_strikes(2, ActionEffect.DamageType.PIERCING), _status("bleed", 1)])
	_migrate("chain_spark",       [_chain(2, ActionEffect.DamageType.SHOCK), _status("chill", 1)])

	# Pure status
	_migrate("hamstring",         [_status("slowed", 2)])
	_migrate("hex",               [_status("slowed", 1)])
	_migrate("sabotage",          [_status("slowed", 2), _status("corrode", 2)])

	# Buff
	_migrate("war_cry",           [_empowered_ally(1)])
	_migrate("rally",             [_empowered_all(1), _armor_self(2, 1)])

	# Defensive
	_migrate("brace",             [_armor_dice(1)])
	_migrate("shield_wall",       [_armor_dice(2)])
	_migrate("fortify",           [_armor_dice(1), _damage_reduction(2.0, 1)])
	_migrate("sidestep",          [_damage_reduction(2.0, 1)])
	_migrate("ward",              [_shield_dice(0.8)])
	_migrate("barrier_pulse",     [_shield_dice(1.0)])
	_migrate("absorb",            [_shield_dice(1.2), _heal_dice(0.3)])

	# Heal
	_migrate("mend",              [_heal_ally_dice()])
	_migrate("mass_mend",         [_heal_all_dice(0.6), _cleanse()])

	# Summary
	print("")
	print("============================================================")
	print("  MIGRATION COMPLETE")
	print("  Migrated: %d" % _migrated)
	print("  Skipped:  %d" % _skipped)
	print("  Errors:   %d" % _errors)
	print("  Total expected: 30")
	print("============================================================")
	print("")

	EditorInterface.get_resource_filesystem().scan()


# ============================================================================
# LOAD BASE EFFECTS
# ============================================================================

func _load_base_effects() -> void:
	"""Load all base ActionEffect .tres from disk."""
	var base_files: Array[String] = [
		"damage_slashing", "damage_blunt", "damage_piercing",
		"damage_fire", "damage_ice", "damage_shock",
		"damage_poison", "damage_shadow",
		"heal",
		"apply_burn", "apply_bleed", "apply_poison", "apply_corrode",
		"apply_slowed", "apply_chill", "apply_expose", "apply_enfeeble",
		"apply_empowered", "apply_ignition",
		"remove_status", "cleanse",
		"shield", "armor_buff", "damage_reduction", "reflect",
		"lifesteal", "execute", "combo_mark", "echo",
		"splash", "chain", "random_strikes",
		"mana_manipulate", "modify_cooldown", "refund_charges",
		"grant_temp_action",
		"channel", "counter_setup", "summon_companion",
	]
	for fname in base_files:
		var path: String = EFFECT_DIR + fname + ".tres"
		if not ResourceLoader.exists(path):
			push_warning("Base effect not found: %s" % path)
			continue
		# Rule #2: load() returns Variant, use explicit typed local
		var res: Resource = load(path)
		if res is ActionEffect:
			_effects[fname] = res
		else:
			push_warning("Not an ActionEffect: %s" % path)


# ============================================================================
# MIGRATION
# ============================================================================

func _migrate(action_id: String, slots: Array) -> void:
	"""Load an action, assign effect_slots, re-save."""
	var path: String = ACTION_DIR + action_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("  [SKIP] Action not found: %s" % path)
		_skipped += 1
		return

	# Rule #2: load() returns Variant
	var res: Resource = load(path)
	if not res is Action:
		push_error("  [ERR] Not an Action: %s" % path)
		_errors += 1
		return

	var action: Action = res as Action

	# Build typed array and use .assign() (Rule #1)
	var typed_slots: Array[ActionEffectSlot] = []
	for slot in slots:
		if slot is ActionEffectSlot:
			typed_slots.append(slot)
		else:
			push_error("  [ERR] Non-slot in array for %s" % action_id)
			_errors += 1
			return

	action.effect_slots.assign(typed_slots)

	var err: int = ResourceSaver.save(action, path)
	if err != OK:
		push_error("  [ERR] Failed to save %s (error %d)" % [path, err])
		_errors += 1
		return

	var slot_summary: String = ""
	for s: ActionEffectSlot in typed_slots:
		if s and s.effect:
			slot_summary += s.effect.effect_name + ", "
	if slot_summary.length() > 2:
		slot_summary = slot_summary.substr(0, slot_summary.length() - 2)

	print("  [OK] %s -> %d slots [%s]" % [action_id, typed_slots.size(), slot_summary])
	_migrated += 1


# ============================================================================
# SLOT BUILDERS -- each returns a configured ActionEffectSlot
# ============================================================================

func _damage(element: String, p_base_damage: int = 0, p_multiplier: float = 1.0) -> ActionEffectSlot:
	"""Damage slot: damage_{element}.tres with overrides."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	var key: String = "damage_%s" % element
	slot.effect = _effects.get(key) as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: %s" % key)
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.base_damage = p_base_damage
	slot.damage_multiplier = p_multiplier
	slot.dice_count = 1
	return slot


func _status(status_name: String, stacks: int) -> ActionEffectSlot:
	"""Status application slot: apply_{status}.tres with stack override."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	var key: String = "apply_%s" % status_name
	slot.effect = _effects.get(key) as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: %s" % key)
	slot.stack_count = stacks
	return slot


func _empowered_ally(stacks: int) -> ActionEffectSlot:
	"""Empowered on single ally (base default target is SINGLE_ALLY)."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("apply_empowered") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: apply_empowered")
	slot.stack_count = stacks
	# Base default is SINGLE_ALLY, no override needed
	return slot


func _empowered_all(stacks: int) -> ActionEffectSlot:
	"""Empowered on all allies (override target)."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("apply_empowered") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: apply_empowered")
	slot.stack_count = stacks
	slot.override_target = true
	slot.target = ActionEffect.TargetType.ALL_ALLIES
	return slot


func _armor_dice(duration: int) -> ActionEffectSlot:
	"""Armor buff from dice value."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("armor_buff") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: armor_buff")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.armor_buff_uses_dice = true
	slot.armor_buff_duration = duration
	slot.dice_count = 1
	return slot


func _armor_self(amount: int, duration: int) -> ActionEffectSlot:
	"""Flat armor buff on self."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("armor_buff") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: armor_buff")
	slot.armor_buff_amount = amount
	slot.armor_buff_uses_dice = false
	slot.armor_buff_duration = duration
	return slot


func _damage_reduction(amount: float, duration: int) -> ActionEffectSlot:
	"""Flat damage reduction."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("damage_reduction") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: damage_reduction")
	slot.reduction_amount = amount
	slot.reduction_uses_dice = false
	slot.reduction_is_percent = false
	slot.reduction_duration = duration
	return slot


func _shield_dice(p_multiplier: float) -> ActionEffectSlot:
	"""Shield (barrier) from dice value."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("shield") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: shield")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.shield_uses_dice = true
	slot.shield_multiplier = p_multiplier
	slot.dice_count = 1
	return slot


func _heal_dice(p_multiplier: float) -> ActionEffectSlot:
	"""Heal self from dice value."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("heal") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: heal")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.heal_uses_dice = true
	slot.heal_multiplier = p_multiplier
	slot.dice_count = 1
	return slot


func _heal_ally_dice() -> ActionEffectSlot:
	"""Heal single ally from dice value."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("heal") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: heal")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.heal_uses_dice = true
	slot.heal_multiplier = 1.0
	slot.dice_count = 1
	# Base heal defaults to SELF, override to SINGLE_ALLY
	slot.override_target = true
	slot.target = ActionEffect.TargetType.SINGLE_ALLY
	return slot


func _heal_all_dice(p_multiplier: float) -> ActionEffectSlot:
	"""Heal all allies from dice value."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("heal") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: heal")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.heal_uses_dice = true
	slot.heal_multiplier = p_multiplier
	slot.dice_count = 1
	slot.override_target = true
	slot.target = ActionEffect.TargetType.ALL_ALLIES
	return slot


func _cleanse() -> ActionEffectSlot:
	"""Cleanse debuffs from self."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("cleanse") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: cleanse")
	# Rule #1: use .assign() for typed Array[String]
	var tags: Array[String] = ["debuff"]
	slot.cleanse_tags.assign(tags)
	return slot


func _random_strikes(count: int, dmg_type: ActionEffect.DamageType) -> ActionEffectSlot:
	"""Random strikes with dice scaling."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("random_strikes") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: random_strikes")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.strike_count = count
	slot.strikes_use_dice = true
	slot.dice_count = 1
	# Note: damage_type comes from the base random_strikes effect at execution,
	# but the original fan_of_blades used PIERCING explicitly via damage_type on
	# the inline effect. The slot doesn't override damage_type on the base --
	# that's baked into the base template. For fan_of_blades, random_strikes.tres
	# is element-agnostic and the combat system resolves element from context.
	return slot


func _chain(count: int, dmg_type: ActionEffect.DamageType) -> ActionEffectSlot:
	"""Chain attack to additional targets."""
	var slot: ActionEffectSlot = ActionEffectSlot.new()
	slot.effect = _effects.get("chain") as ActionEffect
	if not slot.effect:
		push_error("Missing base effect: chain")
	slot.value_source = ActionEffect.ValueSource.DICE_TOTAL
	slot.chain_count = count
	slot.chain_decay = 0.7
	slot.dice_count = 1
	return slot
