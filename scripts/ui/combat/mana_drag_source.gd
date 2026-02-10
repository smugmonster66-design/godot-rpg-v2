# res://scripts/ui/combat/mana_drag_source.gd
# Tiny drag-source Control placed in the center of ManaDieSelector's 3×3 grid.
# Implements _get_drag_data() so Godot's native drag system can originate here.
# Delegates all logic back to the parent ManaDieSelector.
extends Control
class_name ManaDragSource

# ============================================================================
# REFERENCES
# ============================================================================

## Set by ManaDieSelector after creation.
var selector: Control = null  # ManaDieSelector

## Manual preview node (same pattern as DieObjectBase)
var _manual_preview: Control = null
var _is_dragging: bool = false

# ============================================================================
# DRAG INITIATION
# ============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Godot calls this when the user starts dragging from this Control."""
	if not selector or not selector.has_method("_create_mana_drag_data"):
		return null

	var data = selector._create_mana_drag_data()
	if not data:
		return null

	# Create manual preview (same approach as DieObjectBase to avoid
	# the can't-drop cursor issue with set_drag_preview)
	_is_dragging = true

	if selector.has_method("_create_mana_drag_preview"):
		_manual_preview = selector._create_mana_drag_preview()
		if _manual_preview:
			_set_mouse_ignore_recursive(_manual_preview)
			_manual_preview.z_index = 100
			get_tree().root.add_child(_manual_preview)
			_update_preview_position()
			set_process(true)

	return data

func _process(_delta: float):
	if _manual_preview and _is_dragging:
		_update_preview_position()

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
			set_process(false)
			if selector and selector.has_method("_on_drag_ended"):
				selector._on_drag_ended()

# ============================================================================
# UTILITY
# ============================================================================

func _set_mouse_ignore_recursive(node: Node):
	"""Prevent the drag preview from intercepting drop targets."""
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
