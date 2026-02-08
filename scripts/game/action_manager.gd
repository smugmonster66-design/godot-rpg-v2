# action_manager.gd - Manages player's available combat actions
extends Node
class_name ActionManager

var player: Player = null

# All actions in one list (no more item/skill separation)
var actions: Array[Dictionary] = []

signal actions_changed()

func initialize(p_player: Player):
	"""Initialize with player"""
	player = p_player
	
	if player:
		# Check before connecting to avoid duplicate connections
		if not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)
	
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
	"""Add actions from equipped items"""
	if not player:
		return
	
	print("📋 Scanning equipped items for actions...")
	
	var processed_items: Array = []
	
	for slot in player.equipment:
		var item = player.equipment[slot]
		
		print("  Slot: %s, item: %s" % [slot, item.get("name", "null") if item else "empty"])
		
		if not item or item in processed_items:
			continue
		
		processed_items.append(item)
		
		if item.has("actions"):
			print("    Item has %d actions" % item.actions.size())
			for i in range(item.actions.size()):
				var action_data = item.actions[i]
				print("      Action %d: %s" % [i, action_data.get("name", "?")])
				var action = action_data.duplicate()
				action["source"] = item.get("name", "Unknown Item")
				if not action.has("action_resource") and item.has("action_resource"):
					action["action_resource"] = item["action_resource"]
				actions.append(action)
				print("  ✅ Added action: %s from %s" % [action.get("name", "?"), action.get("source")])


func _add_affix_granted_actions():
	"""Add actions granted by NEW_ACTION affixes"""
	if not player or not player.affix_manager:
		return
	
	var granted_actions = player.affix_manager.get_granted_actions()
	for action_resource in granted_actions:
		if action_resource:
			var action_dict = action_resource.to_dict()
			action_dict["action_resource"] = action_resource
			actions.append(action_dict)
			print("  ✅ Added affix action: %s" % action_dict.get("name", "?"))

func _on_equipment_changed(_slot: String, _item):
	"""Rebuild when equipment changes"""
	rebuild_actions()

func get_actions() -> Array[Dictionary]:
	"""Get all available actions"""
	return actions
