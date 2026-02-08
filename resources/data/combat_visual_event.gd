# res://resources/data/combat_visual_event.gd
# Designer-friendly resource that bundles a visual effect preset with appearance.
# Create .tres files in the Inspector, then drag onto Actions, EnemyData, etc.
#
# Usage:
#   1. Right-click in FileSystem → New Resource → CombatVisualEvent
#   2. Pick a ScatterConvergePreset (or leave null for CombatEffect subclass)
#   3. Set tint / element_color / flags
#   4. Drag the .tres onto an Action's confirm_effect, impact_effect, etc.
#
# At runtime, trigger points call:
#   effect_player.play_event(event, from_target, to_target)
extends Resource
class_name CombatVisualEvent

# ============================================================================
# EFFECT TYPE
# ============================================================================

enum EffectType {
	SCATTER_CONVERGE,   ## Particle burst between two points
	COMBAT_EFFECT,      ## Generic CombatEffect subclass (shatter, summon, etc.)
	FLASH,              ## Simple flash + scale pulse on a single target
}

@export var effect_type: EffectType = EffectType.SCATTER_CONVERGE

# ============================================================================
# SCATTER-CONVERGE CONFIG
# ============================================================================
@export_group("Scatter-Converge")

## ScatterConvergePreset with all timing/particle behavior.
## Required when effect_type == SCATTER_CONVERGE.
@export var scatter_preset: ScatterConvergePreset = null

# ============================================================================
# COMBAT EFFECT CONFIG
# ============================================================================
@export_group("Combat Effect")

## PackedScene of a CombatEffect subclass (ShatterEffect, SummonEffect, etc.)
## Required when effect_type == COMBAT_EFFECT.
@export var effect_scene: PackedScene = null

## CombatEffectPreset for the effect's three-track system.
## If null, the effect scene must configure its own preset internally.
@export var effect_preset: CombatEffectPreset = null

# ============================================================================
# APPEARANCE — shared across all effect types
# ============================================================================
@export_group("Appearance")

## Primary color tint for particles / flash
@export var tint: Color = Color.WHITE

## Element color for particle glow layer. If left white, uses tint.
@export var element_color: Color = Color.WHITE

## Use the source die's face texture for particles (scatter-converge only)
@export var use_source_texture: bool = false

# ============================================================================
# FLASH CONFIG — only used when effect_type == FLASH
# ============================================================================
@export_group("Flash")

## Flash color (modulate pulse). Only for FLASH type.
@export var flash_color: Color = Color(1.5, 1.5, 0.5, 1.0)

## Scale pulse magnitude
@export var flash_scale: float = 1.15

## Duration of the flash
@export var flash_duration: float = 0.25

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")

## Delay before the effect starts (seconds)
@export var start_delay: float = 0.0

## Whether to await completion before proceeding (affects game flow)
## When false, the effect fires and the game continues immediately.
@export var await_completion: bool = true

# ============================================================================
# HELPERS
# ============================================================================

func is_valid() -> bool:
	"""Check if this event has enough config to play."""
	match effect_type:
		EffectType.SCATTER_CONVERGE:
			return scatter_preset != null
		EffectType.COMBAT_EFFECT:
			return effect_scene != null
		EffectType.FLASH:
			return true  # flash always works
		_:
			return false


func get_appearance() -> Dictionary:
	"""Build the appearance dict for CombatEffectPlayer."""
	var appearance: Dictionary = {}
	appearance["tint"] = tint
	appearance["element"] = element_color if element_color != Color.WHITE else tint
	return appearance


func _to_string() -> String:
	var type_name = ["SCATTER_CONVERGE", "COMBAT_EFFECT", "FLASH"][effect_type]
	return "CombatVisualEvent(%s, tint=%s)" % [type_name, tint]
