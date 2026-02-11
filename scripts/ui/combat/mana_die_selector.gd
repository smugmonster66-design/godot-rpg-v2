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

@onready var mana_bar: ProgressBar = $ManaBar
@onready var mana_label: Label = $ManaLabel
@onready var cost_label: Label = $CostLabel
@onready var selector_grid: GridContainer = $SelectorGrid
@onready var die_preview_container: PanelContainer = $SelectorGrid/DiePreviewContainer
@onready var elem_left_btn: Button = $SelectorGrid/ElemLeftBtn
@onready var elem_right_btn: Button = $SelectorGrid/ElemRightBtn
@onready var size_up_btn: Button = $SelectorGrid/SizeUpBtn
@onready var size_down_btn: Button = $SelectorGrid/SizeDownBtn

# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("Colors")
@export var cost_affordable_color: Color = Color(0.8, 0.9, 1.0)
@export var cost_unaffordable_color: Color = Color(1.0, 0.3, 0.3)

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

const ELEMENT_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6),
	1: Color(1.0, 0.4, 0.2),
	2: Color(0.3, 0.7, 1.0),
	3: Color(0.9, 0.9, 0.2),
	4: Color(0.3, 0.9, 0.3),
	5: Color(0.5, 0.2, 0.8),
	6: Color(0.8, 0.8, 0.8),
	7: Color(0.7, 0.5, 0.3),
	8: Color(0.9, 0.9, 0.9),
}

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

	# Make child containers pass-through
	if die_preview_container:
		die_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selector_grid:
		selector_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Remove legacy ManaDragSource if present
	var legacy = find_child("ManaDragSource", true, false)
	if legacy:
		legacy.queue_free()

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
		var preview_size = _drag_visual.size * _drag_visual.scale
		if preview_size.length() < 1:
			preview_size = Vector2(62, 62)
		_drag_visual.global_position = get_global_mouse_position() - preview_size / 2
		get_viewport().set_input_as_handled()

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
	"""Mana die dropped on hand — spend mana, add die, grow new preview."""
	print("🎲 ManaDieSelector: Drop on hand — spending mana")

	var die = mana_pool.pull_mana_die()
	if not die:
		_cancel_drag()
		return

	# Add to player's hand
	if player and player.dice_pool:
		player.dice_pool.add_die_to_hand(die)
		print("🔮 Mana die added to hand: %s (D%d, value=%d)" % [
			die.display_name, die.die_type, die.get_total_value()])

	# Remove drag visual
	if _drag_visual and is_instance_valid(_drag_visual):
		_drag_visual.queue_free()
		_drag_visual = null

	# Update all displays first (mana bar, cost, etc.)
	_update_mana_bar(mana_pool.current_mana, mana_pool.max_mana)
	_update_cost_label()
	_update_preview_appearance()
	_update_button_visibility()

	# Grow a fresh preview from center of the selector
	_animate_preview_grow_back()

	drag_ended.emit(true)



func _cancel_drag():
	"""Drag cancelled — animate die back to selector center at full size, then shrink to fit."""
	print("🎲 ManaDieSelector: Drag cancelled — snapping back")

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

		# Phase 1: fly back at full size
		var tween = create_tween()
		tween.tween_property(_drag_visual, "global_position", snap_target, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Phase 2: shrink into the selector
		# Set pivot to center so it shrinks toward center
		tween.tween_callback(func():
			if _drag_visual and is_instance_valid(_drag_visual):
				_drag_visual.pivot_offset = half
		)
		tween.tween_property(_drag_visual, "scale", preview_scale, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

		# Phase 3: swap to real preview
		tween.tween_callback(func():
			if _drag_visual and is_instance_valid(_drag_visual):
				_drag_visual.queue_free()
				_drag_visual = null
			if _current_preview and is_instance_valid(_current_preview):
				_current_preview.visible = true
		)
	else:
		if _current_preview and is_instance_valid(_current_preview):
			_current_preview.visible = true

	drag_ended.emit(false)



func _animate_preview_grow_back():
	"""After a successful drop, rebuild die preview and animate it growing from zero."""
	# Kill old preview
	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.queue_free()
		_current_preview = null

	var preview_die = _create_preview_die_resource()
	if not preview_die:
		return

	# Calculate target scale for the preview cell
	var cell_size = die_preview_container.custom_minimum_size.x if die_preview_container else 48.0
	var target_size = cell_size - 8
	var final_scale = Vector2.ONE

	var visual: Control = null
	if preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	if not visual and preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()

	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
		visual.custom_minimum_size = Vector2.ZERO
		if "base_size" in visual and visual.base_size.x > 0:
			var s = target_size / visual.base_size.x
			final_scale = Vector2(s, s)
		visual.scale = Vector2.ZERO  # Start invisible
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
		var elem_color = ELEMENT_COLORS.get(int(mana_pool.selected_element), Color.WHITE)
		lbl.add_theme_color_override("font_color", elem_color)
		lbl.scale = Vector2.ZERO
		_current_preview = lbl

	die_preview_container.add_child(_current_preview)
	_set_mouse_ignore_recursive(_current_preview)

	# Wait one frame for layout
	await get_tree().process_frame
	if not is_instance_valid(_current_preview) or not is_instance_valid(die_preview_container):
		return

	# Set pivot to center for scale-from-center
	if "base_size" in _current_preview:
		_current_preview.pivot_offset = _current_preview.base_size / 2.0
	else:
		_current_preview.pivot_offset = _current_preview.size / 2.0

	# Center in container based on final scaled size
	var container_size = die_preview_container.size
	var final_visual_size = _current_preview.size * final_scale
	_current_preview.position = (container_size - final_visual_size) / 2.0

	# Grow from zero
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

	var visual: Control = null
	if preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	if not visual and preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()

	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
		visual.custom_minimum_size = Vector2.ZERO
		var cell_size = die_preview_container.custom_minimum_size.x if die_preview_container else 48.0
		var target_size = cell_size - 8
		if "base_size" in visual and visual.base_size.x > 0:
			var scale_factor = target_size / visual.base_size.x
			visual.scale = Vector2(scale_factor, scale_factor)
		_current_preview = visual
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
	else:
		var lbl = Label.new()
		lbl.text = "%s\nD%d" % [mana_pool.get_element_name(), mana_pool.selected_die_size]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		var elem_color = ELEMENT_COLORS.get(int(mana_pool.selected_element), Color.WHITE)
		lbl.add_theme_color_override("font_color", elem_color)
		_current_preview = lbl

	die_preview_container.add_child(_current_preview)

	await get_tree().process_frame
	if is_instance_valid(_current_preview) and is_instance_valid(die_preview_container):
		var container_size = die_preview_container.size
		var visual_size = _current_preview.size * _current_preview.scale
		_current_preview.position = (container_size - visual_size) / 2.0

	if _current_preview:
		_set_mouse_ignore_recursive(_current_preview)

func _update_button_visibility():
	if not mana_pool:
		return
	var elements = mana_pool.get_available_elements()
	var sizes = mana_pool.get_available_die_sizes()
	if elem_left_btn:
		elem_left_btn.visible = elements.size() > 1
	if elem_right_btn:
		elem_right_btn.visible = elements.size() > 1
	if size_up_btn:
		size_up_btn.visible = sizes.size() > 1
	if size_down_btn:
		size_down_btn.visible = sizes.size() > 1

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

func _set_mouse_ignore_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
