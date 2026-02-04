# res://scripts/ui/combat/end_combat_button.gd
# Debug button to immediately end combat and return to map
extends Button
class_name EndCombatButton

@export var player_wins: bool = true

func _ready():
	text = "End Combat (Debug)"
	pressed.connect(_on_pressed)

func _on_pressed():
	print("🛑 End Combat button pressed (player_wins=%s)" % player_wins)
	
	# Try GameRoot first (new layer system)
	if GameManager and GameManager.game_root:
		GameManager.game_root.end_combat(player_wins)
		return
	
	# Fallback: try to find CombatManager and end directly
	var combat_manager = get_tree().get_first_node_in_group("combat_manager")
	if combat_manager and combat_manager.has_method("end_combat"):
		combat_manager.end_combat(player_wins)
		return
	
	# Last resort: just tell GameManager
	if GameManager:
		GameManager.on_combat_ended(player_wins)
		
		# Try to return to map via old system
		if GameManager.has_method("load_map_scene"):
			GameManager.load_map_scene()
