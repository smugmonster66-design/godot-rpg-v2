@tool
extends PanelContainer

signal companion_modified()

const CompanionDataScript = preload("res://resources/data/companion_data.gd")
const ActionEffectScript = preload("res://scripts/resources/action_effect.gd")
const EffectRowScene = preload("res://addons/companion_builder/widgets/effect_row.tscn")

# ============================================================================
# ONREADY — Identity tab
# ============================================================================
@onready var no_selection_label: Label = %NoSelectionLabel
@onready var tab_container: TabContainer = %TabContainer
@onready var companion_name_edit: LineEdit = %CompanionNameEdit
@onready var companion_id_edit: LineEdit = %CompanionIdEdit
@onready var auto_id_button: Button = %AutoIdButton
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var action_name_edit: LineEdit = %ActionNameEdit
@onready var action_description_edit: TextEdit = %ActionDescriptionEdit
@onready var portrait_path_label: Label = %PortraitPathLabel
@onready var pick_portrait_button: Button = %PickPortraitButton
@onready var clear_portrait_button: Button = %ClearPortraitButton
@onready var portrait_preview: TextureRect = %PortraitPreview
@onready var companion_type_dropdown: OptionButton = %CompanionTypeDropdown
@onready var synergy_tags_edit: LineEdit = %SynergyTagsEdit

# ============================================================================
# ONREADY — Combat tab
# ============================================================================
@onready var base_max_hp_spin: SpinBox = %BaseMaxHpSpin
@onready var hp_scaling_dropdown: OptionButton = %HpScalingDropdown
@onready var hp_scaling_value_spin: SpinBox = %HpScalingValueSpin
@onready var hp_preview_widget = %HpPreviewWidget
@onready var trigger_dropdown: OptionButton = %TriggerDropdown
@onready var threshold_row: HBoxContainer = %ThresholdRow
@onready var threshold_spin: SpinBox = %ThresholdSpin
@onready var target_rule_dropdown: OptionButton = %TargetRuleDropdown
@onready var condition_path_label: Label = %ConditionPathLabel
@onready var pick_condition_button: Button = %PickConditionButton
@onready var clear_condition_button: Button = %ClearConditionButton
@onready var inspect_condition_button: Button = %InspectConditionButton
@onready var cooldown_spin: SpinBox = %CooldownSpin
@onready var uses_per_combat_spin: SpinBox = %UsesPerCombatSpin
@onready var fires_on_first_turn_check: CheckBox = %FiresOnFirstTurnCheck
@onready var has_taunt_check: CheckBox = %HasTauntCheck
@onready var taunt_duration_row: HBoxContainer = %TauntDurationRow
@onready var taunt_duration_spin: SpinBox = %TauntDurationSpin

# ============================================================================
# ONREADY — Effects tab
# ============================================================================
@onready var effects_container: VBoxContainer = %EffectsContainer
@onready var add_effect_button: Button = %AddEffectButton

# ============================================================================
# ONREADY — Visuals tab
# ============================================================================
@onready var anim_set_path_label: Label = %AnimSetPathLabel
@onready var pick_anim_set_button: Button = %PickAnimSetButton
@onready var clear_anim_set_button: Button = %ClearAnimSetButton
@onready var inspect_anim_set_button: Button = %InspectAnimSetButton

@onready var idle_anim_path_label: Label = %IdleAnimPathLabel
@onready var pick_idle_anim_button: Button = %PickIdleAnimButton
@onready var clear_idle_anim_button: Button = %ClearIdleAnimButton
@onready var inspect_idle_anim_button: Button = %InspectIdleAnimButton

@onready var summon_enter_path_label: Label = %SummonEnterPathLabel
@onready var pick_summon_enter_button: Button = %PickSummonEnterButton
@onready var clear_summon_enter_button: Button = %ClearSummonEnterButton
@onready var inspect_summon_enter_button: Button = %InspectSummonEnterButton

@onready var emanate_path_label: Label = %EmanatePathLabel
@onready var pick_emanate_button: Button = %PickEmanateButton
@onready var clear_emanate_button: Button = %ClearEmanateButton
@onready var inspect_emanate_button: Button = %InspectEmanateButton

@onready var bark_set_path_label: Label = %BarkSetPathLabel
@onready var pick_bark_set_button: Button = %PickBarkSetButton
@onready var clear_bark_set_button: Button = %ClearBarkSetButton
@onready var inspect_bark_set_button: Button = %InspectBarkSetButton

# ============================================================================
# ONREADY — Summon tab
# ============================================================================
@onready var summon_info_label: Label = %SummonInfoLabel
@onready var duration_turns_spin: SpinBox = %DurationTurnsSpin

# ============================================================================
# STATE
# ============================================================================
var _suppress_signals: bool = false
var _condition_resource: Resource = null
var _visual_resources: Dictionary = {
	"animation_set": null,
	"idle_animation": null,
	"summon_enter_preset": null,
	"entry_emanate_preset": null,
	"bark_set": null,
}
var _file_dialog: EditorFileDialog = null
var _dialog_purpose: String = ""

# ============================================================================
# TRIGGER TOOLTIPS
# ============================================================================
const TRIGGER_TOOLTIPS: Dictionary = {
	"PLAYER_TURN_START": "Fires at the beginning of each player turn",
	"PLAYER_TURN_END": "Fires at the end of each player turn",
	"ENEMY_TURN_START": "Fires when any enemy's turn begins",
	"PLAYER_DAMAGED": "Fires whenever the player takes any damage",
	"PLAYER_DAMAGED_THRESHOLD": "Fires when player HP drops below a percentage threshold",
	"ALLY_DAMAGED": "Fires when any ally (player or companion) takes damage",
	"COMPANION_DAMAGED": "Fires when THIS companion takes damage",
	"OTHER_COMPANION_DAMAGED": "Fires when a different companion (not this one) takes damage",
	"ENEMY_KILLED": "Fires whenever an enemy is killed",
	"COMPANION_KILLED": "Fires when any companion is killed",
	"ROUND_START": "Fires once at the start of each combat round (before any turns)",
	"ON_SUMMON": "Fires once when this companion first enters combat",
	"ON_DEATH": "Fires once when this companion is killed (death rattle effect)",
}

const TARGET_TOOLTIPS: Dictionary = {
	"RANDOM_ENEMY": "Targets a randomly selected living enemy",
	"ALL_ENEMIES": "Targets every living enemy simultaneously",
	"LOWEST_HP_ENEMY": "Targets the enemy with the lowest current HP",
	"PLAYER": "Targets the player character",
	"SELF": "Targets this companion itself",
	"OTHER_COMPANION": "Targets another companion (not this one)",
	"LOWEST_HP_ALLY": "Targets the ally (player or companion) with the lowest current HP",
	"ALL_ALLIES": "Targets the player and all living companions",
	"TRIGGERING_SOURCE": "Targets whatever caused the trigger event (e.g. the enemy that dealt damage)",
	"DAMAGED_ALLY": "Targets the specific ally that was just damaged (for reactive triggers)",
}

const HP_SCALING_TOOLTIPS: Dictionary = {
	"FLAT": "Fixed HP. base_max_hp is the final value, scaling_value is ignored",
	"PLAYER_PERCENT": "HP = player_max_hp x scaling_value. Example: 0.3 = 30% of player HP",
	"PLAYER_LEVEL": "HP = base_max_hp + (player_level x scaling_value). Grows with level",
}

# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	_populate_dropdowns()
	_connect_signals()
	_show_no_selection()

func _populate_dropdowns() -> void:
	# Companion Type
	if companion_type_dropdown:
		companion_type_dropdown.clear()
		var ct_keys = CompanionDataScript.CompanionType.keys()
		var ct_vals = CompanionDataScript.CompanionType.values()
		for i in ct_keys.size():
			companion_type_dropdown.add_item(ct_keys[i], ct_vals[i])
		companion_type_dropdown.set_item_tooltip(0, "Permanent party member. Persists across combats with persistent HP")
		companion_type_dropdown.set_item_tooltip(1, "Temporary companion created by skills. May have limited duration")

	# HP Scaling
	if hp_scaling_dropdown:
		hp_scaling_dropdown.clear()
		var hs_keys = CompanionDataScript.HPScaling.keys()
		var hs_vals = CompanionDataScript.HPScaling.values()
		for i in hs_keys.size():
			hp_scaling_dropdown.add_item(hs_keys[i], hs_vals[i])
			if hs_keys[i] in HP_SCALING_TOOLTIPS:
				hp_scaling_dropdown.set_item_tooltip(i, HP_SCALING_TOOLTIPS[hs_keys[i]])

	# Trigger
	if trigger_dropdown:
		trigger_dropdown.clear()
		var tr_keys = CompanionDataScript.CompanionTrigger.keys()
		var tr_vals = CompanionDataScript.CompanionTrigger.values()
		for i in tr_keys.size():
			trigger_dropdown.add_item(tr_keys[i], tr_vals[i])
			if tr_keys[i] in TRIGGER_TOOLTIPS:
				trigger_dropdown.set_item_tooltip(i, TRIGGER_TOOLTIPS[tr_keys[i]])

	# Target Rule
	if target_rule_dropdown:
		target_rule_dropdown.clear()
		var tg_keys = CompanionDataScript.CompanionTarget.keys()
		var tg_vals = CompanionDataScript.CompanionTarget.values()
		for i in tg_keys.size():
			target_rule_dropdown.add_item(tg_keys[i], tg_vals[i])
			if tg_keys[i] in TARGET_TOOLTIPS:
				target_rule_dropdown.set_item_tooltip(i, TARGET_TOOLTIPS[tg_keys[i]])

func _connect_signals() -> void:
	# Identity
	if companion_name_edit:
		companion_name_edit.text_changed.connect(_on_field_changed)
	if companion_id_edit:
		companion_id_edit.text_changed.connect(_on_field_changed)
	if auto_id_button:
		auto_id_button.pressed.connect(_on_auto_id_pressed)
	if description_edit:
		description_edit.text_changed.connect(_on_text_changed)
	if action_name_edit:
		action_name_edit.text_changed.connect(_on_field_changed)
	if action_description_edit:
		action_description_edit.text_changed.connect(_on_text_changed)
	if pick_portrait_button:
		pick_portrait_button.pressed.connect(func(): _browse_resource("portrait", "*.png,*.jpg,*.webp,*.svg,*.tres", "Portrait Texture"))
	if clear_portrait_button:
		clear_portrait_button.pressed.connect(_on_clear_portrait)
	if companion_type_dropdown:
		companion_type_dropdown.item_selected.connect(_on_type_changed)
	if synergy_tags_edit:
		synergy_tags_edit.text_changed.connect(_on_field_changed)

	# Health
	if base_max_hp_spin:
		base_max_hp_spin.value_changed.connect(_on_hp_field_changed)
	if hp_scaling_dropdown:
		hp_scaling_dropdown.item_selected.connect(_on_hp_scaling_changed)
	if hp_scaling_value_spin:
		hp_scaling_value_spin.value_changed.connect(_on_hp_field_changed)

	# Trigger
	if trigger_dropdown:
		trigger_dropdown.item_selected.connect(_on_trigger_changed)
	if threshold_spin:
		threshold_spin.value_changed.connect(_on_value_changed)

	# Target
	if target_rule_dropdown:
		target_rule_dropdown.item_selected.connect(_on_dropdown_changed)

	# Condition
	if pick_condition_button:
		pick_condition_button.pressed.connect(func(): _browse_resource("condition", "*.tres", "AffixCondition"))
	if clear_condition_button:
		clear_condition_button.pressed.connect(_on_clear_condition)
	if inspect_condition_button:
		inspect_condition_button.pressed.connect(_on_inspect_condition)

	# Limits
	if cooldown_spin:
		cooldown_spin.value_changed.connect(_on_value_changed)
	if uses_per_combat_spin:
		uses_per_combat_spin.value_changed.connect(_on_value_changed)
	if fires_on_first_turn_check:
		fires_on_first_turn_check.toggled.connect(_on_check_changed)

	# Taunt
	if has_taunt_check:
		has_taunt_check.toggled.connect(_on_taunt_toggled)
	if taunt_duration_spin:
		taunt_duration_spin.value_changed.connect(_on_value_changed)

	# Effects
	if add_effect_button:
		add_effect_button.pressed.connect(_on_add_effect_pressed)

	# Visuals — Browse/Clear/Inspect for each resource path
	_connect_visual_row(pick_anim_set_button, clear_anim_set_button, inspect_anim_set_button, "animation_set")
	_connect_visual_row(pick_idle_anim_button, clear_idle_anim_button, inspect_idle_anim_button, "idle_animation")
	_connect_visual_row(pick_summon_enter_button, clear_summon_enter_button, inspect_summon_enter_button, "summon_enter_preset")
	_connect_visual_row(pick_emanate_button, clear_emanate_button, inspect_emanate_button, "entry_emanate_preset")
	_connect_visual_row(pick_bark_set_button, clear_bark_set_button, inspect_bark_set_button, "bark_set")

	# Summon
	if duration_turns_spin:
		duration_turns_spin.value_changed.connect(_on_value_changed)

func _connect_visual_row(browse_btn: Button, clear_btn: Button, inspect_btn: Button, field: String) -> void:
	if browse_btn:
		browse_btn.pressed.connect(func(): _browse_resource(field, "*.tres", field.capitalize()))
	if clear_btn:
		clear_btn.pressed.connect(func(): _clear_visual(field))
	if inspect_btn:
		inspect_btn.pressed.connect(func(): _inspect_visual(field))

# ============================================================================
# DISPLAY STATES
# ============================================================================

func _show_no_selection() -> void:
	if no_selection_label:
		no_selection_label.visible = true
	if tab_container:
		tab_container.visible = false

func _show_detail() -> void:
	if no_selection_label:
		no_selection_label.visible = false
	if tab_container:
		tab_container.visible = true

# ============================================================================
# PUBLIC API
# ============================================================================

func load_companion(data: Resource) -> void:
	_show_detail()
	_suppress_signals = true

	# Identity
	if companion_name_edit:
		companion_name_edit.text = str(data.get("companion_name")) if data.get("companion_name") != null else ""
	if companion_id_edit:
		companion_id_edit.text = str(data.get("companion_id")) if data.get("companion_id") != null else ""
	if description_edit:
		description_edit.text = str(data.get("description")) if data.get("description") != null else ""
	if action_name_edit:
		action_name_edit.text = str(data.get("action_name")) if data.get("action_name") != null else ""
	if action_description_edit:
		action_description_edit.text = str(data.get("action_description")) if data.get("action_description") != null else ""

	# Portrait
	var portrait = data.get("portrait")
	if portrait and portrait is Texture2D:
		portrait_preview.texture = portrait
		portrait_path_label.text = portrait.resource_path.get_file() if portrait.resource_path else "(inline)"
	else:
		portrait_preview.texture = null
		portrait_path_label.text = "(none)"

	# Type
	if companion_type_dropdown:
		var ct = int(data.get("companion_type")) if data.get("companion_type") != null else 0
		_select_by_id(companion_type_dropdown, ct)

	# Synergy Tags
	if synergy_tags_edit:
		var tags = data.get("synergy_tags")
		if tags is Array and tags.size() > 0:
			var tag_strings: PackedStringArray = []
			for t in tags:
				tag_strings.append(String(t))
			synergy_tags_edit.text = ", ".join(tag_strings)
		else:
			synergy_tags_edit.text = ""

	# Health
	if base_max_hp_spin:
		base_max_hp_spin.set_value_no_signal(float(data.get("base_max_hp")) if data.get("base_max_hp") != null else 50.0)
	if hp_scaling_dropdown:
		var hs = int(data.get("hp_scaling")) if data.get("hp_scaling") != null else 0
		_select_by_id(hp_scaling_dropdown, hs)
	if hp_scaling_value_spin:
		hp_scaling_value_spin.set_value_no_signal(float(data.get("hp_scaling_value")) if data.get("hp_scaling_value") != null else 0.0)

	# Trigger
	if trigger_dropdown:
		var tr = int(data.get("trigger")) if data.get("trigger") != null else 0
		_select_by_id(trigger_dropdown, tr)
	var trigger_data = data.get("trigger_data")
	if trigger_data is Dictionary and trigger_data.has("threshold_percent"):
		if threshold_spin:
			threshold_spin.set_value_no_signal(float(trigger_data["threshold_percent"]))
	_update_threshold_visibility()

	# Target
	if target_rule_dropdown:
		var tg = int(data.get("target_rule")) if data.get("target_rule") != null else 0
		_select_by_id(target_rule_dropdown, tg)

	# Condition
	_condition_resource = data.get("condition")
	_update_condition_label()

	# Limits
	if cooldown_spin:
		cooldown_spin.set_value_no_signal(float(data.get("cooldown_turns")) if data.get("cooldown_turns") != null else 0.0)
	if uses_per_combat_spin:
		uses_per_combat_spin.set_value_no_signal(float(data.get("uses_per_combat")) if data.get("uses_per_combat") != null else 0.0)
	if fires_on_first_turn_check:
		fires_on_first_turn_check.set_pressed_no_signal(bool(data.get("fires_on_first_turn")) if data.get("fires_on_first_turn") != null else true)

	# Taunt
	if has_taunt_check:
		has_taunt_check.set_pressed_no_signal(bool(data.get("has_taunt")) if data.get("has_taunt") != null else false)
	if taunt_duration_spin:
		taunt_duration_spin.set_value_no_signal(float(data.get("taunt_duration")) if data.get("taunt_duration") != null else 0.0)
	_update_taunt_visibility()

	# Effects
	_clear_effect_rows()
	var effects = data.get("action_effects")
	if effects is Array:
		for i in effects.size():
			_add_effect_row(effects[i], i)

	# Visuals
	_load_visual("animation_set", data.get("animation_set"), anim_set_path_label)
	_load_visual("idle_animation", data.get("idle_animation"), idle_anim_path_label)
	_load_visual("summon_enter_preset", data.get("summon_enter_preset"), summon_enter_path_label)
	_load_visual("entry_emanate_preset", data.get("entry_emanate_preset"), emanate_path_label)
	_load_visual("bark_set", data.get("bark_set"), bark_set_path_label)

	# Summon
	if duration_turns_spin:
		duration_turns_spin.set_value_no_signal(float(data.get("duration_turns")) if data.get("duration_turns") != null else 0.0)
	_update_summon_state()

	# HP preview
	_update_hp_preview()

	_suppress_signals = false

func clear_all() -> void:
	_suppress_signals = true
	if companion_name_edit: companion_name_edit.text = ""
	if companion_id_edit: companion_id_edit.text = ""
	if description_edit: description_edit.text = ""
	if action_name_edit: action_name_edit.text = ""
	if action_description_edit: action_description_edit.text = ""
	if portrait_preview: portrait_preview.texture = null
	if portrait_path_label: portrait_path_label.text = "(none)"
	if companion_type_dropdown: companion_type_dropdown.select(0)
	if synergy_tags_edit: synergy_tags_edit.text = ""
	if base_max_hp_spin: base_max_hp_spin.set_value_no_signal(50.0)
	if hp_scaling_dropdown: hp_scaling_dropdown.select(0)
	if hp_scaling_value_spin: hp_scaling_value_spin.set_value_no_signal(0.0)
	if trigger_dropdown: trigger_dropdown.select(0)
	if threshold_spin: threshold_spin.set_value_no_signal(0.25)
	if target_rule_dropdown: target_rule_dropdown.select(0)
	_condition_resource = null
	_update_condition_label()
	if cooldown_spin: cooldown_spin.set_value_no_signal(0.0)
	if uses_per_combat_spin: uses_per_combat_spin.set_value_no_signal(0.0)
	if fires_on_first_turn_check: fires_on_first_turn_check.set_pressed_no_signal(true)
	if has_taunt_check: has_taunt_check.set_pressed_no_signal(false)
	if taunt_duration_spin: taunt_duration_spin.set_value_no_signal(0.0)
	_clear_effect_rows()
	for field in _visual_resources:
		_visual_resources[field] = null
	if anim_set_path_label: anim_set_path_label.text = "(none)"
	if idle_anim_path_label: idle_anim_path_label.text = "(none)"
	if summon_enter_path_label: summon_enter_path_label.text = "(none)"
	if emanate_path_label: emanate_path_label.text = "(none)"
	if bark_set_path_label: bark_set_path_label.text = "(none)"
	if duration_turns_spin: duration_turns_spin.set_value_no_signal(0.0)
	_update_threshold_visibility()
	_update_taunt_visibility()
	_update_summon_state()
	_update_hp_preview()
	_suppress_signals = false
	_show_no_selection()

# ============================================================================
# EFFECTS MANAGEMENT
# ============================================================================

func _add_effect_row(effect: Resource = null, index: int = -1) -> void:
	if not effects_container:
		return
	if not effect:
		effect = ActionEffectScript.new()
		effect.effect_name = "New Effect"

	var row = EffectRowScene.instantiate()
	effects_container.add_child(row)
	if index < 0:
		index = effects_container.get_child_count() - 1
	row.set_index(index)
	row.load_effect(effect)

	row.modified.connect(_on_effect_modified)
	row.inspect_requested.connect(_on_effect_inspect_requested)
	row.remove_requested.connect(func(): _on_effect_remove_requested(row))

func _clear_effect_rows() -> void:
	if not effects_container:
		return
	for child in effects_container.get_children():
		child.queue_free()

func _reindex_effects() -> void:
	if not effects_container:
		return
	for i in effects_container.get_child_count():
		var row = effects_container.get_child(i)
		if row.has_method("set_index"):
			row.set_index(i)

func get_effect_resources() -> Array:
	var result: Array = []
	if not effects_container:
		return result
	for child in effects_container.get_children():
		if child.has_method("get_effect"):
			result.append(child.get_effect())
	return result

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_field_changed(_text: String) -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_text_changed() -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_dropdown_changed(_index: int) -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_value_changed(_val: float) -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_check_changed(_val: bool) -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_auto_id_pressed() -> void:
	if companion_name_edit and companion_id_edit:
		var name_str = companion_name_edit.text.strip_edges()
		var id_str = name_str.to_lower().replace(" ", "_").replace("-", "_")
		# Strip non-identifier chars
		var clean = ""
		for c in id_str:
			if c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
				clean += c
		companion_id_edit.text = clean
		if not _suppress_signals:
			companion_modified.emit()

func _on_type_changed(_index: int) -> void:
	_update_summon_state()
	if not _suppress_signals:
		companion_modified.emit()

func _on_hp_scaling_changed(_index: int) -> void:
	_update_hp_preview()
	if not _suppress_signals:
		companion_modified.emit()

func _on_hp_field_changed(_val: float) -> void:
	_update_hp_preview()
	if not _suppress_signals:
		companion_modified.emit()

func _on_trigger_changed(_index: int) -> void:
	_update_threshold_visibility()
	if not _suppress_signals:
		companion_modified.emit()

func _on_taunt_toggled(pressed: bool) -> void:
	_update_taunt_visibility()
	if not _suppress_signals:
		companion_modified.emit()

func _on_add_effect_pressed() -> void:
	_add_effect_row()
	if not _suppress_signals:
		companion_modified.emit()

func _on_effect_modified() -> void:
	if not _suppress_signals:
		companion_modified.emit()

func _on_effect_inspect_requested(effect: Resource) -> void:
	if effect:
		EditorInterface.inspect_object(effect)

func _on_effect_remove_requested(row: Control) -> void:
	row.queue_free()
	call_deferred("_reindex_effects")
	if not _suppress_signals:
		companion_modified.emit()

# ============================================================================
# CONDITIONAL VISIBILITY
# ============================================================================

func _update_threshold_visibility() -> void:
	if not threshold_row or not trigger_dropdown:
		return
	var idx = trigger_dropdown.selected
	if idx >= 0:
		var trigger_name = trigger_dropdown.get_item_text(idx)
		threshold_row.visible = (trigger_name == "PLAYER_DAMAGED_THRESHOLD")
	else:
		threshold_row.visible = false

func _update_taunt_visibility() -> void:
	if taunt_duration_row and has_taunt_check:
		taunt_duration_row.visible = has_taunt_check.button_pressed

func _update_summon_state() -> void:
	if not companion_type_dropdown:
		return
	var idx = companion_type_dropdown.selected
	var is_summon = idx >= 0 and companion_type_dropdown.get_item_text(idx) == "SUMMON"

	if duration_turns_spin:
		duration_turns_spin.editable = is_summon
		duration_turns_spin.modulate.a = 1.0 if is_summon else 0.5

	if summon_info_label:
		if is_summon:
			summon_info_label.text = "Configure summon duration. These fields apply to temporary companions."
		else:
			summon_info_label.text = "These fields only apply to SUMMON-type companions and will be ignored for NPCs."

func _update_hp_preview() -> void:
	if not hp_preview_widget:
		return
	var base_hp = int(base_max_hp_spin.value) if base_max_hp_spin else 50
	var scaling_mode = 0
	if hp_scaling_dropdown and hp_scaling_dropdown.selected >= 0:
		scaling_mode = hp_scaling_dropdown.get_item_id(hp_scaling_dropdown.selected)
	var scaling_value = hp_scaling_value_spin.value if hp_scaling_value_spin else 0.0
	if hp_preview_widget.has_method("update_preview"):
		hp_preview_widget.update_preview(base_hp, scaling_mode, scaling_value)

# ============================================================================
# CONDITION HANDLING
# ============================================================================

func _update_condition_label() -> void:
	if not condition_path_label:
		return
	if _condition_resource and _condition_resource.resource_path:
		condition_path_label.text = _condition_resource.resource_path.get_file()
	else:
		condition_path_label.text = "(none)"

func _on_clear_condition() -> void:
	_condition_resource = null
	_update_condition_label()
	if not _suppress_signals:
		companion_modified.emit()

func _on_inspect_condition() -> void:
	if _condition_resource:
		EditorInterface.inspect_object(_condition_resource)

# ============================================================================
# VISUAL RESOURCE HANDLING
# ============================================================================

func _load_visual(field: String, resource: Resource, label: Label) -> void:
	_visual_resources[field] = resource
	if label:
		if resource and resource.resource_path:
			label.text = resource.resource_path.get_file()
		else:
			label.text = "(none)"

func _clear_visual(field: String) -> void:
	_visual_resources[field] = null
	var label = _get_visual_label(field)
	if label:
		label.text = "(none)"
	if not _suppress_signals:
		companion_modified.emit()

func _inspect_visual(field: String) -> void:
	var res = _visual_resources.get(field)
	if res:
		EditorInterface.inspect_object(res)

func _get_visual_label(field: String) -> Label:
	match field:
		"animation_set": return anim_set_path_label
		"idle_animation": return idle_anim_path_label
		"summon_enter_preset": return summon_enter_path_label
		"entry_emanate_preset": return emanate_path_label
		"bark_set": return bark_set_path_label
	return null

# ============================================================================
# PORTRAIT HANDLING
# ============================================================================

func _on_clear_portrait() -> void:
	if portrait_preview:
		portrait_preview.texture = null
	if portrait_path_label:
		portrait_path_label.text = "(none)"
	if not _suppress_signals:
		companion_modified.emit()

# ============================================================================
# FILE DIALOG
# ============================================================================

func _browse_resource(purpose: String, filter: String, title: String) -> void:
	if _file_dialog:
		_file_dialog.queue_free()

	_dialog_purpose = purpose
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	# Split filters by comma if multiple
	var filters = filter.split(",")
	for f in filters:
		_file_dialog.add_filter(f.strip_edges(), title)
	_file_dialog.file_selected.connect(_on_resource_file_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)

func _on_resource_file_selected(path: String) -> void:
	var res = load(path)
	if not res:
		push_warning("[CompanionBuilder] Could not load: %s" % path)
		return

	match _dialog_purpose:
		"portrait":
			if res is Texture2D:
				if portrait_preview:
					portrait_preview.texture = res
				if portrait_path_label:
					portrait_path_label.text = path.get_file()
			else:
				push_warning("[CompanionBuilder] Selected file is not a Texture2D")
		"condition":
			_condition_resource = res
			_update_condition_label()
		_:
			# Visual resource fields
			if _dialog_purpose in _visual_resources:
				_visual_resources[_dialog_purpose] = res
				var label = _get_visual_label(_dialog_purpose)
				if label:
					label.text = path.get_file()

	if not _suppress_signals:
		companion_modified.emit()

	if _file_dialog:
		_file_dialog.queue_free()
		_file_dialog = null

# ============================================================================
# HELPERS
# ============================================================================

func _select_by_id(dropdown: OptionButton, target_id: int) -> void:
	for i in dropdown.get_item_count():
		if dropdown.get_item_id(i) == target_id:
			dropdown.select(i)
			return

func get_selected_id(dropdown: OptionButton) -> int:
	var idx = dropdown.selected
	if idx >= 0:
		return dropdown.get_item_id(idx)
	return 0
