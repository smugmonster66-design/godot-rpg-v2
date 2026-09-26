# res://scripts/events/game_event.gd
# Lightweight runtime event payload for out-of-combat and cross-system events.
# Mirrors CombatEvent pattern but for dungeon rewards, run affixes, barks, etc.
#
# Usage:
#   var evt = GameEvent.gold_gained(50, portrait_node)
#   GameEventBus.emit_event(evt)
extends RefCounted
class_name GameEvent

# ============================================================================
# EVENT TYPES
# ============================================================================

enum Type {
	# --- Reward events ---
	GOLD_GAINED,             ## Player gained gold (combat, treasure, event, etc.)
	EXP_GAINED,              ## Player gained experience
	ITEM_GAINED,             ## Player gained an item

	# --- Run/dungeon events ---
	RUN_AFFIX_CHOSEN,        ## Player chose a run affix
	SHRINE_APPLIED,          ## Shrine blessing or curse applied
	HEAL_RECEIVED,           ## Player healed outside combat
	DUNGEON_ENTERED,         ## Started a dungeon run
	DUNGEON_COMPLETED,       ## Finished a dungeon run

	# --- Combat bridge events (forwarded from CombatEventBus) ---
	COMBAT_CRIT,             ## A critical hit occurred
	COMBAT_BIG_HIT,          ## A large damage hit
	ENEMY_KILLED,            ## An enemy was killed
	LEVEL_UP,                ## Player leveled up

	# --- Generic ---
	CUSTOM,                  ## Freeform event with source_tag for filtering
}

# ============================================================================
# PAYLOAD
# ============================================================================

## The event type — used for matching by FloaterReaction and BarkReaction
var type: Type = Type.CUSTOM

## The primary node to anchor visuals on (portrait, companion slot, enemy, etc.)
var target_node: Node = null

## Optional origin node (the caster, source of the reward, etc.)
var source_node: Node = null

## Flexible key-value payload. Contents depend on event type.
var values: Dictionary = {}

## Optional tag for filtering (e.g. "fire", "blessing", an affix name)
var source_tag: String = ""

## Timestamp for sequencing (auto-set by GameEventBus.emit_event)
var timestamp: float = 0.0

## Whether this event has been consumed by a handler
var consumed: bool = false

# ============================================================================
# STATIC CONSTRUCTORS
# ============================================================================

static func gold_gained(amount: int, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.GOLD_GAINED
	evt.target_node = target
	evt.values = { "amount": amount }
	return evt

static func exp_gained(amount: int, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.EXP_GAINED
	evt.target_node = target
	evt.values = { "amount": amount }
	return evt

static func item_gained(item_name: String, rarity: int = 0, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.ITEM_GAINED
	evt.target_node = target
	evt.values = { "name": item_name, "rarity": rarity }
	return evt

static func run_affix_chosen(affix_name: String, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.RUN_AFFIX_CHOSEN
	evt.target_node = target
	evt.source_tag = affix_name
	evt.values = { "name": affix_name }
	return evt

static func shrine_applied(shrine_name: String, is_curse: bool, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.SHRINE_APPLIED
	evt.target_node = target
	evt.source_tag = "curse" if is_curse else "blessing"
	evt.values = { "name": shrine_name, "is_curse": is_curse }
	return evt

static func heal_received(amount: int, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.HEAL_RECEIVED
	evt.target_node = target
	evt.values = { "amount": amount }
	return evt

static func dungeon_entered(dungeon_name: String) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.DUNGEON_ENTERED
	evt.values = { "name": dungeon_name }
	return evt

static func dungeon_completed(dungeon_name: String) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.DUNGEON_COMPLETED
	evt.values = { "name": dungeon_name }
	return evt

static func combat_crit(amount: int, target: Node, source: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.COMBAT_CRIT
	evt.target_node = target
	evt.source_node = source
	evt.values = { "amount": amount }
	return evt

static func enemy_killed(enemy_name: String, target: Node) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.ENEMY_KILLED
	evt.target_node = target
	evt.values = { "name": enemy_name }
	return evt

static func custom(tag: String, data: Dictionary = {}, target: Node = null) -> GameEvent:
	var evt = GameEvent.new()
	evt.type = Type.CUSTOM
	evt.source_tag = tag
	evt.target_node = target
	evt.values = data
	return evt
