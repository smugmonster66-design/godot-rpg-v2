# res://resources/data/quest_rewards.gd
# Rewards granted upon quest completion.
extends Resource
class_name QuestRewards

# ============================================================================
# BASIC REWARDS
# ============================================================================
@export_group("Basic")
@export var experience: int = 0
@export var gold: int = 0

# ============================================================================
# ITEM REWARDS
# ============================================================================
@export_group("Items")
## Item templates granted on completion (EquippableItem or ConsumableItem).
## Equipment is rolled like a drop (affixes, level, region); consumables stack.
## List a template twice to grant two.
@export var reward_items: Array[Resource] = []
## Item level for rolled equipment. 0 = the player's level.
@export var reward_item_level: int = 0
## LEGACY, don't use: ItemReward is an inner class, which Godot can't save in a
## .tres, so these never work from a file. Use reward_items.
@export var items: Array[ItemReward] = []
## Items the player can choose from (pick N)
@export var choice_items: Array[ItemReward] = []
## How many items can be chosen from choice_items
@export var choice_count: int = 1

# ============================================================================
# PROGRESSION REWARDS
# ============================================================================
@export_group("Progression")
## Story flags to set true on completion
@export var unlock_flags: Array[StringName] = []
## Location nodes to unlock/reveal
@export var unlock_locations: Array[StringName] = []
## Quests to make available
@export var unlock_quests: Array[StringName] = []

# ============================================================================
# RELATIONSHIP REWARDS
# ============================================================================
@export_group("Relationships")
## NPC affinity changes: { npc_id: delta }
@export var relationship_changes: Dictionary = {}

# ============================================================================
# COMPANION REWARDS
# ============================================================================
@export_group("Companions")
## Companions who join on completion (party if there's room, else camp).
@export var recruit_companions: Array[CompanionData] = []
## companion_ids who leave on completion.
@export var dismiss_companions: Array[StringName] = []
## companion_ids whose bond die is upgraded (a personal quest's ending).
@export var upgrade_companion_bonds: Array[StringName] = []

# ============================================================================
# COUNTER REWARDS
# ============================================================================
@export_group("Counters")
## Counter changes on quest completion: { counter_name: delta }
## Used for morality shifts (virtue, order) and any other counters.
@export var counter_changes: Dictionary = {}

# ============================================================================
# PREVIEW
# ============================================================================

func get_preview_text() -> String:
	"""Get a summary of rewards for quest log display."""
	var parts: Array[String] = []
	
	if experience > 0:
		parts.append("%d XP" % experience)
	if gold > 0:
		parts.append("%d Gold" % gold)
	if reward_items.size() > 0:
		parts.append("%d item(s)" % reward_items.size())
	elif items.size() > 0:
		parts.append("%d item(s)" % items.size())
	if choice_items.size() > 0:
		parts.append("Choose %d item(s)" % choice_count)
	
	if parts.is_empty():
		return "No rewards"
	return ", ".join(parts)


# ============================================================================
# ITEM REWARD SUB-RESOURCE
# ============================================================================

class ItemReward extends Resource:
	## Item resource or item_id to grant
	@export var item_id: StringName = &""
	## How many to grant
	@export var quantity: int = 1
	## If set, loads this resource directly instead of looking up by ID
	@export var item_resource: Resource = null
