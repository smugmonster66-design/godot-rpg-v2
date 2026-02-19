@tool
extends EditorScript
# ============================================================================
# generate_baseline_encounters.gd
# Composes baseline enemies into CombatEncounters and creates a test
# DungeonDefinition with them wired in.
#
# TIERS USED: Trash (combat pool), Elite (elite pool), Boss (boss pool)
# TIERS SKIPPED: Mini-Boss, World Boss (used elsewhere)
#
# PREREQUISITES:
#   generate_baseline_enemies.gd has been run (50 enemies exist)
#
# OUTPUT:
#   ~10 trash encounters  -> res://resources/encounters/baseline/trash/
#   ~6  elite encounters  -> res://resources/encounters/baseline/elite/
#   ~3  boss encounters   -> res://resources/encounters/baseline/boss/
#   1   DungeonDefinition -> res://resources/dungeon/baseline_test.tres
#
# Run: Editor -> File -> Run (Ctrl+Shift+X)
# SAFE TO RE-RUN: Overwrites existing files.
# ============================================================================

const ENEMY_DIR := "res://resources/enemies/baseline"
const ENCOUNTER_DIR := "res://resources/encounters/baseline"
const DUNGEON_DIR := "res://resources/dungeon"

var _count := 0
var _errors := 0
var _enemies: Dictionary = {}  # "trash/brute" -> EnemyData


func _run():
	print("=" .repeat(70))
	print("  BASELINE ENCOUNTER GENERATOR")
	print("=" .repeat(70))

	print("\n[PHASE 0] Loading enemies...")
	if not _load_enemies():
		push_error("Aborting.")
		return
	print("[PHASE 0] Loaded %d enemies." % _enemies.size())

	_ensure_directories()

	# ── Phase 1: Trash encounters (combat pool) ──
	print("\n[PHASE 1] Trash encounters...")
	var trash: Array[CombatEncounter] = []

	# Solos
	trash.append(_make_encounter(
		"Lone Brute", "lone_brute", 1,
		["trash/brute"], [1]))
	trash.append(_make_encounter(
		"Lone Duelist", "lone_duelist", 1,
		["trash/duelist"], [1]))
	trash.append(_make_encounter(
		"Lone Skirmisher", "lone_skirmisher", 1,
		["trash/skirmisher"], [1]))
	trash.append(_make_encounter(
		"Lone Tank", "lone_tank", 1,
		["trash/tank"], [1]))
	trash.append(_make_encounter(
		"Lone Archmage", "lone_archmage", 1,
		["trash/archmage"], [1]))

	# Pairs
	trash.append(_make_encounter(
		"Brute & Skirmisher", "brute_skirmisher", 2,
		["trash/brute", "trash/skirmisher"], [0, 2]))
	trash.append(_make_encounter(
		"Duelist & Trickster", "duelist_trickster", 2,
		["trash/duelist", "trash/trickster"], [0, 2]))
	trash.append(_make_encounter(
		"Battle Mage & Archmage", "battlemage_archmage", 2,
		["trash/battle_mage", "trash/archmage"], [0, 2]))
	trash.append(_make_encounter(
		"Tank & Marshal", "tank_marshal", 2,
		["trash/tank", "trash/marshal"], [0, 2]))
	trash.append(_make_encounter(
		"Brute & Support Mage", "brute_support", 2,
		["trash/brute", "trash/support_mage"], [0, 2]))

	_save_encounters(trash, "trash")
	print("[PHASE 1] %d trash encounters." % trash.size())

	# ── Phase 2: Elite encounters (elite pool) ──
	print("\n[PHASE 2] Elite encounters...")
	var elite: Array[CombatEncounter] = []

	# Synergy pairs
	elite.append(_make_encounter(
		"Elite Tank & Archmage", "elite_tank_archmage", 4,
		["elite/elite_tank", "elite/elite_archmage"], [0, 2]))
	elite.append(_make_encounter(
		"Elite Brute & Marshal", "elite_brute_marshal", 4,
		["elite/elite_brute", "elite/elite_marshal"], [0, 2]))
	elite.append(_make_encounter(
		"Elite War Mage & Duelist", "elite_warmage_duelist", 4,
		["elite/elite_war_mage", "elite/elite_duelist"], [0, 2]))

	# Trios
	elite.append(_make_encounter(
		"Elite Skirmisher Ambush", "elite_skirmish_ambush", 5,
		["elite/elite_skirmisher", "elite/elite_battle_mage", "elite/elite_trickster"],
		[0, 1, 2]))
	elite.append(_make_encounter(
		"Elite War Party", "elite_war_party", 5,
		["elite/elite_tank", "elite/elite_duelist", "elite/elite_support_mage"],
		[0, 1, 2]))
	elite.append(_make_encounter(
		"Elite Brute Squad", "elite_brute_squad", 5,
		["elite/elite_brute", "elite/elite_brute", "elite/elite_marshal"],
		[0, 1, 2]))

	_save_encounters(elite, "elite")
	print("[PHASE 2] %d elite encounters." % elite.size())

	# ── Phase 3: Boss encounters (boss pool) ──
	print("\n[PHASE 3] Boss encounters...")
	var boss: Array[CombatEncounter] = []

	# Solo boss
	boss.append(_make_encounter(
		"Boss Brute", "boss_brute_solo", 7,
		["boss/boss_brute"], [1],
		true))
	# Boss + bodyguard
	boss.append(_make_encounter(
		"Boss Archmage & Bodyguard", "boss_archmage_guard", 8,
		["boss/boss_archmage", "elite/elite_tank"], [1, 0],
		true))
	# Boss + retinue
	boss.append(_make_encounter(
		"Boss Tank & Retinue", "boss_tank_retinue", 9,
		["boss/boss_tank", "elite/elite_brute", "elite/elite_support_mage"],
		[1, 0, 2],
		true))

	_save_encounters(boss, "boss")
	print("[PHASE 3] %d boss encounters." % boss.size())

	# ── Phase 4: DungeonDefinition ──
	print("\n[PHASE 4] Dungeon definition...")
	_build_dungeon(trash, elite, boss)
	print("[PHASE 4] Done.")

	print("\n" + "=" .repeat(70))
	if _errors == 0:
		print("  SUCCESS: %d resources created" % _count)
	else:
		print("  %d ERRORS, %d resources created" % [_errors, _count])
	print("=" .repeat(70))


# ============================================================================
# ENEMY LOADING
# ============================================================================

func _load_enemies() -> bool:
	var ok := true
	var tiers = ["trash", "elite", "boss"]
	var names = [
		"brute", "duelist", "skirmisher", "battle_mage", "archmage",
		"tank", "war_mage", "marshal", "support_mage", "trickster",
	]
	var prefixes = { "trash": "", "elite": "elite_", "boss": "boss_" }

	for tier in tiers:
		for base_name in names:
			var file_name = "%s%s" % [prefixes[tier], base_name]
			var path = "%s/%s/%s.tres" % [ENEMY_DIR, tier, file_name]
			var cache_key = "%s/%s" % [tier, file_name]
			if ResourceLoader.exists(path):
				_enemies[cache_key] = load(path)
			else:
				if tier == "trash":
					push_error("  MISSING: %s" % path)
					ok = false
	print("  Loaded %d enemies" % _enemies.size())
	return ok


func _ensure_directories():
	for sub in ["trash", "elite", "boss"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [ENCOUNTER_DIR, sub])
	DirAccess.make_dir_recursive_absolute(DUNGEON_DIR)


# ============================================================================
# ENCOUNTER COMPOSITION
# ============================================================================

func _make_encounter(enc_name: String, file_id: String, diff_tier: int,
		enemy_keys: Array, slots: Array,
		is_boss: bool = false) -> CombatEncounter:

	var enc = CombatEncounter.new()
	enc.encounter_name = enc_name
	enc.encounter_id = "baseline_%s" % file_id
	enc.difficulty_tier = diff_tier
	enc.is_boss_encounter = is_boss
	if is_boss:
		enc.disable_fleeing = true

	var enemy_list: Array[EnemyData] = []
	for i in range(enemy_keys.size()):
		var key = enemy_keys[i]
		if _enemies.has(key):
			enemy_list.append(_enemies[key])
		else:
			push_error("  Missing enemy: %s (for %s)" % [key, enc_name])
			_errors += 1

	enc.enemies.assign(enemy_list)

	var typed_slots: Array[int] = []
	for s in slots:
		typed_slots.append(s)
	enc.enemy_slots = typed_slots

	enc.level_range_min = maxi(1, diff_tier - 1)
	enc.level_range_max = diff_tier + 2

	return enc


func _save_encounters(encounters: Array[CombatEncounter], folder: String):
	for i in range(encounters.size()):
		var enc = encounters[i]
		var safe_id = enc.encounter_id.replace("baseline_", "")
		var path = "%s/%s/%s.tres" % [ENCOUNTER_DIR, folder, safe_id]
		var err = ResourceSaver.save(enc, path)
		if err == OK:
			_count += 1
			print("  saved: %s (%d enemies)" % [enc.encounter_name, enc.enemies.size()])
			# Reload so DungeonDefinition gets proper ExtResource refs
			encounters[i] = load(path)
		else:
			push_error("  SAVE FAILED: %s -- %s" % [path, error_string(err)])
			_errors += 1


# ============================================================================
# DUNGEON DEFINITION
# ============================================================================

func _build_dungeon(trash: Array[CombatEncounter],
		elite: Array[CombatEncounter],
		boss: Array[CombatEncounter]):

	var dun = DungeonDefinition.new()
	dun.dungeon_name = "Baseline Test Dungeon"
	dun.dungeon_id = "baseline_test"
	dun.description = "Auto-generated test dungeon using all baseline enemy templates. 8 floors, balanced encounters."
	dun.floor_count = 8
	dun.dungeon_level = 3
	dun.dungeon_region = 1

	dun.combat_encounters.assign(trash)
	dun.elite_encounters.assign(elite)
	dun.boss_encounters.assign(boss)

	dun.min_nodes_per_floor = 2
	dun.max_nodes_per_floor = 3
	dun.safe_floor_before_boss = true
	dun.mid_safe_floor = true

	var path = "%s/baseline_test.tres" % DUNGEON_DIR
	var err = ResourceSaver.save(dun, path)
	if err == OK:
		_count += 1
		print("  saved: %s (%d floors, %d/%d/%d)" % [
			dun.dungeon_name, dun.floor_count,
			trash.size(), elite.size(), boss.size()])
	else:
		push_error("  SAVE FAILED: %s" % error_string(err))
		_errors += 1
