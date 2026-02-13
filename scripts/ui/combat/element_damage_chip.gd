# res://scripts/ui/combat/element_damage_chip.gd
# Individual element damage chip — icon + animated value label
# Pre-exists in the scene tree (8 per floater), toggled via visible
extends HBoxContainer
class_name ElementDamageChip

# ============================================================================
# NODE REFERENCES
# ============================================================================
var icon_rect: TextureRect = null
var value_label: Label = null

# ============================================================================
# STATE
# ============================================================================
## Which damage type this chip represents (assigned once in configure)
var damage_type: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

## Currently displayed integer value (for tick animation)
var _displayed_value: int = 0

## Whether the chip is actively showing a value
var _is_active: bool = false

## Active tweens — killed before starting new ones to prevent conflicts
var _spawn_tween: Tween = null
var _tick_tween: Tween = null
var _pulse_tween: Tween = null
var _bob_tween: Tween = null
var _dismiss_tween: Tween = null

## Bob baseline Y (set when chip becomes active)
var _bob_baseline_y: float = 0.0

# ============================================================================
# TUNING
# ============================================================================
const SPAWN_DURATION: float = 0.25
const SPAWN_OVERSHOOT: Vector2 = Vector2(1.15, 1.15)
const SPAWN_DRIFT_PX: float = 10.0

const TICK_DURATION: float = 0.2
const PULSE_SCALE: Vector2 = Vector2(1.2, 1.2)
const PULSE_DURATION: float = 0.15

const DISMISS_DURATION: float = 0.2

const BOB_AMPLITUDE: float = 2.0
const BOB_PERIOD: float = 1.5

const ICON_SIZE: Vector2 = Vector2(16, 16)
const FONT_SIZE: int = 16
const FONT_SIZE_BOLD_BOOST: int = 2

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discover_nodes()
	visible = false
	_is_active = false

func _discover_nodes():
	icon_rect = find_child("ElementIcon", true, false) as TextureRect
	value_label = find_child("ValueLabel", true, false) as Label
	
	# Configure icon defaults
	if icon_rect:
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Configure label defaults
	if value_label:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", FONT_SIZE)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ============================================================================
# CONFIGURE — called once per element assignment
# ============================================================================

func configure(p_damage_type: ActionEffect.DamageType):
	"""One-time setup: assign element type and pull visuals from ELEMENT_VISUALS."""
	damage_type = p_damage_type
	
	if not is_inside_tree():
		await ready
	
	_discover_nodes()
	
	if not GameManager or not GameManager.ELEMENT_VISUALS:
		_apply_fallback_visuals()
		return
	
	var config: ElementVisualConfig = GameManager.ELEMENT_VISUALS
	
	# Icon
	if icon_rect:
		var elem_icon = config.get_icon(damage_type)
		if elem_icon:
			icon_rect.texture = elem_icon
		icon_rect.modulate = config.get_tint_color(damage_type)
	
	# Value label shader material
	if value_label:
		var val_mat = config.get_value_material(damage_type)
		if val_mat:
			value_label.material = val_mat
		else:
			# Tint fallback
			value_label.add_theme_color_override("font_color", config.get_tint_color(damage_type))
		
		# Outline for readability
		value_label.add_theme_constant_override("outline_size", 3)
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))

func _apply_fallback_visuals():
	"""Fallback when ELEMENT_VISUALS isn't available."""
	var fallback_color = _get_fallback_color(damage_type)
	if icon_rect:
		icon_rect.modulate = fallback_color
	if value_label:
		value_label.add_theme_color_override("font_color", fallback_color)
		value_label.add_theme_constant_override("outline_size", 2)
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))

# ============================================================================
# SHOW — spawn animation for first appearance
# ============================================================================

func show_with_value(value: int):
	"""Make visible with spawn pop animation and set initial value."""
	_kill_all_tweens()
	_displayed_value = value
	_is_active = true
	
	if value_label:
		value_label.text = str(value)
	
	# Pre-animation state
	visible = true
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.3, 0.3)
	pivot_offset = size / 2
	
	# Spawn animation: fade in + scale pop + upward drift
	_spawn_tween = create_tween().set_parallel(true)
	
	# Fade in
	_spawn_tween.tween_property(self, "modulate:a", 1.0, SPAWN_DURATION * 0.6)
	
	# Scale: small → overshoot → settle
	_spawn_tween.tween_property(self, "scale", SPAWN_OVERSHOOT, SPAWN_DURATION * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_spawn_tween.chain().tween_property(self, "scale", Vector2.ONE, SPAWN_DURATION * 0.5) \
		.set_ease(Tween.EASE_OUT)
	
	# Slight upward drift
	var start_y = position.y
	position.y = start_y + SPAWN_DRIFT_PX
	_spawn_tween.tween_property(self, "position:y", start_y, SPAWN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	_spawn_tween.finished.connect(func():
		_bob_baseline_y = position.y
		_start_idle_bob()
	, CONNECT_ONE_SHOT)

# ============================================================================
# UPDATE — tick the number when value changes
# ============================================================================

func update_value(new_value: int):
	"""Animate from current displayed value to new_value with tick + pulse."""
	if not _is_active:
		show_with_value(new_value)
		return
	
	if new_value == _displayed_value:
		return
	
	var old_value = _displayed_value
	_displayed_value = new_value
	
	# Kill existing tick/pulse (but keep bob running)
	_kill_tween(_tick_tween)
	_kill_tween(_pulse_tween)
	
	# Tick the number through integers
	if value_label:
		_tick_tween = create_tween()
		_tick_tween.tween_method(
			func(v: float):
				if is_instance_valid(self) and value_label:
					value_label.text = str(int(round(v))),
			float(old_value), float(new_value), TICK_DURATION
		)
	
	# Scale pulse to punctuate the change
	_pulse_tween = create_tween()
	pivot_offset = size / 2
	_pulse_tween.tween_property(self, "scale", PULSE_SCALE, PULSE_DURATION * 0.4) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, PULSE_DURATION * 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Brief color flash — brighten the element tint
	if value_label:
		var bright = Color(1.5, 1.5, 1.5)
		var label_tween = value_label.create_tween()
		label_tween.tween_property(value_label, "modulate", bright, TICK_DURATION * 0.3)
		label_tween.tween_property(value_label, "modulate", Color.WHITE, TICK_DURATION * 0.7)

# ============================================================================
# DISMISS — fade out then hide
# ============================================================================

func dismiss():
	"""Fade out + shrink, then set visible = false."""
	if not _is_active:
		return
	
	_is_active = false
	_kill_all_tweens()
	
	pivot_offset = size / 2
	_dismiss_tween = create_tween().set_parallel(true)
	_dismiss_tween.tween_property(self, "modulate:a", 0.0, DISMISS_DURATION)
	_dismiss_tween.tween_property(self, "scale", Vector2(0.5, 0.5), DISMISS_DURATION) \
		.set_ease(Tween.EASE_IN)
	
	_dismiss_tween.finished.connect(func():
		visible = false
		scale = Vector2.ONE
		modulate = Color.WHITE
		_displayed_value = 0
	, CONNECT_ONE_SHOT)

# ============================================================================
# INSTANT HIDE — no animation (for field clear)
# ============================================================================

func hide_instant():
	"""Immediately hide without animation."""
	_kill_all_tweens()
	_is_active = false
	_displayed_value = 0
	visible = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	if value_label:
		value_label.text = "0"
		value_label.modulate = Color.WHITE

# ============================================================================
# IDLE BOB — gentle sine wave while active
# ============================================================================

func _start_idle_bob():
	"""Start a looping vertical bob animation."""
	if not _is_active:
		return
	
	_kill_tween(_bob_tween)
	_bob_baseline_y = position.y
	
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y",
		_bob_baseline_y - BOB_AMPLITUDE, BOB_PERIOD / 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(self, "position:y",
		_bob_baseline_y + BOB_AMPLITUDE, BOB_PERIOD / 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ============================================================================
# TWEEN MANAGEMENT
# ============================================================================

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _kill_all_tweens():
	_kill_tween(_spawn_tween)
	_kill_tween(_tick_tween)
	_kill_tween(_pulse_tween)
	_kill_tween(_bob_tween)
	_kill_tween(_dismiss_tween)
	_spawn_tween = null
	_tick_tween = null
	_pulse_tween = null
	_bob_tween = null
	_dismiss_tween = null

# ============================================================================
# QUERIES
# ============================================================================

func is_active() -> bool:
	return _is_active

func get_displayed_value() -> int:
	return _displayed_value

# ============================================================================
# FALLBACK COLORS (mirrors ActionField.ELEMENT_COLORS)
# ============================================================================

static func _get_fallback_color(dt: ActionEffect.DamageType) -> Color:
	match dt:
		ActionEffect.DamageType.SLASHING: return Color(0.8, 0.8, 0.8)
		ActionEffect.DamageType.BLUNT: return Color(0.6, 0.5, 0.4)
		ActionEffect.DamageType.PIERCING: return Color(0.9, 0.9, 0.7)
		ActionEffect.DamageType.FIRE: return Color(1.0, 0.4, 0.2)
		ActionEffect.DamageType.ICE: return Color(0.4, 0.8, 1.0)
		ActionEffect.DamageType.SHOCK: return Color(1.0, 1.0, 0.3)
		ActionEffect.DamageType.POISON: return Color(0.4, 0.9, 0.3)
		ActionEffect.DamageType.SHADOW: return Color(0.5, 0.3, 0.7)
		_: return Color.WHITE
