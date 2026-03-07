# res://scripts/ui/popups/die_drop_zone.gd
# Drop target for the consumable die selection popup.
# Accepts die_slot and combat_die drag types from the pool grid.
# Emits die_dropped when a valid die is dropped.
#
# Uses ItemSlotPanel theme variation for idle/hover states,
# ThemeManager._flat_box() with PALETTE for filled state.
#
# Set accept_filter to a Callable(data: Dictionary) -> bool to gate
# which dice are accepted (e.g., inscription slot checks).
extends PanelContainer
class_name DieDropZone

signal die_dropped(die: DieResource, data: Dictionary)

## External filter callable. Set by the parent popup to gate drops.
## Signature: func(data: Dictionary) -> bool
var accept_filter: Callable = Callable()

var _idle_style: StyleBoxFlat = null
var _hover_style: StyleBoxFlat = null
var _filled_style: StyleBoxFlat = null
var _is_filled: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Pull styles from base_theme.tres ItemSlotPanel variation
	_idle_style = ThemeManager.theme.get_stylebox("panel", "ItemSlotPanel").duplicate()
	_idle_style.set_content_margin_all(12)
	_hover_style = ThemeManager.theme.get_stylebox("panel_hover", "ItemSlotPanel").duplicate()
	_hover_style.set_content_margin_all(12)

	# Filled state: success tint from PALETTE
	_filled_style = ThemeManager._flat_box(
		Color(ThemeManager.PALETTE.success.r, ThemeManager.PALETTE.success.g,
			ThemeManager.PALETTE.success.b, 0.15),
		ThemeManager.PALETTE.success, 6, 2)
	_filled_style.set_content_margin_all(12)

	_apply_idle_style()


func reset():
	"""Reset to empty/idle state."""
	_is_filled = false
	_apply_idle_style()


func set_filled():
	"""Switch to filled visual state."""
	_is_filled = true
	add_theme_stylebox_override("panel", _filled_style)


func _apply_idle_style():
	add_theme_stylebox_override("panel", _idle_style)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_apply_idle_style()
		return false
	var drag_type: String = data.get("type", "")
	if drag_type != "die_slot" and drag_type != "combat_die":
		_apply_idle_style()
		return false
	if not data.get("die", null):
		_apply_idle_style()
		return false
	var accepted: bool = true
	if accept_filter.is_valid():
		accepted = accept_filter.call(data)
	if accepted and not _is_filled:
		add_theme_stylebox_override("panel", _hover_style)
	else:
		_apply_idle_style()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant):
	var die: DieResource = data.get("die", null)
	if die:
		set_filled()
		die_dropped.emit(die, data)


func _notification(what: int):
	match what:
		NOTIFICATION_DRAG_END:
			if not _is_filled:
				_apply_idle_style()
