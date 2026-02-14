# res://scripts/dungeon/popups/dungeon_shop_popup.gd
extends DungeonPopupBase

var _items: Array[EquippableItem] = []
var _purchased: Array[EquippableItem] = []
var _run: DungeonRun = null

@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var items_container = $CenterContainer/Panel/VBox/ScrollContainer/ItemsContainer
@onready var gold_label: Label = $CenterContainer/Panel/VBox/GoldLabel

func show_popup(data: Dictionary) -> void:
	_base_show(data, "shop")
	_items = data.get("items", [])
	_run = data.get("run")
	_purchased.clear()

	_refresh_gold()

	# Clear existing shop items
	for child in items_container.get_children():
		child.queue_free()

	# Build a FoldableContainer (4.5) for each shop item
	for i in _items.size():
		var item = _items[i]
		var price = _calculate_price(item)

		# FoldableContainer — accordion, only one open at a time via group
		var foldable = FoldableContainer.new()
		foldable.title = "%s — %dg" % [item.item_name, price]
		foldable.group = "shop_items"  # 4.5: only one open at a time

		# Item detail panel (child of the foldable)
		var detail = VBoxContainer.new()
		var desc = Label.new()
		desc.text = item.description if item.description else "No description"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(desc)

		var buy_btn = Button.new()
		buy_btn.text = "Buy (%dg)" % price
		buy_btn.pressed.connect(_on_buy.bind(i, price))
		detail.add_child(buy_btn)

		foldable.add_child(detail)
		items_container.add_child(foldable)

func _on_buy(index: int, price: int):
	var player = GameManager.player
	if not player or player.gold < price: return
	var item = _items[index]
	player.add_gold(-price)
	player.add_to_inventory(item)
	_purchased.append(item)
	_run.track_gold(-price)
	_refresh_gold()
	# Disable the buy button (find it in the foldable)
	var foldable = items_container.get_child(index)
	if foldable:
		var btn = foldable.find_child("", false, false)  # find the Button
		for child in foldable.get_children():
			var buy = child.find_child("", false, false)
			# Simpler: just remove the foldable
		foldable.title += " [SOLD]"
		for child in foldable.get_children():
			child.queue_free()

func _calculate_price(item: EquippableItem) -> int:
	var base = 20
	match item.rarity:
		EquippableItem.Rarity.UNCOMMON: base = 40
		EquippableItem.Rarity.RARE: base = 80
		EquippableItem.Rarity.EPIC: base = 150
		EquippableItem.Rarity.LEGENDARY: base = 300
	return base

func _refresh_gold():
	if gold_label and GameManager.player:
		gold_label.text = "Gold: %d" % GameManager.player.gold

func _build_result() -> Dictionary:
	return {"purchased": _purchased}
