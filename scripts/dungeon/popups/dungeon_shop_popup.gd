# res://scripts/dungeon/popups/dungeon_shop_popup.gd
extends DungeonPopupBase

var _items: Array = []
var _purchased: Array = []
var _run: DungeonRun = null
var _buy_buttons: Array = []  # [{btn, price}] for affordability refresh

@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var items_container = $CenterContainer/Panel/VBox/ScrollContainer/ItemsContainer
@onready var gold_label: Label = $CenterContainer/Panel/VBox/GoldLabel

func show_popup(data: Dictionary) -> void:
	_base_show(data, "shop")
	_items = data.get("items", [])
	_run = data.get("run")
	_purchased.clear()
	_buy_buttons.clear()

	_refresh_gold()

	for child in items_container.get_children():
		child.queue_free()

	for item in _items:
		var price = _calculate_price(item)
		var foldable = FoldableContainer.new()
		foldable.title = "%s — %dg" % [_get_item_name(item), price]
		foldable.add_child(_build_item_detail(item, price, foldable))
		items_container.add_child(foldable)


func _build_item_detail(item, price: int, foldable: FoldableContainer) -> VBoxContainer:
	var detail = VBoxContainer.new()

	if item is EquippableItem:
		# Rarity + slot header
		var header = Label.new()
		header.text = "%s  •  %s" % [item.get_rarity_name(), item.get_slot_name()]
		header.add_theme_color_override("font_color", item.get_rarity_color())
		detail.add_child(header)

		# Affix layers
		for affix in item.base_stat_affixes:
			detail.add_child(_make_affix_label(affix, Color(0.7, 0.85, 1.0)))
		for affix in item.inherent_affixes:
			detail.add_child(_make_affix_label(affix, Color(0.4, 0.9, 0.4)))
		for affix in item.rolled_affixes:
			detail.add_child(_make_affix_label(affix, Color(0.9, 0.7, 0.3)))

	elif item is ConsumableItem:
		var desc = DescriptionParser.make_rich_label(
			item.description if item.description else "No description")
		detail.add_child(desc)

	var buy_btn = Button.new()
	buy_btn.text = "Buy (%dg)" % price
	var player = GameManager.player
	buy_btn.disabled = (not player or player.gold < price)
	buy_btn.pressed.connect(_on_buy.bind(item, price, foldable))
	detail.add_child(buy_btn)
	_buy_buttons.append({"btn": buy_btn, "price": price})

	return detail


func _make_affix_label(affix: Affix, color: Color) -> RichTextLabel:
	return DescriptionParser.make_rich_label(affix.get_resolved_description(), color)


func _on_buy(item, price: int, foldable: FoldableContainer):
	var player = GameManager.player
	if not player or player.gold < price:
		return
	player.add_gold(-price)
	if item is ConsumableItem:
		player.add_consumable(item)
	else:
		player.add_to_inventory(item)
	_purchased.append(item)
	_run.track_gold(-price)
	foldable.queue_free()
	_refresh_gold()


func _calculate_price(item) -> int:
	if item is ConsumableItem:
		return maxi(item.base_value, 5)
	var base = 20
	if item is EquippableItem:
		match item.rarity:
			EquippableItem.Rarity.UNCOMMON: base = 40
			EquippableItem.Rarity.RARE: base = 80
			EquippableItem.Rarity.EPIC: base = 150
			EquippableItem.Rarity.LEGENDARY: base = 300
	return base


func _get_item_name(item) -> String:
	if item is ConsumableItem:
		return item.item_name if item.item_name else "Consumable"
	if item is EquippableItem:
		return item.item_name if item.item_name else "Equipment"
	return "Unknown Item"


func _refresh_gold():
	if gold_label and GameManager.player:
		gold_label.text = "Gold: %d" % GameManager.player.gold
	var gold = GameManager.player.gold if GameManager.player else 0
	_buy_buttons = _buy_buttons.filter(func(e): return is_instance_valid(e["btn"]))
	for entry in _buy_buttons:
		entry["btn"].disabled = gold < entry["price"]


func _build_result() -> Dictionary:
	return {"purchased": _purchased}
