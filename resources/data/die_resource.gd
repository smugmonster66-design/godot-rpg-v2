@tool
# res://resources/data/die_resource.gd
# Individual die with type, image, element, and dice affixes
# Updated to support DieObject scenes for combat and pool displays
#
# v2.1 CHANGELOG:
#   - Added is_consumed: bool — marks hand dice as used without removing from array
#   - Updated duplicate_die() to copy is_consumed (defaults false)
#   - is_consumed is runtime-only (not serialized — hand is transient)
extends Resource
class_name DieResource

# ============================================================================
# ENUMS
# ============================================================================
enum DieType {
	D4 = 4,
	D6 = 6,
	D8 = 8,
	D10 = 10,
	D12 = 12,
	D20 = 20
}

enum Element {
	NONE,
	SLASHING,
	BLUNT,
	PIERCING,
	FIRE,
	ICE,
	SHOCK,
	POISON,
	SHADOW,
	FAITH
}

# ============================================================================
# DEFAULT ASSET PATHS PER DIE TYPE (hardcoded — naming is inconsistent)
# ============================================================================
static var _default_assets: Dictionary = {}

static func _get_default_assets() -> Dictionary:
	if _default_assets.is_empty():
		_default_assets = {
			4: {  # D4
				"fill": "res://assets/dice/d4s/d4-fill-basic.png",
				"stroke": "res://assets/dice/d4s/d4-stroke-basic.png",
			},
			6: {  # D6
				"fill": "res://assets/dice/D6s/d6-basic-fill.png",
				"stroke": "res://assets/dice/D6s/d6-basic-stroke.png",
			},
			8: {  # D8
				"fill": "res://assets/dice/d8s/d8-fill-basic.png",
				"stroke": "res://assets/dice/d8s/d8-stroke-basic.png",
			},
			10: {  # D10
				"fill": "res://assets/dice/d10s/d10-fill-basic.png",
				"stroke": "res://assets/dice/d10s/d10-stroke-basic.png",
			},
			12: {  # D12
				"fill": "res://assets/dice/d12s/d12-basic-fill.png",
				"stroke": "res://assets/dice/d12s/d12-basic-stroke.png",
			},
			20: {  # D20
				"fill": "res://assets/dice/d20s/d20-fill-basic.png",
				"stroke": "res://assets/dice/d20s/d20-stroke-basic.png",
			},
		}
	return _default_assets

# ============================================================================
# BASIC PROPERTIES
# ============================================================================
@export var display_name: String = "Die"
@export var die_type: DieType = DieType.D6:
	set(value):
		die_type = value
		if Engine.is_editor_hint():
			# Defer so deserialization finishes first — avoids overwriting
			# saved values and lets the Inspector refresh on the next frame.
			call_deferred("_auto_populate_defaults")
@export var color: Color = Color.WHITE
@export var is_mana_die: bool = false
## Rarity name for visual glow. Set by DieGenerator at creation time.
## Not exported — runtime only. Used by RarityGlowHelper in visual systems.
var rarity_name: String = ""

@export_group("Element")
## The element of this die - applies default visual effects
@export var element: Element = Element.NONE
## Default visual effects affix for this element (applied first, can be overwritten)
@export var element_affix: DiceAffix = null

@export_group("Textures")
## Fill texture (drawn first, behind stroke)
@export var fill_texture: Texture2D = null
## Stroke/outline texture (drawn on top of fill)
@export var stroke_texture: Texture2D = null

var icon: Texture2D:
	get:
		return fill_texture
	set(value):
		fill_texture = value

# ============================================================================
# DIE OBJECT SCENES
# ============================================================================
@export_group("Die Object Scenes")
## Scene used to display this die in combat (shows rolled value)
## If null, will auto-select based on die_type
@export var combat_die_scene: PackedScene = null
## Scene used to display this die in pool/inventory (shows max value)
## If null, will auto-select based on die_type
@export var pool_die_scene: PackedScene = null

@export var drag_preview_scene: PackedScene = null

# ============================================================================
# DICE AFFIXES
# ============================================================================
@export_group("Dice Affixes")
## Affixes that are always on this die (e.g., a "Flame Die" has fire affixes built-in)
@export var inherent_affixes: Array[DiceAffix] = []

## Permanent affixes added by consumable inscriptions.
## Separate from inherent (built-in) and applied (runtime/temporary).
@export var inscribed_affixes: Array[DiceAffix] = []

## Maximum inscription slots. Override per-die or use default by die type.
@export var max_inscription_slots: int = -1  ## -1 = use default by die type


## Runtime affixes added by equipment, blessings, curses, etc.
var applied_affixes: Array[DiceAffix] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal value_modified(old_value: int, new_value: int)
signal shattered()


# ============================================================================
# RUNTIME STATE
# ============================================================================
var current_value: int = 1          # Current rolled value (before affixes)
var modified_value: int = 1         # Value after affix modifications
var modifier: int = 0               # Flat modifier from external sources
## Owner stat that powers this die (the dice formula); -1 = none (enemy and
## pool dice). stat_bonus is what it adds on the current face and is part of
## modified_value; it is recomputed whenever the die is rolled or set.
var stat_power: int = -1
var stat_bonus: int = 0
var source: String = ""             # Where this die came from
var tags: Array[String] = []        # Tags on this die (fire, holy, etc.)
var slot_index: int = -1            # Position in pool (for affix requirements)
var forced_roll_value: int = -1

# Locking
var is_locked: bool = false         # Can't be removed
var can_reroll: bool = true         # Can use reroll abilities

# Hand consumption state (v2.1)
## True when this hand die has been placed in an action field this turn.
## The die stays in the hand array to preserve positional relationships
## for neighbor-targeting affixes. UI reads this to hide/grey out the die.
var is_consumed: bool = false
var is_shattered: bool = false

var is_duplicate: bool = false

# ============================================================================
# ELEMENT NAMES
# ============================================================================
const ELEMENT_NAMES = {
	Element.NONE: "None",
	Element.SLASHING: "Slashing",
	Element.BLUNT: "Blunt",
	Element.PIERCING: "Piercing",
	Element.FIRE: "Fire",
	Element.ICE: "Ice",
	Element.SHOCK: "Shock",
	Element.POISON: "Poison",
	Element.SHADOW: "Shadow",
	Element.FAITH: "Holy",
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_type: DieType = DieType.D6, p_source: String = ""):
	die_type = p_type
	source = p_source
	current_value = 1
	modified_value = 1

# ============================================================================
# ELEMENT
# ============================================================================

func get_element_name() -> String:
	"""Get the display name of this die's element"""
	return ELEMENT_NAMES.get(element, "None")

func has_element() -> bool:
	"""Check if this die has an element assigned"""
	return element != Element.NONE

func set_element_with_affix(new_element: Element, affix: DiceAffix = null):
	"""Set the element and optionally the visual affix"""
	element = new_element
	if affix:
		element_affix = affix

# ============================================================================
# DIE OBJECT INSTANTIATION
# ============================================================================

func instantiate_combat_visual() -> Control:
	"""Create a combat die visual (CombatDieObject)"""
	var scene = combat_die_scene
	if not scene:
		scene = _get_default_combat_scene()
	
	if scene:
		var instance = scene.instantiate()
		if instance.has_method("setup"):
			instance.setup(self)
		return instance
	return null

func instantiate_pool_visual() -> Control:
	"""Create a pool die visual (PoolDieObject)"""
	var scene = pool_die_scene
	if not scene:
		scene = _get_default_pool_scene()
	
	if scene:
		var instance = scene.instantiate()
		if instance.has_method("setup"):
			instance.setup(self)
		return instance
	return null

func _get_default_combat_scene() -> PackedScene:
	var path = "res://scenes/ui/components/dice/combat/combat_die_d%d.tscn" % die_type
	if ResourceLoader.exists(path):
		return load(path)
	print("  ⚠️ Combat scene not found: %s — using base" % path)
	return load("res://scenes/ui/components/dice/combat/combat_die_object_base.tscn")

func _get_default_pool_scene() -> PackedScene:
	var path = "res://scenes/ui/components/dice/pool/pool_die_d%d.tscn" % die_type
	if ResourceLoader.exists(path):
		return load(path)
	print("  ⚠️ Pool scene not found: %s — using base" % path)
	return load("res://scenes/ui/components/dice/pool/pool_die_object_base.tscn")

# ============================================================================
# AUTO-POPULATE DEFAULTS
# ============================================================================

func _auto_populate_defaults() -> void:
	"""Auto-populate fill/stroke textures and combat/pool scenes when die_type
	changes in the editor. Overwrites values that are null OR still set to a
	different type's default. Never overwrites user-customized assets.
	Called deferred so deserialization completes before we check null fields."""
	var assets = DieResource._get_default_assets()
	var key: int = int(die_type)
	if not assets.has(key):
		return
	var defaults: Dictionary = assets[key]
	var changed := false

	# Textures: populate if null or still set to another type's default
	if fill_texture == null or _is_any_type_default_fill(fill_texture):
		var path: String = defaults.get("fill", "")
		if path != "" and ResourceLoader.exists(path):
			fill_texture = load(path)
			changed = true

	if stroke_texture == null or _is_any_type_default_stroke(stroke_texture):
		var path: String = defaults.get("stroke", "")
		if path != "" and ResourceLoader.exists(path):
			stroke_texture = load(path)
			changed = true

	# Scenes: populate if null or still set to another type's default
	if combat_die_scene == null or _is_any_type_default_scene(combat_die_scene, "combat"):
		combat_die_scene = _get_default_combat_scene()
		changed = true

	if pool_die_scene == null or _is_any_type_default_scene(pool_die_scene, "pool"):
		pool_die_scene = _get_default_pool_scene()
		changed = true

	if changed:
		emit_changed()
		notify_property_list_changed()


func _is_any_type_default_fill(tex: Texture2D) -> bool:
	"""Check if a texture matches any die type's default fill."""
	if tex == null:
		return true
	var path = tex.resource_path
	for type_defaults in DieResource._get_default_assets().values():
		if path == type_defaults.get("fill", ""):
			return true
	return false


func _is_any_type_default_stroke(tex: Texture2D) -> bool:
	"""Check if a texture matches any die type's default stroke."""
	if tex == null:
		return true
	var path = tex.resource_path
	for type_defaults in DieResource._get_default_assets().values():
		if path == type_defaults.get("stroke", ""):
			return true
	return false


func _is_any_type_default_scene(scene: PackedScene, kind: String) -> bool:
	"""Check if a scene matches any die type's default combat/pool scene."""
	if scene == null:
		return true
	var path = scene.resource_path
	for dt in DieType.values():
		var expected: String
		if kind == "combat":
			expected = "res://scenes/ui/components/dice/combat/combat_die_d%d.tscn" % dt
		else:
			expected = "res://scenes/ui/components/dice/pool/pool_die_d%d.tscn" % dt
		if path == expected:
			return true
	return false


# ============================================================================
# ROLLING
# ============================================================================

func roll() -> int:
	"""Roll the die and return the value"""
	if forced_roll_value > 0:
		current_value = clampi(forced_roll_value, 1, die_type)
	else:
		current_value = randi_range(1, die_type)
	modified_value = current_value + modifier
	_add_stat_bonus()
	return modified_value

func set_value(value: int):
	"""Manually set the die value"""
	current_value = clampi(value, 1, die_type)
	modified_value = current_value + modifier
	_add_stat_bonus()

func apply_stat_power(stat_value: int) -> void:
	"""Power this die with an owner stat (the dice formula). Adjusts the
	current value by the difference, so it works before or after a roll."""
	var old := stat_bonus
	stat_power = maxi(0, stat_value)
	stat_bonus = CombatTuning.die_stat_bonus(stat_power, current_value)
	modified_value += stat_bonus - old
	if has_meta("stat_bonus_applied"):
		set_meta("stat_bonus_applied", stat_bonus)

func _add_stat_bonus() -> void:
	if stat_power < 0:
		stat_bonus = 0
		return
	stat_bonus = CombatTuning.die_stat_bonus(stat_power, current_value)
	modified_value += stat_bonus
	if has_meta("stat_bonus_applied"):
		set_meta("stat_bonus_applied", stat_bonus)

func get_total_value() -> int:
	"""Get the final value after all modifications"""
	return modified_value

func get_max_value() -> int:
	"""Get the maximum possible value for this die type"""
	return die_type

func is_max_roll() -> bool:
	"""Check if current roll is maximum for die type"""
	return current_value == die_type

# ============================================================================
# VALUE MODIFICATION (for affix processor)
# ============================================================================

func apply_flat_modifier(amount: float):
	"""Apply a flat modifier to the modified value"""
	var old = modified_value
	modified_value += int(amount)
	modified_value = max(0, modified_value)
	if old != modified_value:
		value_modified.emit(old, modified_value)

func apply_percent_modifier(percent: float):
	"""Apply a percentage modifier to the modified value"""
	var old = modified_value
	modified_value = int(modified_value * percent)
	modified_value = max(0, modified_value)
	if old != modified_value:
		value_modified.emit(old, modified_value)

func set_minimum_value(minimum: int):
	"""Ensure value is at least this amount"""
	if modified_value < minimum:
		var old = modified_value
		modified_value = minimum
		value_modified.emit(old, modified_value)

func set_maximum_value(maximum: int):
	"""Cap value at this amount"""
	if modified_value > maximum:
		var old = modified_value
		modified_value = maximum
		value_modified.emit(old, modified_value)

func reset_modifications():
	"""Reset modified value to base roll"""
	modified_value = current_value

# ============================================================================
# AFFIXES
# ============================================================================

func add_affix(affix: DiceAffix):
	"""Add a runtime affix"""
	applied_affixes.append(affix)

func remove_affix(affix: DiceAffix):
	"""Remove a runtime affix"""
	applied_affixes.erase(affix)

func clear_applied_affixes():
	"""Remove all runtime affixes"""
	applied_affixes.clear()

func get_all_affixes() -> Array[DiceAffix]:
	"""Get combined element, inherent, and applied affixes.
	Element affix is applied first (as base visual), then inherent, then applied.
	   Later affixes can overwrite visual effects from earlier ones."""
	var all: Array[DiceAffix] = []
	
	# Element affix first (base visual - can be overwritten)
	if element_affix:
		all.append(element_affix)
	
	# Then inherent affixes
	all.append_array(inherent_affixes)
	
	# Then inscribed affixes (permanent player modifications)
	all.append_array(inscribed_affixes)
	
	# Then applied affixes (highest priority for visual overwrites)
	all.append_array(applied_affixes)
	
	return all

func has_affix_with_effect(effect_type: DiceAffix.EffectType) -> bool:
	"""Check if any affix has a specific effect type"""
	for affix in get_all_affixes():
		if affix and affix.effect_type == effect_type:
			return true
	return false

# ============================================================================
# TAGS
# ============================================================================

func add_tag(tag: String):
	if tag not in tags:
		tags.append(tag)

func remove_tag(tag: String):
	tags.erase(tag)

func has_tag(tag: String) -> bool:
	return tag in tags

func get_tags() -> Array[String]:
	return tags

# ============================================================================
# DISPLAY
# ============================================================================

func get_display_name() -> String:
	if display_name and display_name != "Die":
		return display_name
	return "D%d" % die_type

func get_type_string() -> String:
	return "D%d" % die_type

func get_affix_summary() -> String:
	"""Get a summary of all affixes for tooltip"""
	var all_affixes = get_all_affixes()
	if all_affixes.size() == 0:
		return ""
	
	var lines: Array[String] = []
	for affix in all_affixes:
		if affix and affix.show_in_summary:
			lines.append("• " + affix.get_formatted_description())
	return "\n".join(lines)

# ============================================================================
# ELEMENT → DAMAGE TYPE MAPPING
# ============================================================================

## Maps DieResource.Element → ActionEffect.DamageType
## NONE has no mapping — caller must handle it (inherit from action)
const ELEMENT_TO_DAMAGE_TYPE = {
	Element.SLASHING: ActionEffect.DamageType.SLASHING,
	Element.BLUNT: ActionEffect.DamageType.BLUNT,
	Element.PIERCING: ActionEffect.DamageType.PIERCING,
	Element.FIRE: ActionEffect.DamageType.FIRE,
	Element.ICE: ActionEffect.DamageType.ICE,
	Element.SHOCK: ActionEffect.DamageType.SHOCK,
	Element.POISON: ActionEffect.DamageType.POISON,
	Element.SHADOW: ActionEffect.DamageType.SHADOW,
	Element.FAITH: ActionEffect.DamageType.FAITH,
}

func get_effective_element() -> Element:
	"""Get the die's effective element after dice affix overrides.
	Priority: ADD_DAMAGE_TYPE affix (pure override only) > innate element > NONE
	ADD_DAMAGE_TYPE affixes with effect_value > 0 add bonus damage of a secondary
	element but do not reclassify the die — those are skipped here.
	"""
	# Check applied affixes first (highest priority)
	for affix in applied_affixes:
		if affix and affix.effect_type == DiceAffix.EffectType.ADD_DAMAGE_TYPE \
				and affix.effect_value == 0.0:
			var type_str = affix.get_damage_type()
			var mapped = _string_to_element(type_str)
			if mapped != Element.NONE:
				return mapped

	# Check inherent affixes
	for affix in inherent_affixes:
		if affix and affix.effect_type == DiceAffix.EffectType.ADD_DAMAGE_TYPE \
				and affix.effect_value == 0.0:
			var type_str = affix.get_damage_type()
			var mapped = _string_to_element(type_str)
			if mapped != Element.NONE:
				return mapped

	# Fall back to innate element
	return element

func get_effective_damage_type(action_element: ActionEffect.DamageType) -> ActionEffect.DamageType:
	"""Get the DamageType this die contributes as.
	If NONE, inherits the action's element. Otherwise maps to its own type.
	"""
	var eff_element = get_effective_element()
	if eff_element == Element.NONE:
		return action_element
	return ELEMENT_TO_DAMAGE_TYPE.get(eff_element, action_element)

func is_element_match(action_element: ActionEffect.DamageType) -> bool:
	"""Check if this die's effective element matches the action's element.
	NONE dice never count as a match (they inherit, but don't get the bonus).
	"""
	var eff_element = get_effective_element()
	if eff_element == Element.NONE:
		return false
	return ELEMENT_TO_DAMAGE_TYPE.get(eff_element, null) == action_element

static func _string_to_element(type_str: String) -> Element:
	"""Convert a damage type string from DiceAffix to Element enum"""
	match type_str.to_upper():
		"SLASHING": return Element.SLASHING
		"BLUNT": return Element.BLUNT
		"PIERCING": return Element.PIERCING
		"FIRE": return Element.FIRE
		"ICE": return Element.ICE
		"SHOCK": return Element.SHOCK
		"POISON": return Element.POISON
		"SHADOW": return Element.SHADOW
		"FAITH", "HOLY": return Element.FAITH
		_: return Element.NONE

# ============================================================================
# DUPLICATION
# ============================================================================

func duplicate_die() -> DieResource:
	"""Create a deep copy of this die"""
	var copy = DieResource.new(die_type, source)
	copy.die_type = die_type 
	copy.display_name = display_name
	copy.fill_texture = fill_texture
	copy.stroke_texture = stroke_texture
	copy.color = color
	copy.element = element
	copy.element_affix = element_affix  # Reference, not deep copy
	copy.combat_die_scene = combat_die_scene
	copy.pool_die_scene = pool_die_scene
	copy.current_value = current_value
	copy.modified_value = modified_value
	copy.modifier = modifier
	copy.stat_power = stat_power
	copy.stat_bonus = stat_bonus
	copy.tags = tags.duplicate()
	copy.is_locked = is_locked
	copy.can_reroll = can_reroll
	copy.forced_roll_value = forced_roll_value
	copy.is_consumed = false  # Fresh copies are never consumed
	
	# NOTE: is_duplicate is set by the caller (DiceAffixProcessor),
	# not copied from source. Default false.
	
	
	# Deep copy inherent affixes
	for affix in inherent_affixes:
		if affix:
			copy.inherent_affixes.append(affix.duplicate(true))
	
	# Deep copy applied affixes
	for affix in applied_affixes:
		if affix:
			copy.applied_affixes.append(affix.duplicate(true))
	
	# Deep copy inscribed affixes
	for affix in inscribed_affixes:
		if affix:
			copy.inscribed_affixes.append(affix.duplicate(true))
	copy.max_inscription_slots = max_inscription_slots
	
	
	# Copy rarity name
	copy.rarity_name = rarity_name
	
	return copy

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize die to dictionary"""
	var inherent_data: Array[Dictionary] = []
	for affix in inherent_affixes:
		if affix:
			inherent_data.append(affix.to_dict())
	
	var inscribed_data: Array[Dictionary] = []
	for affix in inscribed_affixes:
		if affix:
			inscribed_data.append(affix.to_dict())
	
	
	var applied_data: Array[Dictionary] = []
	for affix in applied_affixes:
		if affix:
			applied_data.append(affix.to_dict())
	
	return {
		"display_name": display_name,
		"die_type": die_type,
		"element": element,
		"color": color.to_html(),
		"current_value": current_value,
		"modified_value": modified_value,
		"modifier": modifier,
		"source": source,
		"tags": tags,
		"is_locked": is_locked,
		"can_reroll": can_reroll,
		"inherent_affixes": inherent_data,
		"applied_affixes": applied_data,
		"inscribed_affixes": inscribed_data,
		# is_consumed is NOT serialized — hand is transient
	}

static func from_dict(data: Dictionary) -> DieResource:
	"""Deserialize die from dictionary"""
	var die = DieResource.new(data.get("die_type", DieType.D6), data.get("source", ""))
	die.display_name = data.get("display_name", "Die")
	die.element = data.get("element", Element.NONE)
	die.color = Color.from_string(data.get("color", "#ffffff"), Color.WHITE)
	die.current_value = data.get("current_value", 1)
	die.modified_value = data.get("modified_value", 1)
	die.modifier = data.get("modifier", 0)
	die.tags = data.get("tags", [])
	die.is_locked = data.get("is_locked", false)
	die.can_reroll = data.get("can_reroll", false)
	
	# Deserialize affixes
	for affix_data in data.get("inherent_affixes", []):
		die.inherent_affixes.append(DiceAffix.from_dict(affix_data))
	
	for affix_data in data.get("applied_affixes", []):
		die.applied_affixes.append(DiceAffix.from_dict(affix_data))
	
	for affix_data in data.get("inscribed_affixes", []):
		die.inscribed_affixes.append(DiceAffix.from_dict(affix_data))
	
	return die

# ============================================================================
# COMPATIBILITY WITH OLD DieData
# ============================================================================

static func from_die_data(die_data) -> DieResource:
	"""Convert old DieData to new DieResource"""
	var die = DieResource.new(die_data.die_type, die_data.source)
	die.current_value = die_data.current_value
	die.modified_value = die_data.current_value
	die.modifier = die_data.modifier
	die.tags = die_data.tags.duplicate() if die_data.tags else []
	die.is_locked = die_data.is_locked
	die.color = die_data.color
	die.icon = die_data.icon
	return die
