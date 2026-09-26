@tool
extends RefCounted
class_name DialogueDeserializer

## Loads a DialogueEncounter into the graph. To keep load -> save lossless:
## - each Line / Action / Set Flag node keeps its original DialogueLine as
##   metadata "source_line";
## - each choice entry keeps its original DialogueChoice under "_source";
## - a line with both choices and next_line gets its next_line drawn as a
##   detached branch, recorded in metadata "hidden_next_line_node";
## - conditions the inline choice UI cannot show are kept as "Advanced (kept)".
## The dock keeps the encounter itself for the encounter-level fields.

const Utils = preload("res://addons/dialogue_editor/io/dialogue_resource_utils.gd")
const SerializerScript = preload("res://addons/dialogue_editor/io/dialogue_serializer.gd")

## choice_node.gd ChoiceCondType
const COND_NONE := 0
const COND_FLAG := 1
const COND_COUNTER := 2
const COND_RELATIONSHIP := 3
const COND_APPROVAL := 4
const COND_PRESERVED := 5

var _serializer = SerializerScript.new()

# ============================================================================
# DESERIALIZE DIALOGUE ENCOUNTER TO GRAPH
# ============================================================================

func deserialize(encounter: DialogueEncounter, graph: DialogueGraphEdit, speakers_panel: Control) -> void:
	"""Load a DialogueEncounter into the graph editor."""
	graph.clear_graph()
	speakers_panel.clear_speakers()

	for speaker in encounter.speakers:
		speakers_panel.add_speaker(speaker)
	graph.set_available_speakers(speakers_panel.get_speakers())

	var start_node = graph.add_start_node(Vector2(100, 200))

	var line_to_node: Dictionary = {}  # DialogueLine -> GraphNode
	if encounter.first_line:
		var first_node = _process_line(encounter.first_line, graph, line_to_node, Vector2(350, 200))
		if first_node:
			graph.connect_node(start_node.name, 0, first_node.name, 0)

func _process_line(line: DialogueLine, graph: DialogueGraphEdit, line_to_node: Dictionary, position: Vector2) -> GraphNode:
	"""Create the node for a DialogueLine (once) and everything after it."""
	if line_to_node.has(line):
		return line_to_node[line]

	var node: GraphNode = null
	var tag = str(line.event_tag)
	if line.text == "" and line.auto_advance and tag.begins_with("game_action:"):
		node = _create_action_node(line, graph)
	elif line.text == "" and line.auto_advance and tag.begins_with("set_flag:"):
		# Legacy Set Flag line (older editor versions). The runtime ignores it;
		# the node is shown so the designer can move it after a choice.
		node = _create_legacy_set_flag_node(line, graph)
	elif _is_legacy_condition_line(line):
		return _create_legacy_condition_node(line, graph, line_to_node, position)
	else:
		node = _create_line_node(line, graph)

	node.position_offset = position
	line_to_node[line] = node
	_attach_outputs(line, node, graph, line_to_node, position)
	return node

# ============================================================================
# NODE BUILDERS
# ============================================================================

func _create_line_node(line: DialogueLine, graph: DialogueGraphEdit) -> GraphNode:
	var node = graph.add_line_node(Vector2(1, 1))
	node.set_meta("source_line", line)

	# Put the speaker's slot where the speaker already is; if they are in no
	# slot, use NONE so saving never adds a bust the file did not have.
	var speaker_slot = 0  # NONE
	if line.speaker_id != &"":
		if line.set_right_bust == line.speaker_id:
			speaker_slot = 3
		elif line.set_center_bust == line.speaker_id:
			speaker_slot = 2
		elif line.set_left_bust == line.speaker_id:
			speaker_slot = 1

	node.set_node_data({
		"speaker_id": line.speaker_id,
		"bust_name": SerializerScript.mood_to_bust_name(line.mood),
		"speaker_slot": speaker_slot,
		"text": line.text,
		"left_speaker": line.set_left_bust,
		"left_bust": "",
		"center_speaker": line.set_center_bust,
		"center_bust": "",
		"right_speaker": line.set_right_bust,
		"right_bust": "",
		"clear_left": line.clear_left,
		"clear_center": line.clear_center,
		"clear_right": line.clear_right,
	})
	var extras = _line_extras_summary(line)
	if extras != "":
		node.tooltip_text = "Kept on save (no editor widget): " + extras
	return node

func _create_action_node(line: DialogueLine, graph: DialogueGraphEdit) -> GraphNode:
	var node = graph.add_action_node(Vector2(1, 1))
	node.set_meta("source_line", line)
	# Parse event_tag: "game_action:<type_int>:<param>" (param may contain colons)
	var tag_str = str(line.event_tag)
	var first_colon = tag_str.find(":")
	var second_colon = tag_str.find(":", first_colon + 1)
	if first_colon >= 0 and second_colon >= 0:
		node.set_node_data({
			"action_type": int(tag_str.substr(first_colon + 1, second_colon - first_colon - 1)),
			"param": tag_str.substr(second_colon + 1),
		})
	return node

func _create_legacy_set_flag_node(line: DialogueLine, graph: DialogueGraphEdit) -> GraphNode:
	var node = graph.add_set_flag_node(Vector2(1, 1))
	node.set_meta("source_line", line)
	var parts = str(line.event_tag).split(":")
	if parts.size() >= 4:
		node.set_node_data({
			"flag_name": parts[1],
			"action_type": int(parts[2]),
			"value": int(parts[3]),
		})
	return node

func _is_legacy_condition_line(line: DialogueLine) -> bool:
	"""Old editor versions wrote Condition nodes as an invisible line with two
	blank-label choices, the first carrying the condition."""
	if line.text != "" or not line.auto_advance or line.event_tag != &"":
		return false
	if line.choices.size() != 2 or line.choices[0].condition == null:
		return false
	return line.choices[0].label == "" and line.choices[1].label == ""

func _create_legacy_condition_node(line: DialogueLine, graph: DialogueGraphEdit, line_to_node: Dictionary, position: Vector2) -> GraphNode:
	var node = graph.add_condition_node(position)
	line_to_node[line] = node
	node.set_node_data(_parse_condition(line.choices[0].condition))
	var next_pos = position + Vector2(350, 0)
	_connect_to_line(graph, node, SerializerScript.CONDITION_TRUE_PORT, line.choices[0].next_line, line_to_node, next_pos + Vector2(0, -100))
	_connect_to_line(graph, node, SerializerScript.CONDITION_FALSE_PORT, line.choices[1].next_line, line_to_node, next_pos + Vector2(0, 100))
	return node

# ============================================================================
# OUTPUTS
# ============================================================================

func _attach_outputs(line: DialogueLine, node: GraphNode, graph: DialogueGraphEdit, line_to_node: Dictionary, position: Vector2) -> void:
	"""Wire a line-like node's output: choices, next line, or End."""
	var next_pos = position + Vector2(400, 0)
	if line.choices.size() > 0:
		var choice_node = _build_choice_node(line, graph, line_to_node, next_pos)
		graph.connect_node(node.name, 0, choice_node.name, 0)
		if line.next_line:
			# The graph has one output per line, so a next_line that coexists with
			# choices is drawn as a detached branch below and re-attached on save.
			var branch_pos = position + Vector2(0, 260 + 150 * line.choices.size())
			var hidden = _process_line(line.next_line, graph, line_to_node, branch_pos)
			if hidden:
				node.set_meta("hidden_next_line_node", str(hidden.name))
				var note = "Also has next_line -> '%s' (detached branch). The runtime uses it " % hidden.name
				note += "instead of the choices on action lines, and when every choice is hidden on normal lines."
				node.tooltip_text = (node.tooltip_text + "\n" + note).strip_edges()
	else:
		_connect_to_line(graph, node, 0, line.next_line, line_to_node, next_pos)

func _connect_to_line(graph: DialogueGraphEdit, from_node: GraphNode, port: int, target: DialogueLine, line_to_node: Dictionary, pos: Vector2) -> void:
	"""Connect from_node:port to the node for target, or to a new End node."""
	if target:
		var to_node = _process_line(target, graph, line_to_node, pos)
		if to_node:
			graph.connect_node(from_node.name, port, to_node.name, 0)
			return
	var end_node = graph.add_end_node(pos)
	graph.connect_node(from_node.name, port, end_node.name, 0)

func _build_choice_node(line: DialogueLine, graph: DialogueGraphEdit, line_to_node: Dictionary, pos: Vector2) -> GraphNode:
	"""Create the choice node for a line's choices. A pair of choices written by a
	Condition node (see DialogueSerializer._expand_choice_target) is rebuilt as a
	single entry followed by a Condition node."""
	var choice_node = graph.add_choice_node(pos)
	var entries: Array = []
	var wiring: Array = []  # [port, kind, a, b, cond_data]
	var choices = line.choices
	var i = 0
	while i < choices.size():
		var a = choices[i]
		var b = choices[i + 1] if i + 1 < choices.size() else null
		var cond_data = _paired_condition_data(a, b)
		if not cond_data.is_empty():
			entries.append(_build_choice_dict(a, true))
			wiring.append([entries.size() - 1, "condition", a, b, cond_data])
			i += 2
		else:
			entries.append(_build_choice_dict(a, false))
			wiring.append([entries.size() - 1, "line", a, null, {}])
			i += 1

	# Set data first so the choice node has an output port per entry
	choice_node.set_node_data({"choices": entries})

	var y_offset = 0
	for w in wiring:
		var port: int = w[0]
		var target_pos = pos + Vector2(400, y_offset)
		if w[1] == "condition":
			var cnode = graph.add_condition_node(target_pos)
			cnode.set_node_data(w[4])
			graph.connect_node(choice_node.name, port, cnode.name, 0)
			var after = target_pos + Vector2(350, 0)
			_connect_to_line(graph, cnode, SerializerScript.CONDITION_TRUE_PORT, w[2].next_line, line_to_node, after + Vector2(0, -100))
			_connect_to_line(graph, cnode, SerializerScript.CONDITION_FALSE_PORT, w[3].next_line, line_to_node, after + Vector2(0, 100))
			y_offset += 300
		else:
			_connect_to_line(graph, choice_node, port, w[2].next_line, line_to_node, target_pos)
			y_offset += 150
	return choice_node

func _paired_condition_data(a, b) -> Dictionary:
	"""If a and b are the True/False copies of one choice split by a Condition
	node, return that Condition node's data; otherwise {}."""
	if a == null or b == null or a.condition == null or b.condition == null:
		return {}
	var ca = a.condition
	var cb = b.condition
	if int(ca.condition_type) != 2 or int(cb.condition_type) != 2:
		return {}
	if ca.single_check == null or ca.single_check != cb.single_check or cb.invert == ca.invert:
		return {}
	# Everything except the condition and target must match
	for pname in Utils.stored_script_props(a):
		if pname == "condition" or pname == "next_line":
			continue
		if not Utils.values_equal(a.get(pname), b.get(pname)):
			return {}
	# The Condition node must be able to reproduce the condition exactly
	var data = _parse_condition(ca)
	var rebuilt = _serializer._create_condition_resource(data)
	if rebuilt == null or not Utils.values_equal(rebuilt, ca):
		return {}
	return data

# ============================================================================
# CHOICE ENTRIES
# ============================================================================

func _build_choice_dict(choice, condition_handled_by_node: bool) -> Dictionary:
	"""Build a choice node entry from a DialogueChoice (original kept in _source)."""
	var appr_npc = ""
	var appr_val = 0
	if not choice.approval_changes.is_empty():
		appr_npc = str(choice.approval_changes.keys()[0])
		appr_val = int(choice.approval_changes.values()[0])

	var virtue_key = Utils.find_key(choice.counter_changes, "virtue")
	var order_key = Utils.find_key(choice.counter_changes, "order")
	var d = {
		"label": choice.label,
		"virtue": int(choice.counter_changes[virtue_key]) if virtue_key != null else 0,
		"order": int(choice.counter_changes[order_key]) if order_key != null else 0,
		"approval_npc": appr_npc,
		"approval": appr_val,
		"show_when_locked": choice.show_when_locked,
		"locked_hint": choice.locked_hint,
		"_source": choice,
		"effects_summary": _choice_extras_summary(choice),
	}
	if condition_handled_by_node:
		d.merge({"cond_type": COND_NONE, "cond_key": "", "cond_op": ">=", "cond_value": 0, "cond_bool": true})
	else:
		d.merge(_parse_choice_condition(choice))
	return d

func _parse_choice_condition(choice) -> Dictionary:
	"""Reverse-map a choice's condition to the inline condition fields. A condition
	the inline UI cannot reproduce exactly is marked PRESERVED and kept as-is."""
	var result = {
		"cond_type": COND_NONE,
		"cond_key": "",
		"cond_op": ">=",
		"cond_value": 0,
		"cond_bool": true,
		"cond_summary": "",
	}
	if choice.condition == null:
		return result

	var cond = choice.condition
	var check = cond.single_check if int(cond.condition_type) == 2 else null
	if check != null:
		result.cond_key = str(check.key)
		result.cond_op = check.compare_operator
		result.cond_value = check.int_value
		match int(check.check_type):
			0:
				result.cond_type = COND_FLAG
				result.cond_bool = check.bool_value
			1:
				result.cond_type = COND_COUNTER
			2:
				result.cond_type = COND_RELATIONSHIP
			8:
				result.cond_type = COND_APPROVAL

	# Only use the inline form if it rebuilds the identical condition
	var rebuilt = _serializer._create_choice_condition(result) if result.cond_type != COND_NONE else null
	if rebuilt == null or not Utils.values_equal(rebuilt, cond):
		result.cond_type = COND_PRESERVED
		result.cond_key = ""
		result.cond_summary = Utils.describe_condition(cond)
	return result

func _parse_condition(condition: Resource) -> Dictionary:
	"""Reverse-map a GameCondition resource back to Condition node data."""
	# Condition node enum: FLAG=0, COUNTER=1, RELATIONSHIP=2, HAS_ITEM=3, PLAYER_LEVEL=4,
	#                      CLASS_LEVEL=5, QUEST_STATE=6, QUEST_OBJECTIVE=7, LOCATION_VISITED=8,
	#                      APPROVAL=9
	var data = {
		"condition_type": 0,
		"flag_name": "",
		"compare_value": 0,
		"compare_operator": ">=",
		"expected_bool": true,
		"quest_state_value": "complete",
		"class_id": "",
		"objective_id": "",
		"objective_check_mode": 0,
	}
	if condition == null or int(condition.condition_type) != 2:  # SINGLE
		return data
	var check = condition.single_check
	if check == null:
		return data

	var is_inverted: bool = condition.invert
	data.flag_name = str(check.key)
	data.compare_value = check.int_value
	data.compare_operator = check.compare_operator

	# SingleCheck.CheckType -> Condition node type
	match int(check.check_type):
		0:  # FLAG
			data.condition_type = 0
			data.expected_bool = check.bool_value
		1:  # COUNTER
			data.condition_type = 1
		2:  # RELATIONSHIP
			data.condition_type = 2
		3:  # HAS_ITEM
			data.condition_type = 3
			data.expected_bool = not is_inverted
		4:  # PLAYER_LEVEL
			data.condition_type = 4
		5:  # CLASS_LEVEL
			data.condition_type = 5
			data.class_id = str(check.class_id)
		6:  # QUEST_STATE
			data.condition_type = 6
			data.quest_state_value = check.quest_state
		7:  # LOCATION_VISITED
			data.condition_type = 8
			data.expected_bool = not is_inverted
		8:  # APPROVAL
			data.condition_type = 9
		9:  # CUSTOM
			var key_str = str(check.key)
			if key_str.begins_with("quest_objective_progress:"):
				# key = "quest_objective_progress:quest_id:obj_id:op:value"
				data.condition_type = 7
				var parts = key_str.split(":")
				if parts.size() >= 5:
					data.flag_name = parts[1]
					data.objective_id = parts[2]
					data.compare_value = int(parts[4])
					match parts[3]:
						">=": data.objective_check_mode = 2
						"<":  data.objective_check_mode = 3
						"==": data.objective_check_mode = 4
						_:    data.objective_check_mode = 2
			elif key_str.begins_with("quest_objective:"):
				data.condition_type = 7
				data.objective_check_mode = 1 if is_inverted else 0
				var parts = key_str.split(":")
				if parts.size() >= 3:
					data.flag_name = parts[1]
					data.objective_id = parts[2]
	return data

# ============================================================================
# SUMMARIES OF PRESERVED FIELDS (shown read-only in the editor)
# ============================================================================

func _choice_extras_summary(choice) -> String:
	var parts: Array[String] = []
	if not choice.set_flags.is_empty():
		parts.append("set flags %s" % str(choice.set_flags))
	var other_counters = {}
	for k in choice.counter_changes:
		if str(k) != "virtue" and str(k) != "order":
			other_counters[k] = choice.counter_changes[k]
	if not other_counters.is_empty():
		parts.append("counters %s" % str(other_counters))
	if choice.approval_changes.size() > 1:
		var rest = choice.approval_changes.duplicate()
		rest.erase(choice.approval_changes.keys()[0])
		parts.append("more approval %s" % str(rest))
	if not choice.relationship_changes.is_empty():
		parts.append("relationship %s" % str(choice.relationship_changes))
	if choice.event_tag != &"":
		parts.append("event %s" % str(choice.event_tag))
	if choice.icon != null:
		parts.append("icon")
	if choice.bubble_color_override != Color.TRANSPARENT:
		parts.append("bubble colour")
	if choice.label_key != "" or choice.locked_hint_key != "":
		parts.append("localisation keys")
	return ", ".join(parts)

func _line_extras_summary(line: DialogueLine) -> String:
	var parts: Array[String] = []
	if line.event_tag != &"":
		parts.append("event_tag %s" % str(line.event_tag))
	if not line.set_flags.is_empty():
		parts.append("set_flags %s" % str(line.set_flags))
	if line.auto_advance:
		parts.append("auto_advance (%.2fs)" % line.auto_advance_delay)
	if line.text_speed_override != 0.0:
		parts.append("text speed %.1f" % line.text_speed_override)
	if line.text_key != "":
		parts.append("text_key")
	if line.sfx != null:
		parts.append("sfx")
	return ", ".join(parts)
