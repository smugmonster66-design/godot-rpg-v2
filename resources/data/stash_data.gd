# res://resources/data/stash_data.gd
# Persistent stash/bank storage for items the player wants to keep but not carry.
# Lives on SaveData and is serialized automatically via ResourceSaver.
extends Resource
class_name StashData

signal stash_changed()

# ============================================================================
# STORAGE
# ============================================================================

## Equipment items stored in the stash (inline sub-resources).
@export var equipment: Array[EquippableItem] = []

## Consumables stored by path + stack count (mirrors SaveData pattern).
## Each entry: { "path": String, "stack": int }
@export var consumables: Array[Dictionary] = []

# ============================================================================
# CAPACITY
# ============================================================================

## Maximum number of equipment items the stash can hold.
@export var max_equipment_slots: int = 50

## Maximum number of distinct consumable stacks the stash can hold.
@export var max_consumable_stacks: int = 20

# ============================================================================
# EQUIPMENT API
# ============================================================================

func add_equipment(item: EquippableItem) -> bool:
	if is_equipment_full():
		return false
	equipment.append(item)
	stash_changed.emit()
	return true

func remove_equipment(item: EquippableItem) -> void:
	var idx = equipment.find(item)
	if idx >= 0:
		equipment.remove_at(idx)
		stash_changed.emit()

func is_equipment_full() -> bool:
	return equipment.size() >= max_equipment_slots

func get_equipment_count() -> int:
	return equipment.size()

# ============================================================================
# CONSUMABLE API
# ============================================================================

func add_consumable(item: ConsumableItem) -> bool:
	var path = item.resource_path
	# Try to stack with existing entry
	for entry in consumables:
		if entry.get("path", "") == path:
			entry["stack"] = entry.get("stack", 0) + item.current_stack
			stash_changed.emit()
			return true
	# New stack — check capacity
	if consumables.size() >= max_consumable_stacks:
		return false
	consumables.append({"path": path, "stack": item.current_stack})
	stash_changed.emit()
	return true

func remove_consumable(path: String, count: int = 1) -> void:
	for i in range(consumables.size() - 1, -1, -1):
		var entry = consumables[i]
		if entry.get("path", "") == path:
			entry["stack"] = entry.get("stack", 0) - count
			if entry["stack"] <= 0:
				consumables.remove_at(i)
			stash_changed.emit()
			return

func get_consumable_items() -> Array[ConsumableItem]:
	var result: Array[ConsumableItem] = []
	for entry in consumables:
		var path = entry.get("path", "")
		if path == "":
			continue
		var res = load(path)
		if res is ConsumableItem:
			var item = res.duplicate() as ConsumableItem
			item.current_stack = entry.get("stack", 1)
			result.append(item)
	return result

func get_consumable_count() -> int:
	return consumables.size()

func is_consumable_full() -> bool:
	return consumables.size() >= max_consumable_stacks
