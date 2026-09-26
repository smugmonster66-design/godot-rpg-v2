@tool
extends RefCounted
class_name DialogueSerializer

# Preload required classes (not automatically available in @tool context)
const DialogueLineScript = preload("res://resources/data/dialogue_line.gd")
const DialogueChoiceScript = preload("res://resources/data/dialogue_choice.gd")
const DialogueEncounterScript = preload("res://resources/data/dialogue_encounter.gd")
const GameConditionScript = preload("res://resources/data/game_condition.gd")

# ============================================================================
# SERIALIZE GRAPH TO DIALOGUE ENCOUNTER
# ============================================================================

func serialize(graph: DialogueGraphEdit, speakers: Array[DialogueSpeaker]) -> DialogueEncounter:
	"""Convert the graph into a DialogueEncounter resource."""
	push_warning("[DialogueSerializer] === STARTING SERIALIZATION ===")
	var encounter = DialogueEncounterScript.new()
	
	# Add speakers
	encounter.speakers.assign(speakers)
	push_warning("[DialogueSerializer] Speakers: %d" % speakers.size())
	
	# Build node lookup
	var nodes = graph.get_all_nodes()
	var node_to_line: Dictionary = {}  # GraphNode -> DialogueLine
	var node_to_choices: Dictionary = {}  # ChoiceNode -> Array[DialogueChoice]
	var processed_nodes: Array = []  # Track processed nodes
	
	push_warning("[DialogueSerializer] Total nodes: %d" % nodes.size())
	
	# First pass: Create all DialogueLine resources
	push_warning("[DialogueSerializer] === FIRST PASS ===")
	for i in nodes.size():
		var node = nodes[i]
		push_warning("[DialogueSerializer] Processing node %d: %s" % [i, node.name])
		
		if not node.has_method("get_node_type"):
			push_warning("[DialogueSerializer]   No get_node_type method!")
			continue
			
		var node_type = node.get_node_type()
		push_warning("[DialogueSerializer]   Type: %s" % node_type)
		
		if node_type == "line":
			push_warning("[DialogueSerializer]   Getting node data...")
			var data = node.get_node_data()
			push_warning("[DialogueSerializer]   Data text: '%s'" % data.get("text", "N/A"))
			
			push_warning("[DialogueSerializer]   Creating line...")
			var line = _create_line_from_node(node)
			push_warning("[DialogueSerializer]   Line created: %s" % line)
			
			node_to_line[node] = line
			
		elif node_type == "choice":
			push_warning("[DialogueSerializer]   Creating choices...")
			var choices: Array[DialogueChoice] = []
			var node_data = node.get_node_data()
			for choice_data in node_data.get("choices", []):
				var choice = DialogueChoiceScript.new()
				choice.label = choice_data.get("label", "")
				# Moral weight → counter_changes
				var counter_changes = {}
				var virtue_val = choice_data.get("virtue", 0)
				var order_val = choice_data.get("order", 0)
				if virtue_val != 0:
					counter_changes[&"virtue"] = virtue_val
				if order_val != 0:
					counter_changes[&"order"] = order_val
				if not counter_changes.is_empty():
					choice.counter_changes = counter_changes
				# Approval → approval_changes
				var approval_npc = choice_data.get("approval_npc", "")
				var approval_val = choice_data.get("approval", 0)
				if approval_npc != "" and approval_val != 0:
					choice.approval_changes = {StringName(approval_npc): approval_val}
				# Per-choice condition
				var cond = _create_choice_condition(choice_data)
				if cond:
					choice.condition = cond
				choice.show_when_locked = choice_data.get("show_when_locked", false)
				var hint = choice_data.get("locked_hint", "")
				if hint != "":
					choice.locked_hint = hint
				choices.append(choice)
			node_to_choices[node] = choices
			push_warning("[DialogueSerializer]   Created %d choices" % choices.size())
	
	# Debug: Print all connections
	push_warning("[DialogueSerializer] === CONNECTIONS ===")
	var conns = graph.get_connection_list()
	push_warning("[DialogueSerializer] Connection count: %d" % conns.size())
	for conn in conns:
		push_warning("  %s:%d -> %s:%d" % [conn.from_node, conn.from_port, conn.to_node, conn.to_port])
	
	# Second pass: Wire up connections (recursively from start)
	push_warning("[DialogueSerializer] === SECOND PASS ===")
	var start_node = graph.get_start_node()
	push_warning("[DialogueSerializer] Start node: %s" % start_node)
	if start_node:
		var first_target = graph.get_connected_node(start_node, 0)
		push_warning("[DialogueSerializer] First target: %s" % first_target)
		if first_target:
			encounter.first_line = _process_node_chain(first_target, graph, node_to_line, node_to_choices, processed_nodes)
			push_warning("[DialogueSerializer] first_line: %s" % encounter.first_line)
	
	push_warning("[DialogueSerializer] === SERIALIZATION COMPLETE ===")
	return encounter

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
	
	var node_type = node.get_node_type() if node.has_method("get_node_type") else ""
	
	match node_type:
		"line":
			processed.append(node)
			var line = node_to_line.get(node) as DialogueLine
			if not line:
				return null
			
			# Get next node
			var next_node = graph.get_connected_node(node, 0)
			if next_node:
				var next_type = next_node.get_node_type() if next_node.has_method("get_node_type") else ""
				
				if next_type == "choice":
					# Wire choices
					line.choices.assign(_process_choice_node(next_node, graph, node_to_line, node_to_choices, processed))
				elif next_type == "end":
					line.next_line = null
				else:
					# Continue chain (could be another line, condition, or set_flag)
					line.next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)
			
			return line
		
		"condition":
			# Condition nodes branch - we need to create a line with condition
			processed.append(node)
			var node_data = node.get_node_data()
			
			# Get true and false branches
			var true_node = graph.get_connected_node(node, 1)  # Port 1 = true
			var false_node = graph.get_connected_node(node, 2)  # Port 2 = false
			
			var true_line = _process_node_chain(true_node, graph, node_to_line, node_to_choices, processed) if true_node else null
			var false_line = _process_node_chain(false_node, graph, node_to_line, node_to_choices, processed) if false_node else null
			
			# Create a branching line using choices with conditions
			var branch_line = DialogueLineScript.new()
			branch_line.text = ""  # Invisible/auto-advance
			branch_line.auto_advance = true
			branch_line.auto_advance_delay = 0.0
			
			# Create conditional choices
			var true_choice = DialogueChoiceScript.new()
			true_choice.label = ""  # Hidden
			true_choice.next_line = true_line
			true_choice.condition = _create_condition_resource(node_data)
			
			var false_choice = DialogueChoiceScript.new()
			false_choice.label = ""
			false_choice.next_line = false_line
			# No condition = always available (fallback)
			
			branch_line.choices.assign([true_choice, false_choice])
			
			# Store for potential re-use if multiple paths converge here
			node_to_line[node] = branch_line
			return branch_line
		
		"set_flag":
			# Set flag nodes modify state and continue
			processed.append(node)
			var node_data = node.get_node_data()
			
			# Create a line that sets flags
			var flag_line = DialogueLineScript.new()
			flag_line.text = ""
			flag_line.auto_advance = true
			flag_line.auto_advance_delay = 0.0
			
			# Set the flag via set_flags array
			var flag_name = node_data.get("flag_name", "")
			if flag_name != "":
				flag_line.set_flags.append(StringName(flag_name))
			
			# Store action info in event_tag for custom processing
			var action_type = node_data.get("action_type", 0)
			var value = node_data.get("value", 1)
			flag_line.event_tag = StringName("set_flag:%s:%d:%d" % [flag_name, action_type, value])
			
			# Store for potential re-use if multiple paths converge here
			node_to_line[node] = flag_line
			
			# Continue to next node
			var next_node = graph.get_connected_node(node, 0)
			if next_node:
				var next_type = next_node.get_node_type() if next_node.has_method("get_node_type") else ""
				if next_type == "choice":
					flag_line.choices.assign(_process_choice_node(next_node, graph, node_to_line, node_to_choices, processed))
				elif next_type == "end":
					flag_line.next_line = null
				else:
					flag_line.next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)

			return flag_line
		
		"game_action":
			# Game action nodes encode action into event_tag and pass through
			processed.append(node)
			var node_data = node.get_node_data()

			var action_line = DialogueLineScript.new()
			action_line.text = ""
			action_line.auto_advance = true
			action_line.auto_advance_delay = 0.0

			# Encode: "game_action:<type_int>:<payload>"
			var action_type = node_data.get("action_type", 0)
			var param = node_data.get("param", "")
			action_line.event_tag = StringName("game_action:%d:%s" % [action_type, param])

			# Store for potential re-use
			node_to_line[node] = action_line

			# Continue to next node — try port 0 first, then fallback
			var next_node = graph.get_connected_node(node, 0)
			if next_node == null:
				for conn in graph.get_connection_list():
					if str(conn.from_node) == str(node.name):
						next_node = graph.get_node_or_null(NodePath(str(conn.to_node)))
						break
			if next_node:
				var next_type = next_node.get_node_type() if next_node.has_method("get_node_type") else ""
				if next_type == "choice":
					# Wire choices directly onto the action line
					action_line.choices.assign(_process_choice_node(next_node, graph, node_to_line, node_to_choices, processed))
				elif next_type == "end":
					action_line.next_line = null
				else:
					action_line.next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)

			return action_line

		"end":
			return null

		_:
			return null

func _process_choice_node(
	node: GraphNode,
	graph: DialogueGraphEdit,
	node_to_line: Dictionary,
	node_to_choices: Dictionary,
	processed: Array
) -> Array[DialogueChoice]:
	"""Process a choice node and return its choices with wired next_lines."""
	processed.append(node)
	
	var choices = node_to_choices.get(node, []) as Array[DialogueChoice]
	var node_data = node.get_node_data()
	var choice_data_array = node_data.get("choices", [])
	
	for i in choices.size():
		# Choice outputs are on ports 0, 1, 2... (output ports indexed separately)
		var next_node = graph.get_connected_node(node, i)
		if next_node:
			choices[i].next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)
	
	return choices

func _create_line_from_node(node: GraphNode) -> DialogueLine:
	"""Create a DialogueLine from a Line GraphNode."""
	var line = DialogueLineScript.new()
	var data = node.get_node_data()
	
	line.speaker_id = data.get("speaker_id", &"")
	line.text = data.get("text", "")
	
	# Speaker's mood/bust for this line
	var bust_name = data.get("bust_name", "")
	if bust_name != "" and bust_name != "base":
		line.mood = StringName(bust_name)
	
	# Explicit bust slot assignments from the "Bust Slots" section
	var left_speaker = data.get("left_speaker", &"")
	var center_speaker = data.get("center_speaker", &"")
	var right_speaker = data.get("right_speaker", &"")
	
	if left_speaker != &"":
		line.set_left_bust = left_speaker
	if center_speaker != &"":
		line.set_center_bust = center_speaker
	if right_speaker != &"":
		line.set_right_bust = right_speaker
	
	# ALSO: If speaker is set with a slot position, set that bust slot
	# speaker_slot: 0=NONE, 1=LEFT, 2=CENTER, 3=RIGHT
	var speaker_slot = data.get("speaker_slot", 3)  # Default RIGHT
	if line.speaker_id != &"" and speaker_slot > 0:
		match speaker_slot:
			1:  # LEFT
				if line.set_left_bust == &"":
					line.set_left_bust = line.speaker_id
			2:  # CENTER
				if line.set_center_bust == &"":
					line.set_center_bust = line.speaker_id
			3:  # RIGHT
				if line.set_right_bust == &"":
					line.set_right_bust = line.speaker_id
	
	# Clear flags
	line.clear_left = data.get("clear_left", false)
	line.clear_center = data.get("clear_center", false)
	line.clear_right = data.get("clear_right", false)
	
	return line

func _create_condition_resource(node_data: Dictionary) -> GameCondition:
	"""Create a GameCondition resource from condition node data."""
	var condition_type = node_data.get("condition_type", 0)
	var flag_name = node_data.get("flag_name", "")
	var compare_value = node_data.get("compare_value", 0)
	var op = node_data.get("compare_operator", ">=")
	var p_expected = node_data.get("expected_bool", true)
	var quest_state_val = node_data.get("quest_state_value", "complete")
	var p_class_id = node_data.get("class_id", "")
	var p_objective_id = node_data.get("objective_id", "")
	var p_obj_check_mode = node_data.get("objective_check_mode", 0)

	# New enum: FLAG=0, COUNTER=1, RELATIONSHIP=2, HAS_ITEM=3, PLAYER_LEVEL=4,
	#           CLASS_LEVEL=5, QUEST_STATE=6, QUEST_OBJECTIVE=7, LOCATION_VISITED=8,
	#           APPROVAL=9
	match condition_type:
		0:  # FLAG
			if flag_name == "":
				return GameConditionScript.always_true()
			return GameConditionScript.flag(StringName(flag_name), p_expected)
		1:  # COUNTER
			if flag_name == "":
				return GameConditionScript.always_true()
			return GameConditionScript.counter_compare(StringName(flag_name), op, compare_value)
		2:  # RELATIONSHIP
			if flag_name == "":
				return GameConditionScript.always_true()
			return GameConditionScript.relationship(StringName(flag_name), op, compare_value)
		3:  # HAS_ITEM
			if flag_name == "":
				return GameConditionScript.always_true()
			var cond = GameConditionScript.has_item(StringName(flag_name), op, compare_value)
			if not p_expected:
				cond.invert = true
			return cond
		4:  # PLAYER_LEVEL
			return GameConditionScript.player_level(op, compare_value)
		5:  # CLASS_LEVEL
			if p_class_id == "":
				return GameConditionScript.always_true()
			return GameConditionScript.class_level(StringName(p_class_id), op, compare_value)
		6:  # QUEST_STATE
			if flag_name == "":
				return GameConditionScript.always_true()
			return GameConditionScript.quest_state(StringName(flag_name), quest_state_val)
		7:  # QUEST_OBJECTIVE
			if flag_name == "" or p_objective_id == "":
				return GameConditionScript.always_true()
			# ObjectiveCheckMode: IS_COMPLETE=0, IS_NOT_COMPLETE=1, PROGRESS_GTE=2, PROGRESS_LT=3, PROGRESS_EQ=4
			if p_obj_check_mode >= 2:
				# Progress comparison mode
				var progress_op = ">="
				match p_obj_check_mode:
					2: progress_op = ">="
					3: progress_op = "<"
					4: progress_op = "=="
				return GameConditionScript.quest_objective_progress(
					StringName(flag_name), StringName(p_objective_id), progress_op, compare_value)
			else:
				# Binary completion check
				var composite_key = "quest_objective:%s:%s" % [flag_name, p_objective_id]
				var cond = GameConditionScript.quest_objective(StringName(composite_key))
				if p_obj_check_mode == 1:  # IS_NOT_COMPLETE
					cond.invert = true
				return cond
		8:  # LOCATION_VISITED
			if flag_name == "":
				return GameConditionScript.always_true()
			var cond = GameConditionScript.location_visited(StringName(flag_name))
			if not p_expected:
				cond.invert = true
			return cond
		9:  # APPROVAL
			if flag_name == "":
				return GameConditionScript.always_true()
			return GameConditionScript.approval(StringName(flag_name), op, compare_value)

	return GameConditionScript.always_true()

func _create_choice_condition(choice_data: Dictionary) -> GameCondition:
	"""Create a GameCondition from inline per-choice condition data. Returns null for NONE."""
	# ChoiceCondType: NONE=0, FLAG=1, COUNTER=2, RELATIONSHIP=3, APPROVAL=4
	var cond_type = choice_data.get("cond_type", 0)
	if cond_type == 0:  # NONE
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
