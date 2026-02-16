# res://resources/data/affix.gd
# Standalone affix resource with category-based effects.
#
# v2 CHANGELOG:
#   - Added ValueSource enum for dynamic value resolution
#   - Added AffixCondition support (gating + scaling)
#   - Added AffixSubEffect support (compound affixes)
#   - Added tags array for filtering and interaction queries
#   - Added ProcTrigger enum and proc configuration
#   - apply_effect() now accepts optional context for dynamic resolution
#   - Full backwards compatibility: existing .tres files work unchanged
#
# v3 CHANGELOG (Item Level Scaling):
#   - roll_value() now accepts power_position + AffixScalingConfig
#   - Added has_scaling(), get_rolled_value_string(), _is_multiplier_category()
#   - Updated get_value_range_string() for multiplier formatting
#   - Hybrid fuzz: percentage-based + absolute minimum floor
#   - Multiplier categories auto-detected for 2-decimal rounding
#
extends Resource
class_name Affix

# ============================================================================
# CATEGORY ENUM
# ============================================================================
enum Category {
	NONE,
	# Stat Bonuses (flat)
	STRENGTH_BONUS,
	AGILITY_BONUS,
	INTELLECT_BONUS,
	LUCK_BONUS,
	# Stat Multipliers
	STRENGTH_MULTIPLIER,
	AGILITY_MULTIPLIER,
	INTELLECT_MULTIPLIER,
	LUCK_MULTIPLIER,
	# Global Combat Modifiers
	DAMAGE_BONUS,
	DAMAGE_MULTIPLIER,
	DEFENSE_BONUS,
	DEFENSE_MULTIPLIER,
	# Physical Defense
	ARMOR_BONUS,
	# Elemental Resistances
	FIRE_RESIST_BONUS,
	ICE_RESIST_BONUS,
	SHOCK_RESIST_BONUS,
	POISON_RESIST_BONUS,
	SHADOW_RESIST_BONUS,
	# Type-Specific Damage Bonuses
	SLASHING_DAMAGE_BONUS,
	BLUNT_DAMAGE_BONUS,
	PIERCING_DAMAGE_BONUS,
	FIRE_DAMAGE_BONUS,
	ICE_DAMAGE_BONUS,
	SHOCK_DAMAGE_BONUS,
	POISON_DAMAGE_BONUS,
	SHADOW_DAMAGE_BONUS,
	# Other
	BARRIER_BONUS,
	HEALTH_BONUS,
	MANA_BONUS,
	# Special
	ELEMENTAL,
	NEW_ACTION,
	DICE,
	PER_TURN,
	ON_HIT,
	PROC,
	MISC,
	# ── Mana System (v4) ──
	MANA_ELEMENT_UNLOCK,         ## Unlocks an element for mana die. effect_data: {"element": "FIRE"}
	MANA_SIZE_UNLOCK,            ## Unlocks a die size for mana die. effect_data: {"die_size": 4}
	MANA_DIE_AFFIX,              ## DiceAffix applied to every pulled mana die. effect_data: {"dice_affix": DiceAffix}
	MANA_COST_MULTIPLIER,        ## Multiplies mana pull costs. 0.8 = 20% cheaper.
	# ── Elemental Combat Modifiers (v4) ──
	ELEMENTAL_DAMAGE_MULTIPLIER, ## Multiplies damage of a specific element. effect_data: {"element": "FIRE"}
	STATUS_DAMAGE_MULTIPLIER,    ## Multiplies damage to targets with a status. effect_data: {"status_id": "burn"}
	RESISTANCE_BYPASS,           ## Flat resistance bypass for an element.
	# ── Skill Rank Bonuses (v5) ──
	SKILL_RANK_BONUS,            ## +N to a specific skill. effect_data: {"skill_id": "flame_inferno"}
	TREE_SKILL_RANK_BONUS,       ## +N to all skills in a tree. effect_data: {"tree_id": "mage_flame"}
	CLASS_SKILL_RANK_BONUS,      ## +N to all class skills. effect_data: {"class_id": "mage"}
	TAG_SKILL_RANK_BONUS,        ## +N to all skills with a tag. effect_data: {"tag": "fire"}
	# ── Action-Scoped Bonuses (v6) ──
	ACTION_DAMAGE_BONUS,         ## +N flat damage to a specific action. effect_data: {"action_id": "fireball"}
	ACTION_DAMAGE_MULTIPLIER,    ## ×N damage to a specific action. effect_data: {"action_id": "fireball"}
	ACTION_BASE_DAMAGE_BONUS,    ## +N base damage to a specific action. effect_data: {"action_id": "fireball"}
	ACTION_DIE_SLOT_BONUS,       ## +N die slots to a specific action. effect_data: {"action_id": "fireball"}
	ACTION_EFFECT_UPGRADE,       ## Adds/modifies an effect on a specific action. effect_data: {"action_id": "fireball", "extra_effect": ActionEffect}
	# ── Class Action Modifiers (v6) ──
	CLASS_ACTION_STAT_MOD,       ## Modifies a numeric property on the class action.
								 ## effect_data: {"property": String, "operation": "add"|"multiply"}
								 ## effect_number = the value to add or multiply by.
	CLASS_ACTION_EFFECT_ADD,     ## Appends an ActionEffect to the class action's effect chain.
								 ## effect_data: {"action_effect": ActionEffect}
	CLASS_ACTION_EFFECT_REPLACE, ## Replaces an ActionEffect at a specific index.
								 ## effect_data: {"effect_index": int, "action_effect": ActionEffect}
	CLASS_ACTION_UPGRADE,        ## Wholesale replaces the class action with a new Action.
								 ## Uses existing granted_action field.
	CLASS_ACTION_CONDITIONAL,    ## Adds a conditional rider effect to the class action.
								 ## effect_data: {"condition": AffixCondition, "action_effect": ActionEffect}
}

# ============================================================================
# VALUE SOURCE ENUM (v2)
# ============================================================================
enum ValueSource {
	STATIC,                  ## Use effect_number as-is (default, backwards-compatible)
	PLAYER_STAT,             ## Named stat × effect_number (stat_name in effect_data)
	PLAYER_HEALTH_PERCENT,   ## (current_hp / max_hp) × effect_number
	EQUIPPED_ITEM_COUNT,     ## Filled equipment slots × effect_number
	ACTIVE_AFFIX_COUNT,      ## Affixes in a category × effect_number (count_category in effect_data)
	EQUIPMENT_RARITY_SUM,    ## Sum of equipped rarity values × effect_number
	DICE_POOL_SIZE,          ## Dice in pool × effect_number
	COMBAT_TURN_NUMBER,      ## Current turn × effect_number
	UNIQUE_ELEMENTS_USED,    ## Unique elements consumed this turn × effect_number
}

# ============================================================================
# PROC TRIGGER ENUM (v2)
# ============================================================================
enum ProcTrigger {
	NONE,               ## Not a proc — skip during proc processing
	ON_DEAL_DAMAGE,     ## After player deals damage to any target
	ON_TAKE_DAMAGE,     ## After player takes damage
	ON_TURN_START,      ## Start of player's turn
	ON_TURN_END,        ## End of player's turn
	ON_COMBAT_START,    ## When combat begins
	ON_COMBAT_END,      ## When combat ends
	ON_DIE_USED,        ## When any die is consumed from hand
	ON_ACTION_USED,     ## When any action is executed
	ON_KILL,            ## When player kills an enemy
	ON_DEFEND,          ## When player uses a defend action
}


# ============================================================================
# ROUNDING MODE ENUM (v4)
# ============================================================================
enum RoundMode {
	AUTO,       ## Integer for flat bonuses, 2-decimal for multiplier categories (legacy default)
	INTEGER,    ## Always round to nearest integer (flat stats, armor, health, damage)
	DECIMAL_2,  ## Always snap to 2 decimal places (percentages, proc chances, multipliers)
}



# ============================================================================
# BASIC DATA
# ============================================================================
@export var affix_name: String = "New Affix"
@export_multiline var description: String = "An affix effect"
@export var icon: Texture2D = null

# ============================================================================
# DISPLAY OPTIONS
# ============================================================================
@export_group("Display")
## Whether this affix appears in item summary tooltips
@export var show_in_summary: bool = true
@export var show_in_active_list: bool = true

@export var has_elemental_identity: bool = false
@export var elemental_identity: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

# ============================================================================
# CATEGORIZATION
# ============================================================================
@export var category: Category = Category.NONE

# ============================================================================
# TAGS (v2) — For filtering, interaction queries, and UI grouping
# ============================================================================
@export_group("Tags")
## Tags for filtering and interaction. Examples: "weapon", "physical",
## "mastery", "fire", "defensive", "set_bonus", "temporary"
@export var tags: Array[String] = []

# ============================================================================
# SOURCE TRACKING
# ============================================================================
@export_group("Source")
## Name of the item/skill/set that granted this affix
var source: String = ""
## Type of source: "item", "skill", "set", "proc", "proc_temp", "proc_stack"
var source_type: String = ""

# ============================================================================
# CONDITION (v2) — Checked before effect application
# ============================================================================
@export_group("Condition")
## Optional condition resource. If null or NONE, affix always applies.
## Drag an AffixCondition resource here to gate or scale this affix.
@export var condition: AffixCondition = null

# ============================================================================
# EFFECT DATA
# ============================================================================
@export_group("Effect Values")

## For simple numeric bonuses/multipliers
@export var effect_number: float = 0.0

## Minimum possible value across the entire game (level 1 item).
## Set to 0.0 to disable scaling (affix uses static effect_number).
@export var effect_min: float = 0.0

## Maximum possible value across the entire game (level 100 item).
## Set to 0.0 to disable scaling (affix uses static effect_number).
@export var effect_max: float = 0.0

## Optional per-affix scaling curve. Overrides the global curve from
## AffixScalingConfig when set. Leave null to use the global curve.
@export var effect_curve: Curve = null

## Per-affix fuzz override. Set to -1.0 to use the global default.
## 0.0 = deterministic (same level = same value), 0.2 = ±20% spread.
@export_range(-1.0, 1.0) var roll_fuzz: float = -1.0

## How rolled values are rounded. AUTO uses legacy behavior (multiplier
## categories get 2 decimals, everything else rounds to integer).
## Set to DECIMAL_2 for percentage-scale affixes (proc chances, gold find, etc.)
## to prevent fractional values (e.g. 0.25) from rounding to 0.
@export var rounding_mode: RoundMode = RoundMode.AUTO


## Where does the effect magnitude come from? (v2)
## STATIC uses effect_number literally. Others derive at runtime.
@export var value_source: ValueSource = ValueSource.STATIC
## For complex effects that need multiple values
@export var effect_data: Dictionary = {}

# ============================================================================
# PROC CONFIGURATION (v2)
# ============================================================================
@export_group("Proc Configuration")
## When this proc triggers. Only checked for PROC, ON_HIT, PER_TURN categories.
@export var proc_trigger: ProcTrigger = ProcTrigger.NONE
## Probability the proc fires when triggered (0.0 to 1.0).
@export_range(0.0, 1.0) var proc_chance: float = 1.0
## Minimum proc chance across the full item level range (level 1).
## Set both min and max to 0.0 to use static proc_chance instead.
@export_range(0.0, 1.0) var proc_chance_min: float = 0.0

## Maximum proc chance across the full item level range (level 100).
@export_range(0.0, 1.0) var proc_chance_max: float = 0.0
# ============================================================================
# GRANTED ACTION (for NEW_ACTION category)
# ============================================================================
@export_group("Granted Action")
## Drag an Action resource here if this affix grants a combat action
@export var granted_action: Action = null

# ============================================================================
# GRANTED DICE (for DICE category)
# ============================================================================
@export_group("Granted Dice")
## Dice added to the player's pool when this affix is active.
@export var granted_dice: Array[DieResource] = []

# ============================================================================
# DICE VISUAL EFFECTS
# ============================================================================
@export_group("Dice Visual Effects")
## Optional DiceAffix to apply visual effects to dice granted by this item
@export var dice_visual_affix: DiceAffix = null

# ============================================================================
# SUB-EFFECTS (v2) — Compound effects
# ============================================================================
@export_group("Sub-Effects (Compound)")
## When non-empty, the evaluator iterates these INSTEAD of the top-level
## effect. Each AffixSubEffect has its own category, value, value source,
## and optional condition override.
@export var sub_effects: Array[AffixSubEffect] = []

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func apply_effect(context: Dictionary = {}) -> Variant:
	"""Apply this affix's effect and return the result.
	
	v2: Now accepts optional context for dynamic value resolution and
	condition checking. Fully backwards-compatible — calling with no
	args behaves identically to the original.
	
	Args:
		context: Runtime state dictionary (player, equipment, combat state).
				 Empty dict = STATIC resolution only (original behavior).
	"""
	# If this grants an action, return it
	if granted_action and category == Category.NEW_ACTION:
		return granted_action
	
	# If this grants dice, return them
	if granted_dice.size() > 0 and category == Category.DICE:
		return granted_dice
	
	# Resolve value (v2: dynamic resolution)
	var value = resolve_value(context)
	
	if value != 0.0:
		return value
	elif effect_data.size() > 0:
		return effect_data
	
	return 0.0

func resolve_value(context: Dictionary = {}) -> float:
	"""Resolve the numeric value using the configured value source.
	
	If no context is provided, falls back to STATIC (effect_number).
	If a condition is attached, applies its multiplier (for scaling conditions).
	"""
	var base_value: float = _resolve_raw_value(context)
	
	# Apply condition multiplier (for scaling conditions like PER_EQUIPPED_ITEM)
	if condition and context.size() > 0:
		var cond_result = condition.evaluate(context)
		if cond_result.blocked:
			return 0.0  # Condition not met — no effect
		base_value *= cond_result.multiplier
	
	return base_value

func _resolve_raw_value(context: Dictionary) -> float:
	"""Internal: resolve value from value_source without condition."""
	if value_source == ValueSource.STATIC or context.is_empty():
		return effect_number
	
	var player = context.get("player", null)
	
	match value_source:
		ValueSource.PLAYER_STAT:
			var stat_name = effect_data.get("stat_name", "strength")
			return _get_stat(player, stat_name) * effect_number
		
		ValueSource.PLAYER_HEALTH_PERCENT:
			var hp_pct = _get_health_percent(player, context)
			return hp_pct * effect_number
		
		ValueSource.EQUIPPED_ITEM_COUNT:
			return float(_count_equipped(player)) * effect_number
		
		ValueSource.ACTIVE_AFFIX_COUNT:
			var cat_name = effect_data.get("count_category", "NONE")
			var mgr = context.get("affix_manager", null)
			return float(_count_in_category(mgr, cat_name)) * effect_number
		
		ValueSource.EQUIPMENT_RARITY_SUM:
			return float(_sum_rarity(player)) * effect_number
		
		ValueSource.DICE_POOL_SIZE:
			var pool = context.get("dice_pool", null)
			var count = pool.dice.size() if pool and "dice" in pool else 0
			return float(count) * effect_number
		
		ValueSource.COMBAT_TURN_NUMBER:
			return float(context.get("turn_number", 0)) * effect_number
		
		_:
			return effect_number

# ============================================================================
# ITEM LEVEL SCALING (v3)
# ============================================================================

func roll_value(power_position: float = -1.0, scaling_config: AffixScalingConfig = null) -> float:
	"""Roll a value for this affix based on a power position (0.0–1.0).
	
	The power position is typically derived from item_level via
	AffixScalingConfig.get_power_position(). This method:
	  1. Maps power_position to a center value within effect_min → effect_max
	  2. Applies per-affix curve override if set
	  3. Adds hybrid fuzz (percentage + absolute minimum) for randomness
	  4. Rounds appropriately (integers for flat bonuses, 2 decimals for multipliers)
	  5. Stamps the result into effect_number for runtime use
	
	Args:
		power_position: 0.0 (weakest) to 1.0 (strongest). From scaling config.
						Pass -1.0 (or omit) for legacy random roll behavior.
		scaling_config: Global scaling config for fuzz defaults. Can be null.
	
	Returns:
		The rolled value (also stored in effect_number).
	"""
	# Skip scaling for static affixes (no min/max defined)
	if effect_min == 0.0 and effect_max == 0.0:
		return effect_number
	
	# Legacy behavior: no power_position provided → pure random within range
	if power_position < 0.0:
		var t: float = randf()
		if effect_curve:
			t = effect_curve.sample(t)
		effect_number = lerpf(effect_min, effect_max, t)
		effect_number = _round_value(effect_number)
		return effect_number
	
	# Step 1: Apply per-affix curve override (if any)
	var t_curved: float = power_position
	if effect_curve:
		t_curved = effect_curve.sample(power_position)
	
	# Step 2: Map to center value
	var center: float = lerpf(effect_min, effect_max, t_curved)
	
	# Step 3: Compute fuzz range (hybrid: percentage + absolute minimum)
	var roll_min: float = center
	var roll_max: float = center
	
	if scaling_config:
		var fuzz_range = scaling_config.compute_fuzz_range(
			center, effect_min, effect_max,
			roll_fuzz  # -1.0 = use global default
		)
		roll_min = fuzz_range.min
		roll_max = fuzz_range.max
	elif roll_fuzz > 0.0:
		# No config available — use per-affix fuzz directly
		var total_range: float = effect_max - effect_min
		var fuzz_amount: float = maxf(total_range * roll_fuzz, 1.0)
		roll_min = maxf(effect_min, center - fuzz_amount)
		roll_max = minf(effect_max, center + fuzz_amount)
	
	# Step 4: Roll within fuzz range
	var rolled: float = randf_range(roll_min, roll_max)
	
	# Step 5: Round appropriately
	# Multipliers (values near 1.x) get 2 decimal places
	# Everything else rounds to integers
	effect_number = _round_value(effect_number)
	
	return effect_number


func has_scaling() -> bool:
	"""Check if this affix uses level-based scaling (has min/max defined)."""
	return not (effect_min == 0.0 and effect_max == 0.0)

func roll_proc_chance(power_position: float = -1.0, scaling_config: AffixScalingConfig = null) -> float:
	"""Roll proc_chance based on item level, same curve logic as roll_value().

	If proc_chance_min and proc_chance_max are both 0.0, proc_chance is
	left unchanged (static). Otherwise, scales proc_chance within the
	min/max range using the same power_position and fuzz system.

	Args:
		power_position: 0.0 (weakest) to 1.0 (strongest). From scaling config.
						Pass -1.0 (or omit) for legacy random roll behavior.
		scaling_config: Global scaling config for fuzz defaults. Can be null.

	Returns:
		The rolled proc_chance (also stored in proc_chance).
	"""
	if not has_proc_chance_scaling():
		return proc_chance

	# Legacy behavior: no power_position → pure random
	if power_position < 0.0:
		var t: float = randf()
		if effect_curve:
			t = effect_curve.sample(t)
		proc_chance = snappedf(lerpf(proc_chance_min, proc_chance_max, t), 0.01)
		return proc_chance

	# Scaled behavior: mirrors roll_value() steps 1-4
	var t_curved: float = power_position
	if effect_curve:
		t_curved = effect_curve.sample(power_position)

	var center: float = lerpf(proc_chance_min, proc_chance_max, t_curved)

	var roll_min_v: float = center
	var roll_max_v: float = center

	if scaling_config:
		var fuzz_range = scaling_config.compute_fuzz_range(
			center, proc_chance_min, proc_chance_max,
			roll_fuzz
		)
		roll_min_v = fuzz_range.min
		roll_max_v = fuzz_range.max
	elif roll_fuzz > 0.0:
		var total_range: float = proc_chance_max - proc_chance_min
		var fuzz_amount: float = maxf(total_range * roll_fuzz, 0.01)
		roll_min_v = maxf(proc_chance_min, center - fuzz_amount)
		roll_max_v = minf(proc_chance_max, center + fuzz_amount)

	proc_chance = clampf(
		snappedf(randf_range(roll_min_v, roll_max_v), 0.01),
		0.0, 1.0
	)
	return proc_chance


func has_proc_chance_scaling() -> bool:
	"""Check if this affix uses level-based proc chance scaling."""
	return not (proc_chance_min == 0.0 and proc_chance_max == 0.0)







func get_value_range_string() -> String:
	"""Get a human-readable string showing the value range.

	Returns:
		"5" for static, "1–8" for scaled, "1.05×–1.40×" for multipliers,
		"5%–25%" for DECIMAL_2 percentage affixes.
	"""
	if not has_scaling():
		if _is_multiplier_category():
			return "%.2f×" % effect_number
		if rounding_mode == RoundMode.DECIMAL_2:
			return "%d%%" % int(effect_number * 100)
		return str(int(effect_number))

	if _is_multiplier_category():
		return "%.2f×–%.2f×" % [effect_min, effect_max]
	if rounding_mode == RoundMode.DECIMAL_2:
		return "%d%%–%d%%" % [int(effect_min * 100), int(effect_max * 100)]
	return "%d–%d" % [int(effect_min), int(effect_max)]


func get_rolled_value_string() -> String:
	"""Get the current rolled value as a display string.

	Returns:
		"+5" for flat bonuses, "×1.25" for multipliers, "25%" for DECIMAL_2.
	"""
	if _is_multiplier_category():
		return "×%.2f" % effect_number
	if rounding_mode == RoundMode.DECIMAL_2:
		return "%d%%" % int(effect_number * 100)
	return "+%d" % int(effect_number)


func get_resolved_description() -> String:
	"""Get description with 'N' replaced by the actual rolled value.

	Handles formatting by rounding mode and category:
	  - Multipliers: "×1.25"
	  - DECIMAL_2: "25%"
	  - Flat bonuses: "7"
	"""
	if description.is_empty():
		return ""

	var value_str: String
	if _is_multiplier_category():
		value_str = "%.2f" % effect_number
	elif rounding_mode == RoundMode.DECIMAL_2:
		value_str = "%d%%" % int(effect_number * 100)
	elif effect_number > 0.0 and effect_number < 1.0:
		# Legacy fallback for untagged percentage affixes
		value_str = "%d%%" % int(effect_number * 100)
	else:
		value_str = str(int(effect_number))

	return description.replace("N", value_str)

func _is_multiplier_category() -> bool:
	"""Check if this affix's category is a multiplier type."""
	return category in [
		Category.STRENGTH_MULTIPLIER,
		Category.AGILITY_MULTIPLIER,
		Category.INTELLECT_MULTIPLIER,
		Category.LUCK_MULTIPLIER,
		Category.DAMAGE_MULTIPLIER,
		Category.DEFENSE_MULTIPLIER,
	]

func _round_value(value: float) -> float:
	"""Round a value according to this affix's rounding_mode.

	AUTO preserves legacy behavior: multiplier categories get 2 decimals,
	everything else rounds to integer. INTEGER and DECIMAL_2 override
	regardless of category.
	"""
	match rounding_mode:
		RoundMode.INTEGER:
			return roundf(value)
		RoundMode.DECIMAL_2:
			return snappedf(value, 0.01)
		_:  # AUTO
			if _is_multiplier_category():
				return snappedf(value, 0.01)
			return roundf(value)

func get_proc_chance_range_string() -> String:
	"""Get human-readable proc chance range for tooltips.

	Returns:
		"25%" for static, "10%–40%" for scaled.
	"""
	if not has_proc_chance_scaling():
		return "%d%%" % int(proc_chance * 100)
	return "%d%%–%d%%" % [int(proc_chance_min * 100), int(proc_chance_max * 100)]

# ============================================================================
# CONDITION HELPERS (v2)
# ============================================================================

func has_condition() -> bool:
	"""Check if this affix has a non-trivial condition."""
	return condition != null and condition.type != AffixCondition.Type.NONE

func check_condition(context: Dictionary) -> bool:
	"""Check if this affix's condition is met. Returns true if no condition."""
	if not has_condition():
		return true
	var result = condition.evaluate(context)
	return not result.blocked

func get_condition_multiplier(context: Dictionary) -> float:
	"""Get the scaling multiplier from condition. Returns 1.0 if none."""
	if not has_condition():
		return 1.0
	var result = condition.evaluate(context)
	return result.multiplier

# ============================================================================
# COMPOUND EFFECT HELPERS (v2)
# ============================================================================

func is_compound() -> bool:
	"""Check if this affix uses sub-effects instead of a single effect."""
	return sub_effects.size() > 0

func get_sub_effect_count() -> int:
	return sub_effects.size()

# ============================================================================
# TAG HELPERS (v2)
# ============================================================================

func has_tag(tag: String) -> bool:
	"""Check if this affix has a specific tag."""
	return tag in tags

func has_any_tag(check_tags: Array[String]) -> bool:
	"""Check if this affix has any of the given tags."""
	for tag in check_tags:
		if tag in tags:
			return true
	return false

func has_all_tags(check_tags: Array[String]) -> bool:
	"""Check if this affix has ALL of the given tags."""
	for tag in check_tags:
		if tag not in tags:
			return false
	return true

func add_tag(tag: String):
	"""Add a tag if not already present."""
	if tag not in tags:
		tags.append(tag)

func remove_tag(tag: String):
	"""Remove a tag if present."""
	tags.erase(tag)

# ============================================================================
# STACKING
# ============================================================================

func can_stack_with(other_affix: Affix) -> bool:
	"""Check if this affix can stack with another"""
	if affix_name != other_affix.affix_name:
		return true
	return source != other_affix.source

# ============================================================================
# DICE VISUAL HELPERS
# ============================================================================

func has_visual_effects() -> bool:
	"""Check if this affix includes visual effects for dice"""
	return dice_visual_affix != null and dice_visual_affix.has_any_visual_effect()

func get_dice_visual_affix() -> DiceAffix:
	"""Get the DiceAffix for visual effects (may be null)"""
	return dice_visual_affix

# ============================================================================
# CATEGORY HELPERS
# ============================================================================

func is_category(check_category: Category) -> bool:
	return category == check_category

func get_category_name() -> String:
	return Category.keys()[category].capitalize().replace("_", " ")

func is_proc_category() -> bool:
	"""Check if this affix is in a proc-capable category."""
	return category in [Category.PROC, Category.ON_HIT, Category.PER_TURN]

# ============================================================================
# ELEMENTAL IDENTITY
# ============================================================================

func get_elemental_identity() -> ActionEffect.DamageType:
	"""Returns this affix's element, or -1 if none is set."""
	if has_elemental_identity:
		return elemental_identity
	return -1

# ============================================================================
# UTILITY
# ============================================================================

func duplicate_with_source(p_source: String, p_source_type: String) -> Affix:
	"""Create a copy of this affix with a specific source"""
	var copy = duplicate(true)
	copy.source = p_source
	copy.source_type = p_source_type
	return copy

func matches_source(p_source: String) -> bool:
	return source == p_source

func get_display_text() -> String:
	var text = affix_name
	if source:
		text += " (from %s)" % source
	return text

func get_value_description() -> String:
	"""Get a description of how the value is resolved."""
	if value_source == ValueSource.STATIC:
		return str(effect_number)
	var src_name = ValueSource.keys()[value_source].replace("_", " ").to_lower()
	return "%s × %s" % [effect_number, src_name]

func get_full_description() -> String:
	"""Get complete description including condition and value source."""
	var parts: Array[String] = []
	if description != "":
		parts.append(description)
	if has_condition():
		parts.append("[%s]" % condition.get_description())
	if value_source != ValueSource.STATIC:
		parts.append("(%s)" % get_value_description())
	return " ".join(parts) if parts.size() > 0 else affix_name

func _to_string() -> String:
	return "Affix<%s: %s>" % [affix_name, get_category_name()]

# ============================================================================
# VALUE RESOLUTION HELPERS (private)
# ============================================================================

func _get_stat(player, stat_name: String) -> float:
	if not player:
		return 0.0
	if not player is Dictionary and player.has_method("get_stat"):
		return float(player.get_stat(stat_name))
	if player is Dictionary:
		return float(player.get(stat_name, 0))
	if stat_name in player:
		return float(player.get(stat_name))
	return 0.0

func _get_health_percent(player, context: Dictionary) -> float:
	var source_combatant = context.get("source", null)
	if source_combatant and source_combatant.has_method("get_health_percent"):
		return source_combatant.get_health_percent()
	if player and player.get("max_hp") and player.max_hp > 0:
		return float(player.current_hp) / float(player.max_hp)
	return 1.0

func _count_equipped(player) -> int:
	if not player:
		return 0
	var count = 0
	for slot in player.equipment:
		if player.equipment[slot] != null:
			count += 1
	return count

func _sum_rarity(player) -> int:
	if not player:
		return 0
	var total = 0
	for slot in player.equipment:
		var item = player.equipment[slot]
		if item:
			total += item.get("rarity", 0)
	return total

func _count_in_category(affix_manager, category_name: String) -> int:
	if not affix_manager:
		return 0
	if category_name in Affix.Category:
		return affix_manager.get_pool(Affix.Category.get(category_name)).size()
	return 0
