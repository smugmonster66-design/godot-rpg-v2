# skill_button.gd - Button that displays and levels up a SkillResource
extends PanelContainer
class_name SkillButton

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_clicked(skill: SkillResource)
signal skill_rank_changed(skill: SkillResource, new_rank: int)

# ============================================================================
# EXPORTS
# ============================================================================
@export var skill: SkillResource = null:
	set(value):
		skill = value
		_update_display()

# ============================================================================
# STATE
# ============================================================================
enum State { LOCKED, AVAILABLE, MAXED }
var current_state: State = State.LOCKED
var current_rank: int = 0

# ============================================================================
# NODE REFERENCES (found via groups or names)
# ============================================================================
var icon_rect: TextureRect
var name_label: Label
var rank_label: Label
var lock_overlay: Control
var highlight_panel: Panel

# ============================================================================
# STYLING
# ============================================================================
const COLOR_LOCKED = Color(0.3, 0.3, 0.3, 1.0)
const COLOR_AVAILABLE = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_MAXED = Color(1.0, 0.85, 0.0, 1.0)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 0.2)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_find_nodes()
	_setup_input()
	_update_display()

func _find_nodes():
	"""Find child nodes by name"""
	icon_rect = find_child("Icon") as TextureRect
	name_label = find_child("NameLabel") as Label
	rank_label = find_child("RankLabel") as Label
	lock_overlay = find_child("LockOverlay") as Control
	highlight_panel = find_child("HighlightPanel") as Panel

func _setup_input():
	"""Setup mouse interaction"""
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

# ============================================================================
# DISPLAY
# ============================================================================

func _update_display():
	if not is_node_ready():
		return
	
	if not skill:
		_show_empty()
		return
	
	# Update icon
	if icon_rect:
		icon_rect.texture = skill.icon
	
	# Update name
	if name_label:
		name_label.text = skill.skill_name
	
	# Update rank display
	_update_rank_display()
	
	# Update visual state
	_update_visual_state()

func _show_empty():
	"""Show empty/unused slot"""
	if icon_rect:
		icon_rect.texture = null
	if name_label:
		name_label.text = ""
	if rank_label:
		rank_label.text = ""
	if lock_overlay:
		lock_overlay.hide()
	
	modulate = Color(0.5, 0.5, 0.5, 0.3)

func _update_rank_display():
	if not rank_label or not skill:
		return
	
	var max_rank = skill.get_max_rank()
	if max_rank > 1:
		rank_label.text = "%d/%d" % [current_rank, max_rank]
	else:
		rank_label.text = "1" if current_rank > 0 else "0"

func _update_visual_state():
	if not skill:
		return
	
	match current_state:
		State.LOCKED:
			modulate = COLOR_LOCKED
			if lock_overlay:
				lock_overlay.show()
		State.AVAILABLE:
			modulate = COLOR_AVAILABLE
			if lock_overlay:
				lock_overlay.hide()
		State.MAXED:
			modulate = COLOR_MAXED
			if lock_overlay:
				lock_overlay.hide()

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func set_state(new_state: State):
	"""Set the button's visual/interaction state"""
	current_state = new_state
	_update_visual_state()

func set_rank(rank: int):
	"""Set current rank (called by parent to sync with player data)"""
	current_rank = rank
	
	if skill:
		var max_rank = skill.get_max_rank()
		if current_rank >= max_rank:
			current_state = State.MAXED
		else:
			current_state = State.AVAILABLE
	
	_update_rank_display()
	_update_visual_state()

func is_maxed() -> bool:
	if not skill:
		return true
	return current_rank >= skill.get_max_rank()

func can_level_up() -> bool:
	return current_state == State.AVAILABLE and not is_maxed()

# ============================================================================
# INPUT
# ============================================================================

func _on_gui_input(event: InputEvent):
	if not skill:
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			skill_clicked.emit(skill)
			accept_event()

func _on_mouse_entered():
	if highlight_panel:
		highlight_panel.show()

func _on_mouse_exited():
	if highlight_panel:
		highlight_panel.hide()

# ============================================================================
# TOOLTIP
# ============================================================================
