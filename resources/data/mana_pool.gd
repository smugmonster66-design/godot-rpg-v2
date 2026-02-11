# res://resources/data/mana_pool.gd
# Mana resource for caster classes. Manages mana state, element/size
# selection, pull cost calculation, and die creation with skill-granted affixes.
#
# Follows the same pattern as PlayerDiceCollection — created by Player in
# _init(), references populated post-initialization via initialize().
#
# USAGE:
#   var pool = ManaPool.new()
#   pool.initialize(level, intellect, affix_manager, affix_evaluator)
#   pool.refill()
#   pool.cycle_element(1)
#   pool.cycle_die_size(1)
#   if pool.can_pull():
#       var die = pool.pull_mana_die()
#
# Element/size availability is driven entirely by affixes:
#   - MANA_ELEMENT_UNLOCK affixes (from skills) → get_available_elements()
#   - MANA_SIZE_UNLOCK affixes (from skills) → get_available_die_sizes()
#   - MANA_DIE_AFFIX affixes (from skills) → applied to every pulled die
#
# When a skill is unlearned, its affixes are removed from the AffixPoolManager,
# and the next query to available elements/sizes automatically reflects this.
# Zero custom cleanup code needed.
#
# NOTE: Extends Resource (not RefCounted) so PlayerClass can @export a
# mana_pool_template in the inspector. Player.initialize_mana_pool() copies
# config from the template to the runtime instance.
extends Resource
class_name ManaPool

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when current or max mana changes.
signal mana_changed(current: int, max_mana: int)

## Emitted when a mana die is successfully pulled.
signal mana_die_pulled(die: DieResource)

## Emitted when the selected element changes.
signal element_changed(element: DieResource.Element)

## Emitted when the selected die size changes.
signal die_size_changed(die_size: int)

## Emitted when a pull fails (insufficient mana, no elements, etc.).
signal pull_failed(reason: String)

# ============================================================================
# CONFIGURATION — Set from PlayerClass.mana_pool_template via @export
# ============================================================================

## Base max mana before level scaling and INT contribution.
@export var base_max_mana: int = 20

## Curve mapping normalized level (0.0–1.0) to mana bonus multiplier.
## Applied as: curve_bonus = mana_curve.sample(level / max_level) * base_max_mana
## If null, no curve scaling is applied (flat base_max_mana + INT).
@export var mana_curve: Curve = null

## How much each point of intellect contributes to max mana.
## Formula: int_bonus = intellect * int_mana_ratio
@export var int_mana_ratio: float = 0.5

## Maximum level for curve normalization (denominator in level / max_level).
@export var max_level: float = 50.0

## Whether mana refills to max at combat start.
@export var refill_on_combat_start: bool = true

# ============================================================================
# RUNTIME STATE (not exported — these live on the Player's instance)
# ============================================================================

## Current mana available for pulling dice.
var current_mana: int = 0

## Runtime: Cost of the last mana pull (for MANA_REFUND event calculations).
var last_pull_cost: int = 0

## Calculated max mana (base + curve + INT + affix bonuses).
var max_mana: int = 20

## Currently selected element for the next mana die pull.
var selected_element: DieResource.Element = DieResource.Element.NONE

## Currently selected die size for the next mana die pull.
var selected_die_size: int = 4


# ============================================================================
# REFERENCES — Set via initialize()
# ============================================================================

## Player's AffixPoolManager — queried for MANA_ELEMENT_UNLOCK,
## MANA_SIZE_UNLOCK, MANA_DIE_AFFIX, and cost reduction affixes.
var _affix_manager: AffixPoolManager = null

## Player's AffixEvaluator — used for MANA_BONUS sum resolution.
var _affix_evaluator: AffixEvaluator = null

# ============================================================================
# ELEMENT DISPLAY NAMES (for UI labels)
# ============================================================================

const ELEMENT_NAMES: Dictionary = {
	DieResource.Element.NONE: "Neutral",
	DieResource.Element.FIRE: "Fire",
	DieResource.Element.ICE: "Ice",
	DieResource.Element.SHOCK: "Shock",
	DieResource.Element.POISON: "Poison",
	DieResource.Element.SHADOW: "Shadow",
	DieResource.Element.SLASHING: "Slashing",
	DieResource.Element.BLUNT: "Blunt",
	DieResource.Element.PIERCING: "Piercing",
}

## Die size display names.
const SIZE_NAMES: Dictionary = {
	4: "D4",
	6: "D6",
	8: "D8",
	10: "D10",
	12: "D12",
	20: "D20",
}

## Ordered list of valid die sizes.
const VALID_SIZES: Array = [4, 6, 8, 10, 12, 20]

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(level: int, intellect: int, affix_manager: AffixPoolManager,
		affix_evaluator: AffixEvaluator = null) -> void:
	"""Initialize the mana pool after Player's affix_manager is populated.

	Call this after equipment + skills are applied so MANA_BONUS affixes
	are present in the pool.

	Args:
		level: Player's current level (for curve scaling).
		intellect: Player's total intellect stat.
		affix_manager: Player's AffixPoolManager.
		affix_evaluator: Player's AffixEvaluator (optional, for MANA_BONUS).
	"""
	_affix_manager = affix_manager
	_affix_evaluator = affix_evaluator

	recalculate_max_mana(level, intellect)

	# Default to first available element and size
	var elements = get_available_elements()
	if elements.size() > 0 and selected_element not in elements:
		selected_element = elements[0]

	var sizes = get_available_die_sizes()
	if sizes.size() > 0 and selected_die_size not in sizes:
		selected_die_size = sizes[0]

	_validate_selection()

	print("🔮 ManaPool initialized: %d/%d mana, element=%s, size=D%d" % [
		current_mana, max_mana,
		ELEMENT_NAMES.get(selected_element, "?"),
		selected_die_size
	])

# ============================================================================
# MAX MANA CALCULATION
# ============================================================================

func recalculate_max_mana(level: int, intellect: int) -> void:
	"""Recalculate max mana from base + curve + INT + affixes.
	Call when level changes, INT changes, or equipment changes.

	Args:
		level: Player's current level.
		intellect: Player's total intellect stat.
	"""
	var old_max = max_mana

	# --- Base ---
	var total: float = float(base_max_mana)

	# --- Curve scaling ---
	if mana_curve:
		var normalized = clampf(float(level) / max_level, 0.0, 1.0)
		total += mana_curve.sample(normalized) * float(base_max_mana)

	# --- INT contribution ---
	total += float(intellect) * int_mana_ratio

	# --- MANA_BONUS affixes ---
	if _affix_manager:
		for affix in _affix_manager.get_pool(Affix.Category.MANA_BONUS):
			total += affix.apply_effect()

	max_mana = maxi(1, int(total))

	# Scale current mana proportionally if max changed
	if old_max > 0 and max_mana != old_max:
		current_mana = clampi(
			roundi(float(current_mana) * (float(max_mana) / float(old_max))),
			0, max_mana
		)
	else:
		current_mana = clampi(current_mana, 0, max_mana)

	mana_changed.emit(current_mana, max_mana)

# ============================================================================
# MANA MANIPULATION
# ============================================================================

func refill() -> void:
	"""Restore mana to max. Typically called at combat start."""
	current_mana = max_mana
	# Auto-select first available element/size if current selection is invalid
	_validate_selection()
	mana_changed.emit(current_mana, max_mana)

func add_mana(amount: int) -> void:
	"""Add mana (clamped to max). Used by MANA_GAIN / MANA_REFUND effects."""
	if amount <= 0:
		return
	var old = current_mana
	current_mana = mini(current_mana + amount, max_mana)
	if current_mana != old:
		mana_changed.emit(current_mana, max_mana)

func spend_mana(amount: int) -> bool:
	"""Spend mana. Returns true if successful, false if insufficient."""
	if amount > current_mana:
		return false
	last_pull_cost = amount
	current_mana -= amount
	mana_changed.emit(current_mana, max_mana)
	return true

func get_mana_percent() -> float:
	"""Get current mana as a 0.0–1.0 percentage."""
	if max_mana <= 0:
		return 0.0
	return float(current_mana) / float(max_mana)

# ============================================================================
# ELEMENT AVAILABILITY — Driven by MANA_ELEMENT_UNLOCK affixes
# ============================================================================

func get_available_elements() -> Array:
	if not _affix_manager:
		return []

	var elements: Array = []
	for affix in _affix_manager.get_pool(Affix.Category.MANA_ELEMENT_UNLOCK):
		var elem = DieResource.Element.NONE

		# Primary: effect_data["element"] string
		var elem_str: String = affix.effect_data.get("element", "") if affix.effect_data else ""
		if not elem_str.is_empty():
			elem = _string_to_element(elem_str)

		# Fallback: elemental_identity (already set on your skill affixes)
		# Fallback: elemental_identity is a DamageType int — convert to Element
		if elem == DieResource.Element.NONE and affix.has_elemental_identity:
			elem = _damage_type_to_element(affix.elemental_identity)

		if elem != DieResource.Element.NONE and elem not in elements:
			elements.append(elem)

	elements.sort()
	return elements


static func _damage_type_to_element(damage_type: int) -> DieResource.Element:
	"""Convert ActionEffect.DamageType int to DieResource.Element."""
	match damage_type:
		ActionEffect.DamageType.SLASHING: return DieResource.Element.SLASHING
		ActionEffect.DamageType.BLUNT: return DieResource.Element.BLUNT
		ActionEffect.DamageType.PIERCING: return DieResource.Element.PIERCING
		ActionEffect.DamageType.FIRE: return DieResource.Element.FIRE
		ActionEffect.DamageType.ICE: return DieResource.Element.ICE
		ActionEffect.DamageType.SHOCK: return DieResource.Element.SHOCK
		ActionEffect.DamageType.POISON: return DieResource.Element.POISON
		ActionEffect.DamageType.SHADOW: return DieResource.Element.SHADOW
		_: return DieResource.Element.NONE

func cycle_element(direction: int) -> void:
	"""Cycle the selected element forward (+1) or backward (-1).
	Wraps around. Does nothing if ≤1 element available."""
	var elements = get_available_elements()
	if elements.size() <= 1:
		return

	var current_idx = elements.find(selected_element)
	if current_idx == -1:
		current_idx = 0

	current_idx = (current_idx + direction) % elements.size()
	if current_idx < 0:
		current_idx += elements.size()

	selected_element = elements[current_idx]
	element_changed.emit(selected_element)

func get_element_name() -> String:
	"""Get display name for the currently selected element."""
	return ELEMENT_NAMES.get(selected_element, "Unknown")

# ============================================================================
# DIE SIZE AVAILABILITY — Driven by MANA_SIZE_UNLOCK affixes
# ============================================================================

func get_available_die_sizes() -> Array:
	var sizes: Array = [4]  # D4 always available for casters

	if _affix_manager:
		for affix in _affix_manager.get_pool(Affix.Category.MANA_SIZE_UNLOCK):
			var size_val: int = int(affix.effect_data.get("die_size", 0))
			if size_val in VALID_SIZES and size_val not in sizes:
				sizes.append(size_val)

	sizes.sort()
	return sizes


func cycle_die_size(direction: int) -> void:
	"""Cycle the selected die size up (+1) or down (-1).
	Wraps around. Does nothing if ≤1 size available."""
	var sizes = get_available_die_sizes()
	if sizes.size() <= 1:
		return

	var current_idx = sizes.find(selected_die_size)
	if current_idx == -1:
		current_idx = 0

	current_idx = (current_idx + direction) % sizes.size()
	if current_idx < 0:
		current_idx += sizes.size()

	selected_die_size = sizes[current_idx]
	die_size_changed.emit(selected_die_size)

# ============================================================================
# PULL COST
# ============================================================================

func get_pull_cost(die_size: int = -1) -> int:
	"""Get mana cost to pull a die of the given size.
	Default: use selected_die_size. d4=4, d6=6, d8=8, etc.
	Applies flat cost reduction from skill affixes (minimum cost 1).

	Also applies MANA_COST_MULTIPLIER affixes for percentage-based
	cost changes (e.g., 0.8 = 20% cheaper).
	"""
	if die_size < 0:
		die_size = selected_die_size

	var base_cost: int = die_size  # DieType enum values ARE the face counts

	# Flat reduction from affixes tagged "mana_pull_cost_reduction"
	var reduction: int = 0
	if _affix_manager:
		var elem_tag = _element_cost_tag(selected_element)
		for affix in _affix_manager.get_affixes_by_tag("mana_pull_cost_reduction"):
			if affix.has_tag(elem_tag) or not _has_any_element_tag(affix):
				reduction += int(affix.effect_number)

	var cost_after_flat: int = maxi(base_cost - reduction, 1)

	# Multiplicative adjustment from MANA_COST_MULTIPLIER affixes
	var multiplier: float = 1.0
	if _affix_manager:
		for affix in _affix_manager.get_pool(Affix.Category.MANA_COST_MULTIPLIER):
			multiplier *= affix.apply_effect()

	return maxi(int(float(cost_after_flat) * multiplier), 1)

func can_pull(die_size: int = -1) -> bool:
	"""Check if the player has enough mana to pull at current/given size.

	Args:
		die_size: Die size to check. -1 uses selected_die_size.

	Returns:
		True if pull is possible.
	"""
	if get_available_elements().is_empty():
		return false
	if get_available_die_sizes().is_empty():
		return false

	var cost = get_pull_cost(die_size)
	return current_mana >= cost

# ============================================================================
# DIE CREATION
# ============================================================================

func pull_mana_die() -> DieResource:
	"""Create a mana die with the selected element and size.

	Deducts mana cost, creates DieResource, applies base textures,
	element visuals, all MANA_DIE_AFFIX DiceAffixes from skills,
	and emits mana_die_pulled.

	Returns:
		The new DieResource, or null if pull failed.
	"""
	if not can_pull():
		var reason = _get_pull_failure_reason()
		pull_failed.emit(reason)
		print("🔮 Pull failed: %s" % reason)
		return null

	var cost = get_pull_cost()
	last_pull_cost = cost

	# Deduct mana
	spend_mana(cost)

	# Create die
	var die = DieResource.new()
	die.die_type = selected_die_size as DieResource.DieType
	die.element = selected_element
	die.display_name = "%s D%d" % [get_element_name(), selected_die_size]
	die.source = "mana"
	die.is_mana_die = true
	die.tags.append("mana_die")
	die.tags.append(_element_tag(selected_element))

	# Apply base shape textures from DieBaseTextures registry
	if DieBaseTextures.instance:
		DieBaseTextures.instance.apply_to(die)

	# Roll the die immediately (it enters the hand already rolled)
	die.roll()

	# Apply element visual affix for shader effects
	_apply_element_visuals(die)

	# Apply all skill-granted MANA_DIE_AFFIX DiceAffixes
	_apply_mana_die_affixes(die)

	print("🔮 Pulled %s (cost %d, mana %d/%d)" % [
		die.display_name, cost, current_mana, max_mana])

	mana_die_pulled.emit(die)
	return die
	
	
const DIE_TEXTURE_PATHS := {
	DieResource.DieType.D4: "res://assets/dice/D6s/d6-basic",
	DieResource.DieType.D6: "res://assets/dice/D6s/d6-basic",
	DieResource.DieType.D8: "res://assets/dice/D6s/d6-basic",
	DieResource.DieType.D10: "res://assets/dice/D6s/d6-basic",
	DieResource.DieType.D12: "res://assets/dice/d12s/d12-basic",
	DieResource.DieType.D20: "res://assets/dice/D6s/d6-basic",
}

func _apply_die_textures(die: DieResource):
	"""Load fill/stroke textures for the die based on its type."""
	var base_path = DIE_TEXTURE_PATHS.get(die.die_type, "")
	if base_path.is_empty():
		return
	
	var fill_path = base_path + "-fill.png"
	var stroke_path = base_path + "-stroke.png"
	
	if ResourceLoader.exists(fill_path):
		die.fill_texture = load(fill_path)
	if ResourceLoader.exists(stroke_path):
		die.stroke_texture = load(stroke_path)

# ============================================================================
# INTERNAL — Affix Application
# ============================================================================


func _apply_element_visuals(die: DieResource) -> void:
	"""Apply element-specific visual affix to the die.

	Loads the element's DiceAffix resource (e.g., fire_element.tres)
	so the visual pipeline applies fill/stroke/value shader materials
	automatically when the die is instantiated as a CombatDieObject.
	"""
	if die.element == DieResource.Element.NONE:
		return

	var tag = _element_tag(die.element)
	var affix_path = "res://resources/affixes/elements/%s_element.tres" % tag
	if ResourceLoader.exists(affix_path):
		die.element_affix = load(affix_path) as DiceAffix
		
		


func _apply_mana_die_affixes(die: DieResource) -> void:
	"""Apply all MANA_DIE_AFFIX DiceAffixes from the player's affix pool.

	Each MANA_DIE_AFFIX affix stores its DiceAffix in effect_data["dice_affix"].
	We duplicate it and add it to the die's affix list.
	"""
	if not _affix_manager:
		return

	for affix in _affix_manager.get_pool(Affix.Category.MANA_DIE_AFFIX):
		var dice_affix = affix.effect_data.get("dice_affix") as DiceAffix
		if dice_affix:
			var copy = dice_affix.duplicate(true)
			die.add_affix(copy)
			print("  🔮 Applied mana die affix: %s" % copy.affix_name)


func notify_options_changed():
	"""Call after skills/affixes change to revalidate element/size selection."""
	_validate_selection()

# ============================================================================
# INTERNAL — Helpers
# ============================================================================

func _get_pull_failure_reason() -> String:
	"""Get human-readable reason why a pull would fail."""
	if get_available_elements().is_empty():
		return "No elements unlocked"
	if get_available_die_sizes().is_empty():
		return "No die sizes unlocked"
	var cost = get_pull_cost()
	if current_mana < cost:
		return "Not enough mana (%d/%d needed)" % [current_mana, cost]
	return "Unknown"

func _has_any_element_tag(affix: Affix) -> bool:
	"""Check if an affix has any element-specific cost tag."""
	for elem in DieResource.Element.values():
		var tag = _element_cost_tag(elem)
		if tag and affix.has_tag(tag):
			return true
	return false

func _element_cost_tag(elem: DieResource.Element) -> String:
	"""Get the affix tag for element-specific cost reduction."""
	match elem:
		DieResource.Element.FIRE: return "fire_cost_reduction"
		DieResource.Element.ICE: return "ice_cost_reduction"
		DieResource.Element.SHOCK: return "shock_cost_reduction"
		DieResource.Element.POISON: return "poison_cost_reduction"
		DieResource.Element.SHADOW: return "shadow_cost_reduction"
		_: return ""

func _element_tag(elem: DieResource.Element) -> String:
	"""Get a lowercase string tag for an element."""
	match elem:
		DieResource.Element.FIRE: return "fire"
		DieResource.Element.ICE: return "ice"
		DieResource.Element.SHOCK: return "shock"
		DieResource.Element.POISON: return "poison"
		DieResource.Element.SHADOW: return "shadow"
		DieResource.Element.SLASHING: return "slashing"
		DieResource.Element.BLUNT: return "blunt"
		DieResource.Element.PIERCING: return "piercing"
		_: return "neutral"

static func _string_to_element(s: String) -> DieResource.Element:
	"""Convert a string (from affix effect_data) to Element enum."""
	match s.to_upper():
		"FIRE": return DieResource.Element.FIRE
		"ICE": return DieResource.Element.ICE
		"SHOCK": return DieResource.Element.SHOCK
		"POISON": return DieResource.Element.POISON
		"SHADOW": return DieResource.Element.SHADOW
		"SLASHING": return DieResource.Element.SLASHING
		"BLUNT": return DieResource.Element.BLUNT
		"PIERCING": return DieResource.Element.PIERCING
		_: return DieResource.Element.NONE

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize runtime state for save/load."""
	return {
		"current_mana": current_mana,
		"max_mana": max_mana,
		"selected_element": selected_element,
		"selected_die_size": selected_die_size,
		"last_pull_cost": last_pull_cost,
		# Configuration is restored from PlayerClass template, not saved
	}

func from_dict(data: Dictionary) -> void:
	"""Restore runtime state from save data."""
	current_mana = data.get("current_mana", 0)
	max_mana = data.get("max_mana", 20)
	selected_element = data.get("selected_element", DieResource.Element.NONE)
	selected_die_size = data.get("selected_die_size", 4)
	last_pull_cost = data.get("last_pull_cost", 0)


func _validate_selection():
	"""Ensure selected_element and selected_die_size are valid choices."""
	var elements = get_available_elements()
	if elements.size() > 0 and selected_element not in elements:
		selected_element = elements[0]
		element_changed.emit(selected_element)
	
	var sizes = get_available_die_sizes()
	if sizes.size() > 0 and selected_die_size not in sizes:
		selected_die_size = sizes[0]
		die_size_changed.emit(selected_die_size)


# ============================================================================
# DEBUG
# ============================================================================

func print_status() -> void:
	"""Print full mana pool state for debugging."""
	print("🔮 === ManaPool Status ===")
	print("  Mana: %d / %d (%.0f%%)" % [current_mana, max_mana, get_mana_percent() * 100])
	print("  Selected: %s D%d (cost: %d)" % [
		get_element_name(), selected_die_size, get_pull_cost()])
	print("  Available elements: %s" % str(get_available_elements().map(
		func(e): return ELEMENT_NAMES.get(e, "?"))))
	print("  Available sizes: %s" % str(get_available_die_sizes().map(
		func(s): return "D%d" % s)))
	print("  Can pull: %s" % can_pull())
	if _affix_manager:
		var mda_count = _affix_manager.get_pool(Affix.Category.MANA_DIE_AFFIX).size()
		print("  Mana die affixes in pool: %d" % mda_count)
	print("🔮 ========================")
