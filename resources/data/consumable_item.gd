# res://resources/data/consumable_item.gd
# Consumable item resource — potions, combat preparations, dice elixirs,
# inscriptions, and curios.
#
# Replaces the legacy Dictionary-based consumable system.
# Stored in Player.consumables (separate from equipment inventory).
extends Resource
class_name ConsumableItem

# ============================================================================
# ENUMS
# ============================================================================

enum ConsumableTier {
	RESTORATIVE,        ## T1: Instant healing/mana/barrier
	COMBAT_PREP,        ## T2: Grants temp Affix(es) for next combat
	DICE_ELIXIR,        ## T3: Grants temp DiceAffix(es) for next combat
	INSCRIPTION,        ## T4: Permanently adds DiceAffix to a die
	CURIO,              ## T5: Unique scripted effects
}

enum UseContext {
	OUT_OF_COMBAT,      ## Can only use from inventory menu
	PRE_COMBAT,         ## Used from inventory, activates at combat start
	IN_COMBAT,          ## Can use during combat (consumes an action)
	ANY,                ## No restriction
}

enum TargetType {
	SELF,               ## Affects player (default)
	SINGLE_DIE,         ## Player selects one die (inscriptions)
	ALL_DICE,           ## Affects entire dice pool
	SINGLE_ENEMY,       ## Target one enemy (combat only)
	ALL_ENEMIES,        ## Target all enemies (combat only)
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
@export var item_name: String = "Consumable"
@export_multiline var description: String = ""
@export_multiline var flavor_text: String = ""
@export var icon: Texture2D = null
@export var tier: ConsumableTier = ConsumableTier.RESTORATIVE
@export var rarity: int = 0  # Matches EquippableItem.Rarity values

# ============================================================================
# USAGE RULES
# ============================================================================
@export_group("Usage")
@export var use_context: UseContext = UseContext.OUT_OF_COMBAT
@export var target_type: TargetType = TargetType.SELF
@export var max_stack: int = 10
@export var consumed_on_use: bool = true

# ============================================================================
# T1: RESTORATIVE
# ============================================================================
@export_group("Restorative")
@export var heal_amount: int = 0
@export var heal_percent: float = 0.0
@export var mana_amount: int = 0
@export var mana_percent: float = 0.0
@export var barrier_amount: int = 0
@export var cleanse_debuffs: bool = false
@export var cleanse_count: int = 0          ## 0 = all

# ============================================================================
# T2: COMBAT PREP (Temp Affixes)
# ============================================================================
@export_group("Combat Prep")
@export var granted_affixes: Array[Affix] = []
@export var combat_duration: int = 1

# ============================================================================
# T3: DICE ELIXIR (Temp DiceAffixes)
# ============================================================================
@export_group("Dice Elixir")
@export var granted_dice_affixes: Array[DiceAffix] = []
@export var dice_target_filter: String = "all"

# ============================================================================
# T4: INSCRIPTION (Permanent DiceAffix)
# ============================================================================
@export_group("Inscription")
@export var inscription_affix: DiceAffix = null
@export var inscription_die_filter: Array[String] = []
@export var can_overwrite: bool = false

# ============================================================================
# T5: CURIO (Scripted Effects)
# ============================================================================
@export_group("Curio")
@export var effect_script: Script = null
@export var effect_params: Dictionary = {}

# ============================================================================
# ECONOMY
# ============================================================================
@export_group("Economy")
@export var base_value: int = 10
@export var region: int = 1
@export var level_requirement: int = 0

# ============================================================================
# RUNTIME STATE (not exported — managed at runtime)
# ============================================================================
## Current stack count. Set to 1 on creation. Managed by Player.add_consumable().
var current_stack: int = 1

# ============================================================================
# PUBLIC API
# ============================================================================

func can_use(player, context: Dictionary = {}) -> bool:
	"""Check if this consumable can be used right now."""
	if not player:
		return false
	if level_requirement > 0 and player.level < level_requirement:
		return false

	var in_combat: bool = context.get("in_combat", false)

	match use_context:
		UseContext.OUT_OF_COMBAT:
			if in_combat:
				return false
		UseContext.PRE_COMBAT:
			if in_combat:
				return false
		UseContext.IN_COMBAT:
			if not in_combat:
				return false
		UseContext.ANY:
			pass  # Always allowed

	# T4: check if a valid die target exists
	if tier == ConsumableTier.INSCRIPTION and inscription_affix:
		if target_type == TargetType.SINGLE_DIE:
			var valid_dice = _get_valid_inscription_targets(player)
			if valid_dice.is_empty():
				return false

	return true


func use(player, context: Dictionary = {}) -> Dictionary:
	"""Execute the consumable. Returns result dict for UI feedback.

	Context keys:
		in_combat (bool): Whether we're in combat.
		combat_manager: Reference to CombatManager (for in-combat effects).
		selected_die (DieResource): For inscription targeting.
	"""
	var result: Dictionary = {"success": false, "message": "", "effects": []}

	if not can_use(player, context):
		result.message = "Cannot use %s right now." % item_name
		return result

	match tier:
		ConsumableTier.RESTORATIVE:
			result = _use_restorative(player)
		ConsumableTier.COMBAT_PREP:
			result = _use_combat_prep(player)
		ConsumableTier.DICE_ELIXIR:
			var die: DieResource = context.get("selected_die", null)
			result = _use_dice_elixir(player, die)
		ConsumableTier.INSCRIPTION:
			var die: DieResource = context.get("selected_die", null)
			result = _use_inscription(player, die)
		ConsumableTier.CURIO:
			result = _use_curio(player, context)

	return result


func get_sell_value() -> int:
	"""Calculate sell value."""
	var tier_mult := [0.3, 0.25, 0.25, 0.2, 0.1]
	var mult: float = tier_mult[tier] if tier < tier_mult.size() else 0.1
	return maxi(1, int(base_value * mult))


func get_rarity_name() -> String:
	"""Map rarity int to name string for UI compatibility."""
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Epic"
		4: return "Legendary"
		_: return "Common"

# ============================================================================
# TIER IMPLEMENTATIONS
# ============================================================================

func _use_restorative(player) -> Dictionary:
	var effects: Array = []

	if heal_amount > 0:
		player.heal(heal_amount)
		effects.append("Healed %d HP" % heal_amount)

	if heal_percent > 0.0:
		var amount = int(player.max_hp * heal_percent)
		player.heal(amount)
		effects.append("Healed %d HP (%d%%)" % [amount, int(heal_percent * 100)])

	if mana_amount > 0 and player.has_method("restore_mana"):
		player.restore_mana(mana_amount)
		effects.append("Restored %d Mana" % mana_amount)

	if mana_percent > 0.0 and player.has_method("restore_mana"):
		var amount = int(player.max_mana * mana_percent)
		player.restore_mana(amount)
		effects.append("Restored %d Mana" % amount)

	if barrier_amount > 0:
		player.base_barrier += barrier_amount
		effects.append("+%d Barrier" % barrier_amount)

	if cleanse_debuffs and player.status_tracker:
		if cleanse_count > 0:
			player.status_tracker.cleanse(["debuff"], cleanse_count)
			effects.append("Cleansed %d debuffs" % cleanse_count)
		else:
			player.status_tracker.cleanse(["debuff"], 0)
			effects.append("Cleansed all debuffs")

	return {"success": true, "message": " | ".join(effects), "effects": effects}


func _use_combat_prep(player) -> Dictionary:
	if granted_affixes.is_empty():
		return {"success": false, "message": "No affixes configured.", "effects": []}

	# Queue for application at next combat start
	player.active_consumable_buffs.append({
		"consumable": self,
		"remaining_combats": combat_duration,
		"type": "affix",
	})

	return {
		"success": true,
		"message": "%s prepared for next combat." % item_name,
		"effects": ["Queued %d affix(es) for %d combat(s)" % [granted_affixes.size(), combat_duration]],
	}


func _use_dice_elixir(player, selected_die: DieResource = null) -> Dictionary:
	if granted_dice_affixes.is_empty():
		return {"success": false, "message": "No dice affixes configured.", "effects": []}

	# If this elixir targets a single die, require selection
	if target_type == TargetType.SINGLE_DIE and not selected_die:
		return {"success": false, "message": "No die selected.", "effects": []}

	var buff_entry: Dictionary = {
		"consumable": self,
		"remaining_combats": combat_duration if combat_duration > 0 else 1,
		"type": "dice_affix",
	}

	# Store selected die reference for single-die targeting
	if selected_die:
		buff_entry["selected_die"] = selected_die

	player.active_consumable_buffs.append(buff_entry)

	var target_text: String = selected_die.get_display_name() if selected_die else "matching dice"
	return {
		"success": true,
		"message": "%s prepared for %s next combat." % [item_name, target_text],
		"effects": ["Queued %d dice affix(es)" % granted_dice_affixes.size()],
	}


func _use_inscription(player, die: DieResource) -> Dictionary:
	if not inscription_affix:
		return {"success": false, "message": "No inscription affix configured.", "effects": []}
	if not die:
		return {"success": false, "message": "No die selected.", "effects": []}

	# Check slot capacity
	var max_slots: int = _get_max_inscription_slots(die)
	if die.inscribed_affixes.size() >= max_slots and not can_overwrite:
		return {"success": false, "message": "Die has no empty inscription slots.", "effects": []}

	# Apply inscription
	var copy: DiceAffix = inscription_affix.duplicate(true)
	copy.source = item_name
	copy.source_type = "inscription"

	if die.inscribed_affixes.size() >= max_slots and can_overwrite:
		# Replace last slot
		die.inscribed_affixes[max_slots - 1] = copy
	else:
		die.inscribed_affixes.append(copy)

	return {
		"success": true,
		"message": "Inscribed %s onto %s." % [copy.affix_name, die.get_display_name()],
		"effects": ["Permanent: %s" % copy.description],
	}


func _use_curio(player, context: Dictionary) -> Dictionary:
	if effect_script:
		var effect = effect_script.new()
		if effect.has_method("execute"):
			return effect.execute(player, effect_params, context)
	return {"success": false, "message": "Curio effect not implemented.", "effects": []}


# ============================================================================
# HELPERS
# ============================================================================

func _get_valid_inscription_targets(player) -> Array[DieResource]:
	"""Get dice that can receive this inscription."""
	var valid: Array[DieResource] = []
	if not player.dice_pool:
		return valid
	for die in player.dice_pool.get_all_dice():
		if not _die_matches_filter(die):
			continue
		var max_slots = _get_max_inscription_slots(die)
		if die.inscribed_affixes.size() < max_slots or can_overwrite:
			valid.append(die)
	return valid


func _die_matches_filter(die: DieResource) -> bool:
	"""Check if a die matches the inscription_die_filter tags."""
	if inscription_die_filter.is_empty():
		return true
	for tag in inscription_die_filter:
		if tag.begins_with("element:"):
			var elem_name = tag.split(":")[1].to_upper()
			var die_elem = DieResource.Element.keys()[die.element]
			if die_elem != elem_name:
				return false
		elif tag.begins_with("type:"):
			var type_name = tag.split(":")[1].to_upper()
			var die_type_name = "D%d" % die.die_type
			if die_type_name != type_name:
				return false
		elif not die.has_tag(tag):
			return false
	return true


static func _get_max_inscription_slots(die: DieResource) -> int:
	"""Inscription slot limit by die type."""
	if "max_inscription_slots" in die:
		return die.max_inscription_slots
	# Fallback based on die type
	match die.die_type:
		DieResource.DieType.D4: return 1
		DieResource.DieType.D6: return 1
		DieResource.DieType.D8: return 2
		DieResource.DieType.D10: return 2
		DieResource.DieType.D12: return 3
		DieResource.DieType.D20: return 3
		_: return 1
