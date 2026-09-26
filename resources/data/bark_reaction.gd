# res://resources/data/bark_reaction.gd
# Maps a GameEvent type (+ conditions) to a pool of bark lines.
# Used inside BarkSet to define a companion's personality reactions.
extends Resource
class_name BarkReaction

# ============================================================================
# MATCHING
# ============================================================================

## The event type this reaction responds to
@export var event_type: GameEvent.Type = GameEvent.Type.CUSTOM

## All conditions must pass (AND logic) for this reaction to fire
@export var conditions: Array[FloaterCondition] = []

## Optional: only match events with this source_tag
@export var required_tag: String = ""

# ============================================================================
# BARK POOL
# ============================================================================

## Pool of possible barks — one is chosen randomly when this reaction fires
@export var barks: Array[BarkEntry] = []

# ============================================================================
# BEHAVIOR
# ============================================================================

## Cooldown in seconds between fires of this reaction
@export var cooldown: float = 5.0

## Probability of firing when matched (0.0-1.0). Allows occasional reactions.
@export var fire_chance: float = 1.0

# ============================================================================
# RUNTIME STATE
# ============================================================================

var _last_fired: float = 0.0

# ============================================================================
# EVALUATION
# ============================================================================

func matches(event: GameEvent) -> bool:
	if event.type != event_type:
		return false

	if required_tag != "" and event.source_tag != required_tag:
		return false

	if cooldown > 0.0:
		var now = Time.get_ticks_msec()
		if (now - _last_fired) < cooldown * 1000.0:
			return false

	for cond in conditions:
		if not cond.evaluate(event):
			return false

	if barks.size() == 0:
		return false

	return true


func pick_bark() -> BarkEntry:
	"""Pick a random bark from the pool."""
	if barks.size() == 0:
		return null
	return barks[randi() % barks.size()]


func mark_fired() -> void:
	_last_fired = Time.get_ticks_msec()
