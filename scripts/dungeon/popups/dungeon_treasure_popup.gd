# res://scripts/dungeon/popups/dungeon_treasure_popup.gd
## Treasure chest popup. Displays gold found and any items.
## Items are already added to inventory before this popup opens
## (handled by DungeonScene._handle_treasure), so this is display-only.
##
## Data in:  { "node": DungeonNodeData, "item": EquippableItem or null, "run": DungeonRun }
## Result:   {}
extends DungeonPopupBase

var _item: EquippableItem = null

# ============================================================================
# NODE REFERENCES — match dungeon_treasure_popup.tscn paths exactly
# ============================================================================
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var gold_section: HBoxContainer = $CenterContainer/Panel/VBox/GoldSection
@onready var gold_label: Label = $CenterContainer/Panel/VBox/GoldSection/GoldLabel
@onready var loot_section: VBoxContainer = $CenterContainer/Panel/VBox/LootSection
@onready var loot_grid: GridContainer = $CenterContainer/Panel/VBox/LootSection/ScrollContainer/LootGrid

# ============================================================================
# ABSTRACT IMPLEMENTATION
# ============================================================================

func show_popup(data: Dictionary) -> void:
	_base_show(data, "treasure")
	_item = data.get("item") as EquippableItem
	var run: DungeonRun = data.get("run")

	# --- Gold display ---
	# Treasure nodes grant some bonus gold (use definition's combat gold as baseline)
	var treasure_gold: int = 0
	if run and run.definition:
		treasure_gold = int(run.definition.gold_per_combat * 1.5)
	if treasure_gold > 0:
		if gold_section: gold_section.show()
		if gold_label: gold_label.text = "+%d Gold" % treasure_gold
		# Apply the gold (DungeonScene doesn't do this for treasure, so popup handles it)
		if run:
			var player = GameManager.player if GameManager else null
			if player:
				player.add_gold(treasure_gold)
				run.track_gold(treasure_gold)
	else:
		if gold_section: gold_section.hide()

	# --- Item display ---
	# Clear previous items
	for child in loot_grid.get_children():
		child.queue_free()

	if _item:
		if loot_section: loot_section.show()
		var item_panel = _create_item_display(_item)
		loot_grid.add_child(item_panel)
	else:
		if loot_section: loot_section.hide()

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
