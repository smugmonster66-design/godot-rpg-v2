@tool
extends VBoxContainer

@onready var sim_level_spin: SpinBox = %SimLevelSpin
@onready var sim_max_hp_spin: SpinBox = %SimMaxHpSpin
@onready var result_label: Label = %ResultLabel

var _base_hp: int = 50
var _scaling_mode: int = 0  # 0=FLAT, 1=PLAYER_PERCENT, 2=PLAYER_LEVEL
var _scaling_value: float = 0.0

func _ready() -> void:
	if sim_level_spin:
		sim_level_spin.value_changed.connect(_on_sim_changed)
	if sim_max_hp_spin:
		sim_max_hp_spin.value_changed.connect(_on_sim_changed)
	_update_display()

func update_preview(base_hp: int, scaling_mode: int, scaling_value: float) -> void:
	_base_hp = base_hp
	_scaling_mode = scaling_mode
	_scaling_value = scaling_value
	_update_display()

func _on_sim_changed(_val: float) -> void:
	_update_display()

func _update_display() -> void:
	if not result_label:
		return

	var player_level = int(sim_level_spin.value) if sim_level_spin else 10
	var player_max_hp = int(sim_max_hp_spin.value) if sim_max_hp_spin else 200
	var calculated: int = _base_hp
	var formula: String = ""

	match _scaling_mode:
		0:  # FLAT
			calculated = _base_hp
			formula = "flat %d" % _base_hp
		1:  # PLAYER_PERCENT
			calculated = maxi(1, roundi(player_max_hp * _scaling_value))
			formula = "%d x %.2f" % [player_max_hp, _scaling_value]
		2:  # PLAYER_LEVEL
			calculated = maxi(1, _base_hp + roundi(player_level * _scaling_value))
			formula = "%d + (%d x %.1f)" % [_base_hp, player_level, _scaling_value]

	result_label.text = "Calculated: %d HP (%s)" % [calculated, formula]
	result_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
