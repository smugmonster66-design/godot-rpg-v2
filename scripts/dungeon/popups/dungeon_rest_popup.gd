# res://scripts/dungeon/popups/dungeon_rest_popup.gd
## Rest site popup. Player adjusts a heal slider and optionally picks
## a temporary DiceAffix buff for the remainder of the run.
##
## Data in:  { "node": DungeonNodeData, "affix_pool": Array[DiceAffix],
##             "run": DungeonRun, "player": Player }
## Result:   { "heal_amount": int, "chosen_affix": DiceAffix or null }
extends DungeonPopupBase

var _player: Player = null
var _affix_pool: Array[DiceAffix] = []
var _chosen_affix: DiceAffix = null
var _heal_amount: int = 0

# ============================================================================
# NODE REFERENCES — match dungeon_rest_popup.tscn paths exactly
# ============================================================================
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var flavor_label: Label = $CenterContainer/Panel/VBox/FlavorLabel
@onready var heal_section: VBoxContainer = $CenterContainer/Panel/VBox/HealSection
@onready var heal_label: Label = $CenterContainer/Panel/VBox/HealSection/HealLabel
@onready var heal_slider: HSlider = $CenterContainer/Panel/VBox/HealSection/HealSlider
@onready var health_preview: Label = $CenterContainer/Panel/VBox/HealSection/HealthPreview
@onready var affix_section: VBoxContainer = $CenterContainer/Panel/VBox/AffixSection
@onready var affix_choices: VBoxContainer = $CenterContainer/Panel/VBox/AffixSection/AffixChoices
@onready var skip_button: Button = $CenterContainer/Panel/VBox/ButtonRow/SkipButton

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	super._ready()
	if heal_slider:
		heal_slider.value_changed.connect(_on_slider_changed)
	if skip_button:
		skip_button.pressed.connect(_on_skip)

# ============================================================================
# ABSTRACT IMPLEMENTATION
# ============================================================================

func show_popup(data: Dictionary) -> void:
	_base_show(data, "rest")
	_player = data.get("player")
	_affix_pool = data.get("affix_pool", [])
	_chosen_affix = null
	_heal_amount = 0

	# --- Heal slider setup ---
	if _player and heal_slider:
		var missing_hp = _player.max_health - _player.health
		if missing_hp <= 0:
			# Full health — hide heal section entirely
			if heal_section: heal_section.hide()
		else:
			if heal_section: heal_section.show()
			heal_slider.min_value = 0
			heal_slider.max_value = missing_hp
			heal_slider.value = missing_hp  # default to full heal
			_on_slider_changed(heal_slider.value)
	elif heal_section:
		heal_section.hide()

	# --- Affix picker setup ---
	# Clear previous choices
	for child in affix_choices.get_children():
		child.queue_free()

	if _affix_pool.size() == 0:
		if affix_section: affix_section.hide()
	else:
		if affix_section: affix_section.show()
		# Offer up to 3 random affixes from the pool
		var shuffled = _affix_pool.duplicate()
		shuffled.shuffle()
		var offer_count = mini(shuffled.size(), 3)
		for i in offer_count:
			var affix: DiceAffix = shuffled[i]
			var btn = Button.new()
			btn.text = affix.display_name if affix.display_name != "" else str(affix)
			btn.toggle_mode = true
			btn.pressed.connect(_on_affix_selected.bind(i, affix, btn))
			affix_choices.add_child(btn)

func _build_result() -> Dictionary:
	return {
		"heal_amount": _heal_amount,
		"chosen_affix": _chosen_affix,
	}

# ============================================================================
# UI CALLBACKS
# ============================================================================

func _on_slider_changed(value: float):
	_heal_amount = int(value)
	if heal_label:
		heal_label.text = "Heal: %d HP" % _heal_amount
	if health_preview and _player:
		var current = _player.health
		var after = mini(current + _heal_amount, _player.max_health)
		health_preview.text = "HP: %d / %d → %d / %d" % [
			current, _player.max_health, after, _player.max_health]

func _on_affix_selected(index: int, affix: DiceAffix, pressed_btn: Button):
	_chosen_affix = affix
	# Untoggle all other buttons so only one is selected
	for child in affix_choices.get_children():
		if child is Button and child != pressed_btn:
			child.button_pressed = false

func _on_skip():
	"""Close without resting — zero heal, no affix."""
	_heal_amount = 0
	_chosen_affix = null
	_on_close()
