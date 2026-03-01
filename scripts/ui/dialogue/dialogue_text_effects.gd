# res://scripts/ui/dialogue/dialogue_text_effects.gd
# Custom RichTextEffects for dialogue BBCode tags.
# Usage: Add these to your RichTextLabel's custom_effects array.
#
# Tags:
#   [pulse freq=2 amp=0.15]text[/pulse] - Scale pulsing
#   [appear speed=10]text[/appear] - Fade-in per character
#   [tremble rate=15 amp=2]text[/tremble] - Shake/vibrate
#   [ghost freq=1 min=0.3]text[/ghost] - Ghostly fade in/out
extends RefCounted
class_name DialogueTextEffects

# ============================================================================
# PULSE EFFECT
# ============================================================================

class PulseEffect extends RichTextEffect:
	var bbcode := "pulse"
	
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var freq = char_fx.env.get("freq", 2.0)
		var amp = char_fx.env.get("amp", 0.15)
		
		var t = char_fx.elapsed_time * freq + char_fx.relative_index * 0.1
		var scale_mod = 1.0 + sin(t * TAU) * amp
		
		char_fx.transform = char_fx.transform.scaled(Vector2(scale_mod, scale_mod))
		return true

# ============================================================================
# APPEAR EFFECT
# ============================================================================

class AppearEffect extends RichTextEffect:
	var bbcode := "appear"
	
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var speed = char_fx.env.get("speed", 10.0)
		
		var time_per_char = 1.0 / speed
		var char_delay = char_fx.relative_index * time_per_char
		var progress = clamp((char_fx.elapsed_time - char_delay) * speed, 0.0, 1.0)
		
		char_fx.color.a *= progress
		char_fx.offset.y = (1.0 - progress) * -10.0
		
		return true

# ============================================================================
# TREMBLE EFFECT
# ============================================================================

class TrembleEffect extends RichTextEffect:
	var bbcode := "tremble"
	
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var rate = char_fx.env.get("rate", 15.0)
		var amp = char_fx.env.get("amp", 2.0)
		
		var seed_x = char_fx.relative_index * 123.456
		var seed_y = char_fx.relative_index * 789.012
		
		var offset_x = sin(char_fx.elapsed_time * rate + seed_x) * amp
		var offset_y = cos(char_fx.elapsed_time * rate * 1.1 + seed_y) * amp
		
		char_fx.offset += Vector2(offset_x, offset_y)
		return true

# ============================================================================
# GHOST EFFECT
# ============================================================================

class GhostEffect extends RichTextEffect:
	var bbcode := "ghost"
	
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var freq = char_fx.env.get("freq", 1.0)
		var min_alpha = char_fx.env.get("min", 0.3)
		
		var t = char_fx.elapsed_time * freq + char_fx.relative_index * 0.2
		var alpha = lerp(min_alpha, 1.0, (sin(t * TAU) + 1.0) * 0.5)
		
		char_fx.color.a *= alpha
		return true

# ============================================================================
# REGISTRATION HELPER
# ============================================================================

static func register_all(rich_text: RichTextLabel) -> void:
	"""Register all custom effects on a RichTextLabel."""
	rich_text.install_effect(PulseEffect.new())
	rich_text.install_effect(AppearEffect.new())
	rich_text.install_effect(TrembleEffect.new())
	rich_text.install_effect(GhostEffect.new())
