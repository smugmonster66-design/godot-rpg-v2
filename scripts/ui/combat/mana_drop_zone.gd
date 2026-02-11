# res://scripts/ui/combat/mana_drop_zone.gd
# Cosmetic overlay for mana dice drops. 180 px tall, full viewport width,
# vertically centred on the player's dice hand (DicePoolDisplay).
# Pulses a subtle highlight to guide the player where to drop.
#
# IMPORTANT: mouse_filter = IGNORE — this node is purely visual.
# Actual drop handling lives in DicePoolDisplay._can_drop_data / _drop_data.
#
# Created by CombatManager during combat init, destroyed on combat end.
# Shown only while mana dragging is enabled (ACTION phase).
extends Control
class_name ManaDropZone

# ============================================================================
# CONFIGURATION
# ============================================================================

const ZONE_HEIGHT: float = 180.0

# ============================================================================
# REFERENCES — set via initialize()
# ============================================================================

var dice_display: DicePoolDisplay = null

# ============================================================================
# INTERNAL
# ============================================================================

var _hover_bg: ColorRect = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	name = "ManaDropZone"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false  # Shown when drag is enabled

	# Clear anchors — CanvasLayer children don't have a layout parent,
	# so anchors fight with manual position/size in _update_geometry()
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# Subtle highlight when mana drag is active
	_hover_bg = ColorRect.new()
	_hover_bg.name = "HoverBG"
	_hover_bg.color = Color(0.3, 0.5, 1.0, 0.08)
	_hover_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_bg)

	# Slow pulse animation
	_start_hover_pulse()

func _start_hover_pulse():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_hover_bg, "modulate:a", 0.3, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_hover_bg, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func initialize(p_display: DicePoolDisplay, _p_pool: PlayerDiceCollection):
	"""Wire up references. Call once after creation."""
	dice_display = p_display
	print("🎯 ManaDropZone initialized (display=%s)" % [dice_display != null])

# ============================================================================
# POSITION TRACKING
# ============================================================================

func _process(_delta: float):
	if not visible:
		return
	_update_geometry()

func _update_geometry():
	"""Reposition to stay centred on the DicePoolDisplay every frame."""
	if not dice_display or not is_instance_valid(dice_display):
		return

	var display_center_y: float = dice_display.global_position.y + dice_display.size.y / 2.0
	var vp_width: float = get_viewport_rect().size.x

	global_position = Vector2(0, display_center_y - ZONE_HEIGHT / 2.0)
	size = Vector2(vp_width, ZONE_HEIGHT)
