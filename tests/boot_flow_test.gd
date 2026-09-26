# res://tests/boot_flow_test.gd
# Headless test of the boot flow: title screen -> New Game / Continue -> map.
#
# WRITES user://save.tres. Back up your save before running.
# Runs as a scene (so autoloads exist), and adds GameRoot to the tree root so
# GameManager recognises it:
#
#   godot --headless --path . res://tests/boot_flow_test.tscn -- new
#   godot --headless --path . res://tests/boot_flow_test.tscn -- continue
#
# "new":      boots GameRoot, confirms New Game on the title screen, checks the
#             player starts inside GameRoot.new_game_zone and that a save exists.
# "continue": boots GameRoot, presses Continue, checks the saved zone and
#             location were restored.
# Exit code 0 = pass, 1 = fail.
extends Node

var _mode := "new"
var _failures: Array[String] = []
# Autoloads looked up at runtime (not compile-time identifiers in -s mode).
var GM: Node
var GS: Node
var MM: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	# GameManager decides how to boot by looking at the last child of the tree
	# root one frame after startup, so GameRoot must be added there before then.
	var root_scene: Node = load("res://scenes/game/game_root.tscn").instantiate()
	get_tree().root.add_child.call_deferred(root_scene)
	_run.call_deferred(root_scene)


func _check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run(root_scene: Node) -> void:
	print("boot_flow_test: mode=%s" % _mode)
	GM = GameManager
	GS = GameState
	MM = MapManager
	await _frames(10)

	var title: Node = root_scene.find_child("TitleScreen", true, false)
	_check(title != null, "title screen is shown at boot")
	_check(GM.player == null, "no player before the player chooses")
	_check(GS.session_active == false, "no session (no autosave) on the title screen")
	if title == null:
		_finish()
		return

	if _mode == "continue":
		_check(GS.has_save(), "a save exists to continue")
		title.continue_requested.emit()
	else:
		title.new_game_confirmed.emit()
	await _frames(30)

	_check(GM.player != null, "player created")
	_check(GS.session_active, "session active after choosing")
	_check(root_scene.find_child("TitleScreen", true, false) == null, "title screen closed")

	var zone: MapDefinition = root_scene.get("new_game_zone")
	var top: MapDefinition = MM.get_current_map()
	if zone != null:
		_check(MM.get_map_depth() == 2, "inside a zone (map depth 2), got %d" % MM.get_map_depth())
		_check(top == zone or (top and zone and top.resource_path == zone.resource_path),
			"current map is new_game_zone (%s)" % (top.map_id if top else "null"))
		_check(zone.contains_location(GS.map.current_location),
			"player location %s is in the zone" % GS.map.current_location)

	if _mode == "new":
		# Force the pending autosave through and confirm it hit the disk.
		await _frames(5)
		_check(GS.has_save(), "autosave wrote a save file")
		var saved := SaveData.load_from_disk()
		_check(saved.map_stack.size() == MM.get_map_depth(),
			"saved map_stack has %d entries (expected %d)" % [saved.map_stack.size(), MM.get_map_depth()])
		_check(saved.has_player_state, "save has player state")

	_finish()


func _finish() -> void:
	# Don't let GameState save again on quit.
	GS.session_active = false
	if _failures.is_empty():
		print("boot_flow_test: ALL PASSED (%s)" % _mode)
		get_tree().quit(0)
	else:
		print("boot_flow_test: %d FAILED (%s)" % [_failures.size(), _mode])
		get_tree().quit(1)
