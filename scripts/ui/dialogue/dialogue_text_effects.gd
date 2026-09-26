# res://scripts/ui/dialogue/dialogue_text_effects.gd
# Custom RichTextEffects for dialogue BBCode tags.
# Usage: Call DialogueTextEffects.register_all(rich_text_label) to install all effects.
#
# Tags:
#   [pulse freq=2 amp=0.15]text[/pulse]            - Scale pulsing
#   [appear speed=10]text[/appear]                  - Fade-in per character
#   [tremble rate=15 amp=2]text[/tremble]           - Shake/vibrate
#   [ghost freq=1 min=0.3]text[/ghost]              - Ghostly fade in/out (per-char stagger)
#   [ember rate=3 amp=0.15]text[/ember]             - Fiery orange flicker
#   [frost drift=1 amp=0.5]text[/frost]             - Icy blue with downward drift
#   [zap rate=20 amp=4]text[/zap]                   - Electric horizontal jitter
#   [toxic rate=1 amp=3]text[/toxic]                - Poison green drip
#   [shadow lag=0.15 amp=2]text[/shadow]            - Dark trailing afterimage
#   [whisper]text[/whisper]                         - Small, faint, gentle sway
#   [shout amp=0.12 rate=8]text[/shout]             - Large with shake
#   [impact duration=0.5 bounce=1.3]text[/impact]   - Slam in from above with bounce
#   [heartbeat bpm=72]text[/heartbeat]              - Rhythmic double-pulse scale
#   [glitch rate=3 amp=5]text[/glitch]              - Random position jumps
#   [fade_pulse freq=1 min=0.3]text[/fade_pulse]    - Uniform fade in/out (no stagger)
extends RefCounted
class_name DialogueTextEffects

# ============================================================================
# PULSE EFFECT — smooth scale oscillation
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
# APPEAR EFFECT — per-character fade-in + slide up
# ============================================================================

class AppearEffect extends RichTextEffect:
	var bbcode := "appear"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var speed = char_fx.env.get("speed", 10.0)

		var time_per_char = 1.0 / speed
		var char_delay = char_fx.relative_index * time_per_char
		var progress = clamp((char_fx.elapsed_time - char_delay) * speed, 0.0, 1.0)

		if not char_fx.outline:
			char_fx.color.a *= progress
		char_fx.offset.y = (1.0 - progress) * -10.0

		return true

# ============================================================================
# TREMBLE EFFECT — shake/vibrate each character
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
# GHOST EFFECT — ghostly fade in/out with per-character stagger
# ============================================================================

class GhostEffect extends RichTextEffect:
	var bbcode := "ghost"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var freq = char_fx.env.get("freq", 1.0)
		var min_alpha = char_fx.env.get("min", 0.3)

		var t = char_fx.elapsed_time * freq + char_fx.relative_index * 0.2
		var alpha = lerp(min_alpha, 1.0, (sin(t * TAU) + 1.0) * 0.5)

		if not char_fx.outline:
			char_fx.color.a *= alpha
		return true

# ============================================================================
# EMBER EFFECT — fiery orange/red flicker
# ============================================================================

class EmberEffect extends RichTextEffect:
	var bbcode := "ember"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var rate = char_fx.env.get("rate", 3.0)
		var amp = char_fx.env.get("amp", 0.15)

		var char_seed = char_fx.relative_index * 47.31
		var flicker = sin(char_fx.elapsed_time * rate * TAU + char_seed)
		var brightness = 1.0 + flicker * amp

		if not char_fx.outline:
			# Tint toward orange-red
			char_fx.color.r = minf(char_fx.color.r * brightness * 1.2, 1.0)
			char_fx.color.g *= brightness * 0.6
			char_fx.color.b *= brightness * 0.3

		return true

# ============================================================================
# FROST EFFECT — icy blue tint with slow downward drift
# ============================================================================

class FrostEffect extends RichTextEffect:
	var bbcode := "frost"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var drift = char_fx.env.get("drift", 1.0)
		var amp = char_fx.env.get("amp", 0.5)

		# Cyclic downward drift per character
		var char_seed = char_fx.relative_index * 0.3
		var cycle = fmod(char_fx.elapsed_time * drift + char_seed, 1.0)
		char_fx.offset.y += cycle * amp

		if not char_fx.outline:
			# Tint toward icy blue-white
			char_fx.color.r *= 0.7
			char_fx.color.g *= 0.85
			char_fx.color.b = minf(char_fx.color.b * 1.3, 1.0)

		return true

# ============================================================================
# ZAP EFFECT — sharp staccato horizontal jitter (electric)
# ============================================================================

class ZapEffect extends RichTextEffect:
	var bbcode := "zap"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var rate = char_fx.env.get("rate", 20.0)
		var amp = char_fx.env.get("amp", 4.0)

		var char_seed = char_fx.relative_index * 91.7
		var wave = sin(char_fx.elapsed_time * rate + char_seed)

		# Only jitter when wave exceeds threshold — creates staccato bursts
		if absf(wave) > 0.7:
			var jitter_x = wave * amp
			char_fx.offset.x += jitter_x

		return true

# ============================================================================
# TOXIC EFFECT — green tint with downward drip
# ============================================================================

class ToxicEffect extends RichTextEffect:
	var bbcode := "toxic"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var rate = char_fx.env.get("rate", 1.0)
		var amp = char_fx.env.get("amp", 3.0)

		# Sawtooth drip: drops down then resets
		var char_seed = char_fx.relative_index * 0.4
		var drip = fmod(char_fx.elapsed_time * rate + char_seed, 1.0)
		char_fx.offset.y += drip * amp

		if not char_fx.outline:
			# Green tint, slight alpha fade at bottom of drip
			char_fx.color.r *= 0.5
			char_fx.color.g = minf(char_fx.color.g * 1.3, 1.0)
			char_fx.color.b *= 0.5
			char_fx.color.a *= lerpf(1.0, 0.6, drip)

		return true

# ============================================================================
# SHADOW EFFECT — dark trailing afterimage
# ============================================================================

class ShadowEffect extends RichTextEffect:
	var bbcode := "shadow"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var lag = char_fx.env.get("lag", 0.15)
		var amp = char_fx.env.get("amp", 2.0)

		# Slow wandering movement; the "trail" feel comes from the lag offset
		var char_seed = char_fx.relative_index * 33.7
		var current_t = char_fx.elapsed_time
		var lagged_t = current_t - lag

		var current_x = sin(current_t * 2.0 + char_seed) * amp
		var lagged_x = sin(lagged_t * 2.0 + char_seed) * amp
		var trail_offset = current_x - lagged_x

		char_fx.offset.x += trail_offset

		if not char_fx.outline:
			# Darken toward shadow purple
			char_fx.color.r *= 0.6
			char_fx.color.g *= 0.5
			char_fx.color.b *= 0.7

		return true

# ============================================================================
# WHISPER EFFECT — small, faint, gentle sway
# ============================================================================

class WhisperEffect extends RichTextEffect:
	var bbcode := "whisper"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		# Scale down
		char_fx.transform = char_fx.transform.scaled(Vector2(0.85, 0.85))

		# Gentle slow sway
		var sway = sin(char_fx.elapsed_time * 1.5 + char_fx.relative_index * 0.15) * 1.0
		char_fx.offset.x += sway

		if not char_fx.outline:
			char_fx.color.a *= 0.6

		return true

# ============================================================================
# SHOUT EFFECT — large scale + slight shake
# ============================================================================

class ShoutEffect extends RichTextEffect:
	var bbcode := "shout"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var amp = char_fx.env.get("amp", 0.12)
		var rate = char_fx.env.get("rate", 8.0)

		# Scale up
		char_fx.transform = char_fx.transform.scaled(Vector2(1.15, 1.15))

		# Light shake
		var seed_x = char_fx.relative_index * 55.3
		var seed_y = char_fx.relative_index * 142.7
		var shake_x = sin(char_fx.elapsed_time * rate + seed_x) * amp * 10.0
		var shake_y = cos(char_fx.elapsed_time * rate * 1.2 + seed_y) * amp * 10.0
		char_fx.offset += Vector2(shake_x, shake_y)

		return true

# ============================================================================
# IMPACT EFFECT — slam in from above with overshoot bounce
# ============================================================================

class ImpactTextEffect extends RichTextEffect:
	var bbcode := "impact"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var duration = char_fx.env.get("duration", 0.5)
		var bounce = char_fx.env.get("bounce", 1.3)

		# Per-character stagger
		var char_delay = char_fx.relative_index * 0.03
		var progress = clamp((char_fx.elapsed_time - char_delay) / duration, 0.0, 1.0)

		# Bounce ease: overshoot then settle
		var eased: float
		if progress < 0.6:
			# Rush in phase — ease out
			var p = progress / 0.6
			eased = p * p * (bounce * 2.0 - p * (bounce * 2.0 - 1.0))
			eased = minf(eased, bounce)
		else:
			# Settle phase — ease back from overshoot to 1.0
			var p = (progress - 0.6) / 0.4
			eased = lerpf(bounce, 1.0, p * p)

		# Start 30px above, land at 0
		char_fx.offset.y = (1.0 - eased) * -30.0

		# Fade in during first 30%
		if not char_fx.outline:
			var alpha = clamp(progress / 0.3, 0.0, 1.0)
			char_fx.color.a *= alpha

		return true

# ============================================================================
# HEARTBEAT EFFECT — rhythmic double-pulse scale
# ============================================================================

class HeartbeatEffect extends RichTextEffect:
	var bbcode := "heartbeat"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var bpm = char_fx.env.get("bpm", 72.0)

		# Period of one full heartbeat cycle
		var period = 60.0 / bpm
		var t = fmod(char_fx.elapsed_time, period) / period  # 0.0 to 1.0

		# Double pulse: two bumps at t=0.0-0.15 and t=0.2-0.35
		var pulse = 0.0
		if t < 0.15:
			# First thump (stronger)
			pulse = sin(t / 0.15 * PI) * 0.12
		elif t >= 0.2 and t < 0.35:
			# Second thump (slightly weaker)
			pulse = sin((t - 0.2) / 0.15 * PI) * 0.08

		var scale_mod = 1.0 + pulse
		char_fx.transform = char_fx.transform.scaled(Vector2(scale_mod, scale_mod))

		return true

# ============================================================================
# GLITCH EFFECT — random characters jump to wrong positions
# ============================================================================

class GlitchEffect extends RichTextEffect:
	var bbcode := "glitch"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var rate = char_fx.env.get("rate", 3.0)
		var amp = char_fx.env.get("amp", 5.0)

		var char_seed = char_fx.relative_index * 77.77
		# Use multiple overlapping waves to create irregular glitch timing
		var wave1 = sin(char_fx.elapsed_time * rate * TAU + char_seed)
		var wave2 = sin(char_fx.elapsed_time * rate * 1.7 * TAU + char_seed * 2.3)

		# Only glitch when both waves align above threshold — creates rare, sudden jumps
		if wave1 > 0.7 and wave2 > 0.3:
			var glitch_x = sin(char_seed * 3.14 + char_fx.elapsed_time * 50.0) * amp
			var glitch_y = cos(char_seed * 2.72 + char_fx.elapsed_time * 50.0) * amp * 0.5
			char_fx.offset += Vector2(glitch_x, glitch_y)

		return true

# ============================================================================
# FADE PULSE EFFECT — uniform fade in/out (all chars together, no stagger)
# ============================================================================

class FadePulseEffect extends RichTextEffect:
	var bbcode := "fade_pulse"

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var freq = char_fx.env.get("freq", 1.0)
		var min_alpha = char_fx.env.get("min", 0.3)

		# No relative_index stagger — all characters fade together
		var t = char_fx.elapsed_time * freq
		var alpha = lerpf(min_alpha, 1.0, (sin(t * TAU) + 1.0) * 0.5)

		if not char_fx.outline:
			char_fx.color.a *= alpha

		return true

# ============================================================================
# REGISTRATION HELPER
# ============================================================================

static func register_all(rich_text: RichTextLabel) -> void:
	# Original effects
	rich_text.install_effect(PulseEffect.new())
	rich_text.install_effect(AppearEffect.new())
	rich_text.install_effect(TrembleEffect.new())
	rich_text.install_effect(GhostEffect.new())
	# Element-themed effects
	rich_text.install_effect(EmberEffect.new())
	rich_text.install_effect(FrostEffect.new())
	rich_text.install_effect(ZapEffect.new())
	rich_text.install_effect(ToxicEffect.new())
	rich_text.install_effect(ShadowEffect.new())
	# Dramatic/narrative effects
	rich_text.install_effect(WhisperEffect.new())
	rich_text.install_effect(ShoutEffect.new())
	rich_text.install_effect(ImpactTextEffect.new())
	rich_text.install_effect(HeartbeatEffect.new())
	rich_text.install_effect(GlitchEffect.new())
	rich_text.install_effect(FadePulseEffect.new())
