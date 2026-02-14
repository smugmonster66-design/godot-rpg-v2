# res://scripts/ui/map/die_slot.gd  
# Slot for displaying dice in the map pool view
# Uses PoolDieObject for visual display
extends PanelContainer
class_name DieSlot

# ============================================================================
# SIGNALS
# ============================================================================
signal die_clicked(slot: DieSlot)
signal die_dropped(from_slot: DieSlot, to_slot: DieSlot)
signal drag_started(slot: DieSlot, die: DieResource)
signal drag_ended(slot: DieSlot)

# ============================================================================
# ENUMS
# ============================================================================
enum DragType {
	REORDER,      # Map mode: drag to reorder within grid
	TO_TARGET,    # Combat mode: drag to external targets (action fields)
}

# ============================================================================
# EXPORTS
# ============================================================================
@export var drag_type: DragType = DragType.REORDER
@export var accepts_drops: bool = true
@export var slot_index: int = 0

@export_group("Display")
## Scale of the die visual inside the slot (base die is 124×124).
## Slot size is derived automatically: 124 * scale + padding.
@export_range(0.1, 1.0, 0.05) var die_display_scale: float = 0.6:
	set(value):
		die_display_scale = value
		_apply_slot_size()
		if is_node_ready():
			update_display()

## Padding in pixels around the die visual inside the slot.
@export var slot_padding: int = 8:
	set(value):
		slot_padding = value
		_apply_slot_size()
		if is_node_ready():
			update_display()

@export_group("Colors")
@export var empty_color: Color = Color(0.08, 0.08, 0.12)       # PALETTE.bg_input
@export var hover_color: Color = Color(0.18, 0.16, 0.26)       # PALETTE.bg_hover
@export var selected_color: Color = Color(0.30, 0.50, 0.80)    # PALETTE.available
@export var drag_target_color: Color = Color(0.30, 0.75, 0.35) # PALETTE.success

# ============================================================================
# CONSTANTS
# ============================================================================
const BASE_DIE_SIZE: float = 124.0

# ============================================================================
# STATE
# ============================================================================
var die: DieResource = null
var current_die_visual: PoolDieObject = null
var is_hovered: bool = false
var is_selected: bool = false
var is_dragging: bool = false
var is_drag_target: bool = false
var _base_style: StyleBox = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_setup_style()
	mouse_filter = MOUSE_FILTER_STOP
	_apply_slot_size()
	update_display()

func _apply_slot_size():
	"""Derive slot minimum size from die_display_scale + padding."""
	var slot_dim = int(BASE_DIE_SIZE * die_display_scale) + slot_padding
	custom_minimum_size = Vector2(slot_dim, slot_dim)

func _setup_style():
	var style = StyleBoxFlat.new()
	style.bg_color = empty_color
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	_base_style = style

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(new_die: DieResource):
	die = new_die
	update_display()

func clear_die():
	die = null
	update_display()

func has_die() -> bool:
	return die != null

func get_die() -> DieResource:
	return die

# ============================================================================
# DISPLAY
# ============================================================================

func update_display():
	_update_background()
	
	if die:
		_show_die()
	else:
		_show_empty()

func _show_die():
	# Remove old visual
	if current_die_visual and is_instance_valid(current_die_visual):
		current_die_visual.queue_free()
		current_die_visual = null
	
	# Create PoolDieObject
	current_die_visual = die.instantiate_pool_visual()
	if current_die_visual:
		current_die_visual.draggable = false  # Slot handles drag
		current_die_visual.set_display_scale(die_display_scale)
		var offset = slot_padding / 2.0
		current_die_visual.position = Vector2(offset, offset)
		add_child(current_die_visual)
		
		# CRITICAL: Override AFTER add_child() because DieObjectBase._ready()
		# sets custom_minimum_size = base_size (124×124), which forces the
		# PanelContainer to expand to fit. Zero it out so the slot respects
		# our _apply_slot_size() dimensions instead.
		current_die_visual.custom_minimum_size = Vector2.ZERO
		current_die_visual.size = Vector2(BASE_DIE_SIZE, BASE_DIE_SIZE)
		current_die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Hide the value label — pool slots show dice visuals only
		var val_label = current_die_visual.find_child("ValueLabel", true, false)
		if val_label:
			val_label.hide()

func _show_empty():
	if current_die_visual and is_instance_valid(current_die_visual):
		current_die_visual.queue_free()
		current_die_visual = null

func _update_background():
	var style = _base_style.duplicate() if _base_style else StyleBoxFlat.new()
	
	if style is StyleBoxFlat:
		if is_drag_target:
			style.bg_color = drag_target_color
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
		elif is_selected:
			style.bg_color = selected_color
		elif die:
			style.bg_color = Color.TRANSPARENT
		elif is_hovered:
			style.bg_color = hover_color
		else:
			style.bg_color = empty_color
	
	add_theme_stylebox_override("panel", style)

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			die_clicked.emit(self)

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovered = true
			_update_background()
		NOTIFICATION_MOUSE_EXIT:
			is_hovered = false
			is_drag_target = false
			_update_background()
		NOTIFICATION_DRAG_END:
			if is_dragging:
				is_dragging = false
				drag_ended.emit(self)
			is_drag_target = false
			update_display()

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not die:
		return null
	if die.is_locked:
		return null
	
	is_dragging = true
	drag_started.emit(self, die)
	
	# Create preview using PoolDieObject
	var preview = die.instantiate_pool_visual()
	if preview:
		preview.modulate = Color(1, 1, 1, 0.8)
		preview.position = -preview.base_size / 2
	else:
		# Fallback
		preview = Label.new()
		preview.text = "D%d" % die.die_type
	
	set_drag_preview(preview)
	
	return {
		"type": "die_slot" if drag_type == DragType.REORDER else "combat_die",
		"slot": self,
		"die": die,
		"from_index": slot_index,
		"source_grid": get_parent(),
		"source_position": global_position,
		"slot_index": slot_index
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not accepts_drops:
		return false
	if not data is Dictionary:
		return false
	if data.get("type") != "die_slot":
		return false
	if data.get("slot") == self:
		return false
	
	is_drag_target = true
	_update_background()
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	if not data is Dictionary:
		return
	
	var from_slot: DieSlot = data.get("slot")
	if from_slot:
		die_dropped.emit(from_slot, self)
	
	is_drag_target = false
	update_display()

# ============================================================================
# SELECTION
# ============================================================================

func set_selected(selected: bool):
	is_selected = selected
	_update_background()

# ============================================================================
# TOOLTIP
# ============================================================================

func _make_custom_tooltip(_for_text: String) -> Object:
	return null  # Use default

func _get_tooltip(_at_position: Vector2) -> String:
	if not die:
		return "Empty slot"
	
	var lines: Array[String] = [die.get_display_name()]
	lines.append("Slot %d" % (slot_index + 1))
	lines.append("Max: %d" % die.get_max_value())
	
	var affixes = die.get_all_affixes()
	if affixes.size() > 0:
		lines.append("")
		lines.append("Affixes:")
		for affix in affixes:
			if affix.has_method("get_formatted_description"):
				lines.append("  • " + affix.get_formatted_description())
	
	return "\n".join(lines)
