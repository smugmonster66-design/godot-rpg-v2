@tool
extends EditorScript
## test_roguelite_data.gd — DIAGNOSTIC VERSION
## Prints detailed state at each step to identify the root cause.

var _pass_count: int = 0
var _fail_count: int = 0


func _run():
	print("\n╔══════════════════════════════════════════╗")
	print("║   ROGUELITE DATA LAYER TESTS             ║")
	print("╚══════════════════════════════════════════╝")
	_test_run_affix_entry()
	_test_run_affix_entry_validation()
	_test_shared_array_diagnostic()
	_test_run_affix_roller_basic()
	_test_run_affix_roller_exclusion()
	_test_run_affix_roller_stacks()
	_test_dungeon_list_entry()
	_test_dungeon_run_tracking()
	print("\n══════════════════════════════════════════")
	if _fail_count == 0:
		print("  ✅ ALL PASSED: %d tests" % _pass_count)
	else:
		print("  Results: %d passed, %d FAILED" % [_pass_count, _fail_count])
	print("══════════════════════════════════════════")


func _assert(label: String, condition: bool, debug_info: String = ""):
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		if debug_info != "":
			print("  ❌ FAIL: %s — %s" % [label, debug_info])
		else:
			print("  ❌ FAIL: %s" % label)


func _make_entry(id: String, entry_name: String, rarity: RunAffixEntry.Rarity,
				  tags: Array = [], exclusive: Array = [],
				  stacks: int = 1, weight: int = 10) -> RunAffixEntry:
	var e := RunAffixEntry.new()
	e.affix_id = id
	e.display_name = entry_name
	e.rarity = rarity
	e.max_stacks = stacks
	e.offer_weight = weight
	e.affix_type = RunAffixEntry.AffixType.DICE
	e.dice_affix = DiceAffix.new()
	e.dice_affix.display_name = entry_name
	e.tags.assign(tags)
	e.mutually_exclusive_tags.assign(exclusive)
	return e


func _make_pool(entries: Array) -> Array:
	var pool := []
	for i in entries.size():
		pool.append(entries[i])
	return pool


func _offer_ids(offers: Array) -> Array:
	var ids := []
	for i in offers.size():
		if offers[i]:
			ids.append(offers[i].affix_id)
		else:
			ids.append("null")
	return ids


# ============================================================================
# DIAGNOSTIC: Understand shared array behavior
# ============================================================================

func _test_shared_array_diagnostic():
	print("\n🔬 DIAGNOSTIC: Shared array behavior")

	var a := DungeonRun.new()
	var b := DungeonRun.new()

	print("    a.run_affixes_chosen.size() after .new(): %d" % a.run_affixes_chosen.size())
	print("    b.run_affixes_chosen.size() after .new(): %d" % b.run_affixes_chosen.size())

	# Check if they share the same array
	var entry := _make_entry("diag", "Diag", RunAffixEntry.Rarity.COMMON)
	a.run_affixes_chosen.append(entry)

	print("    After appending to a:")
	print("      a.size(): %d" % a.run_affixes_chosen.size())
	print("      b.size(): %d" % b.run_affixes_chosen.size())

	var shared: bool = (b.run_affixes_chosen.size() > 0)
	print("    SHARED ARRAY: %s" % str(shared))

	if shared:
		print("    ⚠️ Arrays ARE shared — _init() is not breaking the link")
		print("    ⚠️ Trying manual workaround...")
		# Test if explicit assignment works
		var c := DungeonRun.new()
		c.run_affixes_chosen = []
		print("    c.size() after = []: %d" % c.run_affixes_chosen.size())
		a.run_affixes_chosen.append(entry)
		print("    c.size() after appending to a: %d" % c.run_affixes_chosen.size())
		var still_shared: bool = (c.run_affixes_chosen.size() > 0)
		print("    Assignment breaks link: %s" % str(not still_shared))

	# Check if _init exists
	print("    DungeonRun has _init: %s" % str(a.has_method("_init")))

	# Clean up — remove what we added so it doesn't leak into later tests
	a.run_affixes_chosen.clear()
	b.run_affixes_chosen.clear()

	_assert("diagnostic ran", true)
	print("  ✓ Shared array diagnostic")


# ============================================================================
# TESTS
# ============================================================================

func _test_run_affix_entry():
	print("\n📋 Test: RunAffixEntry basics")
	var e := _make_entry("test_fire", "Searing Dice", RunAffixEntry.Rarity.COMMON,
		["fire", "offense"])

	_assert("display_name set", e.display_name == "Searing Dice")
	_assert("rarity name", e.get_rarity_name() == "Common",
		"got '%s'" % e.get_rarity_name())
	_assert("rarity color not white", e.get_rarity_color() != Color.WHITE)
	_assert("tags size == 2", e.tags.size() == 2,
		"got %d: %s" % [e.tags.size(), str(e.tags)])
	_assert("has_tag fire", e.has_tag("fire"),
		"tags: %s" % str(e.tags))
	_assert("has_tag defense false", not e.has_tag("defense"))
	_assert("effective weight common = full", e.get_effective_weight() == 10,
		"got %d" % e.get_effective_weight())

	var u := _make_entry("u", "U", RunAffixEntry.Rarity.UNCOMMON)
	_assert("effective weight uncommon", u.get_effective_weight() == 6,
		"got %d" % u.get_effective_weight())

	var r := _make_entry("r", "R", RunAffixEntry.Rarity.RARE)
	_assert("effective weight rare", r.get_effective_weight() == 3,
		"got %d" % r.get_effective_weight())
	print("  ✓ RunAffixEntry basics")


func _test_run_affix_entry_validation():
	print("\n📋 Test: RunAffixEntry validation")
	var bad := RunAffixEntry.new()
	var bad_w := bad.validate()
	_assert("empty entry has warnings", bad_w.size() > 0,
		"got %d warnings" % bad_w.size())

	var good := _make_entry("valid", "Valid Entry", RunAffixEntry.Rarity.COMMON)
	var good_w := good.validate()
	_assert("valid entry has no warnings", good_w.size() == 0,
		"warnings: %s" % str(good_w))

	var stat_no_affix := RunAffixEntry.new()
	stat_no_affix.affix_id = "bad_stat"
	stat_no_affix.display_name = "Bad Stat"
	stat_no_affix.affix_type = RunAffixEntry.AffixType.STAT
	var sna_w := stat_no_affix.validate()
	_assert("STAT type without stat_affix warns", sna_w.size() > 0,
		"got %d warnings" % sna_w.size())
	print("  ✓ RunAffixEntry validation")


func _test_run_affix_roller_basic():
	print("\n📋 Test: RunAffixRoller basic selection")

	var entries := []
	for i in 6:
		entries.append(_make_entry("e%d" % i, "Entry %d" % i, RunAffixEntry.Rarity.COMMON))
	var pool := _make_pool(entries)

	_assert("pool has 6", pool.size() == 6, "got %d" % pool.size())

	# Manually build a run with guaranteed empty array
	var run := DungeonRun.new()
	run.run_affixes_chosen = []
	run.affix_offers_given = 0

	print("    run.run_affixes_chosen.size(): %d" % run.run_affixes_chosen.size())
	print("    pool[0].affix_id: '%s', max_stacks: %d" % [pool[0].affix_id, pool[0].max_stacks])

	# Manually test filter
	var roller := RunAffixRoller.new()
	var eligible = roller._filter_eligible(pool, run)
	print("    _filter_eligible returned: %d entries" % eligible.size())

	if eligible.size() == 0 and pool.size() > 0:
		# Debug WHY they were filtered
		print("    🔬 Debugging filter for pool[0]:")
		var test_entry = pool[0]
		var stack = run.get_run_affix_stack_count(test_entry)
		print("      stack_count: %d, max_stacks: %d, filtered: %s" % [
			stack, test_entry.max_stacks, str(stack >= test_entry.max_stacks)])

	var offers := roller.roll_offers(pool, run, 3)

	_assert("got 3 offers", offers.size() == 3,
		"got %d (pool=%d, eligible=%d)" % [offers.size(), pool.size(), eligible.size()])

	var ids := []
	for i in offers.size():
		var o = offers[i]
		_assert("offer not null", o != null)
		if o:
			_assert("offer is distinct", o.affix_id not in ids,
				"duplicate: %s" % o.affix_id)
			ids.append(o.affix_id)

	# Clean up shared array if it exists
	run.run_affixes_chosen.clear()
	print("  ✓ RunAffixRoller basic selection")


func _test_run_affix_roller_exclusion():
	print("\n📋 Test: RunAffixRoller mutual exclusion")

	var fire := _make_entry("fire1", "Fire 1", RunAffixEntry.Rarity.COMMON,
		["fire"], [])
	var ice := _make_entry("ice1", "Ice 1", RunAffixEntry.Rarity.COMMON,
		["ice"], ["fire"])
	var neutral := _make_entry("neutral", "Neutral", RunAffixEntry.Rarity.COMMON)

	_assert("ice has exclusive tag 'fire'", ice.mutually_exclusive_tags.has("fire"),
		"exclusive_tags: %s" % str(ice.mutually_exclusive_tags))

	var pool := _make_pool([fire, ice, neutral])

	var run := DungeonRun.new()
	run.run_affixes_chosen = []
	run.affix_offers_given = 0
	run.run_affixes_chosen.append(fire)

	var roller := RunAffixRoller.new()
	var offers := roller.roll_offers(pool, run, 3)

	var has_ice: bool = false
	for i in offers.size():
		if offers[i] and offers[i].affix_id == "ice1":
			has_ice = true
	_assert("ice excluded when fire active", not has_ice,
		"offers: %s" % str(_offer_ids(offers)))

	run.run_affixes_chosen.clear()
	print("  ✓ RunAffixRoller mutual exclusion")


func _test_run_affix_roller_stacks():
	print("\n📋 Test: RunAffixRoller stack limits")

	var stackable := _make_entry("stack", "Stackable", RunAffixEntry.Rarity.COMMON,
		[], [], 2)
	var unique := _make_entry("unique", "Unique", RunAffixEntry.Rarity.COMMON,
		[], [], 1)
	var filler := _make_entry("filler", "Filler", RunAffixEntry.Rarity.COMMON)

	var pool := _make_pool([stackable, unique, filler])
	var roller := RunAffixRoller.new()

	# ── Test 1: Unique at max (1/1) ──
	print("    ── Sub-test 1: unique at max ──")
	var run1 := DungeonRun.new()
	run1.run_affixes_chosen = []
	run1.affix_offers_given = 0
	print("    run1 after reset: size=%d" % run1.run_affixes_chosen.size())

	run1.run_affixes_chosen.append(unique)
	print("    run1 after append(unique): size=%d" % run1.run_affixes_chosen.size())

	var sc1 := run1.get_run_affix_stack_count(unique)
	_assert("unique stack count is 1", sc1 == 1, "got %d" % sc1)

	var offers := roller.roll_offers(pool, run1, 3)
	var has_unique: bool = false
	for i in offers.size():
		if offers[i] and offers[i].affix_id == "unique":
			has_unique = true
	_assert("unique not offered again", not has_unique,
		"offers: %s" % str(_offer_ids(offers)))
	run1.run_affixes_chosen.clear()

	# ── Test 2: Stackable at 1/2 ──
	print("    ── Sub-test 2: stackable at 1/2 ──")
	var run2 := DungeonRun.new()
	run2.run_affixes_chosen = []
	run2.affix_offers_given = 0
	print("    run2 after reset: size=%d" % run2.run_affixes_chosen.size())

	run2.run_affixes_chosen.append(unique)
	run2.run_affixes_chosen.append(stackable)
	print("    run2 after appends: size=%d" % run2.run_affixes_chosen.size())

	# Dump contents
	for i in run2.run_affixes_chosen.size():
		var item = run2.run_affixes_chosen[i]
		print("      [%d] id='%s' name='%s'" % [i, item.affix_id, item.display_name])

	var sc2 := run2.get_run_affix_stack_count(stackable)
	print("    get_run_affix_stack_count(stackable): %d" % sc2)
	_assert("stackable stack count is 1", sc2 == 1, "got %d" % sc2)

	var offers2 := roller.roll_offers(pool, run2, 3)
	var has_s: bool = false
	for i in offers2.size():
		if offers2[i] and offers2[i].affix_id == "stack":
			has_s = true
	_assert("stackable still offered at 1/2", has_s,
		"offers: %s" % str(_offer_ids(offers2)))
	run2.run_affixes_chosen.clear()

	# ── Test 3: Stackable at 2/2 ──
	print("    ── Sub-test 3: stackable at 2/2 ──")
	var run3 := DungeonRun.new()
	run3.run_affixes_chosen = []
	run3.affix_offers_given = 0

	run3.run_affixes_chosen.append(unique)
	run3.run_affixes_chosen.append(stackable)
	run3.run_affixes_chosen.append(stackable)
	print("    run3 after appends: size=%d" % run3.run_affixes_chosen.size())

	var sc3 := run3.get_run_affix_stack_count(stackable)
	_assert("stackable stack count is 2", sc3 == 2, "got %d" % sc3)

	var offers3 := roller.roll_offers(pool, run3, 3)
	var has_s2: bool = false
	for i in offers3.size():
		if offers3[i] and offers3[i].affix_id == "stack":
			has_s2 = true
	_assert("stackable not offered at 2/2", not has_s2,
		"offers: %s" % str(_offer_ids(offers3)))
	run3.run_affixes_chosen.clear()

	print("  ✓ RunAffixRoller stack limits")


func _test_dungeon_list_entry():
	print("\n📋 Test: DungeonListEntry")

	var entry := DungeonListEntry.new()
	var def := DungeonDefinition.new()
	def.dungeon_name = "Test Crypt"
	def.dungeon_id = "test_crypt"
	def.dungeon_level = 5
	def.floor_count = 8
	entry.dungeon_definition = def

	_assert("display name from def", entry.get_display_name() == "Test Crypt",
		"got '%s'" % entry.get_display_name())
	_assert("display level from def", entry.get_display_level() == 5,
		"got %d" % entry.get_display_level())
	_assert("floor count", entry.get_floor_count() == 8,
		"got %d" % entry.get_floor_count())

	entry.unlock_type = DungeonListEntry.UnlockType.NONE
	_assert("NONE always unlocked", entry.is_unlocked(null))

	entry.unlock_type = DungeonListEntry.UnlockType.PLAYER_LEVEL
	entry.unlock_value = 10

	var low_player := Player.new()
	low_player.level = 5
	_assert("level gate blocks low player", not entry.is_unlocked(low_player),
		"player level=%d, gate=%d" % [low_player.level, entry.unlock_value])

	var high_player := Player.new()
	high_player.level = 10
	_assert("level gate passes high player", entry.is_unlocked(high_player),
		"player level=%d, gate=%d" % [high_player.level, entry.unlock_value])

	var lock_text := entry.get_lock_text()
	_assert("lock text shows level", lock_text.contains("10"),
		"got '%s'" % lock_text)
	print("  ✓ DungeonListEntry")


func _test_dungeon_run_tracking():
	print("\n📋 Test: DungeonRun affix tracking")

	var run := DungeonRun.new()
	run.run_affixes_chosen = []
	run.affix_offers_given = 0

	_assert("starts with 0 affixes", run.run_affixes_chosen.size() == 0,
		"got %d" % run.run_affixes_chosen.size())
	_assert("starts with 0 offers", run.affix_offers_given == 0)

	var entry := _make_entry("tracked", "Tracked Entry", RunAffixEntry.Rarity.COMMON,
		["fire", "offense"])
	_assert("entry tags size == 2", entry.tags.size() == 2,
		"got %d: %s" % [entry.tags.size(), str(entry.tags)])

	run.track_run_affix(entry)

	_assert("1 affix tracked", run.run_affixes_chosen.size() == 1,
		"got %d" % run.run_affixes_chosen.size())
	_assert("1 offer given", run.affix_offers_given == 1,
		"got %d" % run.affix_offers_given)
	_assert("stack count is 1", run.get_run_affix_stack_count(entry) == 1,
		"got %d" % run.get_run_affix_stack_count(entry))

	_assert("has fire tag", run.has_run_affix_tag("fire"),
		"all tags: %s" % str(run.get_all_run_affix_tags()))
	_assert("has offense tag", run.has_run_affix_tag("offense"),
		"all tags: %s" % str(run.get_all_run_affix_tags()))
	_assert("no defense tag", not run.has_run_affix_tag("defense"))

	var all_tags := run.get_all_run_affix_tags()
	_assert("all tags has fire", "fire" in all_tags,
		"all_tags: %s" % str(all_tags))
	_assert("all tags size 2", all_tags.size() == 2,
		"got %d: %s" % [all_tags.size(), str(all_tags)])

	run.skip_affix_offer()
	_assert("skip increments offers", run.affix_offers_given == 2,
		"got %d" % run.affix_offers_given)
	_assert("skip doesn't add affix", run.run_affixes_chosen.size() == 1,
		"got %d" % run.run_affixes_chosen.size())

	run.run_affixes_chosen.clear()
	print("  ✓ DungeonRun affix tracking")
