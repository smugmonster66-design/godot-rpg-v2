# res://scripts/ui/map/map_editor_toolbar.gd
# Floating toolbar for the in-game map editor.
# Built entirely in GDScript — no .tscn needed.
# Add to a CanvasLayer so it stays fixed while the map pans/zooms.
# Uses an HFlowContainer so buttons wrap when the toolbar would exceed viewport width.
extends PanelContainer
class_name MapEditorToolbar

signal add_node_mode_changed(active: bool)
signal connect_mode_changed(active: bool)
signal decor_mode_changed(active: bool)
signal lighting_mode_changed(active: bool)
signal save_requested
signal discard_requested
signal exit_edit_requested

var _btn_add_node: Button = null
var _btn_connect:  Button = null
var _btn_decor:    Button = null
var _btn_lighting: Button = null
var _btn_save:     Button = null
var _is_dirty:     bool   = false
var _tool_buttons: Array[Button] = []   # all toggle buttons for mutual exclusion

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_build_ui()
	mouse_filter = MOUSE_FILTER_STOP
	resized.connect(_reposition)
	get_tree().root.size_changed.connect(_reposition)
	_reposition.call_deferred()

func _reposition() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Clamp width so the toolbar never exceeds viewport width (minus margin).
	# HFlowContainer will wrap buttons that don't fit.
	var max_width: float = vp_size.x - 12.0
	size.x = minf(size.x, max_width)
	position = Vector2((vp_size.x - size.x) * 0.5, 6.0)

func _build_ui() -> void:
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	add_child(flow)

	# Title label
	var title := Label.new()
	title.text = "  MAP EDITOR  "
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	flow.add_child(title)

	flow.add_child(_sep())

	# ── Tool toggles ──────────────────────────────────────────────────────
	_btn_add_node = _make_toggle("+ Node")
	_btn_add_node.toggled.connect(func(on: bool) -> void:
		if on: _deactivate_others(_btn_add_node)
		add_node_mode_changed.emit(on)
	)
	flow.add_child(_btn_add_node)

	_btn_connect = _make_toggle("Connect")
	_btn_connect.toggled.connect(func(on: bool) -> void:
		if on: _deactivate_others(_btn_connect)
		connect_mode_changed.emit(on)
	)
	flow.add_child(_btn_connect)

	_btn_decor = _make_toggle("Decor")
	_btn_decor.toggled.connect(func(on: bool) -> void:
		if on: _deactivate_others(_btn_decor)
		decor_mode_changed.emit(on)
	)
	flow.add_child(_btn_decor)

	_btn_lighting = _make_toggle("Lighting")
	_btn_lighting.toggled.connect(func(on: bool) -> void:
		if on: _deactivate_others(_btn_lighting)
		lighting_mode_changed.emit(on)
	)
	flow.add_child(_btn_lighting)

	_tool_buttons = [_btn_add_node, _btn_connect, _btn_decor, _btn_lighting]

	flow.add_child(_sep())

	# ── Actions ────────────────────────────────────────────────────────────
	_btn_save = Button.new()
	_btn_save.text = "Save All"
	_btn_save.pressed.connect(func() -> void: save_requested.emit())
	flow.add_child(_btn_save)

	var btn_discard := Button.new()
	btn_discard.text = "Discard"
	btn_discard.pressed.connect(func() -> void: discard_requested.emit())
	flow.add_child(btn_discard)

	flow.add_child(_sep())

	var btn_exit := Button.new()
	btn_exit.text = "Exit Edit"
	btn_exit.pressed.connect(func() -> void: exit_edit_requested.emit())
	flow.add_child(btn_exit)

# ============================================================================
# PUBLIC API
# ============================================================================

func deactivate_tools() -> void:
	for btn in _tool_buttons:
		if btn:
			btn.set_pressed_no_signal(false)

func mark_dirty() -> void:
	_is_dirty = true
	if _btn_save:
		_btn_save.text = "Save All *"

func mark_clean() -> void:
	_is_dirty = false
	if _btn_save:
		_btn_save.text = "Save All"

# ============================================================================
# HELPERS
# ============================================================================

func _deactivate_others(active: Button) -> void:
	for btn in _tool_buttons:
		if btn != active and btn:
			btn.set_pressed_no_signal(false)

func _sep() -> Control:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(6.0, 0.0)
	return s

func _make_toggle(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	return b
