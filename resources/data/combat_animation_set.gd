# res://resources/data/combat_animation_set.gd
# Resource that defines the full animation sequence for a combat action
extends Resource
class_name CombatAnimationSet

# ============================================================================
# CAST ANIMATION - Plays at the action field/source when action is confirmed
# ============================================================================
@export_group("Cast Animation")
## Scene to spawn at the action field when action is confirmed
@export var cast_effect: PackedScene
## If set, this takes priority over cast_effect PackedScene.
@export var cast_preset: CombatEffectPreset
## How long the cast animation takes (fallback if scene doesn't signal)
@export var cast_duration: float = 0.3
## Offset from source position
@export var cast_offset: Vector2 = Vector2.ZERO:
	set(v): cast_offset = v if v else Vector2.ZERO
@export var cast_scale: Vector2 = Vector2.ONE:
	set(v): cast_scale = v if v else Vector2.ONE



# ============================================================================
# TRAVEL ANIMATION - Projectile that moves from source to target
# ============================================================================
@export_group("Travel Animation")
## Projectile scene that travels from source to target
@export var travel_effect: PackedScene
## How long the projectile takes to reach target
@export var travel_duration: float = 0.4
## Optional curve for arc path (Y values = height offset)
@export var travel_curve: Curve
## Whether projectile rotates to face movement direction
@export var travel_rotation: bool = true
@export var travel_scale: Vector2 = Vector2.ONE:
	set(v): travel_scale = v if v else Vector2.ONE
@export var impact_scale: Vector2 = Vector2.ONE:
	set(v): impact_scale = v if v else Vector2.ONE

# ============================================================================
# IMPACT ANIMATION - Plays at target(s) when hit
# ============================================================================
@export_group("Impact Animation")
## Scene to spawn at target(s) when damage/effect is applied
@export var impact_effect: PackedScene
## If set, this takes priority over impact_effect PackedScene.
@export var impact_preset: CombatEffectPreset
## How long the impact animation takes (fallback if scene doesn't signal)
@export var impact_duration: float = 0.3
## Offset from target position
@export var impact_offset: Vector2 = Vector2.ZERO:
	set(v): impact_offset = v if v else Vector2.ZERO
## Delay after travel completes before impact plays
@export var impact_delay: float = 0.0:
	set(v): impact_delay = v if v != null else 0.0

# ============================================================================
# TIMING - When the actual game effect (damage, heal) is applied
# ============================================================================
@export_group("Timing")

enum EffectTiming {
	ON_CAST,       ## Apply effect immediately when cast starts
	ON_TRAVEL_END, ## Apply effect when projectile reaches target
	ON_IMPACT      ## Apply effect when impact animation plays (default)
}

## Instantiate the correct CombatEffect subclass from a preset resource.
static func create_effect_from_preset(preset: Variant) -> Variant:
	if preset is SummonPreset:
		return SummonEffect.new()
	elif preset is EmanatePreset:
		return EmanateEffect.new()
	elif preset is ImpactPreset:
		return ImpactEffect.new()
	elif preset is ShatterPreset:
		return ShatterEffect.new()
	elif preset is ScatterConvergePreset:
		return ScatterConvergeEffect.new()
	else:
		push_warning("CombatAnimationSet: Unknown preset type: %s" % preset.get_class())
		return null

## When to apply the actual game effect (damage, heal, etc.)
@export var apply_effect_at: EffectTiming = EffectTiming.ON_IMPACT

# ============================================================================
# AUDIO
# ============================================================================
@export_group("Audio")
## Sound to play when cast animation starts
@export var cast_sound: AudioStream
## Sound to play when projectile launches
@export var travel_sound: AudioStream
## Sound to play on impact
@export var impact_sound: AudioStream
