# res://scripts/ui/components/dice/combat_die_object.gd
# Combat die object - displays ROLLED value for combat hand and action fields
# Inherits visual and animation logic from DieObjectBase
extends DieObjectBase
class_name CombatDieObject

# ============================================================================
# COMBAT-SPECIFIC STATE
# ============================================================================
var slot_index: int = -1  # Position in hand/action field

# ============================================================================
# VALUE DISPLAY - Shows rolled value
# ============================================================================

func _update_value_display():
	"""Show the rolled (modified) value"""
	if not die_resource or not value_label:
		return
	
	value_label.text = str(die_resource.get_total_value())

# ============================================================================
# COMBAT-SPECIFIC ANIMATIONS
# ============================================================================

func play_roll_animation():
	"""Play dice roll animation"""
	if animation_player and animation_player.has_animation("roll"):
		animation_player.play("roll")
	else:
		# Fallback - quick spin
		var tween = create_tween()
		tween.tween_property(self, "rotation", TAU, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): rotation = 0)

func play_placed_animation():
	"""Play animation when placed in action field"""
	if animation_player and animation_player.has_animation("placed"):
		animation_player.play("placed")
	else:
		# Fallback - quick pulse
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func play_consumed_animation():
	"""Play animation when die is used for an action"""
	if animation_player and animation_player.has_animation("consumed"):
		animation_player.play("consumed")
	else:
		# Fallback - fade and shrink
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)

func play_critical_animation():
	"""Play animation for critical/max rolls"""
	if animation_player and animation_player.has_animation("critical"):
		animation_player.play("critical")
	else:
		# Fallback - golden flash
		var original_mod = modulate
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		tween.tween_property(self, "modulate", original_mod, 0.3)

# ============================================================================
# VALUE CHANGE HANDLING
# ============================================================================

func on_value_changed(old_value: int, new_value: int):
	"""Called when die value is modified by affixes"""
	_update_value_display()
	
	# Visual feedback for value change
	if new_value > old_value:
		_flash_color(Color(0.5, 1.0, 0.5))  # Green for increase
	elif new_value < old_value:
		_flash_color(Color(1.0, 0.5, 0.5))  # Red for decrease

func _flash_color(color: Color):
	"""Brief color flash effect"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
