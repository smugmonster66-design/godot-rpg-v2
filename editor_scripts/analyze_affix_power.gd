# res://editor_scripts/analyze_affix_power.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# Analyzes every equipment affix at 6 item-level scale points (1, 10, 20, 50, 70, 100).
# For each affix, simulates a deterministic roll (no fuzz) and prints a table showing
# scaled values, proc chances, and current power_weight assignment status.
#
# Output is grouped by category family (offense, defense, utility, class, special).
# Affixes with power_weight == 0.0 are marked UNRATED.
@tool
extends EditorScript

const SCALING_PATH := "res://resources/scaling/affix_scaling_config.tres"

const AFFIX_DIRS: Array[String] = [
	"res://resources/affixes/base/",
	"res://resources/affixes/classes/",
	"res://resources/affixes/gloves/",
	"res://resources/affixes/weapon/",
]

const SCALE_POINTS: Array[int] = [1, 10, 20, 50, 70, 100]

# Category families for grouping output
const OFFENSE_CATEGORIES: Array[int] = [
	Affix.Category.DAMAGE_BONUS,
	Affix.Category.DAMAGE_MULTIPLIER,
	Affix.Category.SLASHING_DAMAGE_BONUS,
	Affix.Category.BLUNT_DAMAGE_BONUS,
	Affix.Category.PIERCING_DAMAGE_BONUS,
	Affix.Category.FIRE_DAMAGE_BONUS,
	Affix.Category.ICE_DAMAGE_BONUS,
	Affix.Category.SHOCK_DAMAGE_BONUS,
	Affix.Category.POISON_DAMAGE_BONUS,
	Affix.Category.SHADOW_DAMAGE_BONUS,
	Affix.Category.ON_HIT,
	Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
	Affix.Category.STATUS_DAMAGE_MULTIPLIER,
	Affix.Category.RESISTANCE_BYPASS,
	Affix.Category.HEALING_BONUS,
	Affix.Category.HEALING_MULTIPLIER,
]

const DEFENSE_CATEGORIES: Array[int] = [
	Affix.Category.ARMOR_BONUS,
	Affix.Category.DEFENSE_MULTIPLIER,
	Affix.Category.BARRIER_BONUS,
	Affix.Category.HEALTH_BONUS,
	Affix.Category.FIRE_RESIST_BONUS,
	Affix.Category.ICE_RESIST_BONUS,
	Affix.Category.SHOCK_RESIST_BONUS,
	Affix.Category.POISON_RESIST_BONUS,
	Affix.Category.SHADOW_RESIST_BONUS,
]

const UTILITY_CATEGORIES: Array[int] = [
	Affix.Category.STRENGTH_BONUS,
	Affix.Category.AGILITY_BONUS,
	Affix.Category.INTELLECT_BONUS,
	Affix.Category.LUCK_BONUS,
	Affix.Category.STRENGTH_MULTIPLIER,
	Affix.Category.AGILITY_MULTIPLIER,
	Affix.Category.INTELLECT_MULTIPLIER,
	Affix.Category.LUCK_MULTIPLIER,
	Affix.Category.MANA_BONUS,
	Affix.Category.MANA_COST_MULTIPLIER,
	Affix.Category.MANA_ELEMENT_UNLOCK,
	Affix.Category.MANA_SIZE_UNLOCK,
]

const SPECIAL_CATEGORIES: Array[int] = [
	Affix.Category.NEW_ACTION,
	Affix.Category.DICE,
	Affix.Category.PROC,
	Affix.Category.PER_TURN,
	Affix.Category.ELEMENTAL,
	Affix.Category.MISC,
	Affix.Category.MANA_DIE_AFFIX,
]

var _all_affixes: Array = []  # Array of Affix (untyped to handle placeholders)
var _rated_count: int = 0
var _unrated_count: int = 0
# Pre-computed power positions for each scale point (avoids calling methods on placeholders)
var _power_positions: Dictionary = {}

func _run() -> void:
	_rated_count = 0
	_unrated_count = 0

	# Load scaling config and pre-compute power positions using only exported properties
	var config = load(SCALING_PATH)
	if not config:
		printerr("ERROR: Could not load AffixScalingConfig from %s" % SCALING_PATH)
		return

	var max_level: int = config.max_item_level if config.max_item_level > 0 else 100
	var curve: Curve = config.global_scaling_curve
	for lvl in SCALE_POINTS:
		var t_normalized: float = clampf(
			float(lvl - 1) / float(max(max_level - 1, 1)), 0.0, 1.0)
		if curve:
			_power_positions[lvl] = curve.sample(t_normalized)
		else:
			_power_positions[lvl] = t_normalized  # Linear fallback

	# Collect all affixes
	_all_affixes = []
	for dir_path in AFFIX_DIRS:
		_collect_affixes_recursive(dir_path)

	print("\n" + "=".repeat(120))
	print("  AFFIX POWER ANALYSIS — %d affixes found" % _all_affixes.size())
	print("  Scale points: %s" % str(SCALE_POINTS))
	print("=".repeat(120))

	_print_family("OFFENSE", OFFENSE_CATEGORIES)
	_print_family("DEFENSE", DEFENSE_CATEGORIES)
	_print_family("UTILITY / STATS", UTILITY_CATEGORIES)
	_print_family("SPECIAL / GRANTED", SPECIAL_CATEGORIES)
	_print_family("CLASS / ACTION / SKILL", [])  # Catch-all for remaining

	print("\n" + "=".repeat(120))
	print("  SUMMARY: %d rated, %d unrated, %d total" % [_rated_count, _unrated_count, _rated_count + _unrated_count])
	print("=".repeat(120) + "\n")


func _collect_affixes_recursive(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_affixes_recursive(full_path)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			# Accept both proper Affix instances and placeholder Resources
			# that have the affix_name property (script not in tool mode)
			if res is Affix or (res is Resource and "affix_name" in res):
				_all_affixes.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _print_family(family_name: String, categories: Array[int]) -> void:
	# Collect affixes for this family
	var family_affixes: Array = []

	if categories.size() == 0:
		# Catch-all: affixes not in any previous family
		var all_known: Array[int] = []
		all_known.append_array(OFFENSE_CATEGORIES)
		all_known.append_array(DEFENSE_CATEGORIES)
		all_known.append_array(UTILITY_CATEGORIES)
		all_known.append_array(SPECIAL_CATEGORIES)
		for affix in _all_affixes:
			if affix.category not in all_known:
				family_affixes.append(affix)
	else:
		for affix in _all_affixes:
			if affix.category in categories:
				family_affixes.append(affix)

	if family_affixes.size() == 0:
		return

	# Sort by category then name
	family_affixes.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.affix_name < b.affix_name
	)

	print("\n" + "-".repeat(120))
	print("  %s (%d affixes)" % [family_name, family_affixes.size()])
	print("-".repeat(120))

	# Header
	var header = "%-30s | %-28s | " % ["Name", "Category"]
	for lvl in SCALE_POINTS:
		header += "L%-6d | " % lvl
	header += "Weight"
	print(header)
	print("-".repeat(120))

	for affix in family_affixes:
		_print_affix_row(affix)


func _print_affix_row(affix) -> void:
	var cat_name: String = Affix.Category.keys()[affix.category]
	var name_str: String = affix.affix_name.left(29)
	var cat_str: String = cat_name.left(27)

	var row = "%-30s | %-28s | " % [name_str, cat_str]

	# Inline all method checks using exported properties only (avoids placeholder errors)
	var has_value_scaling: bool = not (affix.effect_min == 0.0 and affix.effect_max == 0.0)
	var has_proc_scaling: bool = not (affix.proc_chance_min == 0.0 and affix.proc_chance_max == 0.0)
	var is_proc: bool = affix.category in [
		Affix.Category.PROC, Affix.Category.ON_HIT, Affix.Category.PER_TURN]
	var is_multiplier: bool = affix.category in [
		Affix.Category.DAMAGE_MULTIPLIER, Affix.Category.DEFENSE_MULTIPLIER,
		Affix.Category.STRENGTH_MULTIPLIER, Affix.Category.AGILITY_MULTIPLIER,
		Affix.Category.INTELLECT_MULTIPLIER, Affix.Category.LUCK_MULTIPLIER,
		Affix.Category.MANA_COST_MULTIPLIER, Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		Affix.Category.STATUS_DAMAGE_MULTIPLIER, Affix.Category.HEALING_MULTIPLIER]

	for lvl in SCALE_POINTS:
		var pp: float = _power_positions[lvl]
		var display: String = ""

		if has_value_scaling:
			var center: float = lerpf(affix.effect_min, affix.effect_max, pp)
			if is_multiplier:
				display = "x%.2f" % center
			else:
				display = "%d" % roundi(center)
		elif affix.effect_number != 0.0:
			if is_multiplier:
				display = "x%.2f" % affix.effect_number
			else:
				display = "%d" % roundi(affix.effect_number)

		if is_proc:
			var pc: float = affix.proc_chance
			if has_proc_scaling:
				pc = lerpf(affix.proc_chance_min, affix.proc_chance_max, pp)
			if display != "":
				display = "%s@%d%%" % [display, roundi(pc * 100)]
			else:
				display = "%d%%" % roundi(pc * 100)

		if display == "":
			if affix.granted_action:
				display = "ACTION"
			elif affix.granted_dice.size() > 0:
				display = "DICE"
			elif affix.effect_data.size() > 0:
				display = "DATA"
			else:
				display = "-"

		row += "%-9s | " % display

	# Power weight status
	if affix.power_weight > 0.0:
		row += "%.1f" % affix.power_weight
		_rated_count += 1
	else:
		row += "UNRATED"
		_unrated_count += 1

	print(row)
