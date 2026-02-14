# res://scripts/dungeon/popups/dungeon_complete_popup.gd
## Dungeon completion summary. Displays dungeon name, floors cleared,
## total gold/exp earned, and all items found during the run.
## All rewards are already applied before this popup opens.
##
## Data in:  { "type": "complete", "run": DungeonRun }
## Result:   {}
extends DungeonPopupBase

var _run: DungeonRun = null

# ============================================================================
# NODE REFERENCES — match dungeon_complete_popup.tscn paths exactly
# ============================================================================
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var dungeon_name_label: Label = $CenterContainer/Panel/VBox/SummarySection/DungeonNameLabel
@onready var floors_label: Label = $CenterContainer/Panel/VBox/SummarySection/FloorsLabel
@onready var gold_label: Label = $CenterContainer/Panel/VBox/RewardsSection/GoldRow/GoldLabel
@onready var exp_label: Label = $CenterContainer/Panel/VBox/RewardsSection/ExpRow/ExpLabel
@onready var items_section: VBoxContainer = $CenterContainer/Panel/VBox/ItemsSection
@onready var items_grid: GridContainer = $CenterContainer/Panel/VBox/ItemsSection/ScrollContainer/ItemsGrid

# ============================================================================
# ABSTRACT IMPLEMENTATION
# ============================================================================

func show_popup(data: Dictionary) -> void:
	_base_show(data, "complete")
	_run = data.get("run") as DungeonRun

	if not _run:
		push_warning("CompletePopup: No run data")
		return

	# --- Summary ---
	if dungeon_name_label and _run.definition:
		dungeon_name_label.text = _run.definition.dungeon_name

	if floors_label and _run.definition:
		floors_label.text = "Floors Cleared: %d / %d" % [
			_run.current_floor + 1, _run.definition.floor_count]

	# --- Rewards ---
	if gold_label:
		gold_label.text = "Gold Earned: +%d" % _run.gold_earned

	if exp_label:
		exp_label.text = "Exp Earned: +%d" % _run.exp_earned

	# --- Items ---
	# Clear previous
	for child in items_grid.get_children():
		child.queue_free()

	if _run.items_earned.size() > 0:
		if items_section: items_section.show()
		for item in _run.items_earned:
			var panel = _create_item_display(item)
			items_grid.add_child(panel)
	else:
		if items_section: items_section.hide()

func _build_result() -> Dictionary:
	return {}

# ============================================================================
# ITEM DISPLAY HELPER
# ============================================================================

func _create_item_display(item: EquippableItem) -> PanelContainer:
	"""Creates a simple item display panel. Replace with your project's
	item display scene once available."""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 60)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Item name — colored by rarity
	var name_label = Label.new()
	name_label.text = item.item_name if item.item_name != "" else "Unknown Item"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", _get_rarity_color(item))
	vbox.add_child(name_label)

	# Item type / slot
	var type_label = Label.new()
	type_label.text = _get_slot_name(item)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(type_label)

	# Affix count hint
	if item.affixes.size() > 0:
		var affix_label = Label.new()
		affix_label.text = "%d affix%s" % [item.affixes.size(),
			"es" if item.affixes.size() != 1 else ""]
		affix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		affix_label.add_theme_font_size_override("font_size", 11)
		affix_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(affix_label)

	panel.add_child(vbox)
	return panel

func _get_rarity_color(item: EquippableItem) -> Color:
	if not "rarity" in item: return Color.WHITE
	match item.rarity:
		EquippableItem.Rarity.COMMON: return Color(0.9, 0.9, 0.9)
		EquippableItem.Rarity.UNCOMMON: return Color(0.3, 0.9, 0.3)
		EquippableItem.Rarity.RARE: return Color(0.3, 0.5, 1.0)
		EquippableItem.Rarity.EPIC: return Color(0.7, 0.3, 0.9)
		EquippableItem.Rarity.LEGENDARY: return Color(1.0, 0.7, 0.2)
		_: return Color.WHITE

func _get_slot_name(item: EquippableItem) -> String:
	if item.has_method("get_slot_name"):
		return item.get_slot_name()
	if "slot" in item:
		return str(item.slot).capitalize()
	return "Equipment"
