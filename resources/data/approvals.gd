# res://resources/data/approvals.gd
# Hidden NPC approval tracking — an internal measure of how each NPC
# feels about Bones based on dialogue choices. Unlike Relationships,
# approval is never shown to the player.
# Values are clamped to -100 (despised) to +100 (devoted).
# 0 is neutral.
extends Resource
class_name Approvals

signal approval_changed(npc_id: StringName, old_value: int, new_value: int)

const MIN_VALUE := -100
const MAX_VALUE := 100

# ============================================================================
# STORAGE
# ============================================================================
@export var _data: Dictionary = {}  # StringName -> int

# ============================================================================
# API
# ============================================================================

func set_approval(npc_id: StringName, value: int) -> void:
	"""Set approval to a specific value (clamped to -100 to +100)."""
	var clamped = clampi(value, MIN_VALUE, MAX_VALUE)
	var old_value = _data.get(npc_id, 0)
	if old_value != clamped:
		_data[npc_id] = clamped
		approval_changed.emit(npc_id, old_value, clamped)

func get_approval(npc_id: StringName) -> int:
	"""Get approval value. Returns 0 (neutral) if not set."""
	return _data.get(npc_id, 0)

func modify(npc_id: StringName, delta: int) -> int:
	"""Add to an approval value and return the new value."""
	var new_value = clampi(get_approval(npc_id) + delta, MIN_VALUE, MAX_VALUE)
	set_approval(npc_id, new_value)
	return new_value

func get_all_approvals() -> Dictionary:
	"""Get all approvals as a dictionary."""
	return _data.duplicate()
