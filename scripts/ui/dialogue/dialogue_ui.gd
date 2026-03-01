# res://scripts/ui/dialogue/dialogue_ui.gd
# Main dialogue UI controller. Lives on a CanvasLayer above all game content.
# Busts are anchored to the bubble, not the screen.
# THEME: Uses ThemeManager.PALETTE for all colors.
extends Control
class_name DialogueUI

# ============================================================================
# CONFIGURATION
# ============================================================================
@export_group("Text")
@export var default_text_speed: float = 35.0
@export var click_to_skip_text: bool = true

@export_group("Busts")
@export var bust_tween_duration: float = 0.2

@export_group("Choices")
@export var choice_stagger_delay: float = 0.08
## Distance from center for each choice slot (index 0 = choice 1, etc.)
@export var choice_distances: Array[float] = [180.0, 180.0, 180.0, 180.0, 180.0, 180.0]
## Angle in degrees for each choice slot (0 = right, -90 = up, 180 = left)
@export var choice_angles: Array[float] = [-135.0, -90.0, -45.0, -150.0, -30.0, -90.0]

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var dialogue_container: Control = $DialogueContainer
@onready var bust_container: Control = $DialogueContainer/BustContainer
@onready var left_bust: TextureRect = $DialogueContainer/BustContainer/LeftBust
@onready var center_bust: TextureRect = $DialogueContainer/BustContainer/CenterBust
@onready var right_bust: TextureRect = $DialogueContainer/BustContainer/RightBust
@onready var main_bubble: PanelContainer = $DialogueContainer/MainBubble
@onready var bubble_tail: TextureRect = $DialogueContainer/MainBubble.get_node_or_null("BubbleTail")
@onready var name_label: RichTextLabel = $DialogueContainer/MainBubble/ContentMargin/VBox/NameLabel
@onready var dialogue_text: RichTextLabel = $DialogueContainer/MainBubble/ContentMargin/VBox/DialogueText
@onready var continue_indicator: Control = $DialogueContainer/MainBubble/ContinueIndicator
@onready var choice_ring: Control = $ChoiceRing
@onready var click_catcher: Control = $ClickCatcher

# ============================================================================
# STATE
# ============================================================================
var _current_encounter: DialogueEncounter = null
var _current_line: DialogueLine = null
var _current_speaker: DialogueSpeaker = null
var _text_revealing: bool = false
var _choices_visible: bool = false
var _typewriter_tween: Tween = null
var _bust_slots: Dictionary = {"left": &"", "center": &"", "right": &""}
var _choice_bubbles: Array[ChoiceBubble] = []
const MAX_CHOICES = 6
var _choice_bubble_scene: PackedScene = null

# ============================================================================
# THEME COLOR HELPERS
# ============================================================================

func _get_inactive_bust_color() -> Color:
	return ThemeManager.PALETTE.text_muted

func _get_active_bust_color() -> Color:
	return ThemeManager.PALETTE.text_primary

func _get_dim_overlay_color(intensity: float) -> Color:
	var base = ThemeManager.PALETTE.bg_darkest
	return Color(base.r, base.g, base.b, intensity)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_choice_bubble_scene = load("res://scenes/ui/dialogue/choice_bubble.tscn")
	_create_choice_bubble_pool()
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_displayed.connect(_on_line_displayed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
	click_catcher.gui_input.connect(_on_click_catcher_input)
	
	_hide_all_busts()
	_hide_all_choices()
	
	if continue_indicator:
		continue_indicator.visible = false

func _create_choice_bubble_pool():
	if not _choice_bubble_scene:
		push_warning("DialogueUI: choice_bubble.tscn not found")
		return
	
	for i in MAX_CHOICES:
		var bubble = _choice_bubble_scene.instantiate() as ChoiceBubble
		bubble.visible = false
		choice_ring.add_child(bubble)
		bubble.choice_pressed.connect(_on_choice_bubble_pressed)
		_choice_bubbles.append(bubble)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_dialogue_started(encounter: DialogueEncounter) -> void:
	_current_encounter = encounter
	
	if encounter.show_dim_overlay:
		dim_overlay.color = _get_dim_overlay_color(encounter.dim_intensity)
		dim_overlay.visible = true
	else:
		dim_overlay.visible = false
	
	_bust_slots = {"left": &"", "center": &"", "right": &""}
	_hide_all_busts()
	
	if encounter.initial_left_bust != &"":
		_set_bust_slot("left", encounter.initial_left_bust)
	if encounter.initial_center_bust != &"":
		_set_bust_slot("center", encounter.initial_center_bust)
	if encounter.initial_right_bust != &"":
		_set_bust_slot("right", encounter.initial_right_bust)
	
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_line_displayed(line: DialogueLine, speaker: DialogueSpeaker) -> void:
	_current_line = line
	_current_speaker = speaker
	_choices_visible = false
	_hide_all_choices()
	
	_process_bust_changes(line)
	_update_speaker_name(line, speaker)
	_update_bust_highlights(line.speaker_id)
	_orient_bubble_tail(line.speaker_id)
	_reveal_text(line.get_text(), line.text_speed_override)
	
	if continue_indicator:
		continue_indicator.visible = false

func _on_choices_presented(choices: Array[DialogueChoice]) -> void:
	_choices_visible = true
	if continue_indicator:
		continue_indicator.visible = false
	# Disable click_catcher so choices can receive input
	click_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ensure choice_ring passes mouse events to children
	choice_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrange_and_show_choices(choices)

func _on_dialogue_ended() -> void:
	_current_encounter = null
	_current_line = null
	_current_speaker = null
	
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_callback(func():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hide_all_busts()
		_hide_all_choices()
	)

# ============================================================================
# TEXT REVEAL
# ============================================================================

func _reveal_text(bbcode_text: String, speed_override: float = 0.0) -> void:
	_text_revealing = true
	dialogue_text.text = bbcode_text
	dialogue_text.visible_ratio = 0.0
	
	var speed = speed_override if speed_override > 0 else default_text_speed
	var char_count = dialogue_text.get_total_character_count()
	if char_count == 0:
		_on_text_reveal_complete()
		return
	
	var duration = float(char_count) / speed
	
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	_typewriter_tween.finished.connect(_on_text_reveal_complete, CONNECT_ONE_SHOT)

func _skip_text_reveal() -> void:
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	dialogue_text.visible_ratio = 1.0
	_on_text_reveal_complete()

func _on_text_reveal_complete() -> void:
	_text_revealing = false
	if _current_line and not _current_line.has_choices():
		if continue_indicator:
			continue_indicator.visible = true
	DialogueManager.notify_text_finished()

# ============================================================================
# INPUT
# ============================================================================

func _on_click_catcher_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Don't consume input when choices are visible - let bubbles handle it
	if _choices_visible:
		return
	
	if _text_revealing and click_to_skip_text:
		_skip_text_reveal()
		accept_event()
	elif not _text_revealing:
		DialogueManager.advance()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not DialogueManager.is_active:
		return
	if event.is_action_pressed("ui_cancel"):
		DialogueManager.skip_dialogue()
		get_viewport().set_input_as_handled()

# ============================================================================
# BUST MANAGEMENT
# ============================================================================

func _process_bust_changes(line: DialogueLine) -> void:
	if line.clear_left: _clear_bust_slot("left")
	if line.clear_center: _clear_bust_slot("center")
	if line.clear_right: _clear_bust_slot("right")
	if line.set_left_bust != &"": _set_bust_slot("left", line.set_left_bust, line.mood)
	if line.set_center_bust != &"": _set_bust_slot("center", line.set_center_bust, line.mood)
	if line.set_right_bust != &"": _set_bust_slot("right", line.set_right_bust, line.mood)

func _set_bust_slot(slot_name: String, speaker_id: StringName, mood: StringName = &"") -> void:
	var bust_node = _get_bust_node(slot_name)
	if not bust_node:
		return
	
	var speaker = DialogueManager.get_speaker(speaker_id)
	if not speaker:
		push_warning("DialogueUI: Speaker '%s' not found" % speaker_id)
		return
	
	_bust_slots[slot_name] = speaker_id
	
	var texture = speaker.get_bust(str(mood))
	if texture:
		bust_node.texture = texture
		bust_node.visible = true
		bust_node.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(bust_node, "modulate", _get_inactive_bust_color(), bust_tween_duration)
	else:
		bust_node.visible = false

func _clear_bust_slot(slot_name: String) -> void:
	var bust_node = _get_bust_node(slot_name)
	if not bust_node or not bust_node.visible:
		return
	
	_bust_slots[slot_name] = &""
	
	var tween = create_tween()
	tween.tween_property(bust_node, "modulate", Color(1, 1, 1, 0), bust_tween_duration)
	tween.tween_callback(func():
		bust_node.visible = false
		bust_node.texture = null
	)

func _update_bust_highlights(active_speaker_id: StringName) -> void:
	for slot_name in ["left", "center", "right"]:
		var bust_node = _get_bust_node(slot_name)
		if not bust_node or not bust_node.visible:
			continue
		var is_active = (_bust_slots[slot_name] == active_speaker_id)
		var target_color = _get_active_bust_color() if is_active else _get_inactive_bust_color()
		create_tween().tween_property(bust_node, "modulate", target_color, bust_tween_duration)

func _hide_all_busts() -> void:
	for node in [left_bust, center_bust, right_bust]:
		if node:
			node.visible = false
			node.texture = null
	_bust_slots = {"left": &"", "center": &"", "right": &""}

func _get_bust_node(slot_name: String) -> TextureRect:
	match slot_name:
		"left": return left_bust
		"center": return center_bust
		"right": return right_bust
	return null

func _update_speaker_name(line: DialogueLine, speaker: DialogueSpeaker) -> void:
	if not name_label:
		return
	
	if line.is_narration():
		name_label.text = ""
		name_label.visible = false
	elif speaker:
		var color_hex = speaker.name_color.to_html(false)
		name_label.text = "[color=#%s]%s[/color]" % [color_hex, speaker.get_display_name()]
		name_label.visible = true
	elif line.speaker_id == &"player":
		var player_color = ThemeManager.PALETTE.info
		name_label.text = "[color=#%s]You[/color]" % player_color.to_html(false)
		name_label.visible = true
	else:
		name_label.text = str(line.speaker_id)
		name_label.visible = true

func _orient_bubble_tail(speaker_id: StringName) -> void:
	if not bubble_tail or not main_bubble:
		return
	
	var target_slot: String = ""
	for slot_name in ["left", "center", "right"]:
		if _bust_slots[slot_name] == speaker_id:
			target_slot = slot_name
			break
	
	if target_slot == "":
		bubble_tail.rotation = 0
		bubble_tail.position.x = main_bubble.size.x / 2 - bubble_tail.size.x / 2
		return
	
	var bust_node = _get_bust_node(target_slot)
	if not bust_node:
		return
	
	# Point tail toward the bust (which is above the bubble)
	var bust_center_x = bust_node.position.x + bust_node.size.x / 2
	var bubble_center_x = main_bubble.size.x / 2
	var offset_x = bust_center_x - bubble_center_x
	
	bubble_tail.position.x = (main_bubble.size.x / 2) + (offset_x * 0.3) - (bubble_tail.size.x / 2)
	bubble_tail.rotation = 0  # Tail points up

# ============================================================================
# CHOICE RING
# ============================================================================

func _arrange_and_show_choices(choices: Array[DialogueChoice]) -> void:
	var count = mini(choices.size(), MAX_CHOICES)
	var portrait_center = _get_portrait_center()
	choice_ring.global_position = portrait_center
	
	for i in count:
		var bubble = _choice_bubbles[i]
		var choice = choices[i]
		
		# Get distance and angle for this slot from arrays
		var distance = choice_distances[i] if i < choice_distances.size() else 180.0
		var angle_deg = choice_angles[i] if i < choice_angles.size() else -90.0
		
		var angle_rad = deg_to_rad(angle_deg)
		var pos = Vector2(cos(angle_rad), sin(angle_rad)) * distance
		bubble.position = pos - bubble.size / 2
		bubble.setup(i, choice, angle_rad + PI)
		bubble.appear(i * choice_stagger_delay)
	
	for i in range(count, _choice_bubbles.size()):
		_choice_bubbles[i].visible = false

func _hide_all_choices() -> void:
	for bubble in _choice_bubbles:
		bubble.visible = false
	_choices_visible = false
	# Re-enable click_catcher
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_choice_bubble_pressed(index: int) -> void:
	for bubble in _choice_bubbles:
		if bubble.visible:
			bubble.disappear()
	_choices_visible = false
	# Re-enable click_catcher
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	DialogueManager.select_choice(index)

func _get_portrait_center() -> Vector2:
	# Try to get portrait position from bottom UI
	if GameManager and GameManager.game_root:
		var bottom_ui = GameManager.game_root.get_node_or_null("PersistentUILayer/BottomUIPanel")
		if bottom_ui and bottom_ui.has_node("PortraitContainer"):
			var portrait = bottom_ui.get_node("PortraitContainer")
			return portrait.global_position + portrait.size / 2
	# Fallback position
	var vp = get_viewport_rect().size
	return Vector2(200, vp.y - 200)
