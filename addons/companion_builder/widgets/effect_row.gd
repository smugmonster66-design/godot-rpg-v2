@tool
extends PanelContainer

signal modified()
signal inspect_requested(effect: Resource)
signal remove_requested()

const ActionEffectScript = preload("res://scripts/resources/action_effect.gd")

@onready var index_label: Label = %IndexLabel
@onready var effect_name_edit: LineEdit = %EffectNameEdit
@onready var effect_type_dropdown: OptionButton = %EffectTypeDropdown
@onready var target_type_dropdown: OptionButton = %TargetTypeDropdown
@onready var value_source_dropdown: OptionButton = %ValueSourceDropdown
@onready var base_value_spin: SpinBox = %BaseValueSpin
@onready var inspect_button: Button = %InspectButton
@onready var remove_button: Button = %RemoveButton

var _action_effect: Resource = null
var _suppress_signals: bool = false

# ============================================================================
# EFFECT TYPE TOOLTIPS
# ============================================================================
const EFFECT_TYPE_TOOLTIPS: Dictionary = {
	"DAMAGE": "Deal damage to target",
	"HEAL": "Restore HP to target",
	"ADD_STATUS": "Apply a status effect",
	"REMOVE_STATUS": "Remove a specific status",
	"CLEANSE": "Remove all negative statuses",
	"SHIELD": "Grant barrier/shield",
	"ARMOR_BUFF": "Grant temporary armor",
	"DAMAGE_REDUCTION": "Reduce incoming damage",
	"REFLECT": "Reflect damage back to attacker",
	"LIFESTEAL": "Heal for a percentage of damage dealt",
	"EXECUTE": "Deal bonus damage to low-HP targets",
	"COMBO_MARK": "Mark target for combo follow-up",
	"ECHO": "Repeat the previous effect",
	"SPLASH": "Deal reduced damage to adjacent enemies",
	"CHAIN": "Bounce damage between multiple targets",
	"RANDOM_STRIKES": "Hit random targets multiple times",
	"MANA_MANIPULATE": "Add or remove mana",
	"MODIFY_COOLDOWN": "Change an action's cooldown",
	"REFUND_CHARGES": "Restore action charges",
	"GRANT_TEMP_ACTION": "Give a temporary action for this combat",
	"CHANNEL": "Multi-turn channeled effect",
	"COUNTER_SETUP": "Prepare a counter-attack",
	"SUMMON_COMPANION": "Summon another companion",
}

# ============================================================================
# TARGET TYPE TOOLTIPS
# ============================================================================
const TARGET_TYPE_TOOLTIPS: Dictionary = {
	"SELF": "Targets the source (this companion)",
	"SINGLE_ENEMY": "Targets one enemy (resolved by companion target_rule)",
	"ALL_ENEMIES": "Targets every living enemy",
	"SINGLE_ALLY": "Targets one ally (player or companion)",
	"ALL_ALLIES": "Targets the player and all living companions",
}

# ============================================================================
# VALUE SOURCE TOOLTIPS
# ============================================================================
const VALUE_SOURCE_TOOLTIPS: Dictionary = {
	"STATIC": "Fixed value from base_value field",
	"DICE_TOTAL": "Sum of all dice values (companions don't use dice, usually 0)",
	"DICE_COUNT": "Number of dice used",
	"SOURCE_STAT": "Scale from a source stat (STR/AGI/INT/LCK)",
	"SOURCE_HP_PERCENT": "Source's current HP as a percentage",
	"SOURCE_MISSING_HP": "Source's missing HP amount",
	"TARGET_HP_PERCENT": "Target's current HP as a percentage",
	"TARGET_MISSING_HP": "Target's missing HP amount",
	"TARGET_STATUS_STACKS": "Number of stacks of a specific status on target",
	"TURN_NUMBER": "Current combat turn number",
	"ACTIVE_STATUS_COUNT": "Number of active status effects",
	"MANA_PERCENT": "Current mana as a percentage",
	"SOURCE_CURRENT_HP": "Source's current HP x (base_value / 100)",
	"SOURCE_MAX_HP": "Source's max HP x (base_value / 100)",
	"SOURCE_DEFENSE_STAT": "Source's armor or barrier x base_value",
	"TARGET_CURRENT_HP": "Target's current HP x (base_value / 100)",
	"TARGET_MAX_HP": "Target's max HP x (base_value / 100)",
	"ALIVE_ENEMY_COUNT": "Living enemies x base_value",
	"ALIVE_COMPANION_COUNT": "Living companions x base_value",
	"TRIGGER_DAMAGE_AMOUNT": "Trigger damage x (base_value / 100)",
}

# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	_populate_dropdowns()
	_connect_signals()

func _populate_dropdowns() -> void:
	if not effect_type_dropdown:
		return

	# EffectType
	var et_keys = ActionEffectScript.EffectType.keys()
	var et_vals = ActionEffectScript.EffectType.values()
	effect_type_dropdown.clear()
	for i in et_keys.size():
		effect_type_dropdown.add_item(et_keys[i], et_vals[i])
		if et_keys[i] in EFFECT_TYPE_TOOLTIPS:
			effect_type_dropdown.set_item_tooltip(i, EFFECT_TYPE_TOOLTIPS[et_keys[i]])

	# TargetType
	var tt_keys = ActionEffectScript.TargetType.keys()
	var tt_vals = ActionEffectScript.TargetType.values()
	target_type_dropdown.clear()
	for i in tt_keys.size():
		target_type_dropdown.add_item(tt_keys[i], tt_vals[i])
		if tt_keys[i] in TARGET_TYPE_TOOLTIPS:
			target_type_dropdown.set_item_tooltip(i, TARGET_TYPE_TOOLTIPS[tt_keys[i]])

	# ValueSource
	var vs_keys = ActionEffectScript.ValueSource.keys()
	var vs_vals = ActionEffectScript.ValueSource.values()
	value_source_dropdown.clear()
	for i in vs_keys.size():
		value_source_dropdown.add_item(vs_keys[i], vs_vals[i])
		if vs_keys[i] in VALUE_SOURCE_TOOLTIPS:
			value_source_dropdown.set_item_tooltip(i, VALUE_SOURCE_TOOLTIPS[vs_keys[i]])

func _connect_signals() -> void:
	if effect_name_edit:
		effect_name_edit.text_changed.connect(_on_field_changed)
	if effect_type_dropdown:
		effect_type_dropdown.item_selected.connect(_on_dropdown_changed)
	if target_type_dropdown:
		target_type_dropdown.item_selected.connect(_on_dropdown_changed)
	if value_source_dropdown:
		value_source_dropdown.item_selected.connect(_on_dropdown_changed)
	if base_value_spin:
		base_value_spin.value_changed.connect(_on_value_changed)
	if inspect_button:
		inspect_button.pressed.connect(_on_inspect_pressed)
	if remove_button:
		remove_button.pressed.connect(_on_remove_pressed)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_index(idx: int) -> void:
	if index_label:
		index_label.text = "#%d" % (idx + 1)

func load_effect(effect: Resource) -> void:
	_action_effect = effect
	_suppress_signals = true

	if effect_name_edit and effect:
		effect_name_edit.text = effect.get("effect_name") if effect.get("effect_name") else ""

	if effect_type_dropdown and effect:
		var et = int(effect.get("effect_type")) if effect.get("effect_type") != null else 0
		_select_by_id(effect_type_dropdown, et)

	if target_type_dropdown and effect:
		var tt = int(effect.get("target")) if effect.get("target") != null else 0
		_select_by_id(target_type_dropdown, tt)

	if value_source_dropdown and effect:
		var vs = int(effect.get("value_source")) if effect.get("value_source") != null else 0
		_select_by_id(value_source_dropdown, vs)

	if base_value_spin and effect:
		var bv = 0.0
		# Check common base value fields
		if effect.get("base_damage") != null:
			bv = float(effect.get("base_damage"))
		elif effect.get("base_heal") != null:
			bv = float(effect.get("base_heal"))
		elif effect.get("base_shield") != null:
			bv = float(effect.get("base_shield"))
		elif effect.get("base_value") != null:
			bv = float(effect.get("base_value"))
		base_value_spin.set_value_no_signal(bv)

	_suppress_signals = false

func get_effect() -> Resource:
	if not _action_effect:
		_action_effect = ActionEffectScript.new()

	if effect_name_edit:
		_action_effect.effect_name = effect_name_edit.text

	if effect_type_dropdown:
		var idx = effect_type_dropdown.selected
		if idx >= 0:
			_action_effect.effect_type = effect_type_dropdown.get_item_id(idx)

	if target_type_dropdown:
		var idx = target_type_dropdown.selected
		if idx >= 0:
			_action_effect.target = target_type_dropdown.get_item_id(idx)

	if value_source_dropdown:
		var idx = value_source_dropdown.selected
		if idx >= 0:
			_action_effect.value_source = value_source_dropdown.get_item_id(idx)

	if base_value_spin:
		var val = int(base_value_spin.value)
		var et = _action_effect.effect_type
		# Map base value to the correct property based on effect type
		match et:
			0:  # DAMAGE
				_action_effect.base_damage = val
			1:  # HEAL
				_action_effect.base_heal = val
			5:  # SHIELD
				_action_effect.base_shield = val
			_:
				if "base_value" in _action_effect:
					_action_effect.base_value = val

	return _action_effect

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_field_changed(_text: String) -> void:
	if not _suppress_signals:
		modified.emit()

func _on_dropdown_changed(_index: int) -> void:
	if not _suppress_signals:
		modified.emit()

func _on_value_changed(_val: float) -> void:
	if not _suppress_signals:
		modified.emit()

func _on_inspect_pressed() -> void:
	if not _action_effect:
		_action_effect = ActionEffectScript.new()
	get_effect()  # Sync UI → resource before inspecting
	inspect_requested.emit(_action_effect)

func _on_remove_pressed() -> void:
	remove_requested.emit()

# ============================================================================
# HELPERS
# ============================================================================

func _select_by_id(dropdown: OptionButton, target_id: int) -> void:
	for i in dropdown.get_item_count():
		if dropdown.get_item_id(i) == target_id:
			dropdown.select(i)
			return
