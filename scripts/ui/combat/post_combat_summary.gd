# res://scripts/ui/combat/post_combat_summary.gd
# Post-combat results popup with animated XP bar, gold, and interactive loot cards.
# Expects show_summary() called with results dict from GameManager.
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal summary_closed()

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var xp_bar_tween_duration: float = 1.2
@export var level_up_flash_duration: float = 0.6
@export var loot_card_icon_size: float = 80.0
@export var loot_card_columns: int = 3

@export_group("Rarity Glow")
@export var loot_glow_config: RarityGlowConfig

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel

# Rewards
@onready var xp_value_label: Label = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/XPRow/XPValueLabel
@onready var level_label: Label = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/XPBarRow/LevelLabel
@onready var xp_bar: ProgressBar = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/XPBarRow/XPBar
@onready var next_level_label: Label = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/XPBarRow/NextLevelLabel
@onready var level_up_label: Label = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/LevelUpLabel
@onready var gold_value_label: Label = $CenterContainer/Panel/MarginContainer/VBox/RewardsSection/GoldRow/GoldValueLabel

# Loot
@onready var loot_header: Label = $CenterContainer/Panel/MarginContainer/VBox/LootSection/LootHeader
@onready var loot_scroll: ScrollContainer = $CenterContainer/Panel/MarginContainer/VBox/LootSection/LootScroll
@onready var loot_grid: GridContainer = $CenterContainer/Panel/MarginContainer/VBox/LootSection/LootScroll/LootGrid

# Item Detail
@onready var item_detail_panel: PanelContainer = $CenterContainer/Panel/MarginContainer/VBox/ItemDetailPanel
@onready var detail_icon: TextureRect = $CenterContainer/Panel/MarginContainer/VBox/ItemDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailIcon
@onready var detail_name_label: Label = $CenterContainer/Panel/MarginContainer/VBox/ItemDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailNameVBox/DetailNameLabel
@onready var detail_slot_label: Label = $CenterContainer/Panel/MarginContainer/VBox/ItemDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailNameVBox/DetailSlotLabel
@onready var detail_affix_list: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox/ItemDetailPanel/DetailMargin/DetailVBox/DetailAffixList

# Continue
@onready var continue_button: Button = $CenterContainer/Panel/MarginContainer/VBox/ContinueButton

# ============================================================================
# STATE
# ============================================================================
var _selected_item: EquippableItem = null
var _loot_items: Array[EquippableItem] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	continue_button.pressed.connect(_on_continue_pressed)
	overlay.gui_input.connect(_on_overlay_input)
	level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if loot_grid:
		loot_grid.columns = loot_card_columns

# ============================================================================
# PUBLIC API
# ============================================================================

func show_summary(results: Dictionary) -> void:
	"""Display combat results.
	
	results = {
		"victory": bool,
		"xp_gained": int,
		"gold_gained": int,
		"loot": Array[Dictionary],  # each has "item": EquippableItem
		"pre_level": int,           # level BEFORE xp was applied
		"pre_xp": int,              # experience BEFORE xp was applied
		"pre_xp_needed": int,       # xp needed for next level BEFORE
	}
	"""
	print("📊 Showing post-combat summary")

	_setup_title(results.get("victory", false))
	_setup_gold(results.get("gold_gained", 0))
	_setup_loot(results.get("loot", []))
	_hide_item_detail()

	show()

	# Animate XP bar after visible (needs layout to be computed)
	await get_tree().process_frame
	_animate_xp(results)


func _setup_title(victory: bool) -> void:
	if victory:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _setup_gold(gold: int) -> void:
	if gold > 0:
		gold_value_label.text = "+%d" % gold
		gold_value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		gold_value_label.text = "None"
		gold_value_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

# ============================================================================
# XP BAR ANIMATION
# ============================================================================

func _animate_xp(results: Dictionary) -> void:
	"""Animate XP bar from pre-combat state to post-combat state.
	Handles level-up(s) by filling bar → resetting → filling again."""
	var xp_gained: int = results.get("xp_gained", 0)
	var pre_level: int = results.get("pre_level", 1)
	var pre_xp: int = results.get("pre_xp", 0)
	var pre_xp_needed: int = results.get("pre_xp_needed", 100)

	# Show XP gained amount
	if xp_gained > 0:
		xp_value_label.text = "+%d XP" % xp_gained
	else:
		xp_value_label.text = "No XP"
		xp_value_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# Hide level up label initially
	level_up_label.hide()

	# Set initial bar state
	var current_level: int = pre_level
	var current_xp: int = pre_xp
	var current_needed: int = pre_xp_needed

	level_label.text = "Lv %d" % current_level
	next_level_label.text = "Lv %d" % (current_level + 1)
	xp_bar.max_value = current_needed
	xp_bar.value = current_xp

	var xp_remaining: int = xp_gained

	while xp_remaining > 0:
		var xp_to_next: int = current_needed - current_xp
		var xp_this_step: int = mini(xp_remaining, xp_to_next)

		# Tween to target value
		var target_val: float = float(current_xp + xp_this_step)
		var step_ratio: float = float(xp_this_step) / float(maxi(xp_gained, 1))
		var step_duration: float = xp_bar_tween_duration * step_ratio

		var tween = create_tween()
		tween.tween_property(xp_bar, "value", target_val, maxf(step_duration, 0.15)) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

		xp_remaining -= xp_this_step
		current_xp += xp_this_step

		# Check level up
		if current_xp >= current_needed and xp_remaining > 0:
			current_level += 1
			current_xp = 0
			# Get new needed XP from the class formula: level * 100
			current_needed = current_level * 100

			# Flash level up
			_flash_level_up(current_level)
			await get_tree().create_timer(level_up_flash_duration).timeout

			# Reset bar for next level
			level_label.text = "Lv %d" % current_level
			next_level_label.text = "Lv %d" % (current_level + 1)
			xp_bar.max_value = current_needed
			xp_bar.value = 0

	# Final state — read from Player in case of rounding
	_sync_xp_bar_to_player()


func _flash_level_up(new_level: int) -> void:
	"""Show level up notification with a flash."""
	level_up_label.text = "✨ LEVEL UP! Lv %d ✨" % new_level
	level_up_label.show()
	level_up_label.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(level_up_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(level_up_label, "scale", Vector2(1.1, 1.1), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(level_up_label, "scale", Vector2.ONE, 0.1)


func _sync_xp_bar_to_player() -> void:
	"""Set bar to actual player state after animation finishes."""
	if not GameManager or not GameManager.player or not GameManager.player.active_class:
		return
	var pc = GameManager.player.active_class
	level_label.text = "Lv %d" % pc.level
	next_level_label.text = "Lv %d" % (pc.level + 1)
	xp_bar.max_value = pc.get_exp_for_next_level()
	xp_bar.value = pc.experience

# ============================================================================
# LOOT DISPLAY
# ============================================================================

func _setup_loot(loot_array: Array) -> void:
	"""Populate loot grid with interactive item cards."""
	# Clear existing
	for child in loot_grid.get_children():
		child.queue_free()
	_loot_items.clear()

	if loot_array.is_empty():
		loot_header.text = "No Items Found"
		loot_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		loot_scroll.hide()
		return

	loot_header.text = "Items Found (%d)" % loot_array.size()
	loot_header.remove_theme_color_override("font_color")
	loot_scroll.show()

	for loot_entry in loot_array:
		var item: EquippableItem = loot_entry.get("item") if loot_entry is Dictionary else null
		if not item:
			continue
		_loot_items.append(item)
		var card = _create_loot_card(item)
		loot_grid.add_child(card)


func _create_loot_card(item: EquippableItem) -> PanelContainer:
	"""Create an interactive loot card with rarity visuals."""
	var card = RarityDisplayHelper.create_item_summary_card(item, loot_card_icon_size)

	# Make clickable
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_loot_card_input.bind(item, card))
	card.mouse_entered.connect(_on_loot_card_hover.bind(card))
	card.mouse_exited.connect(_on_loot_card_unhover.bind(card))

	# Apply glow if config provided
	if loot_glow_config:
		# Find the icon TextureRect inside the card
		var icon_rect = _find_texture_rect(card)
		if icon_rect:
			RarityDisplayHelper.apply_rarity_glow(icon_rect, item, loot_glow_config)

	return card


func _find_texture_rect(node: Node) -> TextureRect:
	"""Recursively find the first TextureRect child."""
	for child in node.get_children():
		if child is TextureRect:
			return child
		var found = _find_texture_rect(child)
		if found:
			return found
	return null

# ============================================================================
# ITEM DETAIL (tap to inspect)
# ============================================================================

func _show_item_detail(item: EquippableItem) -> void:
	"""Populate and show the item detail panel."""
	_selected_item = item
	item_detail_panel.show()

	# Icon
	if item.icon:
		detail_icon.texture = item.icon
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(RarityDisplayHelper.get_rarity_color(item) * 0.5)
		detail_icon.texture = ImageTexture.create_from_image(img)
	RarityDisplayHelper.apply_rarity_shader(detail_icon, item)

	# Name + rarity color
	detail_name_label.text = item.item_name
	detail_name_label.add_theme_color_override("font_color",
		RarityDisplayHelper.get_rarity_color(item))

	# Slot + rarity label
	detail_slot_label.text = "%s — %s" % [item.get_slot_name(), item.get_rarity_name()]

	# Affixes
	for child in detail_affix_list.get_children():
		child.queue_free()

	if item.item_affixes.size() > 0:
		for affix in item.item_affixes:
			if affix:
				var affix_panel = RarityDisplayHelper.create_affix_label(affix)
				detail_affix_list.add_child(affix_panel)
	else:
		var no_affix = Label.new()
		no_affix.text = "No affixes"
		no_affix.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		no_affix.add_theme_font_size_override("font_size", 12)
		detail_affix_list.add_child(no_affix)


func _hide_item_detail() -> void:
	_selected_item = null
	item_detail_panel.hide()

# ============================================================================
# INPUT HANDLERS
# ============================================================================

func _on_loot_card_input(event: InputEvent, item: EquippableItem, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_item == item:
			_hide_item_detail()
		else:
			_show_item_detail(item)


func _on_loot_card_hover(card: PanelContainer) -> void:
	var tween = card.create_tween()
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)


func _on_loot_card_unhover(card: PanelContainer) -> void:
	var tween = card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.1)


func _on_continue_pressed() -> void:
	print("📊 Summary closed via Continue")
	hide()
	_hide_item_detail()
	summary_closed.emit()


func _on_overlay_input(event: InputEvent) -> void:
	# Don't close on overlay click — require Continue button
	pass


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
