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
## StatusTracker node — manages all active statuses as StatusAffix instances.
## GameManager adds this to the scene tree after creating the Player.
var status_tracker: StatusTracker = null

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
signal status_changed() 

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
	
	# Create status tracker - GameManager will add it to scene tree
	status_tracker = StatusTracker.new()
	status_tracker.name = "StatusTracker"
	_connect_status_tracker_signals()
	
	set_tracker.initialize(self)
	
	print("🎲 Player resource initialized")

func _connect_status_tracker_signals():
	"""Bridge StatusTracker signals to legacy signals for UI compatibility."""
	status_tracker.status_applied.connect(
		func(sid: String, _instance: Dictionary):
			status_effect_changed.emit(sid, status_tracker.get_stacks(sid))
			status_changed.emit()
	)
	status_tracker.status_stacks_changed.connect(
		func(sid: String, _instance: Dictionary):
			status_effect_changed.emit(sid, status_tracker.get_stacks(sid))
			status_changed.emit()
	)
	status_tracker.status_removed.connect(
		func(sid: String):
			status_effect_changed.emit(sid, 0)
			status_changed.emit()
	)


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
	
	# Status effect modifiers (e.g. Enfeeble reducing damage_multiplier)
	if status_tracker:
		subtotal += int(status_tracker.get_total_stat_modifier(stat_name))
	
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
	
	# Corrode reduces armor via stat_modifier_per_stack {"armor": -2}
	if status_tracker:
		total += int(status_tracker.get_total_stat_modifier("armor"))
	
	return maxi(0, total)
	


func get_barrier() -> int:
	var total = base_barrier + get_equipment_stat_bonus("barrier")
	if active_class:
		total += active_class.get_stat_bonus("barrier")
	
	# Affix pool bonus
	for affix in affix_manager.get_pool(Affix.Category.BARRIER_BONUS):
		total += int(affix.apply_effect())
	
	# Future: status effects that reduce barrier
	if status_tracker:
		total += int(status_tracker.get_total_stat_modifier("barrier"))
	
	return maxi(0, total)


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
	var damage_reduction: int = get_barrier() if is_magical else get_armor()
	
	# Block from StatusTracker
	if status_tracker:
		damage_reduction += status_tracker.get_block_value()
	
	var actual_damage: int = maxi(0, amount - damage_reduction)
	
	# Overhealth absorbs remaining damage
	if status_tracker:
		actual_damage = status_tracker.consume_overhealth(actual_damage)
	
	current_hp = maxi(0, current_hp - actual_damage)
	hp_changed.emit(current_hp, max_hp)
	
	# Trigger ON_DAMAGED status effects (e.g. thorns in the future)
	if status_tracker and actual_damage > 0:
		status_tracker.process_on_event(StatusAffix.TickTiming.ON_DAMAGED)
	
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
	
	#inventory.erase(item)
	
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
	
	#if not inventory.has(item):
		#inventory.append(item)
	
	equipment_changed.emit(slot, null)
	recalculate_stats()
	return true



func apply_item_dice(item: Dictionary):
	if not dice_pool:
		return
	
	var item_name = item.get("name", "Unknown Item")
	var tags = item.get("dice_tags", [])
	var item_affixes = item.get("item_affixes", [])
	var dice_are_modified = item.get("_dice_modified", false)
	
	var item_dice = item.get("dice_resources", [])
	if item_dice.size() > 0:
		for die_template in item_dice:
			if die_template is DieResource:
				var die_copy = die_template.duplicate_die()
				die_copy.source = item_name
				
				for tag in tags:
					die_copy.add_tag(tag)
				
				# Only apply visual effects from item affixes on FRESH dice.
				# Modified dice already have them baked into applied_affixes.
				if not dice_are_modified:
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
	
	# ── Snapshot modified dice back onto the item ──
	var pool_dice = dice_pool.get_dice_by_source(item_name)
	if pool_dice.size() > 0:
		var modified_dice: Array[DieResource] = []
		for die in pool_dice:
			modified_dice.append(die.duplicate_die())
		item["dice_resources"] = modified_dice
		item["_dice_modified"] = true
		print("🎲 Saved %d modified dice back to %s" % [modified_dice.size(), item_name])
	
	dice_pool.remove_dice_by_source(item_name)


func reset_item_dice_to_base(item: Dictionary):
	"""Strip player modifications from an item's dice, restoring templates.
	Call this from a UI 'Reset Dice' button or similar."""
	var equippable: EquippableItem = item.get("equippable_item", null)
	if not equippable:
		print("⚠️ No EquippableItem reference — cannot reset to base")
		return
	
	var fresh: Array[DieResource] = []
	for die in equippable.grants_dice:
		if die:
			fresh.append(die.duplicate_die())
	
	item["dice_resources"] = fresh
	item.erase("_dice_modified")
	print("🎲 Reset dice to base templates for %s" % item.get("name", "Unknown"))
	
	# If currently equipped, re-apply
	if is_item_equipped(item):
		dice_pool.remove_dice_by_source(item.get("name", "Unknown Item"))
		apply_item_dice(item)

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
# STATUS EFFECTS (delegated to StatusTracker)
# ============================================================================

func apply_status(status_affix: StatusAffix, stacks: int = 1, source_name: String = "") -> void:
	"""Apply a status to the player. Stacks additively."""
	if status_tracker:
		status_tracker.apply_status(status_affix, stacks, source_name)

func remove_status(status_id: String) -> void:
	"""Fully remove a status."""
	if status_tracker:
		status_tracker.remove_status(status_id)

func remove_status_stacks(status_id: String, amount: int) -> void:
	"""Remove stacks from a status. 0 = remove all."""
	if status_tracker:
		status_tracker.remove_stacks(status_id, amount)

func cleanse(tags: Array[String], max_removals: int = 0) -> Array[String]:
	"""Cleanse statuses matching tags. Returns removed status_ids."""
	if status_tracker:
		return status_tracker.cleanse(tags, max_removals)
	return []

func process_turn_start_statuses() -> Array[Dictionary]:
	"""Process start-of-turn status ticks. Returns tick results for combat log.
	The combat manager should call this and handle the returned damage/heal."""
	if status_tracker:
		return status_tracker.process_turn_start()
	return []

func process_turn_end_statuses() -> Array[Dictionary]:
	"""Process end-of-turn status ticks. Returns tick results for combat log."""
	if status_tracker:
		return status_tracker.process_turn_end()
	return []

func clear_combat_status_effects() -> void:
	"""Reset all statuses between combats."""
	if status_tracker:
		status_tracker.clear_combat_only()

func clear_all_status_effects() -> void:
	"""Nuclear option: remove everything."""
	if status_tracker:
		status_tracker.clear_all()

## Legacy compatibility shim — logs warnings so you can find and migrate callers.
func add_status_effect(effect: String, amount: int, _turns: int = -1) -> void:
	push_warning("DEPRECATED: add_status_effect('%s'). Use apply_status() with StatusAffix." % effect)
	print("⚠️ Legacy add_status_effect: %s, %d" % [effect, amount])

func remove_status_effect(effect: String, amount: int = -1) -> void:
	push_warning("DEPRECATED: remove_status_effect('%s'). Use remove_status()/remove_status_stacks()." % effect)
	if status_tracker:
		if amount < 0:
			status_tracker.remove_status(effect)
		else:
			status_tracker.remove_stacks(effect, amount)

# ============================================================================
# COMBAT HELPERS
# ============================================================================


func get_damage_bonus() -> int:
	"""Bonus damage from status effects (Expose)."""
	if status_tracker:
		return status_tracker.get_stacks("expose") * 2
	return 0

func get_die_penalty() -> int:
	"""Die value penalty from Slowed + Chill."""
	if status_tracker:
		return status_tracker.get_die_penalty()
	return 0

func check_dodge() -> bool:
	"""Roll a dodge check. Each Dodge stack = 10% chance."""
	if status_tracker:
		return status_tracker.check_dodge()
	return false


func get_physical_damage_bonus() -> int:
	return get_total_stat("strength")

func get_magical_damage_bonus() -> int:
	return get_total_stat("intellect")


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
		
		
func is_item_equipped(item: Dictionary) -> bool:
	"""Check if a specific item is currently equipped in any slot"""
	for slot in equipment:
		if equipment[slot] is Dictionary and is_same(equipment[slot], item):
			return true
	return false
