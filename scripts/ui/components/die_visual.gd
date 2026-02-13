# res://scripts/ui/components/die_visual.gd
extends PanelContainer
class_name DieVisual

# ============================================================================
# DIE FACE SCENES - Lazy loaded
# ============================================================================
static var _die_face_cache: Dictionary = {}

static func _get_die_face_scene(die_type: DieResource.DieType) -> PackedScene:
	if _die_face_cache.has(die_type):
		return _die_face_cache[die_type]
	
	var path = "res://scenes/ui/components/dice/die_face_d%d.tscn" % die_type
	if ResourceLoader.exists(path):
		_die_face_cache[die_type] = load(path)
		return _die_face_cache[die_type]
	
	return null

# ============================================================================
# NODE REFERENCES
# ============================================================================
var die_face_container: Control = null
var current_die_face: Control = null
var value_label: Label = null
var texture_rect: TextureRect = null
var stroke_texture_rect: TextureRect = null

# Visual effect nodes
var overlay_container: Control = null
var particle_container: Control = null
var border_glow: Panel = null
var active_particles: Array[GPUParticles2D] = []
var active_overlays: Array[TextureRect] = []

# ============================================================================
# STATE
# ============================================================================
var die_data: DieResource = null
var can_drag: bool = true
var current_die_type: int = -1
var show_max_value: bool = false

# Drag state
var _is_being_dragged: bool = false
var _was_placed: bool = false

# ============================================================================
# SIGNALS
# ============================================================================
signal die_clicked(die: DieResource)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_setup_transparent_style()
	_setup_effect_containers()
	
	if die_data and current_die_type == -1:
		_load_die_face(die_data.die_type)
		current_die_type = die_data.die_type
		update_display()
		_apply_affix_visual_effects()

func _discover_nodes():
	die_face_container = find_child("DieFaceContainer", true, false) as Control
	
	if not die_face_container:
		die_face_container = Control.new()
		die_face_container.name = "DieFaceContainer"
		die_face_container.custom_minimum_size = Vector2(124, 124)
		die_face_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(die_face_container)

func _setup_transparent_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	add_theme_stylebox_override("panel", style)

func _setup_effect_containers():
	var effect_size = Vector2(124, 124)
	
	# Border glow panel (BEHIND die face)
	border_glow = Panel.new()
	border_glow.name = "BorderGlow"
	border_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_glow.custom_minimum_size = effect_size
	border_glow.size = effect_size
	border_glow.visible = false
	die_face_container.add_child(border_glow)
	die_face_container.move_child(border_glow, 0)
	
	# Overlay container (ON TOP of die face)
	overlay_container = Control.new()
	overlay_container.name = "OverlayContainer"
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_container.custom_minimum_size = effect_size
	overlay_container.size = effect_size
	add_child(overlay_container)
	
	# Particle container (ON TOP of everything)
	particle_container = Control.new()
	particle_container.name = "ParticleContainer"
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle_container.custom_minimum_size = effect_size
	particle_container.size = effect_size
	add_child(particle_container)

func mark_as_placed():
	"""Called by action field when die is successfully placed"""
	_was_placed = true

# ============================================================================
# DIE MANAGEMENT
# ============================================================================

func set_die(die: DieResource):
	die_data = die
	print("🎲 set_die called")
	
	# Ensure containers exist (in case called before _ready)
	if not die_face_container:
		_discover_nodes()
		_setup_transparent_style()
		_setup_effect_containers()
	
	if die_data:
		if current_die_type != die_data.die_type:
			_load_die_face(die_data.die_type)
			current_die_type = die_data.die_type
		update_display()
		_apply_affix_visual_effects()

func _load_die_face(die_type: DieResource.DieType):
	# Clear existing face
	if current_die_face:
		current_die_face.queue_free()
		current_die_face = null
		value_label = null
		texture_rect = null
		stroke_texture_rect = null
	
	# Load and instantiate new face
	var scene_path = "res://scenes/ui/components/dice/die_face_d%d.tscn" % die_type
	print("  Scene path: %s" % scene_path)
	print("  Scene exists: %s" % ResourceLoader.exists(scene_path))
	
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		current_die_face = scene.instantiate()
		die_face_container.add_child(current_die_face)
		
		# Reset anchors and position to fill container properly
		current_die_face.set_anchors_preset(Control.PRESET_TOP_LEFT)
		current_die_face.position = Vector2.ZERO
		current_die_face.size = Vector2(124, 124)
		
		# Find key nodes
		value_label = current_die_face.find_child("ValueLabel", true, false) as Label
		texture_rect = current_die_face.find_child("TextureRect", true, false) as TextureRect
		print("  From scene - value_label: %s" % value_label)
		print("  From scene - texture_rect: %s" % texture_rect)

func update_display():
	if not die_data:
		return
	
	# Update value
	if value_label:
		if show_max_value:
			value_label.text = str(die_data.get_max_value())
		else:
			value_label.text = str(die_data.get_total_value())
	
	# Update fill texture
	if texture_rect:
		if die_data.fill_texture:
			texture_rect.texture = die_data.fill_texture
			print("    Set fill_texture: %s" % die_data.fill_texture.resource_path)
		
		# Apply color
		if die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE
	else:
		print("    WARNING: no texture_rect!")
	
	# Create/update stroke texture
	if die_data.stroke_texture:
		if not stroke_texture_rect:
			stroke_texture_rect = TextureRect.new()
			stroke_texture_rect.name = "StrokeTextureRect"
			stroke_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stroke_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stroke_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stroke_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			if texture_rect:
				var parent = texture_rect.get_parent()
				parent.add_child(stroke_texture_rect)
				parent.move_child(stroke_texture_rect, texture_rect.get_index() + 1)
		
		stroke_texture_rect.texture = die_data.stroke_texture
		stroke_texture_rect.visible = true
		print("    Set stroke_texture: %s" % die_data.stroke_texture.resource_path)
	elif stroke_texture_rect:
		stroke_texture_rect.visible = false
		print("    No stroke texture")

func get_die() -> DieResource:
	return die_data

func roll_and_update():
	if die_data:
		die_data.roll()
		update_display()
		_apply_affix_visual_effects()

# ============================================================================
# AFFIX VISUAL EFFECTS
# ============================================================================

func _apply_affix_visual_effects():
	_clear_visual_effects()
	
	if not die_data:
		return
	
	var all_affixes = die_data.get_all_affixes()
	print("_apply_affix_visual_effects: ", die_data.display_name, " found ", all_affixes.size(), " affixes")
	
	all_affixes.sort_custom(func(a, b): return a.visual_priority < b.visual_priority)
	
	for affix in all_affixes:
		print("  Processing affix: ", affix.affix_name, ", visual_type: ", affix.visual_effect_type)
		_apply_single_affix_effect(affix)

func _clear_visual_effects():
	# Clear overlays
	for overlay in active_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	active_overlays.clear()
	
	# Clear particles
	for particles in active_particles:
		if is_instance_valid(particles):
			particles.queue_free()
	active_particles.clear()
	
	# Hide border glow
	if border_glow:
		border_glow.visible = false
	
	# Clear shader material from fill texture
	if texture_rect and is_instance_valid(texture_rect):
		texture_rect.material = null
		if die_data and die_data.color != Color.WHITE:
			texture_rect.modulate = die_data.color
		else:
			texture_rect.modulate = Color.WHITE
	
	# Clear shader material from stroke texture
	if stroke_texture_rect and is_instance_valid(stroke_texture_rect):
		stroke_texture_rect.material = null
		stroke_texture_rect.modulate = Color.WHITE
	
	# Reset value label (NEW)
	if value_label and is_instance_valid(value_label):
		value_label.material = null
		value_label.remove_theme_color_override("font_color")
		value_label.remove_theme_color_override("font_outline_color")

func _apply_single_affix_effect(affix: DiceAffix):
	# Check for NEW per-component effects first
	if affix.has_per_component_effects():
		_apply_per_component_effects(affix)
		# Also apply particles if set
		if affix.particle_scene:
			_apply_particle_effect(affix)
		return
	
	# Fall back to LEGACY unified effects
	match affix.visual_effect_type:
		DiceAffix.VisualEffectType.NONE:
			pass
		DiceAffix.VisualEffectType.COLOR_TINT:
			_apply_color_tint(affix)
		DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
			_apply_overlay_texture(affix)
		DiceAffix.VisualEffectType.PARTICLE:
			_apply_particle_effect(affix)
		DiceAffix.VisualEffectType.SHADER:
			_apply_shader_effect(affix)
		DiceAffix.VisualEffectType.BORDER_GLOW:
			_apply_border_glow(affix)

# ============================================================================
# NEW PER-COMPONENT EFFECTS
# ============================================================================

func _apply_per_component_effects(affix: DiceAffix):
	"""Apply separate effects to fill, stroke, and value label — uses resolve methods"""
	# Fill texture effects
	if texture_rect and affix.fill_effect_type != DiceAffix.VisualEffectType.NONE:
		match affix.fill_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if affix.fill_effect_color != Color.WHITE:
					texture_rect.modulate = texture_rect.modulate * affix.fill_effect_color
			DiceAffix.VisualEffectType.SHADER:
				var mat = affix.resolve_fill_material()
				if mat:
					texture_rect.material = mat
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.fill_overlay_texture:
					_create_overlay(affix.fill_overlay_texture, affix.fill_overlay_blend_mode, affix.fill_overlay_opacity)
			DiceAffix.VisualEffectType.BORDER_GLOW:
				_apply_border_glow_with_color(affix.fill_effect_color)
	
	# Stroke texture effects
	if stroke_texture_rect and affix.stroke_effect_type != DiceAffix.VisualEffectType.NONE:
		match affix.stroke_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if affix.stroke_effect_color != Color.WHITE:
					stroke_texture_rect.modulate = stroke_texture_rect.modulate * affix.stroke_effect_color
			DiceAffix.VisualEffectType.SHADER:
				var mat = affix.resolve_stroke_material()
				if mat:
					stroke_texture_rect.material = mat
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.stroke_overlay_texture:
					_create_overlay(affix.stroke_overlay_texture, affix.stroke_overlay_blend_mode, affix.stroke_overlay_opacity)
	
	# Value label effects
	if value_label and affix.value_effect_type != DiceAffix.ValueEffectType.NONE:
		match affix.value_effect_type:
			DiceAffix.ValueEffectType.COLOR:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
			DiceAffix.ValueEffectType.OUTLINE_COLOR:
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			DiceAffix.ValueEffectType.COLOR_AND_OUTLINE:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			


func _create_overlay(tex: Texture2D, blend_mode: int, opacity: float):
	"""Helper to create overlay texture"""
	if not overlay_container:
		return
	
	var overlay = TextureRect.new()
	overlay.texture = tex
	overlay.custom_minimum_size = Vector2(124, 124)
	overlay.size = Vector2(124, 124)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = opacity
	
	if blend_mode > 0:
		var mat = CanvasItemMaterial.new()
		match blend_mode:
			1: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			2: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		overlay.material = mat
	
	overlay_container.add_child(overlay)
	active_overlays.append(overlay)

func _apply_border_glow_with_color(color: Color):
	"""Apply border glow with specific color"""
	if not border_glow:
		return
	
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color.TRANSPARENT
	glow_style.border_color = color
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = color
	glow_style.shadow_size = 6
	
	border_glow.add_theme_stylebox_override("panel", glow_style)
	border_glow.visible = true

# ============================================================================
# LEGACY UNIFIED EFFECTS
# ============================================================================

func _apply_color_tint(affix: DiceAffix):
	if affix.effect_color == Color.WHITE:
		return
	
	if texture_rect:
		texture_rect.modulate = texture_rect.modulate * affix.effect_color

func _apply_overlay_texture(affix: DiceAffix):
	if not affix.overlay_texture or not overlay_container:
		return
	
	var overlay = TextureRect.new()
	overlay.texture = affix.overlay_texture
	overlay.custom_minimum_size = Vector2(124, 124)
	overlay.size = Vector2(124, 124)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = affix.overlay_opacity
	
	if affix.overlay_blend_mode > 0:
		var mat = CanvasItemMaterial.new()
		match affix.overlay_blend_mode:
			1: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			2: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		overlay.material = mat
	
	overlay_container.add_child(overlay)
	active_overlays.append(overlay)

func _apply_particle_effect(affix: DiceAffix):
	if not affix.particle_scene or not particle_container:
		return
	
	var particles = affix.particle_scene.instantiate()
	if particles is GPUParticles2D:
		particles.position = Vector2(62, 62)
		particles.emitting = true
		particle_container.add_child(particles)
		active_particles.append(particles)

func _apply_shader_effect(affix: DiceAffix):
	print("_apply_shader_effect called")
	print("  affix.shader_material: ", affix.shader_material)
	print("  texture_rect: ", texture_rect)
	print("  stroke_texture_rect: ", stroke_texture_rect)
	
	if not affix.shader_material:
		print("  SKIPPED - missing shader material")
		return
	
	if texture_rect:
		texture_rect.material = affix.shader_material.duplicate()
		print("  Applied shader to fill texture_rect")
	
	if stroke_texture_rect:
		stroke_texture_rect.material = affix.shader_material.duplicate()
		print("  Applied shader to stroke_texture_rect")

func _apply_border_glow(affix: DiceAffix):
	_apply_border_glow_with_color(affix.effect_color)

func refresh_visual_effects():
	_apply_affix_visual_effects()



# ============================================================================
# INPUT & DRAG (hold-to-drag for mobile compatibility)
# ============================================================================

const DRAG_HOLD_TIME: float = 0.15  # Seconds to hold before drag starts
const DRAG_MOVE_THRESHOLD: float = 12.0  # Pixels of movement to cancel drag (allow scroll)

var _press_position: Vector2 = Vector2.ZERO
var _hold_timer: SceneTreeTimer = null
var _is_pressing: bool = false

func _gui_input(event: InputEvent):
	if not can_drag or not die_data:
		# Still allow click signal even if not draggable
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				die_clicked.emit(die_data)
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start hold-to-drag
			_press_position = event.global_position
			_is_pressing = true
			_hold_timer = get_tree().create_timer(DRAG_HOLD_TIME)
			_hold_timer.timeout.connect(_on_hold_complete)
		else:
			# Released — if still pressing (timer didn't fire), it's a tap
			if _is_pressing:
				_cancel_hold()
				die_clicked.emit(die_data)
	
	elif event is InputEventMouseMotion and _is_pressing:
		# If finger moved too far, cancel hold (user is scrolling)
		var distance = event.global_position.distance_to(_press_position)
		if distance > DRAG_MOVE_THRESHOLD:
			_cancel_hold()

func _cancel_hold():
	_is_pressing = false
	if _hold_timer and _hold_timer.timeout.is_connected(_on_hold_complete):
		_hold_timer.timeout.disconnect(_on_hold_complete)
	_hold_timer = null

func _on_hold_complete():
	if not _is_pressing:
		return
	_is_pressing = false
	_hold_timer = null
	_start_drag()

func _start_drag():
	if not die_data:
		return
	
	_is_being_dragged = true
	_was_placed = false
	visible = false
	
	var preview = _create_drag_preview()
	
	var drag_data = {
		"die": die_data,
		"visual": self,
		"source": "dice_pool",
		"source_position": global_position,
		"slot_index": get_index()
	}
	
	force_drag(drag_data, preview)

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		_is_being_dragged = false
		
		# Restore visibility if NOT placed in an action field
		if not _was_placed:
			visible = true
			modulate = Color.WHITE



func _create_drag_preview() -> Control:
	var face_size = Vector2(124, 124)
	var scene = _get_die_face_scene(die_data.die_type) if die_data else null
	
	var wrapper = Control.new()
	
	if scene:
		var face = scene.instantiate()
		wrapper.add_child(face)
		
		face.anchor_left = 0
		face.anchor_top = 0
		face.anchor_right = 0
		face.anchor_bottom = 0
		face.position = -face_size / 2
		face.size = face_size
		
		var label = face.find_child("ValueLabel", true, false) as Label
		if label:
			label.text = str(die_data.get_total_value())
		
		var tex = face.find_child("TextureRect", true, false) as TextureRect
		if tex:
			if die_data.fill_texture:
				tex.texture = die_data.fill_texture
			if die_data.color != Color.WHITE:
				tex.modulate = die_data.color
			
			if die_data.stroke_texture:
				var stroke_tex = TextureRect.new()
				stroke_tex.name = "StrokeTextureRect"
				stroke_tex.texture = die_data.stroke_texture
				stroke_tex.custom_minimum_size = tex.custom_minimum_size
				stroke_tex.size = tex.size
				stroke_tex.position = tex.position
				stroke_tex.expand_mode = tex.expand_mode
				stroke_tex.stretch_mode = tex.stretch_mode
				stroke_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stroke_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
				stroke_tex.anchor_left = tex.anchor_left
				stroke_tex.anchor_top = tex.anchor_top
				stroke_tex.anchor_right = tex.anchor_right
				stroke_tex.anchor_bottom = tex.anchor_bottom
				stroke_tex.offset_left = tex.offset_left
				stroke_tex.offset_top = tex.offset_top
				stroke_tex.offset_right = tex.offset_right
				stroke_tex.offset_bottom = tex.offset_bottom
				var parent = tex.get_parent()
				parent.add_child(stroke_tex)
				parent.move_child(stroke_tex, tex.get_index() + 1)
		
		_apply_preview_affix_effects(wrapper, face, tex)
	else:
		var label = Label.new()
		label.text = str(die_data.get_total_value()) if die_data else "?"
		label.custom_minimum_size = face_size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.position = -face_size / 2
		wrapper.add_child(label)
	
	wrapper.modulate = Color.WHITE
	return wrapper

func _apply_preview_affix_effects(wrapper: Control, face: Control, tex: TextureRect):
	if not die_data:
		return
	
	var face_size = Vector2(124, 124)
	
	# Find stroke texture if it exists
	var stroke_tex = face.find_child("StrokeTextureRect", true, false) as TextureRect
	var label = face.find_child("ValueLabel", true, false) as Label
	
	for affix in die_data.get_all_affixes():
		# Apply PREVIEW-ONLY effects first
		if affix.has_preview_effects():
			for preview_effect in affix.get_preview_effects():
				_apply_single_preview_effect(preview_effect, tex, stroke_tex, label, wrapper, face, face_size)
		
		# Check for per-component effects
		if affix.has_per_component_effects():
			if tex and affix.fill_effect_type == DiceAffix.VisualEffectType.SHADER and affix.fill_shader_material:
				tex.material = affix.fill_shader_material.duplicate(true)
			elif tex and affix.fill_effect_type == DiceAffix.VisualEffectType.COLOR_TINT:
				tex.modulate = tex.modulate * affix.fill_effect_color
			
			if stroke_tex and affix.stroke_effect_type == DiceAffix.VisualEffectType.SHADER and affix.stroke_shader_material:
				stroke_tex.material = affix.stroke_shader_material.duplicate(true)
			elif stroke_tex and affix.stroke_effect_type == DiceAffix.VisualEffectType.COLOR_TINT:
				stroke_tex.modulate = stroke_tex.modulate * affix.stroke_effect_color
			
			if label and affix.value_effect_type != DiceAffix.ValueEffectType.NONE:
				match affix.value_effect_type:
					DiceAffix.ValueEffectType.COLOR:
						label.add_theme_color_override("font_color", affix.value_text_color)
					DiceAffix.ValueEffectType.OUTLINE_COLOR:
						label.add_theme_color_override("font_outline_color", affix.value_outline_color)
					DiceAffix.ValueEffectType.COLOR_AND_OUTLINE:
						label.add_theme_color_override("font_color", affix.value_text_color)
						label.add_theme_color_override("font_outline_color", affix.value_outline_color)
					DiceAffix.ValueEffectType.SHADER:
						if affix.value_shader_material:
							label.material = affix.value_shader_material.duplicate(true)
			continue
		
		# Legacy effects
		match affix.visual_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if tex:
					tex.modulate = tex.modulate * affix.effect_color
			
			DiceAffix.VisualEffectType.SHADER:
				if tex and affix.shader_material:
					tex.material = affix.shader_material.duplicate(true)
				if stroke_tex and affix.shader_material:
					stroke_tex.material = affix.shader_material.duplicate(true)
			
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.overlay_texture:
					var overlay = TextureRect.new()
					overlay.texture = affix.overlay_texture
					overlay.custom_minimum_size = face_size
					overlay.size = face_size
					overlay.position = face.position
					overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					overlay.modulate.a = affix.overlay_opacity
					
					match affix.overlay_blend_mode:
						1:
							var mat = CanvasItemMaterial.new()
							mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
							overlay.material = mat
						2:
							var mat = CanvasItemMaterial.new()
							mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
							overlay.material = mat
					
					wrapper.add_child(overlay)
			
			DiceAffix.VisualEffectType.BORDER_GLOW:
				var glow = Panel.new()
				glow.custom_minimum_size = face_size
				glow.size = face_size
				glow.position = face.position
				
				var glow_style = StyleBoxFlat.new()
				glow_style.bg_color = Color.TRANSPARENT
				glow_style.border_color = affix.effect_color
				glow_style.set_border_width_all(3)
				glow_style.set_corner_radius_all(8)
				glow_style.shadow_color = affix.effect_color
				glow_style.shadow_size = 6
				glow.add_theme_stylebox_override("panel", glow_style)
				
				wrapper.add_child(glow)
				wrapper.move_child(glow, 0)
			
			DiceAffix.VisualEffectType.PARTICLE:
				pass

func _apply_single_preview_effect(effect: PreviewEffect, tex: TextureRect, stroke_tex: TextureRect, label: Label, wrapper: Control, face: Control, face_size: Vector2):
	"""Apply a single preview effect to the drag preview"""
	# Fill effects
	if tex and effect.fill_effect_type != PreviewEffect.VisualEffectType.NONE:
		match effect.fill_effect_type:
			PreviewEffect.VisualEffectType.COLOR_TINT:
				tex.modulate = tex.modulate * effect.fill_effect_color
			PreviewEffect.VisualEffectType.SHADER:
				if effect.fill_shader_material:
					tex.material = effect.fill_shader_material.duplicate(true)
			PreviewEffect.VisualEffectType.BORDER_GLOW:
				var glow = Panel.new()
				glow.custom_minimum_size = face_size
				glow.size = face_size
				glow.position = face.position
				var glow_style = StyleBoxFlat.new()
				glow_style.bg_color = Color.TRANSPARENT
				glow_style.border_color = effect.fill_effect_color
				glow_style.set_border_width_all(3)
				glow_style.set_corner_radius_all(8)
				glow_style.shadow_color = effect.fill_effect_color
				glow_style.shadow_size = 6
				glow.add_theme_stylebox_override("panel", glow_style)
				wrapper.add_child(glow)
				wrapper.move_child(glow, 0)
	
	# Stroke effects
	if stroke_tex and effect.stroke_effect_type != PreviewEffect.VisualEffectType.NONE:
		match effect.stroke_effect_type:
			PreviewEffect.VisualEffectType.COLOR_TINT:
				stroke_tex.modulate = stroke_tex.modulate * effect.stroke_effect_color
			PreviewEffect.VisualEffectType.SHADER:
				if effect.stroke_shader_material:
					stroke_tex.material = effect.stroke_shader_material.duplicate(true)
	
	# Value label effects
	if label and effect.value_effect_type != PreviewEffect.ValueEffectType.NONE:
		match effect.value_effect_type:
			PreviewEffect.ValueEffectType.COLOR:
				label.add_theme_color_override("font_color", effect.value_text_color)
			PreviewEffect.ValueEffectType.OUTLINE_COLOR:
				label.add_theme_color_override("font_outline_color", effect.value_outline_color)
			PreviewEffect.ValueEffectType.COLOR_AND_OUTLINE:
				label.add_theme_color_override("font_color", effect.value_text_color)
				label.add_theme_color_override("font_outline_color", effect.value_outline_color)
			PreviewEffect.ValueEffectType.SHADER:
				if effect.value_shader_material:
					label.material = effect.value_shader_material.duplicate(true)
	
	# Particle effects
	if effect.particle_scene:
		var particles = effect.particle_scene.instantiate()
		if particles:
			particles.position = effect.particle_offset
			particles.scale = effect.particle_scale
			if particles.has_method("set_emitting") or particles is GPUParticles2D:
				particles.emitting = true
			wrapper.add_child(particles)
