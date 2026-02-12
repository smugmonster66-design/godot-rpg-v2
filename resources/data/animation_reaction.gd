# res://resources/data/animation_reaction.gd
# Maps a CombatEvent type (+ optional conditions) to a MicroAnimationPreset.
# Drag these into ReactiveAnimator's reactions array in the inspector.
#
# The ReactiveAnimator evaluates all reactions against each incoming event.
# Multiple reactions CAN match the same event — they all play (layered).
#
# Examples:
#   Reaction 1: DIE_VALUE_CHANGED + condition(delta > 0) → green pop preset
#   Reaction 2: DIE_VALUE_CHANGED + condition(delta < 0) → red shrink preset
#   Reaction 3: DAMAGE_DEALT + no conditions → red flash + floating number
#   Reaction 4: DAMAGE_DEALT + condition(is_crit == true) → extra screen shake
#   Reaction 5: ENEMY_DIED → shatter particles + death sound
extends Resource
class_name AnimationReaction

# ============================================================================
# MATCHING
# ============================================================================

## The event type this reaction responds to
@export var event_type: CombatEvent.Type = CombatEvent.Type.DIE_VALUE_CHANGED

## All conditions must pass (AND logic) for this reaction to fire.
## Leave empty to fire on every event of this type.
@export var conditions: Array[ReactionCondition] = []

## Optional: only match events with this source_tag.
## Empty string matches all tags.
@export var required_tag: String = ""

# ============================================================================
# ANIMATION
# ============================================================================

## The animation preset to play when this reaction fires
@export var animation_preset: MicroAnimationPreset = null

# ============================================================================
# BEHAVIOR
# ============================================================================

## Priority for ordering when multiple reactions match the same event.
## Higher priority reactions play first. Same priority = insertion order.
@export var priority: int = 0

## When true, this reaction "consumes" the event — lower-priority reactions
## for the same event type are skipped. Use sparingly (e.g. override a
## generic reaction with a specific one).
@export var consume_event: bool = false

## When true, this reaction is disabled and will never fire.
## Useful for temporarily turning off reactions without removing them.
@export var disabled: bool = false

## Queue group for sequential playback. Reactions in the same non-empty
## queue_group play one after another instead of simultaneously.
## Empty string = fire immediately (parallel with everything else).
@export var queue_group: String = ""

## Cooldown in seconds. After firing, this reaction won't fire again
## until the cooldown expires. 0 = no cooldown.
@export var cooldown: float = 0.0

# ============================================================================
# RUNTIME STATE (not exported, not saved)
# ============================================================================

## Timestamp of last fire (for cooldown tracking)
var _last_fired: float = 0.0

# ============================================================================
# EVALUATION
# ============================================================================

func matches(event: CombatEvent) -> bool:
	"""Check if this reaction should fire for the given event."""
	if disabled:
		return false

	if event.type != event_type:
		return false

	if event.consumed:
		return false

	# Tag filter
	if required_tag != "" and event.source_tag != required_tag:
		return false

	# Cooldown check
	if cooldown > 0.0:
		var now = Time.get_ticks_msec()
		if now - _last_fired < cooldown * 1000.0:
			return false

	# All conditions must pass
	for condition in conditions:
		if not condition.evaluate(event):
			return false

	return true


func mark_fired() -> void:
	"""Record that this reaction just fired (for cooldown tracking)."""
	_last_fired = Time.get_ticks_msec()

# ============================================================================
# DEBUG
# ============================================================================

func describe() -> String:
	"""Human-readable description for debugging."""
	var type_name = CombatEvent.Type.keys()[event_type]
	var cond_strs: Array[String] = []
	for c in conditions:
		cond_strs.append(c.describe())
	var cond_text = " AND ".join(cond_strs) if cond_strs.size() > 0 else "always"
	var tag_text = " [tag=%s]" % required_tag if required_tag != "" else ""
	return "%s%s when %s" % [type_name, tag_text, cond_text]
