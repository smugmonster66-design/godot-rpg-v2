# res://scripts/ui/combat/mana_die_selector.gd
# Mana die selector widget for the bottom UI panel.
# Scene-based — all layout is in mana_die_selector.tscn.
#
# Contains a mana progress bar with a 3×3 die-type selector grid. The center
# cell shows a preview of the currently selected mana die (element + size).
#
# DRAG FLOW:
#   1. Player clicks & drags preview → die visual leaves selector, follows cursor
#   2. Drop on hand area (DicePoolDisplay) → mana spent, die added to hand,
#      new preview grows back in selector
#   3. Drop anywhere else → die snaps back to selector, no mana spent
#
# Uses manual drag (not Godot's native _can_drop_data) to avoid CanvasLayer
# cross-layer issues between PersistentUILayer and CombatLayer.
extends Control
class_name ManaDieSelector

# ============================================================================
# SIGNALS
# ============================================================================

signal drag_started()
signal drag_ended(was_placed: bool)

# ============================================================================
# NODE REFERENCES — matching mana_die_selector.tscn
# ============================================================================


@onready var mana_bar: TextureProgressBar = $HBoxContainer/ManaBar
@onready var mana_label: Label = $ManaLabel
@onready var cost_label: Label = $CostLabel
@onready var selector_grid: GridContainer = $HBoxContainer/SelectorGrid
@onready var die_preview_container: PanelContainer = $HBoxContainer/SelectorGrid/DiePreviewContainer
@onready var elem_left_btn: Button = $HBoxContainer/SelectorGrid/ElemLeftBtn
@onready var elem_right_btn: Button = $HBoxContainer/SelectorGrid/ElemRightBtn
@onready var size_up_btn: Button = $HBoxContainer/SelectorGrid/SizeUpBtn
@onready var size_down_btn: Button = $HBoxContainer/SelectorGrid/SizeDownBtn
@onready var preview_anchor: Control = $HBoxContainer/SelectorGrid/DiePreviewContainer/PreviewCenter




# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("Colors")
@export var cost_affordable_color: Color = Color(0.8, 0.9, 1.0)
@export var cost_unaffordable_color: Color = Color(1.0, 0.3, 0.3)

@export_group("Layout")
@export var preview_cell_size: Vector2 = Vector2(64, 64)


# ============================================================================
# STATE
# ============================================================================

var _current_preview: Control = null
var player = null
var mana_pool: ManaPool = null
var is_drag_enabled: bool = false
var is_caster: bool = false

# ============================================================================
# DRAG STATE
# ============================================================================

var _drag_visual: Control = null
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO

# ============================================================================
# CONSTANTS
# ============================================================================

# Element colors resolved via ThemeManager.get_die_element_color()

const ELEMENT_TAGS: Dictionary = {
	DieResource.Element.NONE: "neutral",
	DieResource.Element.SLASHING: "slashing",
	DieResource.Element.BLUNT: "blunt",
	DieResource.Element.PIERCING: "piercing",
	DieResource.Element.FIRE: "fire",
	DieResource.Element.ICE: "ice",
	DieResource.Element.SHOCK: "shock",
	DieResource.Element.POISON: "poison",
	DieResource.Element.SHADOW: "shadow",
}

const DRAG_THRESHOLD: float = 5.0

# ============================================================================
# INITIALIZATION
# ============================================================================


func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

	if die_preview_container:
		die_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		die_preview_container.custom_minimum_size = preview_cell_size
	if selector_grid:
		selector_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var legacy = find_child("ManaDragSource", true, false)
	if legacy:
		legacy.queue_free()

	call_deferred("_debug_layout")

func _debug_layout():
	await get_tree().process_frame
	await get_tree().process_frame
	var hbox = $HBoxContainer
	print("🔮 LAYOUT DEBUG 2:")
	print("  root: size=%s, pos=%s" % [size, position])
	print("  hbox: size=%s, pos=%s" % [hbox.size, hbox.position])
	print("  mana_bar: size=%s, pos=%s, gpos=%s" % [mana_bar.size, mana_bar.position, mana_bar.global_position])
	print("  grid: size=%s, pos=%s, gpos=%s" % [selector_grid.size, selector_grid.position, selector_grid.global_position])
	print("  die_container: size=%s, pos=%s, gpos=%s" % [die_preview_container.size, die_preview_container.position, die_preview_container.global_position])
	print("  preview_anchor: size=%s, pos=%s" % [preview_anchor.size, preview_anchor.position])
	if _current_preview and is_instance_valid(_current_preview):
		print("  preview: size=%s, pos=%s, scale=%s, min=%s" % [_current_preview.size, _current_preview.position, _current_preview.scale, _current_preview.custom_minimum_size])
	if _current_preview and is_instance_valid(_current_preview):
		print("  preview: size=%s, pos=%s, scale=%s, min=%s, pivot=%s" % [_current_preview.size, _current_preview.position, _current_preview.scale, _current_preview.custom_minimum_size, _current_preview.pivot_offset])
		if "base_size" in _current_preview:
			print("  preview base_size=%s" % _current_preview.base_size)



func initialize(p) -> void:
	player = p

	if not player.has_method("has_mana_pool") or not player.has_mana_pool():
		visible = false
		is_caster = false
		return

	mana_pool = player.mana_pool
	is_caster = true
	visible = true

	# Connect signals (disconnect first to avoid duplicates)
	if mana_pool.mana_changed.is_connected(_on_mana_changed):
		mana_pool.mana_changed.disconnect(_on_mana_changed)
	mana_pool.mana_changed.connect(_on_mana_changed)

	if mana_pool.element_changed.is_connected(_on_element_changed):
		mana_pool.element_changed.disconnect(_on_element_changed)
	mana_pool.element_changed.connect(_on_element_changed)

	if mana_pool.die_size_changed.is_connected(_on_size_changed):
		mana_pool.die_size_changed.disconnect(_on_size_changed)
	mana_pool.die_size_changed.connect(_on_size_changed)

	if mana_pool.pull_failed.is_connected(_on_pull_failed):
		mana_pool.pull_failed.disconnect(_on_pull_failed)
	mana_pool.pull_failed.connect(_on_pull_failed)

	if mana_pool.options_changed.is_connected(_on_options_changed):
		mana_pool.options_changed.disconnect(_on_options_changed)
	mana_pool.options_changed.connect(_on_options_changed)


	_update_all()
	print("🔮 ManaDieSelector: Initialized (caster)")

func set_drag_enabled(enabled: bool):
	is_drag_enabled = enabled
	_update_preview_appearance()

# ============================================================================
# MANUAL DRAG — bypasses Godot's native drag system entirely
# ============================================================================

func _input(event: InputEvent):
	if not is_drag_enabled or not visible:
		return

	# --- START DRAG ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _is_dragging:
			if die_preview_container and die_preview_container.get_global_rect().has_point(get_global_mouse_position()):
				if not mana_pool or not mana_pool.can_pull():
					if mana_pool:
						mana_pool.pull_failed.emit("Cannot pull — insufficient mana or no options")
					return
				_begin_drag()
				get_viewport().set_input_as_handled()

		elif not event.pressed and _is_dragging:
			_end_drag()
			get_viewport().set_input_as_handled()

	# --- MOVE DRAG ---
	elif event is InputEventMouseMotion and _is_dragging and _drag_visual:
		# Use base_size (unscaled) for centering — scale may be mid-tween
		var half = Vector2(62, 62)
		if "base_size" in _drag_visual and _drag_visual.base_size.length() > 0:
			half = _drag_visual.base_size / 2.0
		_drag_visual.global_position = get_global_mouse_position() - half

		# Update insertion gap indicator in the hand display
		_update_insertion_gap(get_global_mouse_position())

		get_viewport().set_input_as_handled()


func _update_insertion_gap(mouse_pos: Vector2) -> void:
	"""Tell DicePoolDisplay to show/move/hide the insertion gap based on cursor position."""
	var displays = get_tree().get_nodes_in_group("dice_pool_display")
	for node in displays:
		if node is DicePoolDisplay and node.visible:
			# Show gap if cursor is over the hand display (use the same check as drop detection)
			var rect = node.get_global_rect().grow(60)  # Match the padding from _is_over_hand_area
			if rect.has_point(mouse_pos):
				var idx = node.get_insertion_index_at_position(mouse_pos)
				node.show_insertion_gap(idx)
			else:
				node.hide_insertion_gap()
			return



func _clear_insertion_gap() -> void:
	"""Remove the insertion gap from all displays instantly.
	Used during drop/cancel — the hand is about to refresh so no animation needed."""
	var displays = get_tree().get_nodes_in_group("dice_pool_display")
	for node in displays:
		if node is DicePoolDisplay:
			node.hide_insertion_gap(true)



func _begin_drag():
	"""Start dragging — hide preview, create full-size floating visual."""
	_is_dragging = true
	_drag_start_pos = die_preview_container.global_position + die_preview_container.size / 2.0
	drag_started.emit()
	print("🎲 ManaDieSelector: Drag started")

	# Hide the preview in the selector
	if _current_preview:
		_current_preview.visible = false

	# Create floating drag visual at FULL SIZE (no scaling)
	var preview_die = _create_preview_die_resource()
	if not preview_die:
		_cancel_drag()
		return

	var visual = preview_die.instantiate_combat_visual()
	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		_set_mouse_ignore_recursive(visual)
		# Hide value label on drag preview
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
		visual.z_index = 100
		visual.modulate = Color(1, 1, 1, 0.9)
		# Add to overlay for visibility above all UI
		var overlay = get_tree().current_scene.find_child("DragOverlayLayer", true, false)
		if overlay:
			overlay.add_child(visual)
		else:
			get_tree().root.add_child(visual)
		_drag_visual = visual
		# Center on cursor using base_size (full size, no scaling)
		var half = Vector2(62, 62)
		if "base_size" in visual:
			half = visual.base_size / 2
		visual.global_position = get_global_mouse_position() - half
	else:
		_cancel_drag()



func _end_drag():
	"""Release — check if over hand area, spend mana or snap back."""
	_is_dragging = false
	var mouse = get_global_mouse_position()

	if _is_over_hand_area(mouse):
		_complete_drop()
	else:
		_cancel_drag()


func _is_over_hand_area(mouse: Vector2) -> bool:
	"""Check if mouse is over the hand area — uses generous padding for usability."""
	# Check DicePoolDisplay via group (with padding)
	var displays = get_tree().get_nodes_in_group("dice_pool_display")
	for node in displays:
		var ctrl = node as Control
		if ctrl and ctrl.visible:
			var rect = ctrl.get_global_rect().grow(60)  # 60px padding on all sides
			if rect.has_point(mouse):
				print("  ✅ Over DicePoolDisplay (padded): rect=%s mouse=%s" % [rect, mouse])
				return true

	# Check DicePoolArea parent container
	var pool_area = get_tree().current_scene.find_child("DicePoolArea", true, false) as Control
	if pool_area and pool_area.visible:
		var rect = pool_area.get_global_rect().grow(40)
		if rect.has_point(mouse):
			print("  ✅ Over DicePoolArea (padded): rect=%s mouse=%s" % [pool_area.get_global_rect(), mouse])
			return true

	# Fallback: anywhere above the ManaDieSelector counts as "hand area" during combat
	# This makes it very forgiving — if they drag upward at all, it works
	var selector_top = global_position.y
	if mouse.y < selector_top:
		print("  ✅ Above ManaDieSelector (y=%s < %s)" % [mouse.y, selector_top])
		return true

	print("  ❌ Not over hand area. mouse=%s" % mouse)
	if displays.size() > 0:
		var ctrl = displays[0] as Control
		if ctrl:
			print("    DicePoolDisplay rect=%s visible=%s" % [ctrl.get_global_rect(), ctrl.visible])
	return false


func _complete_drop():
	"""Mana die dropped on hand — spend mana, insert die at drop position, grow new preview."""
	print("🎲 ManaDieSelector: Drop on hand — spending mana")

	_clear_insertion_gap()



	var die = mana_pool.pull_mana_die()
	if not die:
		_cancel_drag()
		return

	# Calculate insertion index from mouse position relative to hand visuals
	var insert_index: int = -1
	var mouse_pos = get_global_mouse_position()
	var displays = get_tree().get_nodes_in_group("dice_pool_display")
	for node in displays:
		if node is DicePoolDisplay and node.visible:
			insert_index = node.get_insertion_index_at_position(mouse_pos)
			break

	# Insert into player's hand at the calculated position
	if player and player.dice_pool:
		if insert_index >= 0:
			player.dice_pool.insert_into_hand(insert_index, die)
			print("🔮 Mana die inserted at index %d: %s (D%d, value=%d)" % [
				insert_index, die.display_name, die.die_type, die.get_total_value()])
		else:
			# Fallback: append at end
			player.dice_pool.add_die_to_hand(die)
			print("🔮 Mana die appended to hand: %s (D%d, value=%d)" % [
				die.display_name, die.die_type, die.get_total_value()])

	# Remove drag visual
	if _drag_visual and is_instance_valid(_drag_visual):
		_drag_visual.queue_free()
		_drag_visual = null

	# Update all displays (mana bar, cost, etc.)
	_update_mana_bar(mana_pool.current_mana, mana_pool.max_mana)
	_update_cost_label()
	_update_preview_appearance()
	_update_button_visibility()

	# Grow a fresh preview from center of the selector
	_animate_preview_grow_back()

	drag_ended.emit(true)

func _cancel_drag():
	"""Drag cancelled — animate die back to selector center at full size, then shrink to fit.
	
	IMPORTANT: drag_ended is emitted AFTER the tween completes (in the Phase 3
	callback) to prevent external signal handlers from interfering with the
	animation or preview state mid-tween.
	"""
	print("🎲 ManaDieSelector: Drag cancelled — snapping back")

	_clear_insertion_gap()

	# Immediately restore the real preview underneath — the drag visual
	# animates on top of it in the overlay layer, so this is invisible
	# until the drag visual is freed. This guarantees the preview is
	# always restored even if the tween breaks.
	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.visible = true

	if _drag_visual and is_instance_valid(_drag_visual):
		var target_pos = die_preview_container.global_position
		var target_center = target_pos + die_preview_container.size / 2.0

		# Calculate where to place full-size visual so its center hits the container center
		var half = Vector2(62, 62)
		if "base_size" in _drag_visual:
			half = _drag_visual.base_size / 2.0
		var snap_target = target_center - half

		# Calculate the preview's display scale for the shrink phase
		var cell_size = die_preview_container.custom_minimum_size.x if die_preview_container else 48.0
		var target_size = cell_size - 8
		var preview_scale = Vector2.ONE
		if "base_size" in _drag_visual and _drag_visual.base_size.x > 0:
			var s = target_size / _drag_visual.base_size.x
			preview_scale = Vector2(s, s)

		# Capture a weak reference so lambdas don't prevent cleanup
		var drag_ref = weakref(_drag_visual)

		# Phase 1: fly back at full size
		var tween = create_tween()
		tween.tween_property(_drag_visual, "global_position", snap_target, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Phase 2: shrink into the selector
		tween.tween_callback(func():
			var dv = drag_ref.get_ref()
			if dv and is_instance_valid(dv):
				dv.pivot_offset = half
		)
		tween.tween_property(_drag_visual, "scale", preview_scale, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

		# Phase 3: cleanup and emit signal AFTER animation completes
		tween.tween_callback(func():
			var dv = drag_ref.get_ref()
			if dv and is_instance_valid(dv):
				dv.queue_free()
			_drag_visual = null
			drag_ended.emit(false)
		)

		# Safety: if the tween is killed (e.g. node exits tree), clean up
		tween.finished.connect(func():
			var dv = drag_ref.get_ref()
			if dv and is_instance_valid(dv):
				dv.queue_free()
			_drag_visual = null
		, CONNECT_ONE_SHOT)
	else:
		# No drag visual to animate — emit immediately
		drag_ended.emit(false)

func _animate_preview_grow_back():
	"""After a successful drop, rebuild die preview and animate it growing from zero."""
	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.queue_free()
		_current_preview = null

	var preview_die = _create_preview_die_resource()
	if not preview_die:
		return

	var cell_size = die_preview_container.custom_minimum_size.x if die_preview_container else 48.0
	var target_size = cell_size - 8
	var final_scale := Vector2.ONE

	var visual: Control = null
	if preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	if not visual and preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()

	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
		_current_preview = visual
	else:
		var lbl = Label.new()
		lbl.text = "%s\nD%d" % [mana_pool.get_element_name(), mana_pool.selected_die_size]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", ThemeManager.get_die_element_color(mana_pool.selected_element))
		_current_preview = lbl

	preview_anchor.add_child(_current_preview)
	_current_preview.custom_minimum_size = Vector2.ZERO

	# Position at center, start at near-zero scale
	if _current_preview is DieObjectBase and "base_size" in _current_preview and _current_preview.base_size.x > 0:
		var s = target_size / _current_preview.base_size.x
		final_scale = Vector2(s, s)
		_current_preview.pivot_offset = _current_preview.base_size / 2.0
		_current_preview.position = Vector2(cell_size, cell_size) / 2.0 - _current_preview.pivot_offset
		_current_preview.scale = Vector2(0.001, 0.001)
	else:
		_current_preview.size = Vector2(target_size, target_size)
		_current_preview.position = Vector2(4, 4)
		_current_preview.scale = Vector2(0.001, 0.001)

	_set_mouse_ignore_recursive(_current_preview)

	var tween = create_tween()
	tween.tween_property(_current_preview, "scale", final_scale, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _find_hand_display() -> Control:
	"""Find the DicePoolDisplay node across CanvasLayers."""
	# Try group first
	var displays = get_tree().get_nodes_in_group("dice_pool_display")
	if displays.size() > 0:
		return displays[0] as Control
	# Fallback: search scene tree
	return get_tree().current_scene.find_child("DicePoolDisplay", true, false) as Control

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_elem_left():
	if mana_pool:
		mana_pool.cycle_element(-1)

func _on_elem_right():
	if mana_pool:
		mana_pool.cycle_element(1)

func _on_size_up():
	if mana_pool:
		mana_pool.cycle_die_size(1)

func _on_size_down():
	if mana_pool:
		mana_pool.cycle_die_size(-1)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_mana_changed(current: int, max_mana: int):
	_update_mana_bar(current, max_mana)
	_update_cost_label()
	_update_preview_appearance()

func _on_element_changed(_element):
	_update_die_preview()
	_update_cost_label()

func _on_size_changed(_die_size):
	_update_die_preview()
	_update_cost_label()

func _on_pull_failed(reason: String):
	print("🔮 ManaDieSelector: Pull failed — %s" % reason)
	if die_preview_container:
		var tween = create_tween()
		tween.tween_property(die_preview_container, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(die_preview_container, "modulate", Color.WHITE, 0.2)

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_all():
	if not mana_pool:
		return
	_update_mana_bar(mana_pool.current_mana, mana_pool.max_mana)
	_update_die_preview()
	_update_button_visibility()
	_update_cost_label()
	_update_preview_appearance()

func _update_mana_bar(current: int, max_mana: int):
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current
	if mana_label:
		mana_label.text = "%d / %d" % [current, max_mana]



func _update_die_preview():
	"""Recreate the die visual in the center cell."""
	if not mana_pool:
		return

	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.queue_free()
		_current_preview = null

	var preview_die = _create_preview_die_resource()
	if not preview_die:
		return

	var cell_size = die_preview_container.custom_minimum_size.x if die_preview_container else 48.0
	var target_size = cell_size - 8

	var visual: Control = null
	if preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	if not visual and preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()

	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
		_current_preview = visual
	else:
		var lbl = Label.new()
		lbl.text = "%s\nD%d" % [mana_pool.get_element_name(), mana_pool.selected_die_size]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", ThemeManager.get_die_element_color(mana_pool.selected_element))
		_current_preview = lbl

	preview_anchor.add_child(_current_preview)
	# Prevent inflation — Control won't propagate this upward anyway,
	# but zero it so the child doesn't occupy excess space internally.
	_current_preview.custom_minimum_size = Vector2.ZERO

	# Center manually: use base_size for die objects, target_size for labels
	if _current_preview is DieObjectBase and "base_size" in _current_preview and _current_preview.base_size.x > 0:
		var s = target_size / _current_preview.base_size.x
		_current_preview.scale = Vector2(s, s)
		_current_preview.pivot_offset = _current_preview.base_size / 2.0
		_current_preview.position = Vector2(cell_size, cell_size) / 2.0 - _current_preview.pivot_offset
	else:
		_current_preview.size = Vector2(target_size, target_size)
		_current_preview.position = Vector2(4, 4)

	_set_mouse_ignore_recursive(_current_preview)


func _update_button_visibility():
	if not mana_pool:
		return
	var elements = mana_pool.get_available_elements()
	var sizes = mana_pool.get_available_die_sizes()
	var show_elem = elements.size() > 1
	var show_size = sizes.size() > 1
	if elem_left_btn:
		elem_left_btn.modulate.a = 1.0 if show_elem else 0.0
		elem_left_btn.disabled = not show_elem
	if elem_right_btn:
		elem_right_btn.modulate.a = 1.0 if show_elem else 0.0
		elem_right_btn.disabled = not show_elem
	if size_up_btn:
		size_up_btn.modulate.a = 1.0 if show_size else 0.0
		size_up_btn.disabled = not show_size
	if size_down_btn:
		size_down_btn.modulate.a = 1.0 if show_size else 0.0
		size_down_btn.disabled = not show_size


func _update_cost_label():
	if not cost_label or not mana_pool:
		return
	var cost = mana_pool.get_pull_cost()
	cost_label.text = "Cost: %d" % cost
	if mana_pool.can_pull():
		cost_label.add_theme_color_override("font_color", cost_affordable_color)
	else:
		cost_label.add_theme_color_override("font_color", cost_unaffordable_color)

func _update_preview_appearance():
	if not die_preview_container:
		return
	var can_interact = is_drag_enabled and mana_pool and mana_pool.can_pull()
	die_preview_container.modulate = Color.WHITE if can_interact else Color(0.6, 0.6, 0.6, 0.8)

# ============================================================================
# HELPERS
# ============================================================================

func _create_preview_die_resource() -> DieResource:
	"""Create a temporary DieResource for preview with base textures + element affix."""
	if not mana_pool:
		return null

	var die = DieResource.new()
	die.die_type = mana_pool.selected_die_size as DieResource.DieType
	die.element = mana_pool.selected_element
	die.display_name = "%s D%d" % [mana_pool.get_element_name(), mana_pool.selected_die_size]
	die.source = "mana_preview"
	die.is_mana_die = true
	die.tags.append("mana_die")

	if DieBaseTextures.instance:
		DieBaseTextures.instance.apply_to(die)

	if die.element != DieResource.Element.NONE:
		var tag = ELEMENT_TAGS.get(die.element, "")
		if tag != "":
			var affix_path = "res://resources/affixes/elements/%s_element.tres" % tag
			if ResourceLoader.exists(affix_path):
				die.element_affix = load(affix_path) as DiceAffix

	return die


func _on_options_changed():
	_update_button_visibility()
	_update_die_preview()
	_update_cost_label()


func cleanup():
	"""Clean up all visuals for combat end. Called by CombatManager.reset_combat()."""
	# Kill any active drag
	if _is_dragging:
		_is_dragging = false
		set_process(false)
	
	# Free floating drag visual (lives in DragOverlayLayer)
	if _drag_visual and is_instance_valid(_drag_visual):
		_drag_visual.queue_free()
		_drag_visual = null
	
	# Free the preview die in the selector
	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.queue_free()
		_current_preview = null
	
	# Disconnect mana pool signals
	if mana_pool:
		if mana_pool.has_signal("mana_changed") and mana_pool.mana_changed.is_connected(_on_mana_changed):
			mana_pool.mana_changed.disconnect(_on_mana_changed)
		if mana_pool.has_signal("element_changed") and mana_pool.element_changed.is_connected(_on_element_changed):
			mana_pool.element_changed.disconnect(_on_element_changed)
		if mana_pool.has_signal("die_size_changed") and mana_pool.die_size_changed.is_connected(_on_size_changed):
			mana_pool.die_size_changed.disconnect(_on_size_changed)
		mana_pool = null
	
	hide()


func _set_mouse_ignore_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
