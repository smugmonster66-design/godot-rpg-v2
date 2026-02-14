# res://scripts/dungeon/dungeon_popup_base.gd
## Abstract base for all dungeon popups.
## Enforces the show_popup / _build_result contract at compile time.
## Each concrete popup is a packed scene with this base (or a subclass).
@abstract
extends Control
class_name DungeonPopupBase

signal popup_closed(result: Dictionary)

## Node ID of the dungeon node this popup is handling.
var _node_id: int = -1

## The popup type string included in every result dict.
var _popup_type: String = ""

# ============================================================================
# ABSTRACT CONTRACT — subclasses MUST implement these
# ============================================================================

## Show the popup with encounter-specific data.
## data always contains "node" (DungeonNodeData) and "run" (DungeonRun).
@abstract
func show_popup(data: Dictionary) -> void

## Build the result dictionary to emit when the popup closes.
@abstract
func _build_result() -> Dictionary

# ============================================================================
# SHARED INFRASTRUCTURE
# ============================================================================

func _ready():
	hide()
	# Discover CloseButton if present (common across all popups)
	var close_btn = find_child("CloseButton", true, false) as Button
	if close_btn:
		if not close_btn.pressed.is_connected(_on_close):
			close_btn.pressed.connect(_on_close)

func _base_show(data: Dictionary, popup_type: String):
	"""Call from subclass show_popup() to set common state."""
	_popup_type = popup_type
	var node: DungeonNodeData = data.get("node")
	_node_id = node.id if node else -1
	show()

func _on_close():
	"""Close and emit result. Subclass overrides _build_result()."""
	var result = _build_result()
	result["type"] = _popup_type
	result["node_id"] = _node_id
	hide()
	popup_closed.emit(result)
