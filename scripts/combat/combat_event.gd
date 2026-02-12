# res://scripts/combat/combat_event.gd
# Lightweight runtime event payload for the reactive animation bus.
# NOT a saved Resource — just a RefCounted data container created at runtime.
#
# Game systems construct these and fire them through CombatEventBus.
# ReactiveAnimator matches events by type + conditions and plays animations.
#
# Usage:
#   var evt = CombatEvent.new()
#   evt.type = CombatEvent.Type.DIE_VALUE_CHANGED
#   evt.target_node = some_die_visual
#   evt.values = { "old": 3, "new": 6, "delta": 3, "element": "FIRE" }
#   event_bus.emit_event(evt)
#
# Or use the static helpers:
#   CombatEvent.die_value_changed(die_visual, 3, 6, "siphon")
extends RefCounted
class_name CombatEvent

# ============================================================================
# EVENT TYPES
# ============================================================================

enum Type {
	# --- Dice events ---
	DIE_VALUE_CHANGED,       ## A die's value was modified (affix, buff, etc.)
	DIE_CONSUMED,            ## A die was used to pay for an action
	DIE_CREATED,             ## A new die appeared mid-combat (mana pull, etc.)
	DIE_LOCKED,              ## A die was locked (cannot be placed)
	DIE_UNLOCKED,            ## A die was unlocked
	DIE_DESTROYED,           ## A die was permanently removed from the pool
	DIE_ROLLED,              ## A die's roll animation completed

	# --- Combat result events ---
	DAMAGE_DEALT,            ## Damage applied to a combatant
	HEAL_APPLIED,            ## Healing applied to a combatant
	CRIT_LANDED,             ## A critical hit occurred
	OVERKILL,                ## Damage exceeded remaining HP
	MISS,                    ## An attack missed or was dodged
	RESIST_TRIGGERED,        ## Elemental resistance reduced damage

	# --- Status events ---
	STATUS_APPLIED,          ## A new status effect was applied
	STATUS_TICKED,           ## A status dealt its per-turn effect
	STATUS_REMOVED,          ## A status expired or was cleansed
	STATUS_STACKS_CHANGED,   ## Stack count changed on existing status

	# --- Defense events ---
	SHIELD_GAINED,           ## Block/shield value added
	SHIELD_BROKEN,           ## All shield/block was consumed
	SHIELD_CONSUMED,         ## Partial shield consumed by a hit

	# --- Resource events ---
	MANA_CHANGED,            ## Mana pool value changed
	MANA_DEPLETED,           ## Mana hit zero
	CHARGE_USED,             ## An action charge was consumed
	CHARGE_RESTORED,         ## An action charge was refunded

	# --- Combatant events ---
	ENEMY_DIED,              ## An enemy was killed
	PLAYER_DIED,             ## The player was killed
	ENEMY_SPAWNED,           ## A new enemy appeared (summon, reinforcement)

	# --- Turn/phase events ---
	TURN_STARTED,            ## A combatant's turn began
	TURN_ENDED,              ## A combatant's turn ended
	ROUND_STARTED,           ## A new combat round began
	ACTION_CONFIRMED,        ## Player confirmed an action (dice placed, go pressed)
	COMBAT_STARTED,          ## Combat encounter began
	COMBAT_ENDED,            ## Combat encounter resolved

	# --- Affix/proc events ---
	AFFIX_TRIGGERED,         ## An equipment affix proc'd
	THRESHOLD_REACHED,       ## A status stack threshold was hit

	# --- Elemental / special ---
	ELEMENT_COMBO,           ## Multiple elements combined for a bonus
	BATTLEFIELD_EFFECT,      ## A battlefield zone triggered
}

# ============================================================================
# PAYLOAD
# ============================================================================

## The event type — used for matching by AnimationReaction
var type: Type = Type.DIE_VALUE_CHANGED

## The primary node to animate (die visual, enemy sprite, health bar, etc.)
var target_node: Node = null

## Optional origin node (the caster, the source die, etc.)
var source_node: Node = null

## Flexible key-value payload. Contents depend on event type.
## Common keys documented per-type in the static helpers below.
var values: Dictionary = {}

## Timestamp for sequencing (auto-set by CombatEventBus.emit_event)
var timestamp: float = 0.0

## Optional tag for filtering (e.g. "siphon", "poison_dot", "frost_nova")
## Allows reactions to target specific causes, not just event types.
var source_tag: String = ""

## Whether this event has been "consumed" by a reaction with consume = true.
## Consumed events are skipped by subsequent reactions in the same frame.
var consumed: bool = false

# ============================================================================
# STATIC CONSTRUCTORS — convenience for common event types
# ============================================================================

static func die_value_changed(die_visual: Node, old_val: int, new_val: int, tag: String = "") -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_VALUE_CHANGED
	evt.target_node = die_visual
	evt.source_tag = tag
	evt.values = {
		"old": old_val,
		"new": new_val,
		"delta": new_val - old_val,
	}
	return evt

static func die_consumed(die_visual: Node) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_CONSUMED
	evt.target_node = die_visual
	return evt

static func die_created(die_visual: Node, tag: String = "") -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_CREATED
	evt.target_node = die_visual
	evt.source_tag = tag
	return evt

static func die_locked(die_visual: Node) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_LOCKED
	evt.target_node = die_visual
	return evt

static func die_unlocked(die_visual: Node) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_UNLOCKED
	evt.target_node = die_visual
	return evt

static func die_destroyed(die_visual: Node) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DIE_DESTROYED
	evt.target_node = die_visual
	return evt

static func damage_dealt(target: Node, amount: int, element: String = "", is_crit: bool = false, source: Node = null) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.DAMAGE_DEALT
	evt.target_node = target
	evt.source_node = source
	evt.values = {
		"amount": amount,
		"element": element,
		"is_crit": is_crit,
	}
	return evt

static func heal_applied(target: Node, amount: int, source: Node = null) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.HEAL_APPLIED
	evt.target_node = target
	evt.source_node = source
	evt.values = { "amount": amount }
	return evt

static func crit_landed(target: Node, amount: int, source: Node = null) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.CRIT_LANDED
	evt.target_node = target
	evt.source_node = source
	evt.values = { "amount": amount }
	return evt

static func status_applied(target: Node, status_name: String, stacks: int, tags: Array = []) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.STATUS_APPLIED
	evt.target_node = target
	evt.values = {
		"status_name": status_name,
		"stacks": stacks,
		"tags": tags,
	}
	return evt

static func status_ticked(target: Node, status_name: String, tick_damage: int, element: String = "") -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.STATUS_TICKED
	evt.target_node = target
	evt.values = {
		"status_name": status_name,
		"tick_damage": tick_damage,
		"element": element,
	}
	return evt

static func status_removed(target: Node, status_name: String) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.STATUS_REMOVED
	evt.target_node = target
	evt.values = { "status_name": status_name }
	return evt

static func mana_changed(ui_node: Node, old_val: int, new_val: int) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.MANA_CHANGED
	evt.target_node = ui_node
	evt.values = {
		"old": old_val,
		"new": new_val,
		"delta": new_val - old_val,
	}
	return evt

static func enemy_died(enemy_visual: Node, enemy_name: String = "") -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.ENEMY_DIED
	evt.target_node = enemy_visual
	evt.values = { "enemy_name": enemy_name }
	return evt

static func shield_gained(target: Node, amount: int) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.SHIELD_GAINED
	evt.target_node = target
	evt.values = { "amount": amount }
	return evt

static func shield_broken(target: Node) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.SHIELD_BROKEN
	evt.target_node = target
	return evt

static func turn_started(combatant_node: Node, is_player: bool) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.TURN_STARTED
	evt.target_node = combatant_node
	evt.values = { "is_player": is_player }
	return evt

static func round_started(round_number: int) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.ROUND_STARTED
	evt.values = { "round_number": round_number }
	return evt

static func affix_triggered(target: Node, affix_name: String, source: Node = null) -> CombatEvent:
	var evt = CombatEvent.new()
	evt.type = Type.AFFIX_TRIGGERED
	evt.target_node = target
	evt.source_node = source
	evt.source_tag = affix_name
	evt.values = { "affix_name": affix_name }
	return evt
