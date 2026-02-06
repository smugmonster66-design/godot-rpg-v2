# player.gd - Player data resource
extends Resource
class_name Player

# ============================================================================
# CORE STATS
# ============================================================================
var max_hp: int = 100
var current_hp: int = 100
var base_armor: int = 0
var base_barrier: int = 0
var max_mana: int = 50
var current_mana: int = 50
var strength: int = 10
var agility: int = 10
var intellect: int = 10
var luck: int = 10

# ============================================================================
# ELEMENTAL RESISTANCES
# ============================================================================
var fire_resist: int = 0
var ice_resist: int = 0
var shock_resist: int = 0
var poison_resist: int = 0
var shadow_resist: int = 0

# ============================================================================
# EQUIPMENT
# ============================================================================
var equipment: Dictionary = {
	"Head": null,
	"Torso": null,
	"Gloves": null,
	"Boots": null,
	"Main Hand": null,
	"Off Hand": null,
	"Accessory": null
}

var equipment_sets: Dictionary = {}

# ============================================================================
# INVENTORY
# ============================================================================
var inventory: Array = []

# ============================================================================
# CLASS SYSTEM
# ============================================================================
var active_class: PlayerClass = null
var available_classes: Dictionary = {}

# ============================================================================
# STATUS EFFECTS
# ============================================================================
var status_effects: Dictionary = {
	"overhealth": {"amount": 0, "turns": 0},
	"block": 0,
	"dodge": 0,
	"poison": 0,
	"burn": {"amount": 0, "turns": 0},
	"bleed": 0,
	"slowed": {"amount": 0, "turns": 0},
	"stunned": {"amount": 0, "turns": 0},
	"corrode": {"amount": 0, "turns": 0},
	"chill": 0,
	"expose": 0,
	"shadow": 0,
	"ignition": 0,
	"enfeeble": {"amount": 0, "turns": 0}
}

# ============================================================================
# DICE POOL
# ============================================================================
# Note: This is a Node, but Player is a Resource. GameManager adds dice_pool 
# to the scene tree after creating the Player.
var dice_pool: PlayerDiceCollection = null

# ============================================================================
# AFFIX MANAGER
# ============================================================================
var affix_manager: AffixPoolManager = AffixPoolManager.new()
var set_tracker: SetTracker = SetTracker.new()


# ============================================================================
# SIGNALS
# ============================================================================
signal stat_changed(stat_name: String, old_value, new_value)
signal equipment_changed(slot: String, item)
signal status_effect_changed(effect: String, value)
signal hp_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal class_changed(new_class: PlayerClass)
signal player_died()
signal inventory_changed()


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	current_hp = max_hp
	current_mana = max_mana
	
	# Create dice collection - GameManager will add it to scene tree
	dice_pool = PlayerDiceCollection.new()
	dice_pool.name = "DicePool"
	# NOTE: Do NOT call add_child() here - Resource can't have children
	# GameManager.initialize_player() calls: add_child(player.dice_pool)
	
	set_tracker.initialize(self)
	
	print("🎲 Player resource initialized")

# ============================================================================
# STAT MANAGEMENT
# ============================================================================

func get_total_stat(stat_name: String) -> int:
	var base_value = get(stat_name) if stat_name in self else 0
	var equipment_bonus = get_equipment_stat_bonus(stat_name)
	var class_bonus = 0
	if active_class:
		class_bonus = active_class.get_stat_bonus(stat_name)
	
	# Affix pool flat bonuses
	var affix_bonus: int = 0
	var bonus_category = _stat_to_bonus_category(stat_name)
	if bonus_category >= 0:
		for affix in affix_manager.get_pool(bonus_category):
			affix_bonus += int(affix.apply_effect())
	
	var subtotal = base_value + equipment_bonus + class_bonus + affix_bonus
	
	# Affix pool multipliers
	var mult_category = _stat_to_multiplier_category(stat_name)
	if mult_category >= 0:
		for affix in affix_manager.get_pool(mult_category):
			subtotal = int(subtotal * affix.apply_effect())
	
	return subtotal


func get_equipment_stat_bonus(stat_name: String) -> int:
	var bonus = 0
	for slot in equipment:
		var item = equipment[slot]
		if item and item.has("stats") and item.stats.has(stat_name):
			if item.has("affinity") and active_class:
				if item.affinity == active_class.main_stat:
					bonus += item.stats[stat_name]
			else:
				bonus += item.stats[stat_name]
	return bonus

func get_armor() -> int:
	var total = base_armor + get_equipment_stat_bonus("armor")
	if active_class:
		total += active_class.get_stat_bonus("armor")
	
	# Affix pool bonus
	for affix in affix_manager.get_pool(Affix.Category.ARMOR_BONUS):
		total += int(affix.apply_effect())
	
	total = max(0, total - status_effects["corrode"]["amount"])
	return total


func get_barrier() -> int:
	var total = base_barrier + get_equipment_stat_bonus("barrier")
	if active_class:
		total += active_class.get_stat_bonus("barrier")
	
	# Affix pool bonus
	for affix in affix_manager.get_pool(Affix.Category.BARRIER_BONUS):
		total += int(affix.apply_effect())
	
	return total


func recalculate_stats():
	# ── Max HP ──
	var base_hp: int = 100  # Or whatever your base formula is
	var hp_bonus: int = 0
	for affix in affix_manager.get_pool(Affix.Category.HEALTH_BONUS):
		hp_bonus += int(affix.apply_effect())
	var new_max_hp = base_hp + hp_bonus
	if new_max_hp != max_hp:
		var old_max = max_hp
		max_hp = new_max_hp
		# Scale current HP proportionally so equipping doesn't leave you at 100/600
		current_hp = clampi(roundi(current_hp * (float(max_hp) / float(old_max))), 1, max_hp)
		hp_changed.emit(current_hp, max_hp)
	
	# ── Max Mana ──
	var base_mana: int = 50 + get_total_stat("intellect") * 2
	var mana_bonus: int = 0
	for affix in affix_manager.get_pool(Affix.Category.MANA_BONUS):
		mana_bonus += int(affix.apply_effect())
	var new_max_mana = base_mana + mana_bonus
	if new_max_mana != max_mana:
		var old_max_mana = max_mana
		max_mana = new_max_mana
		current_mana = clampi(roundi(current_mana * (float(max_mana) / float(old_max_mana))), 0, max_mana)
		mana_changed.emit(current_mana, max_mana)


# ============================================================================
# HEALTH & MANA
# ============================================================================

func take_damage(amount: int, is_magical: bool = false) -> int:
	var damage_reduction = get_barrier() if is_magical else get_armor()
	damage_reduction += status_effects["block"]
	
	var actual_damage = max(0, amount - damage_reduction)
	
	if status_effects["overhealth"]["amount"] > 0:
		var overhealth_damage = min(actual_damage, status_effects["overhealth"]["amount"])
		status_effects["overhealth"]["amount"] -= overhealth_damage
		actual_damage -= overhealth_damage
		status_effect_changed.emit("overhealth", status_effects["overhealth"])
	
	current_hp = max(0, current_hp - actual_damage)
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		die()
	
	return actual_damage

func heal(amount: int):
	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, max_hp)

func die():
	print("Player died!")
	player_died.emit()

func restore_mana(amount: int):
	current_mana = min(max_mana, current_mana + amount)
	mana_changed.emit(current_mana, max_mana)

func consume_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

# ============================================================================
# EQUIPMENT MANAGEMENT
# ============================================================================

func equip_item(item: Dictionary, slot: String = "") -> bool:
	var target_slot = slot if slot != "" else item.get("slot", "")
	
	if item.get("is_heavy", false):
		if equipment["Off Hand"] != null:
			var offhand = equipment["Off Hand"]
			equipment["Off Hand"] = null
			inventory.append(offhand)
		
		if equipment["Main Hand"] != null:
			unequip_item("Main Hand")
		
		equipment["Main Hand"] = item
		equipment["Off Hand"] = item
	else:
		if equipment[target_slot] != null:
			unequip_item(target_slot)
		equipment[target_slot] = item
	
	inventory.erase(item)
	
	_add_item_affixes(item)
	apply_item_dice(item)
	
	equipment_changed.emit(target_slot, item)
	recalculate_stats()
	return true

func unequip_item(slot: String) -> bool:
	if equipment[slot] == null:
		return false
	
	var item = equipment[slot]
	
	_remove_item_affixes(item)
	remove_item_dice(item)
	
	if item.get("is_heavy", false):
		equipment["Main Hand"] = null
		equipment["Off Hand"] = null
	else:
		equipment[slot] = null
	
	if not inventory.has(item):
		inventory.append(item)
	
	equipment_changed.emit(slot, null)
	recalculate_stats()
	return true



func apply_item_dice(item: Dictionary):
	if not dice_pool:
		return
	
	var item_name = item.get("name", "Unknown Item")
	var tags = item.get("dice_tags", [])
	var item_affixes = item.get("item_affixes", [])
	
	var item_dice = item.get("dice_resources", [])
	if item_dice.size() > 0:
		for die_template in item_dice:
			if die_template is DieResource:
				var die_copy = die_template.duplicate_die()
				die_copy.source = item_name
				
				for tag in tags:
					die_copy.add_tag(tag)
				
				# Apply visual effects from item affixes
				for affix in item_affixes:
					if affix is Affix and affix.dice_visual_affix:
						die_copy.add_affix(affix.dice_visual_affix)
				
				dice_pool.add_die(die_copy)
		return
	
	# Legacy fallback
	var die_types = item.get("dice", [])
	if die_types.size() > 0:
		dice_pool.add_dice_from_source(die_types, item_name, tags)






func remove_item_dice(item: Dictionary):
	if not item or not dice_pool:
		return
	
	var item_name = item.get("name", "Unknown Item")
	dice_pool.remove_dice_by_source(item_name)

# ============================================================================
# EQUIPMENT SETS
# ============================================================================

func save_equipment_set(set_name: String):
	var set_data = {}
	for slot in equipment:
		if equipment[slot] != null:
			set_data[slot] = equipment[slot].duplicate()
	equipment_sets[set_name] = set_data

func load_equipment_set(set_name: String) -> bool:
	if not equipment_sets.has(set_name):
		return false
	
	var set_data = equipment_sets[set_name]
	
	for slot in equipment.keys():
		if equipment[slot] != null:
			unequip_item(slot)
	
	var missing_items = []
	for slot in set_data:
		var item = set_data[slot]
		var found = false
		
		for inv_item in inventory:
			if items_match(inv_item, item):
				equip_item(inv_item, slot)
				found = true
				break
		
		if not found:
			missing_items.append(slot)
	
	for slot in missing_items:
		set_data.erase(slot)
	
	return true

func items_match(item1: Dictionary, item2: Dictionary) -> bool:
	return item1.get("name", "") == item2.get("name", "")

# ============================================================================
# CLASS MANAGEMENT
# ============================================================================

func add_class(p_class_name: String, player_class: PlayerClass):
	print("🎲 add_class called: %s" % p_class_name)
	print("   player_class.starting_dice.size(): %d" % player_class.starting_dice.size())
	
	available_classes[p_class_name] = player_class
	print("Class '%s' added" % p_class_name)

func switch_class(p_class_name: String) -> bool:
	if not available_classes.has(p_class_name):
		return false
	
	# Remove old class's dice and skill affixes
	if active_class and dice_pool:
		dice_pool.remove_dice_by_source(active_class.player_class_name)
		
		# Remove skill affixes from old class
		for skill in active_class.get_all_skills():
			if skill:
				affix_manager.remove_affixes_by_source(skill.skill_name)
	
	# Switch to new class
	active_class = available_classes[p_class_name]
	
	# Add new class's dice (use copies to preserve textures and affixes)
	if dice_pool and active_class:
		var class_dice = active_class.get_starting_dice_copies()  # Changed from get_all_class_dice()
		for die in class_dice:
			dice_pool.add_die(die)
	
	# Reapply skill affixes for new class
	if active_class:
		_reapply_class_skill_affixes()
	
	class_changed.emit(active_class)
	print("Switched to class: %s" % p_class_name)
	return true

func _reapply_class_skill_affixes():
	"""Reapply all learned skill affixes for active class"""
	if not active_class:
		return
	
	for skill in active_class.get_all_skills():
		if not skill:
			continue
		
		var rank = active_class.get_skill_rank(skill.skill_id)
		if rank <= 0:
			continue
		
		# Apply affixes for all learned ranks
		for r in range(1, rank + 1):
			var affixes = skill.get_affixes_for_rank(r)
			for affix in affixes:
				if affix:
					var affix_copy = affix.duplicate_with_source(skill.skill_name, "skill")
					affix_manager.add_affix(affix_copy)

# ============================================================================
# STATUS EFFECTS
# ============================================================================

func add_status_effect(effect: String, amount: int, turns: int = -1):
	if status_effects.has(effect):
		if status_effects[effect] is Dictionary:
			status_effects[effect]["amount"] += amount
			if turns > 0:
				status_effects[effect]["turns"] = max(status_effects[effect]["turns"], turns)
		else:
			status_effects[effect] += amount
		status_effect_changed.emit(effect, status_effects[effect])

func remove_status_effect(effect: String, amount: int = -1):
	if status_effects.has(effect):
		if amount < 0:
			if status_effects[effect] is Dictionary:
				status_effects[effect] = {"amount": 0, "turns": 0}
			else:
				status_effects[effect] = 0
		else:
			if status_effects[effect] is Dictionary:
				status_effects[effect]["amount"] = max(0, status_effects[effect]["amount"] - amount)
			else:
				status_effects[effect] = max(0, status_effects[effect] - amount)
		status_effect_changed.emit(effect, status_effects[effect])

func clear_combat_status_effects():
	for effect in status_effects:
		if status_effects[effect] is Dictionary:
			status_effects[effect] = {"amount": 0, "turns": 0}
		else:
			status_effects[effect] = 0
		status_effect_changed.emit(effect, status_effects[effect])

func process_turn_status_effects():
	for effect in ["burn", "slowed", "stunned", "corrode", "enfeeble", "overhealth"]:
		if status_effects[effect]["turns"] > 0:
			status_effects[effect]["turns"] -= 1
			if status_effects[effect]["turns"] <= 0:
				status_effects[effect]["amount"] = 0
			status_effect_changed.emit(effect, status_effects[effect])
	
	if status_effects["poison"] > 0:
		take_damage(status_effects["poison"], false)
	
	if status_effects["burn"]["amount"] > 0:
		take_damage(status_effects["burn"]["amount"], true)
	
	if status_effects["bleed"] > 0:
		take_damage(status_effects["bleed"], false)
		status_effects["bleed"] = max(0, status_effects["bleed"] - 1)
		status_effect_changed.emit("bleed", status_effects["bleed"])

# ============================================================================
# COMBAT HELPERS
# ============================================================================

func get_damage_bonus() -> int:
	var expose_bonus = status_effects["expose"] * 2
	return expose_bonus

func get_physical_damage_bonus() -> int:
	return get_total_stat("strength")

func get_magical_damage_bonus() -> int:
	return get_total_stat("intellect")

func get_die_penalty() -> int:
	var penalty = 0
	if status_effects.has("slowed"):
		penalty += status_effects["slowed"]["amount"]
	penalty += floor(status_effects["chill"] / 2.0)
	return penalty

func check_dodge() -> bool:
	if status_effects["dodge"] <= 0:
		return false
	return randf() * 100 < status_effects["dodge"] * 10

func get_available_combat_actions() -> Array:
	var actions = []
	
	for slot in ["Main Hand", "Off Hand"]:
		var item = equipment[slot]
		if item and item.has("combat_actions"):
			for action in item.combat_actions:
				if action not in actions:
					actions.append(action)
	
	if active_class and active_class.combat_actions:
		for action in active_class.combat_actions:
			if action not in actions:
				actions.append(action)
	
	return actions

# ============================================================================
# INVENTORY MANAGEMENT
# ============================================================================

func add_to_inventory(item: Dictionary):
	inventory.append(item)
	inventory_changed.emit()
	print("🎒 Added to inventory: %s" % item.get("name", "Unknown"))

func remove_from_inventory(item: Dictionary):
	inventory.erase(item)

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func _add_item_affixes(item: Dictionary):
	var item_name = item.get("name", "Unknown Item")
	
	var item_affixes = item.get("item_affixes", [])
	if item_affixes is Array:
		for affix in item_affixes:
			if affix is Affix:
				affix_manager.add_affix(affix)
				print("  ✅ Added affix to manager: %s" % affix.affix_name)
				
				# Handle dice-granting affixes
				if affix.category == Affix.Category.DICE and affix.granted_dice.size() > 0:
					_apply_affix_dice(affix, item_name)

func _apply_affix_dice(affix: Affix, source_name: String):
	"""Add dice granted by an affix to the player's pool"""
	if not dice_pool:
		return
	
	for die_template in affix.granted_dice:
		if die_template is DieResource:
			var die_copy = die_template.duplicate_die()
			die_copy.source = source_name
			
			# Apply visual effects if the affix has them
			if affix.dice_visual_affix:
				die_copy.add_affix(affix.dice_visual_affix)
			
			dice_pool.add_die(die_copy)
			print("  🎲 Affix granted die: %s (from %s)" % [die_copy.display_name, source_name])



func _remove_item_affixes(item: Dictionary):
	var item_name = item.get("name", "Unknown Item")
	affix_manager.remove_affixes_by_source(item_name)


func get_defense_stats() -> Dictionary:
	"""Get all defensive stats for damage calculation"""
	return {
		"armor": get_armor(),
		"fire_resist": get_resist("fire"),
		"ice_resist": get_resist("ice"),
		"shock_resist": get_resist("shock"),
		"poison_resist": get_resist("poison"),
		"shadow_resist": get_resist("shadow")
	}

func get_resist(element: String) -> int:
	var base = get(element + "_resist") if (element + "_resist") in self else 0
	var equipment_bonus = get_equipment_stat_bonus(element + "_resist")
	
	# Affix pool bonus
	var resist_category = _element_to_resist_category(element)
	if resist_category >= 0:
		for affix in affix_manager.get_pool(resist_category):
			equipment_bonus += int(affix.apply_effect())
	
	return base + equipment_bonus



# ============================================================================
# AFFIX CATEGORY MAPPING HELPERS
# ============================================================================

func _stat_to_bonus_category(stat_name: String) -> int:
	match stat_name:
		"strength": return Affix.Category.STRENGTH_BONUS
		"agility": return Affix.Category.AGILITY_BONUS
		"intellect": return Affix.Category.INTELLECT_BONUS
		"luck": return Affix.Category.LUCK_BONUS
		_: return -1

func _stat_to_multiplier_category(stat_name: String) -> int:
	match stat_name:
		"strength": return Affix.Category.STRENGTH_MULTIPLIER
		"agility": return Affix.Category.AGILITY_MULTIPLIER
		"intellect": return Affix.Category.INTELLECT_MULTIPLIER
		"luck": return Affix.Category.LUCK_MULTIPLIER
		_: return -1

func _element_to_resist_category(element: String) -> int:
	match element:
		"fire": return Affix.Category.FIRE_RESIST_BONUS
		"ice": return Affix.Category.ICE_RESIST_BONUS
		"shock": return Affix.Category.SHOCK_RESIST_BONUS
		"poison": return Affix.Category.POISON_RESIST_BONUS
		"shadow": return Affix.Category.SHADOW_RESIST_BONUS
		_: return -1
