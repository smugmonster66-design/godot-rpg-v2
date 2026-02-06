# res://resources/data/affix.gd
# Standalone affix resource with category-based effects
extends Resource
class_name Affix

# ============================================================================
# CATEGORY ENUM
# ============================================================================
enum Category {
	NONE,
	# Stat Bonuses (flat)
	STRENGTH_BONUS,
	AGILITY_BONUS,
	INTELLECT_BONUS,
	LUCK_BONUS,
	# Stat Multipliers
	STRENGTH_MULTIPLIER,
	AGILITY_MULTIPLIER,
	INTELLECT_MULTIPLIER,
	LUCK_MULTIPLIER,
	# Global Combat Modifiers
	DAMAGE_BONUS,
	DAMAGE_MULTIPLIER,
	DEFENSE_BONUS,
	DEFENSE_MULTIPLIER,
	# Physical Defense
	ARMOR_BONUS,
	# Elemental Resistances
	FIRE_RESIST_BONUS,
	ICE_RESIST_BONUS,
	SHOCK_RESIST_BONUS,
	POISON_RESIST_BONUS,
	SHADOW_RESIST_BONUS,
	# Type-Specific Damage Bonuses
	SLASHING_DAMAGE_BONUS,
	BLUNT_DAMAGE_BONUS,
	PIERCING_DAMAGE_BONUS,
	FIRE_DAMAGE_BONUS,
	ICE_DAMAGE_BONUS,
	SHOCK_DAMAGE_BONUS,
	POISON_DAMAGE_BONUS,
	SHADOW_DAMAGE_BONUS,
	# Other
	BARRIER_BONUS,
	HEALTH_BONUS,
	MANA_BONUS,
	# Special
	ELEMENTAL,
	NEW_ACTION,
	DICE,
	PER_TURN,
	ON_HIT,
	PROC,
	MISC
}

# ============================================================================
# BASIC DATA
# ============================================================================
@export var affix_name: String = "New Affix"
@export_multiline var description: String = "An affix effect"
@export var icon: Texture2D = null

# ============================================================================
# DISPLAY OPTIONS (NEW)
# ============================================================================
@export_group("Display")
## Whether this affix appears in item summary tooltips
@export var show_in_summary: bool = true
@export var show_in_active_list: bool = true


# ============================================================================
# CATEGORIZATION
# ============================================================================
@export var category: Category = Category.NONE

# ============================================================================
# SOURCE TRACKING
# ============================================================================
var source: String = ""
var source_type: String = ""

# ============================================================================
# EFFECT DATA
# ============================================================================
@export_group("Effect Values")
## For simple numeric bonuses/multipliers
@export var effect_number: float = 0.0
## For complex effects that need multiple values
@export var effect_data: Dictionary = {}

# ============================================================================
# GRANTED ACTION (for NEW_ACTION category)
# ============================================================================
@export_group("Granted Action")
## Drag an Action resource here if this affix grants a combat action
@export var granted_action: Action = null


# ============================================================================
# GRANTED DICE (for DICE category)
# ============================================================================
@export_group("Granted Dice")
## Dice added to the player's pool when this affix is active.
## Use with category DICE. Drag DieResource files here.
@export var granted_dice: Array[DieResource] = []


# ============================================================================
# DICE VISUAL EFFECTS (NEW)
# ============================================================================
@export_group("Dice Visual Effects")
## Optional DiceAffix to apply visual effects to dice granted by this item
## This allows an item affix to both grant an action AND make dice look special
@export var dice_visual_affix: DiceAffix = null

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func apply_effect() -> Variant:
	"""Apply this affix's effect and return the result"""
	
	# If this grants an action, return it
	if granted_action and category == Category.NEW_ACTION:
		return granted_action
	
	# If this grants dice, return them
	if granted_dice.size() > 0 and category == Category.DICE:
		return granted_dice
	
	if effect_number != 0.0:
		return effect_number
	elif effect_data.size() > 0:
		return effect_data
	
	return 0.0



func can_stack_with(other_affix: Affix) -> bool:
	"""Check if this affix can stack with another"""
	if affix_name != other_affix.affix_name:
		return true
	return source != other_affix.source

# ============================================================================
# DICE VISUAL HELPERS (NEW)
# ============================================================================

func has_visual_effects() -> bool:
	"""Check if this affix includes visual effects for dice"""
	return dice_visual_affix != null and dice_visual_affix.has_any_visual_effect()

func get_dice_visual_affix() -> DiceAffix:
	"""Get the DiceAffix for visual effects (may be null)"""
	return dice_visual_affix

# ============================================================================
# CATEGORY HELPERS
# ============================================================================

func is_category(check_category: Category) -> bool:
	"""Check if this affix has a specific category"""
	return category == check_category

func get_category_name() -> String:
	"""Get category name for display"""
	return Category.keys()[category].capitalize().replace("_", " ")

# ============================================================================
# UTILITY
# ============================================================================

func duplicate_with_source(p_source: String, p_source_type: String) -> Affix:
	"""Create a copy of this affix with a specific source"""
	var copy = duplicate(true)
	copy.source = p_source
	copy.source_type = p_source_type
	return copy

func matches_source(p_source: String) -> bool:
	"""Check if this affix came from a specific source"""
	return source == p_source

func get_display_text() -> String:
	"""Get formatted display text for UI"""
	var text = affix_name
	if source:
		text += " (from %s)" % source
	return text

func _to_string() -> String:
	return "Affix<%s: %s>" % [affix_name, get_category_name()]
