# res://resources/data/dialogue_choice.gd
# A single dialogue choice the player can select.
# Now uses GameCondition for flexible AND/OR logic.
extends Resource
class_name DialogueChoice

# ============================================================================
# DISPLAY
# ============================================================================
@export_group("Display")
## Text shown on the choice bubble
@export var label: String = ""
## Localization key for label (if empty, uses label directly)
@export var label_key: String = ""
## Optional icon shown next to the choice
@export var icon: Texture2D = null
## Override bubble color for this choice (transparent = use default)
@export var bubble_color_override: Color = Color.TRANSPARENT

# ============================================================================
# FLOW
# ============================================================================
@export_group("Flow")
## The dialogue line to show when this choice is selected
@export var next_line: Resource = null  # DialogueLine (circular ref workaround)

# ============================================================================
# CONDITIONS
# ============================================================================
@export_group("Conditions")
## Condition that must be met for this choice to appear.
## Uses GameCondition for AND/OR logic. Leave null for always visible.
@export var condition: Resource = null  # GameCondition

## If true, show the choice grayed out when condition fails (instead of hiding)
@export var show_when_locked: bool = false
## Text to show when hovering a locked choice
@export var locked_hint: String = ""
## Localization key for locked hint
@export var locked_hint_key: String = ""

# ============================================================================
# EVENTS
# ============================================================================
@export_group("Events")
## Event tag to fire when this choice is selected (before showing next_line)
@export var event_tag: StringName = &""
## Flags to set when this choice is selected
@export var set_flags: Array[StringName] = []
## Relationship changes when selected: { npc_id: delta }
@export var relationship_changes: Dictionary = {}

# ============================================================================
# API
# ============================================================================

func get_label() -> String:
	"""Get the localized label text."""
	# TODO: Hook into localization system
	if label_key != "":
		# return tr(label_key)
		pass
	return label

func get_locked_hint() -> String:
	"""Get the localized locked hint text."""
	if locked_hint_key != "":
		# return tr(locked_hint_key)
		pass
	return locked_hint

func is_available() -> bool:
	"""Check if this choice's condition is met."""
	if condition == null:
		return true
	# Use GameState to evaluate the condition
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		return GameState.evaluate_condition(condition)
	# Fallback: if GameState isn't available, allow the choice
	return true

func should_display() -> bool:
	"""Check if this choice should be shown (available OR show_when_locked)."""
	return is_available() or show_when_locked

func apply_effects() -> void:
	"""Apply side effects when this choice is selected."""
	# Set flags
	for flag_name in set_flags:
		if Engine.has_singleton("GameState") or has_node("/root/GameState"):
			GameState.set_flag(flag_name, true)
	
	# Apply relationship changes
	for npc_id in relationship_changes:
		var delta = relationship_changes[npc_id]
		if Engine.has_singleton("GameState") or has_node("/root/GameState"):
			GameState.modify_relationship(npc_id, delta)

func has_node(path: String) -> bool:
	"""Helper to check if a node exists."""
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		return tree.root.has_node(path)
	return false
