# res://resources/data/map_node_button_def.gd
# Defines a single button in a map node's radial action menu.
# Add new ButtonCategory values freely — existing .tres files are unaffected.
extends Resource
class_name MapNodeButtonDef

enum ButtonCategory {
	QUESTS,        # Opens quest grid popup
	NPCS,          # Replaces radial with NPC sub-radial
	ENTER_DUNGEON, # Enters a DungeonDefinition or DungeonChain
	ENTER_ZONE,    # Transfers to a Zone sub-map
	REST,          # Heals player (optionally costs gold)
	PARTY,         # Replaces radial with companion management sub-radial
	STASH,         # Opens stash/bank interface
	TRAVEL,        # Auto-injected: moves the player to this node along the path
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## What this button does
@export var button_category: ButtonCategory = ButtonCategory.ENTER_DUNGEON
## Override display label (empty = use default for category)
@export var label: String = ""
## Background / plate texture drawn behind the icon
@export var button_texture: Texture2D = null
## Icon texture (empty = falls back to the scene-level fallback_icon)
@export var icon: Texture2D = null
## Tooltip shown on hover
@export var tooltip: String = ""

# ============================================================================
# VISIBILITY / AVAILABILITY
# ============================================================================
@export_group("Condition")
## If set, button is hidden or disabled when condition is not met
@export var condition: GameCondition = null
## If true, hide the button when condition fails; if false, show it disabled
@export var hide_when_condition_fails: bool = false

# ============================================================================
# ENTER_DUNGEON DATA
# ============================================================================
@export_group("Dungeon")
## Single dungeon to enter (used if dungeon_chain is null)
@export var dungeon_definition: DungeonDefinition = null
## Chain of dungeons to enter in sequence (takes priority over dungeon_definition)
@export var dungeon_chain: DungeonChain = null

# ============================================================================
# ENTER_ZONE DATA
# ============================================================================
@export_group("Zone")
## The sub-map to load when this button is pressed.
## Drag a MapDefinition .tres file here.
@export var sub_map: MapDefinition = null

# ============================================================================
# NPC DATA
# ============================================================================
@export_group("NPC")
## When set, this NPCS button talks to a specific NPC instead of opening the
## NPC list sub-radial. Used for dynamically-created sub-radial entries.
@export var npc_id: StringName = &""
## When set alongside npc_id, plays this specific encounter instead of
## evaluating the dialogue table. Used by the conversation sub-radial.
@export var encounter_id: StringName = &""

# ============================================================================
# REST DATA
# ============================================================================
@export_group("Rest")
## Gold cost to rest (0 = free). For a donation rest, the suggested donation.
@export var rest_cost_gold: int = 0
## Fraction of max HP to restore (0.5 = 50%)
@export var rest_heal_percent: float = 0.5
## Donation rest (e.g. a shell-house): the player gives what they can, up to
## rest_cost_gold, and always rests. A donation of 0 is accepted only once per
## location. Donations add to the gold_donated counter.
@export var rest_is_donation: bool = false
## Notices for a donation rest. {gold} is replaced by the amount given.
## Empty = the neutral default text.
@export var rest_donation_text: String = ""
@export var rest_free_text: String = ""
@export var rest_refused_text: String = ""

# ============================================================================
# API
# ============================================================================

func get_display_label() -> String:
	if label != "":
		return label
	match button_category:
		ButtonCategory.QUESTS:        return "Quests"
		ButtonCategory.NPCS:          return "Talk"
		ButtonCategory.ENTER_DUNGEON: return "Enter"
		ButtonCategory.ENTER_ZONE:    return "Go"
		ButtonCategory.REST:          return "Rest"
		ButtonCategory.PARTY:         return "Party"
		ButtonCategory.STASH:         return "Stash"
		ButtonCategory.TRAVEL:        return "Travel"
	return "Action"

func is_condition_met(player) -> bool:
	if condition == null or condition.is_empty():
		return true
	return GameState.evaluate_condition(condition)
