# res://scripts/autoload/game_event_bus.gd
# Central signal hub for out-of-combat and cross-system events.
# Mirrors CombatEventBus pattern but as a persistent autoload.
#
# Game systems call emit_event() or convenience methods.
# FloaterLayer and BarkManager listen and respond.
#
# Design notes:
#   - Single signal (game_event) for all event types keeps wiring simple.
#   - Convenience emitters construct GameEvent and fire in one call.
#   - Events are timestamped for sequencing.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

## The ONE signal everything connects to. Filter by event.type in your handler.
signal game_event(event: GameEvent)

# ============================================================================
# CONFIGURATION
# ============================================================================

## When true, print events to console (debug builds only)
@export var debug_logging: bool = false

# ============================================================================
# CORE API
# ============================================================================

func emit_event(event: GameEvent) -> void:
	"""Fire an event immediately. All connected listeners receive it this frame."""
	event.timestamp = Time.get_ticks_msec()

	if debug_logging and OS.is_debug_build():
		_log_event(event)

	game_event.emit(event)

# ============================================================================
# CONVENIENCE EMITTERS
# ============================================================================

func emit_gold_gained(amount: int, target: Node = null) -> void:
	emit_event(GameEvent.gold_gained(amount, target))

func emit_exp_gained(amount: int, target: Node = null) -> void:
	emit_event(GameEvent.exp_gained(amount, target))

func emit_item_gained(item_name: String, rarity: int = 0, target: Node = null) -> void:
	emit_event(GameEvent.item_gained(item_name, rarity, target))

func emit_run_affix_chosen(affix_name: String, target: Node = null) -> void:
	emit_event(GameEvent.run_affix_chosen(affix_name, target))

func emit_shrine_applied(shrine_name: String, is_curse: bool, target: Node = null) -> void:
	emit_event(GameEvent.shrine_applied(shrine_name, is_curse, target))

func emit_heal_received(amount: int, target: Node = null) -> void:
	emit_event(GameEvent.heal_received(amount, target))

func emit_dungeon_entered(dungeon_name: String) -> void:
	emit_event(GameEvent.dungeon_entered(dungeon_name))

func emit_dungeon_completed(dungeon_name: String) -> void:
	emit_event(GameEvent.dungeon_completed(dungeon_name))

func emit_combat_crit(amount: int, target: Node, source: Node = null) -> void:
	emit_event(GameEvent.combat_crit(amount, target, source))

func emit_enemy_killed(enemy_name: String, target: Node) -> void:
	emit_event(GameEvent.enemy_killed(enemy_name, target))

func emit_custom(tag: String, data: Dictionary = {}, target: Node = null) -> void:
	emit_event(GameEvent.custom(tag, data, target))

# ============================================================================
# DEBUG
# ============================================================================

func _log_event(event: GameEvent) -> void:
	var type_name = GameEvent.Type.keys()[event.type]
	var target_name = event.target_node.name if event.target_node and is_instance_valid(event.target_node) else "null"
	var tag_str = " [%s]" % event.source_tag if event.source_tag != "" else ""
	print("  📡 GameEvent: %s → %s%s %s" % [type_name, target_name, tag_str, event.values])
