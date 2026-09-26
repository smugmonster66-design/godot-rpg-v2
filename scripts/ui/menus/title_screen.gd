# res://scripts/ui/menus/title_screen.gd
# Title flow shown at boot: splash ("Tap to Begin") -> main menu (New Game /
# Continue / Options) -> character creation (placeholder until it's designed).
# Builds its own UI in code, so the .tscn is a single root Control.
# GameRoot listens for new_game_confirmed and continue_requested.
extends Control
class_name TitleScreen

signal new_game_confirmed
signal continue_requested

const GAME_TITLE := "Roll The Bones"

enum Step { SPLASH, MENU, OPTIONS, CONFIRM_NEW, CHARACTER }

var _step: Step = Step.SPLASH
var _pages: Dictionary = {}          # Step -> Control
var _continue_button: Button = null
var _tap_label: Label = null
var _tap_tween: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_step(Step.SPLASH)


# ============================================================================
# BUILD
# ============================================================================

func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_pages[Step.SPLASH] = _build_splash()
	_pages[Step.MENU] = _build_menu()
	_pages[Step.OPTIONS] = _build_message_page(
		"OptionsPage", "Options", "Options are coming soon.", "Back", func(): _show_step(Step.MENU))
	_pages[Step.CONFIRM_NEW] = _build_confirm_new()
	_pages[Step.CHARACTER] = _build_message_page(
		"CharacterPage", "Character Creation",
		"Character creation is coming soon.\nFor now you'll begin as the default class.",
		"Begin", func(): new_game_confirmed.emit())


func _page(page_name: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.name = page_name
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.name = page_name + "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	box.custom_minimum_size = Vector2(640, 0)
	center.add_child(box)
	return box


func _title_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label


func _menu_button(button_name: String, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 120)
	button.add_theme_font_size_override("font_size", 44)
	button.pressed.connect(on_press)
	return button


func _build_splash() -> Control:
	var box := _page("SplashPage")
	box.add_child(_title_label(GAME_TITLE, 96))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 240)
	box.add_child(spacer)
	_tap_label = _title_label("Tap to Begin", 48)
	_tap_label.name = "TapLabel"
	box.add_child(_tap_label)
	return box.get_parent()


func _build_menu() -> Control:
	var box := _page("MenuPage")
	box.add_child(_title_label(GAME_TITLE, 80))
	box.add_child(_menu_button("NewGameButton", "New Game", _on_new_game_pressed))
	_continue_button = _menu_button("ContinueButton", "Continue", func(): continue_requested.emit())
	box.add_child(_continue_button)
	box.add_child(_menu_button("OptionsButton", "Options", func(): _show_step(Step.OPTIONS)))
	return box.get_parent()


func _build_confirm_new() -> Control:
	var box := _page("ConfirmNewPage")
	box.add_child(_title_label("Start a new game?", 56))
	box.add_child(_title_label("Your saved game will be replaced the first time the new game saves.", 36))
	box.add_child(_menu_button("ConfirmNewYes", "Start New Game", func(): _show_step(Step.CHARACTER)))
	box.add_child(_menu_button("ConfirmNewNo", "Back", func(): _show_step(Step.MENU)))
	return box.get_parent()


func _build_message_page(page_name: String, heading: String, body: String,
		button_text: String, on_press: Callable) -> Control:
	var box := _page(page_name)
	box.add_child(_title_label(heading, 64))
	box.add_child(_title_label(body, 40))
	box.add_child(_menu_button(page_name + "Button", button_text, on_press))
	return box.get_parent()


# ============================================================================
# FLOW
# ============================================================================

func _show_step(step: Step) -> void:
	_step = step
	for key in _pages:
		(_pages[key] as Control).visible = (key == step)
	if step == Step.MENU and _continue_button:
		_continue_button.disabled = not GameState.has_save()
	if step == Step.SPLASH:
		_start_tap_pulse()
	elif _tap_tween:
		_tap_tween.kill()
		_tap_tween = null


func _start_tap_pulse() -> void:
	if not _tap_label:
		return
	if _tap_tween:
		_tap_tween.kill()
	_tap_tween = create_tween().set_loops()
	_tap_tween.tween_property(_tap_label, "modulate:a", 0.25, 0.9)
	_tap_tween.tween_property(_tap_label, "modulate:a", 1.0, 0.9)


func _gui_input(event: InputEvent) -> void:
	if _step != Step.SPLASH:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		_show_step(Step.MENU)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard / controller: any key on the splash counts as a tap.
	if _step == Step.SPLASH and visible and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		_show_step(Step.MENU)


func _on_new_game_pressed() -> void:
	if GameState.has_save():
		_show_step(Step.CONFIRM_NEW)
	else:
		_show_step(Step.CHARACTER)
