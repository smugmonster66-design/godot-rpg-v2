# res://scripts/ui/menus/skill_popup.gd
# Popup that shows skill details and a Learn button for mobile
extends Control
class_name SkillPopup

# ============================================================================
# SIGNALS
# ============================================================================
signal learn_pressed(skill: SkillResource)
signal closed

# ============================================================================
# NODE REFERENCES
# ============================================================================
@export_group("Labels")
@export var skill_name_label: Label
@export var description_label: RichTextLabel
@export var rank_label: Label
@export var cost_label: Label
@export var prerequisites_label: Label

@export_group("Visuals")
@export var icon_rect: TextureRect
@export var overlay: Control  ## Dark background, click to close

@export_group("Buttons")
@export var learn_button: Button
@export var close_button: Button

# ============================================================================
# STATE
# ============================================================================
var current_skill: SkillResource = null
var current_rank: int = 0
var can_learn: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if overlay:
		overlay.gui_input.connect(_on_overlay_input)

	if learn_button:
		learn_button.pressed.connect(_on_learn_pressed)

	if close_button:
		close_button.pressed.connect(close)

# ============================================================================
# SHOW / CLOSE
# ============================================================================

func show_skill(skill: SkillResource, rank: int, skill_can_learn: bool, points_available: int, missing_reqs: Array = []):
	"""Populate and show the popup for a skill."""
	current_skill = skill
	current_rank = rank
	can_learn = skill_can_learn

	if not skill:
		return

	var max_rank = skill.get_max_rank()
	var is_maxed = rank >= max_rank

	# Name
	if skill_name_label:
		skill_name_label.text = skill.skill_name

	# Icon
	if icon_rect:
		icon_rect.texture = skill.icon if skill.icon else null

	# Description
	if description_label:
		description_label.text = skill.description

	# Rank
	if rank_label:
		rank_label.text = "Rank: %d / %d" % [rank, max_rank]

	# Cost
	if cost_label:
		cost_label.text = "Cost: %d skill point(s)" % skill.skill_point_cost

	# Prerequisites
	if prerequisites_label:
		if skill.prerequisites.size() > 0 or skill.tree_points_required > 0:
			var lines: Array[String] = []

			if skill.tree_points_required > 0:
				lines.append("• %d tree points required" % skill.tree_points_required)

			for prereq in skill.prerequisites:
				if prereq and prereq.required_skill:
					lines.append("• %s" % prereq.get_display_text())

			prerequisites_label.text = "Requires:\n" + "\n".join(lines)
			prerequisites_label.show()
		else:
			prerequisites_label.text = ""
			prerequisites_label.hide()

	# Learn button state
	if learn_button:
		if is_maxed:
			learn_button.text = "Maxed"
			learn_button.disabled = true
		elif not skill_can_learn:
			learn_button.text = "Requirements Not Met"
			learn_button.disabled = true
		elif points_available < skill.skill_point_cost:
			learn_button.text = "Not Enough Points"
			learn_button.disabled = true
		else:
			learn_button.text = "Learn (-%d SP)" % skill.skill_point_cost
			learn_button.disabled = false

	show()

func close():
	"""Hide the popup."""
	current_skill = null
	hide()
	closed.emit()
	get_viewport().set_input_as_handled()

# ============================================================================
# INPUT
# ============================================================================

func _on_overlay_input(event: InputEvent):
	"""Close when clicking the dark overlay."""
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()

func _on_learn_pressed():
	"""Emit learn signal with current skill."""
	if current_skill:
		learn_pressed.emit(current_skill)

func _unhandled_input(event: InputEvent):
	"""Close on back button / escape when visible."""
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
