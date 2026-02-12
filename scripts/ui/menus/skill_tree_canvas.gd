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

func build(tree: SkillTree, rank_getter: Callable, points_spent: int = 0):
	skill_rank_getter = rank_getter
	tree_points_spent = points_spent
	_recycle_all_buttons()

	if not tree:
		queue_redraw()
		return

	# Wait one frame for ScrollContainer to finalize our size
	if size.x <= 0:
		await get_tree().process_frame

	_compute_center_offset()

	for skill in tree.get_all_skills():
		if not skill:
			continue
		_place_skill_button(skill)

	for skill_id in skill_buttons:
		_update_button_state(skill_buttons[skill_id])

	_update_canvas_size()
	queue_redraw()



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
	"""Refresh button states and redraw lines."""
	if rank_getter.is_valid():
		skill_rank_getter = rank_getter
	if points_spent >= 0:
		tree_points_spent = points_spent

	for skill_id in skill_buttons:
		_update_button_state(skill_buttons[skill_id])

	queue_redraw()

func _update_button_state(button: SkillButton):
	"""Update a single button's rank display and locked/available/maxed state."""
	if not button or not button.skill:
		return

	var skill = button.skill
	var current_rank = skill_rank_getter.call(skill.skill_id) if skill_rank_getter.is_valid() else 0
	button.set_rank(current_rank)

	var can_learn = skill.can_learn(skill_rank_getter, tree_points_spent)
	if current_rank >= skill.get_max_rank():
		button.set_state(SkillButton.State.MAXED)
	elif can_learn:
		button.set_state(SkillButton.State.AVAILABLE)
	else:
		button.set_state(SkillButton.State.LOCKED)

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
	"""Draw lines from each skill to its prerequisites."""
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

			# Color based on whether prerequisite is met
			var prereq_rank = skill_rank_getter.call(prereq_skill.skill_id) if skill_rank_getter.is_valid() else 0
			var is_met = prereq_rank >= prereq.required_rank
			var color = line_color_met if is_met else line_color_locked

			draw_line(from_center, to_center, color, line_width, true)

# ============================================================================
# UTILITY
# ============================================================================

func get_button_for_skill(skill_id: String) -> SkillButton:
	"""Get the SkillButton node for a given skill_id."""
	return skill_buttons.get(skill_id, null)

func get_all_buttons() -> Dictionary:
	"""Get the full skill_id -> SkillButton dictionary."""
	return skill_buttons
