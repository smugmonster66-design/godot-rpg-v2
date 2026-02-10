# res://scripts/ui/combat/mana_die_selector.gd
# Combat UI panel for pulling mana dice mid-turn.
# Shows element/size cycling, pull button, mana bar, and drag support.
#
# Scene tree expectation (ManaDieSelector.tscn):
#   ManaDieSelector (PanelContainer)
#   ├── VBoxContainer
#   │   ├── ManaBar (ProgressBar)
#   │   ├── ElementRow (HBoxContainer)
#   │   │   ├── PrevElementButton (Button)
#   │   │   ├── ElementLabel (Label)
#   │   │   └── NextElementButton (Button)
#   │   ├── SizeRow (HBoxContainer)
#   │   │   ├── PrevSizeButton (Button)
#   │   │   ├── SizeLabel (Label)
#   │   │   └── NextSizeButton (Button)
#   │   ├── CostLabel (Label)
#   │   └── PullButton (Button)
#
# All nodes are discovered via find_child — no hard-coded NodePaths.
extends PanelContainer
class_name ManaDieSelector

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted after a die is successfully pulled. CombatUI connects this to
## insert the die into the hand and trigger the entrance animation.
signal mana_die_pulled(die: DieResource)

## Emitted when the mana bar value changes (for external pulse effects).
signal mana_changed(current: int, maximum: int)

# ============================================================================
# NODE REFERENCES (discovered in _ready)
# ============================================================================
var mana_bar: ProgressBar = null
var element_label: Label = null
var size_label: Label = null
var cost_label: Label = null
var pull_button: Button = null
var prev_element_button: Button = null
var next_element_button: Button = null
var prev_size_button: Button = null
var next_size_button: Button = null

# ============================================================================
# STATE
# ============================================================================
var mana_pool = null  # ManaPool resource (set via initialize())
var player: Player = null

## Currently selected element index into available_elements
var _element_index: int = 0
## Currently selected size index into available_sizes
var _size_index: int = 0

## Cached arrays from ManaPool — refreshed each time the selector opens or
## after a pull (in case skills unlocked new options mid-combat).
var _available_elements: Array = []
var _available_sizes: Array = []

# ============================================================================
# ELEMENT DISPLAY NAMES
# ============================================================================
const ELEMENT_NAMES: Dictionary = {
	0: "None",       # DieResource.Element.NONE
	1: "Slashing",   # DieResource.Element.SLASHING
	2: "Blunt",      # DieResource.Element.BLUNT
	3: "Piercing",   # DieResource.Element.PIERCING
	4: "Fire",       # DieResource.Element.FIRE
	5: "Ice",        # DieResource.Element.ICE
	6: "Shock",      # DieResource.Element.SHOCK
	7: "Poison",     # DieResource.Element.POISON
	8: "Shadow",     # DieResource.Element.SHADOW
}

const SIZE_NAMES: Dictionary = {
	4: "D4",
	6: "D6",
	8: "D8",
	10: "D10",
	12: "D12",
	20: "D20",
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_connect_signals()
	visible = false  # Hidden until initialize() is called with a valid mana pool
	print("🔮 ManaDieSelector ready")


func _discover_nodes():
	"""Find child nodes by name — no hard-coded NodePaths."""
	mana_bar = find_child("ManaBar", true, false) as ProgressBar
	element_label = find_child("ElementLabel", true, false) as Label
	size_label = find_child("SizeLabel", true, false) as Label
	cost_label = find_child("CostLabel", true, false) as Label
	pull_button = find_child("PullButton", true, false) as Button
	prev_element_button = find_child("PrevElementButton", true, false) as Button
	next_element_button = find_child("NextElementButton", true, false) as Button
	prev_size_button = find_child("PrevSizeButton", true, false) as Button
	next_size_button = find_child("NextSizeButton", true, false) as Button

	# Log discovery results
	var nodes = {
		"ManaBar": mana_bar, "ElementLabel": element_label,
		"SizeLabel": size_label, "CostLabel": cost_label,
		"PullButton": pull_button, "PrevElementButton": prev_element_button,
		"NextElementButton": next_element_button,
		"PrevSizeButton": prev_size_button, "NextSizeButton": next_size_button,
	}
	for node_name in nodes:
		if nodes[node_name]:
			print("  ✅ Found %s" % node_name)
		else:
			push_warning("ManaDieSelector: Missing child node '%s'" % node_name)


func _connect_signals():
	"""Connect button signals."""
	if pull_button and not pull_button.pressed.is_connected(_on_pull_pressed):
		pull_button.pressed.connect(_on_pull_pressed)
	if prev_element_button and not prev_element_button.pressed.is_connected(_on_prev_element):
		prev_element_button.pressed.connect(_on_prev_element)
	if next_element_button and not next_element_button.pressed.is_connected(_on_next_element):
		next_element_button.pressed.connect(_on_next_element)
	if prev_size_button and not prev_size_button.pressed.is_connected(_on_prev_size):
		prev_size_button.pressed.connect(_on_prev_size)
	if next_size_button and not next_size_button.pressed.is_connected(_on_next_size):
		next_size_button.pressed.connect(_on_next_size)


func initialize(p_player: Player):
	"""Initialize with the player. Call from CombatUI.initialize_ui().
	If the player has no mana pool, the selector stays hidden."""
	player = p_player

	if not player or not player.has_method("has_mana_pool") or not player.has_mana_pool():
		visible = false
		mana_pool = null
		print("🔮 ManaDieSelector: Player has no mana pool — hidden")
		return

	mana_pool = player.mana_pool
	visible = true

	# Connect mana_changed from Player for live bar updates
	if player.has_signal("mana_changed") and not player.mana_changed.is_connected(_on_player_mana_changed):
		player.mana_changed.connect(_on_player_mana_changed)

	_refresh_available_options()
	_update_all_displays()
	print("🔮 ManaDieSelector initialized (elements=%d, sizes=%d)" % [
		_available_elements.size(), _available_sizes.size()
	])


# ============================================================================
# CYCLING — ELEMENT
# ============================================================================

func _on_prev_element():
	if _available_elements.is_empty():
		return
	_element_index = (_element_index - 1 + _available_elements.size()) % _available_elements.size()
	_update_all_displays()


func _on_next_element():
	if _available_elements.is_empty():
		return
	_element_index = (_element_index + 1) % _available_elements.size()
	_update_all_displays()


func get_selected_element() -> int:
	"""Return the currently selected DieResource.Element value."""
	if _available_elements.is_empty():
		return 0  # Element.NONE
	return _available_elements[_element_index]


# ============================================================================
# CYCLING — SIZE
# ============================================================================

func _on_prev_size():
	if _available_sizes.is_empty():
		return
	_size_index = (_size_index - 1 + _available_sizes.size()) % _available_sizes.size()
	_update_all_displays()


func _on_next_size():
	if _available_sizes.is_empty():
		return
	_size_index = (_size_index + 1) % _available_sizes.size()
	_update_all_displays()


func get_selected_size() -> int:
	"""Return the currently selected DieResource.DieType int value (4/6/8/…)."""
	if _available_sizes.is_empty():
		return 6  # D6 default
	return _available_sizes[_size_index]


# ============================================================================
# PULL
# ============================================================================

func _on_pull_pressed():
	"""Player pressed Pull — attempt to create a mana die and emit signal."""
	if not mana_pool:
		push_warning("ManaDieSelector: No mana pool!")
		return

	var element: int = get_selected_element()
	var die_size: int = get_selected_size()

	# Query cost from ManaPool
	var cost: int = _get_pull_cost(element, die_size)

	# Check if player can afford it
	if not player or player.current_mana < cost:
		print("🔮 ManaDieSelector: Not enough mana (have %d, need %d)" % [
			player.current_mana if player else 0, cost
		])
		_flash_cost_label_red()
		return

	# Consume mana
	player.consume_mana(cost)

	# Ask ManaPool to create the die
	var new_die: DieResource = null
	if mana_pool.has_method("create_mana_die"):
		new_die = mana_pool.create_mana_die(element, die_size)
	else:
		# Fallback: construct a basic die manually
		new_die = DieResource.new(die_size, "mana_pull")
		new_die.element = element
		new_die.display_name = "%s Mana D%d" % [ELEMENT_NAMES.get(element, ""), die_size]
		new_die.roll()

	if not new_die:
		push_error("ManaDieSelector: create_mana_die returned null!")
		# Refund mana
		player.restore_mana(cost)
		return

	print("🔮 Pulled mana die: %s (cost %d mana)" % [new_die.display_name, cost])

	# Refresh options (pull may have changed available elements/sizes)
	_refresh_available_options()
	_update_all_displays()

	mana_die_pulled.emit(new_die)


# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_all_displays():
	"""Refresh every label, bar, and button state."""
	_update_mana_bar()
	_update_element_display()
	_update_size_display()
	_update_cost_display()
	_update_pull_button_state()


func _update_mana_bar():
	if not mana_bar or not player:
		return
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.current_mana


func _update_element_display():
	if not element_label:
		return
	var elem = get_selected_element()
	element_label.text = ELEMENT_NAMES.get(elem, "Unknown")

	# Disable cycling buttons if only one option
	var single = _available_elements.size() <= 1
	if prev_element_button:
		prev_element_button.disabled = single
	if next_element_button:
		next_element_button.disabled = single


func _update_size_display():
	if not size_label:
		return
	var sz = get_selected_size()
	size_label.text = SIZE_NAMES.get(sz, "D%d" % sz)

	var single = _available_sizes.size() <= 1
	if prev_size_button:
		prev_size_button.disabled = single
	if next_size_button:
		next_size_button.disabled = single


func _update_cost_display():
	if not cost_label:
		return
	var cost = _get_pull_cost(get_selected_element(), get_selected_size())
	cost_label.text = "Cost: %d Mana" % cost


func _update_pull_button_state():
	if not pull_button or not player:
		return
	var cost = _get_pull_cost(get_selected_element(), get_selected_size())
	pull_button.disabled = player.current_mana < cost
	pull_button.text = "Pull Die (%d)" % cost


# ============================================================================
# MANA BAR PULSE (called externally for mid-turn mana gains)
# ============================================================================

func pulse_mana_bar():
	"""Quick scale-pulse the mana bar to indicate a mid-turn mana gain."""
	if not mana_bar:
		return
	var tween = create_tween()
	tween.tween_property(mana_bar, "scale", Vector2(1.08, 1.15), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(mana_bar, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_IN_OUT)


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_player_mana_changed(current: int, maximum: int):
	"""Live update from Player.mana_changed signal."""
	_update_mana_bar()
	_update_pull_button_state()
	_update_cost_display()
	mana_changed.emit(current, maximum)


# ============================================================================
# HELPERS
# ============================================================================

func _refresh_available_options():
	"""Re-query the ManaPool for available elements and sizes."""
	if not mana_pool:
		_available_elements = [0]  # NONE only
		_available_sizes = [6]     # D6 only
		return

	if mana_pool.has_method("get_available_elements"):
		_available_elements = mana_pool.get_available_elements()
	else:
		_available_elements = [0]  # Fallback

	if mana_pool.has_method("get_available_sizes"):
		_available_sizes = mana_pool.get_available_sizes()
	else:
		_available_sizes = [4, 6]  # Fallback D4/D6

	# Clamp indices
	_element_index = clampi(_element_index, 0, maxi(0, _available_elements.size() - 1))
	_size_index = clampi(_size_index, 0, maxi(0, _available_sizes.size() - 1))


func _get_pull_cost(element: int, die_size: int) -> int:
	"""Ask ManaPool for the pull cost, with fallback calculation."""
	if mana_pool and mana_pool.has_method("get_pull_cost"):
		return mana_pool.get_pull_cost(element, die_size)
	# Fallback: base cost = die_size / 2, elemental dice cost 50% more
	var base_cost: int = int(die_size / 2.0)
	if element != 0:  # Not NONE
		base_cost = int(base_cost * 1.5)
	return maxi(1, base_cost)


func _flash_cost_label_red():
	"""Quick red flash on cost label when player can't afford the pull."""
	if not cost_label:
		return
	var original_color = cost_label.modulate
	cost_label.modulate = Color(1.5, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(cost_label, "modulate", original_color, 0.4) \
		.set_ease(Tween.EASE_OUT)
