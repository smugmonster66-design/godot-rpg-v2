# res://resources/data/story_flags.gd
# Explicitly typed story flags. Add new flags as properties here.
# This gives you autocomplete, type safety, and a clear schema.
extends Resource
class_name StoryFlags

signal flag_changed(flag_name: StringName, new_value: bool)

# ============================================================================
# STORY PROGRESSION - Main questline beats
# ============================================================================
@export_group("Main Story")
@export var prologue_complete: bool = false
@export var met_cate: bool = false
@export var learned_about_sanctum: bool = false
@export var reached_first_town: bool = false

# ============================================================================
# NPC INTERACTIONS - First meetings, important conversations
# ============================================================================
@export_group("NPCs Met")
@export var met_merchant_hilda: bool = false
@export var met_guard_marcus: bool = false
@export var met_mysterious_stranger: bool = false

# ============================================================================
# WORLD STATE - Persistent changes to the world
# ============================================================================
@export_group("World State")
@export var bridge_repaired: bool = false
@export var lighthouse_lit: bool = false
@export var secret_passage_discovered: bool = false

# ============================================================================
# BOSSES DEFEATED
# ============================================================================
@export_group("Bosses")
@export var boss_tutorial_defeated: bool = false
@export var boss_act1_defeated: bool = false

# ============================================================================
# TUTORIALS & SYSTEMS
# ============================================================================
@export_group("Tutorials")
@export var tutorial_combat_complete: bool = false
@export var tutorial_dice_complete: bool = false
@export var tutorial_skills_complete: bool = false

# ============================================================================
# API
# ============================================================================

func set_flag(flag_name: StringName, value: bool) -> bool:
	"""Set a flag by name. Returns true if flag exists."""
	var prop_list = get_property_list()
	for prop in prop_list:
		if prop.name == flag_name and prop.type == TYPE_BOOL:
			var old_value = get(flag_name)
			if old_value != value:
				set(flag_name, value)
				flag_changed.emit(flag_name, value)
			return true
	push_warning("StoryFlags: Unknown flag '%s'" % flag_name)
	return false

func get_flag(flag_name: StringName) -> bool:
	"""Get a flag by name. Returns false if flag doesn't exist."""
	if flag_name in self:
		return get(flag_name)
	push_warning("StoryFlags: Unknown flag '%s'" % flag_name)
	return false

func get_all_flags() -> Dictionary:
	"""Get all flags as a dictionary. Useful for debugging/saving."""
	var result := {}
	for prop in get_property_list():
		if prop.type == TYPE_BOOL and prop.usage & PROPERTY_USAGE_STORAGE:
			result[prop.name] = get(prop.name)
	return result

func get_flag_names() -> Array[StringName]:
	"""Get list of all flag names. Useful for editor tooling."""
	var result: Array[StringName] = []
	for prop in get_property_list():
		if prop.type == TYPE_BOOL and prop.usage & PROPERTY_USAGE_STORAGE:
			result.append(StringName(prop.name))
	return result
