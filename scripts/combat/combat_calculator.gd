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

## Base critical hit damage multiplier.
const CRIT_DAMAGE_MULTIPLIER: float = 1.5

## Crit chance per point of Luck (0.5 = 0.5% per Luck).
const LUCK_CRIT_PER_POINT: float = 0.5


# ============================================================================
# MAIN DAMAGE CALCULATION
# ============================================================================

static func calculate_attack_damage(
	attacker_affixes: AffixPoolManager,
	action_effects: Array[ActionEffect],
	placed_dice: Array,  # Array of DieResource (untyped for backward compat)
	defender_stats: Dictionary,
	action_id: String = "",
	accepted_elements: Array[int] = [],
	attacker_tracker: StatusTracker = null,
	defender_tracker: StatusTracker = null,
	base_crit_chance: float = 0.0,
	base_crit_mult: float = CRIT_DAMAGE_MULTIPLIER
) -> Dictionary:
	"""
	Calculate damage from an attack using split elemental damage.
	
	Each die contributes its rolled value into its own element's damage bucket.
	NONE-element dice inherit the action effect's element.
	Matching-element dice get a bonus multiplier.
	Base damage always goes into the action effect's element.
	
	Args:
		attacker_tracker: Attacker's StatusTracker (for Enfeeble damage reduction).
		defender_tracker: Defender's StatusTracker (for Expose crit bonus).
		base_crit_chance: Pre-calculated crit % from Luck + affix bonuses (0-100).
		base_crit_mult: Base crit damage multiplier (default from tuning constant).
	
	Returns:
	{
		"total_damage": int,
		"damage_packet": DamagePacket,
		"damage_mult": float,
		"defense_mult": float,
		"is_crit": bool,
		"crit_mult": float,
		"pre_crit_damage": int,
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
		
		# Per-effect buckets so the multiplier only scales THIS effect's contribution
		var effect_damages: Dictionary = {}
		
		# Route each die's value into its own element bucket
		for i in range(effect.dice_count):
			if dice_index >= placed_dice.size():
				break
			
			var die = placed_dice[dice_index]
			dice_index += 1
			
			if die is DieResource:
				var die_value = float(die.get_total_value())
				var die_damage_type = die.get_effective_damage_type(effect_element)
				
				# Multi-element match: if accepted_elements is set, any die whose
				# element is in the list gets the synergy bonus. Otherwise fall back
				# to the standard single-element check.
				var is_match: bool
				if accepted_elements.size() > 0:
					var die_elem = die.get_effective_element()
					is_match = (die_elem != DieResource.Element.NONE
						and die_elem in accepted_elements)
				else:
					is_match = die.is_element_match(effect_element)
				
				if is_match:
					die_value *= ELEMENT_MATCH_BONUS
				
				effect_damages[die_damage_type] = effect_damages.get(die_damage_type, 0.0) + die_value
			else:
				# Legacy fallback: raw int value → action element (no match bonus)
				var raw_value = int(die) if die is int else 0
				effect_damages[effect_element] = effect_damages.get(effect_element, 0.0) + float(raw_value)
		
		# Base damage always goes into the action effect's element
		if effect.base_damage > 0:
			effect_damages[effect_element] = effect_damages.get(effect_element, 0.0) + float(effect.base_damage)
		
		# Apply this effect's multiplier to only its own contribution
		if effect.damage_multiplier != 1.0:
			for dt in effect_damages:
				effect_damages[dt] *= effect.damage_multiplier
		
		# Merge into the main packet
		for dt in effect_damages:
			packet.add_damage(dt, effect_damages[dt])
	
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
	
	# Step 3c: Enfeeble — attacker's outgoing damage reduction
	if attacker_tracker:
		var enfeeble_mod: float = attacker_tracker.get_total_stat_modifier("damage_multiplier")
		if enfeeble_mod < 0.0:
			damage_mult = maxf(0.0, damage_mult + enfeeble_mod)
			print("  Enfeeble: damage_mult -> %.2f" % damage_mult)
	
	if damage_mult != 1.0:
		packet.apply_multiplier(damage_mult)
	
	# Snapshot pre-defense breakdown for UI
	var element_breakdown = packet.get_breakdown()
	
	# Step 4: Calculate defense multiplier
	var defense_mult = _calculate_defense_multiplier(defender_stats)
	
	# Step 4b: Apply defender's damage-received bonuses (e.g. Static: +1 shock per stack)
	_apply_damage_received_bonuses(packet, defender_stats)
	
	# Step 5: Calculate final damage after defenses
	var total_damage = packet.calculate_final_damage(defender_stats, defense_mult)
	
	# Step 6: Critical hit roll
	var is_crit: bool = false
	var crit_mult: float = 1.0
	var pre_crit_damage: int = total_damage
	
	var crit_chance: float = base_crit_chance
	if defender_tracker:
		crit_chance += defender_tracker.get_crit_bonus()
	crit_chance = minf(crit_chance, 100.0)
	
	if crit_chance > 0.0 and total_damage > 0 and randf() * 100.0 < crit_chance:
		is_crit = true
		crit_mult = base_crit_mult
		# Future: add CRIT_DAMAGE_MULTIPLIER affix pool bonuses here
		total_damage = int(total_damage * crit_mult)
		print("  CRITICAL HIT! %.0f%% chance, x%.1f -> %d" % [crit_chance, crit_mult, total_damage])
	
	return {
		"total_damage": total_damage,
		"damage_packet": packet,
		"damage_mult": damage_mult,
		"defense_mult": defense_mult,
		"is_crit": is_crit,
		"crit_mult": crit_mult,
		"pre_crit_damage": pre_crit_damage,
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
	damage_multiplier: float,
	accepted_elements: Array[int] = []
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
		
		var is_match: bool
		if accepted_elements.size() > 0:
			var die_elem = die.get_effective_element()
			is_match = (die_elem != DieResource.Element.NONE
				and die_elem in accepted_elements)
		else:
			is_match = die.is_element_match(action_element)
		
		if is_match:
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


static func _apply_damage_received_bonuses(packet: DamagePacket, defender_stats: Dictionary) -> void:
	"""Apply flat bonus damage from defender status effects (e.g. Static).
	
	Reads 'damage_received_bonuses' from defender_stats — a Dictionary of
	DamageType enum → flat bonus amount. Added post-multiplier but pre-defense,
	so armor/barrier still reduces the bonus.
	"""
	var bonuses: Dictionary = defender_stats.get("damage_received_bonuses", {})
	for damage_type in bonuses:
		var bonus: float = float(bonuses[damage_type])
		if bonus != 0.0 and packet.damages.get(damage_type, 0.0) > 0.0:
			packet.add_damage(damage_type, bonus)
