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
	if not node or node in processed:
		return null
	
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
			
			# Continue to next node
			var next_node = graph.get_connected_node(node, 0)
			if next_node:
				flag_line.next_line = _process_node_chain(next_node, graph, node_to_line, node_to_choices, processed)
			
			return flag_line
		
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
		# Choice outputs are on ports 1, 2, 3... (port 0 is input)
		var next_node = graph.get_connected_node(node, i + 1)
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
	
	if flag_name == "":
		return GameConditionScript.always_true()
	
	match condition_type:
		0:  # FLAG_SET
			return GameConditionScript.flag(StringName(flag_name), true)
		1:  # FLAG_NOT_SET
			return GameConditionScript.flag(StringName(flag_name), false)
		2:  # COUNTER_AT_LEAST
			return GameConditionScript.counter_at_least(StringName(flag_name), compare_value)
		3:  # COUNTER_LESS_THAN
			return _create_counter_less_than(StringName(flag_name), compare_value)
		4:  # COUNTER_EQUALS
			return _create_counter_equals(StringName(flag_name), compare_value)
	
	return GameConditionScript.always_true()

func _create_counter_less_than(counter_name: StringName, maximum: int) -> GameCondition:
	"""Create a counter < value condition manually."""
	var c = GameConditionScript.new()
	c.condition_type = GameConditionScript.ConditionType.SINGLE
	c.single_check = GameConditionScript.SingleCheck.new()
	c.single_check.check_type = GameConditionScript.SingleCheck.CheckType.COUNTER
	c.single_check.key = counter_name
	c.single_check.compare_operator = "<"
	c.single_check.int_value = maximum
	return c

func _create_counter_equals(counter_name: StringName, value: int) -> GameCondition:
	"""Create a counter == value condition manually."""
	var c = GameConditionScript.new()
	c.condition_type = GameConditionScript.ConditionType.SINGLE
	c.single_check = GameConditionScript.SingleCheck.new()
	c.single_check.check_type = GameConditionScript.SingleCheck.CheckType.COUNTER
	c.single_check.key = counter_name
	c.single_check.compare_operator = "=="
	c.single_check.int_value = value
	return c
