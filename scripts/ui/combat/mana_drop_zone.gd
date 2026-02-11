# res://scripts/ui/combat/mana_drop_zone.gd
# Invisible drop target for mana dice. 180 px tall, full viewport width,
# vertically centred on the player's dice hand (DicePoolDisplay).
#
# Created by CombatManager during combat init, destroyed on combat end.
# Shown only while mana dragging is enabled (ACTION phase).
#
# Drop logic:
#   1. _can_drop_data validates the drag payload
#   2. _drop_data calls selector.pull_and_create_die() (spends mana)
#   3. Converts global drop X → DicePoolDisplay-local X for index calc
#   4. Inserts into PlayerDiceCollection.insert_into_hand()
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
var dice_pool: PlayerDiceCollection = null

# ============================================================================
# INTERNAL
# ============================================================================

var _hover_bg: ColorRect = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	name = "ManaDropZone"
	mouse_filter = Control.MOUSE_FILTER_STOP
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

	# Subtle highlight when a valid mana die hovers over the zone
	_hover_bg = ColorRect.new()
	_hover_bg.name = "HoverBG"
	_hover_bg.color = Color(0.3, 0.5, 1.0, 0.08)
	_hover_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_bg.visible = false
	add_child(_hover_bg)
	
	# Slow pulse animation
	_start_hover_pulse()

func _start_hover_pulse():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_hover_bg, "modulate:a", 0.3, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_hover_bg, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func initialize(p_display: DicePoolDisplay, p_pool: PlayerDiceCollection):
	"""Wire up references. Call once after creation."""
	dice_display = p_display
	dice_pool = p_pool
	print("🎯 ManaDropZone initialized (display=%s, pool=%s)" % [
		dice_display != null, dice_pool != null])

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

# ============================================================================
# DROP HANDLING
# ============================================================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("type") != "mana_die":
		return false
	# Verify the mana pool can still afford the pull
	var pool = data.get("mana_pool") as ManaPool
	if pool and not pool.can_pull():
		return false
	# Show hover highlight
	if _hover_bg:
		_hover_bg.visible = true
	return true

func _drop_data(_pos: Vector2, data: Variant):
	if _hover_bg:
		_hover_bg.visible = false

	if not data is Dictionary or data.get("type") != "mana_die":
		return

	var selector = data.get("selector") as ManaDieSelector
	if not selector:
		return

	# Pull the die (spends mana, creates DieResource)
	var new_die: DieResource = selector.pull_and_create_die()
	if not new_die:
		print("🎯 ManaDropZone: Pull failed on drop")
		return

	# Convert global mouse X → DicePoolDisplay local for insertion index
	var insert_idx: int = _calculate_insert_index()

	# Insert into the hand data — hand_changed triggers DicePoolDisplay.refresh()
	if dice_pool:
		dice_pool.insert_into_hand(insert_idx, new_die)

	print("🎯 ManaDropZone: %s inserted at index %d" % [new_die.display_name, insert_idx])
	selector.mana_die_created.emit(new_die, insert_idx)

func _calculate_insert_index() -> int:
	"""Map the current mouse X to a hand slot by comparing against
	the midpoints of existing die visuals in DicePoolDisplay."""
	if not dice_display or dice_display.die_visuals.is_empty():
		return 0

	# Get mouse position in dice_display's local coordinate space
	var local_pos: Vector2 = dice_display.get_local_mouse_position()

	for i in range(dice_display.die_visuals.size()):
		var visual = dice_display.die_visuals[i]
		if not is_instance_valid(visual):
			continue
		var mid_x: float = visual.position.x + visual.size.x / 2.0
		if local_pos.x < mid_x:
			return i

	return dice_display.die_visuals.size()

# ============================================================================
# DRAG END CLEANUP
# ============================================================================

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		if _hover_bg:
			_hover_bg.visible = false
