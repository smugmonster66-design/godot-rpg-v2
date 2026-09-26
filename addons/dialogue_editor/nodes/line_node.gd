@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# BUST SLOT
# ============================================================================
enum BustSlot {
	NONE,
	LEFT,
	CENTER,
	RIGHT,
}

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var speaker_dropdown: OptionButton = $VBox/SpeakerRow/SpeakerDropdown
@onready var bust_dropdown: OptionButton = $VBox/BustRow/BustDropdown
@onready var slot_dropdown: OptionButton = $VBox/BustRow/SlotDropdown
@onready var bust_preview: TextureRect = $VBox/BustRow/BustPreview
@onready var text_edit: TextEdit = $VBox/TextEdit
@onready var bust_slots_section: VBoxContainer = $VBox/BustSlotsSection
@onready var left_slot_dropdown: OptionButton = $VBox/BustSlotsSection/LeftRow/LeftSpeaker
@onready var left_bust_dropdown: OptionButton = $VBox/BustSlotsSection/LeftRow/LeftBust
@onready var center_slot_dropdown: OptionButton = $VBox/BustSlotsSection/CenterRow/CenterSpeaker
@onready var center_bust_dropdown: OptionButton = $VBox/BustSlotsSection/CenterRow/CenterBust
@onready var right_slot_dropdown: OptionButton = $VBox/BustSlotsSection/RightRow/RightSpeaker
@onready var right_bust_dropdown: OptionButton = $VBox/BustSlotsSection/RightRow/RightBust
@onready var slots_toggle: Button = $VBox/SlotsToggleRow/SlotsToggle

# ============================================================================
# STATE
# ============================================================================
var speaker_id: StringName = &""
var bust_name: String = ""
var dialogue_text: String = ""
var speaker_slot: BustSlot = BustSlot.RIGHT

# Bust slot assignments
var left_speaker: StringName = &""
var left_bust: String = ""
var center_speaker: StringName = &""
var center_bust: String = ""
var right_speaker: StringName = &""
var right_bust: String = ""

# Clear flags
var clear_left: bool = false
var clear_center: bool = false
var clear_right: bool = false

# Available speakers (set by parent graph/dock)
var _available_speakers: Array[DialogueSpeaker] = []
var _slots_expanded: bool = false
var _bbcode_menu = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "LINE"
	
	# Visual styling
	add_theme_color_override("title_color", Color(0.4, 0.6, 0.9))
	
	# One input, one output
	set_slot(0, true, 0, Color(0.4, 0.6, 0.9), true, 0, Color(0.4, 0.6, 0.9))
	
	# Connect signals
	if speaker_dropdown:
		speaker_dropdown.item_selected.connect(_on_speaker_selected)
	if bust_dropdown:
		bust_dropdown.item_selected.connect(_on_bust_selected)
	if slot_dropdown:
		slot_dropdown.clear()
		slot_dropdown.add_item("Right", BustSlot.RIGHT)
		slot_dropdown.add_item("Center", BustSlot.CENTER)
		slot_dropdown.add_item("Left", BustSlot.LEFT)
		slot_dropdown.item_selected.connect(_on_slot_selected)
	if text_edit:
		text_edit.text_changed.connect(_on_text_changed)
		text_edit.gui_input.connect(_on_text_edit_gui_input)

	# BBCode style context menu (Window must be child of root, not GraphNode)
	var menu_scene = load("res://addons/dialogue_editor/widgets/bbcode_style_menu.tscn")
	if menu_scene:
		_bbcode_menu = menu_scene.instantiate()
		# Defer adding to tree root so it's a proper sub-window
		_add_menu_deferred.call_deferred()

	if slots_toggle:
		slots_toggle.pressed.connect(_on_slots_toggle_pressed)
	
	# Connect bust slot dropdowns
	if left_slot_dropdown:
		left_slot_dropdown.item_selected.connect(_on_left_speaker_selected)
	if left_bust_dropdown:
		left_bust_dropdown.item_selected.connect(_on_left_bust_selected)
	if center_slot_dropdown:
		center_slot_dropdown.item_selected.connect(_on_center_speaker_selected)
	if center_bust_dropdown:
		center_bust_dropdown.item_selected.connect(_on_center_bust_selected)
	if right_slot_dropdown:
		right_slot_dropdown.item_selected.connect(_on_right_speaker_selected)
	if right_bust_dropdown:
		right_bust_dropdown.item_selected.connect(_on_right_bust_selected)
	
	# Start with slots collapsed
	if bust_slots_section:
		bust_slots_section.visible = false

# ============================================================================
# SPEAKER MANAGEMENT
# ============================================================================

func set_available_speakers(speakers: Array[DialogueSpeaker]) -> void:
	_available_speakers = speakers
	_refresh_speaker_dropdown()
	_refresh_slot_speaker_dropdowns()

func _refresh_speaker_dropdown() -> void:
	if not speaker_dropdown:
		return
	
	speaker_dropdown.clear()
	speaker_dropdown.add_item("(None)", 0)
	
	for i in _available_speakers.size():
		var speaker = _available_speakers[i]
		speaker_dropdown.add_item(speaker.display_name, i + 1)
	
	_select_speaker_in_dropdown()

func _refresh_slot_speaker_dropdowns() -> void:
	"""Refresh all three slot speaker dropdowns."""
	for dropdown in [left_slot_dropdown, center_slot_dropdown, right_slot_dropdown]:
		if not dropdown:
			continue
		dropdown.clear()
		dropdown.add_item("(None)", 0)
		dropdown.add_item("[Clear]", -1)  # Special clear option
		for i in _available_speakers.size():
			var speaker = _available_speakers[i]
			dropdown.add_item(speaker.display_name, i + 2)

func _select_speaker_in_dropdown() -> void:
	if not speaker_dropdown:
		return
	
	speaker_dropdown.select(0)
	for i in _available_speakers.size():
		if _available_speakers[i].speaker_id == speaker_id:
			speaker_dropdown.select(i + 1)
			break

func _on_speaker_selected(index: int) -> void:
	if index == 0:
		speaker_id = &""
		bust_name = ""
		_refresh_bust_dropdown()
		_update_bust_preview()
	else:
		var speaker = _available_speakers[index - 1]
		speaker_id = speaker.speaker_id
		_refresh_bust_dropdown()
		if bust_dropdown and bust_dropdown.item_count > 0:
			bust_dropdown.select(0)
			_on_bust_selected(0)
	
	_emit_modified()

# ============================================================================
# BUST MANAGEMENT
# ============================================================================

func _refresh_bust_dropdown() -> void:
	if not bust_dropdown:
		return
	
	bust_dropdown.clear()
	
	var speaker = _get_current_speaker()
	if not speaker:
		bust_dropdown.visible = false
		return
	
	bust_dropdown.visible = true
	var busts = _get_speaker_busts(speaker)
	for i in busts.size():
		bust_dropdown.add_item(busts[i], i)
	
	for i in busts.size():
		if busts[i] == bust_name:
			bust_dropdown.select(i)
			break

func _refresh_bust_dropdown_for_speaker(speaker: DialogueSpeaker, dropdown: OptionButton, current_bust: String) -> void:
	"""Refresh a bust dropdown for a specific speaker."""
	if not dropdown:
		return
	
	dropdown.clear()
	
	if not speaker:
		dropdown.add_item("(default)", 0)
		return
	
	var busts = _get_speaker_busts(speaker)
	for i in busts.size():
		dropdown.add_item(busts[i], i)
	
	for i in busts.size():
		if busts[i] == current_bust:
			dropdown.select(i)
			break

func _on_bust_selected(index: int) -> void:
	var speaker = _get_current_speaker()
	if not speaker:
		return
	
	var busts = _get_speaker_busts(speaker)
	if index >= 0 and index < busts.size():
		bust_name = busts[index]
		_update_bust_preview()
	
	_emit_modified()

func _on_slot_selected(index: int) -> void:
	speaker_slot = slot_dropdown.get_item_id(index) as BustSlot
	_emit_modified()

func _update_bust_preview() -> void:
	if not bust_preview:
		return
	
	var speaker = _get_current_speaker()
	if speaker and bust_name != "":
		var texture = _get_speaker_bust_texture(speaker, bust_name)
		if texture:
			bust_preview.texture = texture
			bust_preview.visible = true
			return
	
	bust_preview.texture = null
	bust_preview.visible = false

func _get_current_speaker() -> DialogueSpeaker:
	for speaker in _available_speakers:
		if speaker.speaker_id == speaker_id:
			return speaker
	return null

func _get_speaker_by_id(id: StringName) -> DialogueSpeaker:
	for speaker in _available_speakers:
		if speaker.speaker_id == id:
			return speaker
	return null

func _get_speaker_busts(speaker: DialogueSpeaker) -> Array[String]:
	"""Get available bust names from speaker."""
	if not speaker:
		return []
	
	# Call the speaker's method directly - requires updated DialogueSpeaker
	return speaker.get_available_busts()

func _get_speaker_bust_texture(speaker: DialogueSpeaker, bust_name: String) -> Texture2D:
	"""Get bust texture from speaker."""
	if not speaker:
		return null
	
	# Call the speaker's method directly - requires updated DialogueSpeaker
	return speaker.get_bust(bust_name)

# ============================================================================
# BUST SLOTS SECTION
# ============================================================================

func _on_slots_toggle_pressed() -> void:
	_slots_expanded = not _slots_expanded
	if bust_slots_section:
		bust_slots_section.visible = _slots_expanded
	if slots_toggle:
		slots_toggle.text = "▼ Bust Slots" if _slots_expanded else "▶ Bust Slots"

func _on_left_speaker_selected(index: int) -> void:
	if index == 0:  # None
		left_speaker = &""
		clear_left = false
	elif index == 1:  # Clear
		left_speaker = &""
		clear_left = true
	else:
		left_speaker = _available_speakers[index - 2].speaker_id
		clear_left = false
		var speaker = _available_speakers[index - 2]
		_refresh_bust_dropdown_for_speaker(speaker, left_bust_dropdown, left_bust)
	_emit_modified()

func _on_left_bust_selected(index: int) -> void:
	var speaker = _get_speaker_by_id(left_speaker)
	if speaker:
		var busts = speaker.get_available_busts()
		if index >= 0 and index < busts.size():
			left_bust = busts[index]
	_emit_modified()

func _on_center_speaker_selected(index: int) -> void:
	if index == 0:
		center_speaker = &""
		clear_center = false
	elif index == 1:
		center_speaker = &""
		clear_center = true
	else:
		center_speaker = _available_speakers[index - 2].speaker_id
		clear_center = false
		var speaker = _available_speakers[index - 2]
		_refresh_bust_dropdown_for_speaker(speaker, center_bust_dropdown, center_bust)
	_emit_modified()

func _on_center_bust_selected(index: int) -> void:
	var speaker = _get_speaker_by_id(center_speaker)
	if speaker:
		var busts = speaker.get_available_busts()
		if index >= 0 and index < busts.size():
			center_bust = busts[index]
	_emit_modified()

func _on_right_speaker_selected(index: int) -> void:
	if index == 0:
		right_speaker = &""
		clear_right = false
	elif index == 1:
		right_speaker = &""
		clear_right = true
	else:
		right_speaker = _available_speakers[index - 2].speaker_id
		clear_right = false
		var speaker = _available_speakers[index - 2]
		_refresh_bust_dropdown_for_speaker(speaker, right_bust_dropdown, right_bust)
	_emit_modified()

func _on_right_bust_selected(index: int) -> void:
	var speaker = _get_speaker_by_id(right_speaker)
	if speaker:
		var busts = speaker.get_available_busts()
		if index >= 0 and index < busts.size():
			right_bust = busts[index]
	_emit_modified()

# ============================================================================
# TEXT
# ============================================================================

func _add_menu_deferred() -> void:
	if _bbcode_menu and not _bbcode_menu.is_inside_tree():
		EditorInterface.get_base_control().add_child(_bbcode_menu)

func _exit_tree() -> void:
	if _bbcode_menu and is_instance_valid(_bbcode_menu):
		_bbcode_menu.queue_free()
		_bbcode_menu = null

func _on_text_changed() -> void:
	if text_edit:
		dialogue_text = text_edit.text
		_auto_resize_text_edit()
	_emit_modified()

func _auto_resize_text_edit() -> void:
	if not text_edit:
		return
	var line_count = text_edit.get_line_count()
	var line_height = text_edit.get_line_height()
	# Minimum 3 lines, grow with content
	var target_lines = maxi(line_count + 1, 3)
	var new_height = target_lines * line_height
	text_edit.custom_minimum_size.y = new_height

func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if text_edit and text_edit.has_selection() and _bbcode_menu:
			_bbcode_menu.show_for_text_edit(text_edit, self)
			text_edit.accept_event()

# ============================================================================
# SERIALIZATION
# ============================================================================

func get_node_type() -> String:
	return "line"

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	data.speaker_id = speaker_id
	data.bust_name = bust_name
	data.speaker_slot = speaker_slot
	data.text = dialogue_text
	
	# Bust slot assignments
	data.left_speaker = left_speaker
	data.left_bust = left_bust
	data.center_speaker = center_speaker
	data.center_bust = center_bust
	data.right_speaker = right_speaker
	data.right_bust = right_bust
	
	# Clear flags
	data.clear_left = clear_left
	data.clear_center = clear_center
	data.clear_right = clear_right
	
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)
	
	speaker_id = data.get("speaker_id", &"")
	bust_name = data.get("bust_name", "")
	speaker_slot = data.get("speaker_slot", BustSlot.RIGHT)
	dialogue_text = data.get("text", "")
	
	# Bust slot assignments
	left_speaker = data.get("left_speaker", &"")
	left_bust = data.get("left_bust", "")
	center_speaker = data.get("center_speaker", &"")
	center_bust = data.get("center_bust", "")
	right_speaker = data.get("right_speaker", &"")
	right_bust = data.get("right_bust", "")
	
	# Clear flags
	clear_left = data.get("clear_left", false)
	clear_center = data.get("clear_center", false)
	clear_right = data.get("clear_right", false)
	
	# Update UI
	_select_speaker_in_dropdown()
	_refresh_bust_dropdown()
	_update_bust_preview()
	
	if slot_dropdown:
		for i in slot_dropdown.item_count:
			if slot_dropdown.get_item_id(i) == speaker_slot:
				slot_dropdown.select(i)
				break
	
	if text_edit:
		text_edit.text = dialogue_text
		_auto_resize_text_edit()
