# res://scripts/combat/combat_event_bus.gd
# Central signal hub for all combat events.
# Game systems fire events here; visual systems (ReactiveAnimator,
# combat log, tutorial triggers, etc.) listen and respond.
#
# Lifecycle:
#   - Created as child of CombatManager during combat init
#   - Game systems call emit_event() or convenience methods
#   - Cleaned up when combat ends (queue_free with parent)
#
# Design notes:
#   - Single signal (game_event) for all event types keeps wiring simple.
#   - Convenience emitters construct CombatEvent and fire in one call.
#   - Events are timestamped for sequencing and deferred playback.
#   - Optional event history for combat log / replay.
extends Node
class_name CombatEventBus

# ============================================================================
# SIGNALS
# ============================================================================

## The ONE signal everything connects to. Filter by event.type in your handler.
signal game_event(event: CombatEvent)

## Emitted when an event is queued (for systems that batch-process per frame)
signal event_queued(event: CombatEvent)

# ============================================================================
# CONFIGURATION
# ============================================================================

## When true, events are stored in _history for combat log / replay
@export var record_history: bool = true

## Max events to keep in history (0 = unlimited)
@export var max_history: int = 500

## When true, print events to console (debug builds only)
@export var debug_logging: bool = false

# ============================================================================
# STATE
# ============================================================================

## Event history for combat log / replay
var _history: Array[CombatEvent] = []

## Deferred event queue — events added here are flushed on _process
## Use queue_event() for events that shouldn't interrupt current animations
var _deferred_queue: Array[CombatEvent] = []

## Whether deferred queue is being flushed (prevents re-entrant flush)
var _flushing: bool = false

## Pause flag — when true, events are queued but not emitted
var _paused: bool = false

# ============================================================================
# CORE API
# ============================================================================

func emit_event(event: CombatEvent) -> void:
	"""Fire an event immediately. All connected listeners receive it this frame."""
	event.timestamp = Time.get_ticks_msec()

	if debug_logging and OS.is_debug_build():
		_log_event(event)

	if record_history:
		_history.append(event)
		if max_history > 0 and _history.size() > max_history:
			_history.pop_front()

	if _paused:
		_deferred_queue.append(event)
		event_queued.emit(event)
		return

	game_event.emit(event)


func queue_event(event: CombatEvent) -> void:
	"""Queue an event for deferred emission on the next _process frame.
	Use this when firing events from within animation callbacks to avoid
	re-entrant signal chains."""
	event.timestamp = Time.get_ticks_msec()
	_deferred_queue.append(event)
	event_queued.emit(event)


func pause() -> void:
	"""Pause event emission. Events accumulate in the deferred queue."""
	_paused = true


func resume() -> void:
	"""Resume event emission and flush any queued events."""
	_paused = false
	_flush_deferred()


func clear_history() -> void:
	"""Clear event history (e.g. on combat end)."""
	_history.clear()


func get_history() -> Array[CombatEvent]:
	"""Get the event history for combat log / replay."""
	return _history


func get_recent_events(count: int = 10) -> Array[CombatEvent]:
	"""Get the N most recent events."""
	var start = maxi(0, _history.size() - count)
	return _history.slice(start)

# ============================================================================
# DEFERRED PROCESSING
# ============================================================================

func _process(_delta: float) -> void:
	if not _paused and _deferred_queue.size() > 0:
		_flush_deferred()


func _flush_deferred() -> void:
	if _flushing:
		return
	_flushing = true

	while _deferred_queue.size() > 0:
		var event = _deferred_queue.pop_front()

		if record_history:
			_history.append(event)
			if max_history > 0 and _history.size() > max_history:
				_history.pop_front()

		game_event.emit(event)

	_flushing = false

# ============================================================================
# CONVENIENCE EMITTERS
# ============================================================================

func emit_die_value_changed(die_visual: Node, old_val: int, new_val: int, tag: String = "") -> void:
	emit_event(CombatEvent.die_value_changed(die_visual, old_val, new_val, tag))

func emit_die_consumed(die_visual: Node) -> void:
	emit_event(CombatEvent.die_consumed(die_visual))

func emit_die_created(die_visual: Node, tag: String = "") -> void:
	emit_event(CombatEvent.die_created(die_visual, tag))

func emit_die_locked(die_visual: Node) -> void:
	emit_event(CombatEvent.die_locked(die_visual))

func emit_die_unlocked(die_visual: Node) -> void:
	emit_event(CombatEvent.die_unlocked(die_visual))

func emit_die_destroyed(die_visual: Node) -> void:
	emit_event(CombatEvent.die_destroyed(die_visual))

func emit_damage_dealt(target: Node, amount: int, element: String = "", is_crit: bool = false, source: Node = null) -> void:
	var evt = CombatEvent.damage_dealt(target, amount, element, is_crit, source)
	emit_event(evt)
	if is_crit:
		emit_event(CombatEvent.crit_landed(target, amount, source))

func emit_heal_applied(target: Node, amount: int, source: Node = null) -> void:
	emit_event(CombatEvent.heal_applied(target, amount, source))

func emit_status_applied(target: Node, status_name: String, stacks: int, tags: Array = []) -> void:
	emit_event(CombatEvent.status_applied(target, status_name, stacks, tags))

func emit_status_ticked(target: Node, status_name: String, tick_damage: int, element: String = "") -> void:
	emit_event(CombatEvent.status_ticked(target, status_name, tick_damage, element))

func emit_status_removed(target: Node, status_name: String) -> void:
	emit_event(CombatEvent.status_removed(target, status_name))

func emit_mana_changed(ui_node: Node, old_val: int, new_val: int) -> void:
	emit_event(CombatEvent.mana_changed(ui_node, old_val, new_val))

func emit_enemy_died(enemy_visual: Node, enemy_name: String = "") -> void:
	emit_event(CombatEvent.enemy_died(enemy_visual, enemy_name))

func emit_shield_gained(target: Node, amount: int) -> void:
	emit_event(CombatEvent.shield_gained(target, amount))

func emit_shield_broken(target: Node) -> void:
	emit_event(CombatEvent.shield_broken(target))

func emit_turn_started(combatant_node: Node, is_player: bool) -> void:
	emit_event(CombatEvent.turn_started(combatant_node, is_player))

func emit_round_started(round_number: int) -> void:
	emit_event(CombatEvent.round_started(round_number))

func emit_affix_triggered(target: Node, affix_name: String, source: Node = null) -> void:
	emit_event(CombatEvent.affix_triggered(target, affix_name, source))

func emit_action_confirmed(source: Node) -> void:
	var evt = CombatEvent.new()
	evt.type = CombatEvent.Type.ACTION_CONFIRMED
	evt.source_node = source
	emit_event(evt)

func emit_combat_started() -> void:
	var evt = CombatEvent.new()
	evt.type = CombatEvent.Type.COMBAT_STARTED
	emit_event(evt)

func emit_combat_ended(player_won: bool) -> void:
	var evt = CombatEvent.new()
	evt.type = CombatEvent.Type.COMBAT_ENDED
	evt.values = { "player_won": player_won }
	emit_event(evt)

# ============================================================================
# DEBUG
# ============================================================================

func _log_event(event: CombatEvent) -> void:
	var type_name = CombatEvent.Type.keys()[event.type]
	var target_name = event.target_node.name if event.target_node and is_instance_valid(event.target_node) else "null"
	var tag_str = " [%s]" % event.source_tag if event.source_tag != "" else ""
	print("  📡 Event: %s → %s%s %s" % [type_name, target_name, tag_str, event.values])
