# res://resources/data/dice_affix_condition.gd
# Inspector-friendly condition resource for dice affixes.
# Evaluated AFTER trigger and position checks, BEFORE effect application.
# Attach to a DiceAffix via its "condition" export slot.
#
# Two modes:
#   GATING conditions — if the check fails the affix is skipped entirely.
#   SCALING conditions — always fire, but provide a runtime multiplier
#       that is applied to the resolved effect value.
extends Resource
class_name DiceAffixCondition

# ============================================================================
# ENUMS
# ============================================================================

## The type of check to perform.
enum Type {
	NONE,                        ## Always passes (no condition). Default.
	
	# --- Value-gating (self) ---
	SELF_VALUE_ABOVE,            ## get_total_value() >= threshold
	SELF_VALUE_BELOW,            ## get_total_value() <= threshold
	SELF_VALUE_BELOW_HALF_MAX,   ## get_total_value() < die_type / 2
	SELF_VALUE_IS_MAX,           ## current_value == die_type
	SELF_VALUE_IS_MIN,           ## current_value == 1
	
	# --- Value-gating (neighbors) ---
	NEIGHBOR_VALUE_ABOVE,        ## At least one targeted neighbor value >= threshold
	ALL_NEIGHBORS_VALUE_ABOVE,   ## ALL targeted neighbors value >= threshold
	
	# --- Context-gating ---
	NEIGHBORS_USED,              ## Both adjacent hand dice already consumed this turn
	MIN_DICE_USED,               ## context.used_count >= threshold
	MAX_DICE_USED,               ## context.used_count <= threshold
	
	# --- Scaling (always fire, multiply effect_value) ---
	PER_USED_DIE,                ## multiplier = context.used_count
	PER_QUALIFYING_NEIGHBOR,     ## multiplier = count of neighbors with value >= threshold
}

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================

@export var type: Type = Type.NONE

## Threshold used by comparison conditions (e.g., SELF_VALUE_ABOVE 6).
## For PER_QUALIFYING_NEIGHBOR this is the neighbor value threshold.
@export var threshold: float = 0.0

## If true, the condition INVERTS its result (pass → fail, fail → pass).
## Does not apply to scaling conditions.
@export var invert: bool = false

# ============================================================================
# EVALUATION
# ============================================================================

## Result of evaluating a condition.
## blocked = true means the affix should be skipped.
## multiplier is used for scaling conditions (defaults to 1.0).
class Result:
	var blocked: bool = false
	var multiplier: float = 1.0
	
	static func pass_result(mult: float = 1.0) -> Result:
		var r = Result.new()
		r.multiplier = mult
		return r
	
	static func fail_result() -> Result:
		var r = Result.new()
		r.blocked = true
		return r

func evaluate(source_die, dice_array: Array, source_index: int, context: Dictionary) -> Result:
	"""Evaluate this condition given runtime state.
	
	Args:
		source_die: The DieResource that owns this affix.
		dice_array: The full hand/pool array being processed.
		source_index: Index of source_die in dice_array.
		context: Runtime context dict from PlayerDiceCollection.
	
	Returns:
		Result with blocked flag and/or multiplier.
	"""
	if type == Type.NONE:
		return Result.pass_result()
	
	var raw_pass: bool = true
	var multiplier: float = 1.0
	var is_scaling := _is_scaling_type()
	
	match type:
		# --- Self value gates ---
		Type.SELF_VALUE_ABOVE:
			raw_pass = source_die.get_total_value() >= threshold
		
		Type.SELF_VALUE_BELOW:
			raw_pass = source_die.get_total_value() <= threshold
		
		Type.SELF_VALUE_BELOW_HALF_MAX:
			raw_pass = source_die.get_total_value() < (source_die.die_type / 2.0)
		
		Type.SELF_VALUE_IS_MAX:
			raw_pass = source_die.current_value == source_die.die_type
		
		Type.SELF_VALUE_IS_MIN:
			raw_pass = source_die.current_value == 1
		
		# --- Neighbor value gates ---
		Type.NEIGHBOR_VALUE_ABOVE:
			raw_pass = _any_neighbor_above(dice_array, source_index)
		
		Type.ALL_NEIGHBORS_VALUE_ABOVE:
			raw_pass = _all_neighbors_above(dice_array, source_index)
		
		# --- Context gates ---
		Type.NEIGHBORS_USED:
			raw_pass = _both_neighbors_used(dice_array, source_index, context)
		
		Type.MIN_DICE_USED:
			var used = context.get("used_count", 0)
			raw_pass = used >= int(threshold)
		
		Type.MAX_DICE_USED:
			var used = context.get("used_count", 0)
			raw_pass = used <= int(threshold)
		
		# --- Scaling (never blocked, just set multiplier) ---
		Type.PER_USED_DIE:
			multiplier = float(context.get("used_count", 0))
		
		Type.PER_QUALIFYING_NEIGHBOR:
			multiplier = float(_count_qualifying_neighbors(dice_array, source_index))
	
	# Scaling conditions always pass
	if is_scaling:
		return Result.pass_result(multiplier)
	
	# Apply inversion for gating conditions
	if invert:
		raw_pass = not raw_pass
	
	if raw_pass:
		return Result.pass_result()
	else:
		return Result.fail_result()

# ============================================================================
# HELPERS
# ============================================================================

func _is_scaling_type() -> bool:
	return type in [Type.PER_USED_DIE, Type.PER_QUALIFYING_NEIGHBOR]

func is_scaling() -> bool:
	"""Public check — used by processor to know if multiplier applies."""
	return _is_scaling_type()

func _any_neighbor_above(dice_array: Array, idx: int) -> bool:
	if idx > 0 and dice_array[idx - 1].get_total_value() >= threshold:
		return true
	if idx < dice_array.size() - 1 and dice_array[idx + 1].get_total_value() >= threshold:
		return true
	return false

func _all_neighbors_above(dice_array: Array, idx: int) -> bool:
	var checked := 0
	if idx > 0:
		if dice_array[idx - 1].get_total_value() < threshold:
			return false
		checked += 1
	if idx < dice_array.size() - 1:
		if dice_array[idx + 1].get_total_value() < threshold:
			return false
		checked += 1
	return checked > 0  # Must have at least one neighbor

func _both_neighbors_used(dice_array: Array, idx: int, context: Dictionary) -> bool:
	var used_indices: Array = context.get("used_indices", [])
	var has_left := idx > 0
	var has_right := idx < dice_array.size() - 1
	
	if not has_left or not has_right:
		return false  # Edge dice can't have both neighbors
	
	var left_die = dice_array[idx - 1]
	var right_die = dice_array[idx + 1]
	return left_die.slot_index in used_indices and right_die.slot_index in used_indices

func _count_qualifying_neighbors(dice_array: Array, idx: int) -> int:
	var count := 0
	if idx > 0 and dice_array[idx - 1].get_total_value() >= threshold:
		count += 1
	if idx < dice_array.size() - 1 and dice_array[idx + 1].get_total_value() >= threshold:
		count += 1
	return count

# ============================================================================
# DESCRIPTION
# ============================================================================

func get_description() -> String:
	"""Human-readable condition description for tooltips."""
	match type:
		Type.NONE:
			return ""
		Type.SELF_VALUE_ABOVE:
			return "if value ≥ %d" % int(threshold)
		Type.SELF_VALUE_BELOW:
			return "if value ≤ %d" % int(threshold)
		Type.SELF_VALUE_BELOW_HALF_MAX:
			return "if value < half max"
		Type.SELF_VALUE_IS_MAX:
			return "if max roll"
		Type.SELF_VALUE_IS_MIN:
			return "if min roll"
		Type.NEIGHBOR_VALUE_ABOVE:
			return "if any neighbor ≥ %d" % int(threshold)
		Type.ALL_NEIGHBORS_VALUE_ABOVE:
			return "if all neighbors ≥ %d" % int(threshold)
		Type.NEIGHBORS_USED:
			return "if both neighbors used"
		Type.MIN_DICE_USED:
			return "if ≥ %d dice used" % int(threshold)
		Type.MAX_DICE_USED:
			return "if ≤ %d dice used" % int(threshold)
		Type.PER_USED_DIE:
			return "per die used this turn"
		Type.PER_QUALIFYING_NEIGHBOR:
			return "per neighbor ≥ %d" % int(threshold)
	return ""

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"type": type,
		"threshold": threshold,
		"invert": invert,
	}

static func from_dict(data: Dictionary) -> Resource:
	var cond = (load("res://resources/data/dice_affix_condition.gd") as Script).new()
	cond.type = data.get("type", Type.NONE)
	cond.threshold = data.get("threshold", 0.0)
	cond.invert = data.get("invert", false)
	return cond
