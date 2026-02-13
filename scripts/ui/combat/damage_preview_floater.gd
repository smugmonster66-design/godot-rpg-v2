# res://scripts/ui/combat/damage_preview_floater.gd
# Floating damage preview — shows per-element damage breakdown above the action field
# Contains 8 pre-built ElementDamageChip children (one per DamageType), toggled via visibility
# Positioned as a child of ActionField; updated whenever placed_dice changes
extends HBoxContainer
class_name DamagePreviewFloater

# ============================================================================
# CHIP LOOKUP
# ============================================================================
## Maps DamageType → ElementDamageChip (built in _ready from child nodes)
var _chips: Dictionary = {}  # ActionEffect.DamageType → ElementDamageChip

## Ordered list of damage types for consistent layout
const ELEMENT_ORDER: Array[int] = [
	ActionEffect.DamageType.SLASHING,
	ActionEffect.DamageType.BLUNT,
	ActionEffect.DamageType.PIERCING,
	ActionEffect.DamageType.FIRE,
	ActionEffect.DamageType.ICE,
	ActionEffect.DamageType.SHOCK,
	ActionEffect.DamageType.POISON,
	ActionEffect.DamageType.SHADOW,
]

## Maps chip node names → DamageType (for discovery)
const CHIP_NAME_MAP: Dictionary = {
	"SlashingChip": ActionEffect.DamageType.SLASHING,
	"BluntChip": ActionEffect.DamageType.BLUNT,
	"PiercingChip": ActionEffect.DamageType.PIERCING,
	"FireChip": ActionEffect.DamageType.FIRE,
	"IceChip": ActionEffect.DamageType.ICE,
	"ShockChip": ActionEffect.DamageType.SHOCK,
	"PoisonChip": ActionEffect.DamageType.POISON,
	"ShadowChip": ActionEffect.DamageType.SHADOW,
}

## Maps DamageType → Affix.Category for type-specific damage bonuses
## Mirrors CombatCalculator._apply_damage_bonuses() type_categories
const TYPE_BONUS_CATEGORIES: Dictionary = {
	ActionEffect.DamageType.SLASHING: "SLASHING_DAMAGE_BONUS",
	ActionEffect.DamageType.BLUNT: "BLUNT_DAMAGE_BONUS",
	ActionEffect.DamageType.PIERCING: "PIERCING_DAMAGE_BONUS",
	ActionEffect.DamageType.FIRE: "FIRE_DAMAGE_BONUS",
	ActionEffect.DamageType.ICE: "ICE_DAMAGE_BONUS",
	ActionEffect.DamageType.SHOCK: "SHOCK_DAMAGE_BONUS",
	ActionEffect.DamageType.POISON: "POISON_DAMAGE_BONUS",
	ActionEffect.DamageType.SHADOW: "SHADOW_DAMAGE_BONUS",
}

# ============================================================================
# STATE
# ============================================================================
## Tracks which elements are currently displayed (for transition logic)
var _active_elements: Dictionary = {}  # DamageType → bool

## Whether the floater has been configured (guards against early calls)
var _is_configured: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = AlignmentMode.ALIGNMENT_CENTER
	
	# Add a small gap between chips
	add_theme_constant_override("separation", 6)
	
	# Discover and configure all 8 chips
	_discover_chips()
	_is_configured = true

func _discover_chips():
	"""Find child ElementDamageChip nodes and configure them by element."""
	for child in get_children():
		if child is ElementDamageChip:
			var chip_name = child.name
			if CHIP_NAME_MAP.has(chip_name):
				var dt: ActionEffect.DamageType = CHIP_NAME_MAP[chip_name]
				_chips[dt] = child
				child.configure(dt)
				_active_elements[dt] = false
	
	if _chips.size() == 0:
		push_warning("DamagePreviewFloater: No ElementDamageChip children found. Expected 8 named chips.")
	elif _chips.size() < 8:
		push_warning("DamagePreviewFloater: Only found %d / 8 chips." % _chips.size())

# ============================================================================
# UPDATE PREVIEW — called by ActionField._update_damage_preview()
# ============================================================================

func update_preview(
	placed_dice: Array,
	action_element: ActionEffect.DamageType,
	base_damage: int,
	p_damage_multiplier: float,
	action_resource: Action = null,
	attacker_affixes: AffixPoolManager = null
):
	"""
	Recalculate and display per-element damage breakdown.
	
	When action_resource is provided, iterates its effects array to properly
	route dice into per-effect element buckets with per-effect base_damage and
	multipliers — matching CombatCalculator.calculate_attack_damage() logic.
	
	When attacker_affixes is provided, applies:
	  - Global DAMAGE_BONUS → primary element
	  - Type-specific bonuses (FIRE_DAMAGE_BONUS, etc.) → respective elements
	  - DAMAGE_MULTIPLIER → scales all buckets
	This mirrors CombatCalculator Steps 2 & 3.
	
	Falls back gracefully when either is null.
	"""
	if not _is_configured:
		return
	
	# No dice placed → hide everything
	if placed_dice.is_empty():
		clear()
		return
	
	# Step 1: Calculate base element breakdown from dice + effects
	var damages: Dictionary = {}
	
	if action_resource and not action_resource.effects.is_empty():
		damages = _calculate_from_effects(placed_dice, action_resource.effects)
	else:
		# Legacy fallback — single element, flat base/mult
		damages = CombatCalculator.calculate_preview_damage(
			placed_dice, action_element, base_damage, p_damage_multiplier
		)
	
	# Step 2: Apply attacker affix damage bonuses (mirrors CombatCalculator Step 2)
	if attacker_affixes:
		var primary_element = action_element
		if action_resource and not action_resource.effects.is_empty():
			primary_element = _get_primary_element(action_resource.effects)
		_apply_affix_damage_bonuses(damages, attacker_affixes, primary_element)
	
	# Step 3: Apply global damage multiplier from affixes (mirrors CombatCalculator Step 3)
	if attacker_affixes:
		var damage_mult = _calculate_affix_damage_multiplier(attacker_affixes)
		if damage_mult != 1.0:
			for dt in damages:
				damages[dt] *= damage_mult
	
	# Update each chip
	_apply_damages_to_chips(damages)

# ============================================================================
# EFFECT-AWARE PREVIEW CALCULATION (Step 1)
# ============================================================================

func _calculate_from_effects(
	placed_dice: Array,
	effects: Array[ActionEffect]
) -> Dictionary:
	"""
	Walk the Action's effects array and build per-element damage totals.
	Mirrors CombatCalculator.calculate_attack_damage() Step 1 logic.
	"""
	var damages: Dictionary = {}
	var dice_index: int = 0
	
	for effect in effects:
		if effect.effect_type != ActionEffect.EffectType.DAMAGE:
			continue
		
		var effect_element: ActionEffect.DamageType = effect.damage_type
		
		# Track per-effect buckets so the multiplier only scales this effect's contribution
		var effect_damages: Dictionary = {}
		
		# Route each die's value into its element bucket
		for i in range(effect.dice_count):
			if dice_index >= placed_dice.size():
				break
			
			var die = placed_dice[dice_index]
			dice_index += 1
			
			if die is DieResource:
				var die_value: float = float(die.get_total_value())
				var die_damage_type: ActionEffect.DamageType = die.get_effective_damage_type(effect_element)
				
				# Element match bonus
				if die.is_element_match(effect_element):
					die_value *= CombatCalculator.ELEMENT_MATCH_BONUS
				
				effect_damages[die_damage_type] = effect_damages.get(die_damage_type, 0.0) + die_value
		
		# Base damage → effect's element
		if effect.base_damage > 0:
			effect_damages[effect_element] = effect_damages.get(effect_element, 0.0) + float(effect.base_damage)
		
		# Apply per-effect multiplier
		if effect.damage_multiplier != 1.0:
			for dt in effect_damages:
				effect_damages[dt] *= effect.damage_multiplier
		
		# Merge into totals
		for dt in effect_damages:
			damages[dt] = damages.get(dt, 0.0) + effect_damages[dt]
	
	return damages

# ============================================================================
# AFFIX BONUS APPLICATION (Steps 2 & 3)
# ============================================================================

func _apply_affix_damage_bonuses(
	damages: Dictionary,
	affixes: AffixPoolManager,
	primary_damage_type: ActionEffect.DamageType
):
	"""
	Apply flat damage bonuses from attacker affixes.
	Mirrors CombatCalculator._apply_damage_bonuses().
	
	- Global DAMAGE_BONUS → added to the primary element bucket
	- Type-specific bonuses (FIRE_DAMAGE_BONUS, etc.) → added to their element
	"""
	# Global damage bonus → primary element
	var global_bonus: float = 0.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_BONUS):
		global_bonus += affix.apply_effect()
	
	if global_bonus > 0:
		damages[primary_damage_type] = damages.get(primary_damage_type, 0.0) + global_bonus
	
	# Type-specific bonuses
	for damage_type in TYPE_BONUS_CATEGORIES:
		var category_name: String = TYPE_BONUS_CATEGORIES[damage_type]
		if category_name in Affix.Category:
			var category = Affix.Category.get(category_name)
			var type_bonus: float = 0.0
			for affix in affixes.get_pool(category):
				type_bonus += affix.apply_effect()
			if type_bonus > 0:
				damages[damage_type] = damages.get(damage_type, 0.0) + type_bonus

func _calculate_affix_damage_multiplier(affixes: AffixPoolManager) -> float:
	"""
	Calculate total damage multiplier from attacker affixes.
	Mirrors CombatCalculator._calculate_damage_multiplier().
	"""
	var mult: float = 1.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_MULTIPLIER):
		mult *= affix.apply_effect()
	return mult

# ============================================================================
# HELPER: Get primary element from effects
# ============================================================================

func _get_primary_element(effects: Array[ActionEffect]) -> ActionEffect.DamageType:
	"""Get the primary damage element from the first damage effect."""
	for effect in effects:
		if effect.effect_type == ActionEffect.EffectType.DAMAGE:
			return effect.damage_type
	return ActionEffect.DamageType.SLASHING

# ============================================================================
# APPLY DAMAGES TO CHIPS
# ============================================================================

func _apply_damages_to_chips(damages: Dictionary):
	"""Show/update/dismiss chips based on the calculated damage dict."""
	for dt_int in ELEMENT_ORDER:
		var dt: ActionEffect.DamageType = dt_int as ActionEffect.DamageType
		if not _chips.has(dt):
			continue
		
		var chip: ElementDamageChip = _chips[dt]
		var value: int = int(damages.get(dt, 0.0))
		var was_active: bool = _active_elements.get(dt, false)
		
		if value > 0:
			if not was_active:
				# New element appearing — spawn animation
				chip.show_with_value(value)
				_active_elements[dt] = true
			else:
				# Existing element updating — tick animation
				chip.update_value(value)
		else:
			if was_active:
				# Element dropped to zero — dismiss
				chip.dismiss()
				_active_elements[dt] = false

# ============================================================================
# CLEAR — instant hide all chips
# ============================================================================

func clear():
	"""Hide all chips immediately (for field clear/cancel)."""
	for dt in _chips:
		var chip: ElementDamageChip = _chips[dt]
		chip.hide_instant()
		_active_elements[dt] = false

# ============================================================================
# QUERIES
# ============================================================================

func has_active_chips() -> bool:
	"""Returns true if any chip is currently displaying a value."""
	for dt in _active_elements:
		if _active_elements[dt]:
			return true
	return false

func get_active_count() -> int:
	"""Returns how many elements are currently displayed."""
	var count: int = 0
	for dt in _active_elements:
		if _active_elements[dt]:
			count += 1
	return count

func get_total_displayed_damage() -> int:
	"""Sum of all currently displayed chip values."""
	var total: int = 0
	for dt in _chips:
		var chip: ElementDamageChip = _chips[dt]
		if chip.is_active():
			total += chip.get_displayed_value()
	return total
