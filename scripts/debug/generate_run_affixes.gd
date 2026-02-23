@tool
extends EditorScript
## generate_run_affixes.gd — Run via Script Editor → File → Run
## Creates 12 sample RunAffixEntry .tres files for the test dungeon,
## plus a DungeonListEntry .tres for the dungeon selection screen.
##
## Output:
##   res://resources/dungeon/run_affixes/   (12 RunAffixEntry .tres files)
##   res://resources/dungeon/entries/        (1 DungeonListEntry .tres file)
##
## After running, drag the run affix .tres files into your DungeonDefinition's
## run_affix_pool array, and the entry .tres into DungeonSelectionScreen's
## dungeon_list array.

const AFFIX_DIR = "res://resources/dungeon/run_affixes/"
const ENTRY_DIR = "res://resources/dungeon/entries/"

var _created: int = 0

func _run():
	print("")
	print("╔══════════════════════════════════════════╗")
	print("║   GENERATE ROGUELITE SAMPLE CONTENT      ║")
	print("╚══════════════════════════════════════════╝")

	_ensure_dir(AFFIX_DIR)
	_ensure_dir(ENTRY_DIR)

	_generate_run_affixes()
	_generate_dungeon_list_entry()

	print("\n✅ Created %d resources total" % _created)
	print("📂 Run affixes: %s" % AFFIX_DIR)
	print("📂 Dungeon entries: %s" % ENTRY_DIR)
	print("\n📋 Next steps:")
	print("   1. Open your DungeonDefinition .tres in Inspector")
	print("   2. Expand 'Run Affixes' → drag all 12 .tres into run_affix_pool")
	print("   3. Open DungeonSelectionScreen node in your scene")
	print("   4. Drag the DungeonListEntry .tres into dungeon_list")


func _ensure_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
		print("📁 Created: %s" % path)


# ============================================================================
# RUN AFFIX GENERATION
# ============================================================================

func _generate_run_affixes():
	print("\n🎲 Generating run affixes...")

	# ── COMMON: Dice Effects (6) ──

	_save_dice_affix(
		"searing_dice", "Searing Dice",
		"Each die deals +2 fire damage when used.",
		RunAffixEntry.Rarity.COMMON,
		["fire", "offense"], [], 3,
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
		{"element": "FIRE"}
	)

	_save_dice_affix(
		"lucky_roll", "Lucky Roll",
		"+1 to all dice rolls.",
		RunAffixEntry.Rarity.COMMON,
		["offense", "utility"], [], 2,
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0
	)

	_save_dice_affix(
		"frostbite_dice", "Frostbite Dice",
		"Each die deals +2 ice damage when used.",
		RunAffixEntry.Rarity.COMMON,
		["ice", "offense"], [], 3,
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
		{"element": "ICE"}
	)

	_save_dice_affix(
		"steady_hand", "Steady Hand",
		"Dice minimum roll value is 2.",
		RunAffixEntry.Rarity.COMMON,
		["utility"], [], 1,
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.SET_MINIMUM_VALUE, 2.0
	)

	_save_dice_affix(
		"chain_sparks", "Chain Sparks",
		"Dice chain 1 shock damage to a second enemy on use.",
		RunAffixEntry.Rarity.COMMON,
		["shock", "offense"], [], 2,
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
		{"element": "SHOCK", "chains": 1, "decay": 0.5}
	)

	_save_dice_affix(
		"vampiric_edge", "Vampiric Edge",
		"Heal for 10% of damage dealt when a die is used.",
		RunAffixEntry.Rarity.COMMON,
		["sustain"], [], 1,
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.LEECH_HEAL, 0.1,
		{"percent": 0.1}
	)

	# ── UNCOMMON: Stat Effects (3) ──

	_save_stat_affix(
		"iron_constitution", "Iron Constitution",
		"+25 maximum health for the run.",
		RunAffixEntry.Rarity.UNCOMMON,
		["defense", "health"], [], 2,
		Affix.Category.HEALTH_BONUS, 25.0
	)

	_save_stat_affix(
		"battle_hardened", "Battle Hardened",
		"+5 armor for the run.",
		RunAffixEntry.Rarity.UNCOMMON,
		["defense", "armor"], [], 2,
		Affix.Category.ARMOR_BONUS, 5.0
	)

	_save_stat_affix(
		"sharpened_blade", "Sharpened Blade",
		"+4 flat damage bonus for the run.",
		RunAffixEntry.Rarity.UNCOMMON,
		["offense"], [], 2,
		Affix.Category.DAMAGE_BONUS, 4.0
	)

	# ── RARE: Powerful or Hybrid (3) ──

	_save_stat_affix(
		"flame_mastery", "Flame Mastery",
		"1.25x fire damage for the run.",
		RunAffixEntry.Rarity.RARE,
		["fire", "offense", "mastery"], ["frost_mastery", "shock_mastery"], 1,
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER, 1.25,
		{"element": "FIRE"}
	)

	_save_stat_affix(
		"frost_mastery", "Frost Mastery",
		"1.25x ice damage for the run.",
		RunAffixEntry.Rarity.RARE,
		["ice", "offense", "mastery"], ["flame_mastery", "shock_mastery"], 1,
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER, 1.25,
		{"element": "ICE"}
	)

	_save_hybrid_affix(
		"berserkers_gambit", "Berserker's Gambit",
		"+3 to all dice rolls, but -15 max health.",
		RunAffixEntry.Rarity.RARE,
		["offense", "risk"], [], 1,
		# Dice part
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0,
		{},
		# Stat part
		Affix.Category.HEALTH_BONUS, -15.0
	)


# ============================================================================
# DUNGEON LIST ENTRY GENERATION
# ============================================================================

func _generate_dungeon_list_entry():
	print("\n🏰 Generating dungeon list entry...")

	# Try to find the test dungeon definition
	var test_def_path := "res://resources/dungeon/dungeon_test.tres"
	var test_def: DungeonDefinition = null
	if ResourceLoader.exists(test_def_path):
		test_def = load(test_def_path) as DungeonDefinition

	if not test_def:
		# Create a placeholder — user drags their own def in Inspector
		print("  ⚠️  dungeon_test.tres not found at expected path")
		print("  ⚠️  Creating entry with null definition — assign manually")

	var entry := DungeonListEntry.new()
	entry.dungeon_definition = test_def
	entry.unlock_type = DungeonListEntry.UnlockType.NONE
	entry.sort_order = 0
	entry.reward_preview = "Gold, Region 1 Equipment, Run Affixes"

	var path := ENTRY_DIR + "test_dungeon_entry.tres"
	var err := ResourceSaver.save(entry, path)
	if err == OK:
		_created += 1
		print("  ✅ %s" % path)
	else:
		print("  ❌ Failed to save: %s (error %d)" % [path, err])


# ============================================================================
# HELPER: Save a DICE-type RunAffixEntry
# ============================================================================

func _save_dice_affix(
	id: String, name: String, desc: String,
	rarity: RunAffixEntry.Rarity,
	tags: Array, exclusive: Array, stacks: int,
	trigger: DiceAffix.Trigger,
	effect_type: DiceAffix.EffectType,
	effect_value: float,
	effect_data: Dictionary = {}
):
	var da := DiceAffix.new()
	da.description = desc
	da.affix_name = id
	da.trigger = trigger
	da.effect_type = effect_type
	da.effect_value = effect_value
	da.effect_data = effect_data
	da.source_type = "dungeon_temp"

	var entry := RunAffixEntry.new()
	entry.affix_id = id
	entry.display_name = name
	entry.description = desc
	entry.rarity = rarity
	entry.affix_type = RunAffixEntry.AffixType.DICE
	entry.dice_affix = da
	entry.tags.assign(tags)
	entry.mutually_exclusive_tags.assign(exclusive)
	entry.max_stacks = stacks
	entry.offer_weight = 10

	_save_entry(entry, id)


# ============================================================================
# HELPER: Save a STAT-type RunAffixEntry
# ============================================================================

func _save_stat_affix(
	id: String, name: String, desc: String,
	rarity: RunAffixEntry.Rarity,
	tags: Array, exclusive: Array, stacks: int,
	category: Affix.Category,
	effect_value: float,
	effect_data: Dictionary = {}
):
	var sa := Affix.new()
	sa.affix_name = name
	sa.description = desc
	sa.category = category
	sa.effect_number = effect_value
	sa.source_type = "dungeon_temp"
	sa.tags.assign(tags)
	if not effect_data.is_empty():
		sa.set("effect_data", effect_data)

	var entry := RunAffixEntry.new()
	entry.affix_id = id
	entry.display_name = name
	entry.description = desc
	entry.rarity = rarity
	entry.affix_type = RunAffixEntry.AffixType.STAT
	entry.stat_affix = sa
	entry.tags.assign(tags)
	entry.mutually_exclusive_tags.assign(exclusive)
	entry.max_stacks = stacks
	entry.offer_weight = 10

	_save_entry(entry, id)


# ============================================================================
# HELPER: Save a HYBRID-type RunAffixEntry
# ============================================================================

func _save_hybrid_affix(
	id: String, name: String, desc: String,
	rarity: RunAffixEntry.Rarity,
	tags: Array, exclusive: Array, stacks: int,
	# Dice part
	trigger: DiceAffix.Trigger,
	dice_effect: DiceAffix.EffectType,
	dice_value: float,
	dice_data: Dictionary,
	# Stat part
	stat_category: Affix.Category,
	stat_value: float
):
	var da := DiceAffix.new()
	da.description = desc
	da.affix_name = id + "_dice"
	da.trigger = trigger
	da.effect_type = dice_effect
	da.effect_value = dice_value
	da.effect_data = dice_data
	da.source_type = "dungeon_temp"

	var sa := Affix.new()
	sa.affix_name = name + " (Stat)"
	sa.description = desc
	sa.category = stat_category
	sa.effect_number = stat_value
	sa.source_type = "dungeon_temp"
	sa.tags.assign(tags)

	var entry := RunAffixEntry.new()
	entry.affix_id = id
	entry.display_name = name
	entry.description = desc
	entry.rarity = rarity
	entry.affix_type = RunAffixEntry.AffixType.HYBRID
	entry.dice_affix = da
	entry.stat_affix = sa
	entry.tags.assign(tags)
	entry.mutually_exclusive_tags.assign(exclusive)
	entry.max_stacks = stacks
	entry.offer_weight = 10

	_save_entry(entry, id)


# ============================================================================
# SAVE TO DISK
# ============================================================================

func _save_entry(entry: RunAffixEntry, id: String):
	var path := AFFIX_DIR + "run_affix_%s.tres" % id
	var err := ResourceSaver.save(entry, path)
	if err == OK:
		_created += 1
		print("  ✅ %s — %s [%s]" % [entry.display_name, entry.get_rarity_name(),
			RunAffixEntry.AffixType.keys()[entry.affix_type]])
	else:
		print("  ❌ Failed to save: %s (error %d)" % [path, err])
