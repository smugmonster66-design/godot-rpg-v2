# res://scripts/resources/skill_resource.gd
# Skill that grants affixes to the player when learned
extends Resource
class_name SkillResource

# ============================================================================
# BASIC INFO
# ============================================================================
@export var skill_id: String = ""
@export var skill_name: String = "New Skill"
@export var icon: Texture2D = null
@export_multiline var description: String = ""  ## Supports BBCode

# ============================================================================
# SKILL TREE PLACEMENT
# ============================================================================
@export_group("Skill Tree Position")
@export_range(1, 10) var tier: int = 1  ## Row in skill tree (1-9)
@export_range(0, 6) var column: int = 0  ## Column in skill tree (0-6)
@export var skill_point_cost: int = 1

# ============================================================================
# REQUIREMENTS
# ============================================================================
@export_group("Requirements")
## Skill prerequisites - each with its own required rank
@export var prerequisites: Array[SkillPrerequisite] = []
## Total skill points that must be spent in THIS tree before learning
@export var tree_points_required: int = 0

# ============================================================================
# AFFIXES PER RANK - Drag and drop Affix resources here
# ============================================================================
@export_group("Rank 1")
@export var rank_1_affixes: Array[Affix] = []

@export_group("Rank 2")
@export var rank_2_affixes: Array[Affix] = []

@export_group("Rank 3")
@export var rank_3_affixes: Array[Affix] = []

@export_group("Rank 4")
@export var rank_4_affixes: Array[Affix] = []

@export_group("Rank 5")
@export var rank_5_affixes: Array[Affix] = []

# ============================================================================
# RANK METHODS
# ============================================================================

func get_max_rank() -> int:
	"""Determine max rank based on which rank arrays have affixes"""
	if not rank_5_affixes.is_empty(): return 5
	if not rank_4_affixes.is_empty(): return 4
	if not rank_3_affixes.is_empty(): return 3
	if not rank_2_affixes.is_empty(): return 2
	if not rank_1_affixes.is_empty(): return 1
	return 1

func get_affixes_for_rank(rank: int) -> Array[Affix]:
	"""Get affixes granted at a specific rank"""
	match rank:
		1: return rank_1_affixes
		2: return rank_2_affixes
		3: return rank_3_affixes
		4: return rank_4_affixes
		5: return rank_5_affixes
		_: return []

func get_affixes_with_source(rank: int) -> Array[Affix]:
	"""Get affixes with source tracking set"""
	var affixes = get_affixes_for_rank(rank)
	var result: Array[Affix] = []
	
	for affix in affixes:
		if affix:
			var copy = affix.duplicate_with_source(skill_name, "skill")
			result.append(copy)
	
	return result

# ============================================================================
# PREREQUISITE CHECKING
# ============================================================================

func can_learn(skill_rank_getter: Callable, tree_points_spent: int) -> bool:
	"""Check if all requirements are met
	
	Args:
		skill_rank_getter: Callable(skill_id: String) -> int that returns current rank
		tree_points_spent: Total points spent in this skill's tree
	"""
	# Check tree points requirement
	if tree_points_spent < tree_points_required:
		return false
	
	# Check all prerequisites
	for prereq in prerequisites:
		if not prereq or not prereq.required_skill:
			continue
		
		var current_rank = skill_rank_getter.call(prereq.required_skill.skill_id)
		if current_rank < prereq.required_rank:
			return false
	
	return true

func get_missing_prerequisites(skill_rank_getter: Callable) -> Array[Dictionary]:
	"""Get list of unmet prerequisites with details
	
	Returns array of {skill: SkillResource, required: int, current: int}
	"""
	var missing: Array[Dictionary] = []
	
	for prereq in prerequisites:
		if not prereq or not prereq.required_skill:
			continue
		
		var current_rank = skill_rank_getter.call(prereq.required_skill.skill_id)
		if current_rank < prereq.required_rank:
			missing.append({
				"skill": prereq.required_skill,
				"required": prereq.required_rank,
				"current": current_rank
			})
	
	return missing

func has_prerequisites() -> bool:
	"""Check if this skill has any prerequisites"""
	return not prerequisites.is_empty() or tree_points_required > 0

# ============================================================================
# GRID POSITION HELPERS
# ============================================================================

func get_grid_position() -> Vector2i:
	"""Get position as Vector2i(column, row) for grid placement"""
	return Vector2i(column, tier - 1)  # tier is 1-indexed, rows are 0-indexed

# ============================================================================
# DISPLAY METHODS
# ============================================================================

func get_rank_description(rank: int) -> String:
	"""Get description of what a specific rank grants"""
	var affixes = get_affixes_for_rank(rank)
	if affixes.is_empty():
		return "No bonuses"
	
	var parts: Array[String] = []
	for affix in affixes:
		if affix:
			parts.append(affix.description)
	
	return ", ".join(parts)

func get_requirements_text(skill_rank_getter: Callable, tree_points_spent: int) -> String:
	"""Get human-readable requirements text"""
	var lines: Array[String] = []
	
	# Tree points requirement
	if tree_points_required > 0:
		var met = tree_points_spent >= tree_points_required
		var status = "✓" if met else "✗"
		lines.append("%s %d points in tree (%d/%d)" % [
			status, tree_points_required, tree_points_spent, tree_points_required
		])
	
	# Skill prerequisites
	for prereq in prerequisites:
		if not prereq or not prereq.required_skill:
			continue
		
		var current = skill_rank_getter.call(prereq.required_skill.skill_id)
		var met = current >= prereq.required_rank
		var status = "✓" if met else "✗"
		lines.append("%s %s Rank %d (%d/%d)" % [
			status, prereq.required_skill.skill_name, prereq.required_rank, current, prereq.required_rank
		])
	
	return "\n".join(lines) if lines.size() > 0 else "No requirements"

func get_total_affix_count() -> int:
	"""Count total affixes across all ranks"""
	var count = 0
	for rank in range(1, 6):
		count += get_affixes_for_rank(rank).size()
	return count

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate skill configuration"""
	var warnings: Array[String] = []
	
	if skill_id.is_empty():
		warnings.append("Skill has no ID")
	
	if skill_name.is_empty():
		warnings.append("Skill has no name")
	
	if rank_1_affixes.is_empty():
		warnings.append("Skill has no rank 1 affixes")
	
	if column < 0 or column > 6:
		warnings.append("Column out of range (0-6)")
	
	if tier < 1 or tier > 10:
		warnings.append("Tier out of range (1-10)")
	
	# Validate prerequisites
	for i in range(prerequisites.size()):
		var prereq = prerequisites[i]
		if prereq and not prereq.is_valid():
			warnings.append("Prerequisite %d is invalid" % i)
	
	return warnings

func _to_string() -> String:
	return "SkillResource<%s: tier %d, col %d, max rank %d>" % [skill_name, tier, column, get_max_rank()]
