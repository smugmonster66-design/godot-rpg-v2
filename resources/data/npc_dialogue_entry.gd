# res://resources/data/npc_dialogue_entry.gd
# A single entry in an NPC's dialogue table.
# NPCManager evaluates these in priority order — first match wins.
extends Resource
class_name NPCDialogueEntry

## Unique identifier for this entry (used to track seen/unseen state).
## Must be unique within an NPC's dialogue table.
@export var encounter_id: StringName = &""

## The dialogue encounter to play when this entry is selected.
@export var encounter: DialogueEncounter = null

## When set, this entry is only available if the condition is met.
## When null, the entry is always available.
@export var condition: GameCondition = null

## If true, this entry is removed from consideration after being seen once.
@export var one_shot: bool = false

## Higher priority entries are evaluated first. Entries with the same priority
## are evaluated in array order.
@export var priority: int = 0

## Optional icon for this conversation entry (shown in conversation sub-radial).
## Falls back to NPCDefinition.default_dialogue_icon if null.
@export var icon: Texture2D = null
