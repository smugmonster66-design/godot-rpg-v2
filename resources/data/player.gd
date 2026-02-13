# player.gd - Player data resource
# v3 — Equipment and inventory are now EquippableItem-based (no Dictionary bridge).
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
# PLAYER LEVEL (for equip requirements)
# ============================================================================
var level: int = 1

# ============================================================================
# EQUIPMENT — Now stores EquippableItem directly (or null)
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
# INVENTORY — Now stores EquippableItem directly
# ============================================================================
var inventory: Array[EquippableItem] = []

# ============================================================================
# CLASS SYSTEM
# ============================================================================
var active_class: PlayerClass = null
var available_classes: Dictionary = {}

# ============================================================================
# STATUS EFFECTS
# ============================================================================
var status_tracker: StatusTracker = null

# ============================================================================
# DICE POOL
# ============================================================================
var dice_pool: PlayerDiceCollection = null

# ============================================================================
# MANA POOL (v4 — Mage System)
# ============================================================================
## Mana pool for caster classes. Null for non-caster classes (warrior, rogue).
## Created in _init(), configured via initialize_mana_pool() after class is set.
var mana_pool: ManaPool = null

# ============================================================================
# AFFIX MANAGER
# ============================================================================
var affix_manager: AffixPoolManager = AffixPoolManager.new()
var set_tracker: SetTracker = SetTracker.new()

# ============================================================================
# SIGNALS
# ============================================================================
signal stat_changed(stat_name: String, old_value, new_value)
signal equipment_changed(slot: String, item: EquippableItem)
signal equip_failed(slot: String, item: EquippableItem, reason: String)
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
	
	dice_pool = PlayerDiceCollection.new()
	dice_pool.name = "DicePool"
	
	status_tracker = StatusTracker.new()
	status_tracker.name = "StatusTracker"
	_connect_status_tracker_signals()
	
	mana_pool = ManaPool.new()
	
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

func get_base_stat(stat_name: String) -> int:
	"""Get the raw base stat value (no equipment, no class, no affixes)."""
	return get(stat_name) if stat_name in self else 0

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
	
	# Status effect modifiers
	if status_tracker:
		subtotal += int(status_tracker.get_total_stat_modifier(stat_name))
	
	return subtotal

func get_equipment_stat_bonus(stat_name: String) -> int:
	"""Equipment stat bonuses now come entirely from the affix system.
	Inherent affixes are registered in the affix_manager on equip,
	so this legacy method returns 0. Kept for compatibility."""
	return 0

func get_armor() -> int:
	var total = base_armor
	if active_class:
		total += active_class.get_stat_bonus("armor")
	
	for affix in affix_manager.get_pool(Affix.Category.ARMOR_BONUS):
		total += int(affix.apply_effect())
	
	if status_tracker:
		total += int(status_tracker.get_total_stat_modifier("armor"))
	
	return maxi(0, total)

func get_barrier() -> int:
	var total = base_barrier
	if active_class:
		total += active_class.get_stat_bonus("barrier")
	
	for affix in affix_manager.get_pool(Affix.Category.BARRIER_BONUS):
		total += int(affix.apply_effect())
	
	if status_tracker:
		total += int(status_tracker.get_total_stat_modifier("barrier"))
	
	return maxi(0, total)

func recalculate_stats():
	# ── Max HP ──
	var base_hp: int = 100
	var hp_bonus: int = 0
	for affix in affix_manager.get_pool(Affix.Category.HEALTH_BONUS):
		hp_bonus += int(affix.apply_effect())
	var new_max_hp = base_hp + hp_bonus
	if new_max_hp != max_hp:
		var old_max = max_hp
		max_hp = new_max_hp
		current_hp = clampi(roundi(current_hp * (float(max_hp) / float(old_max))), 1, max_hp)
		hp_changed.emit(current_hp, max_hp)
	
	# ── Max Mana ──
	var base_mana_val: int = 50 + get_total_stat("intellect") * 2
	var mana_bonus: int = 0
	for affix in affix_manager.get_pool(Affix.Category.MANA_BONUS):
		mana_bonus += int(affix.apply_effect())
	var new_max_mana = base_mana_val + mana_bonus
	if new_max_mana != max_mana:
		var old_max_mana = max_mana
		max_mana = new_max_mana
		current_mana = clampi(roundi(current_mana * (float(max_mana) / float(old_max_mana))), 0, max_mana)
		mana_changed.emit(current_mana, max_mana)
	
	# ── Effective Skill Ranks (v6) ──
	# Equipment may grant SKILL_RANK_BONUS / TREE_SKILL_RANK_BONUS /
	# CLASS_SKILL_RANK_BONUS / TAG_SKILL_RANK_BONUS affixes. Recalculate
	# effective ranks and apply/remove the delta affixes.
	if active_class:
		var changed_skills = active_class.recalculate_effective_ranks()
		if not changed_skills.is_empty():
			# Mana pool may need updating if mana-related skill affixes changed
			if mana_pool:
				mana_pool.notify_options_changed()

# ============================================================================
# MANA POOL INTEGRATION (v4)
# ============================================================================

func initialize_mana_pool() -> void:
	"""Configure the mana pool from the active class's template.

	Call after active_class is set and equipment/skills are applied.
	If the active class has no mana_pool_template, the mana pool is
	left unconfigured (has_mana_pool() returns false).
	"""
	if not mana_pool:
		mana_pool = ManaPool.new()

	if not active_class or not active_class.get("mana_pool_template"):
		return

	var template: ManaPool = active_class.mana_pool_template
	mana_pool.base_max_mana = template.base_max_mana
	mana_pool.mana_curve = template.mana_curve
	mana_pool.int_mana_ratio = template.int_mana_ratio
	mana_pool.max_level = template.max_level
	mana_pool.refill_on_combat_start = template.refill_on_combat_start

	var int_stat = get_total_stat("intellect") if has_method("get_total_stat") else intellect
	mana_pool.initialize(
		active_class.level if active_class else level,
		int_stat,
		affix_manager
	)

func has_mana_pool() -> bool:
	"""Check if the player has an active mana pool (is a caster class).
	Returns false if no class is set or class has no mana_pool_template."""
	if not active_class:
		return false
	if not active_class.get("mana_pool_template"):
		return false
	return mana_pool != null

# ============================================================================
# HEALTH & MANA
# ============================================================================


func take_damage(amount: int, is_magical: bool = false) -> int:
	var damage_reduction: int = get_barrier() if is_magical else get_armor()
	
	if status_tracker:
		damage_reduction += status_tracker.get_block_value()
	
	var actual_damage: int = maxi(0, amount - damage_reduction)
	
	if status_tracker:
		actual_damage = status_tracker.consume_overhealth(actual_damage)
	
	current_hp = maxi(0, current_hp - actual_damage)
	hp_changed.emit(current_hp, max_hp)
	
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
# EQUIPMENT MANAGEMENT — Now EquippableItem-based
# ============================================================================

func equip_item(item: EquippableItem, slot: String = "") -> bool:
	"""Equip an EquippableItem. Returns false if requirements not met."""
	if not item:
		return false
	
	# Resolve target slot
	var target_slot = slot if slot != "" else item.get_slot_name()
	
	# Check equip requirements
	if not item.can_equip(self):
		var reasons = item.get_unmet_requirements(self)
		var reason_text = ", ".join(reasons) if reasons.size() > 0 else "Requirements not met"
		equip_failed.emit(target_slot, item, reason_text)
		print("❌ Cannot equip %s: %s" % [item.item_name, reason_text])
		return false
	
	# Handle heavy weapons (occupy both Main Hand and Off Hand)
	if item.is_heavy_weapon():
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
	
	_add_item_affixes(item)
	_apply_item_dice(item)
	
	equipment_changed.emit(target_slot, item)
	recalculate_stats()
	return true

func unequip_item(slot: String) -> bool:
	"""Unequip item from slot. Returns false if slot is empty."""
	if equipment[slot] == null:
		return false
	
	var item: EquippableItem = equipment[slot]
	
	_remove_item_affixes(item)
	_remove_item_dice(item)
	
	if item.is_heavy_weapon():
		equipment["Main Hand"] = null
		equipment["Off Hand"] = null
	else:
		equipment[slot] = null
	
	equipment_changed.emit(slot, null)
	recalculate_stats()
	return true

func get_equipped_item(slot: String) -> EquippableItem:
	"""Get the EquippableItem in a slot, or null."""
	return equipment.get(slot)

func is_item_equipped(item: EquippableItem) -> bool:
	"""Check if a specific EquippableItem is currently equipped."""
	if not item:
		return false
	for slot in equipment:
		if equipment[slot] == item:
			return true
	return false

func get_equipped_item_by_name(item_name_query: String) -> EquippableItem:
	"""Find an equipped item by name."""
	for slot in equipment:
		var item = equipment[slot]
		if item and item.item_name == item_name_query:
			return item
	return null

# ============================================================================
# DICE MANAGEMENT — EquippableItem-based
# ============================================================================

func _apply_item_dice(item: EquippableItem):
	"""Add item's runtime dice to the player's pool."""
	if not dice_pool or not item:
		return
	
	var source_name = item.item_name
	var tags = item.dice_tags
	var affixes = item.item_affixes
	var dice_modified = item.are_dice_modified()
	
	for die_template in item.get_runtime_dice():
		if die_template is DieResource:
			var die_copy = die_template.duplicate_die()
			die_copy.source = source_name
			
			for tag in tags:
				die_copy.add_tag(tag)
			
			# Snapshot dice may contain stale DiceAffixes from external
			# systems (set bonuses, combat modifiers, etc.) that were on
			# the die when the photo was taken. Strip anything that doesn't
			# belong to this item — those systems will re-apply their own
			# affixes if they're still active.
			if dice_modified:
				var to_keep: Array[DiceAffix] = []
				for da in die_copy.applied_affixes:
					if da.source.is_empty() or da.source == source_name:
						to_keep.append(da)
				die_copy.applied_affixes = to_keep
			
			# Only apply visual effects from item affixes on FRESH dice.
			# Modified dice already have them baked in.
			if not dice_modified:
				for affix in affixes:
					if affix is Affix and affix.dice_visual_affix:
						die_copy.add_affix(affix.dice_visual_affix)
			
			dice_pool.add_die(die_copy)

func _remove_item_dice(item: EquippableItem):
	if not item or not dice_pool:
		return
	
	var pool_dice = dice_pool.get_dice_by_source(item.item_name)
	if pool_dice.size() > 0:
		var modified: Array[DieResource] = []
		for die in pool_dice:
			modified.append(die.duplicate_die())
		item.store_modified_dice(modified)
		print("🎲 Saved %d modified dice back to %s" % [modified.size(), item.item_name])
	
	dice_pool.remove_dice_by_source(item.item_name)


func reset_item_dice_to_base(item: EquippableItem):
	"""Reset an item's dice to templates. If equipped, re-applies to pool."""
	if not item:
		return
	
	item.reset_dice_to_base()
	print("🎲 Reset dice to base templates for %s" % item.item_name)
	
	if is_item_equipped(item):
		dice_pool.remove_dice_by_source(item.item_name)
		_apply_item_dice(item)

# ============================================================================
# AFFIX MANAGEMENT — EquippableItem-based
# ============================================================================

func _add_item_affixes(item: EquippableItem):
	"""Register all item affixes (inherent + rolled) with the affix manager."""
	for affix in item.item_affixes:
		if affix is Affix:
			affix_manager.add_affix(affix)
			print("  ✅ Added affix: %s" % affix.affix_name)
			
			# Handle dice-granting affixes — skip if item has modified dice,
			# because those dice are already in the snapshot and will be
			# restored by _apply_item_dice() via get_runtime_dice().
			if affix.category == Affix.Category.DICE and affix.granted_dice.size() > 0:
				if not item.are_dice_modified():
					_apply_affix_dice(affix, item.item_name)



func _apply_affix_dice(affix: Affix, source_name: String):
	"""Add dice granted by an affix to the player's pool."""
	if not dice_pool:
		return
	for die_template in affix.granted_dice:
		if die_template is DieResource:
			var die_copy = die_template.duplicate_die()
			die_copy.source = source_name
			if affix.dice_visual_affix:
				die_copy.add_affix(affix.dice_visual_affix)
			dice_pool.add_die(die_copy)
			print("  🎲 Affix granted die: %s (from %s)" % [die_copy.display_name, source_name])

func _remove_item_affixes(item: EquippableItem):
	"""Remove all affixes sourced from this item."""
	affix_manager.remove_affixes_by_source(item.item_name)

# ============================================================================
# INVENTORY MANAGEMENT — EquippableItem-based
# ============================================================================

func add_to_inventory(item: EquippableItem):
	"""Add an EquippableItem to inventory."""
	if item and item not in inventory:
		inventory.append(item)
		inventory_changed.emit()
		print("🎒 Added to inventory: %s" % item.item_name)

func remove_from_inventory(item: EquippableItem):
	"""Remove an EquippableItem from inventory."""
	inventory.erase(item)
	inventory_changed.emit()

# ============================================================================
# COMBAT HELPERS
# ============================================================================

func get_physical_damage_bonus() -> int:
	return get_total_stat("strength")

func get_magical_damage_bonus() -> int:
	return get_total_stat("intellect")

func get_expose_bonus() -> int:
	if status_tracker:
		return status_tracker.get_stacks("expose") * 2
	return 0

func get_die_penalty() -> int:
	if status_tracker:
		return status_tracker.get_die_penalty()
	return 0

func check_dodge() -> bool:
	if status_tracker:
		return status_tracker.check_dodge()
	return false

func get_available_combat_actions() -> Array:
	"""Get combat actions from equipped weapons."""
	var actions = []
	for slot in ["Main Hand", "Off Hand"]:
		var item: EquippableItem = equipment[slot]
		if item and item.grants_action and item.action:
			if item.action not in actions:
				actions.append(item.action)
	
	if active_class and active_class.combat_actions:
		for act in active_class.combat_actions:
			if act not in actions:
				actions.append(act)
	
	return actions

func get_defense_stats() -> Dictionary:
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
	
	var resist_category = _element_to_resist_category(element)
	if resist_category >= 0:
		for affix in affix_manager.get_pool(resist_category):
			base += int(affix.apply_effect())
	
	return base

# ============================================================================
# EQUIPMENT SETS
# ============================================================================

func save_equipment_set(set_name: String):
	var set_data = {}
	for slot in equipment:
		if equipment[slot] != null:
			set_data[slot] = equipment[slot]
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
		var item: EquippableItem = set_data[slot]
		var found = false
		
		for inv_item in inventory:
			if inv_item.item_name == item.item_name:
				equip_item(inv_item, slot)
				found = true
				break
		
		if not found:
			missing_items.append(slot)
	
	for slot in missing_items:
		set_data.erase(slot)
	
	return true

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
	
	if active_class and dice_pool:
		dice_pool.remove_dice_by_source(active_class.player_class_name)
		for skill in active_class.get_all_skills():
			if skill:
				affix_manager.remove_affixes_by_source(skill.skill_name)
	
	active_class = available_classes[p_class_name]
	active_class.set_affix_manager_ref(affix_manager)
	
	if dice_pool and active_class:
		var class_dice = active_class.get_starting_dice_copies()
		for die in class_dice:
			dice_pool.add_die(die)
	
	if active_class:
		_reapply_class_skill_affixes()
	
	# v4: Initialize mana pool now that class + skill affixes are in place
	initialize_mana_pool()
	
	class_changed.emit(active_class)
	print("Switched to class: %s" % p_class_name)
	return true

func _reapply_class_skill_affixes():
	if not active_class:
		return
	for skill in active_class.get_all_skills():
		if not skill:
			continue
		var base_rank = active_class.get_skill_rank(skill.skill_id)
		if base_rank <= 0:
			continue
		# Use effective rank (includes gear bonuses) so over-cap affixes get applied
		var effective_rank = base_rank
		if active_class._affix_manager_ref:
			var tree_id = ""
			var class_id = active_class.player_class_name
			# Find tree_id for this skill
			for tree in active_class.get_skill_trees():
				for s in tree.get_all_skills():
					if s and s.skill_id == skill.skill_id:
						tree_id = tree.tree_id
						break
				if tree_id != "":
					break
			effective_rank = active_class.get_effective_skill_rank(
				skill.skill_id, tree_id, class_id, skill.get_max_rank())
		for r in range(1, effective_rank + 1):
			var affixes = skill.get_affixes_for_rank(r)
			for affix in affixes:
				if affix:
					var affix_copy = affix.duplicate_with_source(skill.skill_name, "skill")
					affix_manager.add_affix(affix_copy)

# ============================================================================
# STATUS EFFECTS
# ============================================================================

func apply_status(status_affix: StatusAffix, stacks: int = 1, source_name: String = "") -> void:
	if status_tracker:
		status_tracker.apply_status(status_affix, stacks, source_name)

func remove_status(status_id: String) -> void:
	if status_tracker:
		status_tracker.remove_status(status_id)

func remove_status_stacks(status_id: String, amount: int) -> void:
	if status_tracker:
		status_tracker.remove_stacks(status_id, amount)

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
