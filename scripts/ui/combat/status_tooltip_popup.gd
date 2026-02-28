# res://scripts/ui/combat/status_tooltip_popup.gd
# Floating tooltip panel for status effects.
# Shows name, description, stacks, and remaining turns.
# Auto-fades after 3 seconds. Only one should be visible at a time.
extends CanvasLayer  # ← Changed from PanelContainer
class_name StatusTooltipPopup

# ============================================================================
# CONSTANTS
# ============================================================================

const FADE_DELAY := 3.0
const FADE_DURATION := 0.3

# ============================================================================
# STATE
# ============================================================================

var _fade_tween: Tween = null

# ============================================================================
# NODE REFERENCES (created in code)
# ============================================================================

var tooltip_panel: PanelContainer = null
var vbox: VBoxContainer = null
var name_label: Label = null
var desc_label: RichTextLabel = null
var stats_label: Label = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	layer = 100
	
	# Create panel container
	tooltip_panel = PanelContainer.new()
	tooltip_panel.theme_type_variation = "TooltipPanel"
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_panel.gui_input.connect(_on_input)
	add_child(tooltip_panel)

	# Layout - constrain width but let height adapt
	vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 0)
	tooltip_panel.add_child(vbox)

	# Name
	name_label = Label.new()
	name_label.theme_type_variation = "TooltipHeaderLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Description
	desc_label = RichTextLabel.new()
	desc_label.theme_type_variation = "TooltipLabel"
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Stats line
	stats_label = Label.new()
	stats_label.theme_type_variation = "TooltipStatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stats_label)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_for_status(instance: Dictionary, anchor_pos: Vector2) -> void:
	"""Populate and position the tooltip from a StatusTracker instance dict."""
	var affix: StatusAffix = instance.get("status_affix")
	if not affix:
		queue_free()
		return

	# --- Populate ---
	name_label.text = affix.affix_name
	
	# Apply buff/debuff styling
	if affix.is_debuff:
		name_label.theme_type_variation = "TooltipDebuffLabel"
	else:
		name_label.theme_type_variation = "TooltipBuffLabel"

	desc_label.text = affix.description if affix.description else "No description."

	# Stats
	var stacks: int = instance.get("current_stacks", 0)
	var turns: int = instance.get("remaining_turns", -1)
	var parts: Array[String] = []
	if stacks > 0:
		parts.append("%d stack%s" % [stacks, "s" if stacks != 1 else ""])
	if turns > 0:
		parts.append("%d turn%s remaining" % [turns, "s" if turns != 1 else ""])
	stats_label.text = " · ".join(parts) if parts.size() > 0 else ""
	stats_label.visible = parts.size() > 0

	# --- Position (deferred like DieTooltipPopup) ---
	_position_near.call_deferred(anchor_pos)
	
	# --- Auto-fade ---
	_start_fade_timer()

func dismiss() -> void:
	"""Immediately dismiss the tooltip."""
	if _fade_tween:
		_fade_tween.kill()
	queue_free()

# ============================================================================
# INPUT
# ============================================================================

func _on_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		dismiss()

# ============================================================================
# INTERNALS
# ============================================================================

func _position_near(anchor: Vector2):
	"""Position tooltip above the anchor, clamped to viewport."""
	if not tooltip_panel or not is_instance_valid(tooltip_panel):
		return
	
	tooltip_panel.reset_size()
	
	var vp_size := get_viewport().get_visible_rect().size
	var popup_size := tooltip_panel.size

	# Default: centered above anchor
	var pos := Vector2(
		anchor.x - popup_size.x / 2.0,
		anchor.y - popup_size.y - 12.0
	)

	# If above screen, put below instead
	if pos.y < 8.0:
		pos.y = anchor.y + 20.0

	# Clamp
	pos.x = clampf(pos.x, 8.0, vp_size.x - popup_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp_size.y - popup_size.y - 8.0)

	tooltip_panel.position = pos

func _start_fade_timer():
	if _fade_tween:
		_fade_tween.kill()

	if tooltip_panel:
		tooltip_panel.modulate.a = 1.0
		_fade_tween = create_tween()
		_fade_tween.tween_interval(FADE_DELAY)
		_fade_tween.tween_property(tooltip_panel, "modulate:a", 0.0, FADE_DURATION)
		_fade_tween.tween_callback(queue_free)
