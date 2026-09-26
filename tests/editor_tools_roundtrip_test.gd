extends SceneTree
## Headless regression test for the editor-tool fixes (Engine Gaps 15-18, 21, 23).
##
## Run (never runs the main scene; the GameState autoload is prevented from
## writing user://save.tres on exit):
##   Godot_v4.5.1 --headless --path <project> -s res://tests/editor_tools_roundtrip_test.gd
##
## Exit code 0 = all checks passed, 1 = failures (listed in the output).

# Loaded at run time (not preloaded): the dialogue data scripts reference the
# GameState autoload, which is not registered yet when this script compiles.
var SerializerScript
var DeserializerScript
var GraphScript
var LineScript
var ChoiceScript
var EncounterScript
var ConditionScript
var SingleCheckScript

## SingleCheck.CheckType values used below
const CT_QUEST_STATE := 6
const CT_LOCATION_VISITED := 7
const CT_APPROVAL := 8
const CT_CUSTOM := 9

const TMP_DIR := "user://editor_tools_test/"

var _failures: Array[String] = []
var _checks: int = 0

## Minimal stand-in for the dock's speakers panel
class SpeakersStub extends Control:
	var _speakers: Array[DialogueSpeaker] = []
	func clear_speakers() -> void:
		_speakers.clear()
	func add_speaker(s: DialogueSpeaker) -> void:
		if not s in _speakers:
			_speakers.append(s)
	func get_speakers() -> Array[DialogueSpeaker]:
		return _speakers

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Let the autoloads finish their own _ready work first
	await process_frame
	await process_frame
	SerializerScript = load("res://addons/dialogue_editor/io/dialogue_serializer.gd")
	DeserializerScript = load("res://addons/dialogue_editor/io/dialogue_deserializer.gd")
	GraphScript = load("res://addons/dialogue_editor/graph/dialogue_graph_edit.gd")
	LineScript = load("res://resources/data/dialogue_line.gd")
	ChoiceScript = load("res://resources/data/dialogue_choice.gd")
	EncounterScript = load("res://resources/data/dialogue_encounter.gd")
	ConditionScript = load("res://resources/data/game_condition.gd")
	SingleCheckScript = load("res://resources/data/single_check.gd")
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

	_test_real_dialogues()
	_test_enriched_dialogue()
	_test_condition_and_set_flag_nodes()
	_test_refusals()
	_test_uid_preserved()
	_test_rewards_widget()
	_test_condition_widget()
	_test_action_line_choice_indexing()
	_test_dropdown_roots()
	await _test_grant_item_and_heal_actions()

	_cleanup_tmp()
	print("")
	if _failures.is_empty():
		print("ALL PASSED (%d checks)" % _checks)
	else:
		print("FAILED: %d of %d checks" % [_failures.size(), _checks])
		for f in _failures:
			print("  - " + f)
	_guard_save()
	quit(0 if _failures.is_empty() else 1)

# ============================================================================
# HELPERS
# ============================================================================

func _guard_save() -> void:
	# GameState saves in _exit_tree unless its save data is null.
	var gs = root.get_node_or_null("GameState")
	if gs:
		gs.set("_save_data", null)

func _check(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(msg)

func _stored_props(o: Object) -> Array[String]:
	var out: Array[String] = []
	for p in o.get_property_list():
		if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (p.usage & PROPERTY_USAGE_STORAGE):
			out.append(p.name)
	return out

## Deep structural comparison; appends human-readable differences to diffs.
func _diff(a, b, path: String, diffs: Array, seen: Dictionary, top: bool = false) -> void:
	if a is Resource or b is Resource:
		if not (a is Resource and b is Resource):
			diffs.append("%s: %s vs %s" % [path, a, b])
			return
		var ext_a = a.resource_path != "" and not a.resource_path.contains("::")
		var ext_b = b.resource_path != "" and not b.resource_path.contains("::")
		if (ext_a or ext_b) and not top:
			if a.resource_path != b.resource_path:
				diffs.append("%s: external %s vs %s" % [path, a.resource_path, b.resource_path])
			return
		var key = "%d-%d" % [a.get_instance_id(), b.get_instance_id()]
		if seen.has(key):
			return
		seen[key] = true
		if a.get_script() != b.get_script():
			diffs.append("%s: script differs" % path)
			return
		for p in _stored_props(a):
			_diff(a.get(p), b.get(p), path + "." + p, diffs, seen)
		return
	if a is Array and b is Array:
		if a.size() != b.size():
			diffs.append("%s: size %d vs %d" % [path, a.size(), b.size()])
			return
		for i in a.size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], diffs, seen)
		return
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			diffs.append("%s: %s vs %s" % [path, a, b])
			return
		for k in a:
			if not b.has(k):
				diffs.append("%s: key %s missing (%s vs %s)" % [path, k, a, b])
				return
			_diff(a[k], b[k], "%s{%s}" % [path, k], diffs, seen)
		return
	if typeof(a) != typeof(b) or a != b:
		diffs.append("%s: %s (%s) vs %s (%s)" % [path, a, type_string(typeof(a)), b, type_string(typeof(b))])

func _assert_same(a, b, label: String) -> void:
	var diffs: Array = []
	_diff(a, b, label, diffs, {}, true)
	_check(diffs.is_empty(), "%s differs:\n      %s" % [label, "\n      ".join(diffs.slice(0, 15))])

func _new_graph() -> Array:
	var graph = GraphScript.new()
	graph.size = Vector2(1600, 1000)
	root.add_child(graph)
	var sp = SpeakersStub.new()
	root.add_child(sp)
	return [graph, sp]

func _free_graph(pair: Array) -> void:
	pair[0].queue_free()
	pair[1].queue_free()

## load -> graph -> encounter (in memory), then save -> reload
func _roundtrip(src, label: String):
	var pair = _new_graph()
	DeserializerScript.new().deserialize(src, pair[0], pair[1])
	var ser = SerializerScript.new()
	var out = ser.serialize(pair[0], pair[1].get_speakers(), src)
	_check(ser.errors.is_empty(), "%s: serializer errors %s" % [label, ser.errors])
	_free_graph(pair)
	var path = TMP_DIR + label.validate_filename() + ".tres"
	var err = SerializerScript.save_encounter(out, path)
	_check(err == OK, "%s: save failed %d" % [label, err])
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _all_lines(enc) -> Array:
	var out: Array = []
	var stack: Array = [enc.first_line]
	while not stack.is_empty():
		var l = stack.pop_back()
		if l == null or l in out:
			continue
		out.append(l)
		stack.append(l.next_line)
		for c in l.choices:
			stack.append(c.next_line)
	return out

# ============================================================================
# 15: lossless round-trip
# ============================================================================

func _test_real_dialogues() -> void:
	for path in ["res://resources/dialogues/test dialogue 3.tres",
			"res://resources/dialogues/cate/test_cate_receive_quest.tres",
			"res://resources/dialogues/cate/smithing_test.tres"]:
		var src = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(src != null, "could not load " + path)
		if src == null:
			continue
		var back = _roundtrip(src, "real_" + path.get_file().get_basename())
		_assert_same(src, back, "roundtrip(%s)" % path.get_file())
		# And a second generation must be stable too
		var back2 = _roundtrip(back, "real2_" + path.get_file().get_basename())
		_assert_same(src, back2, "roundtrip2(%s)" % path.get_file())

func _test_enriched_dialogue() -> void:
	var enc = ResourceLoader.load("res://resources/dialogues/test dialogue 3.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var tex = load("res://assets/ui/icons/mapbuttons/smithing.png")

	# Encounter-level fields (no editor widgets)
	enc.encounter_id = &"rt_test"
	enc.display_name = "Round trip"
	enc.initial_left_bust = &"cate"
	enc.initial_center_bust = &"player"
	enc.initial_right_bust = &"narrator"
	enc.pause_game = true
	enc.show_dim_overlay = false
	enc.dim_intensity = 0.75
	enc.one_shot = true
	enc.skippable = false
	enc.on_start_event = &"quest:talk:cate"
	enc.on_end_event = &"quest:custom:rt_end"
	enc.set_flags_on_start = [&"rt_start"] as Array[StringName]
	enc.set_flags_on_end = [&"rt_end"] as Array[StringName]

	var lines = _all_lines(enc)
	var visible: Array = []
	var with_choices: Array = []
	for l in lines:
		if l.text != "":
			visible.append(l)
		if not l.choices.is_empty():
			with_choices.append(l)
	_check(visible.size() >= 3 and with_choices.size() >= 2, "enriched: test dialogue 3 shape changed")

	# Line fields
	var l0 = visible[0]
	l0.text_key = "RT_KEY"
	l0.text_speed_override = 12.5
	l0.auto_advance = true
	l0.auto_advance_delay = 3.25
	l0.event_tag = &"quest:talk:cate"
	l0.set_flags = [&"line_flag"] as Array[StringName]
	l0.mood = &"base"
	l0.speaker_id = &"cate"
	l0.set_left_bust = &"cate"      # speaker on the LEFT: must not drift right
	l0.set_right_bust = &""
	l0.clear_center = true
	var l1 = visible[1]
	l1.mood = &"amused"
	l1.speaker_id = &"cate"
	l1.set_right_bust = &""
	l1.set_center_bust = &""
	l1.set_left_bust = &""          # speaker in no slot: must stay in no slot

	# Choice fields on a normal line
	var normal_choice_line = null
	for l in with_choices:
		if not str(l.event_tag).begins_with("game_action:"):
			normal_choice_line = l
			break
	_check(normal_choice_line != null, "enriched: no normal line with choices")
	var c0 = normal_choice_line.choices[0]
	c0.label_key = "RT_LABEL"
	c0.icon = tex
	c0.bubble_color_override = Color(0.2, 0.4, 0.6, 1.0)
	c0.event_tag = &"quest:collect:shell"
	c0.set_flags = [&"c0_flag", &"c0_flag2"] as Array[StringName]
	c0.relationship_changes = {&"cate": 5}
	c0.counter_changes = {&"virtue": 2, &"order": -1, &"bravery": 3}
	c0.approval_changes = {&"cate": 4, &"imbry": -2}
	var qs = ConditionScript.quest_state(&"harbor_masters_request", "ready")
	var fl = ConditionScript.flag(&"met_cate", true)
	var and_cond = ConditionScript.new()
	and_cond.condition_type = 3  # AND
	and_cond.sub_conditions.assign([qs, fl])
	c0.condition = and_cond
	c0.show_when_locked = true
	c0.locked_hint = "Not yet"
	c0.locked_hint_key = "RT_HINT"

	# A second choice: an inline-looking condition with invert (not inline-representable)
	var c_extra = ChoiceScript.new()
	c_extra.label = "Inverted flag"
	var inv = ConditionScript.flag(&"secret", true)
	inv.invert = true
	c_extra.condition = inv
	c_extra.next_line = visible[2]
	# And a simple inline one (representable)
	var c_simple = ChoiceScript.new()
	c_simple.label = "Approval gated"
	c_simple.condition = ConditionScript.approval(&"cate", ">=", 10)
	c_simple.counter_changes = {&"virtue": 1}
	normal_choice_line.choices.append(c_extra)
	normal_choice_line.choices.append(c_simple)

	# A normal line with BOTH choices and next_line (runtime fallback)
	normal_choice_line.next_line = visible[2]

	# Action line with choices: add a hidden-when-false choice
	var action_line = null
	for l in with_choices:
		if str(l.event_tag).begins_with("game_action:"):
			action_line = l
	if action_line:
		var ac = ChoiceScript.new()
		ac.label = "Only if flagged"
		ac.condition = ConditionScript.flag(&"never_set_test_flag", true)
		action_line.choices.append(ac)

	var back = _roundtrip(enc, "enriched")
	_assert_same(enc, back, "roundtrip(enriched)")

	# Spot checks that the specific regressions are gone
	_check(back.encounter_id == &"rt_test" and back.skippable == false, "enriched: encounter settings lost")
	var bl = _all_lines(back)
	var found_left = false
	for l in bl:
		if l.text == l0.text:
			found_left = l.set_left_bust == &"cate" and l.set_right_bust == &"" and l.event_tag == &"quest:talk:cate" and l.mood == &"base"
	_check(found_left, "enriched: bust slot / event_tag / mood drifted on line 0")

func _test_condition_and_set_flag_nodes() -> void:
	# Build: start -> line -> choices[A, B]; A -> SetFlag(set met) -> SetFlag(+2 virtue)
	#        -> Condition(flag gate) -> true: LT / false: LF ; B -> End
	var pair = _new_graph()
	var g = pair[0]
	var start = g.add_start_node(Vector2(10, 10))
	var line = g.add_line_node(Vector2(200, 10))
	line.set_node_data({"speaker_id": &"", "text": "Question?", "bust_name": "base", "speaker_slot": 0})
	var ch = g.add_choice_node(Vector2(400, 10))
	var a = {"label": "Ask"}
	var b = {"label": "Leave"}
	ch.set_node_data({"choices": [a, b]})
	var sf1 = g.add_set_flag_node(Vector2(600, 10))
	sf1.set_node_data({"flag_name": "met_cate", "action_type": 0, "value": 1})
	var sf2 = g.add_set_flag_node(Vector2(700, 10))
	sf2.set_node_data({"flag_name": "virtue", "action_type": 2, "value": 2})
	var cond = g.add_condition_node(Vector2(800, 10))
	cond.set_node_data({"condition_type": 6, "flag_name": "harbor_masters_request", "quest_state_value": "active", "expected_bool": true})
	var lt = g.add_line_node(Vector2(1000, 10))
	lt.set_node_data({"text": "TRUE branch", "speaker_slot": 0})
	var lf = g.add_line_node(Vector2(1000, 200))
	lf.set_node_data({"text": "FALSE branch", "speaker_slot": 0})
	var end = g.add_end_node(Vector2(600, 300))
	g.connect_node(start.name, 0, line.name, 0)
	g.connect_node(line.name, 0, ch.name, 0)
	g.connect_node(ch.name, 0, sf1.name, 0)
	g.connect_node(sf1.name, 0, sf2.name, 0)
	g.connect_node(sf2.name, 0, cond.name, 0)
	g.connect_node(cond.name, 0, lt.name, 0)
	g.connect_node(cond.name, 1, lf.name, 0)
	g.connect_node(ch.name, 1, end.name, 0)

	var ser = SerializerScript.new()
	var enc = ser.serialize(g, pair[1].get_speakers(), null)
	_free_graph(pair)
	_check(ser.errors.is_empty(), "cond/setflag: unexpected errors %s" % [ser.errors])
	var choices = enc.first_line.choices
	_check(choices.size() == 3, "cond/setflag: expected 3 compiled choices, got %d" % choices.size())
	if choices.size() == 3:
		var ct = choices[0]
		var cf = choices[1]
		_check(ct.label == "Ask" and cf.label == "Ask", "cond/setflag: split choices lost their label")
		_check(ct.set_flags == [&"met_cate"] and cf.set_flags == [&"met_cate"], "cond/setflag: Set Flag not compiled to choice.set_flags")
		_check(int(ct.counter_changes.get(&"virtue", 0)) == 2, "cond/setflag: counter increment not compiled")
		_check(ct.condition != null and ct.condition.single_check != null
			and int(ct.condition.single_check.check_type) == CT_QUEST_STATE
			and ct.condition.single_check.quest_state == "active" and not ct.condition.invert,
			"cond/setflag: true choice condition wrong")
		_check(cf.condition != null and cf.condition.invert and cf.condition.single_check == ct.condition.single_check,
			"cond/setflag: false choice must be NOT(condition) sharing the SingleCheck")
		_check(ct.next_line != null and ct.next_line.text == "TRUE branch", "cond/setflag: true branch miswired")
		_check(cf.next_line != null and cf.next_line.text == "FALSE branch", "cond/setflag: false branch miswired")
		_check(choices[2].label == "Leave" and choices[2].next_line == null, "cond/setflag: plain choice wrong")

	# Save, reload, and check the Condition node is rebuilt and re-saves identically
	var path = TMP_DIR + "cond_nodes.tres"
	ResourceSaver.save(enc, path)
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var pair2 = _new_graph()
	DeserializerScript.new().deserialize(loaded, pair2[0], pair2[1])
	var cond_nodes = pair2[0].get_nodes_by_type("condition")
	_check(cond_nodes.size() == 1, "cond/setflag: Condition node not rebuilt on load (%d)" % cond_nodes.size())
	if cond_nodes.size() == 1:
		var d = cond_nodes[0].get_node_data()
		_check(d.condition_type == 6 and d.flag_name == "harbor_masters_request" and d.quest_state_value == "active",
			"cond/setflag: rebuilt Condition node shows wrong data %s" % d)
	var ser2 = SerializerScript.new()
	var again = ser2.serialize(pair2[0], pair2[1].get_speakers(), loaded)
	_free_graph(pair2)
	_check(ser2.errors.is_empty(), "cond/setflag: re-save errors %s" % [ser2.errors])
	_assert_same(loaded, again, "roundtrip(condition node)")

func _test_refusals() -> void:
	var cases = [
		["line->condition", "condition", {"condition_type": 0, "flag_name": "x"}],
		["line->setflag", "set_flag", {"flag_name": "x", "action_type": 0}],
	]
	for c in cases:
		var pair = _new_graph()
		var g = pair[0]
		var start = g.add_start_node(Vector2(10, 10))
		var line = g.add_line_node(Vector2(200, 10))
		line.set_node_data({"text": "Hi", "speaker_slot": 0})
		var n = g.add_condition_node(Vector2(400, 10)) if c[1] == "condition" else g.add_set_flag_node(Vector2(400, 10))
		n.set_node_data(c[2])
		g.connect_node(start.name, 0, line.name, 0)
		g.connect_node(line.name, 0, n.name, 0)
		var ser = SerializerScript.new()
		ser.serialize(g, pair[1].get_speakers(), null)
		_check(not ser.errors.is_empty(), "refusal: %s should refuse to save" % c[0])
		_free_graph(pair)
	# Unsupported Set Flag modes after a choice
	for mode in [1, 4]:
		var pair = _new_graph()
		var g = pair[0]
		var start = g.add_start_node(Vector2(10, 10))
		var line = g.add_line_node(Vector2(200, 10))
		line.set_node_data({"text": "Hi", "speaker_slot": 0})
		var ch = g.add_choice_node(Vector2(400, 10))
		ch.set_node_data({"choices": [{"label": "ok"}]})
		var sf = g.add_set_flag_node(Vector2(600, 10))
		sf.set_node_data({"flag_name": "x", "action_type": mode, "value": 3})
		g.connect_node(start.name, 0, line.name, 0)
		g.connect_node(line.name, 0, ch.name, 0)
		g.connect_node(ch.name, 0, sf.name, 0)
		var ser = SerializerScript.new()
		ser.serialize(g, pair[1].get_speakers(), null)
		_check(not ser.errors.is_empty(), "refusal: Set Flag mode %d should refuse to save" % mode)
		_free_graph(pair)

func _test_uid_preserved() -> void:
	var src_path = "res://resources/dialogues/cate/smithing_test.tres"
	var text = FileAccess.get_file_as_string(src_path)
	# res:// on purpose: the saver only keeps/assigns uids for res:// paths
	var tmp = "res://tests/_tmp_uid_copy.tres"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var uid_start = text.find("uid=\"")
	var uid_before = text.substr(uid_start, text.find("\"", uid_start + 5) - uid_start + 1)
	var enc = ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE)
	var pair = _new_graph()
	DeserializerScript.new().deserialize(enc, pair[0], pair[1])
	var out = SerializerScript.new().serialize(pair[0], pair[1].get_speakers(), enc)
	_free_graph(pair)
	SerializerScript.save_encounter(out, tmp)
	var after = FileAccess.get_file_as_string(tmp)
	var header = after.substr(0, after.find("\n"))
	_check(header.contains(uid_before), "uid: file uid changed on save (%s -> %s)" % [uid_before, header])
	DirAccess.remove_absolute(tmp)

# ============================================================================
# 18: Quest Manager rewards
# ============================================================================

func _test_rewards_widget() -> void:
	var scene = load("res://addons/quest_manager/widgets/rewards_editor_widget.tscn")
	var w = scene.instantiate()
	root.add_child(w)
	var rs = load("res://resources/data/quest_rewards.gd")
	var r = rs.new()
	r.experience = 50
	r.gold = 20
	r.counter_changes = {&"virtue": 3, &"navy_standing": -2}
	r.relationship_changes = {&"cate": 5}
	r.unlock_flags = [&"f1"] as Array[StringName]
	var it = rs.ItemReward.new()
	it.item_id = &"salve"
	it.quantity = 2
	it.item_resource = load("res://assets/ui/icons/mapbuttons/smithing.png")
	var items = r.items.duplicate()
	items.append(it)
	r.items = items
	var before_counters = r.counter_changes.duplicate(true)
	w.load_rewards(r)
	var built = w.build_rewards()
	_assert_same(r, built, "rewards(unedited)")
	# Edit a shown field; hidden fields must survive, and the source must not change
	w.xp_spin.value = 99
	var built2 = w.build_rewards()
	_check(built2.experience == 99, "rewards: edit not applied")
	_check(built2.counter_changes == before_counters, "rewards: counter_changes lost on edit (%s)" % built2.counter_changes)
	_check(built2.items.size() == 1 and built2.items[0].item_resource == it.item_resource, "rewards: ItemReward.item_resource lost")
	_check(r.counter_changes == before_counters and r.experience == 50, "rewards: source resource was mutated")
	w.queue_free()

# ============================================================================
# 17: condition widget
# ============================================================================

func _test_condition_widget() -> void:
	var scene = load("res://addons/npc_dialogue_manager/widgets/condition_editor_widget.tscn")
	var w = scene.instantiate()
	root.add_child(w)

	var cases = []
	var q = ConditionScript.new()
	q.condition_type = 2
	q.single_check = SingleCheckScript.new()
	q.single_check.check_type = CT_CUSTOM
	q.single_check.key = &"quest_objective:harbor_masters_request:defeat_naval_enemies"
	cases.append(["quest objective (CUSTOM 9)", q, CT_CUSTOM, q.single_check.key])
	cases.append(["approval (8)", ConditionScript.approval(&"cate", ">=", 10), CT_APPROVAL, &"cate"])
	var raw = ConditionScript.new()
	raw.condition_type = 2
	raw.single_check = SingleCheckScript.new()
	raw.single_check.check_type = CT_CUSTOM
	raw.single_check.key = &"quest_objective_progress:q:o:>=:2"
	cases.append(["raw custom", raw, CT_CUSTOM, raw.single_check.key])
	var legacy = ConditionScript.new()
	legacy.condition_type = 2
	legacy.single_check = SingleCheckScript.new()
	legacy.single_check.check_type = CT_APPROVAL
	legacy.single_check.key = &"quest_objective:harbor_masters_request:defeat_naval_enemies"
	cases.append(["legacy 8 + quest_objective key", legacy, CT_CUSTOM, legacy.single_check.key])
	cases.append(["location visited (7)", ConditionScript.location_visited(&"loc_x"), CT_LOCATION_VISITED, &"loc_x"])

	for c in cases:
		w.load_condition(c[1])
		var built = w.build_condition()
		var sc = built.single_check
		_check(sc != null and int(sc.check_type) == int(c[2]) and sc.key == c[3],
			"condition widget %s: got type %s key %s" % [c[0], sc.check_type if sc else "null", sc.key if sc else ""])

	# Picking "Quest Objective" in the dropdown writes CUSTOM (9)
	var qo_index = -1
	for i in w.TYPE_ENTRIES.size():
		if w.TYPE_ENTRIES[i].quest_objective:
			qo_index = i
	w.load_condition(ConditionScript.flag(&"x", true))
	w.type_dropdown.select(qo_index)
	w._on_type_selected(qo_index)
	w._key = "harbor_masters_request"
	w._objective_id = "report_harbor_master"
	var built_qo = w.build_condition()
	_check(int(built_qo.single_check.check_type) == 9 and built_qo.single_check.key == &"quest_objective:harbor_masters_request:report_harbor_master",
		"condition widget: Quest Objective pick wrote %s / %s" % [built_qo.single_check.check_type, built_qo.single_check.key])

	# Every runtime check type is offered
	var offered = {}
	for e in w.TYPE_ENTRIES:
		offered[int(e.type)] = true
	for t in SingleCheckScript.get_script_constant_map()["CheckType"].values():
		_check(offered.has(int(t)), "condition widget: check type %d not offered" % t)

	# The live data fix
	var cate = ResourceLoader.load("res://resources/npcs/region_1/npc_cate.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var checks: Array = []
	for entry in cate.get("dialogue_table"):
		_collect_checks(entry.condition, checks)
	var found = false
	for sc in checks:
		if str(sc.key).begins_with("quest_objective:"):
			found = true
			_check(int(sc.check_type) == 9, "npc_cate.tres quest_objective check is type %d, expected 9" % sc.check_type)
	_check(found, "npc_cate.tres: quest_objective condition not found (property name changed?)")
	w.queue_free()

func _collect_checks(cond, out: Array) -> void:
	if cond == null:
		return
	if cond.single_check:
		out.append(cond.single_check)
	for sub in cond.sub_conditions:
		_collect_checks(sub, out)

# ============================================================================
# 21: choices after an action line
# ============================================================================

func _test_action_line_choice_indexing() -> void:
	var dm = root.get_node_or_null("DialogueManager")
	_check(dm != null, "DialogueManager autoload missing")
	if dm == null:
		return
	var target_hidden = LineScript.new()
	target_hidden.text = "HIDDEN TARGET"
	var target_shown = LineScript.new()
	target_shown.text = "SHOWN TARGET"
	var hidden = ChoiceScript.new()
	hidden.label = "hidden"
	hidden.condition = ConditionScript.flag(&"__editor_tools_test_never_set__", true)
	hidden.next_line = target_hidden
	var shown = ChoiceScript.new()
	shown.label = "shown"
	shown.next_line = target_shown
	var action = LineScript.new()
	action.auto_advance = true
	action.auto_advance_delay = 0.0
	action.event_tag = &"game_action:1:rt_test_shop"  # OPEN_SHOP: non-blocking, no listener
	action.choices.assign([hidden, shown])
	var enc = EncounterScript.new()
	enc.first_line = action

	var presented: Array = []
	var cb = func(choices): presented.append(choices)
	dm.choices_presented.connect(cb)
	dm.start_dialogue(enc)
	dm.choices_presented.disconnect(cb)
	_check(presented.size() == 1 and presented[0].size() == 1 and presented[0][0] == shown,
		"action-line choices: expected only the available choice to be presented, got %s" % [presented])
	dm.select_choice(0)
	_check(dm.current_line == target_shown, "action-line choices: select_choice(0) went to the wrong line")
	if dm.is_active:
		dm.skip_dialogue()

# ============================================================================
# 23: dropdown roots
# ============================================================================

func _test_dropdown_roots() -> void:
	var action_script = load("res://addons/dialogue_editor/nodes/action_node.gd")
	var consts = action_script.get_script_constant_map()
	_check(consts.get("ENCOUNTER_ROOT") == "res://resources/encounters/", "dropdown: ENCOUNTER_ROOT is %s" % consts.get("ENCOUNTER_ROOT"))
	_check(consts.get("DUNGEON_ROOT") == "res://resources/dungeon/", "dropdown: DUNGEON_ROOT is %s" % consts.get("DUNGEON_ROOT"))
	var node = load("res://addons/dialogue_editor/nodes/action_node.tscn").instantiate()
	root.add_child(node)
	var enc_results: Array = []
	node._scan_resource_dir(consts.ENCOUNTER_ROOT, "", "encounter_name", "CombatEncounter", enc_results)
	var has_baseline = false
	var has_region1 = false
	for e in enc_results:
		if str(e.id).contains("/baseline/"):
			has_baseline = true
		if str(e.id).contains("/region1/"):
			has_region1 = true
	_check(has_baseline and has_region1, "dropdown: combat scan missing baseline/region1 (%d found)" % enc_results.size())
	var dun_results: Array = []
	node._scan_resource_dir(consts.DUNGEON_ROOT, "", "dungeon_name", "DungeonDefinition", dun_results)
	_check(dun_results.size() >= 2, "dropdown: dungeon scan found %d DungeonDefinitions" % dun_results.size())
	print("  dropdown scan: %d combat encounters, %d dungeons" % [enc_results.size(), dun_results.size()])
	node.queue_free()

# ============================================================================
# Action types 8 GRANT_ITEM / 9 HEAL
# ============================================================================

func _test_grant_item_and_heal_actions() -> void:
	var action_script = load("res://addons/dialogue_editor/nodes/action_node.gd")
	_check(action_script.split_item_param("res://a/b.tres:3") == ["res://a/b.tres", 3], "grant item: split with quantity")
	_check(action_script.split_item_param("res://a/b.tres") == ["res://a/b.tres", 1], "grant item: split without quantity")

	# Pick one real equipment item and one consumable
	var node = load("res://addons/dialogue_editor/nodes/action_node.tscn").instantiate()
	root.add_child(node)
	var items: Array = []
	node._scan_resource_dir("res://resources/items/", "items", "item_name", "EquippableItem", items)
	var cons: Array = []
	node._scan_resource_dir("res://resources/consumables/", "consumables", "item_name", "ConsumableItem", cons)
	node.queue_free()
	_check(not items.is_empty() and not cons.is_empty(), "grant item: item scan found %d items, %d consumables" % [items.size(), cons.size()])
	if items.is_empty() or cons.is_empty():
		return

	# Encounter: action(grant item x3) -> action(grant consumable) -> action(heal) -> line
	var tags = [
		"game_action:8:%s:3" % items[0].id,
		"game_action:8:%s" % cons[0].id,
		"game_action:9:25+50%",
	]
	var enc = EncounterScript.new()
	var last = LineScript.new()
	last.text = "Done."
	var next = last
	for i in range(tags.size() - 1, -1, -1):
		var a = LineScript.new()
		a.auto_advance = true
		a.auto_advance_delay = 0.0
		a.event_tag = StringName(tags[i])
		a.next_line = next
		next = a
	enc.first_line = next

	var pair = _new_graph()
	DeserializerScript.new().deserialize(enc, pair[0], pair[1])
	# Let the action nodes build their deferred param UI (dropdown + quantity)
	await process_frame
	await process_frame
	var action_nodes = pair[0].get_nodes_by_type("game_action")
	var types: Array = []
	for n in action_nodes:
		types.append(n.get_node_data().action_type)
	types.sort()
	_check(types == [8, 8, 9], "grant item/heal: action node types %s" % [types])
	var ser = SerializerScript.new()
	var out = ser.serialize(pair[0], pair[1].get_speakers(), enc)
	_free_graph(pair)
	_check(ser.errors.is_empty(), "grant item/heal: serializer errors %s" % [ser.errors])
	_assert_same(enc, out, "roundtrip(grant item / heal actions)")

func _cleanup_tmp() -> void:
	var d = DirAccess.open(TMP_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(TMP_DIR)
