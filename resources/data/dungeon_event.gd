extends Resource
class_name DungeonEvent

@export var event_name: String = ""
@export var event_id: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Floor Restrictions")
@export var min_floor: int = 0
@export var max_floor: int = 99

@export_group("Choices")
@export var choices: Array[DungeonEventChoice] = []

func is_valid_for_floor(floor_num: int) -> bool:
	return floor_num >= min_floor and floor_num <= max_floor
