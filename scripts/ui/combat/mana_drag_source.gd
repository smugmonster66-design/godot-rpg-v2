# res://scripts/ui/combat/mana_drag_source.gd
extends Control
class_name ManaDragSource

var selector: Control = null
var _manual_preview: Control = null
var _is_dragging: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float):
	if _manual_preview and _is_dragging:
		_update_preview_position()
	elif not _is_dragging and selector and selector.die_preview_container:
		# Track die_preview_container in parent-local coordinates
		var container: Control = selector.die_preview_container
		position = container.position + container.get_parent().position
		size = container.size

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
			_is_dragging = false
			if _manual_preview:
				_manual_preview.queue_free()
				_manual_preview = null
			if selector and selector.has_method("_on_drag_ended"):
				selector._on_drag_ended()

func _set_mouse_ignore_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
