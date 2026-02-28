# res://scripts/ui/menus/skill_tree_canvas.gd
# Free-positioned canvas that places SkillButtons by tier/column
# and draws prerequisite connection lines between them.
extends Control
class_name SkillTreeCanvas

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_clicked(skill: SkillResource)

# ============================================================================
# CONFIGURATION
# ============================================================================
@export_group("Grid Layout")
## Size of each skill button AND grid cell. All buttons are forced to this size.
@export var cell_size: Vector2 = Vector2(128, 128)
## Padding between cells
@export var cell_padding: Vector2 = Vector2(16, 16)
## Margin around the entire canvas
@export var canvas_margin: Vector2 = Vector2(24, 24)

@export_group("Prerequisite Lines")
@export var line_color_locked: Color = Color(0.4, 0.4, 0.4, 0.6)
@export var line_color_met: Color = Color(0.2, 0.8, 0.3, 0.8)
@export var line_width: float = 2.0

@export_group("Grid Background")
@export var draw_grid_bg: bool = true
@export var grid_line_color: Color = Color(1.0, 1.0, 1.0, 0.05)

@export_group("Scenes")
@export var skill_button_scene: PackedScene  ## res://scenes/ui/menus/skill_button.tscn

# ============================================================================
# GRID CONSTANTS
# ============================================================================
const GRID_ROWS: int = 10
const GRID_COLUMNS: int = 7

# ============================================================================
# STATE
# ============================================================================
## skill_id -> SkillButton node (active buttons for current tree)
var skill_buttons: Dictionary = {}
## skill_id -> SkillResource (for line drawing)
var skill_map: Dictionary = {}
## Callable that returns rank for a given skill_id
var skill_rank_getter: Callable
## Total tree points spent (for line coloring)
var tree_points_spent: int = 0
## Computed center offset — never touches canvas_margin
var _center_offset_x: float = 0.0
## Pool of inactive SkillButton nodes ready for reuse
var _button_pool: Array[SkillButton] = []


## Line2D nodes for prerequisite connections. Key = "fromId->toId"
var _prereq_lines: Dictionary = {}
## Tracks whether each connection was met last frame. Key = same as above.
var _prereq_met_state: Dictionary = {}
## Reference to current tree (for line visual config)
var _current_tree: SkillTree = null

var _player_class_ref: PlayerClass = null
## SubViewport that renders the element shader for icon rank fill
var _fill_viewport: SubViewport = null
var _fill_rect: ColorRect = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Pre-instantiate a few buttons into the pool to warm up
	if skill_button_scene:
		for i in range(5):
			var btn = skill_button_scene.instantiate() as SkillButton
			if btn:
				btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
				btn.skill_clicked.connect(_on_button_clicked)
				btn.hide()
				add_child(btn)
				_button_pool.append(btn)

# ============================================================================
# BUILD
# ============================================================================

func build(tree: SkillTree, rank_getter: Callable, points_spent: int = 0, player_class: PlayerClass = null):
	_player_class_ref = player_class
	skill_rank_getter = rank_getter
	tree_points_spent = points_spent
	_current_tree = tree
	_setup_fill_viewport()
	_recycle_all_buttons()
	_clear_prereq_lines()

	if not tree:
		queue_redraw()
		return

	if size.x <= 0:
		await get_tree().process_frame

	_compute_center_offset()

	for skill in tree.get_all_skills():
		if not skill:
			continue
		_place_skill_button(skill)

	_create_prereq_lines()

	for skill_id in skill_buttons:
		_update_button_state(skill_buttons[skill_id])

	_update_prereq_line_states(false)  # false = no animation on first build
	_update_canvas_size()
	queue_redraw()


func _setup_fill_viewport():
	"""Create a SubViewport that renders the element shader for icon fills."""
	if _fill_viewport:
		_fill_viewport.queue_free()
		_fill_viewport = null
		_fill_rect = null

	if not _current_tree or not _current_tree.prereq_line_shader:
		return

	_fill_viewport = SubViewport.new()
	_fill_viewport.size = Vector2i(64, 64)
	_fill_viewport.transparent_bg = true
	_fill_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_fill_rect = ColorRect.new()
	_fill_rect.color = Color.BLACK
	_fill_rect.size = Vector2(64, 64)
	_fill_rect.material = _current_tree.prereq_line_shader.duplicate()

	_fill_viewport.add_child(_fill_rect)
	add_child(_fill_viewport)

func _recycle_all_buttons():
	"""Return all active buttons to the pool instead of freeing them."""
	for skill_id in skill_buttons:
		var btn: SkillButton = skill_buttons[skill_id]
		btn.skill = null
		btn.hide()
		_button_pool.append(btn)
	skill_buttons.clear()
	skill_map.clear()

func _get_pooled_button() -> SkillButton:
	"""Get a button from the pool, or create a new one if empty."""
	if _button_pool.size() > 0:
		return _button_pool.pop_back()

	# Pool empty — create a new button
	if not skill_button_scene:
		return null
	var btn = skill_button_scene.instantiate() as SkillButton
	if btn:
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.skill_clicked.connect(_on_button_clicked)
		add_child(btn)
	return btn

func _place_skill_button(skill: SkillResource):
	"""Grab a pooled button, assign the skill, and position it."""
	var button = _get_pooled_button()
	if not button:
		push_warning("SkillTreeCanvas: Could not get a button for %s" % skill.skill_id)
		return

	button.skill = skill
	button.position = _get_cell_position(skill.tier, skill.column)
	# Force consistent size — both the layout size and the minimum so the
	# PanelContainer doesn't shrink or stretch based on label content.
	button.custom_minimum_size = cell_size
	button.size = cell_size
	button.show()

	skill_buttons[skill.skill_id] = button
	skill_map[skill.skill_id] = skill

func _on_button_clicked(skill: SkillResource):
	skill_clicked.emit(skill)

# ============================================================================
# POSITIONING
# ============================================================================

func _get_cell_position(tier: int, column: int) -> Vector2:
	var row = tier - 1
	var x = _center_offset_x + column * (cell_size.x + cell_padding.x)
	var y = canvas_margin.y + row * (cell_size.y + cell_padding.y)
	return Vector2(x, y)

func _get_cell_center(tier: int, column: int) -> Vector2:
	"""Get the center point of a cell (for line drawing)."""
	return _get_cell_position(tier, column) + cell_size * 0.5



func _compute_center_offset():
	"""Calculate the horizontal offset so column 3's center aligns with screen center."""
	var mid_col = GRID_COLUMNS / 2.0
	var target_center = size.x / 2.0
	var mid_button_local = mid_col * (cell_size.x + cell_padding.x) + cell_size.x / 2.0
	_center_offset_x = max(canvas_margin.x, target_center - mid_button_local)

func _update_canvas_size():
	"""Set custom_minimum_size so ScrollContainer knows our full extent.
	Uses fixed canvas_margin, NOT the centering offset."""
	var grid_w = GRID_COLUMNS * cell_size.x + (GRID_COLUMNS - 1) * cell_padding.x
	var grid_h = GRID_ROWS * cell_size.y + (GRID_ROWS - 1) * cell_padding.y
	custom_minimum_size = Vector2(
		grid_w + canvas_margin.x * 2,
		grid_h + canvas_margin.y * 2
	)


# ============================================================================
# UPDATE STATES
# ============================================================================

func update_all_states(rank_getter: Callable = Callable(), points_spent: int = -1):
	if rank_getter.is_valid():
		skill_rank_getter = rank_getter
	if points_spent >= 0:
		tree_points_spent = points_spent

	for skill_id in skill_buttons:
		_update_button_state(skill_buttons[skill_id])

	_update_prereq_line_states(true)  # true = animate newly met lines
	queue_redraw()

func _update_button_state(button: SkillButton):
	if not button or not button.skill:
		return

	var skill = button.skill
	var current_rank = skill_rank_getter.call(skill.skill_id) if skill_rank_getter.is_valid() else 0
	button.set_rank(current_rank)
	
	# Effective rank from gear bonuses
	if _player_class_ref:
		var tree_id = _current_tree.tree_id if _current_tree else ""
		var class_id = _player_class_ref.player_class_name
		button.effective_rank = _player_class_ref.get_effective_skill_rank(
			skill.skill_id, tree_id, class_id, skill.get_max_rank()
		)
		button._update_rank_display()

	var can_learn = skill.can_learn(skill_rank_getter, tree_points_spent)
	if current_rank >= skill.get_max_rank():
		button.set_state(SkillButton.State.MAXED)
	elif can_learn:
		button.set_state(SkillButton.State.AVAILABLE)
	else:
		button.set_state(SkillButton.State.LOCKED)
	
	
	# Apply icon engraving shader
	if _current_tree and _current_tree.icon_shader:
		button.set_icon_shader(_current_tree.icon_shader)

	# Pass the element viewport texture for rank fill
	if _fill_viewport:
		button.set_fill_texture(_fill_viewport.get_texture())

# ============================================================================
# DRAWING - prerequisite lines + optional grid background
# ============================================================================

func _draw():
	if draw_grid_bg:
		_draw_grid_background()
	_draw_prerequisite_lines()

func _draw_grid_background():
	"""Draw subtle grid lines for visual structure."""
	for row in range(GRID_ROWS + 1):
		var y = canvas_margin.y + row * (cell_size.y + cell_padding.y) - cell_padding.y * 0.5
		var x_start = _center_offset_x - cell_padding.x * 0.5
		var x_end = _center_offset_x + GRID_COLUMNS * (cell_size.x + cell_padding.x) - cell_padding.x * 0.5
		draw_line(Vector2(x_start, y), Vector2(x_end, y), grid_line_color, 1.0)

	for col in range(GRID_COLUMNS + 1):
		var x = _center_offset_x + col * (cell_size.x + cell_padding.x) - cell_padding.x * 0.5
		var y_start = canvas_margin.y - cell_padding.y * 0.5
		var y_end = canvas_margin.y + GRID_ROWS * (cell_size.y + cell_padding.y) - cell_padding.y * 0.5
		draw_line(Vector2(x, y_start), Vector2(x, y_end), grid_line_color, 1.0)

func _draw_prerequisite_lines():
	# Lines are now managed as Line2D child nodes — nothing to draw here.
	pass
	


# ============================================================================
# PREREQUISITE LINE MANAGEMENT (Line2D nodes)
# ============================================================================

func _clear_prereq_lines():
	"""Remove all Line2D nodes and reset tracking."""
	for key in _prereq_lines:
		var line: Line2D = _prereq_lines[key]
		if is_instance_valid(line):
			line.queue_free()
	_prereq_lines.clear()
	_prereq_met_state.clear()

func _create_prereq_lines():
	"""Create a Line2D node for each prerequisite connection."""
	for skill_id in skill_map:
		var skill: SkillResource = skill_map[skill_id]
		if skill.prerequisites.is_empty():
			continue

		var to_center = _get_cell_center(skill.tier, skill.column)

		for prereq in skill.prerequisites:
			if not prereq or not prereq.required_skill:
				continue
			var prereq_skill: SkillResource = prereq.required_skill
			if not prereq_skill.skill_id in skill_map:
				continue

			var from_center = _get_cell_center(prereq_skill.tier, prereq_skill.column)
			var key = "%s->%s" % [prereq_skill.skill_id, skill_id]

			var line := Line2D.new()
			line.points = PackedVector2Array([from_center, from_center])  # starts collapsed
			line.width = _get_line_width()
			line.default_color = _get_locked_color()
			line.antialiased = true
			line.set_meta("from_pos", from_center)
			line.set_meta("to_pos", to_center)
			line.set_meta("prereq_ref", prereq)
			add_child(line)
			move_child(line, 0)  # keep behind buttons

			_prereq_lines[key] = line
			_prereq_met_state[key] = false
			print("📏 Created %d prereq lines" % _prereq_lines.size())

func _update_prereq_line_states(animate: bool):
	"""Check each connection's met status. Animate fill on newly met lines."""
	for key in _prereq_lines:
		var line: Line2D = _prereq_lines[key]
		if not is_instance_valid(line):
			continue

		var prereq: SkillPrerequisite = line.get_meta("prereq_ref")
		var from_pos: Vector2 = line.get_meta("from_pos")
		var to_pos: Vector2 = line.get_meta("to_pos")

		var prereq_rank = skill_rank_getter.call(prereq.required_skill.skill_id) if skill_rank_getter.is_valid() else 0
		var is_met = prereq_rank >= prereq.required_rank
		var was_met = _prereq_met_state[key]

		if is_met and not was_met:
			# Newly met — animate fill
			_prereq_met_state[key] = true
			if animate:
				_animate_line_fill(line, from_pos, to_pos)
			else:
				_set_line_filled(line, from_pos, to_pos)
		elif is_met and was_met:
			# Already met — ensure filled (covers rebuild)
			_set_line_filled(line, from_pos, to_pos)
		else:
			# Locked — show full line in locked color
			_prereq_met_state[key] = false
			_set_line_locked(line, from_pos, to_pos)
	
	print("📏 Line states updated — met: %d, locked: %d" % [
	_prereq_met_state.values().count(true),
	_prereq_met_state.values().count(false)
])
	
	
	
	
	

func _set_line_locked(line: Line2D, from_pos: Vector2, to_pos: Vector2):
	"""Show full-length line in locked style."""
	line.points = PackedVector2Array([from_pos, to_pos])
	line.default_color = _get_locked_color()
	line.width = _get_line_width()
	line.material = null

func _set_line_filled(line: Line2D, from_pos: Vector2, to_pos: Vector2):
	"""Show full-length line in met style with shader."""
	line.points = PackedVector2Array([from_pos, to_pos])
	line.default_color = _get_met_color()
	line.width = _get_line_width()
	_apply_line_shader(line, 1.0)

func _animate_line_fill(line: Line2D, from_pos: Vector2, to_pos: Vector2):
	"""Tween the line from source to destination with shader."""
	line.default_color = _get_met_color()
	line.width = _get_line_width()
	_apply_line_shader(line, 0.0)

	var duration = _get_fill_duration()
	var tw = create_tween()
	tw.tween_method(
		func(progress: float):
			if is_instance_valid(line):
				var current_end = from_pos.lerp(to_pos, progress)
				line.points = PackedVector2Array([from_pos, current_end])
				_update_line_shader_progress(line, progress),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _apply_line_shader(line: Line2D, progress: float):
	"""Apply the tree's shader material to the line (as a unique copy)."""
	if _current_tree and _current_tree.prereq_line_shader:
		var mat = _current_tree.prereq_line_shader.duplicate() as ShaderMaterial
		mat.set_shader_parameter("fill_progress", progress)
		line.material = mat
	else:
		line.material = null

func _update_line_shader_progress(line: Line2D, progress: float):
	"""Update the fill_progress uniform on the line's shader."""
	if line.material and line.material is ShaderMaterial:
		(line.material as ShaderMaterial).set_shader_parameter("fill_progress", progress)

# ── Tree-aware getters (fall back to canvas defaults) ──

func _get_locked_color() -> Color:
	if _current_tree:
		return _current_tree.prereq_line_color_locked
	return line_color_locked

func _get_met_color() -> Color:
	if _current_tree:
		return _current_tree.prereq_line_color_met
	return line_color_met

func _get_line_width() -> float:
	if _current_tree:
		return _current_tree.prereq_line_width
	return line_width

func _get_fill_duration() -> float:
	if _current_tree:
		return _current_tree.prereq_line_fill_duration
	return 0.4







# ============================================================================
# UTILITY
# ============================================================================

func get_button_for_skill(skill_id: String) -> SkillButton:
	"""Get the SkillButton node for a given skill_id."""
	return skill_buttons.get(skill_id, null)

func get_all_buttons() -> Dictionary:
	"""Get the full skill_id -> SkillButton dictionary."""
	return skill_buttons
