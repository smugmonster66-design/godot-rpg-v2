# res://scripts/ui/combat/status_effect_icon.gd
# Individual status effect icon with stack count overlay.
# Tap to request a tooltip popup.
extends Control
class_name StatusEffectIcon

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when the icon is tapped. Receiver should show a tooltip.
signal tooltip_requested(status_data: Dictionary, icon_global_pos: Vector2)

# ============================================================================
# CONSTANTS
# ============================================================================

const ICON_SIZE := Vector2(64, 64)

# ============================================================================
# STATE
# ============================================================================

## The full StatusTracker instance dict (has status_affix, current_stacks, etc.)
var status_instance: Dictionary = {}
var status_id: String = ""

# ============================================================================
# NODE REFERENCES (created in code)
# ============================================================================

var icon_rect: TextureRect = null
var stack_label: Label = null
var debuff_border: Panel = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# --- Icon ---
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = ICON_SIZE
	icon_rect.size = ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)

	## Border tint applied directly to the icon rect
	#var border_style = StyleBoxFlat.new()
	#border_style.bg_color = Color.TRANSPARENT
	#border_style.set_border_width_all(1)
	#border_style.set_corner_radius_all(3)
	#border_style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	#icon_rect.add_theme_stylebox_override("panel", border_style)

	# --- Stack count label (bottom-right corner) ---
	stack_label = Label.new()
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	stack_label.add_theme_constant_override("shadow_offset_x", 1)
	stack_label.add_theme_constant_override("shadow_offset_y", 1)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stack_label)

	# Apply initial data if set before _ready
	if not status_instance.is_empty():
		_apply_visuals()

# ============================================================================
# PUBLIC API
# ============================================================================

func setup(instance: Dictionary) -> void:
	"""Initialize with a StatusTracker instance dictionary."""
	status_instance = instance
	var affix: StatusAffix = instance.get("status_affix")
	if affix:
		status_id = affix.status_id
	if is_inside_tree():
		_apply_visuals()

func update_stacks(instance: Dictionary) -> void:
	"""Update when stacks change."""
	status_instance = instance
	if not is_inside_tree():
		return
	var stacks: int = instance.get("current_stacks", 0)
	if stack_label:
		stack_label.text = str(stacks) if stacks > 1 else ""

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tooltip_requested.emit(status_instance, global_position)
		accept_event()

# ============================================================================
# INTERNALS
# ============================================================================

func _apply_visuals():
	var affix: StatusAffix = status_instance.get("status_affix")
	if not affix:
		return

	# Icon
	if icon_rect:
		if affix.icon:
			icon_rect.texture = affix.icon
		else:
			# Colored placeholder
			icon_rect.modulate = _fallback_color(affix)
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			icon_rect.texture = ImageTexture.create_from_image(img)

	# Stack count
	var stacks: int = status_instance.get("current_stacks", 0)
	if stack_label:
		stack_label.text = str(stacks) if stacks > 1 else ""

	# Border color: red for debuffs, green for buffs
	if debuff_border:
		var style: StyleBoxFlat = debuff_border.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if affix.is_debuff:
				style.border_color = Color(0.8, 0.2, 0.2, 0.8)
			else:
				style.border_color = Color(0.2, 0.7, 0.3, 0.8)

func _fallback_color(affix: StatusAffix) -> Color:
	"""Fallback tint when no icon texture is available."""
	if affix.is_debuff:
		return Color(0.9, 0.3, 0.2)
	return Color(0.3, 0.8, 0.4)
