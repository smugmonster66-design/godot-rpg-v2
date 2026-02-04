# res://scripts/resources/skill_prerequisite.gd
# Pairs a skill with its required rank for prerequisites
extends Resource
class_name SkillPrerequisite

# ============================================================================
# PREREQUISITE DATA
# ============================================================================
@export var required_skill: SkillResource = null
@export_range(1, 5) var required_rank: int = 1

# ============================================================================
# VALIDATION
# ============================================================================

func is_valid() -> bool:
	"""Check if this prerequisite is properly configured"""
	return required_skill != null and required_rank >= 1

func get_display_text() -> String:
	"""Get human-readable text for this prerequisite"""
	if not required_skill:
		return "Invalid prerequisite"
	
	if required_rank > 1:
		return "%s (Rank %d)" % [required_skill.skill_name, required_rank]
	else:
		return required_skill.skill_name

func _to_string() -> String:
	if required_skill:
		return "Prereq<%s r%d>" % [required_skill.skill_name, required_rank]
	return "Prereq<null>"
