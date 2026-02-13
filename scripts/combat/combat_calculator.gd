# combat_calculator.gd - Handles all damage calculation with split elemental damage
extends RefCounted
class_name CombatCalculator

# ============================================================================
# TUNING CONSTANTS
# ============================================================================

## Multiplier applied to a die's contribution when its element matches the action's element.
## NONE-element dice do NOT receive this bonus.
const ELEMENT_MATCH_BONUS: float = 1.25

## Piercing damage ignores this fraction of armor. 0.5 = ignores half armor.
const PIERCING_ARMOR_PENETRATION: float = 0.5

# ============================================================================
# MAIN DAMAGE CALCULATION
# ============================================================================

static func calculate_attack_damage(
	attacker_affixes: AffixPoolManager,
	action_effects: Array[ActionEffect],
	placed_dice: Array,  # Array of DieResource (untyped for backward compat)
	defender_stats: Dictionary,
	action_id: String = ""
) -> Dictionary:
	"""
	Calculate damage from an attack using split elemental damage.
	
	Each die contributes its rolled value into its own element's damage bucket.
	NONE-element dice inherit the action effect's element.
	Matching-element dice get a bonus multiplier.
	Base damage always goes into the action effect's element.
	
	Returns:
	{
		"total_damage": int,
		"damage_packet": DamagePacket,
		"damage_mult": float,
		"defense_mult": float,
		"breakdown": Dictionary,
		"element_breakdown": Dictionary  # Per-element pre-defense values
	}
	"""
	# Step 1: Build damage packet with split elemental routing
	var packet = DamagePacket.new()
	var dice_index = 0
	
	for effect in action_effects:
		if effect.effect_type != ActionEffect.EffectType.DAMAGE:
			continue
		
		var effect_element = effect.damage_type
		
		# Route each die's value into its own element bucket
		for i in range(effect.dice_count):
			if dice_index >= placed_dice.size():
				break
			
			var die = placed_dice[dice_index]
			dice_index += 1
			
			if die is DieResource:
				var die_value = float(die.get_total_value())
				var die_damage_type = die.get_effective_damage_type(effect_element)
				
				# Apply match bonus if die element matches action element
				if die.is_element_match(effect_element):
					die_value *= ELEMENT_MATCH_BONUS
				
				packet.add_damage(die_damage_type, die_value)
			else:
				# Legacy fallback: raw int value → action element (no match bonus)
				var raw_value = int(die) if die is int else 0
				packet.add_damage(effect_element, float(raw_value))
		
		# Base damage always goes into the action effect's element
		if effect.base_damage > 0:
			packet.add_damage(effect_element, float(effect.base_damage))
		
		# Apply the effect's damage multiplier to ALL buckets built so far
		# Note: This applies per-effect, so multi-effect actions scale correctly
		if effect.damage_multiplier != 1.0:
			packet.apply_multiplier(effect.damage_multiplier)
	
	# Step 2: Add type-specific damage bonuses from attacker affixes
	if attacker_affixes:
		var primary_element = _get_primary_element(action_effects)
		_apply_damage_bonuses(packet, attacker_affixes, primary_element)
		
		# Step 2b: Action-scoped flat damage bonus (v6)
		if action_id != "":
			var action_flat = attacker_affixes.get_action_damage_bonus(action_id)
			if action_flat > 0:
				packet.add_damage(primary_element, action_flat)
	
	# Step 3: Calculate and apply global damage multiplier from affixes
	var damage_mult = 1.0
	if attacker_affixes:
		damage_mult = _calculate_damage_multiplier(attacker_affixes)
		
		# Step 3b: Action-scoped damage multiplier (v6)
		if action_id != "":
			var action_mult = attacker_affixes.get_action_damage_multiplier(action_id)
			damage_mult *= action_mult
		
		if damage_mult != 1.0:
			packet.apply_multiplier(damage_mult)
	
	# Snapshot pre-defense breakdown for UI
	var element_breakdown = packet.get_breakdown()
	
	# Step 4: Calculate defense multiplier
	var defense_mult = _calculate_defense_multiplier(defender_stats)
	
	# Step 5: Calculate final damage after defenses
	var total_damage = packet.calculate_final_damage(defender_stats, defense_mult)
	
	return {
		"total_damage": total_damage,
		"damage_packet": packet,
		"damage_mult": damage_mult,
		"defense_mult": defense_mult,
		"breakdown": packet.get_breakdown(),
		"element_breakdown": element_breakdown
	}

# ============================================================================
# PREVIEW CALCULATION (for ActionField UI)
# ============================================================================

static func calculate_preview_damage(
	placed_dice: Array,
	action_element: ActionEffect.DamageType,
	base_damage: int,
	damage_multiplier: float
) -> Dictionary:
	"""
	Lightweight preview calculation for the action field UI.
	Returns a Dictionary of DamageType → float (pre-defense values).
	Does not account for affixes or defender stats.
	"""
	var damages: Dictionary = {}
	
	# Route each die
	for die in placed_dice:
		if not die is DieResource:
			continue
		
		var die_value = float(die.get_total_value())
		var die_damage_type = die.get_effective_damage_type(action_element)
		
		if die.is_element_match(action_element):
			die_value *= ELEMENT_MATCH_BONUS
		
		damages[die_damage_type] = damages.get(die_damage_type, 0.0) + die_value
	
	# Base damage → action element
	if base_damage > 0:
		damages[action_element] = damages.get(action_element, 0.0) + float(base_damage)
	
	# Apply multiplier
	if damage_multiplier != 1.0:
		for type in damages:
			damages[type] *= damage_multiplier
	
	return damages

# ============================================================================
# HELPER: Get primary element from effects
# ============================================================================

static func _get_primary_element(effects: Array[ActionEffect]) -> ActionEffect.DamageType:
	"""Get the primary damage element from the first damage effect"""
	for effect in effects:
		if effect.effect_type == ActionEffect.EffectType.DAMAGE:
			return effect.damage_type
	return ActionEffect.DamageType.SLASHING

# ============================================================================
# AFFIX APPLICATION
# ============================================================================

static func _apply_damage_bonuses(
	packet: DamagePacket, 
	affixes: AffixPoolManager, 
	primary_damage_type: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING
):
	"""Apply flat damage bonuses by type from attacker affixes"""
	# Global damage bonus applies to the action's primary damage type
	var global_bonus = 0.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_BONUS):
		global_bonus += affix.apply_effect()
	
	if global_bonus > 0:
		packet.add_damage(primary_damage_type, global_bonus)
	
	# Type-specific bonuses
	var type_categories = {
		ActionEffect.DamageType.SLASHING: "SLASHING_DAMAGE_BONUS",
		ActionEffect.DamageType.BLUNT: "BLUNT_DAMAGE_BONUS",
		ActionEffect.DamageType.PIERCING: "PIERCING_DAMAGE_BONUS",
		ActionEffect.DamageType.FIRE: "FIRE_DAMAGE_BONUS",
		ActionEffect.DamageType.ICE: "ICE_DAMAGE_BONUS",
		ActionEffect.DamageType.SHOCK: "SHOCK_DAMAGE_BONUS",
		ActionEffect.DamageType.POISON: "POISON_DAMAGE_BONUS",
		ActionEffect.DamageType.SHADOW: "SHADOW_DAMAGE_BONUS",
	}
	
	for damage_type in type_categories:
		var category_name = type_categories[damage_type]
		if category_name in Affix.Category:
			var category = Affix.Category.get(category_name)
			for affix in affixes.get_pool(category):
				packet.add_damage(damage_type, affix.apply_effect())

static func _calculate_damage_multiplier(affixes: AffixPoolManager) -> float:
	"""Calculate total damage multiplier from affixes"""
	var mult = 1.0
	for affix in affixes.get_pool(Affix.Category.DAMAGE_MULTIPLIER):
		mult *= affix.apply_effect()
	return mult

static func _calculate_defense_multiplier(defender_stats: Dictionary) -> float:
	"""Calculate defender's defense multiplier"""
	return defender_stats.get("defense_mult", 1.0)
