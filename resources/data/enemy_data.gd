# res://resources/data/enemy_data.gd
# Enemy configuration resource with drag-and-drop dice and actions
extends Resource
class_name EnemyData

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
@export var enemy_name: String = "Enemy"
@export_multiline var description: String = "A hostile creature."
@export var portrait: Texture2D = null
@export var sprite_texture: Texture2D = null

# ============================================================================
# STATS
# ============================================================================
@export_group("Stats")
## Base health before affixes. Keep low — health_affix handles scaling.
@export var max_health: int = 10
## Base armor before affixes. 0 = all armor comes from affixes.
@export var base_armor: int = 0
## Base barrier before affixes. 0 = all barrier comes from affixes.
@export var base_barrier: int = 0

# ============================================================================
# DICE - Drag and drop DieResource assets here!
# ============================================================================
@export_group("Dice Pool")
## Dice this enemy starts combat with. Drag DieResource files here.
@export var starting_dice: Array[DieResource] = []

# ============================================================================
# ACTIONS - Drag and drop Action resources here!
# ============================================================================
@export_group("Combat Actions")
## Actions this enemy can perform. Drag Action resource files here.
@export var combat_actions: Array[Action] = []

# ============================================================================
# AI BEHAVIOR
# ============================================================================
@export_group("AI Settings")

enum AIStrategy {
	AGGRESSIVE,
	DEFENSIVE,
	BALANCED,
	RANDOM
}

@export var ai_strategy: AIStrategy = AIStrategy.BALANCED

enum TargetPriority {
	LOWEST_HEALTH,
	HIGHEST_HEALTH,
	RANDOM
}

@export var target_priority: TargetPriority = TargetPriority.RANDOM

@export_subgroup("Timing")
@export_range(0.3, 2.0, 0.1) var action_delay: float = 0.8
@export_range(0.2, 1.0, 0.1) var dice_drag_duration: float = 0.4



# ============================================================================
# VISUAL EVENTS
# ============================================================================
@export_group("Visual Events")

## Default attack effect (enemy → player). Used when action has no confirm_event.
@export var attack_event: CombatVisualEvent = null

## Effect when this enemy takes damage (flash/impact on self)
@export var hit_event: CombatVisualEvent = null

## Effect when this enemy dies
@export var death_event: CombatVisualEvent = null


# ============================================================================
# REWARDS
# ============================================================================
@export_group("Rewards")
@export var experience_reward: int = 10
@export var gold_reward_min: int = 5
@export var gold_reward_max: int = 15
@export var loot_table_id: String = ""  ## @deprecated — kept for migration

@export_subgroup("Loot System (v4)")

## Enemy tier controls drop count, rarity weights, and bonus chances.
## TRASH = 0-1 drops (60% nothing), ELITE = 1 guaranteed, etc.
@export var enemy_tier: EnemyTierLootConfig.EnemyTier = EnemyTierLootConfig.EnemyTier.TRASH

## Stat archetype. Enemies with STR/AGI/INT get a bonus roll from the
## matching sub-pool. NONE = shared pool only.
@export var enemy_archetype: EnemyTierLootConfig.Archetype = EnemyTierLootConfig.Archetype.NONE

@export_subgroup("Level Scaling")

## Level floor — this enemy never scales below this level.
## Also used as the loot floor: dropped items are at least this level.
@export_range(1, 100) var enemy_level_floor: int = 1

## Scaling multiplier applied to the player's active class level.
## 0.85 = enemy affixes roll at 85% of player level.
## 1.0 = equal to player. 1.2 = 20% harder than player.
@export_range(0.1, 2.0, 0.05) var level_scaling_multiplier: float = 0.85

# ============================================================================
# ENEMY AFFIXES — These define the enemy's stats, just like player equipment.
# ============================================================================
@export_group("Enemy Affixes")

## Health affix — ALWAYS rolled and applied at spawn time.
## Controls how the enemy's HP scales with player level.
## Drag a HEALTH_BONUS affix template here (e.g. inherent_health.tres).
## If null, the enemy only has base max_health (10).
@export var health_affix: Affix = preload("res://resources/affixes/base_stats/enemy_inherent_health.tres")

## Stat affixes — rolled at spawn time to give the enemy strength, armor, etc.
## Drag Affix templates here. Each gets duplicated and rolled at effective_level.
## These work identically to item affixes: category determines which stat they boost.
@export var enemy_affixes: Array[Affix] = []



# ============================================================================
# ELEMENTAL MODIFIERS — Controls resistance/immunity/weakness per element
# ============================================================================
@export_group("Elemental Modifiers")

## Per-element damage multipliers applied to incoming damage BEFORE defense.
## Missing elements default to 1.0 (normal damage).
## Keys must match ActionEffect.DamageType names:
##   SLASHING, BLUNT, PIERCING, FIRE, ICE, SHOCK, POISON, SHADOW
##
## Value guide:
##   0.0  = Immune    (fire elemental vs fire)
##   0.25 = Highly resistant
##   0.5  = Resistant (takes half)
##   0.75 = Slightly resistant
##   1.0  = Normal    (default — no entry needed)
##   1.5  = Weak      (takes 150%)
##   2.0  = Very weak (takes double)
##
## Example: {"FIRE": 0.0, "ICE": 2.0} = immune to fire, weak to ice
@export var element_modifiers: Dictionary = {}




# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_actions_as_dicts() -> Array[Dictionary]:
	"""Convert Action resources to dictionaries for combat system"""
	var result: Array[Dictionary] = []
	
	for action in combat_actions:
		if action:
			var dict = action.to_dict()
			dict["source"] = enemy_name
			result.append(dict)
	
	return result

func create_dice_copies() -> Array[DieResource]:
	"""Create fresh copies of starting dice for a combat instance"""
	var copies: Array[DieResource] = []
	
	for die_template in starting_dice:
		if die_template:
			var die_copy = die_template.duplicate_die()
			die_copy.source = enemy_name
			copies.append(die_copy)
	
	return copies

func get_gold_reward() -> int:
	"""Roll gold reward within range"""
	return randi_range(gold_reward_min, gold_reward_max)

# ============================================================================
# LEVEL SCALING
# ============================================================================

func get_effective_level(player_level: int) -> int:
	"""Calculate this enemy's effective level based on the player's level.
	
	effective_level = max(floor, int(player_level * multiplier))
	
	Used for:
	  - Rolling enemy affix values (stats, health)
	  - Setting item_level on loot drops
	"""
	var scaled: int = int(player_level * level_scaling_multiplier)
	return maxi(enemy_level_floor, scaled)


func roll_combat_affixes(player_level: int) -> Dictionary:
	"""Duplicate and roll all enemy affixes at the effective level.
	
	Returns a Dictionary with:
	  "effective_level": int — the computed level
	  "health_bonus": int — rolled health to ADD to max_health
	  "rolled_affixes": Array[Affix] — all rolled affix copies (including health)
	  "stat_totals": Dictionary — category_name → total value (for debug)
	
	Called by Combatant._initialize_from_enemy_data() at spawn time.
	"""
	var eff_level: int = get_effective_level(player_level)
	
	# Get scaling config from autoload
	var scaling_config: AffixScalingConfig = null
	var power_pos: float = clampf(float(eff_level - 1) / 99.0, 0.0, 1.0)
	
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root: Node = tree.root
		if root.has_node("AffixTableRegistry"):
			var registry: Node = root.get_node("AffixTableRegistry")
			if registry.scaling_config:
				scaling_config = registry.scaling_config
				power_pos = scaling_config.get_power_position(eff_level)
	
	var rolled: Array[Affix] = []
	var health_bonus: int = 0
	var stat_totals := {}
	
	# ── Roll health affix (always, if set) ──
	if health_affix:
		var copy: Affix = health_affix.duplicate(true)
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		health_bonus = int(copy.effect_number)
		rolled.append(copy)
		stat_totals["HEALTH_BONUS"] = health_bonus
	
	# ── Roll stat affixes ──
	for affix_template: Affix in enemy_affixes:
		if not affix_template:
			continue
		var copy: Affix = affix_template.duplicate(true)
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		rolled.append(copy)
		
		var cat_name: String = Affix.Category.keys()[copy.category]
		stat_totals[cat_name] = stat_totals.get(cat_name, 0.0) + copy.effect_number
	
	print("🎲 %s: effective Lv.%d (player %d × %.2f, floor %d) — %d affixes, +%d HP" % [
		enemy_name, eff_level, player_level, level_scaling_multiplier,
		enemy_level_floor, rolled.size(), health_bonus])
	
	return {
		"effective_level": eff_level,
		"health_bonus": health_bonus,
		"rolled_affixes": rolled,
		"stat_totals": stat_totals,
	}


func get_element_modifier(damage_type: ActionEffect.DamageType) -> float:
	"""Get the damage multiplier for a specific element.
	Returns 1.0 (normal) for elements not in the dictionary."""
	var key: String = ActionEffect.DamageType.keys()[damage_type]
	return element_modifiers.get(key, 1.0)

func get_all_immunities() -> Array[String]:
	"""Element names this enemy is immune to (modifier <= 0). For UI."""
	var result: Array[String] = []
	for key in element_modifiers:
		if element_modifiers[key] <= 0.0:
			result.append(key.capitalize())
	return result

func get_all_weaknesses() -> Array[String]:
	"""Element names this enemy is weak to (modifier > 1). For UI."""
	var result: Array[String] = []
	for key in element_modifiers:
		if element_modifiers[key] > 1.0:
			result.append(key.capitalize())
	return result

func get_all_resistances() -> Array[String]:
	"""Element names this enemy resists (0 < modifier < 1). For UI."""
	var result: Array[String] = []
	for key in element_modifiers:
		if element_modifiers[key] > 0.0 and element_modifiers[key] < 1.0:
			result.append(key.capitalize())
	return result




func _to_string() -> String:
	return "EnemyData<%s, HP:%d, Floor:%d, Scale:%.2f, Dice:%d, Actions:%d>" % [
		enemy_name, max_health, enemy_level_floor, level_scaling_multiplier,
		starting_dice.size(), combat_actions.size()
	]
