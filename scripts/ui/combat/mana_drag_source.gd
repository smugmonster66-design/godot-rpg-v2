# res://scripts/ui/combat/mana_drag_source.gd
extends Control
class_name ManaDragSource

var selector: Control = null
var _manual_preview: Control = null
var _is_dragging: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
func _process(_delta: float):
	if _manual_preview and _is_dragging:
		_update_preview_position()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not selector or not selector.has_method("_create_mana_drag_data"):
		return null
	var data = selector._create_mana_drag_data()
	if not data:
		return null

	_is_dragging = true
	if selector.has_method("_create_mana_drag_preview"):
		_manual_preview = selector._create_mana_drag_preview()
		if _manual_preview:
			_set_mouse_ignore_recursive(_manual_preview)
			_manual_preview.z_index = 100
			# Add to DragOverlayLayer for visibility above all UI
			var overlay = get_tree().current_scene.find_child("DragOverlayLayer", true, false)
			if overlay:
				overlay.add_child(_manual_preview)
			else:
				get_tree().root.add_child(_manual_preview)
			_update_preview_position()
	return data

func _update_preview_position():
	if _manual_preview:
		var preview_size = _manual_preview.size if _manual_preview.size.length() > 0 else Vector2(62, 62)
		_manual_preview.global_position = get_global_mouse_position() - preview_size / 2

func _notification(what: int):
	match what:
		NOTIFICATION_DRAG_END:
			print("🎯 ManaDragSource: DRAG_END fired, _is_dragging=%s" % _is_dragging)
			_is_dragging = false
			if _manual_preview:
				_manual_preview.queue_free()
				_manual_preview = null
			
			var bottom_ui = get_tree().get_first_node_in_group("bottom_ui")
			print("🎯 ManaDragSource: bottom_ui=%s" % (bottom_ui != null))
			if bottom_ui:
				var mouse = get_global_mouse_position()
				var rect = bottom_ui.get_global_rect()
				print("🎯 ManaDragSource: mouse=%s, rect=%s, hit=%s" % [mouse, rect, rect.has_point(mouse)])
				if rect.has_point(mouse):
					_handle_mana_drop()
			
			if selector and selector.has_method("_on_drag_ended"):
				selector._on_drag_ended()

func _is_mouse_over(control: Control) -> bool:
	var mouse = get_global_mouse_position()
	return control.get_global_rect().has_point(mouse)

func _handle_mana_drop():
	if not selector or not selector.has_method("pull_and_create_die"):
		return
	var new_die: DieResource = selector.pull_and_create_die()
	if not new_die:
		print("🎲 ManaDragSource: Mana pull failed")
		return
	# Find the player's dice pool
	var bottom_ui = get_tree().get_first_node_in_group("bottom_ui")
	if bottom_ui and bottom_ui.player and bottom_ui.player.dice_pool:
		bottom_ui.player.dice_pool.add_die_to_hand(new_die)
		print("🎲 ManaDragSource: %s added to hand" % new_die.display_name)
func _set_mouse_ignore_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
