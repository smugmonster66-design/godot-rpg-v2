# res://scripts/dungeon/popups/dungeon_event_popup.gd
extends DungeonPopupBase

var _event: DungeonEvent = null
var _chosen: DungeonEventChoice = null
var _succeeded: bool = true

# Node refs — editor-placed
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var desc_label: RichTextLabel = $CenterContainer/Panel/VBox/DescriptionLabel
@onready var choices_container: VBoxContainer = $CenterContainer/Panel/VBox/ChoicesContainer
@onready var result_section: VBoxContainer = $CenterContainer/Panel/VBox/ResultSection
@onready var result_label: RichTextLabel = $CenterContainer/Panel/VBox/ResultSection/ResultLabel

func _ready():
	super._ready()
	if result_section: result_section.hide()

func show_popup(data: Dictionary) -> void:
	_base_show(data, "event")
	_event = data.get("event") as DungeonEvent
	_chosen = null

	if title_label: title_label.text = _event.event_name
	if desc_label: desc_label.text = _event.description

	# Clear and rebuild choice buttons (the only code-spawned elements,
	# because choice count is dynamic and unknowable at editor time)
	for child in choices_container.get_children():
		child.queue_free()

	for i in _event.choices.size():
		var choice = _event.choices[i]
		var btn = Button.new()
		btn.text = choice.get_display_text()
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)

	if result_section: result_section.hide()

func _on_choice_pressed(index: int):
	_chosen = _event.choices[index]
	_succeeded = _chosen.roll_success()

	# Hide choice buttons, show result
	for child in choices_container.get_children():
		child.queue_free()

	if result_label:
		result_label.text = _chosen.result_text if _succeeded else _chosen.fail_text
	if result_section: result_section.show()

func _build_result() -> Dictionary:
	return {"choice": _chosen, "succeeded": _succeeded}
