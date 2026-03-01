@tool
extends RefCounted
class_name DialogueDeserializer

# ============================================================================
# DESERIALIZE DIALOGUE ENCOUNTER TO GRAPH
# ============================================================================

func deserialize(encounter: DialogueEncounter, graph: DialogueGraphEdit, speakers_panel: Control) -> void:
	"""Load a DialogueEncounter into the graph editor."""
	
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

func _process_line(
	line: DialogueLine,
	graph: DialogueGraphEdit,
	line_to_node: Dictionary,
	processed_lines: Array,
	position: Vector2
) -> GraphNode:
	"""Process a DialogueLine and its children recursively."""
	
	# Avoid infinite loops
	if line in processed_lines:
		return line_to_node.get(line)
	processed_lines.append(line)
	
	# Check if this is a "system" line (condition branch or set_flag)
	if line.text == "" and line.auto_advance:
		# Check for set_flag event
		if str(line.event_tag).begins_with("set_flag:"):
			return _create_set_flag_node(line, graph, line_to_node, processed_lines, position)
		# Check for condition (has choices with conditions)
		elif line.choices.size() >= 2 and line.choices[0].condition != null:
			return _create_condition_node(line, graph, line_to_node, processed_lines, position)
	
	# Create the line node
	var node = graph.add_line_node(position)
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
	
	# Calculate next position
	var next_pos = position + Vector2(400, 0)
	
	# Handle choices
	if line.has_choices():
		# Create a choice node
		var choice_node = graph.add_choice_node(next_pos)
		
		# Connect line to choice node
		graph.connect_node(node.name, 0, choice_node.name, 0)
		
		# Set up choices and their connections
		var choice_data = {"choices": []}
		var y_offset = 0
		
		for i in line.choices.size():
			var choice = line.choices[i]
			choice_data.choices.append({"label": choice.label})
			
			# Process choice's next_line
			if choice.next_line:
				var choice_next_pos = next_pos + Vector2(400, y_offset)
				var next_node = _process_line(choice.next_line, graph, line_to_node, processed_lines, choice_next_pos)
				if next_node:
					graph.connect_node(choice_node.name, i + 1, next_node.name, 0)
			else:
				# Choice leads to end
				var end_node = graph.add_end_node(next_pos + Vector2(400, y_offset))
				graph.connect_node(choice_node.name, i + 1, end_node.name, 0)
			
			y_offset += 150
		
		choice_node.set_node_data(choice_data)
	
	elif line.next_line:
		# Simple continuation
		var next_node = _process_line(line.next_line, graph, line_to_node, processed_lines, next_pos)
		if next_node:
			graph.connect_node(node.name, 0, next_node.name, 0)
	
	else:
		# End of branch
		var end_node = graph.add_end_node(next_pos)
		graph.connect_node(node.name, 0, end_node.name, 0)
	
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
	
	# Wire to next
	var next_pos = position + Vector2(300, 0)
	if line.next_line:
		var next_node = _process_line(line.next_line, graph, line_to_node, processed_lines, next_pos)
		if next_node:
			graph.connect_node(node.name, 0, next_node.name, 0)
	else:
		var end_node = graph.add_end_node(next_pos)
		graph.connect_node(node.name, 0, end_node.name, 0)
	
	return node

func _parse_condition(condition: Resource) -> Dictionary:
	"""Try to extract condition info from a GameCondition resource."""
	var data = {
		"condition_type": 0,
		"flag_name": "",
		"compare_value": 0,
	}
	
	# This is tricky since GameCondition might not expose its internals
	# For now, just return defaults
	# TODO: Add inspection methods to GameCondition
	
	return data
