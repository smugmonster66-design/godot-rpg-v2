# quest_tab.gd - Quest log display for the player menu
# Shows active, completed, and bounty quests with expandable objectives.
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal refresh_requested()
signal data_changed()

# ============================================================================
# CONSTANTS
# ============================================================================
enum Filter { ACTIVE, COMPLETED, BOUNTIES }

const TYPE_COLORS: Dictionary = {
	QuestDefinition.QuestType.MAIN: Color("ffd700"),       # Gold
	QuestDefinition.QuestType.SIDE: Color("b4b4b4"),       # Silver
	QuestDefinition.QuestType.COMPANION: Color("ff6b9d"),  # Pink
	QuestDefinition.QuestType.BOUNTY: Color("ff8c42"),     # Orange
	QuestDefinition.QuestType.COLLECTION: Color("7bc96f"), # Green
	QuestDefinition.QuestType.EXPLORATION: Color("5bc0de"),# Cyan
	QuestDefinition.QuestType.HIDDEN: Color("9b59b6"),     # Purple
}

const TYPE_LABELS: Dictionary = {
	QuestDefinition.QuestType.MAIN: "Main",
	QuestDefinition.QuestType.SIDE: "Side",
	QuestDefinition.QuestType.COMPANION: "Companion",
	QuestDefinition.QuestType.BOUNTY: "Bounty",
	QuestDefinition.QuestType.COLLECTION: "Collection",
	QuestDefinition.QuestType.EXPLORATION: "Exploration",
	QuestDefinition.QuestType.HIDDEN: "Hidden",
}

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var _current_filter: Filter = Filter.ACTIVE
var _selected_quest_id: StringName = &""
var _expanded_quests: Dictionary = {}  # quest_id -> bool

# UI references
var _filter_bar: HBoxContainer
var _filter_buttons: Array[Button] = []
var _scroll_container: ScrollContainer
var _quest_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_label: RichTextLabel
var _no_quests_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")
	_build_ui()
	_connect_signals()

func _build_ui():
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Filter bar
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 8)
	_filter_bar.custom_minimum_size.y = 48
	root.add_child(_filter_bar)

	var filter_names: Array[String] = ["Active", "Completed", "Bounties"]
	for i in range(filter_names.size()):
		var btn = Button.new()
		btn.text = filter_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 44
		btn.pressed.connect(_on_filter_pressed.bind(i))
		_filter_bar.add_child(btn)
		_filter_buttons.append(btn)

	# Scroll container for quest list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll_container)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_quest_list)

	# "No quests" label
	_no_quests_label = Label.new()
	_no_quests_label.text = "No quests to display."
	_no_quests_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_quests_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_quests_label.add_theme_font_size_override("font_size", 24)
	if ThemeManager:
		_no_quests_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
	_no_quests_label.visible = false
	root.add_child(_no_quests_label)

	# Detail panel (hidden by default, shown on quest tap)
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.visible = false
	root.add_child(_detail_panel)

	var detail_margin = MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_right", 16)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	_detail_panel.add_child(detail_margin)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_vbox)

	var detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_vbox.add_child(detail_scroll)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.scroll_active = false
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_label)

	var close_detail_btn = Button.new()
	close_detail_btn.text = "Close"
	close_detail_btn.custom_minimum_size.y = 40
	close_detail_btn.pressed.connect(_hide_detail_panel)
	detail_vbox.add_child(close_detail_btn)

var _bound_journal: QuestJournal = null

func _connect_signals():
	_bind_journal()
	# GameState swaps its QuestJournal on new game / load; follow it.
	if not GameState.state_loaded.is_connected(_bind_journal):
		GameState.state_loaded.connect(_bind_journal)

func _bind_journal() -> void:
	if _bound_journal and is_instance_valid(_bound_journal):
		if _bound_journal.quest_state_changed.is_connected(_on_quest_state_changed):
			_bound_journal.quest_state_changed.disconnect(_on_quest_state_changed)
		if _bound_journal.objective_updated.is_connected(_on_objective_updated):
			_bound_journal.objective_updated.disconnect(_on_objective_updated)
	_bound_journal = GameState.quests
	if _bound_journal:
		_bound_journal.quest_state_changed.connect(_on_quest_state_changed)
		_bound_journal.objective_updated.connect(_on_objective_updated)

# ============================================================================
# PUBLIC API (called by PlayerMenu)
# ============================================================================

func set_player(p_player: Player):
	player = p_player

func refresh():
	_rebuild_quest_list()

func on_external_data_change():
	_rebuild_quest_list()

# ============================================================================
# FILTER HANDLING
# ============================================================================

func _on_filter_pressed(filter_index: int):
	_current_filter = filter_index as Filter
	# Update button states
	for i in range(_filter_buttons.size()):
		_filter_buttons[i].button_pressed = (i == filter_index)
	_hide_detail_panel()
	_rebuild_quest_list()

# ============================================================================
# QUEST LIST BUILDING
# ============================================================================

func _rebuild_quest_list():
	# Clear existing entries
	for child in _quest_list.get_children():
		child.queue_free()

	var quest_ids: Array[StringName] = _get_filtered_quest_ids()

	_no_quests_label.visible = quest_ids.is_empty()
	_scroll_container.visible = not quest_ids.is_empty()

	# Sort by priority then name
	quest_ids.sort_custom(_sort_quests)

	for quest_id in quest_ids:
		var entry = _build_quest_entry(quest_id)
		if entry:
			_quest_list.add_child(entry)

func _get_filtered_quest_ids() -> Array[StringName]:
	var listed: Array[StringName] = []
	for qid in _get_filtered_quest_ids_unhidden():
		if QuestManager.is_quest_listed(qid):
			listed.append(qid)
	return listed

func _get_filtered_quest_ids_unhidden() -> Array[StringName]:
	match _current_filter:
		Filter.ACTIVE:
			var result: Array[StringName] = []
			for qid in GameState.quests.get_active_quests():
				var def = QuestManager.get_definition(qid)
				if def and def.quest_type != QuestDefinition.QuestType.BOUNTY:
					result.append(qid)
			# Also include AVAILABLE and READY_TO_TURN_IN
			for qid in GameState.quests.get_available_quests():
				var def = QuestManager.get_definition(qid)
				if def and def.quest_type != QuestDefinition.QuestType.BOUNTY:
					result.append(qid)
			for qid in GameState.quests.get_quests_by_state(QuestProgress.QuestState.READY_TO_TURN_IN):
				var def = QuestManager.get_definition(qid)
				if def and def.quest_type != QuestDefinition.QuestType.BOUNTY:
					if qid not in result:
						result.append(qid)
			return result
		Filter.COMPLETED:
			return GameState.quests.get_completed_quests()
		Filter.BOUNTIES:
			var result: Array[StringName] = []
			for qid in GameState.quests.get_active_quests():
				var def = QuestManager.get_definition(qid)
				if def and def.quest_type == QuestDefinition.QuestType.BOUNTY:
					result.append(qid)
			for qid in GameState.quests.get_available_quests():
				var def = QuestManager.get_definition(qid)
				if def and def.quest_type == QuestDefinition.QuestType.BOUNTY:
					result.append(qid)
			return result
	return []

func _sort_quests(a: StringName, b: StringName) -> bool:
	var def_a = QuestManager.get_definition(a)
	var def_b = QuestManager.get_definition(b)
	if def_a == null or def_b == null:
		return false
	if def_a.sort_priority != def_b.sort_priority:
		return def_a.sort_priority < def_b.sort_priority
	# MAIN quests first by type
	if def_a.quest_type != def_b.quest_type:
		return def_a.quest_type < def_b.quest_type
	return def_a.get_display_name() < def_b.get_display_name()

# ============================================================================
# QUEST ENTRY BUILDING
# ============================================================================

func _build_quest_entry(quest_id: StringName) -> Control:
	var info: Dictionary = QuestManager.get_quest_display_info(quest_id)
	if info.is_empty():
		return null

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Quest header row
	var header = Button.new()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 52

	var quest_type: int = info.get("type", 0)
	var type_color: Color = TYPE_COLORS.get(quest_type, Color.WHITE)
	var type_label: String = TYPE_LABELS.get(quest_type, "")
	var state: int = info.get("state", 0)

	var state_prefix: String = ""
	match state:
		QuestProgress.QuestState.AVAILABLE:
			state_prefix = "[NEW] "
		QuestProgress.QuestState.READY_TO_TURN_IN:
			state_prefix = "[TURN IN] "
		QuestProgress.QuestState.COMPLETE:
			state_prefix = "[DONE] "
		QuestProgress.QuestState.FAILED:
			state_prefix = "[FAILED] "

	header.text = "%s%s: %s" % [state_prefix, type_label, info.get("name", "")]
	header.add_theme_color_override("font_color", type_color)
	header.add_theme_font_size_override("font_size", 22)
	header.pressed.connect(_on_quest_header_pressed.bind(quest_id))
	container.add_child(header)

	return container

func _build_objective_row(obj_info: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Indent
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 32
	hbox.add_child(spacer)

	# Checkmark or bullet
	var check_label = Label.new()
	var is_complete: bool = obj_info.get("complete", false)
	check_label.text = "[x]" if is_complete else "[ ]"
	check_label.theme_type_variation = &"ObjText"
	if is_complete and ThemeManager:
		check_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
	hbox.add_child(check_label)

	# Description with progress (already formatted by get_display_description)
	var desc_label = Label.new()
	var desc: String = obj_info.get("description", "")
	if obj_info.get("optional", false):
		desc = "%s (optional)" % desc
	desc_label.text = desc
	desc_label.theme_type_variation = &"ObjText"
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_complete and ThemeManager:
		desc_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
	hbox.add_child(desc_label)

	return hbox

# ============================================================================
# DETAIL PANEL
# ============================================================================

func _show_detail_panel(quest_id: StringName):
	var info: Dictionary = QuestManager.get_quest_display_info(quest_id)
	if info.is_empty():
		return

	_selected_quest_id = quest_id
	var text: String = ""

	# Title
	var type_label: String = TYPE_LABELS.get(info.get("type", 0), "")
	text += "[b]%s[/b]\n" % info.get("name", "")
	text += "[color=#858585]%s Quest[/color]\n\n" % type_label

	# Description
	var desc: String = info.get("description", "")
	if desc != "":
		text += "%s\n\n" % desc
	else:
		var summary: String = info.get("summary", "")
		if summary != "":
			text += "%s\n\n" % summary

	# Objectives
	var objectives: Array = info.get("objectives", [])
	if not objectives.is_empty():
		text += "[b]Objectives:[/b]\n"
		for obj in objectives:
			var check: String = "[x]" if obj.get("complete", false) else "[ ]"
			var obj_desc: String = obj.get("description", "")
			text += "  %s %s\n" % [check, obj_desc]
		text += "\n"

	# Rewards
	var rewards_preview: String = info.get("rewards_preview", "")
	if rewards_preview != "" and rewards_preview != "No rewards":
		text += "[b]Rewards:[/b] %s\n" % rewards_preview

	# Quest giver / turn-in info
	var turn_in_location: StringName = info.get("turn_in_location", &"")
	if turn_in_location != &"":
		var loc = MapManager.get_location(turn_in_location)
		if loc:
			text += "[color=#858585]Turn in at: %s[/color]\n" % loc.display_name

	_detail_label.text = text
	_detail_panel.visible = true

func _hide_detail_panel():
	_detail_panel.visible = false
	_selected_quest_id = &""

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_quest_header_pressed(quest_id: StringName):
	# Toggle expand
	var was_expanded: bool = _expanded_quests.get(quest_id, false)
	_expanded_quests[quest_id] = not was_expanded

	# If expanding, also show detail panel
	if not was_expanded:
		_show_detail_panel(quest_id)
	else:
		if _selected_quest_id == quest_id:
			_hide_detail_panel()

	_rebuild_quest_list()

func _on_quest_state_changed(_quest_id: StringName, _old_state: int, _new_state: int):
	_rebuild_quest_list()

func _on_objective_updated(_quest_id: StringName, _objective_id: StringName, _progress: int):
	_rebuild_quest_list()

func has_active_popup() -> bool:
	return _detail_panel.visible
