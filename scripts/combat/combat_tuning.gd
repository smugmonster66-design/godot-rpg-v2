# res://scripts/combat/combat_tuning.gd
# Combat balance knobs in one place. Values are starting points, to be tuned
# with the balance simulator against the design targets.
extends RefCounted
class_name CombatTuning

# ---------------------------------------------------------------------------
# Main stats power dice (designer, 2026-09-26: "Model B")
# Strength adds to physical-element dice, Intellect to magical-element dice.
# Neutral dice (NONE, FAITH) use the class's primary stat.
# ---------------------------------------------------------------------------
## +1 die value per this many points of the matching stat.
const STAT_PER_DIE_POINT: float = 20.0

# ---------------------------------------------------------------------------
# Crit: Agility adds crit chance, Luck adds crit damage.
# Both use diminishing returns: bonus = cap * stat / (stat + half_point).
# ---------------------------------------------------------------------------
const CRIT_CHANCE_CAP: float = 50.0          ## % crit chance at infinite Agility
const CRIT_CHANCE_HALF_POINT: float = 200.0  ## Agility that gives half the cap
const CRIT_DAMAGE_BASE: float = 1.5          ## crit multiplier with no Luck
const CRIT_DAMAGE_BONUS_CAP: float = 1.0     ## extra multiplier at infinite Luck
const CRIT_DAMAGE_HALF_POINT: float = 200.0  ## Luck that gives half the bonus


static func die_stat_bonus(stat_value: int) -> int:
	"""Die value added by a stat (Strength or Intellect)."""
	return maxi(0, floori(float(stat_value) / STAT_PER_DIE_POINT))


static func crit_chance(agility: int) -> float:
	"""Crit chance in % from Agility (0..CRIT_CHANCE_CAP)."""
	var a := maxf(0.0, float(agility))
	return CRIT_CHANCE_CAP * a / (a + CRIT_CHANCE_HALF_POINT)


static func crit_multiplier(luck: int) -> float:
	"""Crit damage multiplier from Luck (CRIT_DAMAGE_BASE .. base + cap)."""
	var l := maxf(0.0, float(luck))
	return CRIT_DAMAGE_BASE + CRIT_DAMAGE_BONUS_CAP * l / (l + CRIT_DAMAGE_HALF_POINT)
