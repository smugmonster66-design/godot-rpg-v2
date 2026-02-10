# res://resources/data/player_class.gd
# Player class definition with starting stats, dice, and skill trees
extends Resource
class_name PlayerClass

# ============================================================================
# ENUMS
# ============================================================================
enum MainStat {
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	LUCK
}

# ============================================================================
# BASIC INFO
# ============================================================================
@export var class_id: String = ""
@export var player_class_name: String = "New Class"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var portrait: Texture2D = null
@export var main_stat: MainStat = MainStat.STRENGTH

# ============================================================================
# BASE STATS
# ============================================================================
@export_group("Base Stats")
@export var base_health: int = 100
@export var base_mana: int = 50
@export var base_strength: int = 10
@export var base_agility: int = 10
@export var base_intelligence: int = 10
@export var base_luck: int = 10
@export var base_armor: int = 0
@export var base_barrier: int = 0

# ============================================================================
# STAT GROWTH (per level)
# ============================================================================
@export_group("Stat Growth Per Level")
@export var health_per_level: int = 10
@export var mana_per_level: int = 5
@export var strength_per_level: float = 1.0
@export var agility_per_level: float = 1.0
@export var intelligence_per_level: float = 1.0
@export var luck_per_level: float = 1.0

# ============================================================================
# LEVELING (runtime state - preserved per class)
# ============================================================================
var level: int = 1
var experience: int = 0
var skill_points: int = 0
var total_skill_points: int = 0

# ============================================================================
# SKILL RANKS (runtime state - preserved per class)
# ============================================================================
## Tracks learned skill ranks: skill_id -> current_rank
var skill_ranks: Dictionary = {}

# ============================================================================
# STARTING DICE
# ============================================================================
@export_group("Starting Dice")
@export var starting_dice: Array[DieResource] = []

# ============================================================================
# SKILL TREES (up to 3)
# ============================================================================
@export_group("Skill Trees")
@export var skill_tree_1: SkillTree = null
@export var skill_tree_2: SkillTree = null
@export var skill_tree_3: SkillTree = null

# ============================================================================
# STARTING CONFIGURATION
# ============================================================================
@export_group("Starting Configuration")
@export var starting_actions: Array[Dictionary] = []
@export var unlocked_at_level: int = 1

# ============================================================================
# MANA SYSTEM (v4)
# ============================================================================
@export_group("Mana System")
## If non-null, this class has a mana pool. Drag a ManaPool resource here.
## Non-caster classes (warrior, rogue) leave this null.
## The template provides base_max_mana, mana_curve, int_mana_ratio.
## Player.initialize_mana_pool() copies these values at class selection.
@export var mana_pool_template: ManaPool = null

# ============================================================================
# STAT METHODS
# ============================================================================
func get_stat_at_level(stat_name: String, p_level: int) -> int:
	"""Calculate a stat value at a given level"""
	var base = 0
	var growth = 0.0
	
	match stat_name:
		"health", "max_hp":
			base = base_health
			growth = health_per_level
		"mana", "max_mana":
			base = base_mana
			growth = mana_per_level
		"strength":
			base = base_strength
			growth = strength_per_level
		"agility":
			base = base_agility
			growth = agility_per_level
		"intelligence":
			base = base_intelligence
			growth = intelligence_per_level
		"luck":
			base = base_luck
			growth = luck_per_level
		"armor":
			return base_armor
		"barrier":
			return base_barrier
		_:
			return 0
	
	return base + int(growth * (p_level - 1))

func get_stat_bonus(stat_name: String) -> int:
	"""Get base stat bonus"""
	match stat_name:
		"strength": return base_strength
		"agility": return base_agility
		"intelligence": return base_intelligence
		"luck": return base_luck
		"armor": return base_armor
		"barrier": return base_barrier
		_: return 0

func get_main_stat_name() -> String:
	"""Get the name of the main stat"""
	match main_stat:
		MainStat.STRENGTH: return "strength"
		MainStat.AGILITY: return "agility"
		MainStat.INTELLIGENCE: return "intelligence"
		MainStat.LUCK: return "luck"
		_: return "strength"

# ============================================================================
# LEVELING METHODS
# ============================================================================

func get_exp_for_next_level() -> int:
	"""Calculate XP needed for next level"""
	return level * 100

func get_exp_progress() -> float:
	"""Get progress toward next level (0.0 to 1.0)"""
	var needed = get_exp_for_next_level()
	return float(experience) / float(needed) if needed > 0 else 0.0

func gain_experience(amount: int) -> bool:
	"""Add experience, returns true if leveled up"""
	experience += amount
	var leveled = false
	
	while experience >= get_exp_for_next_level():
		experience -= get_exp_for_next_level()
		level += 1
		skill_points += 1
		total_skill_points += 1
		leveled = true
		print("🎉 Level up! Now level %d" % level)
	
	return leveled

func get_available_skill_points() -> int:
	"""Get skill points available to spend"""
	return skill_points

func get_total_skill_points() -> int:
	"""Get total skill points earned"""
	return total_skill_points

func get_spent_skill_points() -> int:
	"""Get number of skill points that have been spent"""
	return total_skill_points - skill_points

func spend_skill_point() -> bool:
	"""Spend a skill point, returns true if successful"""
	if skill_points > 0:
		skill_points -= 1
		return true
	return false

func refund_skill_point():
	"""Refund a skill point"""
	skill_points += 1

# ============================================================================
# SKILL RANK METHODS
# ============================================================================

func get_skill_rank(skill_id: String) -> int:
	"""Get current rank for a skill"""
	return skill_ranks.get(skill_id, 0)

func set_skill_rank(skill_id: String, rank: int):
	"""Set rank for a skill"""
	if rank <= 0:
		skill_ranks.erase(skill_id)
	else:
		skill_ranks[skill_id] = rank

func has_learned_skill(skill_id: String) -> bool:
	"""Check if a skill has been learned (rank >= 1)"""
	return skill_ranks.get(skill_id, 0) >= 1

func get_all_learned_skill_ids() -> Array[String]:
	"""Get IDs of all learned skills"""
	var ids: Array[String] = []
	for skill_id in skill_ranks:
		if skill_ranks[skill_id] > 0:
			ids.append(skill_id)
	return ids

func reset_all_skills():
	"""Reset all skills and refund points"""
	var spent = get_spent_skill_points()
	skill_ranks.clear()
	skill_points = total_skill_points
	print("🌳 Reset all skills, refunded %d points" % spent)

# ============================================================================
# DICE METHODS
# ============================================================================

func get_starting_dice_copies() -> Array[DieResource]:
	var copies: Array[DieResource] = []
	
	for die in starting_dice:
		if die:
			print("🎲 PlayerClass - Original die: %s" % die.display_name)
			print("   Original resource_path: %s" % die.resource_path)
			print("   Original fill_texture: %s" % die.fill_texture)
			print("   Original stroke_texture: %s" % die.stroke_texture)
			
			var copy = die.duplicate_die()
			copy.source = player_class_name
			
			print("   Copy fill_texture: %s" % copy.fill_texture)
			print("   Copy stroke_texture: %s" % copy.stroke_texture)
			
			copies.append(copy)
	
	return copies

func get_all_class_dice() -> Array:
	"""Get all dice types this class provides"""
	var dice_types = []
	for die in starting_dice:
		if die:
			dice_types.append(die.die_type)
	return dice_types

func get_starting_dice_summary() -> String:
	"""Get a summary of starting dice for display"""
	if starting_dice.is_empty():
		return "No starting dice"
	
	var counts: Dictionary = {}
	for die in starting_dice:
		if die:
			var key = "D%d" % die.die_type
			counts[key] = counts.get(key, 0) + 1
	
	var parts: Array[String] = []
	for key in counts:
		parts.append("%dx %s" % [counts[key], key])
	
	return ", ".join(parts)

# ============================================================================
# SKILL TREE METHODS
# ============================================================================

func get_skill_trees() -> Array[SkillTree]:
	"""Get all assigned skill trees"""
	var trees: Array[SkillTree] = []
	if skill_tree_1: trees.append(skill_tree_1)
	if skill_tree_2: trees.append(skill_tree_2)
	if skill_tree_3: trees.append(skill_tree_3)
	return trees

func get_skill_tree_count() -> int:
	"""Count assigned skill trees"""
	var count = 0
	if skill_tree_1: count += 1
	if skill_tree_2: count += 1
	if skill_tree_3: count += 1
	return count

func get_skill_tree_by_index(index: int) -> SkillTree:
	"""Get skill tree by index (0-2)"""
	match index:
		0: return skill_tree_1
		1: return skill_tree_2
		2: return skill_tree_3
		_: return null

func get_skill_tree_by_id(id: String) -> SkillTree:
	"""Find a skill tree by its ID"""
	for tree in get_skill_trees():
		if tree and tree.tree_id == id:
			return tree
	return null

func get_all_skills() -> Array[SkillResource]:
	"""Get all skills from all skill trees"""
	var skills: Array[SkillResource] = []
	for tree in get_skill_trees():
		if tree:
			skills.append_array(tree.get_all_skills())
	return skills

func get_skill_by_id(id: String) -> SkillResource:
	"""Find a skill by ID across all trees"""
	for tree in get_skill_trees():
		if tree:
			var skill = tree.get_skill_by_id(id)
			if skill:
				return skill
	return null

# ============================================================================
# DEFAULT ACTIONS
# ============================================================================

func get_default_actions() -> Array[Dictionary]:
	"""Get default combat actions for this class"""
	if starting_actions.size() > 0:
		return starting_actions.duplicate(true)
	
	return [
		{
			"name": "Attack",
			"action_type": 0,
			"base_damage": 0,
			"damage_multiplier": 1.0,
			"die_slots": 1,
			"source": "class"
		},
		{
			"name": "Defend",
			"action_type": 1,
			"base_damage": 0,
			"damage_multiplier": 0.5,
			"die_slots": 1,
			"source": "class"
		}
	]

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_save_data() -> Dictionary:
	"""Serialize class state for saving"""
	return {
		"class_id": class_id,
		"level": level,
		"experience": experience,
		"skill_points": skill_points,
		"total_skill_points": total_skill_points,
		"skill_ranks": skill_ranks.duplicate()
	}

func load_save_data(data: Dictionary):
	"""Restore class state from save data"""
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	skill_points = data.get("skill_points", 0)
	total_skill_points = data.get("total_skill_points", 0)
	skill_ranks = data.get("skill_ranks", {}).duplicate()

# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Validate the class configuration"""
	var warnings: Array[String] = []
	
	if class_id.is_empty():
		warnings.append("Class has no ID")
	
	if player_class_name.is_empty():
		warnings.append("Class has no name")
	
	if base_health <= 0:
		warnings.append("Base health should be positive")
	
	if starting_dice.is_empty():
		warnings.append("Class has no starting dice")
	
	if get_skill_tree_count() == 0:
		warnings.append("Class has no skill trees")
	
	for tree in get_skill_trees():
		if tree:
			var tree_warnings = tree.validate()
			for warning in tree_warnings:
				warnings.append("[%s] %s" % [tree.tree_name, warning])
	
	return warnings

func _to_string() -> String:
	return "PlayerClass<%s Lv.%d: %d dice, %d trees, %d skills learned>" % [
		player_class_name,
		level,
		starting_dice.size(),
		get_skill_tree_count(),
		skill_ranks.size()
	]
