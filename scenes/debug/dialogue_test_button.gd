extends Button
class_name DialogueTestButton

## The dialogue encounter to play when clicked
@export var test_dialogue: DialogueEncounter

func _ready() -> void:
	pressed.connect(_on_pressed)
	text = "Test Dialogue" if text == "" else text

func _on_pressed() -> void:
	if test_dialogue:
		print("[DialogueTestButton] Starting dialogue: ", test_dialogue.encounter_id)
		DialogueManager.start_dialogue(test_dialogue)
	else:
		push_warning("[DialogueTestButton] No test_dialogue assigned!")
