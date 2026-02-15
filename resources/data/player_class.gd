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
# CLASS ACTION (v6)
# ============================================================================
@export_group("Class Action")
## The signature combat action for this class. Always available in combat.
## Skills can modify this action via CLASS_ACTION_* affix categories.
@export var class_action: Action = null

## If true, the class action cannot be unequipped or replaced by items.
## The CLASS_ACTION_UPGRADE category can still swap it via skills.
@export var class_action_locked: bool = true

## Optional: tag applied to the class action for affix condition checks.
## e.g., "warrior_class_action", "mage_class_action"
@export var class_action_tag: String = ""


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

func add_experience(amount: int) -> bool:
	"""Alias for gain_experience (matches caller convention)."""
	return gain_experience(amount)


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

# ============================================================================
# EFFECTIVE SKILL RANK (v5 — Bonus Ranks from Equipment)
# ============================================================================

func get_effective_skill_rank(skill_id: String, tree_id: String = "",
		class_id: String = "", max_rank: int = 5,
		skill_tags: Array[String] = []) -> int:
	"""Get the effective rank of a skill including bonus ranks from gear.
	
	Bonus ranks do NOT unlock unlearned skills — base rank must be >= 1.
	Effective rank is capped at max_rank (from the SkillResource).
	
	Args:
		skill_id: The skill's unique ID.
		tree_id: The skill's tree ID (for TREE_SKILL_RANK_BONUS lookups).
		class_id: The class ID (for CLASS_SKILL_RANK_BONUS lookups).
		max_rank: Maximum rank this skill supports.
		skill_tags: Tags on the SkillResource (for TAG_SKILL_RANK_BONUS lookups).
	"""
	var base_rank: int = skill_ranks.get(skill_id, 0)
	if base_rank == 0:
		return 0  # Unlearned — bonus ranks don't unlock skills
	
	
	var bonus: int = _get_skill_rank_bonus(skill_id, tree_id, class_id)
	return base_rank + bonus  # Gear can push past max — over-cap re-applies highest rank affix

func _get_skill_rank_bonus(skill_id: String, tree_id: String,
		class_id: String, skill_tags: Array[String] = []) -> int:
	"""Sum all skill rank bonuses from equipment/affixes.
	
	Queries the player's AffixPoolManager for:
	  - SKILL_RANK_BONUS matching this skill_id
	  - TREE_SKILL_RANK_BONUS matching this tree_id
	  - CLASS_SKILL_RANK_BONUS matching this class_id
	  - TAG_SKILL_RANK_BONUS matching any tag on the skill
	
	Requires affix_manager to be set on the parent Player.
	"""
	var bonus: int = 0
	
	if not _affix_manager_ref:
		print("⚠️ _affix_manager_ref is null for %s!" % skill_id)
		return 0
	
	
	var pool = _affix_manager_ref.get_pool(Affix.Category.SKILL_RANK_BONUS)
	print("🔍 Checking rank bonus for %s — pool size: %d" % [skill_id, pool.size()])
	for affix in pool:
		print("   affix: %s | effect_data: %s" % [affix.affix_name, affix.effect_data])
	
	
	# +N to specific skill
	for affix in _affix_manager_ref.get_pool(Affix.Category.SKILL_RANK_BONUS):
		if affix.effect_data.get("skill_id", "") == skill_id:
			bonus += int(affix.effect_number)
	
	# +N to all skills in tree
	if tree_id != "":
		for affix in _affix_manager_ref.get_pool(Affix.Category.TREE_SKILL_RANK_BONUS):
			if affix.effect_data.get("tree_id", "") == tree_id:
				bonus += int(affix.effect_number)
	
	# +N to all class skills
	if class_id != "":
		for affix in _affix_manager_ref.get_pool(Affix.Category.CLASS_SKILL_RANK_BONUS):
			if affix.effect_data.get("class_id", "") == class_id:
				bonus += int(affix.effect_number)
	
	# +N to all skills with a matching tag
	if not skill_tags.is_empty():
		for affix in _affix_manager_ref.get_pool(Affix.Category.TAG_SKILL_RANK_BONUS):
			var required_tag = affix.effect_data.get("tag", "")
			if required_tag != "" and required_tag in skill_tags:
				bonus += int(affix.effect_number)
	
	
	print("   → total bonus for %s: %d" % [skill_id, bonus])
	return bonus

## Reference to AffixPoolManager — set by Player during initialization.
## Used for bonus rank calculations.
var _affix_manager_ref: AffixPoolManager = null

func set_affix_manager_ref(manager: AffixPoolManager) -> void:
	"""Store reference to the player's AffixPoolManager for bonus rank queries."""
	_affix_manager_ref = manager

# ============================================================================
# SKILL → ACTION REGISTRY (v6)
# ============================================================================

## Maps skill_id → action_id for skills that grant combat actions via NEW_ACTION.
## Populated during skill learning, used by combat to trace actions back to skills.
var skill_action_registry: Dictionary = {}  # { "flame_eruption": "eruption_action" }

## Tracks the highest rank whose affixes are currently applied per skill.
## Includes bonus ranks from equipment. Used by Chunk 2 to diff on equip changes.
var applied_effective_ranks: Dictionary = {}  # { "flame_eruption": 3 }

## Emitted when equipment changes cause effective ranks to shift.
## Array contains skill_ids whose effective rank changed.
signal effective_ranks_changed(changed_skills: Array[String])

func register_skill_action(skill_id: String, action_id: String) -> void:
	"""Register that a skill grants a specific action."""
	skill_action_registry[skill_id] = action_id

func unregister_skill_action(skill_id: String) -> void:
	"""Remove a skill's action registration."""
	skill_action_registry.erase(skill_id)

func get_skill_for_action(action_id: String) -> String:
	"""Reverse lookup: given an action_id, find which skill granted it."""
	for skill_id in skill_action_registry:
		if skill_action_registry[skill_id] == action_id:
			return skill_id
	return ""

func get_action_for_skill(skill_id: String) -> String:
	"""Forward lookup: given a skill_id, get its granted action_id."""
	return skill_action_registry.get(skill_id, "")


# ============================================================================
# BONUS RANK APPLICATION ENGINE (v6 — Chunk 2)
# ============================================================================

func recalculate_effective_ranks() -> Array[String]:
	print("🔍 recalculate_effective_ranks called")
	print("   _affix_manager_ref: %s" % _affix_manager_ref)
	
	"""Recalculate all effective ranks and apply/remove delta affixes.
	
	Compares each learned skill's current effective rank (including gear bonuses)
	against the last applied effective rank. For any difference, applies or
	removes the appropriate rank affixes.
	
	Returns array of skill_ids whose effective rank changed.
	Call this from Player.recalculate_stats() after equipment affixes are updated.
	"""
	if not _affix_manager_ref:
		return []
	
	var changed: Array[String] = []
	
	for skill_id in skill_ranks:
		var base_rank: int = skill_ranks[skill_id]
		if base_rank == 0:
			continue
		
		# Look up the SkillResource to get tree_id, max_rank, tags
		var skill: SkillResource = _find_skill_resource(skill_id)
		if not skill:
			continue
		
		var tree_id: String = _find_tree_id_for_skill(skill_id)
		var new_effective: int = get_effective_skill_rank(
			skill_id, tree_id, class_id, skill.get_max_rank(), skill.tags
		)
		var old_effective: int = applied_effective_ranks.get(skill_id, base_rank)
		
		if new_effective == old_effective:
			continue
		
		changed.append(skill_id)
		
		if new_effective > old_effective:
			# Apply affixes for ranks (old_effective+1) through new_effective
			for rank in range(old_effective + 1, new_effective + 1):
				_apply_bonus_rank_affixes(skill, rank)
		else:
			# Remove affixes for ranks (new_effective+1) through old_effective
			for rank in range(new_effective + 1, old_effective + 1):
				_remove_bonus_rank_affixes(skill, rank)
		
		applied_effective_ranks[skill_id] = new_effective
		print("📊 %s effective rank: %d → %d (base %d)" % [
			skill.skill_name, old_effective, new_effective, base_rank
		])
	
	if not changed.is_empty():
		effective_ranks_changed.emit(changed)
	
	return changed


func _apply_bonus_rank_affixes(skill: SkillResource, rank: int) -> void:
	"""Apply all affixes for a specific rank of a skill (bonus rank path)."""
	var affixes = skill.get_affixes_for_rank(rank)
	for affix in affixes:
		if not affix:
			continue
		var copy = affix.duplicate_with_source(skill.skill_name, "skill")
		_affix_manager_ref.add_affix(copy)
		print("  ⬆️ Bonus rank applied: %s (rank %d of %s)" % [
			affix.affix_name, rank, skill.skill_name
		])
		
		# If this grants an action, register it
		if affix.category == Affix.Category.NEW_ACTION and affix.granted_action:
			register_skill_action(skill.skill_id, affix.granted_action.action_id)
			print("  📋 Bonus rank registered action: %s → %s" % [
				skill.skill_id, affix.granted_action.action_id
			])


func _remove_bonus_rank_affixes(skill: SkillResource, rank: int) -> void:
	"""Remove affixes that were applied for a specific bonus rank."""
	var affixes = skill.get_affixes_for_rank(rank)
	for affix in affixes:
		if not affix:
			continue
		var removed = _affix_manager_ref.remove_affix_by_source_and_name(
			skill.skill_name, affix.affix_name
		)
		if removed:
			print("  ⬇️ Bonus rank removed: %s (rank %d of %s)" % [
				affix.affix_name, rank, skill.skill_name
			])
		else:
			push_warning("  ⚠️ Could not find affix to remove: %s from %s rank %d" % [
				affix.affix_name, skill.skill_name, rank
			])
		
		# If this removes an action, unregister it
		if affix.category == Affix.Category.NEW_ACTION and affix.granted_action:
			unregister_skill_action(skill.skill_id)
			print("  📋 Bonus rank unregistered action: %s" % skill.skill_id)


func _find_skill_resource(skill_id: String) -> SkillResource:
	"""Find a SkillResource by ID across all skill trees."""
	for tree in get_skill_trees():
		if not tree:
			continue
		var skill = tree.get_skill_by_id(skill_id)
		if skill:
			return skill
	return null


func _find_tree_id_for_skill(skill_id: String) -> String:
	"""Find which tree a skill belongs to."""
	for tree in get_skill_trees():
		if not tree:
			continue
		if tree.get_skill_by_id(skill_id):
			return tree.tree_id
	return ""



func reset_all_skills():
	"""Reset all skills and refund points"""
	var spent = get_spent_skill_points()
	skill_ranks.clear()
	applied_effective_ranks.clear()
	skill_action_registry.clear()
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
		"skill_ranks": skill_ranks.duplicate(),
		"skill_action_registry": skill_action_registry.duplicate(),
		"applied_effective_ranks": applied_effective_ranks.duplicate(),
	}

func load_save_data(data: Dictionary):
	"""Restore class state from save data"""
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	skill_points = data.get("skill_points", 0)
	total_skill_points = data.get("total_skill_points", 0)
	skill_ranks = data.get("skill_ranks", {}).duplicate()
	skill_action_registry = data.get("skill_action_registry", {}).duplicate()
	applied_effective_ranks = data.get("applied_effective_ranks", {}).duplicate()



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
