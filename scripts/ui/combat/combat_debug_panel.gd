# res://scripts/ui/combat/combat_debug_panel.gd
# Debug overlay that shows a scrolling, color-coded combat event log.
# Connects to CombatEventBus.game_event and formats each CombatEvent
# into readable "WHO -> WHAT -> WHOM = RESULT" lines.
#
# Toggle: F12 (debug builds only)
# Architecture: Pure listener — adds no new data, just consumes the event bus.
# Styling: Inherits from ThemeManager + base_theme.tres. No hardcoded colors.
#
# Usage:
#   - Add as child of CombatManager or CombatUI
#   - Call connect_to_bus(event_bus) after CombatEventBus is created
#   - Panel auto-hides in non-debug builds
extends CanvasLayer
class_name CombatDebugPanel

# ============================================================================
# CONFIGURATION
# ============================================================================

## Maximum log lines before oldest are trimmed
@export var max_lines: int = 300

## Panel width in pixels
@export var panel_width: int = 420

## Background opacity (0.0 - 1.0)
@export var bg_opacity: float = 0.85

## Toggle hotkey (only in debug builds)
@export var toggle_key: Key = KEY_F12

# ============================================================================
# FILTER FLAGS
# ============================================================================

enum Filter {
	ALL        = 0xFF,
	ACTIONS    = 1 << 0,
	DAMAGE     = 1 << 1,
	DICE       = 1 << 2,
	STATUS     = 1 << 3,
	RESOURCES  = 1 << 4,
	LIFECYCLE  = 1 << 5,
}

var _active_filters: int = Filter.ALL

# ============================================================================
# NODE REFERENCES
# ============================================================================

var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _filter_bar: HBoxContainer = null
var _copy_button: Button = null
var _clear_button: Button = null
var _close_button: Button = null

var _event_bus: CombatEventBus = null
var _visible: bool = false
var _auto_scroll: bool = true
var _line_count: int = 0

## Plain text mirror for clipboard copy
var _plain_log: PackedStringArray = PackedStringArray()

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	layer = 200  # Above everything
	_build_ui()
	_panel.visible = false
	
	# Only show in debug builds
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED


func _build_ui():
	# --- Root panel ---
	_panel = PanelContainer.new()
	_panel.name = "DebugPanelRoot"
	
	# Inherit base theme so Buttons/Labels/ScrollBars pick up project styles
	if ThemeManager and ThemeManager.theme:
		_panel.theme = ThemeManager.theme
	
	# Anchor to right side of screen
	# Full screen overlay
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Panel background via ThemeManager._flat_box
	var bg_color = Color(
		ThemeManager.PALETTE.bg_darkest.r,
		ThemeManager.PALETTE.bg_darkest.g,
		ThemeManager.PALETTE.bg_darkest.b,
		bg_opacity)
	var style = ThemeManager._flat_box(bg_color, ThemeManager.PALETTE.border_subtle, 6, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(root_vbox)
	
	# --- Header bar ---
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "Combat Log"
	title.add_theme_color_override("font_color", ThemeManager.PALETTE.text_secondary)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	_copy_button = Button.new()
	_copy_button.text = "Copy"
	_copy_button.custom_minimum_size = Vector2(50, 0)
	_copy_button.pressed.connect(_on_copy_pressed)
	_copy_button.tooltip_text = "Copy log to clipboard"
	header.add_child(_copy_button)
	
	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.custom_minimum_size = Vector2(50, 0)
	_clear_button.pressed.connect(_on_clear_pressed)
	header.add_child(_clear_button)
	
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(28, 0)
	_close_button.pressed.connect(func(): toggle_visible())
	header.add_child(_close_button)
	
	# --- Filter bar ---
	_filter_bar = HBoxContainer.new()
	_filter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_filter_bar)
	
	_add_filter_toggle("All", Filter.ALL)
	_add_filter_toggle("Act", Filter.ACTIONS)
	_add_filter_toggle("Dmg", Filter.DAMAGE)
	_add_filter_toggle("Dice", Filter.DICE)
	_add_filter_toggle("Sts", Filter.STATUS)
	_add_filter_toggle("Res", Filter.RESOURCES)
	_add_filter_toggle("Life", Filter.LIFECYCLE)
	
	# --- Separator ---
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	root_vbox.add_child(sep)
	
	# --- Scroll area ---
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 1)
	_scroll.add_child(_vbox)
	
	# Detect manual scroll to disable auto-scroll
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	
	add_child(_panel)


func _add_filter_toggle(label_text: String, filter_flag: int):
	var btn = Button.new()
	btn.text = label_text
	btn.toggle_mode = true
	btn.button_pressed = true
	btn.custom_minimum_size = Vector2(36, 0)
	btn.toggled.connect(_on_filter_toggled.bind(filter_flag))
	_filter_bar.add_child(btn)


# ============================================================================
# PALETTE HELPERS — resolve colors from ThemeManager at runtime
# ============================================================================

func _color_action_player() -> Color:
	return ThemeManager.PALETTE.info

func _color_action_enemy() -> Color:
	return ThemeManager.PALETTE.danger

func _color_damage() -> Color:
	return ThemeManager.PALETTE.danger

func _color_heal() -> Color:
	return ThemeManager.PALETTE.success

func _color_status() -> Color:
	return ThemeManager.PALETTE.shock

func _color_dice() -> Color:
	return ThemeManager.PALETTE.warning

func _color_mana() -> Color:
	return ThemeManager.PALETTE.mana

func _color_shield() -> Color:
	return ThemeManager.PALETTE.barrier

func _color_proc() -> Color:
	return ThemeManager.PALETTE.shadow

func _color_lifecycle() -> Color:
	return ThemeManager.PALETTE.text_muted

func _color_death() -> Color:
	return ThemeManager.PALETTE.danger.lightened(0.2)

func _color_crit() -> Color:
	return ThemeManager.PALETTE.warning

func _color_divider() -> Color:
	return ThemeManager.PALETTE.text_muted

func _color_for_element(element_str: String) -> Color:
	"""Use ThemeManager's element color lookup for damage type coloring."""
	if element_str == "":
		return _color_damage()
	return ThemeManager.get_element_color(element_str)


# ============================================================================
# PUBLIC API
# ============================================================================

func connect_to_bus(event_bus: CombatEventBus) -> void:
	"""Connect to a CombatEventBus instance. Call after bus is created."""
	if _event_bus and _event_bus.game_event.is_connected(_on_game_event):
		_event_bus.game_event.disconnect(_on_game_event)
	
	_event_bus = event_bus
	_event_bus.game_event.connect(_on_game_event)
	_add_line(
		"[color=#%s]-- Connected to CombatEventBus --[/color]" % _color_lifecycle().to_html(false),
		"-- Connected to CombatEventBus --")
	print("  Debug Panel: Connected to CombatEventBus")


func disconnect_from_bus() -> void:
	"""Disconnect from the event bus. Call on combat end."""
	if _event_bus and _event_bus.game_event.is_connected(_on_game_event):
		_event_bus.game_event.disconnect(_on_game_event)
	_event_bus = null


func toggle_visible() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_auto_scroll = true
		_scroll_to_bottom()


func clear_log() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_line_count = 0
	_plain_log.clear()


# ============================================================================
# INPUT
# ============================================================================

func _unhandled_key_input(event: InputEvent):
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			toggle_visible()
			get_viewport().set_input_as_handled()


# ============================================================================
# EVENT HANDLER — The core translation layer
# ============================================================================

func _on_game_event(event: CombatEvent) -> void:
	var type = event.type
	var vals = event.values
	var tag = event.source_tag
	
	match type:
		# -- LIFECYCLE --
		CombatEvent.Type.COMBAT_STARTED:
			_add_divider("COMBAT START")
		
		CombatEvent.Type.COMBAT_ENDED:
			var won = vals.get("player_won", false)
			var result_text = "VICTORY" if won else "DEFEAT"
			_add_divider(result_text)
		
		CombatEvent.Type.ROUND_STARTED:
			var rnd = vals.get("round_number", 0)
			_add_divider("ROUND %d" % rnd)
		
		CombatEvent.Type.TURN_STARTED:
			var is_player = vals.get("is_player", false)
			var name_str = _node_name(event.target_node)
			var turn_label = "PLAYER" if is_player else name_str
			_add_formatted(
				"%s's Turn" % turn_label,
				_color_lifecycle(), Filter.LIFECYCLE, true
			)
		
		# -- ACTIONS --
		CombatEvent.Type.ACTION_CONFIRMED:
			# Lightweight marker -- the richer ACTION_EXECUTED follows
			pass
		
		CombatEvent.Type.ACTION_EXECUTED:
			var action_name = vals.get("action_name", "???")
			var source_name = _node_name(event.source_node)
			var target_names: Array = vals.get("target_names", [])
			var dice_vals: Array = vals.get("dice_values", [])
			var dice_count = vals.get("dice_count", 0)
			
			var target_str = ", ".join(target_names) if target_names.size() > 0 else "---"
			var dice_str = ""
			if dice_count > 0:
				var val_strs: Array = []
				for v in dice_vals:
					val_strs.append(str(v))
				dice_str = " [%s]" % "+".join(val_strs)
			
			var is_player = _is_player_node(event.source_node)
			var color = _color_action_player() if is_player else _color_action_enemy()
			_add_formatted(
				"%s -> %s -> %s%s" % [source_name, action_name, target_str, dice_str],
				color, Filter.ACTIONS
			)
		
		# -- DAMAGE --
		CombatEvent.Type.DAMAGE_DEALT:
			var amount = vals.get("amount", 0)
			var element = vals.get("element", "")
			var is_crit = vals.get("is_crit", false)
			var target_name = _node_name(event.target_node)
			
			var elem_str = " %s" % element if element != "" else ""
			var crit_str = " CRIT!" if is_crit else ""
			var tag_str = " [%s]" % tag if tag != "" else ""
			
			var color = _color_crit() if is_crit else _color_for_element(element)
			_add_formatted(
				"  %d%s damage -> %s%s%s" % [amount, elem_str, target_name, crit_str, tag_str],
				color, Filter.DAMAGE
			)
		
		CombatEvent.Type.CRIT_LANDED:
			# Already handled inline with DAMAGE_DEALT via is_crit flag
			pass
		
		# -- HEALING --
		CombatEvent.Type.HEAL_APPLIED:
			var amount = vals.get("amount", 0)
			var target_name = _node_name(event.target_node)
			_add_formatted(
				"  +%d heal -> %s" % [amount, target_name],
				_color_heal(), Filter.DAMAGE
			)
		
		# -- STATUS --
		CombatEvent.Type.STATUS_APPLIED:
			var status_name = vals.get("status_name", "???")
			var stacks = vals.get("stacks", 1)
			var target_name = _node_name(event.target_node)
			_add_formatted(
				"  +%dx %s -> %s" % [stacks, status_name, target_name],
				ThemeManager.get_status_color(status_name), Filter.STATUS
			)
		
		CombatEvent.Type.STATUS_TICKED:
			var status_name = vals.get("status_name", "???")
			var tick_dmg = vals.get("tick_damage", 0)
			var element = vals.get("element", "")
			var target_name = _node_name(event.target_node)
			var elem_str = " %s" % element if element != "" else ""
			var color = ThemeManager.get_status_color(status_name)
			if tick_dmg > 0:
				_add_formatted(
					"  %s tick: %d%s -> %s" % [status_name, tick_dmg, elem_str, target_name],
					color, Filter.STATUS
				)
			else:
				_add_formatted(
					"  %s tick -> %s" % [status_name, target_name],
					color, Filter.STATUS
				)
		
		CombatEvent.Type.STATUS_REMOVED:
			var status_name = vals.get("status_name", "???")
			var target_name = _node_name(event.target_node)
			_add_formatted(
				"  -%s expired on %s" % [status_name, target_name],
				ThemeManager.get_status_color(status_name), Filter.STATUS
			)
		
		CombatEvent.Type.STATUS_STACKS_CHANGED:
			var status_name = vals.get("status_name", "???")
			var target_name = _node_name(event.target_node)
			var old_stacks = vals.get("old_stacks", 0)
			var new_stacks = vals.get("new_stacks", 0)
			_add_formatted(
				"  %s stacks %d->%d on %s" % [status_name, old_stacks, new_stacks, target_name],
				ThemeManager.get_status_color(status_name), Filter.STATUS
			)
		
		# -- DICE --
		CombatEvent.Type.DIE_VALUE_CHANGED:
			var old_val = vals.get("old", 0)
			var new_val = vals.get("new", 0)
			var delta = vals.get("delta", 0)
			var sign_str = "+" if delta > 0 else ""
			var tag_str = " (%s)" % tag if tag != "" else ""
			_add_formatted(
				"  Die %d->%d (%s%d)%s" % [old_val, new_val, sign_str, delta, tag_str],
				_color_dice(), Filter.DICE
			)
		
		CombatEvent.Type.DIE_CONSUMED:
			_add_formatted("  Die consumed", _color_dice(), Filter.DICE)
		
		CombatEvent.Type.DIE_CREATED:
			var tag_str = " (%s)" % tag if tag != "" else ""
			_add_formatted(
				"  Die created%s" % tag_str,
				_color_dice(), Filter.DICE
			)
		
		CombatEvent.Type.DIE_LOCKED:
			_add_formatted("  Die locked", _color_dice(), Filter.DICE)
		
		CombatEvent.Type.DIE_UNLOCKED:
			_add_formatted("  Die unlocked", _color_dice(), Filter.DICE)
		
		CombatEvent.Type.DIE_DESTROYED:
			_add_formatted("  Die DESTROYED", _color_death(), Filter.DICE)
		
		CombatEvent.Type.DIE_ROLLED:
			pass  # Too noisy -- skip unless filters are narrow
		
		# -- SHIELDS --
		CombatEvent.Type.SHIELD_GAINED:
			var amount = vals.get("amount", 0)
			var target_name = _node_name(event.target_node)
			_add_formatted(
				"  +%d shield -> %s" % [amount, target_name],
				_color_shield(), Filter.RESOURCES
			)
		
		CombatEvent.Type.SHIELD_BROKEN:
			var target_name = _node_name(event.target_node)
			_add_formatted(
				"  Shield BROKEN on %s" % target_name,
				_color_shield(), Filter.RESOURCES
			)
		
		CombatEvent.Type.SHIELD_CONSUMED:
			pass  # Granular -- skip to reduce noise
		
		# -- MANA --
		CombatEvent.Type.MANA_CHANGED:
			var old_val = vals.get("old", 0)
			var new_val = vals.get("new", 0)
			var delta = vals.get("delta", 0)
			var sign_str = "+" if delta > 0 else ""
			_add_formatted(
				"  Mana %d->%d (%s%d)" % [old_val, new_val, sign_str, delta],
				_color_mana(), Filter.RESOURCES
			)
		
		CombatEvent.Type.MANA_DEPLETED:
			_add_formatted("  Mana DEPLETED", _color_mana(), Filter.RESOURCES)
		
		CombatEvent.Type.CHARGE_USED:
			_add_formatted("  Charge used", _color_mana(), Filter.RESOURCES)
		
		CombatEvent.Type.CHARGE_RESTORED:
			_add_formatted("  Charge restored", _color_mana(), Filter.RESOURCES)
		
		# -- COMBATANT EVENTS --
		CombatEvent.Type.ENEMY_DIED:
			var enemy_name = vals.get("enemy_name", "Enemy")
			_add_formatted(
				"  ** %s DIED **" % enemy_name,
				_color_death(), Filter.LIFECYCLE
			)
		
		CombatEvent.Type.PLAYER_DIED:
			_add_formatted(
				"  ** PLAYER DIED **",
				_color_death(), Filter.LIFECYCLE
			)
		
		CombatEvent.Type.ENEMY_SPAWNED:
			var enemy_name = vals.get("enemy_name", "Enemy")
			_add_formatted(
				"  %s spawned" % enemy_name,
				_color_lifecycle(), Filter.LIFECYCLE
			)
		
		# -- AFFIX / PROC --
		CombatEvent.Type.AFFIX_TRIGGERED:
			var affix_name = vals.get("affix_name", tag)
			_add_formatted(
				"  Proc: %s" % affix_name,
				_color_proc(), Filter.ACTIONS
			)
		
		CombatEvent.Type.THRESHOLD_REACHED:
			var status_name = vals.get("status_name", "???")
			var threshold = vals.get("threshold", 0)
			_add_formatted(
				"  Threshold: %s reached %d stacks" % [status_name, threshold],
				_color_proc(), Filter.STATUS
			)
		
		# -- SPECIAL --
		CombatEvent.Type.ELEMENT_COMBO:
			var combo_name = vals.get("combo_name", "combo")
			_add_formatted(
				"  Element combo: %s" % combo_name,
				_color_proc(), Filter.ACTIONS
			)
		
		CombatEvent.Type.BATTLEFIELD_EFFECT:
			var effect_name = vals.get("effect_name", "effect")
			_add_formatted(
				"  Battlefield: %s" % effect_name,
				_color_proc(), Filter.ACTIONS
			)
		
		_:
			# Catch-all for unhandled event types
			var type_name = CombatEvent.Type.keys()[type] if type < CombatEvent.Type.size() else "UNKNOWN"
			_add_formatted(
				"  [%s] %s" % [type_name, str(vals).left(80)],
				_color_lifecycle(), Filter.LIFECYCLE
			)


# ============================================================================
# LINE RENDERING
# ============================================================================

func _add_formatted(text: String, color: Color, filter: int, bold: bool = false) -> void:
	"""Add a color-coded line, respecting active filters."""
	if filter != Filter.ALL and not (_active_filters & filter):
		return
	
	var bbcode: String
	if bold:
		bbcode = "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), text]
	else:
		bbcode = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	
	_add_line(bbcode, text)


func _add_divider(label_text: String) -> void:
	"""Add a prominent divider line."""
	var bar = "---"
	var text = "%s %s %s" % [bar, label_text, bar]
	var bbcode = "[color=#%s][b]%s[/b][/color]" % [_color_divider().to_html(false), text]
	_add_line(bbcode, text)


func _add_line(bbcode: String, plain: String) -> void:
	"""Add a BBCode-formatted line to the log."""
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.text = bbcode
	# Let theme handle font/size -- no manual overrides
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	
	_vbox.add_child(rtl)
	_line_count += 1
	_plain_log.append(plain)
	
	# Trim oldest lines if over max
	while _line_count > max_lines:
		var oldest = _vbox.get_child(0)
		if oldest:
			oldest.queue_free()
			_line_count -= 1
	while _plain_log.size() > max_lines:
		_plain_log.remove_at(0)
	
	# Auto-scroll to bottom
	if _auto_scroll:
		call_deferred("_scroll_to_bottom")


func _scroll_to_bottom():
	if _scroll:
		var vbar = _scroll.get_v_scroll_bar()
		vbar.value = vbar.max_value


# ============================================================================
# HELPERS
# ============================================================================

func _node_name(node: Node) -> String:
	"""Extract a readable name from a combatant node."""
	if not node or not is_instance_valid(node):
		return "???"
	if "combatant_name" in node and node.combatant_name != "":
		return node.combatant_name
	return node.name


func _is_player_node(node: Node) -> bool:
	"""Check if a node is the player combatant."""
	if not node or not is_instance_valid(node):
		return false
	if "is_player_controlled" in node:
		return node.is_player_controlled
	var cm = get_tree().get_first_node_in_group("combat_manager")
	if cm and "player_combatant" in cm:
		return node == cm.player_combatant
	return false


# ============================================================================
# CALLBACKS
# ============================================================================

func _on_filter_toggled(toggled: bool, filter_flag: int):
	if filter_flag == Filter.ALL:
		if toggled:
			_active_filters = Filter.ALL
		else:
			_active_filters = 0
		for child in _filter_bar.get_children():
			if child is Button and child.toggle_mode:
				child.set_pressed_no_signal(toggled)
	else:
		if toggled:
			_active_filters = _active_filters | filter_flag
		else:
			_active_filters = _active_filters & ~filter_flag


func _on_scroll_changed(_value: float):
	"""Detect if user scrolled away from bottom -- pause auto-scroll."""
	if not _scroll:
		return
	var vbar = _scroll.get_v_scroll_bar()
	_auto_scroll = (vbar.value >= vbar.max_value - vbar.page - 30)


func _on_copy_pressed():
	"""Copy the full plain-text log to clipboard."""
	var text = "\n".join(_plain_log)
	DisplayServer.clipboard_set(text)
	_copy_button.text = "Done!"
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(_copy_button):
			_copy_button.text = "Copy"
	)


func _on_clear_pressed():
	clear_log()
