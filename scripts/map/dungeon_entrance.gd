# res://scripts/map/dungeon_entrance.gd
## Attach to any node on the map that should launch a dungeon.
## Works with Button, Area2D, or any node — just call enter().
extends Node
class_name DungeonEntrance

## Drag your DungeonDefinition .tres file here in the Inspector.
@export var dungeon_definition: DungeonDefinition = null

## Drag a DungeonChain .tres here to enter a chain instead of a single dungeon.
## Takes priority over dungeon_definition if both are set.
@export var dungeon_chain: DungeonChain = null

## Optional: minimum player level to enter (0 = no restriction)
@export var min_level: int = 0

## Optional: label shown on the button / tooltip
@export var entrance_label: String = "Enter Dungeon"

func _ready():
	# If parent is a Button, auto-connect pressed signal
	if get_parent() is Button:
		var btn = get_parent() as Button
		if not btn.pressed.is_connected(enter):
			btn.pressed.connect(enter)

func enter():
	if not dungeon_chain and not dungeon_definition:
		push_error("DungeonEntrance: No dungeon_definition or dungeon_chain assigned!")
		return

	# Optional level gate
	if min_level > 0 and GameManager and GameManager.player:
		if GameManager.player.level < min_level:
			print("Need level %d to enter this dungeon" % min_level)
			return

	# Find GameRoot and enter
	var game_root = get_tree().get_first_node_in_group("game_root")
	if not game_root:
		game_root = get_tree().root.find_child("GameRoot", true, false)

	if not game_root:
		push_error("DungeonEntrance: Can't find GameRoot!")
		return

	if dungeon_chain and game_root.has_method("enter_dungeon_chain"):
		game_root.enter_dungeon_chain(dungeon_chain)
	elif dungeon_definition and game_root.has_method("enter_dungeon"):
		game_root.enter_dungeon(dungeon_definition)
	else:
		push_error("DungeonEntrance: GameRoot missing required method!")
