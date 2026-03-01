@tool
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal issue_selected(node: GraphNode)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var issues_list: ItemList = $VBox/IssuesList
@onready var validate_button: Button = $VBox/ButtonRow/ValidateButton
@onready var status_label: Label = $VBox/StatusLabel

# ============================================================================
# STATE
# ============================================================================
var _graph: DialogueGraphEdit = null
var _speakers: Array[DialogueSpeaker] = []
var _issues: Array[Dictionary] = []  # [{node, severity, message}, ...]

enum Severity {
	ERROR,    # Will break dialogue
	WARNING,  # Might cause issues
	INFO,     # Suggestions
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if validate_button:
		validate_button.pressed.connect(_on_validate_pressed)
	if issues_list:
		issues_list.item_selected.connect(_on_issue_selected)
	
	_update_status()

func set_graph(graph: DialogueGraphEdit) -> void:
	_graph = graph

func set_speakers(speakers: Array[DialogueSpeaker]) -> void:
	_speakers = speakers

# ============================================================================
# VALIDATION
# ============================================================================

func _on_validate_pressed() -> void:
	validate()

func validate() -> void:
	_issues.clear()
	
	if not _graph:
		_add_issue(null, Severity.ERROR, "No graph to validate")
		_refresh_list()
		return
	
	var nodes = _graph.get_all_nodes()
	var connections = _graph.get_connection_list()
	
	# Check for start node
	var start_node = _graph.get_start_node()
	if not start_node:
		_add_issue(null, Severity.ERROR, "Missing START node")
	else:
		# Check start node has an output connection
		var start_connected = false
		for conn in connections:
			if conn.from_node == start_node.name:
				start_connected = true
				break
		if not start_connected:
			_add_issue(start_node, Severity.ERROR, "START node has no connection")
	
	# Check each node
	for node in nodes:
		_validate_node(node, connections)
	
	# Check for orphaned nodes (no input except start)
	for node in nodes:
		if node == start_node:
			continue
		
		var has_input = false
		for conn in connections:
			if conn.to_node == node.name:
				has_input = true
				break
		
		if not has_input:
			_add_issue(node, Severity.WARNING, "Node '%s' has no incoming connection (orphaned)" % node.name)
	
	# Check for at least one end node
	var end_nodes = _graph.get_nodes_by_type("end")
	if end_nodes.is_empty():
		_add_issue(null, Severity.WARNING, "No END nodes - dialogue may not terminate properly")
	
	_refresh_list()
	_update_status()

func _validate_node(node: GraphNode, connections: Array) -> void:
	var node_type = node.get_node_type() if node.has_method("get_node_type") else ""
	var data = node.get_node_data() if node.has_method("get_node_data") else {}
	
	match node_type:
		"line":
			_validate_line_node(node, data, connections)
		"choice":
			_validate_choice_node(node, data, connections)
		"condition":
			_validate_condition_node(node, data, connections)
		"set_flag":
			_validate_set_flag_node(node, data, connections)

func _validate_line_node(node: GraphNode, data: Dictionary, connections: Array) -> void:
	# Check for empty text
	var text = data.get("text", "")
	if text.strip_edges() == "":
		_add_issue(node, Severity.WARNING, "Line node '%s' has no dialogue text" % node.name)
	
	# Check speaker exists
	var speaker_id = data.get("speaker_id", &"")
	if speaker_id != &"" and speaker_id != &"narrator":
		var found = false
		for speaker in _speakers:
			if speaker.speaker_id == speaker_id:
				found = true
				break
		if not found:
			_add_issue(node, Severity.ERROR, "Line node '%s' references unknown speaker '%s'" % [node.name, speaker_id])
	
	# Check has output connection (unless it has choices)
	var has_output = false
	for conn in connections:
		if conn.from_node == node.name:
			has_output = true
			break
	if not has_output:
		_add_issue(node, Severity.WARNING, "Line node '%s' has no output connection (dead end)" % node.name)

func _validate_choice_node(node: GraphNode, data: Dictionary, connections: Array) -> void:
	var choices = data.get("choices", [])
	
	# Check has at least one choice
	if choices.is_empty():
		_add_issue(node, Severity.ERROR, "Choice node '%s' has no choices" % node.name)
		return
	
	# Check each choice has a label and connection
	for i in choices.size():
		var choice_data = choices[i]
		var label = choice_data.get("label", "")
		
		if label.strip_edges() == "":
			_add_issue(node, Severity.WARNING, "Choice %d in '%s' has no label" % [i + 1, node.name])
		
		# Check connection for this choice (port i+1)
		var has_connection = false
		for conn in connections:
			if conn.from_node == node.name and conn.from_port == i + 1:
				has_connection = true
				break
		if not has_connection:
			_add_issue(node, Severity.WARNING, "Choice %d '%s' in '%s' has no connection" % [i + 1, label, node.name])

func _validate_condition_node(node: GraphNode, data: Dictionary, connections: Array) -> void:
	var flag_name = data.get("flag_name", "")
	
	# Check flag name is set
	if flag_name.strip_edges() == "":
		_add_issue(node, Severity.ERROR, "Condition node '%s' has no flag/counter name" % node.name)
	
	# Check both outputs have connections
	var has_true = false
	var has_false = false
	for conn in connections:
		if conn.from_node == node.name:
			if conn.from_port == 1:
				has_true = true
			elif conn.from_port == 2:
				has_false = true
	
	if not has_true:
		_add_issue(node, Severity.WARNING, "Condition '%s' True branch has no connection" % node.name)
	if not has_false:
		_add_issue(node, Severity.WARNING, "Condition '%s' False branch has no connection" % node.name)

func _validate_set_flag_node(node: GraphNode, data: Dictionary, connections: Array) -> void:
	var flag_name = data.get("flag_name", "")
	
	# Check flag name is set
	if flag_name.strip_edges() == "":
		_add_issue(node, Severity.ERROR, "Set Flag node '%s' has no flag/counter name" % node.name)
	
	# Check has output connection
	var has_output = false
	for conn in connections:
		if conn.from_node == node.name:
			has_output = true
			break
	if not has_output:
		_add_issue(node, Severity.WARNING, "Set Flag node '%s' has no output connection" % node.name)

# ============================================================================
# ISSUE MANAGEMENT
# ============================================================================

func _add_issue(node: GraphNode, severity: Severity, message: String) -> void:
	_issues.append({
		"node": node,
		"severity": severity,
		"message": message,
	})

func _refresh_list() -> void:
	if not issues_list:
		return
	
	issues_list.clear()
	
	for issue in _issues:
		var prefix = ""
		var color = Color.WHITE
		match issue.severity:
			Severity.ERROR:
				prefix = "❌ "
				color = Color(1.0, 0.4, 0.4)
			Severity.WARNING:
				prefix = "⚠️ "
				color = Color(1.0, 0.8, 0.3)
			Severity.INFO:
				prefix = "ℹ️ "
				color = Color(0.5, 0.7, 1.0)
		
		var idx = issues_list.add_item(prefix + issue.message)
		issues_list.set_item_custom_fg_color(idx, color)

func _update_status() -> void:
	if not status_label:
		return
	
	var error_count = 0
	var warning_count = 0
	
	for issue in _issues:
		match issue.severity:
			Severity.ERROR:
				error_count += 1
			Severity.WARNING:
				warning_count += 1
	
	if _issues.is_empty():
		status_label.text = "✓ No issues found"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif error_count > 0:
		status_label.text = "%d errors, %d warnings" % [error_count, warning_count]
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		status_label.text = "%d warnings" % warning_count
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

func _on_issue_selected(index: int) -> void:
	if index < 0 or index >= _issues.size():
		return
	
	var issue = _issues[index]
	var node = issue.get("node")
	if node:
		node.selected = true
		issue_selected.emit(node)

# ============================================================================
# PUBLIC
# ============================================================================

func get_error_count() -> int:
	var count = 0
	for issue in _issues:
		if issue.severity == Severity.ERROR:
			count += 1
	return count

func has_errors() -> bool:
	return get_error_count() > 0
