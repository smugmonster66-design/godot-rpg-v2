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
	SHADOW
}

# ============================================================================
# BASIC PROPERTIES
# ============================================================================
@export var display_name: String = "Die"
@export var die_type: DieType = DieType.D6
@export var color: Color = Color.WHITE

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

## Runtime affixes added by equipment, blessings, curses, etc.
var applied_affixes: Array[DiceAffix] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal value_modified(old_value: int, new_value: int)

# ============================================================================
# RUNTIME STATE
# ============================================================================
var current_value: int = 1          # Current rolled value (before affixes)
var modified_value: int = 1         # Value after affix modifications
var modifier: int = 0               # Flat modifier from external sources
var source: String = ""             # Where this die came from
var tags: Array[String] = []        # Tags on this die (fire, holy, etc.)
var slot_index: int = -1            # Position in pool (for affix requirements)

# Locking
var is_locked: bool = false         # Can't be removed
var can_reroll: bool = true         # Can use reroll abilities

# Hand consumption state (v2.1)
## True when this hand die has been placed in an action field this turn.
## The die stays in the hand array to preserve positional relationships
## for neighbor-targeting affixes. UI reads this to hide/grey out the die.
var is_consumed: bool = false

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
	print("🎲 _get_default_combat_scene: checking %s" % path)
	if ResourceLoader.exists(path):
		print("  ✅ Found!")
		return load(path)
	# Fallback to generic
	var fallback = "res://scenes/ui/components/dice/combat/combat_die_object_base.tscn"
	print("  ❌ Not found, trying fallback: %s" % fallback)
	if ResourceLoader.exists(fallback):
		return load(fallback)
	print("  ❌ Fallback also not found!")
	return null

func _get_default_pool_scene() -> PackedScene:
	var path = "res://scenes/ui/components/dice/pool/pool_die_d%d.tscn" % die_type
	print("🎲 _get_default_pool_scene: checking %s" % path)
	if ResourceLoader.exists(path):
		print("  ✅ Found!")
		return load(path)
	# Fallback to generic
	var fallback = "res://scenes/ui/components/dice/pool/pool_die_object_base.tscn"
	print("  ❌ Not found, trying fallback: %s" % fallback)
	if ResourceLoader.exists(fallback):
		return load(fallback)
	print("  ❌ Fallback also not found!")
	return null

# ============================================================================
# ROLLING
# ============================================================================

func roll() -> int:
	"""Roll the die and return the value"""
	current_value = randi_range(1, die_type)
	modified_value = current_value + modifier
	return modified_value

func set_value(value: int):
	"""Manually set the die value"""
	current_value = clampi(value, 1, die_type)
	modified_value = current_value + modifier

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
	modified_value = max(1, modified_value)  # Minimum 1
	if old != modified_value:
		value_modified.emit(old, modified_value)

func apply_percent_modifier(percent: float):
	"""Apply a percentage modifier to the modified value"""
	var old = modified_value
	modified_value = int(modified_value * percent)
	modified_value = max(1, modified_value)  # Minimum 1
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
		if affix:
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
}

func get_effective_element() -> Element:
	"""Get the die's effective element after dice affix overrides.
	Priority: ADD_DAMAGE_TYPE affix > innate element > NONE
	"""
	# Check applied affixes first (highest priority)
	for affix in applied_affixes:
		if affix and affix.effect_type == DiceAffix.EffectType.ADD_DAMAGE_TYPE:
			var type_str = affix.get_damage_type()
			var mapped = _string_to_element(type_str)
			if mapped != Element.NONE:
				return mapped
	
	# Check inherent affixes
	for affix in inherent_affixes:
		if affix and affix.effect_type == DiceAffix.EffectType.ADD_DAMAGE_TYPE:
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
		_: return Element.NONE

# ============================================================================
# DUPLICATION
# ============================================================================

func duplicate_die() -> DieResource:
	"""Create a deep copy of this die"""
	var copy = DieResource.new(die_type, source)
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
	copy.tags = tags.duplicate()
	copy.is_locked = is_locked
	copy.can_reroll = can_reroll
	copy.is_consumed = false  # Fresh copies are never consumed
	
	# Deep copy inherent affixes
	for affix in inherent_affixes:
		if affix:
			copy.inherent_affixes.append(affix.duplicate(true))
	
	# Deep copy applied affixes
	for affix in applied_affixes:
		if affix:
			copy.applied_affixes.append(affix.duplicate(true))
	
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
