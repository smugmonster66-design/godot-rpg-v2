@tool
extends Control

const CompanionDataScript = preload("res://resources/data/companion_data.gd")
const ActionEffectScript = preload("res://scripts/resources/action_effect.gd")
const CompanionSerializer = preload("res://addons/companion_builder/io/companion_serializer.gd")
const CompanionDeserializer = preload("res://addons/companion_builder/io/companion_deserializer.gd")

@onready var browser: PanelContainer = %CompanionBrowserPanel
@onready var detail: PanelContainer = %CompanionDetailPanel
@onready var save_button: Button = %SaveButton
@onready var save_as_button: Button = %SaveAsButton
@onready var validate_button: Button = %ValidateButton
@onready var inspect_button: Button = %InspectButton
@onready var template_dropdown: OptionButton = %TemplateDropdown
@onready var current_companion_label: Label = %CurrentCompanionLabel

var _current_companion: Resource = null
var _current_file_path: String = ""
var _is_dirty: bool = false
var _editor_plugin: EditorPlugin = null
var _file_dialog: EditorFileDialog = null

# ============================================================================
# TEMPLATES
# ============================================================================
const TEMPLATES: Array[Dictionary] = [
	{},  # placeholder for "Select Template..." header
	{
		"name": "Blank",
		"companion_name": "New Companion", "companion_type": 0,
		"base_max_hp": 50, "hp_scaling": 0, "hp_scaling_value": 0.0,
		"trigger": 0, "target_rule": 0, "effects": [],
	},
	{
		"name": "Healer NPC",
		"companion_name": "Healer", "companion_type": 0,
		"base_max_hp": 30, "hp_scaling": 1, "hp_scaling_value": 0.25,
		"trigger": 1, "target_rule": 6,  # PLAYER_TURN_END, LOWEST_HP_ALLY
		"effects": [{"effect_name": "Healing Touch", "effect_type": 1, "target": 3, "value_source": 0, "base_heal": 15}],
	},
	{
		"name": "DPS NPC",
		"companion_name": "Striker", "companion_type": 0,
		"base_max_hp": 50, "hp_scaling": 2, "hp_scaling_value": 2.0,
		"trigger": 0, "target_rule": 0,  # PLAYER_TURN_START, RANDOM_ENEMY
		"effects": [{"effect_name": "Strike", "effect_type": 0, "target": 1, "value_source": 0, "base_damage": 12}],
	},
	{
		"name": "Tank NPC",
		"companion_name": "Guardian", "companion_type": 0,
		"base_max_hp": 40, "hp_scaling": 1, "hp_scaling_value": 0.5,
		"trigger": 0, "target_rule": 1,  # PLAYER_TURN_START, ALL_ENEMIES
		"has_taunt": true, "taunt_duration": 0,
		"effects": [{"effect_name": "Taunt", "effect_type": 2, "target": 2, "value_source": 0, "base_value": 0}],
	},
	{
		"name": "Temp DPS Summon",
		"companion_name": "Fire Sprite", "companion_type": 1,
		"base_max_hp": 30, "hp_scaling": 0, "hp_scaling_value": 0.0,
		"trigger": 0, "target_rule": 0,
		"duration_turns": 3, "fires_on_first_turn": false,
		"effects": [{"effect_name": "Flame Burst", "effect_type": 0, "target": 1, "value_source": 0, "base_damage": 10}],
	},
	{
		"name": "Reactive Protector",
		"companion_name": "Warden", "companion_type": 0,
		"base_max_hp": 35, "hp_scaling": 1, "hp_scaling_value": 0.35,
		"trigger": 3, "target_rule": 3,  # PLAYER_DAMAGED, PLAYER
		"cooldown_turns": 1,
		"effects": [{"effect_name": "Emergency Shield", "effect_type": 5, "target": 3, "value_source": 0, "base_shield": 8}],
	},
	{
		"name": "Death Rattle Summon",
		"companion_name": "Bomb Spirit", "companion_type": 1,
		"base_max_hp": 20, "hp_scaling": 0, "hp_scaling_value": 0.0,
		"trigger": 12, "target_rule": 1,  # ON_DEATH, ALL_ENEMIES
		"effects": [{"effect_name": "Detonation", "effect_type": 0, "target": 2, "value_source": 0, "base_damage": 25}],
	},
]

# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	_populate_template_dropdown()

	if browser:
		browser.companion_selected.connect(_on_companion_selected)
		browser.companion_created.connect(_on_companion_selected)

	if detail:
		detail.companion_modified.connect(_on_companion_modified)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if save_as_button:
		save_as_button.pressed.connect(_on_save_as_pressed)
	if validate_button:
		validate_button.pressed.connect(_on_validate_pressed)
	if inspect_button:
		inspect_button.pressed.connect(_on_inspect_pressed)
	if template_dropdown:
		template_dropdown.item_selected.connect(_on_template_selected)

func _populate_template_dropdown() -> void:
	if not template_dropdown:
		return
	template_dropdown.clear()
	template_dropdown.add_item("Select Template...")
	for i in range(1, TEMPLATES.size()):
		template_dropdown.add_item(TEMPLATES[i].get("name", "Template %d" % i))

# ============================================================================
# PUBLIC
# ============================================================================

func set_editor_plugin(p: EditorPlugin) -> void:
	_editor_plugin = p

# ============================================================================
# COMPANION SELECTION
# ============================================================================

func _on_companion_selected(resource: Resource, file_path: String) -> void:
	_current_companion = resource
	_current_file_path = file_path
	_is_dirty = false
	_update_title()

	if detail:
		CompanionDeserializer.deserialize(resource, detail)

func _on_companion_modified() -> void:
	_is_dirty = true
	_update_title()

# ============================================================================
# SAVE
# ============================================================================

func _on_save_pressed() -> void:
	if _current_file_path == "":
		_on_save_as_pressed()
		return
	_save_to_path(_current_file_path)

func _on_save_as_pressed() -> void:
	if _file_dialog:
		_file_dialog.queue_free()

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Companion Resource")
	if _current_file_path != "":
		_file_dialog.current_path = _current_file_path
	else:
		_file_dialog.current_path = "res://resources/companions/"
	_file_dialog.file_selected.connect(_on_save_path_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)

func _on_save_path_selected(path: String) -> void:
	_current_file_path = path
	_save_to_path(path)
	if _file_dialog:
		_file_dialog.queue_free()
		_file_dialog = null

func _save_to_path(path: String) -> void:
	if not detail:
		push_error("[CompanionBuilder] Detail panel not available")
		return

	var data = CompanionSerializer.serialize(detail, _current_companion)
	if not data:
		push_error("[CompanionBuilder] Serialization failed")
		return

	# Ensure directory exists
	var dir_path = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	data.take_over_path(path)
	var err = ResourceSaver.save(data, path)
	if err == OK:
		_current_companion = data
		_is_dirty = false
		_update_title()
		EditorInterface.get_resource_filesystem().scan()
		print("[CompanionBuilder] Saved: %s" % path)
		# Refresh browser
		if browser and browser.has_method("_on_refresh_pressed"):
			browser._on_refresh_pressed()
	else:
		push_error("[CompanionBuilder] Save failed: %s — %s" % [path, error_string(err)])

# ============================================================================
# VALIDATE
# ============================================================================

func _on_validate_pressed() -> void:
	if not detail:
		return

	var errors: Array[String] = []
	var warnings: Array[String] = []

	# Build temporary data for validation
	var data = CompanionSerializer.serialize(detail, _current_companion)
	if not data:
		push_error("[CompanionBuilder] Cannot validate: serialization failed")
		return

	# Required fields
	if str(data.companion_name).strip_edges() == "":
		errors.append("Companion name is empty")
	if str(data.companion_id).strip_edges() == "" or str(data.companion_id) == "&\"\"":
		errors.append("Companion ID is empty")

	# Health
	if data.base_max_hp <= 0:
		errors.append("Base Max HP must be greater than 0")
	if int(data.hp_scaling) != 0 and data.hp_scaling_value <= 0.0:
		errors.append("HP Scaling Value must be > 0 when scaling mode is not FLAT")

	# Trigger threshold
	if int(data.trigger) == 4:  # PLAYER_DAMAGED_THRESHOLD
		var threshold = data.trigger_data.get("threshold_percent", 0.0)
		if threshold < 0.01 or threshold > 1.0:
			errors.append("Threshold percent must be between 0.01 and 1.0")

	# Effects
	if data.action_effects.is_empty():
		warnings.append("No action effects defined — companion will do nothing when triggered")

	# Summon duration
	if int(data.companion_type) == 1 and data.duration_turns == 0:
		warnings.append("Summon duration is 0 (lasts entire combat). Set a value if you want it to expire")

	# Display results
	if errors.is_empty() and warnings.is_empty():
		print("[CompanionBuilder] ✓ Validation passed — no issues found")
	else:
		for e in errors:
			push_error("[CompanionBuilder] ✗ %s" % e)
		for w in warnings:
			push_warning("[CompanionBuilder] ⚠ %s" % w)
		print("[CompanionBuilder] Validation: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])

# ============================================================================
# INSPECT
# ============================================================================

func _on_inspect_pressed() -> void:
	if _current_companion:
		EditorInterface.inspect_object(_current_companion)

# ============================================================================
# TEMPLATES
# ============================================================================

func _on_template_selected(index: int) -> void:
	if index <= 0 or index >= TEMPLATES.size():
		return

	var template = TEMPLATES[index]
	var data = CompanionDataScript.new()

	data.companion_name = template.get("companion_name", "New Companion")
	data.companion_id = StringName(data.companion_name.to_lower().replace(" ", "_"))
	data.companion_type = template.get("companion_type", 0)
	data.base_max_hp = template.get("base_max_hp", 50)
	data.hp_scaling = template.get("hp_scaling", 0)
	data.hp_scaling_value = template.get("hp_scaling_value", 0.0)
	data.trigger = template.get("trigger", 0)
	data.target_rule = template.get("target_rule", 0)
	data.has_taunt = template.get("has_taunt", false)
	data.taunt_duration = template.get("taunt_duration", 0)
	data.cooldown_turns = template.get("cooldown_turns", 0)
	data.fires_on_first_turn = template.get("fires_on_first_turn", true)
	data.duration_turns = template.get("duration_turns", 0)

	# Build effects from template
	var effect_defs = template.get("effects", [])
	var effects: Array[ActionEffect] = []
	for edef in effect_defs:
		var effect = ActionEffectScript.new()
		effect.effect_name = edef.get("effect_name", "Effect")
		effect.effect_type = edef.get("effect_type", 0)
		effect.target = edef.get("target", 0)
		effect.value_source = edef.get("value_source", 0)
		if edef.has("base_damage"):
			effect.base_damage = edef["base_damage"]
		if edef.has("base_heal"):
			effect.base_heal = edef["base_heal"]
		if edef.has("base_shield"):
			effect.base_shield = edef["base_shield"]
		effects.append(effect)
	data.action_effects = effects

	_current_companion = data
	_current_file_path = ""
	_is_dirty = true

	if detail:
		CompanionDeserializer.deserialize(data, detail)
	_update_title()

	# Reset template dropdown
	if template_dropdown:
		template_dropdown.select(0)

# ============================================================================
# UI HELPERS
# ============================================================================

func _update_title() -> void:
	if not current_companion_label:
		return
	if _current_companion:
		var display = str(_current_companion.get("companion_name"))
		var cid = str(_current_companion.get("companion_id"))
		var dirty_marker = " *" if _is_dirty else ""
		var file_str = " — %s" % _current_file_path.get_file() if _current_file_path != "" else ""
		current_companion_label.text = "%s (%s)%s%s" % [display, cid, file_str, dirty_marker]
	else:
		current_companion_label.text = ""
