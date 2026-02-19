# res://scripts/ui/combat/status_tooltip_popup.gd
# Floating tooltip panel for status effects.
# Shows name, description, stacks, and remaining turns.
# Auto-fades after 5 seconds. Only one should be visible at a time.
extends PanelContainer
class_name StatusTooltipPopup

# ============================================================================
# CONSTANTS
# ============================================================================

const FADE_DELAY := 5.0
const FADE_DURATION := 0.4
const MAX_WIDTH := 260.0
const MARGIN := 8

# ============================================================================
# STATE
# ============================================================================

var _fade_tween: Tween = null

# ============================================================================
# NODE REFERENCES (created in code)
# ============================================================================

var vbox: VBoxContainer = null
var name_label: Label = null
var desc_label: RichTextLabel = null
var stats_label: Label = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.5, 0.45, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(MARGIN)
	add_theme_stylebox_override("panel", style)

	# Layout
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Name
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Description
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.custom_minimum_size.x = MAX_WIDTH - MARGIN * 2
	desc_label.add_theme_font_size_override("normal_font_size", 12)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Stats line (stacks / turns)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
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
	var display_name: String = affix.affix_name
	if affix.is_debuff:
		name_label.text = display_name
		name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	else:
		name_label.text = display_name
		name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

	desc_label.text = affix.description if affix.description else "No description."

	# Stats
	var stacks: int = instance.get("current_stacks", 0)
	var turns: int = instance.get("remaining_turns", -1)
	var parts: Array[String] = []
	if stacks > 0:
		parts.append("%d stack%s" % [stacks, "s" if stacks != 1 else ""])
	if turns > 0:
		parts.append("%d turn%s remaining" % [turns, "s" if turns != 1 else ""])
	elif turns == -1:
		# Stack-based or permanent — no turn display
		pass
	stats_label.text = " · ".join(parts) if parts.size() > 0 else ""
	stats_label.visible = parts.size() > 0

	# --- Position ---
	# Wait a frame for size calculation
	await get_tree().process_frame
	_position_near(anchor_pos)

	# --- Auto-fade ---
	_start_fade_timer()

func dismiss() -> void:
	"""Immediately dismiss the tooltip."""
	if _fade_tween:
		_fade_tween.kill()
	queue_free()

# ============================================================================
# INPUT — Tap anywhere on the tooltip to dismiss early
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		dismiss()
		accept_event()

# ============================================================================
# INTERNALS
# ============================================================================

func _position_near(anchor: Vector2):
	"""Position tooltip above the anchor, clamped to viewport."""
	var vp_size := get_viewport_rect().size
	var popup_size := size

	# Default: above and centered on anchor
	var pos := Vector2(
		anchor.x - popup_size.x / 2.0,
		anchor.y - popup_size.y - 8.0
	)

	# Clamp to viewport
	pos.x = clampf(pos.x, 4.0, vp_size.x - popup_size.x - 4.0)
	pos.y = clampf(pos.y, 4.0, vp_size.y - popup_size.y - 4.0)

	# If it would overlap the anchor (not enough room above), put below
	if pos.y + popup_size.y > anchor.y - 4.0 and anchor.y - popup_size.y < 4.0:
		pos.y = anchor.y + 32.0

	global_position = pos

func _start_fade_timer():
	if _fade_tween:
		_fade_tween.kill()

	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_interval(FADE_DELAY)
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(queue_free)
