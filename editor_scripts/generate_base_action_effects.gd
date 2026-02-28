# res://scripts/tools/generate_base_action_effects.gd
# EditorScript -- run from Script Editor -> File -> Run
#
# Generates 39 base ActionEffect .tres files at:
#   res://resources/action_effects/base/
#
# These are identity-only templates: they define WHAT (effect type, element,
# status) but carry neutral default values. ActionEffectSlot on each Action
# provides all actual values (damage, stacks, durations, etc.).
#
# SAFE TO RE-RUN: skips files that already exist.
#
# Generator notes applied:
#   Rule 1:  .assign() for any typed array property
#   Rule 2:  Explicit typed locals from array indices (no := from Variant)
#   Rule 3:  StatusAffix loaded from disk before referencing
#   Rule 5:  No emoji in print statements
#   Rule 7:  DirAccess.make_dir_recursive_absolute() for directory creation
#   Rule 8:  Helper function params typed to avoid silent abort
#   Rule 11: Progress prints per item
#   Scan:    EditorInterface.get_resource_filesystem().scan() at end
@tool
extends EditorScript

const OUTPUT_DIR := "res://resources/action_effects/base/"

# Status paths -- update these if your status .tres locations differ
const STATUSES := {
	"burn":      "res://resources/statuses/burn.tres",
	"bleed":     "res://resources/statuses/bleed.tres",
	"poison":    "res://resources/statuses/poison.tres",
	"corrode":   "res://resources/statuses/corrode.tres",
	"slowed":    "res://resources/statuses/slowed.tres",
	"chill":     "res://resources/statuses/chill.tres",
	"expose":    "res://resources/statuses/expose.tres",
	"enfeeble":  "res://resources/statuses/enfeeble.tres",
	"empowered": "res://resources/statuses/empowered.tres",
	"ignition":  "res://resources/statuses/ignition.tres",
}


func _run() -> void:
	print("")
	print("============================================================")
	print("  Generate Base ActionEffect Templates")
	print("============================================================")

	# Rule #7: use static absolute method for directory creation
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var created := 0
	var skipped := 0

	# ── DAMAGE: one per element ──────────────────────────────────────
	# Rule #2: extract typed locals from array indices to avoid Variant
	var elements: Array[Array] = [
		["slashing", ActionEffect.DamageType.SLASHING],
		["blunt",    ActionEffect.DamageType.BLUNT],
		["piercing", ActionEffect.DamageType.PIERCING],
		["fire",     ActionEffect.DamageType.FIRE],
		["ice",      ActionEffect.DamageType.ICE],
		["shock",    ActionEffect.DamageType.SHOCK],
		["poison",   ActionEffect.DamageType.POISON],
		["shadow",   ActionEffect.DamageType.SHADOW],
	]
	for elem in elements:
		var elem_name: String = elem[0]
		var elem_type: int = elem[1]
		var fname: String = "damage_%s.tres" % elem_name
		if _file_exists(fname):
			skipped += 1
			continue
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "%s Damage" % elem_name.capitalize()
		e.effect_type = ActionEffect.EffectType.DAMAGE
		e.target = ActionEffect.TargetType.SINGLE_ENEMY
		e.damage_type = elem_type as ActionEffect.DamageType
		e.value_source = ActionEffect.ValueSource.DICE_TOTAL
		e.base_damage = 0
		e.damage_multiplier = 1.0
		e.dice_count = 1
		_save_effect(e, fname)
		created += 1

	# ── HEAL ─────────────────────────────────────────────────────────
	if not _file_exists("heal.tres"):
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Heal"
		e.effect_type = ActionEffect.EffectType.HEAL
		e.target = ActionEffect.TargetType.SELF
		e.value_source = ActionEffect.ValueSource.STATIC
		e.base_heal = 0
		e.heal_multiplier = 1.0
		e.heal_uses_dice = false
		_save_effect(e, "heal.tres")
		created += 1
	else:
		skipped += 1

	# ── STATUS APPLICATION: debuffs -> SINGLE_ENEMY ──────────────────
	var debuff_statuses: Array[String] = [
		"burn", "bleed", "poison", "corrode",
		"slowed", "chill", "expose", "enfeeble",
	]
	for sid in debuff_statuses:
		var fname: String = "apply_%s.tres" % sid
		if _file_exists(fname):
			skipped += 1
			continue
		# Rule #3: status loaded from disk, has resource_path
		var status_res: StatusAffix = _load_status(sid)
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Apply %s" % sid.capitalize()
		e.effect_type = ActionEffect.EffectType.ADD_STATUS
		e.target = ActionEffect.TargetType.SINGLE_ENEMY
		e.value_source = ActionEffect.ValueSource.STATIC
		e.status_affix = status_res
		e.stack_count = 1
		_save_effect(e, fname)
		created += 1

	# ── STATUS APPLICATION: buffs ────────────────────────────────────
	# Empowered -> default SINGLE_ALLY (slot can override to SELF, ALL_ALLIES)
	if not _file_exists("apply_empowered.tres"):
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Apply Empowered"
		e.effect_type = ActionEffect.EffectType.ADD_STATUS
		e.target = ActionEffect.TargetType.SINGLE_ALLY
		e.value_source = ActionEffect.ValueSource.STATIC
		e.status_affix = _load_status("empowered")
		e.stack_count = 1
		_save_effect(e, "apply_empowered.tres")
		created += 1
	else:
		skipped += 1

	# Ignition -> default SELF
	if not _file_exists("apply_ignition.tres"):
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Apply Ignition"
		e.effect_type = ActionEffect.EffectType.ADD_STATUS
		e.target = ActionEffect.TargetType.SELF
		e.value_source = ActionEffect.ValueSource.STATIC
		e.status_affix = _load_status("ignition")
		e.stack_count = 1
		_save_effect(e, "apply_ignition.tres")
		created += 1
	else:
		skipped += 1

	# ── REMOVE STATUS ────────────────────────────────────────────────
	if not _file_exists("remove_status.tres"):
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Remove Status"
		e.effect_type = ActionEffect.EffectType.REMOVE_STATUS
		e.target = ActionEffect.TargetType.SINGLE_ENEMY
		e.value_source = ActionEffect.ValueSource.STATIC
		e.stack_count = 1
		_save_effect(e, "remove_status.tres")
		created += 1
	else:
		skipped += 1

	# ── CLEANSE ──────────────────────────────────────────────────────
	if not _file_exists("cleanse.tres"):
		var e: ActionEffect = ActionEffect.new()
		e.effect_name = "Cleanse"
		e.effect_type = ActionEffect.EffectType.CLEANSE
		e.target = ActionEffect.TargetType.SELF
		e.value_source = ActionEffect.ValueSource.STATIC
		_save_effect(e, "cleanse.tres")
		created += 1
	else:
		skipped += 1

	# ── DEFENSIVE ────────────────────────────────────────────────────
	# Rule #2: use helper with typed params to avoid Variant from array index
	var defensive: Array[Array] = [
		["shield.tres",           "Shield",           ActionEffect.EffectType.SHIELD,           ActionEffect.TargetType.SELF],
		["armor_buff.tres",       "Armor Buff",       ActionEffect.EffectType.ARMOR_BUFF,       ActionEffect.TargetType.SELF],
		["damage_reduction.tres", "Damage Reduction", ActionEffect.EffectType.DAMAGE_REDUCTION, ActionEffect.TargetType.SELF],
		["reflect.tres",          "Reflect",          ActionEffect.EffectType.REFLECT,          ActionEffect.TargetType.SELF],
	]
	for entry in defensive:
		var counts: Dictionary = _create_from_entry(entry)
		created += counts.created
		skipped += counts.skipped

	# ── COMBAT MODIFIERS ─────────────────────────────────────────────
	var combat_mods: Array[Array] = [
		["lifesteal.tres",  "Lifesteal",  ActionEffect.EffectType.LIFESTEAL,  ActionEffect.TargetType.SINGLE_ENEMY],
		["execute.tres",    "Execute",    ActionEffect.EffectType.EXECUTE,    ActionEffect.TargetType.SINGLE_ENEMY],
		["combo_mark.tres", "Combo Mark", ActionEffect.EffectType.COMBO_MARK, ActionEffect.TargetType.SINGLE_ENEMY],
		["echo.tres",       "Echo",       ActionEffect.EffectType.ECHO,       ActionEffect.TargetType.SINGLE_ENEMY],
	]
	for entry in combat_mods:
		var counts: Dictionary = _create_from_entry(entry)
		created += counts.created
		skipped += counts.skipped

	# ── MULTI-TARGET ─────────────────────────────────────────────────
	var multi: Array[Array] = [
		["splash.tres",         "Splash",        ActionEffect.EffectType.SPLASH,         ActionEffect.TargetType.SINGLE_ENEMY],
		["chain.tres",          "Chain",          ActionEffect.EffectType.CHAIN,           ActionEffect.TargetType.SINGLE_ENEMY],
		["random_strikes.tres", "Random Strikes", ActionEffect.EffectType.RANDOM_STRIKES, ActionEffect.TargetType.SINGLE_ENEMY],
	]
	for entry in multi:
		var counts: Dictionary = _create_from_entry(entry)
		created += counts.created
		skipped += counts.skipped

	# ── ECONOMY ──────────────────────────────────────────────────────
	var economy: Array[Array] = [
		["mana_manipulate.tres",   "Mana Manipulate",   ActionEffect.EffectType.MANA_MANIPULATE,   ActionEffect.TargetType.SELF],
		["modify_cooldown.tres",   "Modify Cooldown",   ActionEffect.EffectType.MODIFY_COOLDOWN,   ActionEffect.TargetType.SELF],
		["refund_charges.tres",    "Refund Charges",    ActionEffect.EffectType.REFUND_CHARGES,    ActionEffect.TargetType.SELF],
		["grant_temp_action.tres", "Grant Temp Action", ActionEffect.EffectType.GRANT_TEMP_ACTION, ActionEffect.TargetType.SELF],
	]
	for entry in economy:
		var counts: Dictionary = _create_from_entry(entry)
		created += counts.created
		skipped += counts.skipped

	# ── BATTLEFIELD + SUMMON ─────────────────────────────────────────
	var battlefield: Array[Array] = [
		["channel.tres",          "Channel",          ActionEffect.EffectType.CHANNEL,          ActionEffect.TargetType.SELF],
		["counter_setup.tres",    "Counter Setup",    ActionEffect.EffectType.COUNTER_SETUP,    ActionEffect.TargetType.SELF],
		["summon_companion.tres", "Summon Companion", ActionEffect.EffectType.SUMMON_COMPANION, ActionEffect.TargetType.SELF],
	]
	for entry in battlefield:
		var counts: Dictionary = _create_from_entry(entry)
		created += counts.created
		skipped += counts.skipped

	# ── Summary ──────────────────────────────────────────────────────
	print("")
	print("  Created: %d" % created)
	print("  Skipped (already exist): %d" % skipped)
	print("  Total expected: 39")
	print("============================================================")
	print("")

	# Force reimport so editor sees new resources immediately
	EditorInterface.get_resource_filesystem().scan()


# ============================================================================
# HELPERS
# ============================================================================

func _create_from_entry(entry: Array) -> Dictionary:
	"""Create a simple ActionEffect from a [fname, name, effect_type, target] array.
	Rule #2: extracts typed locals from array indices to avoid Variant inference."""
	var fname: String = entry[0]
	var eff_name: String = entry[1]
	var eff_type: int = entry[2]
	var tgt: int = entry[3]

	if _file_exists(fname):
		return {"created": 0, "skipped": 1}

	var e: ActionEffect = ActionEffect.new()
	e.effect_name = eff_name
	e.effect_type = eff_type as ActionEffect.EffectType
	e.target = tgt as ActionEffect.TargetType
	e.value_source = ActionEffect.ValueSource.STATIC
	_save_effect(e, fname)
	return {"created": 1, "skipped": 0}


func _save_effect(e: ActionEffect, fname: String) -> void:
	var path: String = OUTPUT_DIR + fname
	var err: int = ResourceSaver.save(e, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
	else:
		print("  [+] %s  (%s)" % [fname, e.effect_name])


func _file_exists(fname: String) -> bool:
	return FileAccess.file_exists(OUTPUT_DIR + fname)


func _load_status(status_id: String) -> StatusAffix:
	"""Load a StatusAffix from disk. Returns null if not found.
	Rule #3: loaded resources have resource_path, safe to reference."""
	var path: String = STATUSES.get(status_id, "")
	if path == "":
		push_warning("No path configured for status: %s" % status_id)
		return null
	if not ResourceLoader.exists(path):
		push_warning("Status file not found: %s" % path)
		return null
	# Rule #2: load() returns Variant, use explicit typed local
	var res: Resource = load(path)
	if res is StatusAffix:
		return res as StatusAffix
	push_warning("Resource at %s is not a StatusAffix" % path)
	return null
