# res://resources/data/micro_animation_preset.gd
# Designer-facing resource that defines a small, composable reactive animation.
# These are NOT full combat animation sequences (CombatAnimationSet handles those).
# Instead, these are the quick "juice" animations — pops, flashes, shakes,
# floating numbers, particle bursts — that react to game events.
#
# Multiple tracks can be enabled simultaneously and play in parallel.
# Attach to AnimationReaction.animation_preset in the inspector.
#
# Examples:
#   "Die value grew"  → scale_enabled + flash_enabled (green) + label_pop
#   "Took damage"     → shake_enabled + flash_enabled (red) + label_pop (red, "-12")
#   "Crit landed"     → scale_enabled (big) + shake_enabled + screen_shake + sound
#   "Status applied"  → flash_enabled (purple) + particle_scene (debuff swirl)
#   "Shield broken"   → shake_enabled + particle_scene (shatter) + sound
extends Resource
class_name MicroAnimationPreset

# ============================================================================
# SCALE POP
# ============================================================================
@export_group("Scale Pop")

## Enable the scale pop track
@export var scale_enabled: bool = false

## Peak scale during the pop (relative to current scale, e.g. 1.25 = 25% bigger)
@export var scale_peak: Vector2 = Vector2(1.25, 1.25)

## Duration of the outward pop
@export var scale_out_duration: float = 0.08

## Duration of the return to original scale
@export var scale_in_duration: float = 0.15

## Ease type for the return
@export var scale_ease: Tween.EaseType = Tween.EASE_OUT

## Transition type for the return (BACK gives a satisfying overshoot)
@export var scale_trans: Tween.TransitionType = Tween.TRANS_BACK

# ============================================================================
# COLOR FLASH
# ============================================================================
@export_group("Color Flash")

## Enable the color flash track
@export var flash_enabled: bool = false

## Flash color applied to modulate (values > 1.0 create HDR glow)
@export var flash_color: Color = Color(1.5, 1.5, 0.5)

## Duration of the flash-in
@export var flash_in_duration: float = 0.06

## Duration of the return to original modulate
@export var flash_out_duration: float = 0.2

## Whether to use a key from event.values to pick the color dynamically.
## If set, looks for event.values[flash_color_key] as a Color.
## Falls back to flash_color if key is missing.
@export var flash_color_key: String = ""

# ============================================================================
# SHAKE
# ============================================================================
@export_group("Shake")

## Enable the shake track (rapid position jitter)
@export var shake_enabled: bool = false

## Maximum pixel offset per shake frame
@export var shake_intensity: float = 4.0

## Total shake duration
@export var shake_duration: float = 0.2

## Number of shake frames (higher = more frantic)
@export var shake_count: int = 6

## Whether intensity decays over the duration
@export var shake_decay: bool = true

# ============================================================================
# SCREEN SHAKE
# ============================================================================
@export_group("Screen Shake")

## Enable a camera/viewport shake (affects the whole screen)
@export var screen_shake_enabled: bool = false

## Screen shake intensity in pixels
@export var screen_shake_intensity: float = 6.0

## Screen shake duration
@export var screen_shake_duration: float = 0.15

# ============================================================================
# PARTICLE BURST
# ============================================================================
@export_group("Particle Burst")

## PackedScene to instantiate at the target position.
## Should auto-free (one-shot particles or timed scene).
@export var particle_scene: PackedScene = null

## Offset from target node's global_position
@export var particle_offset: Vector2 = Vector2.ZERO

## Scale for the particle instance
@export var particle_scale: Vector2 = Vector2.ONE

# ============================================================================
# COMBAT EFFECT (leverages existing CombatEffectPlayer pipeline)
# ============================================================================
@export_group("Combat Effect")

## A CombatEffectPreset (ScatterConvergePreset, ShatterPreset, etc.)
## Played via CombatEffectPlayer — supports projectiles, scatter-converge,
## shader tracks, screen effects.
@export var combat_effect_preset: CombatEffectPreset = null

## Direction for the effect when both source and target nodes exist.
enum EffectDirection { SOURCE_TO_TARGET, TARGET_TO_SOURCE }
@export var combat_effect_direction: EffectDirection = EffectDirection.SOURCE_TO_TARGET

## Appearance overrides passed to CombatEffectPlayer (keys: "tint", "element", "texture")
@export var combat_effect_appearance: Dictionary = {}

## A full CombatAnimationSet (cast → travel → impact) to play.
## Use for reactions that should trigger a complete action-style sequence.
## If both this and combat_effect_preset are set, preset wins.
@export var combat_animation_set: CombatAnimationSet = null


# ============================================================================
# SOUND
# ============================================================================
@export_group("Sound")

## Audio stream to play when the reaction fires
@export var sound: AudioStream = null

## Volume adjustment in dB
@export var sound_volume_db: float = 0.0

## Random pitch variance (± this value). 0.1 = pitches between 0.9–1.1
@export var sound_pitch_variance: float = 0.1

# ============================================================================
# FLOATING LABEL (damage numbers, "+3", "BLOCKED", etc.)
# ============================================================================
@export_group("Floating Label")

## Enable the floating label track
@export var label_enabled: bool = false

## Text to display. Leave empty to auto-generate from event values.
## Auto-generation rules:
##   DIE_VALUE_CHANGED → "+{delta}" or "{delta}" (signed)
##   DAMAGE_DEALT      → "-{amount}"
##   HEAL_APPLIED      → "+{amount}"
##   STATUS_APPLIED    → "{status_name}"
##   Other             → uses label_value_key
@export var label_text: String = ""

## If label_text is empty and auto-generation doesn't apply,
## use this key from event.values to get the display text.
@export var label_value_key: String = ""

## Prefix added to auto-generated or value-key text (e.g. "+", "-", "")
@export var label_prefix: String = ""

## Label color
@export var label_color: Color = Color.WHITE

## Font size
@export var label_font_size: int = 24

## Theme type variation for the floating label (e.g. &"tiny", &"normal", &"display").
## When set, overrides label_font_size with the theme's value.
@export var label_theme_type: StringName = &"caption"

## Whether to bold the label
@export var label_bold: bool = false

## How far the label rises before fading out (pixels)
@export var label_rise_distance: float = 40.0

## Total duration of the float + fade
@export var label_duration: float = 0.7

## Horizontal scatter range (random offset ±). Good for stacking numbers.
@export var label_scatter_x: float = 0.0

## Whether to use a key from event.values for the color dynamically.
@export var label_color_key: String = ""

## Scale at spawn (can be > 1 for emphasis, then shrinks)
@export var label_start_scale: float = 1.0

## Scale at end
@export var label_end_scale: float = 0.8

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")

## Delay before this preset starts playing (after the reaction fires)
@export var start_delay: float = 0.0

# ============================================================================
# HELPERS
# ============================================================================

func get_total_duration() -> float:
	"""Estimate the total duration of all enabled tracks for sequencing."""
	var d: float = start_delay
	var track_max: float = 0.0

	if scale_enabled:
		track_max = maxf(track_max, scale_out_duration + scale_in_duration)
	if flash_enabled:
		track_max = maxf(track_max, flash_in_duration + flash_out_duration)
	if shake_enabled:
		track_max = maxf(track_max, shake_duration)
	if screen_shake_enabled:
		track_max = maxf(track_max, screen_shake_duration)
	if label_enabled:
		track_max = maxf(track_max, label_duration)

	if combat_effect_preset and combat_effect_preset.has_method("get_total_duration"):
		track_max = maxf(track_max, combat_effect_preset.get_total_duration())
	if combat_animation_set:
		var anim_dur = combat_animation_set.cast_duration + combat_animation_set.travel_duration + combat_animation_set.impact_duration
		track_max = maxf(track_max, anim_dur)

	return d + track_max


func has_any_track() -> bool:
	"""Returns true if at least one animation track is enabled."""
	return (scale_enabled or flash_enabled or shake_enabled or
			screen_shake_enabled or label_enabled or
			particle_scene != null or sound != null or
			combat_effect_preset != null or combat_animation_set != null)
