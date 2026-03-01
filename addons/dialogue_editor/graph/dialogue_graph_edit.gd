@tool
extends GraphEdit
class_name DialogueGraphEdit

# ============================================================================
# SIGNALS
# ============================================================================
signal modified
signal dialogue_node_selected(node: GraphNode)

# ============================================================================
# PRELOADS
# ============================================================================
const StartNode = preload("res://addons/dialogue_editor/nodes/start_node.tscn")
const LineNode = preload("res://addons/dialogue_editor/nodes/line_node.tscn")
const ChoiceNode = preload("res://addons/dialogue_editor/nodes/choice_node.tscn")
const ConditionNode = preload("res://addons/dialogue_editor/nodes/condition_node.tscn")
const SetFlagNode = preload("res://addons/dialogue_editor/nodes/set_flag_node.tscn")
const EndNode = preload("res://addons/dialogue_editor/nodes/end_node.tscn")

# ============================================================================
# STATE
# ============================================================================
var _node_counter: int = 0
var _start_node: GraphNode = null
var _available_speakers: Array[DialogueSpeaker] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Configure GraphEdit
	right_disconnects = true
	show_grid = true
	snapping_enabled = true
	snapping_distance = 20
	minimap_enabled = true
	minimap_size = Vector2(200, 150)
	minimap_opacity = 0.65
	
	# Connect signals
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	node_selected.connect(_on_node_selected)
	
	# Setup valid connection types
	# Type 0 = Flow (single output to single input)
	# Type 1 = Choice/Condition (multiple outputs)
	add_valid_connection_type(0, 0)
	add_valid_connection_type(1, 0)
	
	print("[DialogueGraph] Ready")

# ============================================================================
# SPEAKER MANAGEMENT
# ============================================================================

func set_available_speakers(speakers: Array[DialogueSpeaker]) -> void:
	_available_speakers = speakers
	# Update all line nodes
	for node in get_all_nodes():
		if node.has_method("set_available_speakers"):
			node.set_available_speakers(speakers)

# ============================================================================
# NODE CREATION
# ============================================================================

func add_start_node(at_position: Vector2 = Vector2(100, 200)) -> GraphNode:
	if _start_node and is_instance_valid(_start_node):
		push_warning("[DialogueGraph] Start node already exists")
		return _start_node
	
	var node = StartNode.instantiate()
	node.name = "StartNode"
	node.position_offset = at_position
	add_child(node)
	_start_node = node
	_connect_node_signals(node)
	return node

func add_line_node(at_position: Vector2 = Vector2.ZERO) -> GraphNode:
	if at_position == Vector2.ZERO:
		at_position = _get_center_position()
	
	var node = LineNode.instantiate()
	node.name = "LineNode_%d" % _node_counter
	_node_counter += 1
	node.position_offset = at_position
	add_child(node)
	_connect_node_signals(node)
	
	# Give it available speakers
	if node.has_method("set_available_speakers"):
		node.set_available_speakers(_available_speakers)
	
	modified.emit()
	return node

func add_choice_node(at_position: Vector2 = Vector2.ZERO) -> GraphNode:
	if at_position == Vector2.ZERO:
		at_position = _get_center_position()
	
	var node = ChoiceNode.instantiate()
	node.name = "ChoiceNode_%d" % _node_counter
	_node_counter += 1
	node.position_offset = at_position
	add_child(node)
	_connect_node_signals(node)
	modified.emit()
	return node

func add_condition_node(at_position: Vector2 = Vector2.ZERO) -> GraphNode:
	if at_position == Vector2.ZERO:
		at_position = _get_center_position()
	
	var node = ConditionNode.instantiate()
	node.name = "ConditionNode_%d" % _node_counter
	_node_counter += 1
	node.position_offset = at_position
	add_child(node)
	_connect_node_signals(node)
	modified.emit()
	return node

func add_set_flag_node(at_position: Vector2 = Vector2.ZERO) -> GraphNode:
	if at_position == Vector2.ZERO:
		at_position = _get_center_position()
	
	var node = SetFlagNode.instantiate()
	node.name = "SetFlagNode_%d" % _node_counter
	_node_counter += 1
	node.position_offset = at_position
	add_child(node)
	_connect_node_signals(node)
	modified.emit()
	return node

func add_end_node(at_position: Vector2 = Vector2.ZERO) -> GraphNode:
	if at_position == Vector2.ZERO:
		at_position = _get_center_position()
	
	var node = EndNode.instantiate()
	node.name = "EndNode_%d" % _node_counter
	_node_counter += 1
	node.position_offset = at_position
	add_child(node)
	_connect_node_signals(node)
	modified.emit()
	return node

func _connect_node_signals(node: GraphNode) -> void:
	if node.has_signal("modified"):
		node.modified.connect(_on_node_modified)
	node.position_offset_changed.connect(_on_node_moved)

func _get_center_position() -> Vector2:
	return (scroll_offset + size / 2) / zoom

# ============================================================================
# GRAPH OPERATIONS
# ============================================================================

func clear_graph() -> void:
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	_start_node = null
	_node_counter = 0

func delete_selected_nodes() -> void:
	var to_delete: Array[GraphNode] = []
	for child in get_children():
		if child is GraphNode and child.selected:
			# Don't allow deleting the start node
			if child == _start_node:
				continue
			to_delete.append(child)
	
	for node in to_delete:
		_remove_connections_for_node(node)
		node.queue_free()
	
	if to_delete.size() > 0:
		modified.emit()

func select_all_nodes() -> void:
	for child in get_children():
		if child is GraphNode:
			child.selected = true

func _remove_connections_for_node(node: GraphNode) -> void:
	var connections_to_remove: Array = []
	for conn in get_connection_list():
		if conn.from_node == node.name or conn.to_node == node.name:
			connections_to_remove.append(conn)
	
	for conn in connections_to_remove:
		disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)

# ============================================================================
# CONNECTION HANDLING
# ============================================================================

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Prevent connecting to self
	if from_node == to_node:
		return
	
	# Prevent connecting to start node's input (it has no input)
	var target = get_node_or_null(NodePath(to_node))
	if target == _start_node:
		return
	
	# Check if this output already has a connection (for single-output nodes)
	var source = get_node_or_null(NodePath(from_node))
	if source and not (source.has_method("is_multi_output") and source.is_multi_output()):
		# Single output - disconnect existing
		for conn in get_connection_list():
			if conn.from_node == from_node and conn.from_port == from_port:
				disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
				break
	
	connect_node(from_node, from_port, to_node, to_port)
	modified.emit()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)
	modified.emit()

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node = get_node_or_null(NodePath(node_name))
		if node and node != _start_node:
			_remove_connections_for_node(node)
			node.queue_free()
	modified.emit()

func _on_node_selected(node: GraphNode) -> void:
	dialogue_node_selected.emit(node)

func _on_node_modified() -> void:
	modified.emit()

func _on_node_moved() -> void:
	modified.emit()

# ============================================================================
# QUERIES
# ============================================================================

func get_start_node() -> GraphNode:
	return _start_node

func get_all_nodes() -> Array[GraphNode]:
	var nodes: Array[GraphNode] = []
	for child in get_children():
		if child is GraphNode:
			nodes.append(child)
	return nodes

func get_nodes_by_type(type_name: String) -> Array[GraphNode]:
	var nodes: Array[GraphNode] = []
	for child in get_children():
		if child is GraphNode and child.has_method("get_node_type"):
			if child.get_node_type() == type_name:
				nodes.append(child)
	return nodes

func get_connected_node(from_node: GraphNode, from_port: int) -> GraphNode:
	"""Get the node connected to a specific output port."""
	for conn in get_connection_list():
		if conn.from_node == from_node.name and conn.from_port == from_port:
			return get_node_or_null(NodePath(conn.to_node))
	return null

func get_incoming_node(to_node: GraphNode, to_port: int = 0) -> GraphNode:
	"""Get the node connected to a specific input port."""
	for conn in get_connection_list():
		if conn.to_node == to_node.name and conn.to_port == to_port:
			return get_node_or_null(NodePath(conn.from_node))
	return null

# ============================================================================
# CONTEXT MENU
# ============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_show_add_node_popup(event.position)

func _show_add_node_popup(at_position: Vector2) -> void:
	var popup = PopupMenu.new()
	popup.add_item("Add Line Node", 0)
	popup.add_item("Add Choice Node", 1)
	popup.add_separator()
	popup.add_item("Add Condition Node", 2)
	popup.add_item("Add Set Flag Node", 3)
	popup.add_separator()
	popup.add_item("Add End Node", 4)
	popup.id_pressed.connect(func(id):
		var graph_pos = (scroll_offset + at_position) / zoom
		match id:
			0: add_line_node(graph_pos)
			1: add_choice_node(graph_pos)
			2: add_condition_node(graph_pos)
			3: add_set_flag_node(graph_pos)
			4: add_end_node(graph_pos)
		popup.queue_free()
	)
	add_child(popup)
	popup.position = get_screen_position() + at_position
	popup.popup()
