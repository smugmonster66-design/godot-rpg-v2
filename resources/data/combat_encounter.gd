# res://resources/data/combat_encounter.gd
# Defines a combat encounter with enemies, positioning, and metadata
extends Resource
class_name CombatEncounter

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
@export var encounter_name: String = "Combat Encounter"
@export_multiline var description: String = ""
@export var encounter_id: String = ""  # Unique ID for tracking/quests

# ============================================================================
# ENEMIES - Drag EnemyData resources here!
# ============================================================================
@export_group("Enemies")
## Enemy configurations for this encounter. Drag EnemyData resources here.
@export var enemies: Array[EnemyData] = []

## Spawn positions for each enemy (index matches enemies array)
## If empty or insufficient, uses default positions
enum EnemySlotPosition { LEFT = 0, MIDDLE = 1, RIGHT = 2 }

@export var enemy_slots: Array[int] = []  # Values from EnemySlotPosition]

# ============================================================================
# ENVIRONMENT
# ============================================================================
@export_group("Environment")
@export var background_texture: Texture2D = null
@export var background_color: Color = Color(0.1, 0.1, 0.15)
@export var music: AudioStream = null
@export var ambience: AudioStream = null

# ============================================================================
# DIFFICULTY & SCALING
# ============================================================================
@export_group("Difficulty")
@export_range(1, 10) var difficulty_tier: int = 1
@export var level_range_min: int = 1
@export var level_range_max: int = 5
## Multiplier for enemy stats (1.0 = normal)
@export var stat_multiplier: float = 1.0

# ============================================================================
# REWARDS
# ============================================================================
@export_group("Rewards")
@export var experience_multiplier: float = 1.0
@export var gold_multiplier: float = 1.0
@export var guaranteed_drops: Array[Resource] = []  # Items that always drop
@export var bonus_loot_table: String = ""  # Additional loot table ID

# ============================================================================
# SPECIAL RULES
# ============================================================================
@export_group("Special Rules")
@export var is_boss_encounter: bool = false
@export var disable_fleeing: bool = false
@export var turn_limit: int = 0  # 0 = no limit
@export var player_starts_first: bool = true

# ============================================================================
# DEFAULT POSITIONS
# ============================================================================
const DEFAULT_ENEMY_POSITIONS = [
	Vector2(600, 200),   # Enemy 1
	Vector2(700, 300),   # Enemy 2
	Vector2(600, 400),   # Enemy 3
]

# ============================================================================
# METHODS
# ============================================================================

func get_enemy_count() -> int:
	return enemies.size()

func get_enemy_slot(index: int) -> int:
	"""Get the UI slot (0=left, 1=middle, 2=right) for enemy at index."""
	if index < enemy_slots.size():
		return clampi(enemy_slots[index], 0, 2)
	# Auto-assign: center single enemies, spread multiples left-to-right
	match enemies.size():
		1: return EnemySlotPosition.MIDDLE
		2: return EnemySlotPosition.LEFT if index == 0 else EnemySlotPosition.RIGHT
		_: return clampi(index, 0, 2)


func get_total_experience() -> int:
	"""Calculate total experience reward"""
	var total = 0
	for enemy_data in enemies:
		if enemy_data:
			total += enemy_data.experience_reward
	return int(total * experience_multiplier)

func get_total_gold_range() -> Vector2i:
	"""Calculate total gold reward range (min, max)"""
	var min_gold = 0
	var max_gold = 0
	for enemy_data in enemies:
		if enemy_data:
			min_gold += enemy_data.gold_reward_min
			max_gold += enemy_data.gold_reward_max
	return Vector2i(
		int(min_gold * gold_multiplier),
		int(max_gold * gold_multiplier)
	)

func validate() -> Array[String]:
	"""Validate encounter configuration, returns array of warnings"""
	var warnings: Array[String] = []
	
	if enemies.size() == 0:
		warnings.append("No enemies defined")
	
	if enemies.size() > 3:
		warnings.append("More than 3 enemies may cause UI issues")
	
	for i in range(enemies.size()):
		if enemies[i] == null:
			warnings.append("Enemy slot %d is empty" % i)
		elif enemies[i].combat_actions.size() == 0:
			warnings.append("Enemy '%s' has no actions" % enemies[i].enemy_name)
		elif enemies[i].starting_dice.size() == 0:
			warnings.append("Enemy '%s' has no dice" % enemies[i].enemy_name)
	
	# Add to validate():
	if enemy_slots.size() >= 2:
		var used: Dictionary = {}
		for i in range(mini(enemy_slots.size(), enemies.size())):
			var slot = enemy_slots[i]
			if used.has(slot):
				warnings.append("Duplicate slot position %d for enemies %d and %d" % [slot, used[slot], i])
			used[slot] = i
	
	
	return warnings

func _to_string() -> String:
	return "CombatEncounter<%s, %d enemies, tier %d>" % [
		encounter_name, enemies.size(), difficulty_tier
	]
