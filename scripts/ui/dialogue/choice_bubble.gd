# res://scripts/ui/dialogue/choice_bubble.gd
# A single choice speech bubble.
# THEME: Uses ThemeManager.PALETTE for colors.
extends Control
class_name ChoiceBubble

signal choice_pressed(index: int)

@onready var bubble_panel: PanelContainer = $BubblePanel
@onready var tail: TextureRect = $BubblePanel/Tail
@onready var label: Label = $BubblePanel/MarginContainer/Label
@onready var icon_rect: TextureRect = $BubblePanel/MarginContainer/HBox/Icon
@onready var lock_icon: TextureRect = $BubblePanel/MarginContainer/HBox/LockIcon

var choice_index: int = -1
var choice_data: DialogueChoice = null
var _is_hovered: bool = false
var _is_locked: bool = false

@export_group("Animation")
@export var hover_scale: float = 1.08
@export var appear_duration: float = 0.25
@export var hover_tween_duration: float = 0.12

func setup(index: int, choice: DialogueChoice, angle_to_portrait: float) -> void:
	choice_index = index
	choice_data = choice
	_is_locked = not choice.is_available()
	
	if label:
		label.text = choice.get_label()
	
	# Icon
	if icon_rect:
		if choice.icon and not _is_locked:
			icon_rect.texture = choice.icon
			icon_rect.visible = true
		else:
			icon_rect.visible = false
	
	# Lock icon for locked choices
	if lock_icon:
		lock_icon.visible = _is_locked
	
	# Styling
	if bubble_panel:
		if _is_locked:
			bubble_panel.modulate = ThemeManager.PALETTE.text_muted
			if label:
				label.modulate = ThemeManager.PALETTE.text_muted
		elif choice.bubble_color_override != Color.TRANSPARENT:
			bubble_panel.modulate = choice.bubble_color_override
		else:
			bubble_panel.modulate = Color.WHITE
	
	# Tooltip for locked choices
	if _is_locked and choice.get_locked_hint() != "":
		tooltip_text = choice.get_locked_hint()
	else:
		tooltip_text = ""
	
	_orient_tail(angle_to_portrait)

func _orient_tail(angle: float) -> void:
	if tail:
		tail.rotation = angle + PI / 2.0
		var bubble_size = bubble_panel.size if bubble_panel else Vector2(200, 60)
		var tail_offset = Vector2(cos(angle), sin(angle)) * (bubble_size.y * 0.4)
		tail.position = bubble_size / 2.0 + tail_offset

func appear(delay: float = 0.0) -> void:
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.3, 0.3)
	visible = true
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, appear_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
	tween.tween_property(self, "modulate", Color.WHITE, appear_duration * 0.7)\
		.set_ease(Tween.EASE_OUT).set_delay(delay)

func disappear() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.1)
	tween.chain().tween_callback(func(): visible = false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not _is_locked:
				_on_pressed()
			accept_event()

func _on_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05)
	tween.tween_callback(func(): choice_pressed.emit(choice_index))

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_is_hovered = true
			_update_hover()
		NOTIFICATION_MOUSE_EXIT:
			_is_hovered = false
			_update_hover()

func _update_hover() -> void:
	if _is_locked:
		return  # No hover effect on locked choices
	
	var target_scale = Vector2(hover_scale, hover_scale) if _is_hovered else Vector2.ONE
	var hover_color = ThemeManager.PALETTE.text_primary if _is_hovered else Color.WHITE
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", target_scale, hover_tween_duration).set_ease(Tween.EASE_OUT)
	if bubble_panel and choice_data and choice_data.bubble_color_override == Color.TRANSPARENT:
		tween.tween_property(bubble_panel, "modulate", hover_color, hover_tween_duration)
