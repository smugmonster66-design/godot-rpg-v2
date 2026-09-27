# res://tools/balance_sim/balance_sim.gd
# Headless balance simulator: real gear (loot code), real dice and dice
# affixes, real enemies and encounters, and the real CombatManager rules,
# driven by a simple player policy. Skills and companions are left out.
#
# Run (one shard; shards can run in parallel, one per level):
#   godot --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=run
#       levels=18 chars=100 fights=2 runs=1 outlevel=0 seed=1 tag=baseline out=<dir>/L18.csv
#   Lists use ";" (levels="1;18;35"). Other keys: profiles, builds (str;int),
#   tiers (trash;elite;miniboss;boss), outlevel_levels, verbose=1 (engine logs),
#   knob.NAME=value (sets a CombatTuning static var for this run).
# Report (reads every .csv in <dir>):
#   godot --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=report
#       in=<dir> title="..." md=<file.md> csv=<summary.csv> intro=<optional .md to insert>
# Smoke test: mode=smoke level=18 (one character per build and profile).
#
# The root node is named GameRoot with show_title_screen on, so GameManager
# leaves the boot flow alone (no new game, no map scene).
extends Node

const Factory = preload("res://tools/balance_sim/sim_character_factory.gd")
const SimCM = preload("res://tools/balance_sim/sim_combat_manager.gd")
const Report = preload("res://tools/balance_sim/sim_report.gd")

var show_title_screen: bool = true  # read by GameManager._ready

const LEVELS := [1, 18, 35, 50, 75, 100]
const TIERS := ["trash", "elite", "miniboss", "boss"]
const ENC_DIRS := {
	"trash": ["res://resources/encounters/baseline/trash/", "res://resources/encounters/region1/navy/trash/"],
	"elite": ["res://resources/encounters/baseline/elite/", "res://resources/encounters/region1/navy/elite/"],
	"boss": ["res://resources/encounters/baseline/boss/", "res://resources/encounters/region1/navy/boss/"],
}
const MINIBOSS_DIRS := ["res://resources/enemies/baseline/mini_boss/", "res://resources/enemies/region1/navy/mini_boss/"]
## A dungeon run: fights in order (floor = index), HP carried between them.
const RUN_PLAN := ["trash", "trash", "elite", "trash", "miniboss", "elite", "boss"]
const RUN_KITS := {
	"undergeared": ["navy_ration_biscuit", "hardtack_surplus"],
	"on_curve": ["hardtack_surplus", "restorative_bundle", "sanctum_tonic"],
	"well_geared": ["sanctum_tonic", "sanctum_tonic", "officers_brandy", "officers_brandy"],
	"min_maxed": ["officers_brandy", "officers_brandy", "admiralty_reserve", "admiralty_reserve"],
}

var args: Dictionary = {}
var factory = null
var cm = null
var pools: Dictionary = {}  # tier -> Array of {enc, family}
var _log_file: FileAccess = null


func _ready() -> void:
	name = "GameRoot"
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _progress(msg: String) -> void:
	var was: bool = Engine.print_to_stdout
	Engine.print_to_stdout = true
	print("[sim] " + msg)
	Engine.print_to_stdout = was


func _run() -> void:
	# Let GameManager and the other autoloads finish their _ready frames.
	for i in 5:
		await get_tree().process_frame
	var mode: String = args.get("mode", "run")
	if mode == "report":
		Report.new().build(args)
		_progress("report done")
		get_tree().quit()
		return
	Engine.print_to_stdout = args.get("verbose", "0") == "1"
	Engine.print_error_messages = args.get("verbose", "0") == "1"
	factory = Factory.new(self)
	var holder := Node.new()
	holder.name = "SimCombat"
	add_child(holder)
	var pc: Combatant = load("res://scenes/entities/combatant.tscn").instantiate()
	pc.name = "PlayerCombatant"
	pc.is_player_controlled = true
	var spawner := EncounterSpawner.new()
	spawner.name = "EncounterSpawner"
	cm = SimCM.new()
	cm.name = "CombatManager"
	cm.add_child(pc)
	cm.add_child(spawner)
	holder.add_child(cm)
	_build_pools()
	var tuning = CombatTuning.new()
	for k in args:
		if str(k).begins_with("knob."):
			var ok: bool = tuning.has_method("set_knob") and tuning.call("set_knob", str(k).substr(5), str(args[k]))
			_progress("knob %s = %s%s" % [str(k).substr(5), args[k], "" if ok else " (UNKNOWN)"])
	cm.opt_a = float(args.get("opt_a", "0"))
	cm.opt_b = float(args.get("opt_b", "1"))
	cm.opt_a_linear = args.get("opt_a_curve", "pos") == "lin"
	if mode == "run":
		await _run_cells()
	elif mode == "smoke":
		_smoke()
	_progress("done")
	Engine.print_to_stdout = true
	get_tree().quit()


# ---------------------------------------------------------------------------
# Encounters
# ---------------------------------------------------------------------------

func _list_tres(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		var fn := f.trim_suffix(".remap")
		if fn.ends_with(".tres"):
			out.append(dir_path + fn)
	out.sort()
	return out


func _build_pools() -> void:
	for tier in ENC_DIRS:
		pools[tier] = []
		for dir_path in ENC_DIRS[tier]:
			var fam := "navy" if dir_path.contains("navy") else "baseline"
			for p in _list_tres(dir_path):
				var enc: CombatEncounter = load(p)
				if enc == null:
					continue
				# Trash target is a group of 2-3: lone trash fights are left out.
				if tier == "trash" and enc.enemies.size() < 2:
					continue
				pools[tier].append({"enc": enc, "family": fam, "id": p.get_file().get_basename()})
	# No mini-boss encounters exist: each mini-boss enemy fights alone.
	pools["miniboss"] = []
	for dir_path in MINIBOSS_DIRS:
		var fam := "navy" if dir_path.contains("navy") else "baseline"
		for p in _list_tres(dir_path):
			var ed: EnemyData = load(p)
			if ed == null:
				continue
			var enc := CombatEncounter.new()
			enc.encounter_name = ed.enemy_name
			enc.encounter_id = "sim_miniboss_" + p.get_file().get_basename()
			var arr: Array[EnemyData] = [ed]
			enc.enemies = arr
			enc.player_starts_first = true
			pools["miniboss"].append({"enc": enc, "family": fam, "id": p.get_file().get_basename()})
	for t in pools:
		_progress("pool %s: %d encounters" % [t, pools[t].size()])


# ---------------------------------------------------------------------------
# Runs
# ---------------------------------------------------------------------------

const ROW_FIELDS := ["tag", "kind", "level", "content_level", "profile", "build", "weapon", "tier", "family", "encounter",
	"char_id", "won", "timeout", "rounds", "player_actions", "kills", "enemies", "player_damage", "dot_damage",
	"damage_taken", "healed", "max_hp", "end_hp", "start_hp", "hits", "hit_sum", "hit_max", "raw_hit", "raw_no_dice",
	"raw_no_pips", "crit_extra", "enemy_hp_total", "class_actions", "weapon_actions", "unplaced_dice",
	"dice_count", "armor", "barrier", "strength", "intellect", "agility", "luck", "power", "potion_heal", "floor"]


func _open_out() -> void:
	var path: String = args.get("out", "user://sim/out.csv")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	_log_file.store_line(",".join(ROW_FIELDS))


func _write_row(r: Dictionary) -> void:
	var cells: PackedStringArray = []
	for f in ROW_FIELDS:
		var v = r.get(f, "")
		if v is bool:
			v = 1 if v else 0
		elif v is float:
			v = "%.3f" % v
		cells.append(str(v).replace(",", ";"))
	_log_file.store_line(",".join(cells))


func _char_row(ch: Dictionary) -> Dictionary:
	var p: Player = ch["player"]
	return {
		"level": ch["level"], "profile": ch["profile"], "build": ch["build"], "weapon": ch["weapon"],
		"dice_count": p.dice_pool.get_pool_count(), "armor": p.get_armor(), "barrier": p.get_barrier(),
		"strength": p.get_total_stat("strength"), "intellect": p.get_total_stat("intellect"),
		"agility": p.get_total_stat("agility"), "luck": p.get_total_stat("luck"),
		"power": snappedf(p.get_power_level(), 0.1),
	}


func _fight_row(ch: Dictionary, f: Dictionary, tier: String, pick: Dictionary) -> Dictionary:
	var r := _char_row(ch)
	r.merge(f, true)
	var hits: Array = f.get("enemy_hits", [])
	var s := 0
	var mx := 0
	for h in hits:
		s += int(h)
		mx = maxi(mx, int(h))
	r["hits"] = hits.size()
	r["hit_sum"] = s
	r["hit_max"] = mx
	r["tier"] = tier
	r["family"] = pick["family"]
	r["encounter"] = pick["id"]
	return r


func _parse_list(key: String, default: Array) -> Array:
	if not args.has(key):
		return default
	var out: Array = []
	for s in str(args[key]).split(";"):
		if s.is_valid_int():
			out.append(int(s))
		else:
			out.append(s)
	return out


func _breathe() -> void:
	"""Let a frame pass so freed nodes and finished timers are released
	(the sim runs whole fights inside one frame)."""
	await get_tree().process_frame


func _run_cells() -> void:
	var seed_base: int = int(args.get("seed", "1"))
	var levels := _parse_list("levels", LEVELS)
	var profiles := _parse_list("profiles", Factory.PROFILE_ORDER)
	var builds := _parse_list("builds", ["str", "int"])
	var tiers := _parse_list("tiers", TIERS)
	var n_chars: int = int(args.get("chars", "20"))
	var n_fights: int = int(args.get("fights", "2"))
	var n_runs: int = int(args.get("runs", "0"))
	var outlevel: bool = args.get("outlevel", "0") == "1"
	var tag: String = args.get("tag", "sim")
	## A later batch can add characters to an earlier one (same seed, new indices).
	var char_offset: int = int(args.get("char_offset", "0"))
	_open_out()
	var t0 := Time.get_ticks_msec()
	var fights_done := 0
	for level in levels:
		for profile in profiles:
			for build in builds:
				var weapons: Array = Factory.WEAPONS[build]
				for cj in n_chars:
					var ci: int = cj + char_offset
					# Seeded per character, so runs with the same seed build the same gear.
					seed(hash([seed_base, level, profile, build, ci]))
					# Weapons cycle so every weapon gets the same share of characters.
					var ch: Dictionary = factory.build_character(level, profile, build, ci % weapons.size())
					var cid := "%s-%d-%s-%s-%d" % [tag, level, profile, build, ci]
					for tier in tiers:
						for fi in n_fights:
							var pick: Dictionary = pools[tier][randi() % pools[tier].size()]
							factory.apply_preps(ch, tier)
							GameManager.player = ch["player"]
							GameManager.pending_depth = {}
							var f: Dictionary = cm.run_fight(ch["player"], pick["enc"])
							var row := _fight_row(ch, f, tier, pick)
							row["tag"] = tag
							row["kind"] = "fight"
							row["char_id"] = cid
							row["content_level"] = level
							_write_row(row)
							fights_done += 1
					for ri in n_runs:
						_dungeon_run(ch, cid, tag)
					factory.free_player(ch["player"])
					await _breathe()
				_progress("L%d %s %s: %d fights, %.0fs" % [level, profile, build, fights_done, (Time.get_ticks_msec() - t0) / 1000.0])
	if outlevel:
		await _run_outlevel(seed_base, n_chars, n_fights, tag, char_offset)
	_log_file.close()


func _run_outlevel(seed_base: int, n_chars: int, n_fights: int, tag: String, char_offset: int = 0) -> void:
	"""On-curve player at level L+10 against the enemies an on-curve level-L
	player meets (enemies are spawned while a level-L reference player is
	GameManager.player, so their level, affixes and power matching are the
	level-L ones)."""
	var tiers := _parse_list("tiers", TIERS)
	var content_levels := _parse_list("outlevel_levels", [18, 35, 50, 75])
	for cl in content_levels:
		for build in _parse_list("builds", ["str", "int"]):
			for cj in n_chars:
				var ci: int = cj + char_offset
				seed(hash([seed_base, "outlevel", cl, build, ci]))
				var weapon_idx: int = ci % Factory.WEAPONS[build].size()
				var ch: Dictionary = factory.build_character(cl + 10, "on_curve", build, weapon_idx)
				var ref: Dictionary = factory.build_character(cl, "on_curve", build, weapon_idx)
				var cid := "%s-out-%d-%s-%d" % [tag, cl, build, ci]
				for tier in tiers:
					for fi in n_fights:
						var pick: Dictionary = pools[tier][randi() % pools[tier].size()]
						factory.apply_preps(ch, tier)
						cm.spawn_as = ref["player"]
						GameManager.player = ch["player"]
						GameManager.pending_depth = {}
						var f: Dictionary = cm.run_fight(ch["player"], pick["enc"])
						cm.spawn_as = null
						var row := _fight_row(ch, f, tier, pick)
						row["tag"] = tag
						row["kind"] = "outlevel"
						row["char_id"] = cid
						row["content_level"] = cl
						_write_row(row)
				factory.free_player(ref["player"])
				factory.free_player(ch["player"])
				await _breathe()
			_progress("outlevel content L%d %s done" % [cl, build])


func _dungeon_run(ch: Dictionary, cid: String, tag: String) -> void:
	"""RUN_PLAN in order, one fight per floor with the real depth scaling
	(CombatTuning.depth_multipliers, depth_scaling 1.0), HP carried over.
	Between fights the profile drinks a restorative (real ConsumableItem.use,
	out of combat) when below 60% HP. No rests inside the run."""
	var p: Player = ch["player"]
	var kit: Array = []
	for n in RUN_KITS[ch["profile"]]:
		var c: ConsumableItem = load(Factory.CONS + "restoratives/" + n + ".tres")
		if c:
			kit.append(c.duplicate())
	var hp: int = p.max_hp
	for floor_i in RUN_PLAN.size():
		var tier: String = RUN_PLAN[floor_i]
		var potion_heal := 0
		if floor_i > 0 and hp < int(p.max_hp * 0.6) and not kit.is_empty():
			p.current_hp = hp
			var before := p.current_hp
			var c: ConsumableItem = kit.pop_front()
			c.use(p, {})
			potion_heal = p.current_hp - before
			hp = p.current_hp
		var pick: Dictionary = pools[tier][randi() % pools[tier].size()]
		factory.apply_preps(ch, tier)
		GameManager.player = p
		GameManager.pending_depth = CombatTuning.depth_multipliers(floor_i, 1.0)
		var f: Dictionary = cm.run_fight(p, pick["enc"], hp)
		GameManager.pending_depth = {}
		var row := _fight_row(ch, f, tier, pick)
		row["tag"] = tag
		row["kind"] = "run"
		row["char_id"] = cid
		row["content_level"] = ch["level"]
		row["floor"] = floor_i
		row["start_hp"] = hp
		row["potion_heal"] = potion_heal
		_write_row(row)
		hp = int(f.get("end_hp", 0))
		if not f.get("won", false):
			break


func _smoke() -> void:
	seed(int(args.get("seed", "1")))
	var level: int = int(args.get("level", "18"))
	for build in ["str", "int"]:
		for profile in Factory.PROFILE_ORDER:
			var ch: Dictionary = factory.build_character(level, profile, build)
			var p: Player = ch["player"]
			var acts: Array = []
			cm.action_manager.initialize(p)
			for a in cm.action_manager.get_actions():
				acts.append(a.get("name", "?"))
			_progress("%s %s L%d weapon=%s hp=%d armor=%d barrier=%d str=%d int=%d dice=%d power=%.0f actions=%s" % [
				build, profile, level, ch["weapon"], p.max_hp, p.get_armor(), p.get_barrier(),
				p.get_total_stat("strength"), p.get_total_stat("intellect"), p.dice_pool.get_pool_count(),
				p.get_power_level(), str(acts)])
			for tier in TIERS:
				var pick: Dictionary = pools[tier][randi() % pools[tier].size()]
				GameManager.player = p
				var t := Time.get_ticks_usec()
				var f: Dictionary = cm.run_fight(p, pick["enc"])
				_progress("   %s %s: won=%s rounds=%d acts=%d kills=%d/%d dmg=%d taken=%d hits=%s end_hp=%d/%d raw=%.0f nodice=%.0f  (%.1f ms)" % [
					tier, pick["id"], f["won"], f["rounds"], f["player_actions"], f["kills"], f["enemies"],
					f["player_damage"], f["damage_taken"], str(f["enemy_hits"].slice(0, 6)), f["end_hp"], f["max_hp"],
					f["raw_hit"], f["raw_no_dice"], (Time.get_ticks_usec() - t) / 1000.0])
			factory.free_player(p)
