# res://scripts/shared/item_grant.gd
# One place that gives the player items outside combat loot: quest rewards,
# GameEvent effects, and the dialogue GRANT_ITEM action all go through here.
#
#   ItemGrant.grant(load("res://resources/items/.../salve.tres"))        # 1 item
#   ItemGrant.grant(template, 3)                                          # 3 copies
#   ItemGrant.remove_by_name("Margery's Mackerel")                        # take one back
#
# EquippableItem templates are rolled through LootManager.generate_drop (affixes,
# item level, region) exactly like a drop. ConsumableItem templates are copied and
# stacked. Anything else is refused with a warning.
extends RefCounted
class_name ItemGrant


static func _game_manager() -> Node:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameManager")
	return null


static func grant(template: Resource, quantity: int = 1, item_level: int = -1, region: int = -1) -> Array:
	"""Give the player `quantity` of `template`. Returns the items created.
	item_level / region default to the player's level and the active region."""
	var created: Array = []
	var gm := _game_manager()
	if gm == null or gm.player == null:
		push_warning("ItemGrant.grant: no player")
		return created
	if template == null:
		push_warning("ItemGrant.grant: template is null")
		return created
	var player = gm.player
	var lvl: int = item_level if item_level > 0 else max(1, int(player.level))
	var reg: int = region if region > 0 else int(gm.get("active_region") if gm.get("active_region") != null else 1)

	for i in max(1, quantity):
		if template is EquippableItem:
			var loot = gm.get_node_or_null("/root/LootManager")
			var result: Dictionary = loot.generate_drop(template, lvl, reg) if loot else {}
			var item: EquippableItem = result.get("item")
			if item:
				player.add_to_inventory(item)
				created.append(item)
		elif template is ConsumableItem:
			var copy: ConsumableItem = template.duplicate(true)
			player.add_consumable(copy)
			created.append(copy)
		else:
			push_warning("ItemGrant.grant: %s is not an EquippableItem or ConsumableItem" % template)
			break
	return created


static func remove_by_name(item_name: String, quantity: int = 1) -> int:
	"""Take up to `quantity` items with this display name from the player
	(equipment inventory first, then consumables). Returns how many were removed.
	Items are identified by name, the same way HAS_ITEM conditions count them."""
	var gm := _game_manager()
	if gm == null or gm.player == null:
		return 0
	var player = gm.player
	var removed := 0
	for item in player.inventory.duplicate():
		if removed >= quantity:
			break
		if item and item.item_name == item_name:
			player.remove_from_inventory(item)
			removed += 1
	for c in player.consumables.duplicate():
		while removed < quantity and c and c.item_name == item_name and player.consumables.has(c):
			player.remove_consumable(c)
			removed += 1
	return removed


static func heal_player(amount: int = 0, percent: float = 0.0) -> int:
	"""Heal the player by a flat amount and/or a fraction of max HP.
	Returns the HP actually restored."""
	var gm := _game_manager()
	if gm == null or gm.player == null:
		return 0
	var player = gm.player
	var total: int = amount + int(round(player.max_hp * clampf(percent, 0.0, 1.0)))
	var before: int = player.current_hp
	if total > 0:
		player.heal(total)
	return player.current_hp - before
