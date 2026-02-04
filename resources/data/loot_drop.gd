# loot_drop.gd - Single entry in a loot table
extends Resource
class_name LootDrop

# ============================================================================
# ENUMS
# ============================================================================
enum DropType {
	ITEM,        # Drops an item
	CURRENCY,    # Drops gold/currency
	TABLE,       # References another loot table
	NOTHING      # Explicitly drops nothing
}

# ============================================================================
# DROP TYPE
# ============================================================================
@export var drop_type: DropType = DropType.ITEM

# ============================================================================
# ITEM DROP SETTINGS (if drop_type = ITEM)
# ============================================================================
@export_group("Item Settings")
@export var item_template: EquippableItem = null

# Quantity range
@export var quantity_min: int = 1
@export var quantity_max: int = 1

# Rarity override (-1 = use item's default rarity)
@export var force_rarity: int = -1  # -1 or EquippableItem.Rarity enum values

# ============================================================================
# CURRENCY DROP SETTINGS (if drop_type = CURRENCY)
# ============================================================================
@export_group("Currency Settings")
@export var currency_min: int = 0
@export var currency_max: int = 0

# ============================================================================
# NESTED TABLE SETTINGS (if drop_type = TABLE)
# ============================================================================
@export_group("Nested Table Settings")
@export var nested_table: LootTable = null

# ============================================================================
# DROP WEIGHT & FLAGS
# ============================================================================
@export_group("Drop Properties")
@export var drop_weight: int = 100  # Higher = more likely
@export var is_guaranteed: bool = false  # If true, always drops (ignores weight)

# ============================================================================
# UTILITY
# ============================================================================

func get_quantity() -> int:
	"""Roll random quantity within range"""
	if quantity_min == quantity_max:
		return quantity_min
	return randi_range(quantity_min, quantity_max)

func get_currency_amount() -> int:
	"""Roll random currency amount within range"""
	if currency_min == currency_max:
		return currency_min
	return randi_range(currency_min, currency_max)

func get_display_name() -> String:
	"""Get human-readable name for editor"""
	match drop_type:
		DropType.ITEM:
			if item_template:
				return "%s (x%d-%d)" % [item_template.item_name, quantity_min, quantity_max]
			return "No Item Set"
		DropType.CURRENCY:
			return "Gold: %d-%d" % [currency_min, currency_max]
		DropType.TABLE:
			if nested_table:
				return "Table: %s" % nested_table.table_name
			return "No Table Set"
		DropType.NOTHING:
			return "Nothing"
	return "Unknown"

func is_valid() -> bool:
	"""Check if this drop is properly configured"""
	match drop_type:
		DropType.ITEM:
			return item_template != null
		DropType.CURRENCY:
			return currency_max > 0
		DropType.TABLE:
			return nested_table != null
		DropType.NOTHING:
			return true
	return false
