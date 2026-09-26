@tool
extends EditorScript
# ============================================================================
# generate_navy_dungeon.gd
# Composes Navy faction enemies into CombatEncounters, creates the first
# DungeonEvent and DungeonShrine content, and assembles the Sanctum Navy
# DungeonDefinition.
#
# PREREQUISITES:
#   - generate_navy_enemies.gd has been run (85 enemies exist)
#   - resources/items/region_1/ contains equippable item templates
#   - resources/consumables/region_1/ contains consumable templates
#   - resources/dungeon/run_affixes/ contains 12 run affix entries
#
# OUTPUT:
#   10 trash encounters  -> res://resources/encounters/region1/navy/trash/
#   6  elite encounters  -> res://resources/encounters/region1/navy/elite/
#   3  boss encounters   -> res://resources/encounters/region1/navy/boss/
#   6  dungeon events    -> res://resources/dungeon/events/
#   4  dungeon shrines   -> res://resources/dungeon/shrines/
#   1  DungeonDefinition -> res://resources/dungeon/sanctum_navy.tres
#
# Run: Editor -> File -> Run (Ctrl+Shift+X)
# SAFE TO RE-RUN: Overwrites existing files.
# ============================================================================

const NAVY_ENEMY_DIR := "res://resources/enemies/region1/navy"
const ENCOUNTER_DIR := "res://resources/encounters/region1/navy"
const EVENT_DIR := "res://resources/dungeon/events"
const SHRINE_DIR := "res://resources/dungeon/shrines"
const DUNGEON_DIR := "res://resources/dungeon"
const RUN_AFFIX_DIR := "res://resources/dungeon/run_affixes"
const DICE_AFFIX_DIR := "res://resources/dice_affixes/rollable/combat"
const ITEM_DIR := "res://resources/items/region_1"
const CONSUMABLE_DIR := "res://resources/consumables/region_1"

var _enemies: Dictionary = {}  # "tier/filename" -> EnemyData
var _count := 0
var _errors := 0


func _run():
	print("=" .repeat(70))
	print("  SANCTUM NAVY DUNGEON GENERATOR")
	print("=" .repeat(70))

	# ── Phase 0: Load enemies ──
	print("\n[PHASE 0] Loading Navy enemies...")
	if not _load_enemies():
		push_error("Aborting — missing enemies.")
		return
	print("[PHASE 0] Loaded %d enemies." % _enemies.size())

	_ensure_directories()

	# ── Phase 1: Trash encounters ──
	print("\n[PHASE 1] Trash encounters...")
	var trash: Array[CombatEncounter] = []

	# Solos
	trash.append(_make_encounter(
		"Navy Patrol", "navy_patrol", 1,
		["trash/navy_enforcer"], [1]))
	trash.append(_make_encounter(
		"Dock Watch", "dock_watch", 1,
		["trash/harbour_sentinel"], [1]))
	trash.append(_make_encounter(
		"Fencer's Challenge", "fencers_challenge", 1,
		["trash/navy_fencer"], [1]))

	# Pairs
	trash.append(_make_encounter(
		"Shore Patrol", "shore_patrol", 2,
		["trash/navy_enforcer", "trash/navy_scout"], [0, 2]))
	trash.append(_make_encounter(
		"Naval Guard Post", "naval_guard_post", 2,
		["trash/harbour_sentinel", "trash/naval_arcanist"], [0, 2]))
	trash.append(_make_encounter(
		"Boarding Party", "boarding_party", 2,
		["trash/marine_boarder", "trash/rigging_runner"], [0, 2]))
	trash.append(_make_encounter(
		"Command Squad", "command_squad", 2,
		["trash/navy_sergeant", "trash/navy_enforcer"], [0, 2]))

	# Trios
	trash.append(_make_encounter(
		"Arcane Escort", "arcane_escort", 3,
		["trash/naval_arcanist", "trash/navy_fencer", "trash/navy_scout"],
		[0, 1, 2]))
	trash.append(_make_encounter(
		"Medical Detail", "medical_detail", 3,
		["trash/navy_chirurgeon", "trash/marine_boarder", "trash/navy_enforcer"],
		[0, 1, 2]))
	trash.append(_make_encounter(
		"Drum Corps", "drum_corps", 3,
		["trash/drum_major", "trash/navy_enforcer", "trash/navy_fencer"],
		[0, 1, 2]))

	_save_encounters(trash, "trash")
	print("[PHASE 1] %d trash encounters." % trash.size())

	# ── Phase 2: Elite encounters ──
	print("\n[PHASE 2] Elite encounters...")
	var elite: Array[CombatEncounter] = []

	# Pairs
	elite.append(_make_encounter(
		"Shieldwall Advance", "shieldwall_advance", 4,
		["elite/shieldwall_veteran", "elite/senior_arcanist"], [0, 2]))
	elite.append(_make_encounter(
		"Enforcer Patrol", "enforcer_patrol", 4,
		["elite/enforcer_sergeant", "elite/staff_sergeant"], [0, 2]))
	elite.append(_make_encounter(
		"Storm Patrol", "storm_patrol", 4,
		["elite/stormcaller", "elite/senior_ward_officer"], [0, 2]))

	# Trios
	elite.append(_make_encounter(
		"Veteran Boarding Crew", "veteran_boarding_crew", 5,
		["elite/veteran_boarder", "elite/topman", "elite/senior_chirurgeon"],
		[0, 1, 2]))
	elite.append(_make_encounter(
		"Officer's Guard", "officers_guard", 5,
		["elite/shieldwall_veteran", "elite/fencing_officer", "elite/senior_signalman"],
		[0, 1, 2]))
	elite.append(_make_encounter(
		"Tide Chapel Guard", "tide_chapel_guard", 5,
		["elite/tide_chaplain", "elite/senior_drummer", "elite/gate_sentinel"],
		[0, 1, 2]))

	_save_encounters(elite, "elite")
	print("[PHASE 2] %d elite encounters." % elite.size())

	# ── Phase 3: Boss encounters ──
	print("\n[PHASE 3] Boss encounters...")
	var boss: Array[CombatEncounter] = []

	boss.append(_make_encounter(
		"Breach Captain", "breach_captain_solo", 7,
		["boss/breach_captain"], [1],
		true))
	boss.append(_make_encounter(
		"Arcanist Commander & Honor Guard", "arcanist_commander_guard", 8,
		["boss/arcanist_commander", "elite/shieldwall_veteran"], [1, 0],
		true))
	boss.append(_make_encounter(
		"Bulwark Captain's Last Stand", "bulwark_last_stand", 9,
		["boss/bulwark_captain", "elite/senior_arcanist", "elite/enforcer_sergeant"],
		[1, 0, 2],
		true))

	_save_encounters(boss, "boss")
	print("[PHASE 3] %d boss encounters." % boss.size())

	# ── Phase 4: Dungeon events ──
	print("\n[PHASE 4] Dungeon events...")
	var events := _create_events()
	print("[PHASE 4] %d events." % events.size())

	# ── Phase 5: Dungeon shrines ──
	print("\n[PHASE 5] Dungeon shrines...")
	var shrines := _create_shrines()
	print("[PHASE 5] %d shrines." % shrines.size())

	# ── Phase 6: Dungeon definition ──
	print("\n[PHASE 6] Dungeon definition...")
	_build_dungeon(trash, elite, boss, events, shrines)
	print("[PHASE 6] Done.")

	# ── Phase 7: Filesystem scan ──
	EditorInterface.get_resource_filesystem().scan()

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

	for tier in tiers:
		var dir_path = "%s/%s" % [NAVY_ENEMY_DIR, tier]
		var dir = DirAccess.open(dir_path)
		if not dir:
			push_error("  Cannot open: %s" % dir_path)
			ok = false
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var base = file_name.get_basename()
				var path = "%s/%s" % [dir_path, file_name]
				var cache_key = "%s/%s" % [tier, base]
				if ResourceLoader.exists(path):
					_enemies[cache_key] = load(path)
			file_name = dir.get_next()
		dir.list_dir_end()

	print("  Loaded %d enemies" % _enemies.size())
	# Require at least trash enemies
	if not _enemies.has("trash/navy_enforcer"):
		push_error("  MISSING: trash/navy_enforcer — run generate_navy_enemies.gd first")
		ok = false
	return ok


func _ensure_directories():
	for sub in ["trash", "elite", "boss"]:
		DirAccess.make_dir_recursive_absolute(
			"%s/%s" % [ENCOUNTER_DIR, sub])
	DirAccess.make_dir_recursive_absolute(EVENT_DIR)
	DirAccess.make_dir_recursive_absolute(SHRINE_DIR)
	DirAccess.make_dir_recursive_absolute(DUNGEON_DIR)


# ============================================================================
# ENCOUNTER COMPOSITION
# ============================================================================

func _make_encounter(enc_name: String, file_id: String, diff_tier: int,
		enemy_keys: Array, slots: Array,
		is_boss: bool = false) -> CombatEncounter:

	var enc = CombatEncounter.new()
	enc.encounter_name = enc_name
	enc.encounter_id = "navy_%s" % file_id
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
		var safe_id = enc.encounter_id.replace("navy_", "")
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
# DUNGEON EVENTS
# ============================================================================

func _create_events() -> Array[DungeonEvent]:
	var events: Array[DungeonEvent] = []

	# Load dice affixes for temp rewards
	var da_bonus_damage = _load_if_exists("%s/tier_1/bonus_damage_flat.tres" % DICE_AFFIX_DIR)
	var da_fire_damage = _load_if_exists("%s/tier_1/add_fire_damage_flat.tres" % DICE_AFFIX_DIR)

	# ── Event 1: Abandoned Armory ──
	var e1 = DungeonEvent.new()
	e1.event_name = "Abandoned Armory"
	e1.event_id = "navy_abandoned_armory"
	e1.description = "You discover an unlocked navy armory, weapons scattered across racks and crates. Dust motes hang in the air — it hasn't been disturbed in some time."

	var e1c1 = DungeonEventChoice.new()
	e1c1.choice_text = "Search carefully"
	e1c1.result_text = "You methodically sort through the racks and find a pouch of coins tucked behind a shield."
	e1c1.gold_reward = 15

	var e1c2 = DungeonEventChoice.new()
	e1c2.choice_text = "Grab and run"
	e1c2.result_text = "You scoop up armfuls of loose valuables before anyone notices!"
	e1c2.gold_reward = 30
	e1c2.success_chance = 0.7
	e1c2.fail_text = "A hidden tripwire snaps — a blade swings from the ceiling!"
	e1c2.fail_heal_amount = -10

	var e1c3 = DungeonEventChoice.new()
	e1c3.choice_text = "Leave it"
	e1c3.result_text = "Discretion is the better part of valor. You note the location and move on."
	e1c3.experience_reward = 5

	var e1_choices: Array[DungeonEventChoice] = [e1c1, e1c2, e1c3]
	e1.choices.assign(e1_choices)
	events.append(_save_event(e1))

	# ── Event 2: Captured Spy ──
	var e2 = DungeonEvent.new()
	e2.event_name = "Captured Spy"
	e2.event_id = "navy_captured_spy"
	e2.description = "A prisoner in navy stocks claims to be an ally with intelligence about what lies ahead. Their eyes are desperate but lucid."
	e2.min_floor = 2
	e2.max_floor = 6

	var e2c1 = DungeonEventChoice.new()
	e2c1.choice_text = "Free them"
	e2c1.result_text = "Grateful, the spy bandages your wounds with supplies hidden in their clothing."
	e2c1.heal_percent = 0.15

	var e2c2 = DungeonEventChoice.new()
	e2c2.choice_text = "Interrogate for intel"
	e2c2.result_text = "They reveal a weakness in the enemy formations — you'll strike harder in the next fight."
	e2c2.success_chance = 0.6
	e2c2.grant_temp_affix = da_bonus_damage
	e2c2.fail_text = "The 'spy' was bait! They lash out with a concealed blade."
	e2c2.fail_heal_amount = -5

	var e2_choices: Array[DungeonEventChoice] = [e2c1, e2c2]
	e2.choices.assign(e2_choices)
	events.append(_save_event(e2))

	# ── Event 3: Naval Supply Cache ──
	var e3 = DungeonEvent.new()
	e3.event_name = "Naval Supply Cache"
	e3.event_id = "navy_supply_cache"
	e3.description = "You find a sealed supply crate marked with the Navy quartermaster's stamp. The lock is rusted but the contents look intact."

	var e3c1 = DungeonEventChoice.new()
	e3c1.choice_text = "Pry it open"
	e3c1.result_text = "The crate cracks open to reveal a generous stash of naval pay!"
	e3c1.gold_reward = 40
	e3c1.success_chance = 0.8
	e3c1.fail_text = "The crate was booby-trapped! A small explosion catches you off guard."
	e3c1.fail_heal_amount = -8

	var e3c2 = DungeonEventChoice.new()
	e3c2.choice_text = "Sell the location"
	e3c2.result_text = "You mark the crate's position for later retrieval. Someone will pay for this information."
	e3c2.gold_reward = 20

	var e3_choices: Array[DungeonEventChoice] = [e3c1, e3c2]
	e3.choices.assign(e3_choices)
	events.append(_save_event(e3))

	# ── Event 4: Storm Warning ──
	var e4 = DungeonEvent.new()
	e4.event_name = "Storm Warning"
	e4.event_id = "navy_storm_warning"
	e4.description = "Dark clouds gather overhead. Lightning crackles through the sanctum halls, casting jagged shadows across the stone."
	e4.min_floor = 1
	e4.max_floor = 4

	var e4c1 = DungeonEventChoice.new()
	e4c1.choice_text = "Push forward quickly"
	e4c1.result_text = "You dash through the storm and emerge on the other side, wiser for the experience."
	e4c1.experience_reward = 20
	e4c1.success_chance = 0.75
	e4c1.fail_text = "A bolt of lightning strikes nearby — the shockwave throws you against the wall!"
	e4c1.fail_heal_amount = -12

	var e4c2 = DungeonEventChoice.new()
	e4c2.choice_text = "Wait it out"
	e4c2.result_text = "You find shelter and rest while the storm passes. The quiet does you good."
	e4c2.heal_amount = 10

	var e4_choices: Array[DungeonEventChoice] = [e4c1, e4c2]
	e4.choices.assign(e4_choices)
	events.append(_save_event(e4))

	# ── Event 5: Deserter's Offer ──
	var e5 = DungeonEvent.new()
	e5.event_name = "Deserter's Offer"
	e5.event_id = "navy_deserters_offer"
	e5.description = "A navy deserter lurks in the shadows, offering to share secrets of the sanctum's defenses — for a price."
	e5.min_floor = 3
	e5.max_floor = 7

	var e5c1 = DungeonEventChoice.new()
	e5c1.choice_text = "Pay 25 gold"
	e5c1.result_text = "The deserter reveals a fire-weakening technique. Your dice burn hotter!"
	e5c1.gold_reward = -25
	e5c1.grant_temp_affix = da_fire_damage

	var e5c2 = DungeonEventChoice.new()
	e5c2.choice_text = "Refuse"
	e5c2.result_text = "You decline the offer. The deserter shrugs and disappears into the darkness."
	e5c2.experience_reward = 10

	var e5_choices: Array[DungeonEventChoice] = [e5c1, e5c2]
	e5.choices.assign(e5_choices)
	events.append(_save_event(e5))

	# ── Event 6: Shrine of the Deep ──
	var e6 = DungeonEvent.new()
	e6.event_name = "Shrine of the Deep"
	e6.event_id = "navy_shrine_of_deep"
	e6.description = "A forgotten shrine to an ocean deity glows with faint blue light at the corridor's end. The air tastes of salt."
	e6.min_floor = 4
	e6.max_floor = 8

	var e6c1 = DungeonEventChoice.new()
	e6c1.choice_text = "Offer a prayer"
	e6c1.result_text = "The deity's warmth flows through you, mending wounds both seen and unseen."
	e6c1.heal_percent = 0.25
	e6c1.success_chance = 0.5
	e6c1.fail_text = "The deity is displeased by your presumption. Cold water crashes over you!"
	e6c1.fail_heal_amount = -15

	var e6c2 = DungeonEventChoice.new()
	e6c2.choice_text = "Take the offering bowl"
	e6c2.result_text = "The offering bowl contains a handful of ancient coins. The deity doesn't seem to mind."
	e6c2.gold_reward = 25

	var e6c3 = DungeonEventChoice.new()
	e6c3.choice_text = "Meditate quietly"
	e6c3.result_text = "You sit in contemplation. The silence brings clarity and understanding."
	e6c3.experience_reward = 15

	var e6_choices: Array[DungeonEventChoice] = [e6c1, e6c2, e6c3]
	e6.choices.assign(e6_choices)
	events.append(_save_event(e6))

	return events


func _save_event(event: DungeonEvent) -> DungeonEvent:
	var path = "%s/%s.tres" % [EVENT_DIR, event.event_id]
	var err = ResourceSaver.save(event, path)
	if err == OK:
		_count += 1
		print("  saved: %s (%d choices)" % [event.event_name, event.choices.size()])
		return load(path)
	else:
		push_error("  SAVE FAILED: %s -- %s" % [path, error_string(err)])
		_errors += 1
		return event


# ============================================================================
# DUNGEON SHRINES
# ============================================================================

func _create_shrines() -> Array[DungeonShrine]:
	var shrines: Array[DungeonShrine] = []

	# ── Shrine 1: Ironclad ──
	var s1 = DungeonShrine.new()
	s1.shrine_name = "Shrine of the Ironclad"
	s1.description = "An iron-bound altar emanates a protective aura. Runes of fortification glow along its surface, but a faint crimson haze dampens the air around it."

	var s1_blessing = Affix.new()
	s1_blessing.affix_name = "Ironclad Blessing"
	s1_blessing.description = "+N armor"
	s1_blessing.category = Affix.Category.ARMOR_BONUS
	s1_blessing.effect_min = 4.0
	s1_blessing.effect_max = 15.0
	s1_blessing.source_type = "shrine"
	var s1_blessing_tags: Array[String] = ["shrine", "defense"]
	s1_blessing.tags.assign(s1_blessing_tags)
	s1.blessing_affix = s1_blessing

	var s1_curse = Affix.new()
	s1_curse.affix_name = "Ironclad Burden"
	s1_curse.description = "Deal N% less damage"
	s1_curse.category = Affix.Category.DAMAGE_MULTIPLIER
	s1_curse.effect_min = 0.85
	s1_curse.effect_max = 0.95
	s1_curse.source_type = "shrine"
	var s1_curse_tags: Array[String] = ["shrine", "offense"]
	s1_curse.tags.assign(s1_curse_tags)
	s1.curse_affix = s1_curse
	s1.curse_description = "Your strikes feel weakened, as if pushing through water."

	shrines.append(_save_shrine(s1, "shrine_ironclad"))

	# ── Shrine 2: Tempest ──
	var s2 = DungeonShrine.new()
	s2.shrine_name = "Shrine of the Tempest"
	s2.description = "Crackling energy dances across this weathered monument, promising raw power. Static electricity makes your hair stand on end."

	var s2_blessing = Affix.new()
	s2_blessing.affix_name = "Tempest Fury"
	s2_blessing.description = "+N damage"
	s2_blessing.category = Affix.Category.DAMAGE_BONUS
	s2_blessing.effect_min = 2.0
	s2_blessing.effect_max = 8.0
	s2_blessing.source_type = "shrine"
	var s2_blessing_tags: Array[String] = ["shrine", "offense"]
	s2_blessing.tags.assign(s2_blessing_tags)
	s2.blessing_affix = s2_blessing

	var s2_curse = Affix.new()
	s2_curse.affix_name = "Tempest Exposure"
	s2_curse.description = "N% less defense"
	s2_curse.category = Affix.Category.DEFENSE_MULTIPLIER
	s2_curse.effect_min = 0.80
	s2_curse.effect_max = 0.90
	s2_curse.source_type = "shrine"
	var s2_curse_tags: Array[String] = ["shrine", "defense"]
	s2_curse.tags.assign(s2_curse_tags)
	s2.curse_affix = s2_curse
	s2.curse_description = "The tempest strips away your protection."

	shrines.append(_save_shrine(s2, "shrine_tempest"))

	# ── Shrine 3: Navigator (no curse) ──
	var s3 = DungeonShrine.new()
	s3.shrine_name = "Shrine of the Navigator"
	s3.description = "A compass rose carved into the floor glows softly, offering clarity. The air around it is still and focused."

	var s3_blessing = Affix.new()
	s3_blessing.affix_name = "Navigator's Clarity"
	s3_blessing.description = "+N max mana"
	s3_blessing.category = Affix.Category.MANA_BONUS
	s3_blessing.effect_min = 1.0
	s3_blessing.effect_max = 4.0
	s3_blessing.source_type = "shrine"
	var s3_blessing_tags: Array[String] = ["shrine", "utility"]
	s3_blessing.tags.assign(s3_blessing_tags)
	s3.blessing_affix = s3_blessing

	shrines.append(_save_shrine(s3, "shrine_navigator"))

	# ── Shrine 4: Tide ──
	var s4 = DungeonShrine.new()
	s4.shrine_name = "Shrine of the Tide"
	s4.description = "Seawater pools at the base of this coral-encrusted altar, pulsing with restorative energy. Barnacles cling to its surface."

	var s4_blessing = Affix.new()
	s4_blessing.affix_name = "Tidal Restoration"
	s4_blessing.description = "Healing is N% more effective"
	s4_blessing.category = Affix.Category.HEALING_MULTIPLIER
	s4_blessing.effect_min = 1.10
	s4_blessing.effect_max = 1.40
	s4_blessing.source_type = "shrine"
	var s4_blessing_tags: Array[String] = ["shrine", "healing"]
	s4_blessing.tags.assign(s4_blessing_tags)
	s4.blessing_affix = s4_blessing

	var s4_curse = Affix.new()
	s4_curse.affix_name = "Tidal Ebb"
	s4_curse.description = "N max health"
	s4_curse.category = Affix.Category.HEALTH_BONUS
	s4_curse.effect_min = -15.0
	s4_curse.effect_max = -5.0
	s4_curse.source_type = "shrine"
	var s4_curse_tags: Array[String] = ["shrine", "health"]
	s4_curse.tags.assign(s4_curse_tags)
	s4.curse_affix = s4_curse
	s4.curse_description = "The tide recedes, taking some of your vitality with it."

	shrines.append(_save_shrine(s4, "shrine_tide"))

	return shrines


func _save_shrine(shrine: DungeonShrine, file_id: String) -> DungeonShrine:
	var path = "%s/%s.tres" % [SHRINE_DIR, file_id]
	var err = ResourceSaver.save(shrine, path)
	if err == OK:
		_count += 1
		var curse_str = " + curse" if shrine.has_curse() else ""
		print("  saved: %s (blessing%s)" % [shrine.shrine_name, curse_str])
		return load(path)
	else:
		push_error("  SAVE FAILED: %s -- %s" % [path, error_string(err)])
		_errors += 1
		return shrine


# ============================================================================
# DUNGEON DEFINITION
# ============================================================================

func _build_dungeon(trash: Array[CombatEncounter],
		elite: Array[CombatEncounter],
		boss: Array[CombatEncounter],
		events: Array[DungeonEvent],
		shrines: Array[DungeonShrine]):

	var dun = DungeonDefinition.new()
	dun.dungeon_name = "Sanctum Navy Fortress"
	dun.dungeon_id = "sanctum_navy"
	dun.description = "The Sanctum Navy's coastal fortress. Navigate through barracks, armories, and command halls guarded by disciplined soldiers and war mages."
	dun.floor_count = 8
	dun.dungeon_level = 5
	dun.dungeon_region = 1

	dun.combat_encounters.assign(trash)
	dun.elite_encounters.assign(elite)
	dun.boss_encounters.assign(boss)
	dun.event_pool.assign(events)
	dun.shrine_pool.assign(shrines)

	# ── Loot & shop pools (equippable items) ──
	var equip_items := _load_all_from_dir_recursive(ITEM_DIR)
	print("  Loaded %d equippable item templates" % equip_items.size())
	var typed_equip: Array[EquippableItem] = []
	for item in equip_items:
		if item is EquippableItem:
			typed_equip.append(item)
	dun.loot_pool.assign(typed_equip)
	dun.shop_pool.assign(typed_equip)

	# ── Consumable pools ──
	var shop_consumables: Array[ConsumableItem] = []
	var loot_consumables: Array[ConsumableItem] = []

	for subdir in ["restoratives", "combat_preps", "dice_elixirs"]:
		var dir_path = "%s/%s" % [CONSUMABLE_DIR, subdir]
		var loaded = _load_all_from_dir(dir_path)
		for res in loaded:
			if res is ConsumableItem:
				shop_consumables.append(res)
				if subdir in ["restoratives", "dice_elixirs"]:
					loot_consumables.append(res)

	print("  Loaded %d shop consumables, %d loot consumables" % [
		shop_consumables.size(), loot_consumables.size()])
	dun.consumable_shop_pool.assign(shop_consumables)
	dun.consumable_loot_pool.assign(loot_consumables)

	# ── Rest affix pool (existing dice affixes) ──
	var rest_affixes: Array[DiceAffix] = []
	for da_file in ["tier_1/bonus_damage_flat", "tier_2/heal_on_use_flat",
					 "tier_1/add_fire_damage_flat", "tier_1/add_ice_damage_flat",
					 "tier_1/add_shock_damage_flat"]:
		var da = _load_if_exists("%s/%s.tres" % [DICE_AFFIX_DIR, da_file])
		if da: rest_affixes.append(da)
	dun.rest_affix_pool.assign(rest_affixes)
	print("  %d rest affixes" % rest_affixes.size())

	# ── Run affix pool (existing run affixes) ──
	var run_affixes: Array[RunAffixEntry] = []
	var ra_loaded = _load_all_from_dir(RUN_AFFIX_DIR)
	for res in ra_loaded:
		if res is RunAffixEntry:
			run_affixes.append(res)
	dun.run_affix_pool.assign(run_affixes)
	print("  %d run affixes" % run_affixes.size())

	dun.affix_choices_per_offer = 3
	dun.offer_on_entry = true
	dun.offer_after_elite = true

	dun.gold_per_combat = 15
	dun.gold_per_elite = 30
	dun.exp_per_combat = 20
	dun.exp_per_elite = 50

	dun.min_nodes_per_floor = 2
	dun.max_nodes_per_floor = 3
	dun.safe_floor_before_boss = true
	dun.mid_safe_floor = true

	var path = "%s/sanctum_navy.tres" % DUNGEON_DIR
	var err = ResourceSaver.save(dun, path)
	if err == OK:
		_count += 1
		print("  saved: %s (%d floors, %d/%d/%d encounters, %d events, %d shrines)" % [
			dun.dungeon_name, dun.floor_count,
			trash.size(), elite.size(), boss.size(),
			events.size(), shrines.size()])
	else:
		push_error("  SAVE FAILED: %s" % error_string(err))
		_errors += 1


# ============================================================================
# UTILITY
# ============================================================================

func _load_if_exists(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("  Not found: %s" % path)
	return null


func _load_all_from_dir(dir_path: String) -> Array:
	var results: Array = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_warning("  Cannot open: %s" % dir_path)
		return results
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(path):
				results.append(load(path))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _load_all_from_dir_recursive(dir_path: String) -> Array:
	var results: Array = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_warning("  Cannot open: %s" % dir_path)
		return results
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = "%s/%s" % [dir_path, file_name]
		if dir.current_is_dir() and not file_name.begins_with("."):
			results.append_array(_load_all_from_dir_recursive(full_path))
		elif file_name.ends_with(".tres"):
			if ResourceLoader.exists(full_path):
				results.append(load(full_path))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
