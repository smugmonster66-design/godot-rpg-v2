# res://scripts/resources/skill_tree.gd
extends Resource
class_name SkillTree

# ============================================================================
# BASIC INFO
# ============================================================================
@export var tree_id: String = ""
@export var tree_name: String = "New Tree"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================================
# SKILLS BY TIER (rows 1-9)
# ============================================================================
@export_group("Tier 1 (Row 1)")
@export var tier_1_skills: Array[SkillResource] = []

@export_group("Tier 2 (Row 2)")
@export var tier_2_skills: Array[SkillResource] = []

@export_group("Tier 3 (Row 3)")
@export var tier_3_skills: Array[SkillResource] = []

@export_group("Tier 4 (Row 4)")
@export var tier_4_skills: Array[SkillResource] = []

@export_group("Tier 5 (Row 5)")
@export var tier_5_skills: Array[SkillResource] = []

@export_group("Tier 6 (Row 6)")
@export var tier_6_skills: Array[SkillResource] = []

@export_group("Tier 7 (Row 7)")
@export var tier_7_skills: Array[SkillResource] = []

@export_group("Tier 8 (Row 8)")
@export var tier_8_skills: Array[SkillResource] = []

@export_group("Tier 9 (Row 9)")
@export var tier_9_skills: Array[SkillResource] = []

@export_group("Tier 10 (Row 10)")
@export var tier_10_skills: Array[SkillResource] = []

# ============================================================================
# TIER UNLOCK REQUIREMENTS
# ============================================================================
@export_group("Tier Unlock Requirements")
@export var tier_2_points_required: int = 1
@export var tier_3_points_required: int = 3
@export var tier_4_points_required: int = 5
@export var tier_5_points_required: int = 8
@export var tier_6_points_required: int = 11
@export var tier_7_points_required: int = 15
@export var tier_8_points_required: int = 20
@export var tier_9_points_required: int = 25
@export var tier_10_points_required: int = 28
# ============================================================================
# GRID CONSTANTS
# ============================================================================
const GRID_ROWS: int = 10
const GRID_COLUMNS: int = 7

# ============================================================================
# SKILL ACCESS
# ============================================================================

func get_all_skills() -> Array[SkillResource]:
	"""Get all skills from all tiers"""
	var skills: Array[SkillResource] = []
	skills.append_array(tier_1_skills)
	skills.append_array(tier_2_skills)
	skills.append_array(tier_3_skills)
	skills.append_array(tier_4_skills)
	skills.append_array(tier_5_skills)
	skills.append_array(tier_6_skills)
	skills.append_array(tier_7_skills)
	skills.append_array(tier_8_skills)
	skills.append_array(tier_9_skills)
	skills.append_array(tier_10_skills)
	return skills

func get_skills_for_tier(tier: int) -> Array[SkillResource]:
	"""Get skills for a specific tier"""
	match tier:
		1: return tier_1_skills
		2: return tier_2_skills
		3: return tier_3_skills
		4: return tier_4_skills
		5: return tier_5_skills
		6: return tier_6_skills
		7: return tier_7_skills
		8: return tier_8_skills
		9: return tier_9_skills
		10: return tier_10_skills
		_: return []

func get_skill_by_id(id: String) -> SkillResource:
	"""Find a skill by its ID"""
	for skill in get_all_skills():
		if skill and skill.skill_id == id:
			return skill
	return null

func get_skill_at_position(row: int, col: int) -> SkillResource:
	"""Get skill at a specific grid position (row 0-8, col 0-6)"""
	var tier = row + 1  # Convert 0-indexed row to 1-indexed tier
	var tier_skills = get_skills_for_tier(tier)
	
	for skill in tier_skills:
		if skill and skill.column == col:
			return skill
	
	return null

func get_skill_grid() -> Array:
	"""Get a 2D array representing the skill grid [row][col]"""
	var grid: Array = []
	
	for row in range(GRID_ROWS):
		var row_array: Array = []
		for col in range(GRID_COLUMNS):
			row_array.append(get_skill_at_position(row, col))
		grid.append(row_array)
	
	return grid

# ============================================================================
# TIER UNLOCK CHECKING
# ============================================================================

func get_points_required_for_tier(tier: int) -> int:
	"""Get points required to unlock a tier"""
	match tier:
		1: return 0
		2: return tier_2_points_required
		3: return tier_3_points_required
		4: return tier_4_points_required
		5: return tier_5_points_required
		6: return tier_6_points_required
		7: return tier_7_points_required
		8: return tier_8_points_required
		9: return tier_9_points_required
		10: return tier_10_points_required
		_: return 999

func is_tier_unlocked(tier: int, points_spent_in_tree: int) -> bool:
	"""Check if a tier is unlocked based on points spent"""
	return points_spent_in_tree >= get_points_required_for_tier(tier)

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate the skill tree configuration"""
	var warnings: Array[String] = []
	
	if tree_id.is_empty():
		warnings.append("Tree has no ID")
	
	if tree_name.is_empty():
		warnings.append("Tree has no name")
	
	# Check for position conflicts
	var positions: Dictionary = {}
	for skill in get_all_skills():
		if not skill:
			continue
		
		var pos_key = "%d_%d" % [skill.tier, skill.column]
		if positions.has(pos_key):
			warnings.append("Position conflict at tier %d, column %d: %s and %s" % [
				skill.tier, skill.column, positions[pos_key], skill.skill_name
			])
		else:
			positions[pos_key] = skill.skill_name
		
		var skill_warnings = skill.validate()
		for warning in skill_warnings:
			warnings.append("[%s] %s" % [skill.skill_name, warning])
	
	return warnings

func _to_string() -> String:
	return "SkillTree<%s: %d skills>" % [tree_name, get_all_skills().size()]
