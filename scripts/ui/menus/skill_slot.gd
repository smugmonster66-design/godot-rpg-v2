# skill_slot.gd - Wrapper that shows either a SkillButton or empty spacer
extends Control
class_name SkillSlot

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_clicked(skill: SkillResource)

# ============================================================================
# EXPORTS
# ============================================================================
@export var skill: SkillResource = null:
	set(value):
		skill = value
		_update_display()

# ============================================================================
# CHILDREN (set in scene)
# ============================================================================
@export var skill_button: SkillButton
@export var spacer: Control

# ============================================================================
# SIZING
# ============================================================================
@export var slot_size: Vector2 = Vector2(80, 100)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	custom_minimum_size = slot_size
	
	if skill_button:
		skill_button.skill_clicked.connect(_on_skill_button_clicked)
	
	_update_display()

func _update_display():
	if not is_node_ready():
		return
	
	if skill:
		# Show button, hide spacer
		if skill_button:
			skill_button.skill = skill
			skill_button.show()
		if spacer:
			spacer.hide()
	else:
		# Hide button, show spacer
		if skill_button:
			skill_button.hide()
		if spacer:
			spacer.show()

# ============================================================================
# PASS-THROUGH METHODS
# ============================================================================

func set_rank(rank: int):
	if skill_button:
		skill_button.set_rank(rank)

func set_state(state: SkillButton.State):
	if skill_button:
		skill_button.set_state(state)

func get_skill() -> SkillResource:
	return skill

func _on_skill_button_clicked(clicked_skill: SkillResource):
	skill_clicked.emit(clicked_skill)
