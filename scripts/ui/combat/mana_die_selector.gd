# res://scripts/ui/combat/mana_die_selector.gd
# Mana die selector widget for the bottom UI panel.
# Scene-based — all layout is in mana_die_selector.tscn.
#
# Contains a mana progress bar with a 3×3 die-type selector grid overlapping
# its right end. The center cell shows a preview of the currently selected
# mana die (element + size). Players drag from anywhere on this widget into
# their hand during the ACTION phase to pull a mana die.
#
# Arrow buttons only appear when >1 option is unlocked.
# Drag only works when is_drag_enabled == true (ACTION phase).
#
# Drag is handled directly on this Control — no separate ManaDragSource needed.
# Since ManaDieSelector is the root parent, no child can block its _get_drag_data.
#
# INTEGRATION:
#   # Instance the scene, add to tree, then:
#   selector.initialize(player)
#   selector.set_drag_enabled(true)   # ACTION phase
#   selector.set_drag_enabled(false)  # PREP / enemy turn
extends Control
class_name ManaDieSelector

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a mana die is successfully pulled and needs to be inserted
## into the hand. The consumer (DicePoolDisplay) handles visual creation.
signal mana_die_created(die: DieResource, insert_index: int)

## Emitted when drag starts (for UI feedback).
signal drag_started()

## Emitted when drag ends (placed or cancelled).
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
# CONFIGURATION — tweak in Inspector
# ============================================================================

@export_group("Colors")
## Cost label color when affordable.
@export var cost_affordable_color: Color = Color(0.8, 0.9, 1.0)
## Cost label color when too expensive.
@export var cost_unaffordable_color: Color = Color(1.0, 0.3, 0.3)

# ============================================================================
# STATE
# ============================================================================

## Current die preview visual (child of preview_anchor).
var _current_preview: Control = null

var player: Player = null
var mana_pool: ManaPool = null

## Whether dragging from the preview is currently allowed (ACTION phase only).
var is_drag_enabled: bool = false

## Whether the widget is visible and functional (player is a caster).
var is_caster: bool = false

# ============================================================================
# DRAG STATE
# ============================================================================

var _manual_preview: Control = null
var _is_dragging: bool = false

# ============================================================================
# ELEMENT COLORS (for fallback text-label tinting)
# ============================================================================

const ELEMENT_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6),     # NONE / Neutral
	1: Color(1.0, 0.4, 0.2),     # FIRE
	2: Color(0.3, 0.7, 1.0),     # ICE
	3: Color(0.9, 0.9, 0.2),     # SHOCK
	4: Color(0.3, 0.9, 0.3),     # POISON
	5: Color(0.5, 0.2, 0.8),     # SHADOW
	6: Color(0.8, 0.8, 0.8),     # SLASHING
	7: Color(0.7, 0.5, 0.3),     # BLUNT
	8: Color(0.9, 0.9, 0.9),     # PIERCING
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Start hidden — shown after initialize() if player is a caster
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

	# Make container nodes pass-through so _get_drag_data on THIS node fires
	if die_preview_container:
		die_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selector_grid:
		selector_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Remove the legacy ManaDragSource node if present in the scene tree
	var legacy_drag = find_child("ManaDragSource", true, false)
	if legacy_drag:
		legacy_drag.queue_free()

func initialize(p_player: Player):
	"""Initialize with the player. Shows widget if player has a mana pool."""
	player = p_player

	if player and player.has_mana_pool():
		mana_pool = player.mana_pool
		is_caster = true
		_connect_mana_signals()
		_update_all()
		visible = true
		print("🔮 ManaDieSelector: Initialized (caster)")
	else:
		is_caster = false
		visible = false
		print("🔮 ManaDieSelector: Hidden (not a caster)")

func set_drag_enabled(enabled: bool):
	"""Enable or disable drag. Call from CombatManager on phase change."""
	is_drag_enabled = enabled
	_update_preview_appearance()







func _input(event: InputEvent):
	if not is_drag_enabled or not visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	if not die_preview_container or not die_preview_container.get_global_rect().has_point(get_global_mouse_position()):
		return
	
	# Check we can actually pull
	if not mana_pool or not mana_pool.can_pull():
		if mana_pool:
			mana_pool.pull_failed.emit("Cannot pull — insufficient mana or no options")
		return
	
	drag_started.emit()
	_is_dragging = true
	
	# Create manual preview
	_manual_preview = _create_mana_drag_preview()
	if _manual_preview:
		_set_mouse_ignore_recursive(_manual_preview)
		_manual_preview.z_index = 100
		var overlay = get_tree().current_scene.find_child("DragOverlayLayer", true, false)
		if overlay:
			overlay.add_child(_manual_preview)
		else:
			get_tree().root.add_child(_manual_preview)
		_update_preview_position()
	set_process(true)
	
	# Start Godot's drag system programmatically — bypasses GUI routing entirely
	var data = {
		"type": "mana_die",
		"element": mana_pool.selected_element,
		"die_size": mana_pool.selected_die_size,
		"pull_cost": mana_pool.get_pull_cost(),
		"mana_pool": mana_pool,
		"selector": self,
	}
	# Invisible dummy preview — our manual preview handles visuals
	var dummy = Control.new()
	dummy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dummy.modulate = Color(1, 1, 1, 0)
	dummy.custom_minimum_size = Vector2(1, 1)
	force_drag(data, dummy)
	get_viewport().set_input_as_handled()



func _find_topmost_stop_control(node: Node, global_pos: Vector2) -> Control:
	"""Find the topmost Control with MOUSE_FILTER_STOP that contains the point."""
	var result: Control = null
	for child in node.get_children():
		var found = _find_topmost_stop_control(child, global_pos)
		if found:
			result = found
	if node is Control:
		var c: Control = node as Control
		if c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			var rect = Rect2(c.global_position, c.size)
			if rect.has_point(global_pos):
				result = c
	return result






# ============================================================================
# SIGNAL CONNECTIONS
# ============================================================================

func _connect_mana_signals():
	"""Connect to ManaPool signals for live updates."""
	if not mana_pool:
		return

	if not mana_pool.mana_changed.is_connected(_on_mana_changed):
		mana_pool.mana_changed.connect(_on_mana_changed)
	if not mana_pool.element_changed.is_connected(_on_element_changed):
		mana_pool.element_changed.connect(_on_element_changed)
	if not mana_pool.die_size_changed.is_connected(_on_die_size_changed):
		mana_pool.die_size_changed.connect(_on_die_size_changed)
	if not mana_pool.pull_failed.is_connected(_on_pull_failed):
		mana_pool.pull_failed.connect(_on_pull_failed)

# ============================================================================
# BUTTON HANDLERS — connected via .tscn signal connections
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

func _on_die_size_changed(_die_size):
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
	"""Refresh everything — called after initialize."""
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
	print("🔮 _update_die_preview() called — stack: ", get_stack())
	"""Recreate the die visual in the center cell."""
	if not mana_pool:
		return
	# Remove old preview
	if _current_preview and is_instance_valid(_current_preview):
		_current_preview.queue_free()
		_current_preview = null
	var preview_die = _create_preview_die_resource()
	if not preview_die:
		return
	# Try to create a visual via the die's visual system
	var visual: Control = null
	if preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()
	if not visual and preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	if visual:
		if visual is DieObjectBase:
			visual.draggable = false
		# Pull out of layout entirely
		visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
		visual.custom_minimum_size = Vector2.ZERO
		# Scale to fit
		var cell_size = die_preview_container.custom_minimum_size.x
		var target_size = cell_size - 8
		if "base_size" in visual and visual.base_size.x > 0:
			var scale_factor = target_size / visual.base_size.x
			visual.scale = Vector2(scale_factor, scale_factor)
		_current_preview = visual
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
	else:
		# Fallback: text label
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
	
	# Wait one frame so the visual's _ready() has run and layout has settled
	await get_tree().process_frame
	if is_instance_valid(_current_preview) and is_instance_valid(die_preview_container):
		var container_size = die_preview_container.size
		var visual_size = _current_preview.size * _current_preview.scale
		_current_preview.position = (container_size - visual_size) / 2.0
	
	# Re-apply IGNORE after the visual's _ready() has reset mouse_filter to STOP
	if _current_preview:
		_set_mouse_ignore_recursive(_current_preview)
	
	# ManaDragSource must be last child to receive input first
	var drag_source = die_preview_container.find_child("ManaDragSource", false, false)
	if drag_source:
		die_preview_container.move_child(drag_source, -1)


func _update_button_visibility():
	"""Show/hide arrow buttons based on available options."""
	if not mana_pool:
		return

	var elements = mana_pool.get_available_elements()
	var sizes = mana_pool.get_available_die_sizes()
	var multi_elements = elements.size() > 1
	var multi_sizes = sizes.size() > 1

	if elem_left_btn:
		elem_left_btn.visible = multi_elements
	if elem_right_btn:
		elem_right_btn.visible = multi_elements
	if size_up_btn:
		size_up_btn.visible = multi_sizes
	if size_down_btn:
		size_down_btn.visible = multi_sizes

func _update_cost_label():
	"""Update the pull cost display."""
	if not cost_label or not mana_pool:
		return

	var cost = mana_pool.get_pull_cost()
	cost_label.text = "Cost: %d" % cost

	if mana_pool.can_pull():
		cost_label.add_theme_color_override("font_color", cost_affordable_color)
	else:
		cost_label.add_theme_color_override("font_color", cost_unaffordable_color)

func _update_preview_appearance():
	"""Dim the preview when dragging is disabled or can't afford a pull."""
	if not die_preview_container:
		return

	var can_interact = is_drag_enabled and mana_pool and mana_pool.can_pull()
	die_preview_container.modulate = Color.WHITE if can_interact else Color(0.6, 0.6, 0.6, 0.8)

# ============================================================================
# DIRECT DRAG HANDLING
# ============================================================================




func _process(_delta: float):
	if _manual_preview and _is_dragging:
		_update_preview_position()

func _update_preview_position():
	if _manual_preview:
		var preview_size = _manual_preview.size if _manual_preview.size.length() > 0 else Vector2(62, 62)
		_manual_preview.global_position = get_global_mouse_position() - preview_size / 2

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		if _manual_preview:
			_manual_preview.queue_free()
			_manual_preview = null
		set_process(false)
		drag_ended.emit(false)

# ============================================================================
# DRAG PREVIEW CREATION
# ============================================================================

func _create_mana_drag_preview() -> Control:
	"""Create the visual that follows the cursor during drag."""
	var preview_die = _create_preview_die_resource()
	if not preview_die:
		return null

	var visual: Control = null
	if preview_die.has_method("instantiate_combat_visual"):
		visual = preview_die.instantiate_combat_visual()
	elif preview_die.has_method("instantiate_pool_visual"):
		visual = preview_die.instantiate_pool_visual()

	if visual:
		visual.modulate = Color(1, 1, 1, 0.8)
		var lbl = visual.find_child("ValueLabel", true, false)
		if lbl:
			lbl.visible = false
		if visual is DieObjectBase:
			visual.draggable = false
		return visual

	# Fallback label
	var lbl = Label.new()
	lbl.text = "D%d" % mana_pool.selected_die_size
	lbl.add_theme_font_size_override("font_size", 18)
	return lbl

# ============================================================================
# MANA DIE PULL — Called by ManaDropZone on successful drop
# ============================================================================

func pull_and_create_die() -> DieResource:
	"""Actually pull the mana die (spend mana, create DieResource).
	Called by the drop target after confirming a valid drop.
	Returns the new DieResource, or null if pull fails."""
	if not mana_pool:
		return null
	return mana_pool.pull_mana_die()

# ============================================================================
# HELPERS
# ============================================================================

func _create_preview_die_resource() -> DieResource:
	"""Create a temporary DieResource matching the current selection for preview."""
	if not mana_pool:
		return null

	var die = DieResource.new()
	die.die_type = mana_pool.selected_die_size as DieResource.DieType
	die.element = mana_pool.selected_element
	die.display_name = "%s D%d" % [mana_pool.get_element_name(), mana_pool.selected_die_size]
	die.source = "mana_preview"
	die.tags.append("mana_die")

	if DieBaseTextures.instance:
		DieBaseTextures.instance.apply_to(die)
	if mana_pool:
		mana_pool._apply_element_visuals(die)

	return die

func _set_mouse_ignore_recursive(node: Node):
	"""Recursively set MOUSE_FILTER_IGNORE on all Control children."""
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
