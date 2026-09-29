# res://scripts/combat/combat_tuning.gd
# Combat balance knobs in one place. Values are tuned with the balance
# simulator (res://tools/balance_sim) against the design targets
# (PLOT _Ledger/Balance Targets.md).
#
# The knobs are static vars so the simulator can try other values for a run
# (set_knob). The game only ever uses the defaults written here.
extends RefCounted
class_name CombatTuning

# ---------------------------------------------------------------------------
# Main stats power dice (designer, 2026-09-26: "Model B")
# Strength adds to physical-element dice, Intellect to magical-element dice.
# Neutral dice (NONE, FAITH) use the class's primary stat.
# ---------------------------------------------------------------------------
## Dice formula (designer, 2026-09-27, "middle"; built 2026-09-29):
##     value = face x (1 + stat / STAT_DIE_SCALE) + stat / STAT_DIE_FLAT
## rounded once. The rolled face stays on the die (DieResource.current_value)
## so skills written in faces still read the face. Replaces the old flat
## "+1 per STAT_PER_DIE_POINT".
static var STAT_DIE_SCALE: float = 88.0
static var STAT_DIE_FLAT: float = 16.0

# ---------------------------------------------------------------------------
# Crit: Agility adds crit chance, Luck adds crit damage.
# Both use diminishing returns: bonus = cap * stat / (stat + half_point).
# ---------------------------------------------------------------------------
const CRIT_CHANCE_CAP: float = 50.0          ## % crit chance at infinite Agility
const CRIT_CHANCE_HALF_POINT: float = 200.0  ## Agility that gives half the cap
const CRIT_DAMAGE_BASE: float = 1.5          ## crit multiplier with no Luck
const CRIT_DAMAGE_BONUS_CAP: float = 1.0     ## extra multiplier at infinite Luck
const CRIT_DAMAGE_HALF_POINT: float = 200.0  ## Luck that gives half the bonus

# ---------------------------------------------------------------------------
# Defence: A1, hit-relative (designer, 2026-09-27)
# For each element pile of a hit, with D = armour (physical) or barrier
# (magical) after piercing and the defence multiplier:
#     reduction = D / (D + DEFENSE_K * pile), capped at DEFENSE_CAP
# Armour equal to K times the hit halves it. Scale-free: armour and damage
# growing together keep the same reduction. Piercing still halves armour.
# Applies to the player, enemies and companions (DamagePacket).
# ---------------------------------------------------------------------------
## Tuned 2026-09-27 with the simulator: 8 (started at 5). Higher K lets more
## of each hit through; 8 moved enemy hits toward the targets at little cost
## to kill speed. The cap rarely binds (0.75 and 0.85 ran the same).
static var DEFENSE_K: float = 8.0
static var DEFENSE_CAP: float = 0.85

# ---------------------------------------------------------------------------
# Healing: C1, heals scale like damage (designer, 2026-09-27)
# heal = (dice + base_heal) x multiplier + the healer's HEALING_BONUS affixes,
# then x HEALING_MULTIPLIER affixes. The bonus also adds to each proc heal
# (regeneration, heal on kill ...). Lifesteal and leech are a share of the
# damage dealt and already scale.
# ---------------------------------------------------------------------------
## Scales every HEALING_BONUS affix value (1.0 = as rolled).
static var HEALING_BONUS_SCALE: float = 1.0

# ---------------------------------------------------------------------------
# Statuses: D, strength follows the applier's level (designer, 2026-09-27)
# Stored on the status when applied (StatusTracker instance "potency"):
#     potency = 1 + (STATUS_POTENCY_AT_CAP - 1) x power_position(level)
# power_position is the same smoothstep curve every affix uses
# (AffixScalingConfig), so status strength grows like a flat damage affix
# (enemy flat damage affixes run 1-45 over levels 1-100). Potency multiplies
# per-stack magnitudes only: bleed / poison / burn ticks, the burn burst,
# static, fortified, warded, corrode and block. Stack counts, durations and
# thresholds don't change.
# ---------------------------------------------------------------------------
static var STATUS_POTENCY_ENABLED: bool = true
static var STATUS_POTENCY_AT_CAP: float = 45.0

# ---------------------------------------------------------------------------
# Enemy strength by tier and level (designer, 2026-09-27)
# Enemy damage grows on the same curve as gear, with a step per tier:
#     damage x ENEMY_DAMAGE_TIER[tier] x (1 + ENEMY_DAMAGE_GROWTH x pos)
# where pos is the affix power position (smoothstep) at the enemy's
# effective level. Enemy HP x ENEMY_HP_TIER[tier]. Applied at spawn
# (Combatant), on top of power matching, the encounter multiplier and depth.
# Index = EnemyTierLootConfig.EnemyTier: TRASH, ELITE, MINI_BOSS, BOSS, WORLD_BOSS.
# World bosses aren't tuned yet (they copy the boss values).
# ---------------------------------------------------------------------------
# Tuned 2026-09-27 with the simulator against the revised turn targets
# (trash 2-3, elite 4-5, mini-boss 5-8, boss 10-15 turns). Bosses and
# mini-bosses act once per die (3-5 dice), so a long fight survivable at
# 50-80% HP lost needs small hits: the boss damage step ends up at 0.2,
# far below the 2.5 starting point. See the final sim report.
static var ENEMY_DAMAGE_GROWTH: float = 0.7
static var ENEMY_DAMAGE_TIER: Array[float] = [1.25, 0.7, 1.0, 0.2, 0.2]
static var ENEMY_HP_TIER: Array[float] = [1.0, 2.2, 8.0, 16.0, 16.0]


static func enemy_damage_multiplier(tier: int, effective_level: int) -> float:
	var step: float = ENEMY_DAMAGE_TIER[clampi(tier, 0, ENEMY_DAMAGE_TIER.size() - 1)]
	return step * (1.0 + ENEMY_DAMAGE_GROWTH * _power_position(effective_level))


static func enemy_hp_multiplier(tier: int) -> float:
	return ENEMY_HP_TIER[clampi(tier, 0, ENEMY_HP_TIER.size() - 1)]


static func _power_position(level: int) -> float:
	var pos := clampf(float(level - 1) / 99.0, 0.0, 1.0)
	var tree := Engine.get_main_loop()
	if tree is SceneTree and (tree as SceneTree).root.has_node("AffixTableRegistry"):
		var cfg = (tree as SceneTree).root.get_node("AffixTableRegistry").scaling_config
		if cfg:
			pos = cfg.get_power_position(level)
	return pos

# ---------------------------------------------------------------------------
# Losing (designer, 2026-09-26; Balance Targets "Losing")
# ---------------------------------------------------------------------------
## Share of carried gold donated when the shellkeepers rescue you after a
## loss outside a dungeon. Dungeon deaths are free (the lost run is the price).
const DEFEAT_DONATION_PERCENT: float = 0.12

# ---------------------------------------------------------------------------
# Dungeon depth: later floors are harder (designer, 2026-09-26)
# Per floor below the entrance, scaled by DungeonDefinition.depth_scaling.
# ---------------------------------------------------------------------------
static var DEPTH_STATS_PER_FLOOR: float = 0.05   ## enemy HP / armour / barrier
static var DEPTH_DAMAGE_PER_FLOOR: float = 0.03  ## enemy damage


static func depth_multipliers(floor_num: int, depth_scaling: float) -> Dictionary:
	"""{stats, damage} multipliers for enemies on a dungeon floor."""
	var f := maxf(0.0, float(floor_num)) * maxf(0.0, depth_scaling)
	return {"stats": 1.0 + DEPTH_STATS_PER_FLOOR * f, "damage": 1.0 + DEPTH_DAMAGE_PER_FLOOR * f}


static func die_stat_bonus(stat_value: int, face: int = 0) -> int:
	"""Die value a stat (Strength or Intellect) adds to a die showing `face`:
	face x stat / STAT_DIE_SCALE + stat / STAT_DIE_FLAT, rounded."""
	var s := maxf(0.0, float(stat_value))
	return maxi(0, roundi(float(maxi(0, face)) * s / STAT_DIE_SCALE + s / STAT_DIE_FLAT))


static func at_least(percent_value: float, minimum: float) -> float:
	"""Whichever is bigger (Class Framework rule): a percentage-based amount
	with a flat minimum, e.g. "+20% (at least +2)". Works for penalties too
	(the one with the larger size wins, keeping its sign)."""
	return percent_value if absf(percent_value) >= absf(minimum) else minimum


static func crit_chance(agility: int) -> float:
	"""Crit chance in % from Agility (0..CRIT_CHANCE_CAP)."""
	var a := maxf(0.0, float(agility))
	return CRIT_CHANCE_CAP * a / (a + CRIT_CHANCE_HALF_POINT)


static func crit_multiplier(luck: int) -> float:
	"""Crit damage multiplier from Luck (CRIT_DAMAGE_BASE .. base + cap)."""
	var l := maxf(0.0, float(luck))
	return CRIT_DAMAGE_BASE + CRIT_DAMAGE_BONUS_CAP * l / (l + CRIT_DAMAGE_HALF_POINT)


static func defense_reduction(defense: float, pile: float) -> float:
	"""A1: the share of one element pile that defence removes (0..DEFENSE_CAP)."""
	if defense <= 0.0 or pile <= 0.0:
		return 0.0
	return minf(DEFENSE_CAP, defense / (defense + DEFENSE_K * pile))


static func status_potency(level: int) -> float:
	"""D: the strength of a status applied by someone of this level
	(1.0 at level 1, STATUS_POTENCY_AT_CAP at level 100)."""
	if not STATUS_POTENCY_ENABLED or level <= 1:
		return 1.0
	return 1.0 + (STATUS_POTENCY_AT_CAP - 1.0) * _power_position(level)


static func set_knob(knob: String, value: String) -> bool:
	"""Balance simulator only: set a knob by name for one run."""
	match knob:
		"STAT_DIE_SCALE": STAT_DIE_SCALE = float(value)
		"STAT_DIE_FLAT": STAT_DIE_FLAT = float(value)
		"DEFENSE_K": DEFENSE_K = float(value)
		"DEFENSE_CAP": DEFENSE_CAP = float(value)
		"HEALING_BONUS_SCALE": HEALING_BONUS_SCALE = float(value)
		"STATUS_POTENCY_ENABLED": STATUS_POTENCY_ENABLED = value in ["1", "true"]
		"STATUS_POTENCY_AT_CAP": STATUS_POTENCY_AT_CAP = float(value)
		"DEPTH_STATS_PER_FLOOR": DEPTH_STATS_PER_FLOOR = float(value)
		"DEPTH_DAMAGE_PER_FLOOR": DEPTH_DAMAGE_PER_FLOOR = float(value)
		"ENEMY_DAMAGE_GROWTH": ENEMY_DAMAGE_GROWTH = float(value)
		"ENEMY_DAMAGE_TIER": ENEMY_DAMAGE_TIER = _float_list(value)
		"ENEMY_HP_TIER": ENEMY_HP_TIER = _float_list(value)
		_: return false
	return true


static func _float_list(value: String) -> Array[float]:
	"""'1;1.5;3;5;5' -> [1.0, 1.5, 3.0, 5.0, 5.0] (simulator knobs)."""
	var out: Array[float] = []
	for part in value.split(";"):
		out.append(float(part))
	return out
