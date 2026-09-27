# res://tools/balance_sim/sim_report.gd
# Reads the fight rows the simulator wrote (one CSV per shard) and writes the
# markdown report and a summary CSV, with PASS/FAIL against Balance Targets.
extends RefCounted

## Balance Targets (approved 2026-09-26), on-curve player vs on-level content.
## [low, high] on the median fight; win rate on the mean.
const TARGETS := {
	"trash": {"turns": [2.0, 3.0], "apk": [1.0, 2.0], "hp_lost": [0.05, 0.12], "hit_pct": [0.03, 0.06], "win": [0.95, 1.0]},
	"elite": {"turns": [4.0, 5.0], "apk": [3.0, 4.0], "hp_lost": [0.15, 0.30], "hit_pct": [0.05, 0.10], "win": [0.85, 0.95]},
	"miniboss": {"turns": [5.0, 7.0], "apk": [6.0, 10.0], "hp_lost": [0.30, 0.50], "hit_pct": [0.08, 0.15], "win": [0.75, 0.85]},
	"boss": {"turns": [8.0, 12.0], "apk": [15.0, 25.0], "hp_lost": [0.50, 0.80], "hit_pct": [0.10, 0.20], "win": [0.55, 0.75]},
}
const TIERS := ["trash", "elite", "miniboss", "boss"]
const PROFILES := ["undergeared", "on_curve", "well_geared", "min_maxed"]
const METRICS := ["turns", "apk", "hp_lost", "hit_pct", "hit_max_pct", "win", "dice_share", "face_share", "crit_share", "sustain", "dmg_per_action", "timeout"]

var rows: Array = []
var md: PackedStringArray = []
var csv: PackedStringArray = []
var _level_cache: Array = []


func build(args: Dictionary) -> void:
	var in_dir: String = args.get("in", "user://sim")
	_load(in_dir, args.get("tag", ""))
	md.append("---")
	md.append("tags:\n  - plot/audit\ndate: \"%s\"" % Time.get_date_string_from_system())
	md.append("source: \"res://tools/balance_sim (engine/balance-sim)\"")
	md.append("---\n")
	md.append("# %s\n" % args.get("title", "Balance Sim"))
	var intro: String = args.get("intro", "")
	if intro != "" and FileAccess.file_exists(intro):
		md.append(FileAccess.get_file_as_string(intro))
	csv.append("group,level,profile,build,tier,weapon,family,metric,n,mean,p10,p50,p90,target_low,target_high,verdict")
	_headline()
	_tier_tables()
	_dice_and_growth()
	_parity()
	_weapons()
	_families()
	_outlevel()
	_runs()
	_convergence()
	_write(args.get("md", "user://sim/report.md"), "\n".join(md))
	_write(args.get("csv", "user://sim/summary.csv"), "\n".join(csv))


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ---------------------------------------------------------------------------
# Loading and metrics
# ---------------------------------------------------------------------------

func _load(dir_path: String, tag: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		push_error("sim_report: no dir " + dir_path)
		return
	for fn in d.get_files():
		if not fn.ends_with(".csv"):
			continue
		var f := FileAccess.open(dir_path.path_join(fn), FileAccess.READ)
		var header := f.get_csv_line()
		while not f.eof_reached():
			var line := f.get_csv_line()
			if line.size() < header.size():
				continue
			var r := {}
			for i in header.size():
				r[header[i]] = line[i]
			if tag != "" and r.get("tag", "") != tag:
				continue
			_derive(r)
			rows.append(r)


func _num(r: Dictionary, k: String) -> float:
	var v: String = str(r.get(k, ""))
	return float(v) if v != "" else 0.0


func _derive(r: Dictionary) -> void:
	for k in ["level", "content_level", "floor"]:
		r[k] = int(_num(r, k))
	var max_hp := maxf(1.0, _num(r, "max_hp"))
	var start := _num(r, "start_hp")
	if start <= 0.0:
		start = max_hp
	var m := {}
	m["turns"] = _num(r, "rounds")
	var kills := _num(r, "kills")
	m["apk"] = _num(r, "player_actions") / kills if kills > 0.0 else null
	m["hp_lost"] = clampf((start - _num(r, "end_hp")) / max_hp, 0.0, 1.0)
	var hits := _num(r, "hits")
	m["hit_pct"] = (_num(r, "hit_sum") / hits) / max_hp if hits > 0.0 else null
	m["hit_max_pct"] = _num(r, "hit_max") / max_hp if hits > 0.0 else null
	m["win"] = _num(r, "won")
	var raw := _num(r, "raw_hit")
	m["dice_share"] = (raw - _num(r, "raw_no_dice")) / raw if raw > 0.0 else null
	m["face_share"] = (_num(r, "raw_no_pips") - _num(r, "raw_no_dice")) / raw if raw > 0.0 else null
	var dmg := _num(r, "player_damage")
	m["crit_share"] = _num(r, "crit_extra") / dmg if dmg > 0.0 else null
	var taken := _num(r, "damage_taken")
	m["sustain"] = _num(r, "healed") / taken if taken > 0.0 else null
	var acts := _num(r, "player_actions")
	m["dmg_per_action"] = dmg / acts if acts > 0.0 else null
	m["timeout"] = _num(r, "timeout")
	r["m"] = m


func _select(filter: Callable) -> Array:
	return rows.filter(filter)


func _stats(sel: Array, metric: String) -> Dictionary:
	var vals: Array = []
	for r in sel:
		var v = r["m"].get(metric)
		if v != null:
			vals.append(float(v))
	if vals.is_empty():
		return {"n": 0}
	vals.sort()
	var s := 0.0
	for v in vals:
		s += v
	return {"n": vals.size(), "mean": s / vals.size(), "p10": _pct(vals, 0.1), "p50": _pct(vals, 0.5), "p90": _pct(vals, 0.9)}


static func _pct(sorted: Array, q: float) -> float:
	if sorted.size() == 1:
		return sorted[0]
	var pos := q * (sorted.size() - 1)
	var lo := floori(pos)
	var hi := mini(lo + 1, sorted.size() - 1)
	return lerpf(sorted[lo], sorted[hi], pos - lo)


func _verdict(tier: String, metric: String, st: Dictionary) -> String:
	if st.get("n", 0) == 0 or not TARGETS.has(tier) or not TARGETS[tier].has(metric):
		return ""
	var t: Array = TARGETS[tier][metric]
	var v: float = st["mean"] if metric == "win" else st["p50"]
	return "PASS" if v >= t[0] - 1e-6 and v <= t[1] + 1e-6 else "FAIL"


func _fmt(metric: String, v: float) -> String:
	if metric in ["hp_lost", "hit_pct", "hit_max_pct", "win", "dice_share", "face_share", "crit_share", "sustain", "timeout"]:
		return "%.0f%%" % (v * 100.0)
	if metric == "dmg_per_action":
		return "%.0f" % v
	return "%.1f" % v


func _cell(metric: String, st: Dictionary) -> String:
	if st.get("n", 0) == 0:
		return "n/a"
	if metric == "win" or metric == "timeout":
		return _fmt(metric, st["mean"])
	return "%s (%s–%s)" % [_fmt(metric, st["p50"]), _fmt(metric, st["p10"]), _fmt(metric, st["p90"])]


func _csv_row(group: String, level, profile: String, build: String, tier: String, weapon: String, family: String, metric: String, st: Dictionary) -> void:
	if st.get("n", 0) == 0:
		return
	var t: Array = TARGETS.get(tier, {}).get(metric, ["", ""])
	var verdict := _verdict(tier, metric, st) if profile == "on_curve" else ""
	csv.append("%s,%s,%s,%s,%s,%s,%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%s,%s,%s" % [group, str(level), profile, build, tier, weapon, family, metric,
		st["n"], st["mean"], st["p10"], st["p50"], st["p90"], str(t[0]), str(t[1]), verdict])


func _levels() -> Array:
	if not _level_cache.is_empty():
		return _level_cache
	for r in rows:
		if r["kind"] == "fight" and not (r["level"] in _level_cache):
			_level_cache.append(r["level"])
	_level_cache.sort()
	return _level_cache


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _headline() -> void:
	var fights := rows.filter(func(r): return r["kind"] == "fight")
	var chars := {}
	for r in fights:
		chars[r["char_id"]] = true
	md.append("## Sample\n")
	md.append("- Fight rows: %d on-level, %d outlevelling, %d dungeon-run fights." % [fights.size(),
		rows.filter(func(r): return r["kind"] == "outlevel").size(), rows.filter(func(r): return r["kind"] == "run").size()])
	md.append("- Distinct generated characters (on-level): %d." % chars.size())
	md.append("- Tables pool both builds unless they say otherwise. Values are the median fight with the 10th–90th percentile in brackets; win and timeout rates are means.\n")
	md.append("## Headline: on-curve player vs Balance Targets\n")
	md.append("PASS/FAIL on the median fight (win rate on the mean), both builds pooled.\n")
	md.append("| Level | Tier | Turns | Actions/kill | HP lost | Enemy hit | Win |")
	md.append("|---|---|---|---|---|---|---|")
	var pass_n := 0
	var total_n := 0
	for level in _levels():
		for tier in TIERS:
			var sel := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == "on_curve" and r["tier"] == tier)
			if sel.is_empty():
				continue
			var cells: PackedStringArray = []
			for metric in ["turns", "apk", "hp_lost", "hit_pct", "win"]:
				var st := _stats(sel, metric)
				var v := _verdict(tier, metric, st)
				if v != "":
					total_n += 1
					if v == "PASS":
						pass_n += 1
				var shown: String = _fmt("win", st.get("mean", 0.0)) if metric == "win" else _cell(metric, st)
				cells.append("%s %s" % [shown, v])
			md.append("| %d | %s | %s |" % [level, tier, " | ".join(cells)])
	md.append("\n**%d of %d on-curve checks pass.**\n" % [pass_n, total_n])
	csv.append("headline,all,on_curve,both,,,,pass_count,%d,%d,,,,,," % [total_n, pass_n])


func _tier_tables() -> void:
	md.append("## All profiles by level and tier\n")
	md.append("Both builds pooled; n = fights.\n")
	for tier in TIERS:
		md.append("### %s\n" % tier.capitalize())
		md.append("| Level | Profile | n | Turns | Actions/kill | HP lost | Enemy hit | Biggest hit | Win | Timeouts | Dmg/action |")
		md.append("|---|---|---|---|---|---|---|---|---|---|---|")
		for level in _levels():
			for profile in PROFILES:
				var sel := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == profile and r["tier"] == tier)
				if sel.is_empty():
					continue
				var cells: PackedStringArray = []
				for metric in ["turns", "apk", "hp_lost", "hit_pct", "hit_max_pct", "win", "timeout", "dmg_per_action"]:
					cells.append(_cell(metric, _stats(sel, metric)))
				md.append("| %d | %s | %d | %s |" % [level, profile, sel.size(), " | ".join(cells)])
				for build in ["str", "int", "both"]:
					var bsel: Array = sel if build == "both" else sel.filter(func(r): return r["build"] == build)
					for metric in METRICS:
						_csv_row("cell", level, profile, build, tier, "", "", metric, _stats(bsel, metric))
		md.append("")


func _dice_and_growth() -> void:
	md.append("## Dice share, crits and sustain\n")
	md.append("Dice share is the part of a hit's raw (pre-defence) damage that comes from the dice. It is measured with the real damage calculation by zeroing the placed dice. It includes the stat pips that ride on each die (Strength or Intellect); \"faces only\" leaves the pips out. Target: at least 50% at every level. Crit share = extra damage from crits ÷ player damage. Sustain = HP healed in the fight ÷ HP lost.\n")
	md.append("| Level | Profile | Dice share | Faces only | Crit share | Sustain in fight | Dice ≥ 50% |")
	md.append("|---|---|---|---|---|---|---|")
	for level in _levels():
		for profile in PROFILES:
			var sel := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == profile)
			if sel.is_empty():
				continue
			var ds := _stats(sel, "dice_share")
			var verdict := ""
			if ds.get("n", 0) > 0:
				verdict = "PASS" if ds["p50"] >= 0.5 else "FAIL"
				csv.append("dice,%d,%s,both,,,,dice_share,%d,%.4f,%.4f,%.4f,%.4f,0.5,1,%s" % [level, profile, ds["n"], ds["mean"], ds["p10"], ds["p50"], ds["p90"], verdict])
			var sus := _stats(sel, "sustain")
			md.append("| %d | %s | %s | %s | %s | %s | %s |" % [level, profile, _cell("dice_share", ds), _cell("face_share", _stats(sel, "face_share")),
				_cell("crit_share", _stats(sel, "crit_share")), _fmt("sustain", sus.get("mean", 0.0)), verdict])
	md.append("")
	md.append("## Power growth (on-curve)\n")
	md.append("Offence = mean raw damage per player action (pre-defence, real calculation). Defence = max HP; armour and barrier are listed beside it. Growth is per 10 levels between the sampled levels. Target: about ×2 every 10–12 levels (×1.78–×2.0 per 10; verdict band ×1.6–×2.2 on the combined figure).\n")
	md.append("| Level | Raw dmg/action | Max HP | Armour | Barrier | STR | INT | Dice in pool | Offence ×/10 lv | HP ×/10 lv | Combined ×/10 lv | Verdict |")
	md.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	var prev := {}
	for level in _levels():
		var sel := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == "on_curve")
		if sel.is_empty():
			continue
		var sums := {"raw_hit": 0.0, "player_actions": 0.0, "max_hp": 0.0, "armor": 0.0, "barrier": 0.0, "strength": 0.0, "intellect": 0.0, "dice_count": 0.0}
		for r in sel:
			for k in sums:
				sums[k] += _num(r, k)
		var n := float(sel.size())
		var off: float = sums["raw_hit"] / maxf(1.0, sums["player_actions"])
		var cur := {"level": level, "off": off, "hp": sums["max_hp"] / n}
		var g := ["", "", "", ""]
		if not prev.is_empty():
			var span := float(level - int(prev["level"])) / 10.0
			var fo := pow(off / maxf(0.001, prev["off"]), 1.0 / span)
			var fh := pow(float(cur["hp"]) / maxf(0.001, prev["hp"]), 1.0 / span)
			var fc := sqrt(fo * fh)
			g = ["×%.2f" % fo, "×%.2f" % fh, "×%.2f" % fc, "PASS" if fc >= 1.6 and fc <= 2.2 else "FAIL"]
			csv.append("growth,%d,on_curve,both,,,,combined_per10,%d,%.4f,,,,1.78,2.0,%s" % [level, sel.size(), fc, g[3]])
		md.append("| %d | %.1f | %.0f | %.0f | %.0f | %.0f | %.0f | %.1f | %s | %s | %s | %s |" % [level, off, sums["max_hp"] / n,
			sums["armor"] / n, sums["barrier"] / n, sums["strength"] / n, sums["intellect"] / n, sums["dice_count"] / n, g[0], g[1], g[2], g[3]])
		prev = cur
	md.append("")


func _parity() -> void:
	md.append("## Build parity (Strength vs Intellect, same profile)\n")
	md.append("Damage per player action after defences, on-level, all tiers pooled. Target: within about 10%.\n")
	md.append("| Level | Profile | STR dmg/action | INT dmg/action | STR ÷ INT | STR win | INT win | Verdict |")
	md.append("|---|---|---|---|---|---|---|---|")
	for level in _levels():
		for profile in PROFILES:
			var s := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == profile and r["build"] == "str")
			var i := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == profile and r["build"] == "int")
			if s.is_empty() or i.is_empty():
				continue
			var ds := _stats(s, "dmg_per_action")
			var di := _stats(i, "dmg_per_action")
			if ds.get("n", 0) == 0 or di.get("n", 0) == 0:
				continue
			var ratio: float = ds["mean"] / maxf(0.001, di["mean"])
			var verdict := "PASS" if absf(ratio - 1.0) <= 0.1 else "FAIL"
			md.append("| %d | %s | %.1f | %.1f | %.2f | %s | %s | %s |" % [level, profile, ds["mean"], di["mean"], ratio,
				_fmt("win", _stats(s, "win")["mean"]), _fmt("win", _stats(i, "win")["mean"]), verdict])
			csv.append("parity,%d,%s,,,,,str_over_int,%d,%.4f,,,,0.9,1.1,%s" % [level, profile, s.size() + i.size(), ratio, verdict])
	md.append("")


func _weapons() -> void:
	md.append("## By weapon (on-curve, all levels and tiers)\n")
	md.append("| Weapon | Build | n | Win | Dmg/action | Actions/kill | Turns | HP lost | Dice share | Class-action share |")
	md.append("|---|---|---|---|---|---|---|---|---|---|")
	var weapons := {}
	for r in rows:
		if r["kind"] == "fight":
			weapons[r["weapon"]] = r["build"]
	var names := weapons.keys()
	names.sort()
	for w in names:
		var sel := _select(func(r): return r["kind"] == "fight" and r["profile"] == "on_curve" and r["weapon"] == w)
		if sel.is_empty():
			continue
		var ca := 0.0
		var pa := 0.0
		for r in sel:
			ca += _num(r, "class_actions")
			pa += _num(r, "player_actions")
		md.append("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %.0f%% |" % [w, weapons[w], sel.size(), _fmt("win", _stats(sel, "win")["mean"]),
			_cell("dmg_per_action", _stats(sel, "dmg_per_action")), _cell("apk", _stats(sel, "apk")), _cell("turns", _stats(sel, "turns")),
			_cell("hp_lost", _stats(sel, "hp_lost")), _cell("dice_share", _stats(sel, "dice_share")), 100.0 * ca / maxf(1.0, pa)])
		for tier in TIERS:
			var tsel := sel.filter(func(r): return r["tier"] == tier)
			for metric in ["win", "turns", "apk", "hp_lost", "dmg_per_action"]:
				_csv_row("weapon", "all", "on_curve", weapons[w], tier, w, "", metric, _stats(tsel, metric))
	md.append("")
	md.append("### Win rate by weapon and level (on-curve, all tiers)\n")
	var levels := _levels()
	var hdr := "| Weapon |"
	var sep := "|---|"
	for l in levels:
		hdr += " L%d |" % l
		sep += "---|"
	md.append(hdr)
	md.append(sep)
	for w in names:
		var line := "| %s |" % w
		for l in levels:
			var sel := _select(func(r): return r["kind"] == "fight" and r["profile"] == "on_curve" and r["weapon"] == w and r["level"] == l)
			line += " %s |" % (_fmt("win", _stats(sel, "win").get("mean", 0.0)) if not sel.is_empty() else "")
		md.append(line)
	md.append("")


func _families() -> void:
	md.append("## By enemy family (on-curve, all levels)\n")
	md.append("| Family | Tier | n | Win | Turns | Actions/kill | HP lost | Enemy hit |")
	md.append("|---|---|---|---|---|---|---|---|")
	for fam in ["baseline", "navy"]:
		for tier in TIERS:
			var sel := _select(func(r): return r["kind"] == "fight" and r["profile"] == "on_curve" and r["family"] == fam and r["tier"] == tier)
			if sel.is_empty():
				continue
			md.append("| %s | %s | %d | %s | %s | %s | %s | %s |" % [fam, tier, sel.size(), _fmt("win", _stats(sel, "win")["mean"]),
				_cell("turns", _stats(sel, "turns")), _cell("apk", _stats(sel, "apk")), _cell("hp_lost", _stats(sel, "hp_lost")), _cell("hit_pct", _stats(sel, "hit_pct"))])
			for metric in ["win", "turns", "apk", "hp_lost", "hit_pct"]:
				_csv_row("family", "all", "on_curve", "both", tier, "", fam, metric, _stats(sel, metric))
	md.append("")


func _outlevel() -> void:
	var out := rows.filter(func(r): return r["kind"] == "outlevel")
	if out.is_empty():
		return
	md.append("## Outlevelling by 10 (on-curve)\n")
	md.append("An on-curve player at level L+10 against the enemies a level-L on-curve player meets, compared with that level-L player. Target: about 2× faster kills and about 0.5× damage taken. Verdict bands: kill speed-up ×1.6–×2.5 and damage taken (as % of max HP) ×0.35–×0.65.\n")
	md.append("| Content level | Tier | Actions/kill at L | at L+10 | Speed-up | HP lost at L | at L+10 | Ratio (% HP) | Ratio (HP) | Verdict |")
	md.append("|---|---|---|---|---|---|---|---|---|---|")
	var cls := {}
	for r in out:
		cls[r["content_level"]] = true
	var keys := cls.keys()
	keys.sort()
	for cl in keys:
		for tier in TIERS:
			var o := out.filter(func(r): return r["content_level"] == cl and r["tier"] == tier)
			var b := _select(func(r): return r["kind"] == "fight" and r["profile"] == "on_curve" and r["level"] == cl and r["tier"] == tier)
			if o.is_empty() or b.is_empty():
				continue
			var ab := _stats(b, "apk")
			var ao := _stats(o, "apk")
			var hb := _stats(b, "hp_lost")
			var ho := _stats(o, "hp_lost")
			if ab.get("n", 0) == 0 or ao.get("n", 0) == 0:
				continue
			var speed: float = ab["mean"] / maxf(0.001, ao["mean"])
			var ratio: float = ho["mean"] / maxf(0.0001, hb["mean"])
			var hp_b := 0.0
			var hp_o := 0.0
			for r in b:
				hp_b += _num(r, "damage_taken")
			for r in o:
				hp_o += _num(r, "damage_taken")
			var ratio_hp: float = (hp_o / o.size()) / maxf(0.0001, hp_b / b.size())
			var verdict := "PASS" if speed >= 1.6 and speed <= 2.5 and ratio >= 0.35 and ratio <= 0.65 else "FAIL"
			md.append("| %d | %s | %.1f | %.1f | ×%.2f | %s | %s | ×%.2f | ×%.2f | %s |" % [cl, tier, ab["mean"], ao["mean"], speed,
				_fmt("hp_lost", hb["mean"]), _fmt("hp_lost", ho["mean"]), ratio, ratio_hp, verdict])
			csv.append("outlevel,%d,on_curve,both,%s,,,speedup,%d,%.4f,,,,1.6,2.5,%s" % [cl, tier, o.size(), speed, verdict])
			csv.append("outlevel,%d,on_curve,both,%s,,,damage_ratio,%d,%.4f,,,,0.35,0.65,%s" % [cl, tier, o.size(), ratio, verdict])
	md.append("")


func _runs() -> void:
	var run_rows := rows.filter(func(r): return r["kind"] == "run")
	if run_rows.is_empty():
		return
	md.append("## Dungeon runs (sustain)\n")
	md.append("Seven fights in a row (trash, trash, elite, trash, mini-boss, elite, boss) on floors 0–6 with the real depth scaling, HP carried over and no rests. Between fights the profile drinks a restorative when under 60% HP. Sustain = (healing in fights + potion healing) ÷ damage taken over the run. Target: 30–50%.\n")
	md.append("| Level | Profile | Runs | Cleared | Reached boss | Sustain | Potion part of sustain | Verdict |")
	md.append("|---|---|---|---|---|---|---|---|")
	for level in _levels():
		for profile in PROFILES:
			var sel := run_rows.filter(func(r): return r["level"] == level and r["profile"] == profile)
			if sel.is_empty():
				continue
			var runs := {}
			var healed := 0.0
			var potion := 0.0
			var taken := 0.0
			for r in sel:
				var key: String = r["char_id"]
				if not runs.has(key):
					runs[key] = {"max_floor": -1, "boss_won": false}
				runs[key]["max_floor"] = maxi(runs[key]["max_floor"], r["floor"])
				if r["tier"] == "boss" and _num(r, "won") > 0.0:
					runs[key]["boss_won"] = true
				healed += _num(r, "healed")
				potion += _num(r, "potion_heal")
				taken += _num(r, "damage_taken")
			var cleared := 0
			var reached := 0
			for k in runs:
				if runs[k]["boss_won"]:
					cleared += 1
				if runs[k]["max_floor"] >= 6:
					reached += 1
			var sus := (healed + potion) / maxf(1.0, taken)
			var verdict := "PASS" if sus >= 0.3 and sus <= 0.5 else "FAIL"
			md.append("| %d | %s | %d | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %s |" % [level, profile, runs.size(), 100.0 * cleared / runs.size(),
				100.0 * reached / runs.size(), 100.0 * sus, 100.0 * potion / maxf(1.0, healed + potion), verdict])
			csv.append("run,%d,%s,both,,,,sustain,%d,%.4f,,,,0.3,0.5,%s" % [level, profile, runs.size(), sus, verdict])
			csv.append("run,%d,%s,both,,,,cleared,%d,%.4f,,,,,," % [level, profile, runs.size(), float(cleared) / runs.size()])
	md.append("")


func _char_index(r: Dictionary) -> int:
	var cid: String = str(r["char_id"])
	return int(cid.get_slice("-", cid.get_slice_count("-") - 1))


func _half_split_ok(sel: Array) -> Array:
	"""[stable, worst_ratio, label] for one cell split into two halves."""
	var a := sel.filter(func(r): return (_char_index(r) / 8) % 2 == 0)
	var b := sel.filter(func(r): return (_char_index(r) / 8) % 2 == 1)
	var ok := true
	var worst := 0.0
	var label := ""
	var checks := [["turns", "p50", 0.10, 0.5], ["apk", "p50", 0.10, 1.0], ["hp_lost", "mean", 0.10, 0.03], ["win", "mean", 1.0, 0.05]]
	for c in checks:
		var sa := _stats(a, c[0])
		var sb := _stats(b, c[0])
		if sa.get("n", 0) == 0 or sb.get("n", 0) == 0:
			continue
		var diff: float = absf(float(sa[c[1]]) - float(sb[c[1]]))
		var rel: float = diff / maxf(0.0001, (float(sa[c[1]]) + float(sb[c[1]])) / 2.0)
		if rel > c[2] and diff > c[3]:
			ok = false
			if diff / c[3] > worst:
				worst = diff / c[3]
				label = "%s %.2f vs %.2f" % [c[0], float(sa[c[1]]), float(sb[c[1]])]
	return [ok, worst, label]


func _convergence() -> void:
	md.append("## Convergence check
")
	md.append("Each cell is split into two independent halves by character (alternate blocks of 8 characters, so each half holds every weapon equally). The halves are compared on median turns and median actions per kill (within 10%, or 0.5 turn and 1 action, since both are counted in whole or half steps), mean % HP lost (within 10% or 3 points) and win rate (within 5 points). HP lost is compared on the mean because it is two-humped (a won fight loses a little, a lost fight loses 100%), so its median jumps between the humps. A cell is stable when every check agrees.
")
	for pooled in [true, false]:
		var stable := 0
		var total := 0
		var worst := 0.0
		var worst_cell := ""
		for level in _levels():
			for profile in PROFILES:
				for build in (["both"] if pooled else ["str", "int"]):
					for tier in TIERS:
						var sel := _select(func(r): return r["kind"] == "fight" and r["level"] == level and r["profile"] == profile and (build == "both" or r["build"] == build) and r["tier"] == tier)
						if sel.size() < 4:
							continue
						var res := _half_split_ok(sel)
						total += 1
						if res[0]:
							stable += 1
						elif res[1] > worst:
							worst = res[1]
							worst_cell = "L%d %s %s %s: %s" % [level, profile, build, tier, res[2]]
		var what := "level × profile × tier cells (builds pooled, as in the tables)" if pooled else "level × profile × build × tier cells"
		md.append("- **%d of %d %s stable.** Largest unstable split: %s." % [stable, total, what, worst_cell if worst_cell != "" else "none"])
		csv.append("convergence,all,,%s,,,,stable_cells,%d,%d,,,,,," % ["both" if pooled else "per_build", total, stable])
	md.append("")
