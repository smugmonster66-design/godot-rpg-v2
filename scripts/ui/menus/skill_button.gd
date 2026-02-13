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

@export var default_icon: Texture2D

# ============================================================================
# STATE
# ============================================================================
enum State { LOCKED, AVAILABLE, MAXED }
var current_state: State = State.LOCKED
var current_rank: int = 0
var effective_rank: int = 0

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
@export_group("State Colors")
@export var color_locked: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var color_available: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var color_maxed: Color = Color(1.0, 0.85, 0.0, 1.0)


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_find_nodes()
	_setup_input()
	_update_display()

func _find_nodes():
	icon_rect = $VBoxContainer/ButtonTexture/MarginContainer/IconRect
	name_label = $VBoxContainer/HBoxContainer/NameLabel
	rank_label = $VBoxContainer/HBoxContainer/RankLabel
	lock_overlay = $LockOverlay
	highlight_panel = $HighlightPanel

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
		icon_rect.texture = skill.icon if skill.icon else default_icon
	
	
	
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
	if lock_overlay:
		lock_overlay.hide()
	
	modulate = Color(0.5, 0.5, 0.5, 0.3)


func _update_rank_display():
	if not rank_label or not skill:
		return
	
	var max_rank = skill.get_max_rank()
	var has_bonus = effective_rank > current_rank and current_rank > 0
	var display_rank = effective_rank if has_bonus else current_rank
	
	if max_rank > 1:
		if has_bonus:
			rank_label.text = "%d+%d/%d" % [current_rank, effective_rank - current_rank, max_rank]
		else:
			rank_label.text = "%d/%d" % [current_rank, max_rank]
	else:
		if has_bonus:
			rank_label.text = "%d" % effective_rank
		else:
			rank_label.text = "%d" % current_rank
	
	# Blue tint when gear-boosted
	if has_bonus:
		rank_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	else:
		rank_label.remove_theme_color_override("font_color")


func _update_visual_state():
	if not skill:
		return
	
	var button_texture = $ButtonTexture if has_node("ButtonTexture") else null
	var target = button_texture if button_texture else self
	match current_state:
		State.LOCKED:
			target.modulate = color_locked
		State.AVAILABLE:
			target.modulate = color_available
		State.MAXED:
			target.modulate = color_maxed

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
