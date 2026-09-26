@tool
extends RefCounted
class_name DialogueSerializer

# Preload required classes (not automatically available in @tool context)
const DialogueLineScript = preload("res://resources/data/dialogue_line.gd")
const DialogueChoiceScript = preload("res://resources/data/dialogue_choice.gd")
const DialogueEncounterScript = preload("res://resources/data/dialogue_encounter.gd")
const GameConditionScript = preload("res://resources/data/game_condition.gd")
const Utils = preload("res://addons/dialogue_editor/io/dialogue_resource_utils.gd")

## Condition node output ports. GraphNode port indices count enabled ports only:
## slot 1 (True) is output port 0, slot 2 (False) is output port 1.
const CONDITION_TRUE_PORT := 0
const CONDITION_FALSE_PORT := 1

## Set Flag node action types (set_flag_node.gd ActionType)
const SF_SET_FLAG := 0
const SF_CLEAR_FLAG := 1
const SF_INCREMENT_COUNTER := 2
const SF_DECREMENT_COUNTER := 3
const SF_SET_COUNTER := 4

## choice_node.gd ChoiceCondType.PRESERVED: keep the original (complex) condition
const PRESERVED_COND_TYPE := 5

## Problems that would produce data the runtime ignores. The dock refuses to
## save while this is non-empty.
var errors: Array[String] = []

# ============================================================================
# SERIALIZE GRAPH TO DIALOGUE ENCOUNTER
# ============================================================================

func serialize(graph: DialogueGraphEdit, speakers: Array[DialogueSpeaker], source_encounter: Resource = null) -> DialogueEncounter:
	"""Convert the graph into a DialogueEncounter resource.

	source_encounter is the encounter the graph was loaded from (null for a new
	dialogue). Every encounter field the graph has no UI for (encounter_id,
	display_name, initial busts, settings, events, flags) is copied from it."""
	errors.clear()
	var encounter = DialogueEncounterScript.new()
	if source_encounter:
		Utils.copy_script_props(source_encounter, encounter, ["speakers", "first_line"])

	encounter.speakers.assign(speakers)

	var node_to_line: Dictionary = {}     # GraphNode -> DialogueLine
	var node_to_choices: Dictionary = {}  # ChoiceNode -> Array[DialogueChoice]
	var processed_nodes: Array = []

	# Create DialogueLine resources for all line nodes up-front
	for node in graph.get_all_nodes():
		if _node_type(node) == "line":
			node_to_line[node] = _create_line_from_node(node)

	var start_node = graph.get_start_node()
	if start_node:
		var first_target = graph.get_connected_node(start_node, 0)
		if first_target:
			encounter.first_line = _process_node_chain(first_target, graph, node_to_line, node_to_choices, processed_nodes)

	return encounter

static func save_encounter(encounter: Resource, path: String) -> Error:
	"""Save and keep the file's existing uid. The encounter is a new resource, so
	ResourceSaver would otherwise write the file without its uid and break
	uid-based references (e.g. from NPC dialogue tables)."""
	var old_uid = ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
	var err = ResourceSaver.save(encounter, path)
	if err == OK and old_uid != ResourceUID.INVALID_ID:
		var text = FileAccess.get_file_as_string(path)
		var header = text.substr(0, text.find("
"))
		if not header.contains(ResourceUID.id_to_text(old_uid)):
			err = ResourceSaver.set_uid(path, old_uid)
	return err

func _node_type(node) -> String:
	if node == null or not node.has_method("get_node_type"):
		return ""
	return node.get_node_type()

func _process_node_chain(
	node: GraphNode,
	graph: DialogueGraphEdit,
	node_to_line: Dictionary,
	node_to_choices: Dictionary,
	processed: Array
) -> DialogueLine:
	"""Recursively process a node and return the DialogueLine it represents."""
	if not node:
		return null

	# If already processed, return the existing line (allows multiple paths to same node)
	if node in processed:
		return node_to_line.get(node)

	match _node_type(node):
		"line":
			processed.append(node)
			var line = node_to_line.get(node) as DialogueLine
			if not line:
				return null
			_wire_line_output(line, node, graph, node_to_line, node_to_choices, processed)
			return line

		"game_action":
			processed.append(node)
			var action_line = _create_action_line_from_node(node)
			node_to_line[node] = action_line
			_wire_line_output(action_line, node, graph, node_to_line, node_to_choices, processed)
			return action_line

		"condition":
			processed.append(node)
			errors.append(("Condition node '%s' is not directly after a choice. The runtime cannot branch "
				+ "silently on a condition. Connect it to a choice output (the choice is then shown only "
				+ "when the condition holds, and the False branch becomes a second copy of the choice), "
				+ "or use conditional choices / separate NPC dialogue entries.") % node.name)
			return null

		"set_flag":
			processed.append(node)
			errors.append(("Set Flag node '%s' is not directly after a choice. The runtime ignores flags "
				+ "on lines. Connect it to a choice output (it becomes that choice's set_flags / "
				+ "counter_changes), or use an Action node (Custom Event) whose GameEventDefinition has a "
				+ "SET_FLAG effect.") % node.name)
			return null

	return null

func _wire_line_output(
	line: DialogueLine,
	node: GraphNode,
	graph: DialogueGraphEdit,
	node_to_line: Dictionary,
	node_to_choices: Dictionary,
	processed: Array
) -> void:
	"""Connect a line-like node's single output: choices, next line, or end."""
	var next_node = graph.get_connected_node(node, 0)
	var next_type = _node_type(next_node)
	if next_type == "choice":
		line.choices.assign(_process_choice_node(next_node, graph, node_to_line, node_to_choices, processed))
		# A line can carry both choices and next_line (the runtime falls back to
		# next_line when every choice is hidden, and action lines prefer it). The
		# deserializer shows that next_line as a detached branch and records it here.
		var hidden_name = str(node.get_meta("hidden_next_line_node", ""))
		if hidden_name != "":
			var hidden_node = graph.get_node_or_null(NodePath(hidden_name))
			if hidden_node is GraphNode:
				line.next_line = _process_node_chain(hidden_node, graph, node_to_line, node_to_choices, processed)
	elif next_node and next_type != "end":
		line.next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)

# ============================================================================
# CHOICES (Condition / Set Flag nodes compile onto them)
# ============================================================================

func _process_choice_node(
	node: GraphNode,
	graph: DialogueGraphEdit,
	node_to_line: Dictionary,
	node_to_choices: Dictionary,
	processed: Array
) -> Array[DialogueChoice]:
	"""Build the DialogueChoice list for a choice node and wire each output."""
	if node_to_choices.has(node):
		return node_to_choices[node]
	processed.append(node)

	var result: Array[DialogueChoice] = []
	node_to_choices[node] = result
	var choice_data_array = node.get_node_data().get("choices", [])
	for i in choice_data_array.size():
		var base = _create_choice_from_data(choice_data_array[i])
		# Choice outputs: choice i is output port i
		var target = graph.get_connected_node(node, i)
		result.append_array(_expand_choice_target(base, target, [], graph, node_to_line, node_to_choices, processed, []))
	return result

func _expand_choice_target(
	base: DialogueChoice,
	target: GraphNode,
	extra_conditions: Array,
	graph: DialogueGraphEdit,
	node_to_line: Dictionary,
	node_to_choices: Dictionary,
	processed: Array,
	visiting: Array
) -> Array[DialogueChoice]:
	"""Resolve Set Flag / Condition nodes hanging off a choice output.

	- Set Flag nodes become effects on the choice (set_flags / counter_changes),
	  which DialogueChoice.apply_effects() runs when the choice is picked.
	- A Condition node splits the choice: one copy gated on the condition leads to
	  the True branch, and (if the False port is connected) one copy gated on NOT
	  condition leads to the False branch. The copies share one SingleCheck
	  sub-resource so the deserializer can rebuild the Condition node on load."""
	var out: Array[DialogueChoice] = []
	var t = _node_type(target)

	if t == "set_flag" or t == "condition":
		if target in visiting:
			errors.append("Loop through '%s' after a choice: Condition/Set Flag nodes cannot form a cycle." % target.name)
			return out
		visiting = visiting + [target]

	if t == "set_flag":
		_apply_set_flag_to_choice(base, target)
		var next_target = graph.get_connected_node(target, 0)
		return _expand_choice_target(base, next_target, extra_conditions, graph, node_to_line, node_to_choices, processed, visiting)

	if t == "condition":
		var cond = _create_condition_resource(target.get_node_data())
		if cond == null:
			errors.append("Condition node '%s' is incomplete (its flag / counter / quest / NPC key is empty)." % target.name)
			return out
		var true_target = graph.get_connected_node(target, CONDITION_TRUE_PORT)
		var false_target = graph.get_connected_node(target, CONDITION_FALSE_PORT)
		out.append_array(_expand_choice_target(_copy_choice(base), true_target, extra_conditions + [cond],
			graph, node_to_line, node_to_choices, processed, visiting))
		if false_target != null:
			var neg = GameConditionScript.new()
			neg.condition_type = cond.condition_type
			neg.single_check = cond.single_check
			neg.invert = not cond.invert
			out.append_array(_expand_choice_target(_copy_choice(base), false_target, extra_conditions + [neg],
				graph, node_to_line, node_to_choices, processed, visiting))
		return out

	# Terminal: a line / action / end / nothing
	var all_conds: Array = []
	if base.condition != null:
		all_conds.append(base.condition)
	all_conds.append_array(extra_conditions)
	if all_conds.size() == 1:
		base.condition = all_conds[0]
	elif all_conds.size() > 1:
		var and_cond = GameConditionScript.new()
		and_cond.condition_type = 3  # AND
		var subs: Array[GameCondition] = []
		for c in all_conds:
			subs.append(c)
		and_cond.sub_conditions = subs
		base.condition = and_cond
	if target != null and t != "end":
		base.next_line = _process_node_chain(target, graph, node_to_line, node_to_choices, processed)
	out.append(base)
	return out

func _copy_choice(choice: DialogueChoice) -> DialogueChoice:
	var c = DialogueChoiceScript.new()
	Utils.copy_script_props(choice, c)
	return c

func _apply_set_flag_to_choice(choice: DialogueChoice, node: GraphNode) -> void:
	var data = node.get_node_data()
	var flag_name = str(data.get("flag_name", "")).strip_edges()
	var action_type = int(data.get("action_type", SF_SET_FLAG))
	var value = int(data.get("value", 1))
	if flag_name == "":
		errors.append("Set Flag node '%s' has no flag/counter name." % node.name)
		return
	match action_type:
		SF_SET_FLAG:
			var flags: Array[StringName] = []
			flags.assign(choice.set_flags)
			if not StringName(flag_name) in flags:
				flags.append(StringName(flag_name))
			choice.set_flags = flags
		SF_INCREMENT_COUNTER, SF_DECREMENT_COUNTER:
			var delta = value if action_type == SF_INCREMENT_COUNTER else -value
			var cc: Dictionary = choice.counter_changes.duplicate(true)
			var existing_key = Utils.find_key(cc, flag_name)
			var key = existing_key if existing_key != null else StringName(flag_name)
			cc[key] = int(cc.get(key, 0)) + delta
			choice.counter_changes = cc
		SF_CLEAR_FLAG:
			errors.append(("Set Flag node '%s' uses Clear Flag, which dialogue choices cannot do "
				+ "(they only set flags true). Use an Action node (Custom Event) with a "
				+ "GameEventDefinition instead.") % node.name)
		SF_SET_COUNTER:
			errors.append(("Set Flag node '%s' uses Set Counter To, which dialogue choices cannot do "
				+ "(they only add to counters). Use Increment/Decrement, or an Action node "
				+ "(Custom Event) with a GameEventDefinition.") % node.name)
		_:
			errors.append("Set Flag node '%s' has an unknown action type %d." % [node.name, action_type])

func _create_choice_from_data(choice_data: Dictionary) -> DialogueChoice:
	"""Create a DialogueChoice from a choice-node entry. Every field the UI has no
	widget for is preserved from the original resource (entry key "_source")."""
	var choice = DialogueChoiceScript.new()
	var src = choice_data.get("_source", null)
	if src != null:
		Utils.copy_script_props(src, choice, ["next_line", "condition"])

	choice.label = choice_data.get("label", "")

	# Moral weight -> counter_changes (other counters are preserved)
	var cc: Dictionary = choice.counter_changes.duplicate(true)
	for axis in ["virtue", "order"]:
		var ui_val = int(choice_data.get(axis, 0))
		var existing_key = Utils.find_key(cc, axis)
		var existing_val = int(cc[existing_key]) if existing_key != null else 0
		if ui_val == existing_val:
			continue
		if existing_key != null:
			cc.erase(existing_key)
		if ui_val != 0:
			cc[existing_key if existing_key != null else StringName(axis)] = ui_val
	choice.counter_changes = cc

	# Approval: the UI shows only the first entry; the rest are preserved
	var ac: Dictionary = choice.approval_changes.duplicate(true)
	var ui_npc = str(choice_data.get("approval_npc", "")).strip_edges()
	var ui_appr = int(choice_data.get("approval", 0))
	var first_key = ac.keys()[0] if not ac.is_empty() else null
	var unchanged = (first_key == null and (ui_npc == "" or ui_appr == 0)) \
		or (first_key != null and str(first_key) == ui_npc and int(ac[first_key]) == ui_appr)
	if not unchanged:
		if first_key != null:
			ac.erase(first_key)
		if ui_npc != "" and ui_appr != 0:
			ac[StringName(ui_npc)] = ui_appr
	choice.approval_changes = ac

	# Condition: the simple inline condition from the UI, or the original
	# (complex) condition when the entry is marked as preserved.
	if int(choice_data.get("cond_type", 0)) == PRESERVED_COND_TYPE:
		choice.condition = src.condition if src != null else null
	else:
		choice.condition = _create_choice_condition(choice_data)

	choice.show_when_locked = choice_data.get("show_when_locked", false)
	choice.locked_hint = choice_data.get("locked_hint", "")
	return choice

# ============================================================================
# LINES
# ============================================================================

static func mood_to_bust_name(mood: StringName) -> String:
	"""How a line's mood is shown in the Line node's bust dropdown."""
	return str(mood) if mood != &"" else "base"

func _create_line_from_node(node: GraphNode) -> DialogueLine:
	"""Create a DialogueLine from a Line GraphNode."""
	var line = DialogueLineScript.new()
	var src = (node.get_meta("source_line") if node.has_meta("source_line") else null)
	if src != null:
		Utils.copy_script_props(src, line, ["next_line", "choices"])
	var data = node.get_node_data()

	line.speaker_id = data.get("speaker_id", &"")
	line.text = data.get("text", "")

	# Mood ("base" in the UI means no mood). If the UI still shows what the
	# original mood loads as, keep the original value (e.g. an explicit &"base").
	var bust_name = str(data.get("bust_name", ""))
	if src != null and mood_to_bust_name(src.mood) == bust_name:
		line.mood = src.mood
	elif bust_name != "" and bust_name != "base":
		line.mood = StringName(bust_name)
	else:
		line.mood = &""

	# Explicit bust slot assignments from the "Bust Slots" section
	line.set_left_bust = data.get("left_speaker", &"")
	line.set_center_bust = data.get("center_speaker", &"")
	line.set_right_bust = data.get("right_speaker", &"")

	# If the speaker is placed in a slot, put them there (only fills empty slots).
	# speaker_slot: 0=NONE, 1=LEFT, 2=CENTER, 3=RIGHT
	var speaker_slot = data.get("speaker_slot", 3)
	if line.speaker_id != &"" and speaker_slot > 0:
		match speaker_slot:
			1:
				if line.set_left_bust == &"":
					line.set_left_bust = line.speaker_id
			2:
				if line.set_center_bust == &"":
					line.set_center_bust = line.speaker_id
			3:
				if line.set_right_bust == &"":
					line.set_right_bust = line.speaker_id

	line.clear_left = data.get("clear_left", false)
	line.clear_center = data.get("clear_center", false)
	line.clear_right = data.get("clear_right", false)

	return line

func _create_action_line_from_node(node: GraphNode) -> DialogueLine:
	"""Action nodes are invisible auto-advance lines with a game_action event_tag."""
	var action_line = DialogueLineScript.new()
	var src = (node.get_meta("source_line") if node.has_meta("source_line") else null)
	if src != null:
		Utils.copy_script_props(src, action_line, ["next_line", "choices"])
	else:
		action_line.auto_advance_delay = 0.0
	action_line.text = ""
	action_line.auto_advance = true

	# Encode: "game_action:<type_int>:<payload>"
	var node_data = node.get_node_data()
	var action_type = node_data.get("action_type", 0)
	var param = node_data.get("param", "")
	action_line.event_tag = StringName("game_action:%d:%s" % [action_type, param])
	return action_line

# ============================================================================
# CONDITIONS
# ============================================================================

func _create_condition_resource(node_data: Dictionary) -> GameCondition:
	"""Create a GameCondition from Condition node data. Returns null if the node
	is missing the key it needs."""
	var condition_type = node_data.get("condition_type", 0)
	var flag_name = str(node_data.get("flag_name", ""))
	var compare_value = node_data.get("compare_value", 0)
	var op = node_data.get("compare_operator", ">=")
	var p_expected = node_data.get("expected_bool", true)
	var quest_state_val = node_data.get("quest_state_value", "complete")
	var p_class_id = str(node_data.get("class_id", ""))
	var p_objective_id = str(node_data.get("objective_id", ""))
	var p_obj_check_mode = node_data.get("objective_check_mode", 0)

	# Condition node enum: FLAG=0, COUNTER=1, RELATIONSHIP=2, HAS_ITEM=3, PLAYER_LEVEL=4,
	#                      CLASS_LEVEL=5, QUEST_STATE=6, QUEST_OBJECTIVE=7, LOCATION_VISITED=8,
	#                      APPROVAL=9
	match condition_type:
		0:  # FLAG
			if flag_name == "":
				return null
			return GameConditionScript.flag(StringName(flag_name), p_expected)
		1:  # COUNTER
			if flag_name == "":
				return null
			return GameConditionScript.counter_compare(StringName(flag_name), op, compare_value)
		2:  # RELATIONSHIP
			if flag_name == "":
				return null
			return GameConditionScript.relationship(StringName(flag_name), op, compare_value)
		3:  # HAS_ITEM
			if flag_name == "":
				return null
			var cond = GameConditionScript.has_item(StringName(flag_name), op, compare_value)
			if not p_expected:
				cond.invert = true
			return cond
		4:  # PLAYER_LEVEL
			return GameConditionScript.player_level(op, compare_value)
		5:  # CLASS_LEVEL
			if p_class_id == "":
				return null
			return GameConditionScript.class_level(StringName(p_class_id), op, compare_value)
		6:  # QUEST_STATE
			if flag_name == "":
				return null
			return GameConditionScript.quest_state(StringName(flag_name), quest_state_val)
		7:  # QUEST_OBJECTIVE
			if flag_name == "" or p_objective_id == "":
				return null
			# ObjectiveCheckMode: IS_COMPLETE=0, IS_NOT_COMPLETE=1, PROGRESS_GTE=2, PROGRESS_LT=3, PROGRESS_EQ=4
			if p_obj_check_mode >= 2:
				var progress_op = ">="
				match p_obj_check_mode:
					2: progress_op = ">="
					3: progress_op = "<"
					4: progress_op = "=="
				return GameConditionScript.quest_objective_progress(
					StringName(flag_name), StringName(p_objective_id), progress_op, compare_value)
			else:
				var composite_key = "quest_objective:%s:%s" % [flag_name, p_objective_id]
				var cond = GameConditionScript.quest_objective(StringName(composite_key))
				if p_obj_check_mode == 1:  # IS_NOT_COMPLETE
					cond.invert = true
				return cond
		8:  # LOCATION_VISITED
			if flag_name == "":
				return null
			var cond = GameConditionScript.location_visited(StringName(flag_name))
			if not p_expected:
				cond.invert = true
			return cond
		9:  # APPROVAL
			if flag_name == "":
				return null
			return GameConditionScript.approval(StringName(flag_name), op, compare_value)

	return null

func _create_choice_condition(choice_data: Dictionary) -> GameCondition:
	"""Create a GameCondition from inline per-choice condition data. Returns null for NONE."""
	# ChoiceCondType: NONE=0, FLAG=1, COUNTER=2, RELATIONSHIP=3, APPROVAL=4, PRESERVED=5
	var cond_type = choice_data.get("cond_type", 0)
	if cond_type == 0:
		return null

	var key = choice_data.get("cond_key", "")
	if key == "":
		return null

	var op = choice_data.get("cond_op", ">=")
	var value = choice_data.get("cond_value", 0)
	var cond_bool = choice_data.get("cond_bool", true)

	match cond_type:
		1:  # FLAG
			return GameConditionScript.flag(StringName(key), cond_bool)
		2:  # COUNTER
			return GameConditionScript.counter_compare(StringName(key), op, value)
		3:  # RELATIONSHIP
			return GameConditionScript.relationship(StringName(key), op, value)
		4:  # APPROVAL
			return GameConditionScript.approval(StringName(key), op, value)

	return null
