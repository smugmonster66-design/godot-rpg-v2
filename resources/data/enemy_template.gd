# res://resources/data/enemy_template.gd
# Template defining an enemy's combat identity: Role + Stat Profile.
#
# This is the "blueprint class" layer above individual EnemyData resources.
# A template like "STR Brute" or "INT Caster" captures:
#   - WHAT it does in combat (role, AI defaults, action profile)
#   - HOW it scales across tiers (per-tier RoleTierBudgets)
#   - WHAT stats it favors (archetype, defense profile, stat weights)
#
# Family/faction identity is handled by TAGS on EnemyData, not here.
# Templates are role × archetype baselines that any family can use.
#
# Individual EnemyData resources reference a template and inherit its
# defaults. Anything on EnemyData can override the template — the template
# is a starting point, not a cage.
#
# DIRECTORY CONVENTION:
#   res://resources/enemy_templates/{role}_{archetype}.tres
#   e.g. res://resources/enemy_templates/brute_str.tres
#        res://resources/enemy_templates/caster_int.tres
#
extends Resource
class_name EnemyTemplate

# ============================================================================
# ENUMS
# ============================================================================

## Tactical identity — WHAT this enemy does in a fight.
enum CombatRole {
	## High single-target damage. Fewer large dice. Aggressive AI.
	BRUTE,
	## Multi-hit, evasion-flavored. Many small dice. Balanced AI.
	SKIRMISHER,
	## Elemental/status damage. Barrier-heavy. Balanced/Defensive AI.
	CASTER,
	## Soaks damage, protects allies. Defensive AI. High armor+barrier.
	TANK,
	## Buffs allies, debuffs player. Priority kill target. Defensive AI.
	SUPPORT,
}

## How the enemy distributes its defense budget.
enum DefenseProfile {
	## Mostly armor, little/no barrier. Physical wall.
	ARMOR_HEAVY,
	## Mostly barrier, little/no armor. Magical shield.
	BARRIER_HEAVY,
	## Balanced armor and barrier. Well-rounded.
	HYBRID,
	## Low defenses across the board. Glass cannon or fodder.
	MINIMAL,
}

## How the enemy's dice pool is composed.
enum DicePhilosophy {
	## Fewer dice, larger sizes (d8+). One big hit per turn.
	FEW_LARGE,
	## Many dice, smaller sizes (d4-d6). Multiple actions or multi-die combos.
	MANY_SMALL,
	## Mix of sizes. Flexible action economy.
	BALANCED,
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")

## Human-readable name for this template (e.g. "STR Brute", "INT Caster").
@export var template_name: String = ""

## Designer notes — what this template represents tactically.
@export_multiline var template_description: String = ""

## Tactical combat identity.
@export var role: CombatRole = CombatRole.BRUTE

## Which primary stat this enemy favors. Flows to EnemyData.enemy_archetype
## and drives loot archetype bonus rolls.
@export var archetype: EnemyTierLootConfig.Archetype = EnemyTierLootConfig.Archetype.STR

# ============================================================================
# COMBAT PROFILE
# ============================================================================
@export_group("Combat Profile")

## How the enemy's dice pool is shaped.
@export var dice_philosophy: DicePhilosophy = DicePhilosophy.FEW_LARGE

## How the enemy distributes armor vs barrier.
@export var defense_profile: DefenseProfile = DefenseProfile.ARMOR_HEAVY

## Default AI strategy (can be overridden per tier via RoleTierBudget).
@export var default_ai_strategy: EnemyData.AIStrategy = EnemyData.AIStrategy.AGGRESSIVE

## Default target priority.
@export var default_target_priority: EnemyData.TargetPriority = EnemyData.TargetPriority.RANDOM


@export_group("Default Actions")

## Base actions for this template. Trash-tier enemies use the first 2,
## elite+ enemies add from the rest. Individual EnemyData can replace any.
@export var default_actions: Array[Action] = []

# ============================================================================
# STAT WEIGHTS — Relative emphasis, not absolute values.
# ============================================================================
@export_group("Stat Weights")

## Health pool relative to tier baseline. 1.0 = average for tier.
## Brute/Tank > 1.0, Caster/Support < 1.0.
@export_range(0.3, 3.0, 0.05) var health_weight: float = 1.0

## Armor emphasis. Multiplied by defense_scale from tier budget.
## High for ARMOR_HEAVY profiles, low for BARRIER_HEAVY.
@export_range(0.0, 3.0, 0.05) var armor_weight: float = 1.0

## Barrier emphasis. Multiplied by defense_scale from tier budget.
@export_range(0.0, 3.0, 0.05) var barrier_weight: float = 0.0

## Offensive stat emphasis. How much the role invests in damage affixes.
@export_range(0.0, 3.0, 0.05) var damage_weight: float = 1.0

# ============================================================================
# ACTION PROFILE — Tags that describe what kind of actions this role uses.
# ============================================================================
@export_group("Action Profile")

## Tags describing the actions this role should have.
## Used by generators to pick from action pools.
## e.g. ["melee", "heavy_hit", "cleave"] for a Brute.
## e.g. ["elemental", "status_apply", "barrier_self"] for a Caster.
@export var action_tags: PackedStringArray = []

## Preferred damage types for this template's actions.
## Empty = physical by default. Casters might list [FIRE, ICE, SHOCK].
@export var preferred_damage_types: Array[ActionEffect.DamageType] = []

# ============================================================================
# TIER BUDGETS — One per enemy tier, all Inspector-editable.
# ============================================================================
@export_group("Tier Budgets")

## Mechanical budget for Trash-tier enemies using this template.
@export var trash_budget: RoleTierBudget

## Mechanical budget for Elite-tier enemies using this template.
@export var elite_budget: RoleTierBudget

## Mechanical budget for Mini-Boss-tier enemies using this template.
@export var mini_boss_budget: RoleTierBudget

## Mechanical budget for Boss-tier enemies using this template.
@export var boss_budget: RoleTierBudget

## Mechanical budget for World-Boss-tier enemies using this template.
@export var world_boss_budget: RoleTierBudget

# ============================================================================
# AFFIX TEMPLATES — Default stat affixes for enemies built from this template.
# ============================================================================
@export_group("Default Affixes")

## Health affix template. Duplicated and rolled per enemy instance.
## If null, individual EnemyData must supply its own.
@export var default_health_affix: Affix = null

## Stat affix templates appropriate for this role's archetype.
## e.g. A STR brute gets [strength_bonus, damage_bonus].
## An INT caster gets [intellect_bonus, barrier_bonus].
## Individual EnemyData can add to or replace these.
@export var default_stat_affixes: Array[Affix] = []

# ============================================================================
# VISUAL DEFAULTS
# ============================================================================
@export_group("Visual Defaults")

## Default attack visual event. Individual enemies can override.
@export var default_attack_event: CombatVisualEvent = null

## Default hit reaction event.
@export var default_hit_event: CombatVisualEvent = null

## Default death event.
@export var default_death_event: CombatVisualEvent = null

# ============================================================================
# PUBLIC API
# ============================================================================

func get_budget_for_tier(tier: EnemyTierLootConfig.EnemyTier) -> RoleTierBudget:
	"""Get the RoleTierBudget for a specific enemy tier."""
	match tier:
		EnemyTierLootConfig.EnemyTier.TRASH: return trash_budget
		EnemyTierLootConfig.EnemyTier.ELITE: return elite_budget
		EnemyTierLootConfig.EnemyTier.MINI_BOSS: return mini_boss_budget
		EnemyTierLootConfig.EnemyTier.BOSS: return boss_budget
		EnemyTierLootConfig.EnemyTier.WORLD_BOSS: return world_boss_budget
	push_warning("EnemyTemplate.get_budget_for_tier(): Unknown tier %d" % tier)
	return trash_budget


func get_effective_ai_strategy(tier: EnemyTierLootConfig.EnemyTier) -> EnemyData.AIStrategy:
	"""Get the AI strategy for a tier, respecting tier-level overrides."""
	var budget := get_budget_for_tier(tier)
	if budget:
		return budget.get_effective_ai_strategy(default_ai_strategy)
	return default_ai_strategy


# ============================================================================
# VALIDATION
# ============================================================================

func validate() -> Array[String]:
	"""Check template for common configuration issues."""
	var warnings: Array[String] = []

	if template_name == "":
		warnings.append("Missing template_name")

	# Check tier budgets exist
	var budget_names := ["trash", "elite", "mini_boss", "boss", "world_boss"]
	var budgets := [trash_budget, elite_budget, mini_boss_budget, boss_budget, world_boss_budget]
	for i in range(budgets.size()):
		if not budgets[i]:
			warnings.append("Missing %s_budget" % budget_names[i])

	# Role/archetype alignment check (soft warning)
	match role:
		CombatRole.BRUTE:
			if archetype == EnemyTierLootConfig.Archetype.INT:
				warnings.append("Brute role with INT archetype — intentional?")
		CombatRole.CASTER:
			if archetype == EnemyTierLootConfig.Archetype.STR:
				warnings.append("Caster role with STR archetype — intentional?")

	# Defense profile / weight sanity
	match defense_profile:
		DefenseProfile.ARMOR_HEAVY:
			if barrier_weight > armor_weight:
				warnings.append("ARMOR_HEAVY profile but barrier_weight > armor_weight")
		DefenseProfile.BARRIER_HEAVY:
			if armor_weight > barrier_weight:
				warnings.append("BARRIER_HEAVY profile but armor_weight > barrier_weight")
		DefenseProfile.MINIMAL:
			if armor_weight > 0.5 or barrier_weight > 0.5:
				warnings.append("MINIMAL profile but defense weights are high")

	# Dice philosophy / budget alignment
	if trash_budget:
		match dice_philosophy:
			DicePhilosophy.FEW_LARGE:
				if trash_budget.die_size_ceiling < DieResource.DieType.D6:
					warnings.append("FEW_LARGE philosophy but trash ceiling is below D6")
			DicePhilosophy.MANY_SMALL:
				if trash_budget.dice_count_max < 2:
					warnings.append("MANY_SMALL philosophy but trash max dice < 2")

	return warnings
