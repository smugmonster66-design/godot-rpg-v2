@tool
extends EditorScript
# ============================================================================
# wire_region1_base_stat_affixes.gd
# Loads pre-saved base stat affix .tres files and wires them into each
# Region 1 item template's base_stat_affixes array.
#
# PREREQUISITES:
#   1. generate_base_stat_affixes.gd has been run (11 affix .tres files exist)
#   2. generate_region1_base_items.gd has been run (68 item .tres files exist)
#
# HOW IT WORKS:
#   - Each affix is a real on-disk Resource with a resource_path
#   - ResourceSaver writes them as ExtResource refs (no null issues)
#   - Items are loaded, patched, re-saved in place
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
# ============================================================================

const ITEM_DIR := "res://resources/items/region_1"
const AFFIX_DIR := "res://resources/affixes/base_stats"

# ── Affix shorthand keys → file names ──
# Used in the mapping table below for readability
const AX := {
	"str":   "inherent_strength",
	"agi":   "inherent_agility",
	"int":   "inherent_intellect",
	"hp":    "inherent_health",
	"mana":  "inherent_mana",
	"dmg":   "inherent_damage",
	"def":   "inherent_defense",
	"arm":   "inherent_armor",
	"bar":   "inherent_barrier",
	"arm_h": "inherent_armor_hybrid",
	"bar_h": "inherent_barrier_hybrid",
}

var _wired := 0
var _skipped := 0
var _errors := 0
var _affix_cache := {}  # file_name → loaded Affix resource


func _run():
	print("=" .repeat(60))
	print("  REGION 1 BASE STAT AFFIX WIRING")
	print("=" .repeat(60))

	# ── Step 1: Pre-load and validate all affix files ──
	print("\n── LOADING AFFIXES ──")
	var all_valid := true
	for key: String in AX:
		var file_name: String = AX[key]
		var path: String = "%s/%s.tres" % [AFFIX_DIR, file_name]
		if not ResourceLoader.exists(path):
			push_error("  ❌ MISSING: %s" % path)
			all_valid = false
			continue
		var res: Resource = load(path)
		if not res is Affix:
			push_error("  ❌ NOT AN AFFIX: %s" % path)
			all_valid = false
			continue
		_affix_cache[file_name] = res
		print("  ✅ %s  (%s)" % [key, path])

	if not all_valid:
		push_error("Aborting — missing or invalid affix files. Run generate_base_stat_affixes.gd first.")
		return

	print("  All 11 affix templates loaded.\n")

	# ── Step 2: Wire each item ──
	_wire_armor()
	_wire_main_hand()
	_wire_off_hand()
	_wire_heavy()
	_wire_accessories()

	# ── Summary ──
	print("")
	print("=" .repeat(60))
	print("  WIRING COMPLETE")
	print("    Wired:   %d" % _wired)
	print("    Skipped: %d" % _skipped)
	print("    Errors:  %d" % _errors)
	print("    Total:   %d / 68 expected" % (_wired + _skipped + _errors))
	print("=" .repeat(60))


# ============================================================================
# ARMOR  (36 items: 4 slots × 3 stats × 3 defense)
# ============================================================================

func _wire_armor():
	print("── ARMOR ──")

	# Secondary stat per [slot][primary]
	# Head:   STR→hp,  AGI→mana, INT→mana
	# Torso:  STR→hp,  AGI→hp,   INT→hp
	# Gloves: STR→dmg, AGI→dmg,  INT→dmg
	# Boots:  STR→def, AGI→hp,   INT→mana
	var secondaries := {
		"head":   { "str": "hp",  "agi": "mana", "int": "mana" },
		"torso":  { "str": "hp",  "agi": "hp",   "int": "hp" },
		"gloves": { "str": "dmg", "agi": "dmg",  "int": "dmg" },
		"boots":  { "str": "def", "agi": "hp",   "int": "mana" },
	}

	# File name patterns per [stat][defense_type]
	# Derived from _armor_name() in the original generator
	var name_map := {
		"head": {
			"str_armor": "iron_helm",       "str_barrier": "runed_iron_helm",    "str_hybrid": "marine_helm",
			"agi_armor": "leather_cap",     "agi_barrier": "warded_leather_cap", "agi_hybrid": "scouts_half_helm",
			"int_armor": "plated_circlet",  "int_barrier": "arcane_circlet",     "int_hybrid": "scholars_circlet",
		},
		"torso": {
			"str_armor": "iron_cuirass",      "str_barrier": "runed_iron_cuirass",    "str_hybrid": "marine_cuirass",
			"agi_armor": "leather_jerkin",    "agi_barrier": "warded_leather_jerkin", "agi_hybrid": "scouts_jerkin",
			"int_armor": "plated_robe",       "int_barrier": "arcane_robe",           "int_hybrid": "scholars_robe",
		},
		"gloves": {
			"str_armor": "iron_gauntlets",      "str_barrier": "runed_iron_gauntlets",    "str_hybrid": "marine_gauntlets",
			"agi_armor": "leather_gloves",      "agi_barrier": "warded_leather_gloves",   "agi_hybrid": "scouts_gloves",
			"int_armor": "plated_wraps",        "int_barrier": "arcane_wraps",            "int_hybrid": "scholars_wraps",
		},
		"boots": {
			"str_armor": "iron_boots",        "str_barrier": "runed_iron_boots",      "str_hybrid": "marine_boots",
			"agi_armor": "leather_boots",     "agi_barrier": "warded_leather_boots",  "agi_hybrid": "scouts_boots",
			"int_armor": "plated_shoes",      "int_barrier": "arcane_shoes",          "int_hybrid": "scholars_shoes",
		},
	}

	for slot: String in ["head", "torso", "gloves", "boots"]:
		for stat: String in ["str", "agi", "int"]:
			for defense: String in ["armor", "barrier", "hybrid"]:
				var combo_key: String = "%s_%s" % [stat, defense]
				var file_name: String = name_map[slot][combo_key]

				# Build affix list
				var affix_keys: Array[String] = []
				affix_keys.append(stat)  # Primary stat always first
				if defense == "hybrid":
					# Hybrid trades secondary for split armor+barrier
					affix_keys.append("arm_h")
					affix_keys.append("bar_h")
				else:
					# Normal: secondary stat + pure defense
					affix_keys.append(secondaries[slot][stat])
					affix_keys.append("arm" if defense == "armor" else "bar")

				_wire_item(slot, file_name, affix_keys)


# ============================================================================
# MAIN HAND  (7 items)
# ============================================================================

func _wire_main_hand():
	print("\n── MAIN HAND ──")
	_wire_item("main_hand", "naval_cutlass",   ["str", "dmg"])
	_wire_item("main_hand", "officers_rapier",  ["agi", "dmg"])
	_wire_item("main_hand", "iron_mace",        ["str", "hp"])
	_wire_item("main_hand", "sanctum_stiletto", ["agi", "dmg"])
	_wire_item("main_hand", "cinder_wand",      ["int", "mana"])
	_wire_item("main_hand", "frost_wand",       ["int", "mana"])
	_wire_item("main_hand", "spark_wand",       ["int", "mana"])


# ============================================================================
# OFF HAND  (10 items: 3 archetypes × 3 defense + parrying blade)
# ============================================================================

func _wire_off_hand():
	print("\n── OFF HAND ──")

	# Naval Shield (STR + Health + defense)
	_wire_item("off_hand", "naval_shield_armor",   ["str", "hp", "arm"])
	_wire_item("off_hand", "naval_shield_barrier",  ["str", "hp", "bar"])
	_wire_item("off_hand", "naval_shield_hybrid",   ["str", "arm_h", "bar_h"])

	# Scout's Buckler (AGI + Health + defense)
	_wire_item("off_hand", "scouts_buckler_armor",   ["agi", "hp", "arm"])
	_wire_item("off_hand", "scouts_buckler_barrier",  ["agi", "hp", "bar"])
	_wire_item("off_hand", "scouts_buckler_hybrid",   ["agi", "arm_h", "bar_h"])

	# Worn Tome (INT + Mana + defense)
	_wire_item("off_hand", "worn_tome_armor",   ["int", "mana", "arm"])
	_wire_item("off_hand", "worn_tome_barrier",  ["int", "mana", "bar"])
	_wire_item("off_hand", "worn_tome_hybrid",   ["int", "arm_h", "bar_h"])

	# Parrying Blade (AGI + Damage, no defense)
	_wire_item("off_hand", "parrying_blade", ["agi", "dmg"])


# ============================================================================
# HEAVY  (9 items)
# ============================================================================

func _wire_heavy():
	print("\n── HEAVY ──")
	_wire_item("heavy", "naval_greatsword",  ["str", "dmg"])
	_wire_item("heavy", "iron_warhammer",    ["str", "hp"])
	_wire_item("heavy", "marine_halberd",    ["str", "dmg"])
	_wire_item("heavy", "longbow",           ["agi", "dmg"])
	_wire_item("heavy", "ember_staff",       ["int", "mana"])
	_wire_item("heavy", "frost_staff_region1", ["int", "mana"])
	_wire_item("heavy", "storm_staff",       ["int", "mana"])
	_wire_item("heavy", "venom_staff",       ["int", "mana"])
	_wire_item("heavy", "shadow_staff",      ["int", "mana"])


# ============================================================================
# ACCESSORIES  (6 items)
# ============================================================================

func _wire_accessories():
	print("\n── ACCESSORIES ──")
	_wire_item("accessory", "iron_signet",      ["str", "hp"])
	_wire_item("accessory", "scouts_band",      ["agi", "hp"])
	_wire_item("accessory", "scholars_ring",    ["int", "mana"])
	_wire_item("accessory", "naval_medallion",  ["str", "dmg"])
	_wire_item("accessory", "riders_pendant",   ["agi", "hp"])
	_wire_item("accessory", "arcane_pendant",   ["int", "mana"])


# ============================================================================
# CORE WIRING FUNCTION
# ============================================================================

func _wire_item(folder: String, file_name: String, affix_keys: Array[String]):
	"""Load an item, assign base_stat_affixes from cached affixes, re-save."""
	var item_path: String = "%s/%s/%s.tres" % [ITEM_DIR, folder, file_name]

	# ── Validate item exists ──
	if not ResourceLoader.exists(item_path):
		push_error("  ❌ ITEM NOT FOUND: %s" % item_path)
		_errors += 1
		return

	# ── Load item ──
	var item: Resource = load(item_path)
	if not item is EquippableItem:
		push_error("  ❌ NOT AN EQUIPPABLE ITEM: %s" % item_path)
		_errors += 1
		return

	# ── Resolve affix references ──
	var affixes: Array[Affix] = []
	var affix_names: Array[String] = []
	for key: String in affix_keys:
		var affix_file: String = AX[key]
		if not _affix_cache.has(affix_file):
			push_error("  ❌ AFFIX NOT CACHED: %s (for %s)" % [affix_file, file_name])
			_errors += 1
			return
		var affix: Affix = _affix_cache[affix_file]
		affixes.append(affix)
		affix_names.append(key)

	# ── Assign to item using .assign() for typed array safety ──
	item.base_stat_affixes.assign(affixes)

	# ── Re-save ──
	var err := ResourceSaver.save(item, item_path)
	if err == OK:
		_wired += 1
		print("  ✅ %s → [%s]" % [item.item_name, ", ".join(affix_names)])
	else:
		push_error("  ❌ SAVE FAILED: %s — %s" % [item_path, error_string(err)])
		_errors += 1
