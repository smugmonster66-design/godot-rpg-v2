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
	
	# --- Element-gating (v4 — Mana System) ---
	SELF_ELEMENT_IS,             ## source die's effective element == condition_element
	SELF_ELEMENT_NOT,            ## source die's effective element != condition_element
	NEIGHBOR_HAS_ELEMENT,        ## at least one neighbor's effective element == condition_element
	ALL_NEIGHBORS_HAVE_ELEMENT,  ## ALL neighbors' effective element == condition_element
	NEIGHBOR_ELEMENT_DIFFERS,    ## at least one neighbor has a DIFFERENT element from self
	
	# --- Mana context (v4) ---
	MIN_ELEMENT_DICE_USED,       ## context.element_use_counts[condition_element] >= threshold
	
	# --- Mana scaling (v4) ---
	PER_ELEMENT_DIE_USED,        ## multiplier = context.element_use_counts[condition_element]
	PER_DIE_PLACED_THIS_TURN,    ## multiplier = context.used_count (alias for clarity)
	
	# --- Target status (v4 — requires combat context) ---
	TARGET_HAS_STATUS,           ## context.target_statuses has condition_status_id active
	TARGET_STATUS_STACKS_ABOVE,  ## context.target_statuses[condition_status_id].stacks >= threshold
	
	# --- Die-type gates (v5 — Item→Dice bridge) ---
	SELF_DIE_TYPE_IS,            ## source_die.die_type == int(threshold). E.g. threshold=4 → D4 only
	SELF_DIE_TYPE_ABOVE,         ## source_die.die_type >= int(threshold). E.g. threshold=8 → D8, D10, D12, D20
	
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

## Element required by SELF_ELEMENT_IS, NEIGHBOR_HAS_ELEMENT, etc.
## Uses DieResource.Element values as strings: "FIRE", "ICE", "SHOCK", etc.
## Stored as String for inspector friendliness; converted at runtime.
@export var condition_element: String = ""

## Status ID required by TARGET_HAS_STATUS, TARGET_STATUS_STACKS_ABOVE.
## Matches the status_id used in StatusAffix (e.g., "burn", "freeze", "shock").
@export var condition_status_id: String = ""

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
		
		# --- Element-gating (v4) ---
		Type.SELF_ELEMENT_IS:
			raw_pass = _die_element_matches(source_die, condition_element)
		
		Type.SELF_ELEMENT_NOT:
			raw_pass = not _die_element_matches(source_die, condition_element)
		
		Type.NEIGHBOR_HAS_ELEMENT:
			raw_pass = _any_neighbor_has_element(dice_array, source_index, condition_element)
		
		Type.ALL_NEIGHBORS_HAVE_ELEMENT:
			raw_pass = _all_neighbors_have_element(dice_array, source_index, condition_element)
		
		Type.NEIGHBOR_ELEMENT_DIFFERS:
			raw_pass = _any_neighbor_element_differs(dice_array, source_index, source_die)
		
		# --- Mana context (v4) ---
		Type.MIN_ELEMENT_DICE_USED:
			var elem_counts: Dictionary = context.get("element_use_counts", {})
			var elem_enum = DieResource._string_to_element(condition_element)
			raw_pass = elem_counts.get(elem_enum, 0) >= int(threshold)
		
		# --- Mana scaling (v4) ---
		Type.PER_ELEMENT_DIE_USED:
			var elem_counts2: Dictionary = context.get("element_use_counts", {})
			var elem_enum2 = DieResource._string_to_element(condition_element)
			multiplier = float(elem_counts2.get(elem_enum2, 0))
		
		Type.PER_DIE_PLACED_THIS_TURN:
			multiplier = float(context.get("used_count", 0))
		
		# --- Target status (v4) ---
		Type.TARGET_HAS_STATUS:
			var target_statuses: Dictionary = context.get("target_statuses", {})
			raw_pass = target_statuses.has(condition_status_id)
		
		
		# --- Die-type gates (v5) ---
		Type.SELF_DIE_TYPE_IS:
			raw_pass = source_die.die_type == int(threshold)
		
		Type.SELF_DIE_TYPE_ABOVE:
			raw_pass = source_die.die_type >= int(threshold)
		
		
		Type.TARGET_STATUS_STACKS_ABOVE:
			var target_statuses2: Dictionary = context.get("target_statuses", {})
			var status_info = target_statuses2.get(condition_status_id, {})
			var stacks = status_info.get("stacks", 0) if status_info is Dictionary else 0
			raw_pass = stacks >= int(threshold)
	
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
	return type in [
		Type.PER_USED_DIE,
		Type.PER_QUALIFYING_NEIGHBOR,
		Type.PER_ELEMENT_DIE_USED,
		Type.PER_DIE_PLACED_THIS_TURN,
	]


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
# ELEMENT HELPERS (v4 — Mana System)
# ============================================================================

func _die_element_matches(die, element_str: String) -> bool:
	"""Check if a die's effective element matches the condition element string."""
	var target_elem = DieResource._string_to_element(element_str)
	return die.get_effective_element() == target_elem

func _any_neighbor_has_element(dice_array: Array, idx: int, element_str: String) -> bool:
	"""True if at least one adjacent die has the specified element."""
	var target_elem = DieResource._string_to_element(element_str)
	if idx > 0 and dice_array[idx - 1].get_effective_element() == target_elem:
		return true
	if idx < dice_array.size() - 1 and dice_array[idx + 1].get_effective_element() == target_elem:
		return true
	return false

func _all_neighbors_have_element(dice_array: Array, idx: int, element_str: String) -> bool:
	"""True if ALL adjacent dice have the specified element. Must have at least one neighbor."""
	var target_elem = DieResource._string_to_element(element_str)
	var checked := 0
	if idx > 0:
		if dice_array[idx - 1].get_effective_element() != target_elem:
			return false
		checked += 1
	if idx < dice_array.size() - 1:
		if dice_array[idx + 1].get_effective_element() != target_elem:
			return false
		checked += 1
	return checked > 0

func _any_neighbor_element_differs(dice_array: Array, idx: int, source_die) -> bool:
	"""True if at least one adjacent die has a DIFFERENT element from source."""
	var self_elem = source_die.get_effective_element()
	if idx > 0 and dice_array[idx - 1].get_effective_element() != self_elem:
		return true
	if idx < dice_array.size() - 1 and dice_array[idx + 1].get_effective_element() != self_elem:
		return true
	return false

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
		# --- v4 ---
		Type.SELF_ELEMENT_IS:
			return "if %s element" % condition_element
		Type.SELF_ELEMENT_NOT:
			return "if not %s element" % condition_element
		Type.NEIGHBOR_HAS_ELEMENT:
			if condition_element == "MATCH_SELF":
				return "if neighbor shares element"
			return "if neighbor is %s" % condition_element
		Type.ALL_NEIGHBORS_HAVE_ELEMENT:
			if condition_element == "MATCH_SELF":
				return "if all neighbors share element"
			return "if all neighbors %s" % condition_element
		Type.NEIGHBOR_ELEMENT_DIFFERS:
			return "if neighbor differs in element"
		Type.MIN_ELEMENT_DICE_USED:
			return "if ≥ %d %s dice used" % [int(threshold), condition_element]
		Type.PER_ELEMENT_DIE_USED:
			return "per %s die used" % condition_element
		Type.PER_DIE_PLACED_THIS_TURN:
			return "per die placed this turn"
		Type.TARGET_HAS_STATUS:
			return "if target has %s" % condition_status_id
		Type.TARGET_STATUS_STACKS_ABOVE:
			return "if target %s stacks ≥ %d" % [condition_status_id, int(threshold)]
		Type.SELF_DIE_TYPE_IS:
			return "if D%d" % int(threshold)
		Type.SELF_DIE_TYPE_ABOVE:
			return "if D%d or higher" % int(threshold)
	return ""
# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"type": type,
		"threshold": threshold,
		"invert": invert,
		"condition_element": condition_element,
		"condition_status_id": condition_status_id,
	}

static func from_dict(data: Dictionary) -> Resource:
	var cond = (load("res://resources/data/dice_affix_condition.gd") as Script).new()
	cond.type = data.get("type", Type.NONE)
	cond.threshold = data.get("threshold", 0.0)
	cond.invert = data.get("invert", false)
	cond.condition_element = data.get("condition_element", "")
	cond.condition_status_id = data.get("condition_status_id", "")
	return cond
