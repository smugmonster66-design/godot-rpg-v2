# res://scripts/ui/combat/companion_slot.gd
# Individual companion slot -- discovers child nodes from the scene tree.
# Attach this script to each CompanionSlot PanelContainer.
# Lives in PersistentUILayer -- visible on map AND combat.
# Empty slots are hidden (visible = false).
extends PanelContainer
class_name CompanionSlot

# ============================================================================
# SIGNALS
# ============================================================================
signal slot_clicked(slot: CompanionSlot)

# ============================================================================
# CONSTANTS
# ============================================================================
const NPC_BORDER_COLOR := Color(0.85, 0.70, 0.30, 0.9)
const SUMMON_BORDER_COLOR := Color(0.55, 0.35, 0.80, 0.9)
const EMPTY_BORDER_COLOR := Color(0.30, 0.30, 0.35, 0.5)

# ============================================================================
# STATE (set by CompanionPanel._discover_slots())
# ============================================================================
var slot_index: int = -1
var is_npc_slot: bool = true
var companion: CompanionCombatant = null
var companion_data: CompanionData = null
var is_empty: bool = true

# ============================================================================
# CHILD NODES -- discovered from scene tree
# ============================================================================
var portrait_rect: TextureRect = null
var hp_bar: TextureProgressBar = null
var name_label: Label = null
var frame_bg: TextureRect = null
var frame_fg: TextureRect = null

# Overlay nodes -- created programmatically
var death_overlay: ColorRect = null
var skull_label: Label = null
var style_box: StyleBoxFlat = null
var _firing_tween: Tween = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

	portrait_rect = find_child("CompanionPortrait", false, false) as TextureRect
	frame_bg = find_child("CompanionFrameBG", false, false) as TextureRect
	frame_fg = find_child("CompanionFrameFG", false, false) as TextureRect

	if frame_fg:
		hp_bar = frame_fg.find_child("HPBar", false, false) as TextureProgressBar
		var name_panel = frame_fg.find_child("NamePanel", true, false)
		if name_panel:
			name_label = name_panel.find_child("NameLabel", false, false) as Label

	print("    [Companion] Slot %s: portrait=%s hp=%s name=%s" % [
		name, "OK" if portrait_rect else "MISS",
		"OK" if hp_bar else "MISS", "OK" if name_label else "MISS"])

	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	death_overlay.set_anchors_preset(PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.visible = false
	add_child(death_overlay)

	skull_label = Label.new()
	skull_label.text = "X"
	skull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skull_label.set_anchors_preset(PRESET_CENTER)
	skull_label.add_theme_font_size_override("font_size", 24)
	skull_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skull_label.visible = false
	add_child(skull_label)

	style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.07, 0.10, 0.3)
	style_box.border_color = EMPTY_BORDER_COLOR
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style_box)

	gui_input.connect(_on_gui_input)

	# Start hidden (empty)
	_show_empty()

# ============================================================================
# PERSISTENT DISPLAY (map/dungeon -- uses CompanionData directly)
# ============================================================================

func set_companion_data(data: CompanionData) -> void:
	"""Populate slot for persistent (non-combat) display."""
	companion_data = data
	companion = null
	is_empty = false
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	if portrait_rect:
		portrait_rect.texture = data.portrait if data and data.portrait else null
		portrait_rect.modulate = Color.WHITE
		portrait_rect.visible = true

	if name_label:
		name_label.text = data.companion_name if data else ""

	# Show full HP for persistent display
	if hp_bar:
		hp_bar.max_value = data.base_max_hp if data else 100
		hp_bar.value = data.base_max_hp if data else 100
		hp_bar.visible = true
		hp_bar.tint_progress = Color.WHITE

	_update_border_color()
	death_overlay.visible = false
	skull_label.visible = false

# ============================================================================
# COMBAT DISPLAY (uses CompanionCombatant node)
# ============================================================================

func set_companion(p_companion: CompanionCombatant) -> void:
	"""Populate slot with a live combat companion."""
	companion = p_companion
	companion_data = p_companion.companion_data if p_companion else null
	is_empty = false
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	if portrait_rect:
		if p_companion.companion_data and p_companion.companion_data.portrait:
			portrait_rect.texture = p_companion.companion_data.portrait
		else:
			portrait_rect.texture = null
			push_warning("CompanionSlot: No portrait on %s (path: %s)" % [
				p_companion.combatant_name,
				p_companion.companion_data.resource_path if p_companion.companion_data else "null"])
		portrait_rect.modulate = Color.WHITE
		portrait_rect.visible = true

	if name_label:
		name_label.text = p_companion.combatant_name

	_update_hp(p_companion.current_health, p_companion.max_health)
	if hp_bar:
		hp_bar.visible = true

	if not p_companion.health_changed.is_connected(_on_health_changed):
		p_companion.health_changed.connect(_on_health_changed)
	if not p_companion.died.is_connected(_on_companion_died):
		p_companion.died.connect(_on_companion_died)

	_update_border_color()
	death_overlay.visible = false
	skull_label.visible = false

func set_empty() -> void:
	"""Reset to empty (hidden)."""
	if companion:
		if companion.health_changed.is_connected(_on_health_changed):
			companion.health_changed.disconnect(_on_health_changed)
		if companion.died.is_connected(_on_companion_died):
			companion.died.disconnect(_on_companion_died)
	companion = null
	companion_data = null
	is_empty = true
	_show_empty()

func update_health(current: int, maximum: int) -> void:
	_update_hp(current, maximum)

func show_dead() -> void:
	if portrait_rect:
		portrait_rect.modulate = Color(0.3, 0.3, 0.3, 0.7)
	death_overlay.visible = true
	skull_label.visible = true
	if hp_bar:
		hp_bar.value = 0

func play_fire_animation() -> void:
	if _firing_tween and _firing_tween.is_running():
		_firing_tween.kill()
	_firing_tween = create_tween()
	_firing_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.0), 0.1)
	_firing_tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func play_damage_animation() -> void:
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(4, 0), 0.03)
	tween.tween_property(self, "position", original_pos - Vector2(4, 0), 0.03)
	tween.tween_property(self, "position", original_pos + Vector2(2, 0), 0.03)
	tween.tween_property(self, "position", original_pos, 0.03)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

func show_taunt_indicator(visible_flag: bool) -> void:
	if style_box:
		if visible_flag:
			style_box.border_color = Color(0.3, 0.6, 0.9, 0.9)
			style_box.set_border_width_all(3)
		else:
			_update_border_color()
			style_box.set_border_width_all(2)

# ============================================================================
# SUMMON ANIMATIONS
# ============================================================================

func play_summon_enter(entry_emanate: EmanatePreset = null, effects_layer: CanvasLayer = null) -> void:
	# Capture center BEFORE scale/pivot changes
	var slot_center = global_position + size / 2.0

	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.3, 0.3)
	pivot_offset = size / 2.0

	if entry_emanate:
		_play_entry_emanate(entry_emanate, effects_layer, slot_center)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", 0.0, 0.5).from(0.3)
	await tween.finished


func _play_entry_emanate(preset: EmanatePreset, effects_layer: CanvasLayer, center: Vector2) -> void:
	var effect = EmanateEffect.new()
	if effects_layer:
		effects_layer.add_child(effect)
	else:
		get_tree().root.add_child(effect)
	effect.configure(preset, center)
	effect.play()

func play_summon_exit() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.5).set_ease(Tween.EASE_IN)
	await tween.finished

# ============================================================================
# PRIVATE
# ============================================================================

func _show_empty() -> void:
	if portrait_rect:
		portrait_rect.texture = null
		portrait_rect.visible = false
	if name_label:
		name_label.text = ""
	if hp_bar:
		hp_bar.value = 0
		hp_bar.visible = false
	death_overlay.visible = false
	skull_label.visible = false
	# Keep visible=true so VBoxContainer always reserves layout space.
	# Use modulate alpha to hide instead.
	visible = false
	modulate = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_hp(current: int, maximum: int) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
		if maximum > 0 and float(current) / float(maximum) < 0.3:
			hp_bar.tint_progress = Color(1.0, 0.4, 0.4)
		else:
			hp_bar.tint_progress = Color.WHITE

func _update_border_color() -> void:
	if style_box:
		if is_npc_slot:
			style_box.border_color = NPC_BORDER_COLOR
		else:
			style_box.border_color = SUMMON_BORDER_COLOR

func _on_health_changed(current: int, maximum: int) -> void:
	_update_hp(current, maximum)
	if current < maximum:
		play_damage_animation()

func _on_companion_died() -> void:
	show_dead()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)
