# res://scripts/ui/components/dice/die_object_base.gd
# Base class for die visual objects - handles textures, affixes, and animations
# Subclassed by CombatDieObject (rolled values) and PoolDieObject (max values)
extends Control
class_name DieObjectBase

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when user initiates drag - parent decides whether to allow it
signal drag_requested(die_object: DieObjectBase)
## Emitted on click (when not dragging)
signal clicked(die_object: DieObjectBase)
## Emitted when drag ends
signal drag_ended(die_object: DieObjectBase, was_placed: bool)

# ============================================================================
# EXPORTS
# ============================================================================
@export var base_size: Vector2 = Vector2(124, 124)

# ============================================================================
# NODE REFERENCES (set by scene, found in _ready if needed)
# ============================================================================
var fill_texture: TextureRect = null
var stroke_texture: TextureRect = null
var value_label: Label = null
var animation_player: AnimationPlayer = null
var preview_effects: Control = null

# ============================================================================
# PREVIEW MATERIALS (stored during setup, applied during drag)
# ============================================================================
var _preview_fill_material: Material = null
var _preview_stroke_material: Material = null
var _preview_value_material: Material = null

# ============================================================================
# STATE
# ============================================================================
var die_resource: DieResource = null
var draggable: bool = true
var _is_being_dragged: bool = false
var _was_placed: bool = false
var _original_position: Vector2 = Vector2.ZERO
var _original_scale: Vector2 = Vector2.ONE

var _manual_preview: Control = null
var _active_touches: Dictionary = {}  # touch_index -> true, tracked during drag


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = base_size
	size = base_size
	pivot_offset = base_size / 2
	set_process(false)  # Only process during drag
	
	_discover_nodes()
	
	# If die_resource was set before _ready (e.g., via setup), apply it now
	if die_resource:
		_apply_all_visuals()

func _discover_nodes():
	"""Find child nodes - called automatically, can be overridden"""
	if not fill_texture:
		fill_texture = find_child("FillTexture", true, false) as TextureRect
	if not stroke_texture:
		stroke_texture = find_child("StrokeTexture", true, false) as TextureRect
	if not value_label:
		value_label = find_child("ValueLabel", true, false) as Label
	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not preview_effects:
		preview_effects = find_child("PreviewEffects", true, false) as Control

# ============================================================================
# SETUP API
# ============================================================================

func setup(die: DieResource):
	"""Initialize the die object with a DieResource"""
	die_resource = die
	
	if not is_inside_tree():
		# Will apply in _ready
		return
	
	_discover_nodes()
	_apply_all_visuals()

func _apply_all_visuals():
	"""Apply all visual properties from die_resource"""
	_apply_textures()
	_apply_base_color()
	_apply_affixes()
	_setup_preview_effects()
	_update_value_display()

func _apply_textures():
	"""Apply fill and stroke textures from the DieResource"""
	if not die_resource:
		return
	
	if fill_texture and die_resource.fill_texture:
		fill_texture.texture = die_resource.fill_texture
	
	if stroke_texture and die_resource.stroke_texture:
		stroke_texture.texture = die_resource.stroke_texture

func _apply_base_color():
	"""Apply the die's base color tint"""
	if not die_resource or not fill_texture:
		return
	
	if die_resource.color != Color.WHITE:
		fill_texture.modulate = die_resource.color
	else:
		fill_texture.modulate = Color.WHITE

func _apply_affixes():
	"""Apply visual effects from all affixes on the die"""
	if not die_resource:
		return
	
	for affix in die_resource.get_all_affixes():
		_apply_single_affix(affix)

func _apply_single_affix(affix: DiceAffix):
	"""Apply a single affix's visual effects"""
	if not affix:
		return
	
	# Check for per-component effects first (newer system)
	if affix.has_method("has_per_component_effects") and affix.has_per_component_effects():
		_apply_per_component_effects(affix)
	else:
		# Fallback to unified visual effect (older system)
		_apply_unified_visual_effect(affix)

func _apply_per_component_effects(affix: DiceAffix):
	"""Apply per-component (fill/stroke/value) effects — uses resolve methods for global config"""
	# Fill effects
	if fill_texture:
		match affix.fill_effect_type:
			DiceAffix.VisualEffectType.SHADER:
				var mat = affix.resolve_fill_material()
				if mat:
					fill_texture.material = mat
			DiceAffix.VisualEffectType.COLOR_TINT:
				fill_texture.modulate = fill_texture.modulate * affix.fill_effect_color
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.fill_overlay_texture:
					_add_overlay(fill_texture, affix.fill_overlay_texture, 
						affix.fill_overlay_blend_mode, affix.fill_overlay_opacity)
	
	# Stroke effects
	if stroke_texture:
		match affix.stroke_effect_type:
			DiceAffix.VisualEffectType.SHADER:
				var mat = affix.resolve_stroke_material()
				if mat:
					stroke_texture.material = mat
			DiceAffix.VisualEffectType.COLOR_TINT:
				stroke_texture.modulate = stroke_texture.modulate * affix.stroke_effect_color
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.stroke_overlay_texture:
					_add_overlay(stroke_texture, affix.stroke_overlay_texture,
						affix.stroke_overlay_blend_mode, affix.stroke_overlay_opacity)
	
	# Value label effects
	# Value label effects
	if value_label:
		match affix.value_effect_type:
			DiceAffix.ValueEffectType.COLOR:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
			DiceAffix.ValueEffectType.OUTLINE_COLOR:
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			DiceAffix.ValueEffectType.COLOR_AND_OUTLINE:
				value_label.add_theme_color_override("font_color", affix.value_text_color)
				value_label.add_theme_color_override("font_outline_color", affix.value_outline_color)
			# Value shaders disabled — keep values readable with black outline



func _apply_unified_visual_effect(affix: DiceAffix):
	"""Apply unified visual effect (legacy - affects entire die)"""
	match affix.visual_effect_type:
		DiceAffix.VisualEffectType.COLOR_TINT:
			if fill_texture:
				fill_texture.modulate = fill_texture.modulate * affix.effect_color
		DiceAffix.VisualEffectType.SHADER:
			if affix.shader_material:
				if fill_texture:
					fill_texture.material = affix.shader_material.duplicate(true)
				if stroke_texture:
					stroke_texture.material = affix.shader_material.duplicate(true)
		DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
			if affix.overlay_texture and fill_texture:
				_add_overlay(fill_texture, affix.overlay_texture, 
					affix.overlay_blend_mode, affix.overlay_opacity)
		DiceAffix.VisualEffectType.BORDER_GLOW:
			_add_border_glow(affix.effect_color)

func _add_overlay(target: TextureRect, texture: Texture2D, blend_mode: int, opacity: float):
	"""Add an overlay texture on top of a target"""
	var overlay = TextureRect.new()
	overlay.name = "AffixOverlay"
	overlay.texture = texture
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.modulate.a = opacity
	
	match blend_mode:
		1:  # Add
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			overlay.material = mat
		2:  # Multiply
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
			overlay.material = mat
	
	target.add_child(overlay)

func _add_border_glow(color: Color):
	"""Add a glowing border effect"""
	var glow = Panel.new()
	glow.name = "BorderGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color.TRANSPARENT
	glow_style.border_color = color
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = color
	glow_style.shadow_size = 6
	glow.add_theme_stylebox_override("panel", glow_style)
	
	add_child(glow)
	move_child(glow, 0)  # Behind everything

# ============================================================================
# PREVIEW EFFECTS SETUP
# ============================================================================

func _setup_preview_effects():
	"""Populate PreviewEffects node from affix preview_effects arrays"""
	if not die_resource or not preview_effects:
		return
	
	# Clear any existing preview effect children
	for child in preview_effects.get_children():
		child.queue_free()
	
	# Clear stored materials
	_preview_fill_material = null
	_preview_stroke_material = null
	_preview_value_material = null
	
	# Collect preview effects from all affixes
	for affix in die_resource.get_all_affixes():
		if not affix.has_method("has_preview_effects"):
			continue
		if not affix.has_preview_effects():
			continue
		
		for effect in affix.get_preview_effects():
			_add_preview_effect(effect)

func _add_preview_effect(effect):
	"""Add a single PreviewEffect - particles to node, materials stored for drag"""
	# Store materials for application during drag preview
	if effect.fill_shader_material:
		_preview_fill_material = effect.fill_shader_material
	if effect.stroke_shader_material:
		_preview_stroke_material = effect.stroke_shader_material
	if effect.value_shader_material:
		_preview_value_material = effect.value_shader_material
	
	# Instantiate particle scenes into PreviewEffects container
	if effect.particle_scene and preview_effects:
		var particles = effect.particle_scene.instantiate()
		particles.position = effect.particle_offset
		particles.scale = effect.particle_scale
		# Don't start emitting yet - will start when shown
		if particles is GPUParticles2D or particles is CPUParticles2D:
			particles.emitting = false
		preview_effects.add_child(particles)

# ============================================================================
# VALUE DISPLAY - Override in subclasses
# ============================================================================

func _update_value_display():
	"""Override in subclass to show rolled vs max value"""
	pass

# ============================================================================
# REFRESH API
# ============================================================================

func refresh_display():
	"""Refresh all visual elements (call after die_resource changes)"""
	_clear_affix_effects()
	_apply_all_visuals()

func _clear_affix_effects():
	"""Remove all dynamically applied affix effects"""
	# Clear materials
	if fill_texture:
		fill_texture.material = null
		fill_texture.modulate = Color.WHITE
	if stroke_texture:
		stroke_texture.material = null
		stroke_texture.modulate = Color.WHITE
	if value_label:
		value_label.material = null
		value_label.remove_theme_color_override("font_color")
		value_label.remove_theme_color_override("font_outline_color")
	
	# Remove dynamically added children
	for child in get_children():
		if child.name == "BorderGlow" or child.name == "AffixOverlay":
			child.queue_free()
	
	# Remove overlays from fill/stroke
	if fill_texture:
		for child in fill_texture.get_children():
			if child.name == "AffixOverlay":
				child.queue_free()
	if stroke_texture:
		for child in stroke_texture.get_children():
			if child.name == "AffixOverlay":
				child.queue_free()

# ============================================================================
# DRAG VISUAL PRIMITIVES - Called by parent, not directly by drag system
# ============================================================================

func start_drag_visual():
	"""Visual feedback when drag starts"""
	_is_being_dragged = true
	_original_position = position
	_original_scale = scale
	
	if animation_player and animation_player.has_animation("pickup"):
		animation_player.play("pickup")
	else:
		# Fallback tween animation
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func end_drag_visual(was_placed: bool):
	"""Visual feedback when drag ends"""
	_is_being_dragged = false
	_was_placed = was_placed
	
	if was_placed:
		if animation_player and animation_player.has_animation("place"):
			animation_player.play("place")
		else:
			# Fallback - just reset
			modulate = Color.WHITE
			scale = Vector2.ONE
	else:
		if animation_player and animation_player.has_animation("snap_back"):
			animation_player.play("snap_back")
		else:
			# Fallback tween snap back
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(self, "scale", _original_scale, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	drag_ended.emit(self, was_placed)

func show_reject_feedback():
	"""Visual feedback when action is rejected"""
	if animation_player and animation_player.has_animation("reject"):
		animation_player.play("reject")
	else:
		# Fallback shake animation
		var tween = create_tween()
		var orig_pos = position
		tween.tween_property(self, "position", orig_pos + Vector2(-5, 0), 0.05)
		tween.tween_property(self, "position", orig_pos + Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", orig_pos + Vector2(-3, 0), 0.05)
		tween.tween_property(self, "position", orig_pos, 0.05)

func show_hover():
	"""Visual feedback on mouse hover"""
	if not draggable:
		return
	
	if animation_player and animation_player.has_animation("hover"):
		animation_player.play("hover")
	else:
		# Subtle scale up
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func hide_hover():
	"""Remove hover feedback"""
	if _is_being_dragged:
		return  # Don't interrupt drag
	
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
	else:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func play_roll_source_animation():
	"""Flash when this die is the source of a roll projectile"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.8, 1.8, 1.8), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func play_roll_animation():
	"""Play roll complete animation (combat dice)"""
	if animation_player and animation_player.has_animation("roll_complete"):
		animation_player.play("roll_complete")

func play_locked_animation():
	"""Play locked state animation"""
	if animation_player and animation_player.has_animation("locked"):
		animation_player.play("locked")
	else:
		# Fallback - desaturate
		modulate = Color(0.7, 0.7, 0.7)

# ============================================================================
# SCALING FOR DIFFERENT CONTEXTS
# ============================================================================

func set_display_scale(target_scale: float):
	"""Instantly set scale (e.g., 0.5 for action field slots)"""
	scale = Vector2(target_scale, target_scale)

func animate_to_scale(target_scale: float, duration: float = 0.2) -> Tween:
	"""Animate to target scale, returns tween for chaining"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

func animate_to_position(target_pos: Vector2, duration: float = 0.2) -> Tween:
	"""Animate to target position, returns tween for chaining"""
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

# ============================================================================
# DRAG PREVIEW CREATION
# ============================================================================

func create_drag_preview() -> Control:
	"""Create a visual copy for drag preview with preview effects"""
	var preview = duplicate() as DieObjectBase
	preview.draggable = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	
	# Reset layout for manual positioning
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	preview.offset_left = 0
	preview.offset_top = 0
	preview.offset_right = base_size.x
	preview.offset_bottom = base_size.y
	preview.size = base_size
	
	# Show preview effects and apply stored materials
	_activate_preview_effects(preview)
	
	return preview

func _activate_preview_effects(preview: Control):
	"""Activate preview effects on a preview copy"""
	# Show the PreviewEffects container
	var effects_container = preview.find_child("PreviewEffects", true, false)
	if effects_container:
		effects_container.show()
		# Start any particle emitters
		for child in effects_container.get_children():
			if child is GPUParticles2D or child is CPUParticles2D:
				child.emitting = true
	
	# Apply stored preview materials
	if _preview_fill_material:
		var fill = preview.find_child("FillTexture", true, false) as TextureRect
		if fill:
			fill.material = _preview_fill_material.duplicate(true)
	
	if _preview_stroke_material:
		var stroke = preview.find_child("StrokeTexture", true, false) as TextureRect
		if stroke:
			stroke.material = _preview_stroke_material.duplicate(true)
	
	if _preview_value_material:
		var label = preview.find_child("ValueLabel", true, false) as Label
		if label:
			label.material = _preview_value_material.duplicate(true)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Godot's native drag initiation - returns drag data to start dragging"""
	print("🎲 DieObjectBase._get_drag_data() - draggable=%s, die=%s" % [draggable, die_resource != null])
	
	if not draggable or not die_resource:
		print("  ❌ Cannot drag: draggable=%s, has_resource=%s" % [draggable, die_resource != null])
		return null
	
	if die_resource.is_locked:
		print("  ❌ Die is locked")
		show_reject_feedback()
		return null
	
	print("  ✅ Starting drag for %s" % die_resource.display_name)
	
	# Start visual feedback
	start_drag_visual()
	
	# Emit signal for parent to know
	drag_requested.emit(self)
	
	# Create manual preview (not using set_drag_preview to avoid can't-drop cursor)
	_manual_preview = create_drag_preview()
	# =========================================================================
	# DRAG-DROP FIX: Recursively set MOUSE_FILTER_IGNORE on the entire preview
	# tree. Without this, the preview Control sits under the cursor at z_index
	# 100 and intercepts _can_drop_data checks, preventing ActionField from
	# ever seeing the drop. create_drag_preview() sets IGNORE on the root but
	# child nodes (FillTexture, StrokeTexture, ValueLabel, PreviewEffects,
	# particles, etc.) can still have STOP or PASS and block the hit test.
	# =========================================================================
	_set_mouse_ignore_recursive(_manual_preview)
	_manual_preview.z_index = 100  # Always on top
	# Add to highest CanvasLayer so preview renders above all UI
	var overlay = _find_top_canvas_layer()
	overlay.add_child(_manual_preview)
	print("🎲 Preview parented to: %s (class: %s, layer: %s)" % [
	overlay.name, overlay.get_class(),
	overlay.layer if overlay is CanvasLayer else "N/A"])
	_update_manual_preview_position()
	_active_touches.clear()
	set_process(true)
	set_process_input(true)
	
	
	self.modulate = Color(1, 1, 1, 0)
	
	# Return drag data
	return {
		"type": "combat_die",
		"die": die_resource,
		"die_object": self,
		"visual": self,
		"source_position": global_position,
		"slot_index": get_index()
	}

func _process(_delta: float):
	if _manual_preview and _is_being_dragged:
		# Safety net: if all input is released but NOTIFICATION_DRAG_END
		# never fired (lag spike, focus loss, touch desyncs, etc.),
		# clean up the orphaned preview ourselves.
		var mouse_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var touch_held = _active_touches.size() > 0
		if not mouse_held and not touch_held:
			_force_cleanup_drag()
			return
		_update_manual_preview_position()

func _input(event: InputEvent):
	# Only process touch events while actively dragging
	if not _is_being_dragged:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = true
		else:
			_active_touches.erase(event.index)

func _update_manual_preview_position():
	if _manual_preview:
		_manual_preview.global_position = get_global_mouse_position() - base_size / 2

func _force_cleanup_drag():
	self.modulate = Color.WHITE
	"""Emergency cleanup when NOTIFICATION_DRAG_END is missed."""
	print("🎲 Drag cleanup: input released but NOTIFICATION_DRAG_END missed — forcing cleanup")
	if _is_being_dragged:
		end_drag_visual(_was_placed)
		_is_being_dragged = false
	if _manual_preview:
		_manual_preview.queue_free()
		_manual_preview = null
	_active_touches.clear()
	set_process(false)
	set_process_input(false)

func _find_top_canvas_layer() -> Node:
	"""Find the highest CanvasLayer to parent the drag preview on,
	so it renders above all other UI layers."""
	var best: CanvasLayer = null
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			if not best or child.layer > best.layer:
				best = child
	# Fallback to root if no CanvasLayer found
	return best if best else get_tree().root


func _notification(what: int):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if draggable and not _is_being_dragged:
				show_hover()
		NOTIFICATION_MOUSE_EXIT:
			if not _is_being_dragged:
				hide_hover()
		NOTIFICATION_DRAG_END:
			self.modulate = Color.WHITE
			if _is_being_dragged:
				end_drag_visual(_was_placed)
				_is_being_dragged = false
			# Clean up manual preview
			if _manual_preview:
				_manual_preview.queue_free()
				_manual_preview = null
			_active_touches.clear()
			set_process(false)
			set_process_input(false)

# ============================================================================
# UTILITY
# ============================================================================

func mark_as_placed():
	"""Called when die is successfully placed (e.g., in action field)"""
	_was_placed = true

func get_die() -> DieResource:
	"""Get the associated DieResource"""
	return die_resource

func is_being_dragged() -> bool:
	return _is_being_dragged

# ============================================================================
# DRAG-DROP FIX HELPER (NEW)
# ============================================================================

func _set_mouse_ignore_recursive(node: Node):
	"""Recursively set MOUSE_FILTER_IGNORE on a node and all Control children.
	This prevents the drag preview from intercepting drop target detection.
	Called on the manual preview after create_drag_preview() to ensure child
	nodes like FillTexture, StrokeTexture, ValueLabel, particle emitters,
	and PreviewEffects containers don't block the mouse from reaching the
	ActionField underneath."""
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
