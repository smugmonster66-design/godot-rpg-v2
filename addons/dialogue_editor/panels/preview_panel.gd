@tool
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal preview_node_requested(node: GraphNode)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var preview_container: PanelContainer = $VBox/PreviewContainer
@onready var bust_left: TextureRect = $VBox/PreviewContainer/PreviewMargin/PreviewContent/BustRow/BustLeft
@onready var bust_center: TextureRect = $VBox/PreviewContainer/PreviewMargin/PreviewContent/BustRow/BustCenter
@onready var bust_right: TextureRect = $VBox/PreviewContainer/PreviewMargin/PreviewContent/BustRow/BustRight
@onready var speaker_label: Label = $VBox/PreviewContainer/PreviewMargin/PreviewContent/SpeakerLabel
@onready var dialogue_label: RichTextLabel = $VBox/PreviewContainer/PreviewMargin/PreviewContent/DialogueLabel
@onready var choices_container: VBoxContainer = $VBox/PreviewContainer/PreviewMargin/PreviewContent/ChoicesContainer
@onready var no_selection_label: Label = $VBox/NoSelectionLabel
@onready var nav_row: HBoxContainer = $VBox/NavRow
@onready var prev_button: Button = $VBox/NavRow/PrevButton
@onready var next_button: Button = $VBox/NavRow/NextButton
@onready var node_label: Label = $VBox/NavRow/NodeLabel

# ============================================================================
# STATE
# ============================================================================
var _graph: DialogueGraphEdit = null
var _current_node: GraphNode = null
var _speakers: Array[DialogueSpeaker] = []

# Bust state for preview
var _preview_busts: Dictionary = {"left": null, "center": null, "right": null}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	
	_clear_preview()

func set_graph(graph: DialogueGraphEdit) -> void:
	_graph = graph
	if _graph:
		_graph.dialogue_node_selected.connect(_on_graph_node_selected)

func set_speakers(speakers: Array[DialogueSpeaker]) -> void:
	_speakers = speakers

# ============================================================================
# PREVIEW UPDATE
# ============================================================================

func _on_graph_node_selected(node: GraphNode) -> void:
	preview_node(node)

func preview_node(node: GraphNode) -> void:
	_current_node = node
	
	if not node:
		_clear_preview()
		return
	
	var node_type = node.get_node_type() if node.has_method("get_node_type") else ""
	
	match node_type:
		"start":
			_preview_start_node(node)
		"line":
			_preview_line_node(node)
		"choice":
			_preview_choice_node(node)
		"condition":
			_preview_condition_node(node)
		"set_flag":
			_preview_set_flag_node(node)
		"end":
			_preview_end_node(node)
		_:
			_clear_preview()

func _clear_preview() -> void:
	if preview_container:
		preview_container.visible = false
	if no_selection_label:
		no_selection_label.visible = true
	if nav_row:
		nav_row.visible = false
	_current_node = null

func _show_preview() -> void:
	if preview_container:
		preview_container.visible = true
	if no_selection_label:
		no_selection_label.visible = false
	if nav_row:
		nav_row.visible = true

# ============================================================================
# NODE TYPE PREVIEWS
# ============================================================================

func _preview_start_node(node: GraphNode) -> void:
	_show_preview()
	_hide_busts()
	_hide_choices()
	
	speaker_label.text = "START"
	speaker_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	dialogue_label.text = "[i]Entry point - dialogue begins here[/i]"
	node_label.text = node.name

func _preview_line_node(node: GraphNode) -> void:
	_show_preview()
	
	var data = node.get_node_data()
	var speaker_id = data.get("speaker_id", &"")
	var bust_name = data.get("bust_name", "")
	var text = data.get("text", "")
	
	# Get speaker
	var speaker = _get_speaker(speaker_id)
	
	# Update speaker name
	if speaker:
		speaker_label.text = speaker.display_name
		speaker_label.add_theme_color_override("font_color", speaker.name_color)
	elif speaker_id == &"":
		speaker_label.text = "[Narrator]"
		speaker_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		speaker_label.text = str(speaker_id)
		speaker_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update bust slots based on line data
	_update_bust_preview(data, speaker, bust_name)
	
	# Update dialogue text
	dialogue_label.text = text if text != "" else "[i]No text entered[/i]"
	
	# Hide choices for line nodes
	_hide_choices()
	
	node_label.text = node.name

func _preview_choice_node(node: GraphNode) -> void:
	_show_preview()
	_hide_busts()
	
	speaker_label.text = "PLAYER CHOICE"
	speaker_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	dialogue_label.text = "[i]Player selects from:[/i]"
	
	# Show choices
	var data = node.get_node_data()
	var choices = data.get("choices", [])
	_show_choices(choices)
	
	node_label.text = node.name

func _preview_condition_node(node: GraphNode) -> void:
	_show_preview()
	_hide_busts()
	_hide_choices()
	
	speaker_label.text = "CONDITION"
	speaker_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	
	var data = node.get_node_data()
	var condition_type = data.get("condition_type", 0)
	var flag_name = data.get("flag_name", "")
	var compare_value = data.get("compare_value", 0)
	
	var condition_text = ""
	match condition_type:
		0: condition_text = "Flag '%s' is SET" % flag_name
		1: condition_text = "Flag '%s' is NOT SET" % flag_name
		2: condition_text = "Counter '%s' >= %d" % [flag_name, compare_value]
		3: condition_text = "Counter '%s' < %d" % [flag_name, compare_value]
		4: condition_text = "Counter '%s' == %d" % [flag_name, compare_value]
	
	dialogue_label.text = "[b]If:[/b] %s\n[color=green]✓ True →[/color] ...\n[color=red]✗ False →[/color] ..." % condition_text
	
	node_label.text = node.name

func _preview_set_flag_node(node: GraphNode) -> void:
	_show_preview()
	_hide_busts()
	_hide_choices()
	
	speaker_label.text = "SET FLAG"
	speaker_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.7))
	
	var data = node.get_node_data()
	var action_type = data.get("action_type", 0)
	var flag_name = data.get("flag_name", "")
	var value = data.get("value", 1)
	
	var action_text = ""
	match action_type:
		0: action_text = "Set flag '%s' = TRUE" % flag_name
		1: action_text = "Clear flag '%s' = FALSE" % flag_name
		2: action_text = "Increment '%s' by %d" % [flag_name, value]
		3: action_text = "Decrement '%s' by %d" % [flag_name, value]
		4: action_text = "Set '%s' = %d" % [flag_name, value]
	
	dialogue_label.text = "[b]Action:[/b] %s" % action_text
	
	node_label.text = node.name

func _preview_end_node(node: GraphNode) -> void:
	_show_preview()
	_hide_busts()
	_hide_choices()
	
	speaker_label.text = "END"
	speaker_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	dialogue_label.text = "[i]Dialogue ends here[/i]"
	
	node_label.text = node.name

# ============================================================================
# BUST PREVIEW
# ============================================================================

func _update_bust_preview(data: Dictionary, speaker: DialogueSpeaker, bust_name: String) -> void:
	# Apply bust slot changes from this line
	var left_speaker_id = data.get("left_speaker", &"")
	var center_speaker_id = data.get("center_speaker", &"")
	var right_speaker_id = data.get("right_speaker", &"")
	
	# Update slots
	if left_speaker_id != &"":
		var s = _get_speaker(left_speaker_id)
		_preview_busts.left = _get_bust_texture(s, data.get("left_bust", ""))
	if center_speaker_id != &"":
		var s = _get_speaker(center_speaker_id)
		_preview_busts.center = _get_bust_texture(s, data.get("center_bust", ""))
	if right_speaker_id != &"":
		var s = _get_speaker(right_speaker_id)
		_preview_busts.right = _get_bust_texture(s, data.get("right_bust", ""))
	
	# Clear flags
	if data.get("clear_left", false):
		_preview_busts.left = null
	if data.get("clear_center", false):
		_preview_busts.center = null
	if data.get("clear_right", false):
		_preview_busts.right = null
	
	# If speaker has a bust, show it in their slot (default right)
	if speaker and bust_name != "":
		var slot = data.get("speaker_slot", 2)  # Default RIGHT
		var texture = _get_bust_texture(speaker, bust_name)
		match slot:
			0: pass  # NONE
			1: _preview_busts.left = texture  # LEFT
			2: _preview_busts.center = texture  # CENTER
			3: _preview_busts.right = texture  # RIGHT
	
	# Apply to UI
	_apply_bust_textures()

func _apply_bust_textures() -> void:
	if bust_left:
		bust_left.texture = _preview_busts.left
		bust_left.visible = _preview_busts.left != null
	if bust_center:
		bust_center.texture = _preview_busts.center
		bust_center.visible = _preview_busts.center != null
	if bust_right:
		bust_right.texture = _preview_busts.right
		bust_right.visible = _preview_busts.right != null

func _hide_busts() -> void:
	if bust_left:
		bust_left.visible = false
	if bust_center:
		bust_center.visible = false
	if bust_right:
		bust_right.visible = false

# ============================================================================
# CHOICES PREVIEW
# ============================================================================

func _show_choices(choices: Array) -> void:
	if not choices_container:
		return
	
	# Clear existing
	for child in choices_container.get_children():
		child.queue_free()
	
	choices_container.visible = true
	
	for i in choices.size():
		var choice_data = choices[i]
		var label = choice_data.get("label", "Choice %d" % (i + 1))
		
		var btn = Button.new()
		btn.text = "→ %s" % label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choices_container.add_child(btn)

func _hide_choices() -> void:
	if choices_container:
		choices_container.visible = false
		for child in choices_container.get_children():
			child.queue_free()

# ============================================================================
# NAVIGATION
# ============================================================================

func _on_prev_pressed() -> void:
	if not _current_node or not _graph:
		return
	
	# Find node connected to this one's input
	var prev_node = _graph.get_incoming_node(_current_node, 0)
	if prev_node:
		prev_node.selected = true
		preview_node(prev_node)

func _on_next_pressed() -> void:
	if not _current_node or not _graph:
		return
	
	# Find node connected to this one's output
	var next_node = _graph.get_connected_node(_current_node, 0)
	if next_node:
		next_node.selected = true
		preview_node(next_node)

# ============================================================================
# HELPERS
# ============================================================================

func _get_speaker(speaker_id: StringName) -> DialogueSpeaker:
	for speaker in _speakers:
		if speaker.speaker_id == speaker_id:
			return speaker
	return null

func _get_bust_texture(speaker: DialogueSpeaker, bust_name: String) -> Texture2D:
	"""Get bust texture from speaker."""
	if not speaker:
		return null
	
	# Call the speaker's method directly - requires updated DialogueSpeaker
	return speaker.get_bust(bust_name)
