# res://resources/data/npc_definition.gd
# Defines an NPC: identity, home location, portrait, and dialogue table.
# Place .tres files in resources/npcs/{region}/.
@tool
extends Resource
class_name NPCDefinition

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique identifier (e.g. &"blacksmith_haven"). Must match the .tres filename.
@export var npc_id: StringName = &""
## Display name shown in menus and dialogue.
@export var display_name: String = ""
## Portrait texture used in the radial menu button and dialogue UI.
@export var portrait: Texture2D = null
## The DialogueSpeaker resource for this NPC (bust textures, voice, etc.).
@export var speaker: DialogueSpeaker = null

# ============================================================================
# LOCATION
# ============================================================================
@export_group("Location")
## The location_id where this NPC lives. Leave empty for global/scripted NPCs.
## Dropdown is populated from LocationNode .tres files; you can also type custom values.
@export var home_location_id: StringName = &""

# ============================================================================
# AVAILABILITY
# ============================================================================
@export_group("Availability")
## When set, the NPC is only visible/available if the condition is met.
@export var availability_condition: GameCondition = null

# ============================================================================
# DIALOGUE
# ============================================================================
@export_group("Dialogue")
## Dialogue table — evaluated in priority order, first match wins.
@export var dialogue_table: Array[NPCDialogueEntry] = []
## Default icon used for conversation entries that don't have their own icon set.
## Shown in the conversation sub-radial when an NPC has multiple available dialogues.
@export var default_dialogue_icon: Texture2D = null

# ============================================================================
# DYNAMIC INSPECTOR — home_location_id dropdown
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	if property["name"] == "home_location_id":
		var hint_string = _build_location_enum_hint()
		if hint_string != "":
			property["hint"] = PROPERTY_HINT_ENUM_SUGGESTION
			property["hint_string"] = hint_string

func _build_location_enum_hint() -> String:
	if not Engine.is_editor_hint():
		return ""
	var ids: Array[String] = []
	_scan_locations_recursive("res://resources/definitions/locations/", ids)
	_scan_locations_recursive("res://resources/maps/", ids)
	# Deduplicate while preserving order
	var seen: Dictionary = {}
	var unique: Array[String] = []
	for id in ids:
		if id not in seen:
			seen[id] = true
			unique.append(id)
	return ",".join(unique)

func _scan_locations_recursive(path: String, ids: Array[String]) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_locations_recursive(full_path, ids)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is LocationNode and res.location_id != &"":
				ids.append(String(res.location_id))
		file_name = dir.get_next()
	dir.list_dir_end()
