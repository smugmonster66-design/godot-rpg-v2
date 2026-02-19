@tool
extends EditorScript
# ============================================================================
# generate_baseline_enemies.gd  (DEBUG BUILD)
# Creates one EnemyData per template x tier = 50 enemies.
# ============================================================================

const TEMPLATE_DIR := "res://resources/enemy_templates"
const DICE_DIR := "res://resources/dice/base"
const OUTPUT_DIR := "res://resources/enemies/baseline"

const TIER_TRASH := 0
const TIER_ELITE := 1
const TIER_MINI_BOSS := 2
const TIER_BOSS := 3
const TIER_WORLD_BOSS := 4

var _count := 0
var _errors := 0
var _templates: Dictionary = {}
var _dice_cache: Dictionary = {}

# Element mapping per template
const TEMPLATE_ELEMENTS := {
	"brute_str":      ["blunt"],
	"brute_agi":      ["piercing"],
	"skirmisher_agi": ["slashing"],
	"skirmisher_int": ["shock", "ice"],
	"caster_int":     ["fire"],
	"tank_str":       ["blunt"],
	"tank_int":       ["shadow"],
	"support_str":    ["none"],
	"support_int":    ["none"],
	"support_agi":    ["none"],
}


func _run():
	print("=" .repeat(70))
	print("  BASELINE ENEMY GENERATOR (DEBUG BUILD)")
	print("=" .repeat(70))

	print("\n[PHASE 0] Validating...")
	if not _validate_and_load():
		push_error("Aborting.")
		return
	print("[PHASE 0] Done.")

	print("\n[PHASE 1] Creating directories...")
	_ensure_directories()
	print("[PHASE 1] Done.")

	print("\n[PHASE 2] Creating enemies...")

	var template_defs := [
		["brute_str",      "Brute",       0],
		["brute_agi",      "Duelist",     0],
		["skirmisher_agi", "Skirmisher",  1],
		["skirmisher_int", "Battle Mage", 1],
		["caster_int",     "Archmage",    2],
		["tank_str",       "Tank",        3],
		["tank_int",       "War Mage",    3],
		["support_str",    "Marshal",     4],
		["support_int",    "Support Mage",4],
		["support_agi",    "Trickster",   4],
	]

	var tier_defs := [
		[TIER_TRASH,      "",           "trash"],
		[TIER_ELITE,      "Elite",      "elite"],
		[TIER_MINI_BOSS,  "Mini-Boss",  "mini_boss"],
		[TIER_BOSS,       "Boss",       "boss"],
		[TIER_WORLD_BOSS, "World Boss", "world_boss"],
	]

	for t_idx in range(template_defs.size()):
		var tdef = template_defs[t_idx]
		var file_name = tdef[0]
		var display_name = tdef[1]
		var role_val = tdef[2]
		print("\n  --- Template %d: %s (%s) ---" % [t_idx, display_name, file_name])

		if not _templates.has(file_name):
			push_error("    Template not in cache!")
			_errors += 1
			continue
		var template = _templates[file_name]

		for tier_idx in range(tier_defs.size()):
			var tier = tier_defs[tier_idx]
			var tier_enum = tier[0]
			var prefix = tier[1]
			var folder = tier[2]

			var enemy_name = display_name if prefix.is_empty() else "%s %s" % [prefix, display_name]
			print("    >> %s (tier=%d)" % [enemy_name, tier_enum])

			print("    [A] getting budget for tier %d..." % tier_enum)
			var budget = null
			match tier_enum:
				TIER_TRASH: budget = template.trash_budget
				TIER_ELITE: budget = template.elite_budget
				TIER_MINI_BOSS: budget = template.mini_boss_budget
				TIER_BOSS: budget = template.boss_budget
				TIER_WORLD_BOSS: budget = template.world_boss_budget
			if not budget:
				push_error("    No budget!")
				_errors += 1
				continue
			print("    [A] Budget OK")

			print("    [B] Entering _create_enemy...")
			_create_enemy(enemy_name, file_name, template, role_val, tier_enum, folder, budget)
			print("    [B] Returned from _create_enemy")

	print("\n" + "=" .repeat(70))
	if _errors == 0:
		print("  SUCCESS: %d enemies" % _count)
	else:
		print("  %d ERRORS, %d enemies" % [_errors, _count])
	print("=" .repeat(70))


func _validate_and_load() -> bool:
	print("  Loading templates...")
	var ok := true

	var fnames := [
		"brute_str", "brute_agi", "skirmisher_agi", "skirmisher_int",
		"caster_int", "tank_str", "tank_int", "support_str",
		"support_int", "support_agi",
	]

	for i in range(fnames.size()):
		var fname = fnames[i]
		var path = "%s/%s.tres" % [TEMPLATE_DIR, fname]
		if ResourceLoader.exists(path):
			_templates[fname] = load(path)
			print("    ok: %s" % fname)
		else:
			push_error("    MISSING: %s" % path)
			ok = false

	print("  Loading base dice...")
	var sizes = [4, 6, 8, 10, 12]
	var elems = ["none", "slashing", "blunt", "piercing", "fire", "ice", "shock", "shadow"]
	for s_idx in range(sizes.size()):
		for e_idx in range(elems.size()):
			var sz = sizes[s_idx]
			var el = elems[e_idx]
			var key = "d%d_%s" % [sz, el]
			var path = "%s/%s.tres" % [DICE_DIR, key]
			if ResourceLoader.exists(path):
				_dice_cache[key] = load(path)
			else:
				if el == "none":
					push_error("    MISSING: %s" % path)
					ok = false
	print("    Loaded %d base dice" % _dice_cache.size())
	return ok


func _ensure_directories():
	var folders = ["trash", "elite", "mini_boss", "boss", "world_boss"]
	for i in range(folders.size()):
		var dir_path = "%s/%s" % [OUTPUT_DIR, folders[i]]
		DirAccess.make_dir_recursive_absolute(dir_path)
		print("    dir: %s" % dir_path)


func _create_enemy(enemy_name: String, template_key: String,
		template, role_val: int, tier_enum: int,
		folder: String, budget):

	print("      [1] EnemyData.new()")
	var enemy = EnemyData.new()

	print("      [2] enemy_name = %s" % enemy_name)
	enemy.enemy_name = enemy_name
	enemy.description = "Baseline %s." % enemy_name

	print("      [3] template ref")
	enemy.template = template

	print("      [4] combat_role = %d" % role_val)
	enemy.combat_role = role_val

	print("      [5] dice pool")
	var dice = _build_dice_pool(template_key, budget)
	print("      [5] got %d dice" % dice.size())
	enemy.starting_dice.assign(dice)
	print("      [5] assigned")

	print("      [6] actions")
	var all_actions = template.default_actions
	print("      [6] template has %d actions" % all_actions.size())
	var actions: Array[Action] = []
	if tier_enum == TIER_TRASH:
		var limit = mini(2, all_actions.size())
		for i in range(limit):
			if all_actions[i]:
				actions.append(all_actions[i])
	else:
		for i in range(all_actions.size()):
			if all_actions[i]:
				actions.append(all_actions[i])
	print("      [6] assigning %d" % actions.size())
	enemy.combat_actions.assign(actions)
	print("      [6] done")

	print("      [7] stats")
	var base_hp = [10, 15, 25, 40, 60]
	enemy.max_health = int(base_hp[tier_enum] * template.health_weight)
	var def_base = int(budget.defense_scale * 2.0)
	enemy.base_armor = int(def_base * template.armor_weight)
	enemy.base_barrier = int(def_base * template.barrier_weight)
	print("      [7] HP=%d A=%d B=%d" % [enemy.max_health, enemy.base_armor, enemy.base_barrier])

	print("      [8] health affix")
	if template.default_health_affix:
		enemy.health_affix = template.default_health_affix
	print("      [8] done")

	print("      [9] stat affixes")
	# Guard with get() in case property doesn't exist on template
	var has_stat_affixes = template.get("default_stat_affixes")
	if has_stat_affixes and has_stat_affixes.size() > 0:
		enemy.enemy_affixes.assign(has_stat_affixes)
		print("      [9] assigned %d" % has_stat_affixes.size())
	else:
		print("      [9] none")

	print("      [10] AI")
	if budget.override_ai_strategy:
		enemy.ai_strategy = budget.ai_strategy_override
	else:
		enemy.ai_strategy = template.default_ai_strategy
	enemy.target_priority = template.default_target_priority
	enemy.action_delay = budget.action_delay
	enemy.dice_drag_duration = budget.dice_drag_duration
	print("      [10] done")

	print("      [11] visual events")
	var atk_ev = template.get("default_attack_event")
	if atk_ev:
		enemy.attack_event = atk_ev
	var hit_ev = template.get("default_hit_event")
	if hit_ev:
		enemy.hit_event = hit_ev
	var death_ev = template.get("default_death_event")
	if death_ev:
		enemy.death_event = death_ev
	print("      [11] done")

	print("      [12] rewards")
	var xp = [10, 30, 75, 150, 500]
	var gmin = [3, 10, 25, 50, 150]
	var gmax = [10, 30, 75, 150, 500]
	enemy.experience_reward = xp[tier_enum]
	enemy.gold_reward_min = gmin[tier_enum]
	enemy.gold_reward_max = gmax[tier_enum]
	print("      [12] done")

	print("      [13] loot tier/arch")
	enemy.enemy_tier = tier_enum
	enemy.enemy_archetype = template.archetype
	print("      [13] done")

	print("      [14] level scaling")
	var floors = [1, 3, 5, 8, 12]
	enemy.enemy_level_floor = floors[tier_enum]
	enemy.level_scaling_multiplier = budget.level_scaling
	print("      [14] done")

	print("      [15] saving...")
	var safe_name = enemy_name.to_lower().replace(" ", "_").replace("-", "_")
	var path = "%s/%s/%s.tres" % [OUTPUT_DIR, folder, safe_name]
	var err = ResourceSaver.save(enemy, path)
	if err == OK:
		_count += 1
		print("      SAVED: %s" % path)
	else:
		push_error("      SAVE FAILED: %s -- %s" % [path, error_string(err)])
		_errors += 1


func _build_dice_pool(template_key: String, budget) -> Array[DieResource]:
	var dice: Array[DieResource] = []
	var dice_count = budget.dice_count_max
	var die_size = mini(int(budget.die_size_ceiling), 12)
	var elements = TEMPLATE_ELEMENTS.get(template_key, ["none"])
	print("      [5a] %d x d%d, elem=%s" % [dice_count, die_size, str(elements)])

	for i in range(dice_count):
		var elem = elements[i % elements.size()]
		var key = "d%d_%s" % [die_size, elem]
		if not _dice_cache.has(key):
			print("      [5b] fallback: %s" % key)
			key = "d%d_none" % die_size
		if _dice_cache.has(key):
			dice.append(_dice_cache[key])
		else:
			push_error("      no die: %s" % key)
			_errors += 1

	return dice
