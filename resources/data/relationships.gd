# res://resources/data/relationships.gd
# NPC affinity/reputation tracking.
# Values are clamped to -100 (hostile) to +100 (devoted).
# 0 is neutral.
extends Resource
class_name Relationships

signal relationship_changed(npc_id: StringName, old_value: int, new_value: int)

const MIN_VALUE := -100
const MAX_VALUE := 100

# Thresholds for relationship states
const HOSTILE_THRESHOLD := -50
const UNFRIENDLY_THRESHOLD := -20
const FRIENDLY_THRESHOLD := 20
const ALLIED_THRESHOLD := 50
const DEVOTED_THRESHOLD := 80

enum RelationshipState {
	HOSTILE,    # -100 to -50
	UNFRIENDLY, # -49 to -20
	NEUTRAL,    # -19 to +19
	FRIENDLY,   # +20 to +49
	ALLIED,     # +50 to +79
	DEVOTED     # +80 to +100
}

# ============================================================================
# STORAGE
# ============================================================================
@export var _data: Dictionary = {}  # StringName -> int

# ============================================================================
# API
# ============================================================================

func set_relationship(npc_id: StringName, value: int) -> void:
	"""Set relationship to a specific value (clamped to -100 to +100)."""
	var clamped = clampi(value, MIN_VALUE, MAX_VALUE)
	var old_value = _data.get(npc_id, 0)
	if old_value != clamped:
		_data[npc_id] = clamped
		relationship_changed.emit(npc_id, old_value, clamped)

func get_relationship(npc_id: StringName) -> int:
	"""Get relationship value. Returns 0 (neutral) if not set."""
	return _data.get(npc_id, 0)

func modify(npc_id: StringName, delta: int) -> int:
	"""Add to a relationship value and return the new value."""
	var new_value = clampi(get_relationship(npc_id) + delta, MIN_VALUE, MAX_VALUE)
	set_relationship(npc_id, new_value)
	return new_value

func get_state(npc_id: StringName) -> RelationshipState:
	"""Get the relationship state enum for an NPC."""
	var value = get_relationship(npc_id)
	if value >= DEVOTED_THRESHOLD:
		return RelationshipState.DEVOTED
	elif value >= ALLIED_THRESHOLD:
		return RelationshipState.ALLIED
	elif value >= FRIENDLY_THRESHOLD:
		return RelationshipState.FRIENDLY
	elif value > UNFRIENDLY_THRESHOLD:
		return RelationshipState.NEUTRAL
	elif value > HOSTILE_THRESHOLD:
		return RelationshipState.UNFRIENDLY
	else:
		return RelationshipState.HOSTILE

func get_state_name(npc_id: StringName) -> String:
	"""Get human-readable relationship state."""
	match get_state(npc_id):
		RelationshipState.HOSTILE: return "Hostile"
		RelationshipState.UNFRIENDLY: return "Unfriendly"
		RelationshipState.NEUTRAL: return "Neutral"
		RelationshipState.FRIENDLY: return "Friendly"
		RelationshipState.ALLIED: return "Allied"
		RelationshipState.DEVOTED: return "Devoted"
	return "Unknown"

func is_at_least(npc_id: StringName, minimum_state: RelationshipState) -> bool:
	"""Check if relationship meets a minimum state."""
	return get_state(npc_id) >= minimum_state

func get_all_relationships() -> Dictionary:
	"""Get all relationships as a dictionary."""
	return _data.duplicate()
