# res://scripts/ui/bark_bubble.gd
# Lightweight speech bubble for quick character barks.
# Instantiated by BarkManager, styled via theme to match dialogue bubbles.
# Auto-fades after duration; can be dismissed early via fade_out().
extends PanelContainer
class_name BarkBubble

# ============================================================================
# SIGNALS
# ============================================================================

signal faded_out

# ============================================================================
# EXPORTS
# ============================================================================

@export var default_duration: float = 2.0
@export var fade_in_time: float = 0.2
@export var fade_out_time: float = 0.3

# ============================================================================
# CHILD REFERENCES (set up in _ready or by BarkManager)
# ============================================================================

var _name_label: Label = null
var _text_label: RichTextLabel = null
var _tween: Tween = null
var _anchor_node: Node = null
var _is_fading: bool = false

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Build minimal UI structure
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.theme_type_variation = &"small"
	_name_label.visible = false
	vbox.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(_text_label)

	# Start invisible for fade-in
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)


func show_bark(entry: BarkEntry, anchor: Node, resolved_speaker_id: StringName = &"") -> void:
	"""Display the bark text and animate in."""
	_anchor_node = anchor

	# Set text
	_text_label.text = entry.text

	# Set speaker name if available
	var sid = entry.speaker_id if entry.speaker_id != &"" else resolved_speaker_id
	if sid != &"" and DialogueManager:
		var speaker = DialogueManager.get_speaker(sid)
		if speaker:
			_name_label.text = speaker.display_name
			_name_label.add_theme_color_override("font_color", speaker.name_color)
			_name_label.visible = true

	# Position above anchor
	_update_position()

	# Set pivot for scale animation
	await get_tree().process_frame
	pivot_offset = size / 2

	# Animate in
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_time) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, fade_in_time) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Schedule fade-out
	var duration = entry.duration if entry.duration > 0.0 else default_duration
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and not _is_fading:
		fade_out(fade_out_time)


func fade_out(speed: float = 0.3) -> void:
	"""Fade out and signal completion."""
	if _is_fading:
		return
	_is_fading = true

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, speed) \
		.set_ease(Tween.EASE_IN)
	_tween.finished.connect(_on_fade_complete)


func _on_fade_complete() -> void:
	faded_out.emit()
	queue_free()

# ============================================================================
# POSITIONING
# ============================================================================

func _update_position() -> void:
	if not _anchor_node or not is_instance_valid(_anchor_node):
		return

	var center: Vector2
	if _anchor_node is Control:
		center = _anchor_node.global_position + _anchor_node.size / 2
	elif _anchor_node is Node2D:
		center = _anchor_node.global_position
	else:
		return

	# Position above the anchor
	global_position = center - Vector2(size.x / 2, size.y + 20)
