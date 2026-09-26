# res://resources/data/floater_reaction.gd
# Maps a GameEvent type (+ optional conditions) to a MicroAnimationPreset.
# Drag these into FloaterLayer's reactions array in the inspector.
# Mirrors AnimationReaction but for out-of-combat GameEvents.
extends Resource
class_name FloaterReaction

# ============================================================================
# MATCHING
# ============================================================================

## The event type this reaction responds to
@export var event_type: GameEvent.Type = GameEvent.Type.GOLD_GAINED

## All conditions must pass (AND logic) for this reaction to fire
@export var conditions: Array[FloaterCondition] = []

## Optional: only match events with this source_tag
@export var required_tag: String = ""

# ============================================================================
# ANIMATION
# ============================================================================

## The animation preset to play. Reuses MicroAnimationPreset's label track.
@export var animation_preset: MicroAnimationPreset = null

## Text template for the floating label. Placeholders like {amount}, {name}
## are resolved from event.values. Empty string = use preset's label_text.
@export var label_text_template: String = ""

# ============================================================================
# BEHAVIOR
# ============================================================================

## Priority for ordering when multiple reactions match the same event.
@export var priority: int = 0

## When true, lower-priority reactions for the same event are skipped.
@export var consume_event: bool = false

## Cooldown in seconds. 0 = no cooldown.
@export var cooldown: float = 0.0

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

	return true


func mark_fired() -> void:
	_last_fired = Time.get_ticks_msec()


func resolve_text(event: GameEvent) -> String:
	"""Resolve label_text_template with event values."""
	if label_text_template == "":
		return ""
	var text = label_text_template
	for k in event.values:
		text = text.replace("{%s}" % k, str(event.values[k]))
	return text
