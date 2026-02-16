@tool
extends EditorScript
# ============================================================================
# generate_base_stat_affixes.gd
# Creates standalone base stat affix .tres files for Region 1 items.
#
# These are the inherent stat bonuses that every item gets regardless of
# rarity. Each affix is saved as its own file so it has a real resource_path,
# which means items can reference them via ExtResource without null issues.
#
# After running this, run the wiring script to assign these affixes to
# each item template's base_stat_affixes array.
#
# Output: res://resources/affixes/base_stats/ (11 files)
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
# ============================================================================

const BASE_DIR := "res://resources/affixes/base_stats"

var _count := 0

func _run():
	print("=" .repeat(60))
	print("  BASE STAT AFFIX GENERATOR")
	print("=" .repeat(60))

	_ensure_dir()

	# ── Primary Stats ──
	print("\n── PRIMARY STATS ──")

	_generate("inherent_strength", "Inherent Strength", "+{value} Strength",
		Affix.Category.STRENGTH_BONUS, "stat,inherent,physical", 1.0, 50.0)

	_generate("inherent_agility", "Inherent Agility", "+{value} Agility",
		Affix.Category.AGILITY_BONUS, "stat,inherent,physical", 1.0, 50.0)

	_generate("inherent_intellect", "Inherent Intellect", "+{value} Intellect",
		Affix.Category.INTELLECT_BONUS, "stat,inherent,magical", 1.0, 50.0)

	# ── Secondary Stats ──
	print("\n── SECONDARY STATS ──")

	_generate("inherent_health", "Inherent Health", "+{value} Health",
		Affix.Category.HEALTH_BONUS, "defense,inherent,health", 5.0, 250.0)

	_generate("inherent_mana", "Inherent Mana", "+{value} Mana",
		Affix.Category.MANA_BONUS, "mana,inherent", 3.0, 80.0)

	_generate("inherent_damage", "Inherent Damage", "+{value} Damage",
		Affix.Category.DAMAGE_BONUS, "damage,inherent", 1.0, 30.0)

	_generate("inherent_defense", "Inherent Defense", "+{value} Defense",
		Affix.Category.DEFENSE_BONUS, "defense,inherent", 1.0, 50.0)

	# ── Defense: Full ──
	print("\n── DEFENSE (FULL) ──")

	_generate("inherent_armor", "Inherent Armor", "+{value} Armor",
		Affix.Category.ARMOR_BONUS, "defense,inherent,armor", 2.0, 60.0)

	_generate("inherent_barrier", "Inherent Barrier", "+{value} Barrier",
		Affix.Category.BARRIER_BONUS, "defense,inherent,barrier", 3.0, 120.0)

	# ── Defense: Hybrid (half values) ──
	print("\n── DEFENSE (HYBRID) ──")

	_generate("inherent_armor_hybrid", "Inherent Armor (Hybrid)", "+{value} Armor",
		Affix.Category.ARMOR_BONUS, "defense,inherent,armor,hybrid", 1.0, 30.0)

	_generate("inherent_barrier_hybrid", "Inherent Barrier (Hybrid)", "+{value} Barrier",
		Affix.Category.BARRIER_BONUS, "defense,inherent,barrier,hybrid", 1.5, 60.0)

	print("")
	print("=" .repeat(60))
	print("  DONE — %d / 11 affix templates generated" % _count)
	print("  Location: %s/" % BASE_DIR)
	print("=" .repeat(60))

# ============================================================================
# CORE
# ============================================================================

func _generate(file_name: String, affix_name: String, desc: String,
		category: Affix.Category, tags_csv: String,
		effect_min: float, effect_max: float):
	"""Create and save a single base stat affix."""
	print("  → Creating %s..." % affix_name)

	var affix := Affix.new()
	affix.affix_name = affix_name
	affix.description = desc
	affix.category = category
	affix.effect_min = effect_min
	affix.effect_max = effect_max
	affix.show_in_summary = true
	affix.show_in_active_list = true

	# Tags — split CSV into typed array, then .assign() to avoid type mismatch
	var tag_list: Array[String] = []
	for t: String in tags_csv.split(",", false):
		tag_list.append(t.strip_edges())
	affix.tags.assign(tag_list)

	var path: String = "%s/%s.tres" % [BASE_DIR, file_name]
	var err := ResourceSaver.save(affix, path)
	if err == OK:
		_count += 1
		print("    ✅ %s  [%.1f – %.1f]" % [path, effect_min, effect_max])
	else:
		push_error("    ❌ Save failed: %s — %s" % [path, error_string(err)])

# ============================================================================
# SETUP
# ============================================================================

func _ensure_dir():
	var da := DirAccess.open("res://")
	if not da.dir_exists(BASE_DIR):
		da.make_dir_recursive(BASE_DIR)
		print("  📁 Created %s" % BASE_DIR)
	else:
		print("  📁 Directory exists: %s" % BASE_DIR)
