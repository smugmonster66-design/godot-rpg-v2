extends Resource
class_name DungeonShrine

@export var shrine_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Blessing")
@export var blessing_affix: Affix = null

@export_group("Curse (Optional)")
@export var curse_affix: Affix = null
@export_multiline var curse_description: String = ""

func has_curse() -> bool:
	return curse_affix != null
