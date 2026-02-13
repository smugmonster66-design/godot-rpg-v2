# action_manager.gd - Manages player's available combat actions
# v3 — Reads EquippableItem directly from player.equipment.
extends Node
class_name ActionManager

var player: Player = null

# All actions in one list
var actions: Array[Dictionary] = []

signal actions_changed()

func initialize(p_player: Player):
	player = p_player
	
	if player:
		if not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)
		
		# Rebuild actions when bonus ranks grant/revoke NEW_ACTION affixes
		if player.active_class and player.active_class.has_signal("effective_ranks_changed"):
			if not player.active_class.effective_ranks_changed.is_connected(_on_effective_ranks_changed):
				player.active_class.effective_ranks_changed.connect(_on_effective_ranks_changed)
	
	rebuild_actions()

func rebuild_actions():
	print("📋 rebuild_actions() called")
	actions.clear()
	
	_add_item_actions()
	_add_affix_granted_actions()
	
	print("📋 Actions rebuilt: %d total" % actions.size())
	for i in range(actions.size()):
		print("  [%d] %s from %s" % [i, actions[i].get("name", "?"), actions[i].get("source", "?")])
	
	actions_changed.emit()

func _add_item_actions():
	"""Add actions from equipped items (now EquippableItem-based)."""
	if not player:
		return
	
	print("📋 Scanning equipped items for actions...")
	
	var processed_items: Array[EquippableItem] = []
	
	for slot in player.equipment:
		var item: EquippableItem = player.equipment[slot]
		
		if not item or item in processed_items:
			continue
		
		processed_items.append(item)
		print("  Slot: %s, item: %s" % [slot, item.item_name])
		
		if item.grants_action and item.action:
			var action_dict = item.action.to_dict()
			action_dict["action_resource"] = item.action
			action_dict["source"] = item.item_name
			action_dict["source_icon"] = item.icon
			action_dict["source_rarity"] = item.get_rarity_name()
			
			var elem_id = item.get_elemental_identity()
			if elem_id >= 0:
				action_dict["source_element"] = elem_id
			
			# v6: Apply die slot bonuses from action-scoped affixes
			if player and player.affix_manager:
				var slot_bonus = player.affix_manager.get_action_die_slot_bonus(
					item.action.action_id
				)
				if slot_bonus > 0:
					action_dict["die_slots"] = action_dict.get("die_slots", 1) + slot_bonus
					print("  🎲 +%d die slots to %s (from skill ranks)" % [
						slot_bonus, item.action.action_name
					])
			
			actions.append(action_dict)
			print("  ✅ Added action: %s from %s (slots: %d)" % [
				action_dict.get("name", "?"), item.item_name,
				action_dict.get("die_slots", 1)
			])

func _add_affix_granted_actions():
	"""Add actions granted by NEW_ACTION affixes."""
	if not player or not player.affix_manager:
		return
	
	var granted_actions = player.affix_manager.get_granted_actions()
	for action_resource in granted_actions:
		if action_resource:
			var action_dict = action_resource.to_dict()
			action_dict["action_resource"] = action_resource
			
			# v6: Apply die slot bonuses from action-scoped affixes
			var slot_bonus = player.affix_manager.get_action_die_slot_bonus(
				action_resource.action_id
			)
			if slot_bonus > 0:
				action_dict["die_slots"] = action_dict.get("die_slots", 1) + slot_bonus
				print("  🎲 +%d die slots to %s (from skill ranks)" % [
					slot_bonus, action_resource.action_name
				])
			
			# Try to find source item for icon/rarity/element
			var source_name = action_dict.get("source", "")
			if source_name and player:
				var source_item = player.get_equipped_item_by_name(source_name)
				if source_item:
					action_dict["source_icon"] = source_item.icon
					action_dict["source_rarity"] = source_item.get_rarity_name()
					var elem_id = source_item.get_elemental_identity()
					if elem_id >= 0:
						action_dict["source_element"] = elem_id
			
			actions.append(action_dict)
			print("  ✅ Added affix action: %s (slots: %d)" % [
				action_dict.get("name", "?"), action_dict.get("die_slots", 1)
			])

func _on_equipment_changed(_slot: String, _item):
	rebuild_actions()

func _on_effective_ranks_changed(_changed_skills: Array[String]):
	"""Bonus ranks changed — actions may have been granted or revoked."""
	print("📋 ActionManager: Effective ranks changed for %s — rebuilding" % str(_changed_skills))
	rebuild_actions()

func get_actions() -> Array[Dictionary]:
	return actions
