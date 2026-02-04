# res://scripts/effects/combat_effect_base.gd
# Base class for all combat effect scenes
extends Node2D
class_name CombatEffectBase

signal effect_started()
signal effect_finished()

@export var auto_free: bool = true
@export var duration: float = 0.5

func play():
	"""Override in subclasses to start the effect"""
	effect_started.emit()
	# Subclasses implement actual animation
	await get_tree().create_timer(duration).timeout
	_on_finished()

func _on_finished():
	"""Called when effect completes"""
	effect_finished.emit()
	if auto_free:
		queue_free()
