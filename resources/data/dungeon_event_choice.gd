extends Resource
class_name DungeonEventChoice

@export var choice_text: String = ""
@export_multiline var result_text: String = ""

@export_group("Rewards")
@export var heal_amount: int = 0
@export var heal_percent: float = 0.0
@export var gold_reward: int = 0
@export var experience_reward: int = 0
@export var grant_item: EquippableItem = null
@export var grant_temp_affix: DiceAffix = null

@export_group("Risk")
@export_range(0.0, 1.0) var success_chance: float = 1.0
@export_multiline var fail_text: String = ""
@export var fail_heal_amount: int = 0
@export var fail_gold_reward: int = 0

func is_risky() -> bool:
	return success_chance < 1.0

func roll_success() -> bool:
	return success_chance >= 1.0 or randf() <= success_chance

func get_display_text() -> String:
	if is_risky():
		return "%s (%d%%)" % [choice_text, int(success_chance * 100)]
	return choice_text
