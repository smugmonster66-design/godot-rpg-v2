# res://scripts/dungeon/popups/run_affix_choice_popup.gd
## Roguelite affix choice popup. Presents N affix cards; player picks one
## or skips for a small bonus. Used at dungeon entry and after elite kills.
##
## Data in:  { "run": DungeonRun, "offers": Array[RunAffixEntry],
##             "trigger": String, "skip_gold": int }
## Result:   { "chosen": RunAffixEntry or null, "skipped": bool }
extends DungeonPopupBase

var _offers: Array[RunAffixEntry] = []
var _chosen: RunAffixEntry = null
var _skipped: bool = false
var _skip_gold: int = 0
var _cards: Array[PanelContainer] = []
var _selected_index: int = -1

# ============================================================================
# NODE REFERENCES — match run_affix_choice_popup.tscn
# ============================================================================
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/Panel/VBox/SubtitleLabel
@onready var card_container: VBoxContainer = $CenterContainer/Panel/VBox/ScrollContainer/CardContainer
@onready var confirm_button: Button = $CenterContainer/Panel/VBox/ButtonRow/ConfirmButton
@onready var skip_button: Button = $CenterContainer/Panel/VBox/ButtonRow/SkipButton
var _trigger: String = ""

# ============================================================================
# SELECTION HIGHLIGHT — only these override the theme
# ============================================================================
const SELECTED_BORDER_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	super._ready()
	if confirm_button: confirm_button.pressed.connect(_on_confirm)
	if skip_button: skip_button.pressed.connect(_on_skip)

# ============================================================================
# ABSTRACT IMPLEMENTATION
# ============================================================================

func show_popup(data: Dictionary) -> void:
	_base_show(data, "run_affix")
	_offers = []; _chosen = null; _skipped = false; _selected_index = -1
	_skip_gold = data.get("skip_gold", 0)
	_trigger = data.get("trigger", "entry")

	var raw_offers = data.get("offers", [])
	for entry in raw_offers:
		if entry is RunAffixEntry: _offers.append(entry)

	# Title based on trigger
	var trigger: String = data.get("trigger", "entry")
	if title_label:
		match trigger:
			"entry": title_label.text = "Dungeon Blessing"
			"elite": title_label.text = "Elite Vanquished"
			"boss":  title_label.text = "Boss Conquered"
			_:       title_label.text = "Choose a Blessing"

	if subtitle_label:
		subtitle_label.text = "Choose one to empower your run"

	if skip_button:
		skip_button.text = "Skip (+%d Gold)" % _skip_gold if _skip_gold > 0 else "Skip"
		skip_button.visible = true

	if confirm_button:
		confirm_button.disabled = true
		confirm_button.text = "Confirm"

	_clear_cards()
	_build_cards()

func _build_result() -> Dictionary:
	return { "chosen": _chosen, "skipped": _skipped, "trigger": _trigger }

# ============================================================================
# CARD CONSTRUCTION — theme-inherited, no hard-coded styles
# ============================================================================

func _clear_cards():
	_cards.clear()
	if not card_container: return
	for child in card_container.get_children(): child.queue_free()

func _build_cards():
	if not card_container: return
	for i in _offers.size():
		var card: PanelContainer = _create_card(_offers[i], i)
		card_container.add_child(card)
		_cards.append(card)

func _create_card(entry: RunAffixEntry, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	# Icon (if present)
	if entry.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = entry.icon
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)

	# Text column
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(text_vbox)

	# Name + rarity on same row
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	text_vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = entry.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = entry.get_rarity_name()
	rarity_label.modulate = entry.get_rarity_color()
	rarity_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_hbox.add_child(rarity_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = entry.get_display_text()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_child(desc_label)

	# Type tag
	var type_label := Label.new()
	match entry.affix_type:
		RunAffixEntry.AffixType.DICE:   type_label.text = "⬡ Dice Effect"
		RunAffixEntry.AffixType.STAT:   type_label.text = "◆ Stat Bonus"
		RunAffixEntry.AffixType.HYBRID: type_label.text = "⬡◆ Hybrid"
	type_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	text_vbox.add_child(type_label)

	# Invisible click overlay
	var click_btn := Button.new()
	click_btn.flat = true
	click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s_name in ["normal", "hover", "pressed", "focus"]:
		click_btn.add_theme_stylebox_override(s_name, empty)
	click_btn.pressed.connect(_on_card_pressed.bind(index))
	card.add_child(click_btn)

	return card

# ============================================================================
# SELECTION — minimal override, theme provides the base
# ============================================================================

func _on_card_pressed(index: int):
	if index < 0 or index >= _offers.size(): return
	_selected_index = index
	_chosen = _offers[index]
	_skipped = false

	for i in _cards.size():
		_set_card_selected(_cards[i], i == index, _offers[i])

	if confirm_button:
		confirm_button.disabled = false
		confirm_button.text = "Choose: %s" % _chosen.display_name

func _set_card_selected(card: PanelContainer, selected: bool, entry: RunAffixEntry):
	if selected:
		# Override theme stylebox with highlighted border
		var base: StyleBox = card.get_theme_stylebox("panel")
		if base and base is StyleBoxFlat:
			var highlight: StyleBoxFlat = base.duplicate()
			highlight.border_color = entry.get_rarity_color().lerp(SELECTED_BORDER_COLOR, 0.5)
			highlight.set_border_width_all(3)
			card.add_theme_stylebox_override("panel", highlight)
		else:
			# Fallback: create minimal highlight
			var highlight := StyleBoxFlat.new()
			highlight.border_color = SELECTED_BORDER_COLOR
			highlight.set_border_width_all(3)
			highlight.set_corner_radius_all(6)
			card.add_theme_stylebox_override("panel", highlight)
	else:
		# Remove override → revert to theme default
		card.remove_theme_stylebox_override("panel")

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_confirm():
	if _chosen == null: return
	_skipped = false
	_on_close()

func _on_skip():
	_chosen = null; _skipped = true; _selected_index = -1
	_on_close()
