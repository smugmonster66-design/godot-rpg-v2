# res://scripts/effects/sprite_effect.gd
# Plays a sprite sheet animation as a combat effect
extends CombatEffectBase
class_name SpriteEffect

@export var animation_name: String = "default"
@export var flip_h: bool = false
@export var flip_v: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func play():
	if not sprite:
		push_warning("SpriteEffect: No AnimatedSprite2D child found")
		_on_finished()
		return
	
	effect_started.emit()
	
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v
	sprite.play(animation_name)
	
	await sprite.animation_finished
	_on_finished()
