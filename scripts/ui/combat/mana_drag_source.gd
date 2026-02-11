# res://scripts/ui/combat/mana_drag_source.gd
# Thin drag source for mana die preview in ManaDieSelector.
# On drag start: pulls mana die, adds to hand, returns standard
# "combat_die" drag data that ActionFields accept natively.
extends Control
class_name ManaDragSource

var selector: ManaDieSelector = null
var _manual_preview: Control = null
var _is_dragging: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float):
	if _manual_preview and _is_dragging:
		var preview_size = _manual_preview.size if _manual_preview.size.length() > 0 else Vector2(62, 62)
		_manual_preview.global_position = get_global_mouse_position() - preview_size / 2

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not selector:
		print("🎲 ManaDragSource: No selector")
		return null

	var result = selector.pull_mana_die_for_drag()
	if result.is_empty():
		print("🎲 ManaDragSource: Pull failed")
		return null

	var die: DieResource = result["die"]
	_is_dragging = true
	print("🎲 ManaDragSource: Drag started for %s" % die.display_name)

	# Create manual preview (matches DieObjectBase pattern — avoids can't-drop cursor)
	var preview = die.instantiate_combat_visual()
	if preview:
		if preview is DieObjectBase:
			preview.draggable = false
		_set_mouse_ignore_recursive(preview)
		preview.modulate = Color(1, 1, 1, 0.8)
		preview.z_index = 100
		var overlay = get_tree().current_scene.find_child("DragOverlayLayer", true, false)
		if overlay:
			overlay.add_child(preview)
		else:
			get_tree().root.add_child(preview)
		_manual_preview = preview

	return {
		"type": "combat_die",
		"die": die,
		"die_object": null,
		"source_position": global_position,
		"slot_index": -1,
	}

func _notification(what: int):
	match what:
		NOTIFICATION_DRAG_END:
			_is_dragging = false
			if _manual_preview:
				_manual_preview.queue_free()
				_manual_preview = null
			if selector:
				selector._on_mana_drag_ended()

func _set_mouse_ignore_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
