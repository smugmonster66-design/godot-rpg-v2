@tool
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal speaker_selected(speaker: DialogueSpeaker)
signal speakers_changed

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var speaker_list: ItemList = $VBox/SpeakerList
@onready var add_button: Button = $VBox/ButtonRow/AddButton
@onready var remove_button: Button = $VBox/ButtonRow/RemoveButton
@onready var browse_button: Button = $VBox/ButtonRow/BrowseButton

# ============================================================================
# STATE
# ============================================================================
var _speakers: Array[DialogueSpeaker] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_on_add_pressed)
	if remove_button:
		remove_button.pressed.connect(_on_remove_pressed)
	if browse_button:
		browse_button.pressed.connect(_on_browse_pressed)
	if speaker_list:
		speaker_list.item_selected.connect(_on_speaker_list_selected)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_speakers() -> Array[DialogueSpeaker]:
	return _speakers

func clear_speakers() -> void:
	_speakers.clear()
	_refresh_list()

func add_speaker(speaker: DialogueSpeaker) -> void:
	if not speaker in _speakers:
		_speakers.append(speaker)
		_refresh_list()
		speakers_changed.emit()

func remove_speaker(speaker: DialogueSpeaker) -> void:
	var idx = _speakers.find(speaker)
	if idx >= 0:
		_speakers.remove_at(idx)
		_refresh_list()
		speakers_changed.emit()

func set_speakers(speakers: Array[DialogueSpeaker]) -> void:
	_speakers = speakers.duplicate()
	_refresh_list()

# ============================================================================
# UI
# ============================================================================

func _refresh_list() -> void:
	if not speaker_list:
		return
	
	speaker_list.clear()
	for speaker in _speakers:
		var display = speaker.display_name if speaker.display_name else str(speaker.speaker_id)
		speaker_list.add_item(display)
		
		# Try to show bust thumbnail (compatible with both APIs)
		var texture: Texture2D = null
		if speaker.has_method("get_bust"):
			texture = speaker.get_bust("")  # Empty string = default
		if not texture and speaker.bust_texture:
			texture = speaker.bust_texture
		if texture:
			speaker_list.set_item_icon(speaker_list.item_count - 1, texture)

func _on_speaker_list_selected(index: int) -> void:
	if index >= 0 and index < _speakers.size():
		speaker_selected.emit(_speakers[index])

func _on_add_pressed() -> void:
	# Create a new empty speaker
	var speaker = DialogueSpeaker.new()
	speaker.speaker_id = &"new_speaker_%d" % _speakers.size()
	speaker.display_name = "New Speaker"
	add_speaker(speaker)

func _on_remove_pressed() -> void:
	var selected = speaker_list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		if idx >= 0 and idx < _speakers.size():
			remove_speaker(_speakers[idx])

func _on_browse_pressed() -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Dialogue Speaker")
	dialog.current_path = "res://resources/speakers/"
	dialog.file_selected.connect(_on_speaker_file_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)

func _on_speaker_file_selected(path: String) -> void:
	var speaker = load(path) as DialogueSpeaker
	if speaker:
		add_speaker(speaker)
	else:
		push_error("[SpeakersPanel] Failed to load speaker: ", path)
