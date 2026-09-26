@tool
extends RefCounted
class_name DialogueDeserializer

# ============================================================================
# DESERIALIZE DIALOGUE ENCOUNTER TO GRAPH
# ============================================================================

func deserialize(encounter: DialogueEncounter, graph: DialogueGraphEdit, speakers_panel: Control) -> void:
	"""Load a DialogueEncounter into the graph editor."""
	push_warning("[Deserializer] === STARTING DESERIALIZE ===")
	push_warning("[Deserializer] encounter: %s" % encounter)
	push_warning("[Deserializer] encounter.first_line: %s" % encounter.first_line)
	if encounter.first_line:
		push_warning("[Deserializer] first_line.text: '%s'" % encounter.first_line.text)
		push_warning("[Deserializer] first_line.choices: %s" % encounter.first_line.choices)
		push_warning("[Deserializer] first_line.choices.size(): %d" % encounter.first_line.choices.size())
	
	# Clear existing
	graph.clear_graph()
	speakers_panel.clear_speakers()
	
	# Load speakers
	for speaker in encounter.speakers:
		speakers_panel.add_speaker(speaker)
	
	# Update graph with speakers
	graph.set_available_speakers(speakers_panel.get_speakers())
	
	# Create start node
	var start_node = graph.add_start_node(Vector2(100, 200))
	
	# Track created nodes to wire connections
	var line_to_node: Dictionary = {}  # DialogueLine -> GraphNode
	var processed_lines: Array = []
	
	# Recursively process from first line
	if encounter.first_line:
		_process_line(encounter.first_line, graph, line_to_node, processed_lines, Vector2(350, 200))
	
	# Wire start node to first line
	if encounter.first_line and line_to_node.has(encounter.first_line):
		var first_node = line_to_node[encounter.first_line]
		graph.connect_node(start_node.name, 0, first_node.name, 0)
	
	push_warning("[Deserializer] === DESERIALIZE COMPLETE ===")

func _process_line(
	line: DialogueLine,
	graph: DialogueGraphEdit,
	line_to_node: Dictionary,
	processed_lines: Array,
	position: Vector2
) -> GraphNode:
	"""Process a DialogueLine and its children recursively."""
	push_warning("[Deserializer] _process_line: '%s'" % line.text)
	push_warning("[Deserializer]   choices.size(): %d" % line.choices.size())
	
	# Avoid infinite loops
	if line in processed_lines:
		push_warning("[Deserializer]   Already processed, returning existing node")
		return line_to_node.get(line)
	processed_lines.append(line)
	
	# Check if this is a "system" line (condition branch or set_flag)
	if line.text == "" and line.auto_advance:
		# Check for set_flag event
		if str(line.event_tag).begins_with("set_flag:"):
			return _create_set_flag_node(line, graph, line_to_node, processed_lines, position)
		elif str(line.event_tag).begins_with("game_action:"):
			return _create_action_node(line, graph, line_to_node, processed_lines, position)
		# Check for condition (has choices with conditions)
		elif line.choices.size() >= 2 and line.choices[0].condition != null:
			return _create_condition_node(line, graph, line_to_node, processed_lines, position)
	
	# Create the line node
	push_warning("[Deserializer]   Creating line node...")
	var node = graph.add_line_node(position)
	push_warning("[Deserializer]   Line node created: %s" % node.name)
	line_to_node[line] = node
	
	# Set line data
	var data = {
		"speaker_id": line.speaker_id,
		"bust_name": str(line.mood) if line.mood != &"" else "base",
		"text": line.text,
		"left_speaker": line.set_left_bust,  # set_*_bust IS the speaker ID
		"left_bust": "",
		"center_speaker": line.set_center_bust,
		"center_bust": "",
		"right_speaker": line.set_right_bust,
		"right_bust": "",
		"clear_left": line.clear_left,
		"clear_center": line.clear_center,
		"clear_right": line.clear_right,
	}
	node.set_node_data(data)
	push_warning("[Deserializer]   Line node data set")
	
	# Calculate next position
	var next_pos = position + Vector2(400, 0)
	
	# Handle choices - use direct property access, not method calls (methods may not work in @tool)
	if line.choices.size() > 0:
		push_warning("[Deserializer]   HAS CHOICES! Creating choice node...")
		# Create a choice node
		var choice_node = graph.add_choice_node(next_pos)
		push_warning("[Deserializer]   Choice node created: %s" % choice_node.name)
		
		# Connect line to choice node
		graph.connect_node(node.name, 0, choice_node.name, 0)
		push_warning("[Deserializer]   Connected line to choice node")
		
		# Set up choices and their connections
		var choice_data = {"choices": []}
		var y_offset = 0
		
		for i in line.choices.size():
			var choice = line.choices[i]
			push_warning("[Deserializer]   Processing choice %d: '%s'" % [i, choice.label])
			choice_data.choices.append(_build_choice_dict(choice))
			
			# Process choice's next_line
			if choice.next_line:
				push_warning("[Deserializer]     Choice has next_line, processing...")
				var choice_next_pos = next_pos + Vector2(400, y_offset)
				var next_node = _process_line(choice.next_line, graph, line_to_node, processed_lines, choice_next_pos)
				if next_node:
					graph.connect_node(choice_node.name, i, next_node.name, 0)
					push_warning("[Deserializer]     Connected choice %d to node %s" % [i, next_node.name])
			else:
				# Choice leads to end
				push_warning("[Deserializer]     Choice has no next_line, adding END")
				var end_node = graph.add_end_node(next_pos + Vector2(400, y_offset))
				graph.connect_node(choice_node.name, i, end_node.name, 0)
			
			y_offset += 150
		
		choice_node.set_node_data(choice_data)
		push_warning("[Deserializer]   Choice node data set")
	
	elif line.next_line:
		# Simple continuation
		push_warning("[Deserializer]   Has next_line, processing continuation...")
		var next_node = _process_line(line.next_line, graph, line_to_node, processed_lines, next_pos)
		if next_node:
			graph.connect_node(node.name, 0, next_node.name, 0)
	
	else:
		# End of branch
		push_warning("[Deserializer]   No choices or next_line, adding END node")
		var end_node = graph.add_end_node(next_pos)
		graph.connect_node(node.name, 0, end_node.name, 0)
	
	push_warning("[Deserializer]   _process_line complete for '%s'" % line.text)
	return node

func _create_condition_node(
	line: DialogueLine,
	graph: DialogueGraphEdit,
	line_to_node: Dictionary,
	processed_lines: Array,
	position: Vector2
) -> GraphNode:
	"""Create a condition node from a branching line."""
	var node = graph.add_condition_node(position)
	line_to_node[line] = node
	
	# Try to extract condition info from the first choice's condition
	var condition = line.choices[0].condition
	if condition:
		var data = _parse_condition(condition)
		node.set_node_data(data)
	
	# Wire true branch (first choice)
	var true_line = line.choices[0].next_line if line.choices.size() > 0 else null
	var false_line = line.choices[1].next_line if line.choices.size() > 1 else null
	
	var next_pos = position + Vector2(350, 0)
	
	if true_line:
		var true_node = _process_line(true_line, graph, line_to_node, processed_lines, next_pos + Vector2(0, -100))
		if true_node:
			graph.connect_node(node.name, 1, true_node.name, 0)
	else:
		var end_node = graph.add_end_node(next_pos + Vector2(0, -100))
		graph.connect_node(node.name, 1, end_node.name, 0)
	
	if false_line:
		var false_node = _process_line(false_line, graph, line_to_node, processed_lines, next_pos + Vector2(0, 100))
		if false_node:
			graph.connect_node(node.name, 2, false_node.name, 0)
	else:
		var end_node = graph.add_end_node(next_pos + Vector2(0, 100))
		graph.connect_node(node.name, 2, end_node.name, 0)
	
	return node

func _create_set_flag_node(
	line: DialogueLine,
	graph: DialogueGraphEdit,
	line_to_node: Dictionary,
	processed_lines: Array,
	position: Vector2
) -> GraphNode:
	"""Create a set flag node from a system line."""
	var node = graph.add_set_flag_node(position)
	line_to_node[line] = node
	
	# Parse event_tag: "set_flag:flag_name:action_type:value"
	var parts = str(line.event_tag).split(":")
	if parts.size() >= 4:
		var data = {
			"flag_name": parts[1],
			"action_type": int(parts[2]),
			"value": int(parts[3]),
		}
		node.set_node_data(data)
	
	# Wire to next — set_flag lines may use next_line OR choices
	var next_pos = position + Vector2(300, 0)
	if line.choices.size() > 0:
		var choice_node = graph.add_choice_node(next_pos)
		graph.connect_node(node.name, 0, choice_node.name, 0)
		var choice_data = {"choices": []}
		var y_offset = 0
		for i in line.choices.size():
			var choice = line.choices[i]
			choice_data.choices.append(_build_choice_dict(choice))
			if choice.next_line:
				var choice_next_pos = next_pos + Vector2(400, y_offset)
				var next_node = _process_line(choice.next_line, graph, line_to_node, processed_lines, choice_next_pos)
				if next_node:
					graph.connect_node(choice_node.name, i, next_node.name, 0)
			else:
				var end_node = graph.add_end_node(next_pos + Vector2(400, y_offset))
				graph.connect_node(choice_node.name, i, end_node.name, 0)
			y_offset += 150
		choice_node.set_node_data(choice_data)
	elif line.next_line:
		var next_node = _process_line(line.next_line, graph, line_to_node, processed_lines, next_pos)
		if next_node:
			graph.connect_node(node.name, 0, next_node.name, 0)
	else:
		var end_node = graph.add_end_node(next_pos)
		graph.connect_node(node.name, 0, end_node.name, 0)

	return node

func _create_action_node(
	line: DialogueLine,
	graph: DialogueGraphEdit,
	line_to_node: Dictionary,
	processed_lines: Array,
	position: Vector2
) -> GraphNode:
	"""Create an action node from a system line with game_action event_tag."""
	var node = graph.add_action_node(position)
	line_to_node[line] = node

	# Parse event_tag: "game_action:<type_int>:<param>"
	var tag_str = str(line.event_tag)
	var first_colon = tag_str.find(":")
	var second_colon = tag_str.find(":", first_colon + 1)
	if first_colon >= 0 and second_colon >= 0:
		var action_type = int(tag_str.substr(first_colon + 1, second_colon - first_colon - 1))
		var param = tag_str.substr(second_colon + 1)
		var data = {
			"action_type": action_type,
			"param": param,
		}
		node.set_node_data(data)

	# Wire to next — action lines may use next_line OR choices
	var next_pos = position + Vector2(300, 0)
	if line.choices.size() > 0:
		# Action line with choices (e.g. auto_advance event followed by player choices)
		var choice_node = graph.add_choice_node(next_pos)
		graph.connect_node(node.name, 0, choice_node.name, 0)
		var choice_data = {"choices": []}
		var y_offset = 0
		for i in line.choices.size():
			var choice = line.choices[i]
			choice_data.choices.append(_build_choice_dict(choice))
			if choice.next_line:
				var choice_next_pos = next_pos + Vector2(400, y_offset)
				var next_node = _process_line(choice.next_line, graph, line_to_node, processed_lines, choice_next_pos)
				if next_node:
					graph.connect_node(choice_node.name, i, next_node.name, 0)
			else:
				var end_node = graph.add_end_node(next_pos + Vector2(400, y_offset))
				graph.connect_node(choice_node.name, i, end_node.name, 0)
			y_offset += 150
		choice_node.set_node_data(choice_data)
	elif line.next_line:
		var next_node = _process_line(line.next_line, graph, line_to_node, processed_lines, next_pos)
		if next_node:
			graph.connect_node(node.name, 0, next_node.name, 0)
	else:
		var end_node = graph.add_end_node(next_pos)
		graph.connect_node(node.name, 0, end_node.name, 0)

	return node

func _build_choice_dict(choice) -> Dictionary:
	"""Build a choice node data dict from a DialogueChoice resource."""
	var appr_npc = ""
	var appr_val = 0
	if not choice.approval_changes.is_empty():
		appr_npc = str(choice.approval_changes.keys()[0])
		appr_val = choice.approval_changes.values()[0]

	var d = {
		"label": choice.label,
		"virtue": choice.counter_changes.get(&"virtue", 0),
		"order": choice.counter_changes.get(&"order", 0),
		"approval_npc": appr_npc,
		"approval": appr_val,
	}

	# Merge inline condition fields
	var cond_fields = _parse_choice_condition(choice)
	d.merge(cond_fields)
	return d

func _parse_condition(condition: Resource) -> Dictionary:
	"""Reverse-map a GameCondition resource back to condition node data."""
	# New enum: FLAG=0, COUNTER=1, RELATIONSHIP=2, HAS_ITEM=3, PLAYER_LEVEL=4,
	#           CLASS_LEVEL=5, QUEST_STATE=6, QUEST_OBJECTIVE=7, LOCATION_VISITED=8,
	#           APPROVAL=9
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

	# Must be a SINGLE condition (condition_type == 2 in the enum)
	if condition.condition_type != 2:  # GameCondition.ConditionType.SINGLE
		return data

	var check = condition.single_check
	if check == null:
		return data

	var is_inverted: bool = condition.invert

	data.flag_name = str(check.key)
	data.compare_value = check.int_value
	data.compare_operator = check.compare_operator

	# Map SingleCheck.CheckType back to ConditionNode.ConditionType
	match check.check_type:
		0:  # FLAG
			data.condition_type = 0  # FLAG
			data.expected_bool = check.bool_value
		1:  # COUNTER
			data.condition_type = 1  # COUNTER
		2:  # RELATIONSHIP
			data.condition_type = 2  # RELATIONSHIP
		3:  # HAS_ITEM
			data.condition_type = 3  # HAS_ITEM
			data.expected_bool = not is_inverted
		4:  # PLAYER_LEVEL
			data.condition_type = 4  # PLAYER_LEVEL
		5:  # CLASS_LEVEL
			data.condition_type = 5  # CLASS_LEVEL
			data.class_id = str(check.class_id)
		6:  # QUEST_STATE
			data.condition_type = 6  # QUEST_STATE
			data.quest_state_value = check.quest_state
		7:  # LOCATION_VISITED
			data.condition_type = 8  # LOCATION_VISITED
			data.expected_bool = not is_inverted
		8:  # APPROVAL
			data.condition_type = 9  # APPROVAL
		9:  # CUSTOM
			var key_str = str(check.key)
			if key_str.begins_with("quest_objective_progress:"):
				# Progress check: key = "quest_objective_progress:quest_id:obj_id:op:value"
				data.condition_type = 7  # QUEST_OBJECTIVE
				var parts = key_str.split(":")
				if parts.size() >= 5:
					data.flag_name = parts[1]
					data.objective_id = parts[2]
					var op = parts[3]
					data.compare_value = int(parts[4])
					# ObjectiveCheckMode: PROGRESS_GTE=2, PROGRESS_LT=3, PROGRESS_EQ=4
					match op:
						">=": data.objective_check_mode = 2
						"<":  data.objective_check_mode = 3
						"==": data.objective_check_mode = 4
						_:    data.objective_check_mode = 2
			elif key_str.begins_with("quest_objective:"):
				# Binary completion check
				data.condition_type = 7  # QUEST_OBJECTIVE
				# ObjectiveCheckMode: IS_COMPLETE=0, IS_NOT_COMPLETE=1
				data.objective_check_mode = 1 if is_inverted else 0
				var parts = key_str.split(":")
				if parts.size() >= 3:
					data.flag_name = parts[1]
					data.objective_id = parts[2]

	return data

func _parse_choice_condition(choice) -> Dictionary:
	"""Reverse-map a DialogueChoice's condition to inline condition fields."""
	# ChoiceCondType: NONE=0, FLAG=1, COUNTER=2, RELATIONSHIP=3, APPROVAL=4
	var result = {
		"cond_type": 0,
		"cond_key": "",
		"cond_op": ">=",
		"cond_value": 0,
		"cond_bool": true,
		"show_when_locked": choice.show_when_locked,
		"locked_hint": choice.locked_hint,
	}

	if choice.condition == null:
		return result

	# Must be a SINGLE condition
	if choice.condition.condition_type != 2:  # GameCondition.ConditionType.SINGLE
		return result

	var check = choice.condition.single_check
	if check == null:
		return result

	result.cond_key = str(check.key)
	result.cond_op = check.compare_operator
	result.cond_value = check.int_value

	# SingleCheck.CheckType: FLAG=0, COUNTER=1, RELATIONSHIP=2, ..., APPROVAL=8
	match check.check_type:
		0:  # FLAG
			result.cond_type = 1  # ChoiceCondType.FLAG
			result.cond_bool = check.bool_value
		1:  # COUNTER
			result.cond_type = 2  # ChoiceCondType.COUNTER
		2:  # RELATIONSHIP
			result.cond_type = 3  # ChoiceCondType.RELATIONSHIP
		8:  # APPROVAL
			result.cond_type = 4  # ChoiceCondType.APPROVAL

	return result
