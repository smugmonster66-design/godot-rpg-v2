@tool
extends VBoxContainer

signal rewards_modified()

@onready var xp_spin: SpinBox = %XPSpin
@onready var gold_spin: SpinBox = %GoldSpin
@onready var items_list: VBoxContainer = %ItemsList
@onready var add_item_button: Button = %AddItemButton
@onready var choice_count_spin: SpinBox = %ChoiceCountSpin
@onready var choice_items_list: VBoxContainer = %ChoiceItemsList
@onready var add_choice_item_button: Button = %AddChoiceItemButton
@onready var unlock_flags_list: VBoxContainer = %UnlockFlagsList
@onready var add_unlock_flag_button: Button = %AddUnlockFlagButton
@onready var unlock_locations_list: VBoxContainer = %UnlockLocationsList
@onready var add_unlock_location_button: Button = %AddUnlockLocationButton
@onready var unlock_quests_list: VBoxContainer = %UnlockQuestsList
@onready var add_unlock_quest_button: Button = %AddUnlockQuestButton
@onready var relationships_list: VBoxContainer = %RelationshipsList
@onready var add_relationship_button: Button = %AddRelationshipButton

var _suppress_signals: bool = false
## The QuestRewards resource last passed to load_rewards(). build_rewards()
## starts from a copy of it so fields this widget has no UI for (e.g.
## counter_changes, ItemReward.item_resource) are preserved on every edit.
var _loaded_rewards: Resource = null

func _ready() -> void:
	if xp_spin:
		xp_spin.value_changed.connect(_on_value_changed)
	if gold_spin:
		gold_spin.value_changed.connect(_on_value_changed)
	if choice_count_spin:
		choice_count_spin.value_changed.connect(_on_value_changed)
	if add_item_button:
		add_item_button.pressed.connect(_on_add_item)
	if add_choice_item_button:
		add_choice_item_button.pressed.connect(_on_add_choice_item)
	if add_unlock_flag_button:
		add_unlock_flag_button.pressed.connect(_on_add_unlock_flag)
	if add_unlock_location_button:
		add_unlock_location_button.pressed.connect(_on_add_unlock_location)
	if add_unlock_quest_button:
		add_unlock_quest_button.pressed.connect(_on_add_unlock_quest)
	if add_relationship_button:
		add_relationship_button.pressed.connect(_on_add_relationship)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_rewards(rewards: Resource) -> void:
	_suppress_signals = true
	_loaded_rewards = rewards

	# Clear all dynamic lists
	_clear_list(items_list)
	_clear_list(choice_items_list)
	_clear_list(unlock_flags_list)
	_clear_list(unlock_locations_list)
	_clear_list(unlock_quests_list)
	_clear_list(relationships_list)

	if rewards == null:
		if xp_spin:
			xp_spin.value = 0
		if gold_spin:
			gold_spin.value = 0
		if choice_count_spin:
			choice_count_spin.value = 1
		_suppress_signals = false
		return

	if xp_spin:
		xp_spin.value = rewards.get("experience") if rewards.get("experience") != null else 0
	if gold_spin:
		gold_spin.value = rewards.get("gold") if rewards.get("gold") != null else 0
	if choice_count_spin:
		choice_count_spin.value = rewards.get("choice_count") if rewards.get("choice_count") != null else 1

	# Load items
	var items = rewards.get("items")
	if items:
		for item in items:
			_add_item_row(items_list, str(item.get("item_id")), item.get("quantity") if item.get("quantity") != null else 1, item)

	# Load choice items
	var choice_items = rewards.get("choice_items")
	if choice_items:
		for item in choice_items:
			_add_item_row(choice_items_list, str(item.get("item_id")), item.get("quantity") if item.get("quantity") != null else 1, item)

	# Load unlock flags
	var flags = rewards.get("unlock_flags")
	if flags:
		for flag in flags:
			_add_string_row(unlock_flags_list, str(flag))

	# Load unlock locations
	var locations = rewards.get("unlock_locations")
	if locations:
		for loc in locations:
			_add_string_row(unlock_locations_list, str(loc))

	# Load unlock quests
	var quests = rewards.get("unlock_quests")
	if quests:
		for q in quests:
			_add_string_row(unlock_quests_list, str(q))

	# Load relationships
	var rels = rewards.get("relationship_changes")
	if rels and rels is Dictionary:
		for npc_id in rels:
			_add_relationship_row(str(npc_id), rels[npc_id])

	_suppress_signals = false

func build_rewards() -> Resource:
	var rewards_script = load("res://resources/data/quest_rewards.gd")
	if not rewards_script:
		return null

	# Start from a copy of the loaded rewards so every field without a widget
	# (counter_changes, and anything added to QuestRewards later) survives.
	# Collections are deep-copied so the original resource is never mutated;
	# every field with a widget is overwritten below with a fresh value.
	var rewards: Resource
	if _loaded_rewards != null:
		rewards = _loaded_rewards.duplicate(false)
		for prop in rewards.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_STORAGE):
				continue
			var v = rewards.get(prop.name)
			if v is Dictionary or v is Array:
				rewards.set(prop.name, v.duplicate(true))
	else:
		rewards = rewards_script.new()
	rewards.experience = int(xp_spin.value) if xp_spin else 0
	rewards.gold = int(gold_spin.value) if gold_spin else 0
	rewards.choice_count = int(choice_count_spin.value) if choice_count_spin else 1

	# Build items
	var item_reward_class = rewards_script.ItemReward
	# items/choice_items are typed Array[ItemReward]: fill a fresh typed copy
	# (assigning an untyped Array to them fails)
	rewards.items = _typed_like(rewards.items, _build_item_array(items_list, item_reward_class))
	rewards.choice_items = _typed_like(rewards.choice_items, _build_item_array(choice_items_list, item_reward_class))

	# Build unlock arrays
	rewards.unlock_flags = _build_string_array(unlock_flags_list)
	rewards.unlock_locations = _build_string_array(unlock_locations_list)
	rewards.unlock_quests = _build_string_array(unlock_quests_list)

	# Build relationships
	rewards.relationship_changes = _build_relationship_dict()

	return rewards

# ============================================================================
# DYNAMIC ROW HELPERS
# ============================================================================

func _add_item_row(container: VBoxContainer, item_id: String = "", quantity: int = 1, source_item: Resource = null) -> void:
	var row = HBoxContainer.new()
	# Keep the original ItemReward so fields without a widget (item_resource)
	# are carried through when the row is rebuilt.
	if source_item != null:
		row.set_meta("source_item", source_item)
	var id_edit = LineEdit.new()
	id_edit.placeholder_text = "item_id"
	id_edit.text = item_id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(_on_value_changed_text)
	row.add_child(id_edit)

	var qty_spin = SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 999
	qty_spin.value = quantity
	qty_spin.custom_minimum_size = Vector2(70, 0)
	qty_spin.value_changed.connect(_on_value_changed)
	row.add_child(qty_spin)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.pressed.connect(func(): row.queue_free(); _emit_modified())
	row.add_child(remove_btn)

	container.add_child(row)

func _add_string_row(container: VBoxContainer, value: String = "") -> void:
	var row = HBoxContainer.new()
	var edit = LineEdit.new()
	edit.text = value
	edit.placeholder_text = "value"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_value_changed_text)
	row.add_child(edit)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.pressed.connect(func(): row.queue_free(); _emit_modified())
	row.add_child(remove_btn)

	container.add_child(row)

func _add_relationship_row(npc_id: String = "", delta: int = 0) -> void:
	var row = HBoxContainer.new()
	var id_edit = LineEdit.new()
	id_edit.placeholder_text = "npc_id"
	id_edit.text = npc_id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(_on_value_changed_text)
	row.add_child(id_edit)

	var delta_spin = SpinBox.new()
	delta_spin.min_value = -100
	delta_spin.max_value = 100
	delta_spin.value = delta
	delta_spin.custom_minimum_size = Vector2(70, 0)
	delta_spin.value_changed.connect(_on_value_changed)
	row.add_child(delta_spin)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.pressed.connect(func(): row.queue_free(); _emit_modified())
	row.add_child(remove_btn)

	relationships_list.add_child(row)

# ============================================================================
# BUILD HELPERS
# ============================================================================

func _build_item_array(container: VBoxContainer, item_class) -> Array:
	var result = []
	if not container:
		return result
	for child in container.get_children():
		if child is HBoxContainer and child.get_child_count() >= 2:
			var id_edit = child.get_child(0) as LineEdit
			var qty_spin = child.get_child(1) as SpinBox
			if id_edit and id_edit.text.strip_edges() != "":
				var source = child.get_meta("source_item") if child.has_meta("source_item") else null
				var item = source.duplicate(false) if source != null else item_class.new()
				item.item_id = StringName(id_edit.text.strip_edges())
				item.quantity = int(qty_spin.value) if qty_spin else 1
				result.append(item)
	return result

func _typed_like(template: Array, values: Array) -> Array:
	"""A new array with the same element type as template, holding values."""
	var out = template.duplicate()
	out.clear()
	out.append_array(values)
	return out

func _build_string_array(container: VBoxContainer) -> Array[StringName]:
	var result: Array[StringName] = []
	if not container:
		return result
	for child in container.get_children():
		if child is HBoxContainer and child.get_child_count() >= 1:
			var edit = child.get_child(0) as LineEdit
			if edit and edit.text.strip_edges() != "":
				result.append(StringName(edit.text.strip_edges()))
	return result

func _build_relationship_dict() -> Dictionary:
	var result: Dictionary = {}
	if not relationships_list:
		return result
	for child in relationships_list.get_children():
		if child is HBoxContainer and child.get_child_count() >= 2:
			var id_edit = child.get_child(0) as LineEdit
			var delta_spin = child.get_child(1) as SpinBox
			if id_edit and id_edit.text.strip_edges() != "":
				result[StringName(id_edit.text.strip_edges())] = int(delta_spin.value)
	return result

func _clear_list(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

# ============================================================================
# HANDLERS
# ============================================================================

func _on_add_item() -> void:
	_add_item_row(items_list)
	_emit_modified()

func _on_add_choice_item() -> void:
	_add_item_row(choice_items_list)
	_emit_modified()

func _on_add_unlock_flag() -> void:
	_add_string_row(unlock_flags_list)
	_emit_modified()

func _on_add_unlock_location() -> void:
	_add_string_row(unlock_locations_list)
	_emit_modified()

func _on_add_unlock_quest() -> void:
	_add_string_row(unlock_quests_list)
	_emit_modified()

func _on_add_relationship() -> void:
	_add_relationship_row()
	_emit_modified()

func _on_value_changed(_value) -> void:
	_emit_modified()

func _on_value_changed_text(_text: String) -> void:
	_emit_modified()

func _emit_modified() -> void:
	if not _suppress_signals:
		rewards_modified.emit()
