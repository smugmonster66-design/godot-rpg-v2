# res://resources/data/dice_affix.gd
# Affix system specifically for dice
# Separate from item affixes, these affect dice behavior based on position and neighbors
#
# v2 CHANGELOG:
#   - Added ValueSource enum for dynamic value resolution
#   - Added new EffectTypes: RANDOMIZE_ELEMENT, LEECH_HEAL, DESTROY_SELF,
#     REMOVE_ALL_TAGS, SET_ELEMENT
#   - Added @export condition: DiceAffixCondition (inspector resource)
#   - Added @export value_source: ValueSource
#   - Added @export sub_effects: Array[DiceAffixSubEffect] for compound effects
#   - Updated serialization (to_dict / from_dict) for new fields
#   - All existing fields, visual systems, methods preserved — no breaking changes
extends Resource
class_name DiceAffix

# ============================================================================
# ENUMS
# ============================================================================

## When does this affix trigger?
enum Trigger {
	ON_ROLL,           # When the die is rolled at turn start
	ON_USE,            # When the die is placed in an action field
	PASSIVE,           # Always active while in collection
	ON_REORDER,        # When dice are reordered (drag-drop)
	ON_COMBAT_START,   # At the start of combat
	ON_COMBAT_END,     # At the end of combat
}

## What position does this affix require?
enum PositionRequirement {
	ANY,               # Works in any slot
	FIRST,             # Only works in first slot (index 0)
	LAST,              # Only works in last slot
	NOT_FIRST,         # Works anywhere except first
	NOT_LAST,          # Works anywhere except last
	SPECIFIC_SLOT,     # Works in a specific slot (use required_slot)
	EVEN_SLOTS,        # Works in even-indexed slots (0, 2, 4...)
	ODD_SLOTS,         # Works in odd-indexed slots (1, 3, 5...)
}

## What does this affix target?
enum NeighborTarget {
	SELF,              # Only affects this die
	LEFT,              # Affects die to the left
	RIGHT,             # Affects die to the right
	BOTH_NEIGHBORS,    # Affects dice on both sides
	ALL_LEFT,          # Affects all dice to the left
	ALL_RIGHT,         # Affects all dice to the right
	ALL_OTHERS,        # Affects all other dice
	ALL_DICE,          # Affects all dice including self
}

## What type of effect does this apply?
enum EffectType {
	# Value modifications
	MODIFY_VALUE_FLAT,       # Add flat value to roll
	MODIFY_VALUE_PERCENT,    # Multiply roll value
	SET_MINIMUM_VALUE,       # Set minimum roll value
	SET_MAXIMUM_VALUE,       # Set maximum roll value
	SET_ROLL_VALUE,
	
	# Tag modifications
	ADD_TAG,                 # Add a tag to die/target
	REMOVE_TAG,              # Remove a tag from die/target
	COPY_TAGS,               # Copy tags from neighbor
	REMOVE_ALL_TAGS,         # Remove ALL tags (v2) — used by Purify
	
	# Reroll effects
	GRANT_REROLL,            # Allow rerolling this die
	AUTO_REROLL_LOW,         # Automatically reroll if below threshold
	
	# Special effects
	DUPLICATE_ON_MAX,        # Create copy if max value rolled
	LOCK_DIE,                # Prevent die from being consumed
	CHANGE_DIE_TYPE,         # Transform die type (d6 -> d8)
	COPY_NEIGHBOR_VALUE,     # Copy percentage of neighbor's value
	
	# Combat effects
	ADD_DAMAGE_TYPE,         # Add elemental damage type
	GRANT_STATUS_EFFECT,     # Apply status on use
	
	# Meta effects
	CONDITIONAL,             # Effect only if condition met (legacy — prefer condition resource)
	
	# --- NEW (v2) ---
	RANDOMIZE_ELEMENT,       # Set element to random from effect_data.elements
	LEECH_HEAL,              # % of damage dealt returned as healing (stored for combat)
	DESTROY_SELF,            # Permanently remove this die from pool after use
	SET_ELEMENT,             # Set die element to effect_data.element
	CREATE_COMBAT_MODIFIER,  # Push a CombatModifier (set via combat_modifier export)
	
	# --- Combat Event Emitters (v4 — Mana System) ---
	EMIT_SPLASH_DAMAGE,      # Splash dmg to adjacent enemies. effect_data: {element, percent}
	EMIT_CHAIN_DAMAGE,       # Chain dmg to N targets. effect_data: {element, chains, decay}
	EMIT_AOE_DAMAGE,         # AoE dmg to all enemies. effect_data: {element}
	EMIT_BONUS_DAMAGE,       # Flat/percent bonus dmg. effect_data: {element}
	
	# --- Mana Event Emitters (v4) ---
	MANA_REFUND,             # Refund % of last pull cost. effect_value = percent (0.0–1.0)
	MANA_GAIN,               # Gain flat mana. effect_value = amount
	
	# --- Dice Manipulation (v4) ---
	ROLL_KEEP_HIGHEST,       # Roll N times, keep highest. effect_value = extra_rolls
	GRANT_EXTRA_ROLL,        # Grant reroll keeping best. effect_value = extra_rolls
	IGNORE_RESISTANCE,       # Bypass target resistance. effect_data: {element}
}

## Where does the effect magnitude come from? (v2)
## STATIC uses the literal effect_value. Others derive the value at runtime.
enum ValueSource {
	STATIC,              # Use effect_value as-is (default, backwards-compatible)
	SELF_VALUE,          # This die's get_total_value()
	SELF_VALUE_FRACTION, # This die's get_total_value() * effect_value
	NEIGHBOR_VALUE,      # Targeted neighbor's get_total_value()
	NEIGHBOR_PERCENT,    # Targeted neighbor's get_total_value() * effect_value
	CONTEXT_USED_COUNT,  # context.used_count * effect_value
	SELF_TAGS,           # For tag-copy effects: uses source die's tags
	PARENT_TARGET_VALUE,   # (v2.1) First die from parent affix's neighbor_target — raw value
	PARENT_TARGET_PERCENT, # (v2.1) First die from parent affix's neighbor_target — value * effect_value
	SNAPSHOT_TARGET_VALUE,
	SNAPSHOT_TARGET_PERCENT,
	# --- Mana Context (v4) ---
	CONTEXT_ELEMENT_DICE_USED,  # context.element_use_counts[element] * effect_value
	CONTEXT_DICE_PLACED,        # context.used_count * effect_value (alias)
}

enum VisualEffectType {
	NONE,              # No visual effect
	COLOR_TINT,        # Tint the component a color
	OVERLAY_TEXTURE,   # Overlay a texture on top
	PARTICLE,          # Add particle effect
	SHADER,            # Apply a shader
	BORDER_GLOW,       # Glowing border effect
}

## Value label specific effects
enum ValueEffectType {
	NONE,              # No effect on value label
	COLOR,             # Change text color
	OUTLINE_COLOR,     # Change outline color
	SHADER,            # Apply shader to label
	COLOR_AND_OUTLINE, # Change both colors
}

# ============================================================================
# BASIC DATA
# ============================================================================
@export var affix_name: String = "New Dice Affix"
@export_multiline var description: String = "A dice affix effect"
@export var icon: Texture2D = null

# ============================================================================
# DISPLAY OPTIONS
# ============================================================================
@export_group("Display")
## Whether this affix appears in die summary tooltips
@export var show_in_summary: bool = true

# ============================================================================
# RARITY METADATA
# ============================================================================
@export_group("Rarity Metadata")

## Which rarity tier this affix belongs to (for table organization / UI).
## 0 = untiered (inherent/element affixes), 1-3 = rollable tiers.
@export_range(0, 3) var affix_tier: int = 0

## Die rarity this affix was rolled on (stamped at generation time).
## -1 = not yet stamped (template). Runtime only, not saved on templates.
var rolled_on_rarity: int = -1

## When true, fill/stroke/value materials are pulled from GameManager.ELEMENT_VISUALS
## instead of this affix's own material fields. Set the element_type below.
@export var use_global_element_visuals: bool = false

## Which element to look up in the global config (only used when use_global_element_visuals = true)
@export var global_element_type: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING


# ============================================================================
# TRIGGER CONFIGURATION
# ============================================================================
@export_group("Trigger")
@export var trigger: Trigger = Trigger.ON_ROLL

# ============================================================================
# POSITION CONFIGURATION
# ============================================================================
@export_group("Position")
@export var position_requirement: PositionRequirement = PositionRequirement.ANY
@export var required_slot: int = 0  # Used with SPECIFIC_SLOT

# ============================================================================
# TARGET CONFIGURATION
# ============================================================================
@export_group("Target")
@export var neighbor_target: NeighborTarget = NeighborTarget.SELF

# ============================================================================
# CONDITION (v2) — checked after trigger/position, before effect
# ============================================================================
@export_group("Condition")
## Optional condition resource. If null or NONE, affix always fires.
## Drag a DiceAffixCondition resource here to gate or scale this affix.
@export var condition: DiceAffixCondition = null

# ============================================================================
# EFFECT CONFIGURATION
# ============================================================================
@export_group("Effect")
@export var effect_type: EffectType = EffectType.MODIFY_VALUE_FLAT
@export var effect_value: float = 0.0

## Minimum effect value across the full item level range (level 1 item).
## Set both min and max to 0.0 to disable scaling (uses static effect_value).
@export var effect_value_min: float = 0.0

## Maximum effect value across the full item level range (level 100 item).
@export var effect_value_max: float = 0.0

## Optional per-affix scaling curve override. Leave null to use linear.
@export var effect_curve: Curve = null

## Per-affix fuzz override. -1.0 = use global default from AffixScalingConfig.
## 0.0 = deterministic, 0.15 = ±15% spread.
@export_range(-1.0, 1.0) var roll_fuzz: float = -1.0

## Where does the effect magnitude come from? (v2)
## STATIC = use effect_value literally. Others derive at runtime.
@export var value_source: ValueSource = ValueSource.STATIC

## Complex effect data for effects that need multiple values
## Examples:
## - ADD_TAG: {"tag": "fire"}
## - AUTO_REROLL_LOW: {"threshold": 2}
## - COPY_NEIGHBOR_VALUE: {"percent": 0.25}
## - RANDOMIZE_ELEMENT: {"elements": ["FIRE", "ICE", "SHOCK", "POISON"]}
## - LEECH_HEAL: {"percent": 0.1}
## - SET_ELEMENT: {"element": "FIRE"}
## - ADD_DAMAGE_TYPE: {"type": "fire", "percent": 0.5}
## - CONDITIONAL (legacy): {"condition": "value_above", "threshold": 6, ...}
@export var effect_data: Dictionary = {}

# ============================================================================
# SUB-EFFECTS (v2) — Compound effects
# ============================================================================
@export_group("Sub-Effects (Compound)")
## When non-empty, the processor iterates these INSTEAD of the top-level
## effect_type. Each DiceAffixSubEffect is a full inspector resource with
## its own effect_type, value, target override, and optional condition.
##
## Example — Siphon (steal 25% from left, add to self):
##   sub_effects[0]: MODIFY_VALUE_FLAT, value_source=NEIGHBOR_PERCENT,
##                   effect_value=-0.25, target_override=LEFT
##   sub_effects[1]: MODIFY_VALUE_FLAT, value_source=NEIGHBOR_PERCENT,
##                   effect_value=0.25, target_override=SELF
@export var sub_effects: Array[DiceAffixSubEffect] = []

# ============================================================================
# COMBAT MODIFIER (v2) — for CREATE_COMBAT_MODIFIER effect type
# ============================================================================
@export_group("Combat Modifier")
## CombatModifier resource to push when effect_type is CREATE_COMBAT_MODIFIER.
## The modifier persists across turns within the combat.
@export var combat_modifier: CombatModifier = null

# ============================================================================
# VISUAL EFFECTS (ORIGINAL - unified, for backwards compatibility)
# ============================================================================
@export_group("Visual Effect")
@export var visual_effect_type: VisualEffectType = VisualEffectType.NONE

## Color for COLOR_TINT and BORDER_GLOW effects
@export var effect_color: Color = Color.WHITE

## Texture overlaid on die for OVERLAY_TEXTURE effect
@export var overlay_texture: Texture2D = null

## Overlay blend mode (0=Mix, 1=Add, 2=Multiply)
@export_range(0, 2) var overlay_blend_mode: int = 0

## Overlay opacity
@export_range(0.0, 1.0) var overlay_opacity: float = 0.5

## Particle scene for PARTICLE effect
@export var particle_scene: PackedScene = null

## Shader material for SHADER effect
@export var shader_material: ShaderMaterial = null

## Animation to play (if die face has AnimationPlayer)
@export var animation_name: String = ""

## Effect priority (higher = applied later/on top)
@export var visual_priority: int = 0

# ============================================================================
# FILL TEXTURE VISUAL EFFECTS (per-component)
# ============================================================================
@export_group("Fill Texture Effects")
@export var fill_effect_type: VisualEffectType = VisualEffectType.NONE
@export var fill_effect_color: Color = Color.WHITE
@export var fill_shader_material: ShaderMaterial = null
@export var fill_overlay_texture: Texture2D = null
@export_range(0, 2) var fill_overlay_blend_mode: int = 0
@export_range(0.0, 1.0) var fill_overlay_opacity: float = 0.5

# ============================================================================
# STROKE TEXTURE VISUAL EFFECTS (per-component)
# ============================================================================
@export_group("Stroke Texture Effects")
@export var stroke_effect_type: VisualEffectType = VisualEffectType.NONE
@export var stroke_effect_color: Color = Color.WHITE
@export var stroke_shader_material: ShaderMaterial = null
@export var stroke_overlay_texture: Texture2D = null
@export_range(0, 2) var stroke_overlay_blend_mode: int = 0
@export_range(0.0, 1.0) var stroke_overlay_opacity: float = 0.5

# ============================================================================
# VALUE LABEL VISUAL EFFECTS (per-component)
# ============================================================================
@export_group("Value Label Effects")
@export var value_effect_type: ValueEffectType = ValueEffectType.NONE
@export var value_text_color: Color = Color.WHITE
@export var value_outline_color: Color = Color.BLACK
@export var value_shader_material: ShaderMaterial = null

# ============================================================================
# PREVIEW-ONLY VISUAL EFFECTS
# ============================================================================
@export_group("Preview Effects (Drag Only)")
## Effects that only appear on the drag preview, not the normal die display
## Add PreviewEffect resources here - each one can have fill/stroke/label effects
@export var preview_effects: Array[PreviewEffect] = []


# ============================================================================
# ROLL VISUAL EFFECT (v2.2) — animated effect on affix activation
# ============================================================================
@export_group("Roll Animation")
## Optional visual animation played when this affix activates.
## Supports projectiles between dice, flash/pulse on source and/or target.
@export var roll_visual: AffixRollVisual = null



# ============================================================================
# SOURCE TRACKING
# ============================================================================
var source: String = ""
var source_type: String = ""  # "item", "skill", "enemy", etc.

# ============================================================================
# POSITION CHECKING
# ============================================================================

func check_position(slot_index: int, total_slots: int) -> bool:
	"""Check if position requirement is met"""
	match position_requirement:
		PositionRequirement.ANY:
			return true
		PositionRequirement.FIRST:
			return slot_index == 0
		PositionRequirement.LAST:
			return slot_index == total_slots - 1
		PositionRequirement.NOT_FIRST:
			return slot_index > 0
		PositionRequirement.NOT_LAST:
			return slot_index < total_slots - 1
		PositionRequirement.SPECIFIC_SLOT:
			return slot_index == required_slot
		PositionRequirement.EVEN_SLOTS:
			return slot_index % 2 == 0
		PositionRequirement.ODD_SLOTS:
			return slot_index % 2 == 1
	return true

func get_target_indices(source_index: int, total_dice: int) -> Array[int]:
	"""Get indices of dice this affix targets based on neighbor_target"""
	var targets: Array[int] = []
	
	match neighbor_target:
		NeighborTarget.SELF:
			targets.append(source_index)
		
		NeighborTarget.LEFT:
			if source_index > 0:
				targets.append(source_index - 1)
		
		NeighborTarget.RIGHT:
			if source_index < total_dice - 1:
				targets.append(source_index + 1)
		
		NeighborTarget.BOTH_NEIGHBORS:
			if source_index > 0:
				targets.append(source_index - 1)
			if source_index < total_dice - 1:
				targets.append(source_index + 1)
		
		NeighborTarget.ALL_LEFT:
			for i in range(source_index):
				targets.append(i)
		
		NeighborTarget.ALL_RIGHT:
			for i in range(source_index + 1, total_dice):
				targets.append(i)
		
		NeighborTarget.ALL_OTHERS:
			for i in range(total_dice):
				if i != source_index:
					targets.append(i)
		
		NeighborTarget.ALL_DICE:
			for i in range(total_dice):
				targets.append(i)
	
	return targets

## Helper to resolve target indices for a specific NeighborTarget (used by sub-effects)
func get_target_indices_for(target: NeighborTarget, source_index: int, total_dice: int) -> Array[int]:
	var targets: Array[int] = []
	match target:
		NeighborTarget.SELF:
			targets.append(source_index)
		NeighborTarget.LEFT:
			if source_index > 0:
				targets.append(source_index - 1)
		NeighborTarget.RIGHT:
			if source_index < total_dice - 1:
				targets.append(source_index + 1)
		NeighborTarget.BOTH_NEIGHBORS:
			if source_index > 0:
				targets.append(source_index - 1)
			if source_index < total_dice - 1:
				targets.append(source_index + 1)
		NeighborTarget.ALL_LEFT:
			for i in range(source_index):
				targets.append(i)
		NeighborTarget.ALL_RIGHT:
			for i in range(source_index + 1, total_dice):
				targets.append(i)
		NeighborTarget.ALL_OTHERS:
			for i in range(total_dice):
				if i != source_index:
					targets.append(i)
		NeighborTarget.ALL_DICE:
			for i in range(total_dice):
				targets.append(i)
	return targets

# ============================================================================
# CONDITION CHECKING (v2)
# ============================================================================

func has_condition() -> bool:
	"""Check if this affix has a non-trivial condition."""
	return condition != null and condition.type != DiceAffixCondition.Type.NONE

func evaluate_condition(source_die, dice_array: Array, source_index: int, context: Dictionary) -> DiceAffixCondition.Result:
	"""Evaluate this affix's condition. Returns pass if no condition set."""
	if not has_condition():
		return DiceAffixCondition.Result.pass_result()
	return condition.evaluate(source_die, dice_array, source_index, context)

# ============================================================================
# COMPOUND EFFECT CHECKING (v2)
# ============================================================================

func is_compound() -> bool:
	"""Check if this affix uses sub-effects instead of a single effect."""
	return sub_effects.size() > 0

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func get_value_modifier() -> float:
	"""Get the numeric modifier for value-based effects"""
	return effect_value

func get_effect_tag() -> String:
	"""Get the tag for tag-based effects"""
	return effect_data.get("tag", "")

func get_threshold() -> int:
	"""Get threshold for threshold-based effects"""
	return int(effect_data.get("threshold", 0))

func get_percent() -> float:
	"""Get percentage for percent-based effects"""
	return effect_data.get("percent", 0.0)

func get_new_die_type() -> int:
	"""Get new die type for CHANGE_DIE_TYPE effect"""
	return int(effect_data.get("new_type", 6))

func get_damage_type() -> String:
	"""Get damage type for ADD_DAMAGE_TYPE effect"""
	return effect_data.get("type", "physical")

func get_status_effect() -> Dictionary:
	"""Get status effect data for GRANT_STATUS_EFFECT"""
	return effect_data.get("status", {})

func get_random_elements() -> Array:
	"""Get element list for RANDOMIZE_ELEMENT (v2)"""
	return effect_data.get("elements", ["FIRE", "ICE", "SHOCK", "POISON"])

func get_set_element() -> String:
	"""Get element for SET_ELEMENT (v2)"""
	return effect_data.get("element", "NONE")

# ============================================================================
# VISUAL EFFECT HELPERS
# ============================================================================

func has_any_visual_effect() -> bool:
	"""Check if this affix has any visual effects configured"""
	return (visual_effect_type != VisualEffectType.NONE or
			fill_effect_type != VisualEffectType.NONE or 
			stroke_effect_type != VisualEffectType.NONE or 
			value_effect_type != ValueEffectType.NONE or
			particle_scene != null)

func has_per_component_effects() -> bool:
	"""Check if using new per-component effects"""
	return (fill_effect_type != VisualEffectType.NONE or
			stroke_effect_type != VisualEffectType.NONE or
			value_effect_type != ValueEffectType.NONE)

func has_preview_effects() -> bool:
	"""Check if this affix has preview-only effects"""
	return preview_effects.size() > 0

func get_preview_effects() -> Array[PreviewEffect]:
	"""Get all preview effects"""
	return preview_effects

# ============================================================================
# DESCRIPTION GENERATION
# ============================================================================

func get_formatted_description() -> String:
	"""Generate a formatted description with actual values"""
	var text = description
	
	# Replace placeholders
	text = text.replace("{value}", str(effect_value))
	text = text.replace("{percent}", str(int(get_percent() * 100)) + "%")
	text = text.replace("{threshold}", str(get_threshold()))
	text = text.replace("{tag}", get_effect_tag())
	text = text.replace("{slot}", str(required_slot + 1))  # 1-indexed for display
	
	# Add position info if not ANY
	if position_requirement != PositionRequirement.ANY:
		text += " [" + _get_position_text() + "]"
	
	# Add condition info if present (v2)
	if has_condition():
		var cond_text = condition.get_description()
		if cond_text:
			text += " (%s)" % cond_text
	
	return text

func _get_position_text() -> String:
	"""Get human-readable position requirement text"""
	match position_requirement:
		PositionRequirement.FIRST: return "First slot"
		PositionRequirement.LAST: return "Last slot"
		PositionRequirement.NOT_FIRST: return "Not first"
		PositionRequirement.NOT_LAST: return "Not last"
		PositionRequirement.SPECIFIC_SLOT: return "Slot %d" % (required_slot + 1)
		PositionRequirement.EVEN_SLOTS: return "Even slots"
		PositionRequirement.ODD_SLOTS: return "Odd slots"
	return ""



# ============================================================================
# GLOBAL ELEMENT VISUAL RESOLUTION
# ============================================================================

# ============================================================================
# GLOBAL ELEMENT VISUAL RESOLUTION
# ============================================================================

func resolve_fill_material() -> ShaderMaterial:
	"""Get fill material — from global config if flagged, otherwise own field"""
	if use_global_element_visuals and GameManager.ELEMENT_VISUALS:
		return GameManager.ELEMENT_VISUALS.get_fill_material(global_element_type)
	if fill_shader_material:
		return fill_shader_material.duplicate(true)
	return null

func resolve_stroke_material() -> ShaderMaterial:
	"""Get stroke material — from global config if flagged, otherwise own field"""
	if use_global_element_visuals and GameManager.ELEMENT_VISUALS:
		return GameManager.ELEMENT_VISUALS.get_stroke_material(global_element_type)
	if stroke_shader_material:
		return stroke_shader_material.duplicate(true)
	return null

func resolve_value_material() -> ShaderMaterial:
	"""Get value material — from global config if flagged, otherwise own field"""
	if use_global_element_visuals and GameManager.ELEMENT_VISUALS:
		return GameManager.ELEMENT_VISUALS.get_value_material(global_element_type)
	if value_shader_material:
		return value_shader_material.duplicate(true)
	return null



# ============================================================================
# UTILITY
# ============================================================================

func duplicate_with_source(p_source: String, p_source_type: String) -> DiceAffix:
	"""Create a copy with source tracking"""
	var copy = duplicate(true)
	copy.source = p_source
	copy.source_type = p_source_type
	return copy

func matches_source(p_source: String) -> bool:
	"""Check if from specific source"""
	return source == p_source

func get_display_text() -> String:
	"""Get display text for UI"""
	var text = affix_name
	if source:
		text += " (from %s)" % source
	return text

# ============================================================================
# SERIALIZATION
# ============================================================================

# ============================================================================
# SCALING
# ============================================================================

func has_scaling() -> bool:
	"""Check if this dice affix uses level-based scaling."""
	return not (effect_value_min == 0.0 and effect_value_max == 0.0)


func roll_scaled_value(power_position: float = -1.0,
		scaling_config: AffixScalingConfig = null) -> float:
	"""Roll effect_value based on item level, mirroring Affix.roll_value().

	Args:
		power_position: 0.0 (weakest) to 1.0 (strongest).
		scaling_config: Global config for fuzz. Can be null.

	Returns:
		The rolled value (also stored in effect_value).
	"""
	if not has_scaling():
		return effect_value

	# Legacy: no power_position → pure random
	if power_position < 0.0:
		var t: float = randf()
		if effect_curve:
			t = effect_curve.sample(t)
		effect_value = _round_dice_value(lerpf(effect_value_min, effect_value_max, t))
		return effect_value

	# Step 1: Apply curve
	var t_curved: float = power_position
	if effect_curve:
		t_curved = effect_curve.sample(power_position)

	# Step 2: Center value
	var center: float = lerpf(effect_value_min, effect_value_max, t_curved)

	# Step 3: Fuzz range
	var roll_min_v: float = center
	var roll_max_v: float = center

	if scaling_config:
		var fuzz_range = scaling_config.compute_fuzz_range(
			center, effect_value_min, effect_value_max, roll_fuzz)
		roll_min_v = fuzz_range.min
		roll_max_v = fuzz_range.max
	elif roll_fuzz > 0.0:
		var total_range: float = effect_value_max - effect_value_min
		var fuzz_amount: float = maxf(total_range * roll_fuzz, 0.5)
		roll_min_v = maxf(effect_value_min, center - fuzz_amount)
		roll_max_v = minf(effect_value_max, center + fuzz_amount)

	# Step 4: Roll
	effect_value = _round_dice_value(randf_range(roll_min_v, roll_max_v))
	return effect_value


func _round_dice_value(value: float) -> float:
	"""Round a dice affix value appropriately.

	Percent-style effects (0.0-1.0 range) get 2 decimal places.
	Everything else rounds to nearest 0.5 (for nice die math).
	"""
	if effect_value_max <= 1.0 and effect_value_min >= 0.0:
		return snappedf(value, 0.01)
	elif effect_value_max <= 5.0:
		return snappedf(value, 0.5)
	else:
		return roundf(value)


func get_value_range_string() -> String:
	"""Human-readable value range for tooltips."""
	if not has_scaling():
		return _format_dice_value(effect_value)

	return "%s–%s" % [_format_dice_value(effect_value_min),
					   _format_dice_value(effect_value_max)]


func get_rolled_value_string() -> String:
	"""Current rolled value as display string."""
	return _format_dice_value(effect_value)


func _format_dice_value(val: float) -> String:
	"""Format a value for display."""
	if effect_value_max <= 1.0 and effect_value_min >= 0.0 and effect_value_max > 0.0:
		return "%d%%" % int(val * 100)
	elif val == int(val):
		return "+%d" % int(val)
	else:
		return "+%.1f" % val


func to_dict() -> Dictionary:
	"""Serialize to dictionary"""
	var data := {
		"affix_name": affix_name,
		"description": description,
		"show_in_summary": show_in_summary,
		"trigger": trigger,
		"position_requirement": position_requirement,
		"required_slot": required_slot,
		"neighbor_target": neighbor_target,
		"effect_type": effect_type,
		"effect_value": effect_value,
		"value_source": value_source,
		"effect_data": effect_data,
		"source": source,
		"source_type": source_type,
		"effect_value_min": effect_value_min,
		"effect_value_max": effect_value_max,
		"affix_tier": affix_tier,
		"rolled_on_rarity": rolled_on_rarity,
		# Legacy visual
		"visual_effect_type": visual_effect_type,
		"visual_priority": visual_priority,
		# Per-component visual
		"fill_effect_type": fill_effect_type,
		"stroke_effect_type": stroke_effect_type,
		"value_effect_type": value_effect_type,
	}
	# v2 fields
	if condition:
		data["condition"] = condition.to_dict()
	if sub_effects.size() > 0:
		var subs: Array[Dictionary] = []
		for sub in sub_effects:
			subs.append(sub.to_dict())
		data["sub_effects"] = subs
	return data

static func from_dict(data: Dictionary) -> DiceAffix:
	"""Deserialize from dictionary"""
	var affix = DiceAffix.new()
	affix.affix_name = data.get("affix_name", "Unknown")
	affix.description = data.get("description", "")
	affix.show_in_summary = data.get("show_in_summary", true)
	affix.trigger = data.get("trigger", Trigger.ON_ROLL)
	affix.position_requirement = data.get("position_requirement", PositionRequirement.ANY)
	affix.required_slot = data.get("required_slot", 0)
	affix.neighbor_target = data.get("neighbor_target", NeighborTarget.SELF)
	affix.effect_type = data.get("effect_type", EffectType.MODIFY_VALUE_FLAT)
	affix.effect_value = data.get("effect_value", 0.0)
	affix.value_source = data.get("value_source", ValueSource.STATIC)
	affix.effect_data = data.get("effect_data", {})
	affix.source = data.get("source", "")
	affix.source_type = data.get("source_type", "")
	affix.effect_value_min = data.get("effect_value_min", 0.0)
	affix.effect_value_max = data.get("effect_value_max", 0.0)
	affix.affix_tier = data.get("affix_tier", 0)
	affix.rolled_on_rarity = data.get("rolled_on_rarity", -1)
	# Legacy visual
	affix.visual_effect_type = data.get("visual_effect_type", VisualEffectType.NONE)
	affix.visual_priority = data.get("visual_priority", 0)
	# Per-component visual
	affix.fill_effect_type = data.get("fill_effect_type", VisualEffectType.NONE)
	affix.stroke_effect_type = data.get("stroke_effect_type", VisualEffectType.NONE)
	affix.value_effect_type = data.get("value_effect_type", ValueEffectType.NONE)
	# v2 fields
	if data.has("condition"):
		affix.condition = DiceAffixCondition.from_dict(data["condition"])
	if data.has("sub_effects"):
		for sub_data in data["sub_effects"]:
			affix.sub_effects.append(DiceAffixSubEffect.from_dict(sub_data))
	return affix
