# res://resources/data/dungeon_chain.gd
# A sequential chain of dungeons. The player completes them in order.
# Used as the dungeon_chain field on MapNodeButtonDef.
extends Resource
class_name DungeonChain

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique identifier for this chain
@export var chain_id: StringName = &""
## Display name shown in UI
@export var chain_name: String = ""
## Description shown in UI
@export_multiline var description: String = ""
## Icon for this chain
@export var icon: Texture2D = null

# ============================================================================
# DUNGEONS
# ============================================================================
@export_group("Dungeons")
## Dungeons to complete in order (index 0 is first)
@export var dungeons: Array[DungeonDefinition] = []
## If true, repeat the last dungeon indefinitely after the chain is completed
@export var repeat_last_on_completion: bool = false

# ============================================================================
# CHAIN CLEAR REWARDS
# ============================================================================
@export_group("Chain Clear Rewards")
## Bonus gold awarded only when the entire chain is completed in one session
@export var chain_clear_gold: int = 0
## Bonus XP awarded only when the entire chain is completed in one session
@export var chain_clear_exp: int = 0
## Bonus item awarded only when the entire chain is completed in one session
@export var chain_clear_item: EquippableItem = null

# ============================================================================
# API
# ============================================================================

func get_dungeon_for_run(completed_count: int) -> DungeonDefinition:
	"""Get the dungeon to run next given how many in the chain are already done."""
	if dungeons.is_empty():
		return null
	if completed_count < dungeons.size():
		return dungeons[completed_count]
	if repeat_last_on_completion:
		return dungeons[-1]
	return null

func is_complete(completed_count: int) -> bool:
	"""Returns true if all dungeons have been completed and no repeat."""
	if repeat_last_on_completion:
		return false
	return completed_count >= dungeons.size()

func get_dungeon_count() -> int:
	return dungeons.size()

func get_dungeon(index: int) -> DungeonDefinition:
	if index < 0 or index >= dungeons.size():
		return null
	return dungeons[index]

func get_display_name() -> String:
	return chain_name if chain_name != "" else str(chain_id)

func validate() -> Array[String]:
	var warnings: Array[String] = []
	if chain_id == &"":
		warnings.append("Missing chain_id")
	if dungeons.size() < 2:
		warnings.append("Chain needs at least 2 dungeons")
	for i in dungeons.size():
		if not dungeons[i]:
			warnings.append("Null dungeon at index %d" % i)
	return warnings
