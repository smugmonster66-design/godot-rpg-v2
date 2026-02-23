# res://scripts/ui/menus/dungeon_selection_screen.gd
## Full-screen dungeon selection overlay. Shows available dungeons as
## scrollable cards with level, floor count, description, lock state,
## and a Begin Run button.
##
## Lives in PersistentUILayer alongside PlayerMenu. GameRoot discovers it,
## connects dungeon_selected, and calls open()/close().
##
## Setup: Populate dungeon_list in the Inspector with DungeonListEntry .tres files.
extends Control
class_name DungeonSelectionScreen

# ============================================================================
# SIGNALS
# ============================================================================
signal dungeon_selected(definition: DungeonDefinition)
signal selection_closed

# ============================================================================
# CONFIGURATION
# ============================================================================

## Master list of dungeons available from this screen.
## Drag DungeonListEntry .tres files here in the Inspector.
@export var dungeon_list: Array[DungeonListEntry] = []

# ============================================================================
# NODE REFERENCES — match dungeon_selection_screen.tscn paths
# ============================================================================
@onready var bg_overlay: ColorRect = $BGOverlay
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var scroll_container: ScrollContainer = $CenterContainer/Panel/VBox/ScrollContainer
@onready var card_list: VBoxContainer = $CenterContainer/Panel/VBox/ScrollContainer/CardList
@onready var detail_section: VBoxContainer = $CenterContainer/Panel/VBox/DetailSection
@onready var detail_name: Label = $CenterContainer/Panel/VBox/DetailSection/DetailName
@onready var detail_desc: Label = $CenterContainer/Panel/VBox/DetailSection/DetailDesc
@onready var detail_stats: Label = $CenterContainer/Panel/VBox/DetailSection/DetailStats
@onready var detail_rewards: Label = $CenterContainer/Panel/VBox/DetailSection/DetailRewards
@onready var button_row: HBoxContainer = $CenterContainer/Panel/VBox/ButtonRow
@onready var begin_button: Button = $CenterContainer/Panel/VBox/ButtonRow/BeginButton
@onready var close_button: Button = $CenterContainer/Panel/VBox/ButtonRow/CloseButton

# ============================================================================
# STATE
# ============================================================================
var _player: Player = null
var _selected_entry: DungeonListEntry = null
var _selected_index: int = -1
var _cards: Array[PanelContainer] = []

# ============================================================================
# SELECTION HIGHLIGHT — only this overrides the theme
# ============================================================================
const SELECTED_BORDER: Color = Color(0.85, 0.7, 0.3, 0.9)
const LOCKED_MODULATE: Color = Color(0.5, 0.5, 0.5, 0.7)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	if begin_button:
		begin_button.pressed.connect(_on_begin_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

# ============================================================================
# PUBLIC API
# ============================================================================

func open(player: Player):
	"""Show the selection screen. Rebuilds cards each time to reflect unlock state."""
	_player = player
	_selected_entry = null
	_selected_index = -1

	# Sort entries by sort_order
	var sorted_entries: Array[DungeonListEntry] = dungeon_list.duplicate()
	sorted_entries.sort_custom(func(a, b): return a.sort_order < b.sort_order)

	_clear_cards()
	_build_cards(sorted_entries)

	# Reset detail panel
	if detail_section:
		detail_section.hide()
	if begin_button:
		begin_button.disabled = true
		begin_button.text = "Select a Dungeon"

	show()
	print("🏰 DungeonSelectionScreen: Opened (%d dungeons)" % dungeon_list.size())

func close():
	hide()
	_selected_entry = null
	_selected_index = -1
	selection_closed.emit()
	print("🏰 DungeonSelectionScreen: Closed")

# ============================================================================
# CARD BUILDING — theme-inherited, no hard-coded styles
# ============================================================================

func _clear_cards():
	_cards.clear()
	if not card_list:
		return
	for child in card_list.get_children():
		child.queue_free()

func _build_cards(entries: Array[DungeonListEntry]):
	if not card_list:
		return

	for i in entries.size():
		var entry: DungeonListEntry = entries[i]
		if not entry or not entry.dungeon_definition:
			continue
		var unlocked: bool = entry.is_unlocked(_player)
		var card: PanelContainer = _create_dungeon_card(entry, i, unlocked)
		card_list.add_child(card)
		_cards.append(card)

func _create_dungeon_card(entry: DungeonListEntry, index: int, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Dim locked cards via modulate
	if not unlocked:
		card.modulate = LOCKED_MODULATE

	# Content layout
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Icon
	var icon_tex: Texture2D = entry.get_icon()
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(56, 56)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)

	# Text column
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	# Name
	var name_label := Label.new()
	name_label.text = entry.get_display_name()
	text_vbox.add_child(name_label)

	# Info row: level + floors
	var info_label := Label.new()
	info_label.text = "Lv. %d  •  %d Floors" % [entry.get_display_level(), entry.get_floor_count()]
	text_vbox.add_child(info_label)

	# Lock text or reward preview
	if not unlocked:
		var lock_label := Label.new()
		lock_label.text = entry.get_lock_text()
		lock_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		text_vbox.add_child(lock_label)
	elif entry.reward_preview != "":
		var reward_label := Label.new()
		reward_label.text = entry.reward_preview
		reward_label.modulate = Color(0.6, 1.0, 0.6, 1.0)
		text_vbox.add_child(reward_label)

	# Click overlay (unlocked only)
	if unlocked:
		var click_btn := Button.new()
		click_btn.flat = true
		click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for s_name in ["normal", "hover", "pressed", "focus"]:
			click_btn.add_theme_stylebox_override(s_name, empty)
		click_btn.pressed.connect(_on_card_pressed.bind(index, entry))
		card.add_child(click_btn)

	return card

# ============================================================================
# SELECTION — minimal override, theme provides the base
# ============================================================================

func _on_card_pressed(index: int, entry: DungeonListEntry):
	_selected_entry = entry
	_selected_index = index

	# Update card visuals
	for i in _cards.size():
		_set_card_highlight(_cards[i], i == index)

	# Update detail panel
	_show_detail(entry)

	# Enable begin button
	if begin_button:
		begin_button.disabled = false
		begin_button.text = "Enter %s" % entry.get_display_name()

func _set_card_highlight(card: PanelContainer, selected: bool):
	if selected:
		var base: StyleBox = card.get_theme_stylebox("panel")
		if base and base is StyleBoxFlat:
			var highlight: StyleBoxFlat = base.duplicate()
			highlight.border_color = SELECTED_BORDER
			highlight.set_border_width_all(3)
			card.add_theme_stylebox_override("panel", highlight)
		else:
			var highlight := StyleBoxFlat.new()
			highlight.border_color = SELECTED_BORDER
			highlight.set_border_width_all(3)
			highlight.set_corner_radius_all(6)
			card.add_theme_stylebox_override("panel", highlight)
	else:
		# Remove override → revert to theme default
		card.remove_theme_stylebox_override("panel")

func _show_detail(entry: DungeonListEntry):
	if detail_section:
		detail_section.show()
	if detail_name:
		detail_name.text = entry.get_display_name()
	if detail_desc:
		var desc: String = entry.get_description()
		detail_desc.text = desc if desc != "" else "No description."
		detail_desc.visible = desc != ""
	if detail_stats:
		var def: DungeonDefinition = entry.dungeon_definition
		var parts: Array[String] = []
		parts.append("Level %d" % entry.get_display_level())
		parts.append("%d Floors" % entry.get_floor_count())
		parts.append("Region %d" % def.dungeon_region)
		if def.has_run_affix_pool():
			parts.append("%d Run Affixes" % def.run_affix_pool.size())
		detail_stats.text = "  •  ".join(parts)
	if detail_rewards:
		if entry.reward_preview != "":
			detail_rewards.text = "Rewards: %s" % entry.reward_preview
			detail_rewards.show()
		else:
			detail_rewards.hide()

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_begin_pressed():
	if not _selected_entry or not _selected_entry.dungeon_definition:
		return
	var def: DungeonDefinition = _selected_entry.dungeon_definition
	print("🏰 DungeonSelectionScreen: Selected '%s'" % def.dungeon_name)
	hide()
	dungeon_selected.emit(def)

func _on_close_pressed():
	close()

# ============================================================================
# INPUT — Escape to close
# ============================================================================

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
