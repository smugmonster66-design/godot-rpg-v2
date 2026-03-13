@tool
# res://resources/data/combat_animation_set.gd
# Resource that defines the full animation sequence for a combat action
extends Resource
class_name CombatAnimationSet

# ============================================================================
# CAST ANIMATION - Plays at the action field/source when action is confirmed
# ============================================================================
@export_group("Cast Animation")
## Scene to spawn at the action field when action is confirmed
@export var cast_effect: PackedScene:
	set(v):
		print("🔍 SETTER ENTRY: v=%s type=%s" % [v, typeof(v)])
		cast_effect = v
		if v:
			print("🔍 v is truthy, calling extract...")
			var detected := _extract_max_particle_lifetime(v)
			print("🔍 detected = %s" % detected)
			cast_duration = detected
			print("🔍 cast_duration now = %s" % cast_duration)
			notify_property_list_changed()
		else:
			print("🔍 v is falsy, skipping")


## If set, this takes priority over cast_effect PackedScene.
@export var cast_preset: CombatEffectPreset
## How long the cast animation takes. 0 = auto-detect from scene's particle lifetimes.
@export var cast_duration: float = 0.0
## Offset from source position
@export var cast_offset: Vector2 = Vector2.ZERO:
	set(v): cast_offset = v if v else Vector2.ZERO
@export var cast_scale: Vector2 = Vector2.ONE:
	set(v): cast_scale = v if v else Vector2.ONE

# ============================================================================
# FIRE ANIMATION - Plays at source simultaneously with travel start
# ============================================================================
@export_group("Fire Animation")
## Node2D-based effect scene
@export var fire_effect: PackedScene:
	set(v):
		fire_effect = v
		if v:
			fire_duration = _extract_max_particle_lifetime(v)
			notify_property_list_changed()
## Takes priority over PackedScene
@export var fire_preset: CombatEffectPreset
## How long the fire animation takes. 0 = auto-detect from scene's particle lifetimes.
@export var fire_duration: float = 0.0
## Offset from source position
@export var fire_offset: Vector2 = Vector2.ZERO
@export var fire_scale: Vector2 = Vector2.ONE
@export var fire_sound: AudioStream

# ============================================================================
# TRAVEL ANIMATION - Projectile that moves from source to target
# ============================================================================
@export_group("Travel Animation")
## Projectile scene that travels from source to target
@export var travel_effect: PackedScene:
	set(v):
		travel_effect = v
		if v:
			travel_duration = _extract_max_particle_lifetime(v)
			notify_property_list_changed()
## How long the projectile takes to reach target. 0 = auto-detect from scene's particle lifetimes.
@export var travel_duration: float = 0.0
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
@export var impact_effect: PackedScene:
	set(v):
		impact_effect = v
		if v:
			impact_duration = _extract_max_particle_lifetime(v)
			notify_property_list_changed()
## If set, this takes priority over impact_effect PackedScene.
@export var impact_preset: CombatEffectPreset
## How long the impact animation takes. 0 = auto-detect from scene's particle lifetimes.
@export var impact_duration: float = 0.0
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
	ON_IMPACT,     ## Apply effect when impact animation plays (default)
	ON_FIRE        ## Apply effect when fire animation starts
}

## When to apply the actual game effect (damage, heal, etc.)
@export var apply_effect_at: EffectTiming = EffectTiming.ON_IMPACT

# ============================================================================
# STAGE OVERLAP - Let stages start before the previous one finishes
# ============================================================================
@export_group("Stage Overlap")
## Start travel this many seconds before cast finishes (0 = fully sequential)
@export var cast_travel_overlap: float = 0.0
## Start impact this many seconds before travel finishes (0 = fully sequential)
@export var travel_impact_overlap: float = 0.0

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

# ============================================================================
# DURATION AUTO-DETECTION
# ============================================================================

const DEFAULT_FALLBACK_DURATION := 0.5

## Scan a PackedScene for the longest GPUParticles2D lifetime.
## Called automatically when assigning an effect scene while duration is 0.
## Uses SceneState to read .tscn data directly — no instantiation needed.
static func _extract_max_particle_lifetime(scene: PackedScene) -> float:
	if not scene:
		return DEFAULT_FALLBACK_DURATION
	var max_lt := _scan_scene_state(scene)
	return max_lt if max_lt > 0.0 else DEFAULT_FALLBACK_DURATION

static func _scan_scene_state(scene: PackedScene) -> float:
	var state := scene.get_state()
	var max_lt := 0.0
	for i in range(state.get_node_count()):
		# Check if this node is a GPUParticles2D
		if state.get_node_type(i) == &"GPUParticles2D":
			var lt := 1.0  # Godot default lifetime
			for j in range(state.get_node_property_count(i)):
				if state.get_node_property_name(i, j) == &"lifetime":
					lt = state.get_node_property_value(i, j)
					break
			max_lt = max(max_lt, lt)
		# Recurse into instanced sub-scenes
		var sub_scene := state.get_node_instance(i)
		if sub_scene:
			max_lt = max(max_lt, _scan_scene_state(sub_scene))
	return max_lt


# ============================================================================
# FACTORY
# ============================================================================

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
