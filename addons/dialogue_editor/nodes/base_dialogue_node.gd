@tool
extends GraphNode
class_name BaseDialogueNode

# ============================================================================
# SIGNALS
# ============================================================================
signal modified

# ============================================================================
# VIRTUAL METHODS
# ============================================================================

func get_node_type() -> String:
	"""Override in subclasses to return node type name."""
	return "base"

func get_node_data() -> Dictionary:
	"""Override to return serializable data for this node."""
	return {
		"type": get_node_type(),
		"position": position_offset,
	}

func set_node_data(data: Dictionary) -> void:
	"""Override to restore node state from serialized data."""
	if data.has("position"):
		position_offset = data.position

func is_multi_output() -> bool:
	"""Override to return true if this node has multiple output ports."""
	return false

# ============================================================================
# HELPERS
# ============================================================================

func _emit_modified() -> void:
	modified.emit()
