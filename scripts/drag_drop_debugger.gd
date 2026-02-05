# res://scripts/debug/drag_drop_debugger.gd
# TEMPORARY DEBUG TOOL - Attach as a child of your CombatScene root
# Prints real-time info about what's under the mouse during drag operations.
# Remove or disable before shipping.
extends Node

const ENABLED: bool = true

var _is_dragging: bool = false
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 0.25  # Check every 250ms during drag

func _ready():
	if not ENABLED:
		set_process(false)
		return
	print("🔬 DragDropDebugger active - will report mouse target during drags")
	set_process(true)

func _process(delta: float):
	if not ENABLED:
		return
	
	# Detect drag state via Input
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _is_dragging:
			_is_dragging = true
			_check_timer = 0.0
			print("🔬 [DragDebug] Mouse down detected - monitoring drop targets...")
		
		_check_timer += delta
		if _check_timer >= CHECK_INTERVAL:
			_check_timer = 0.0
			_report_what_is_under_mouse()
	else:
		if _is_dragging:
			_is_dragging = false
			print("🔬 [DragDebug] Mouse released")

func _report_what_is_under_mouse():
	"""Find and report what Control node is under the mouse cursor"""
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport = get_viewport()
	
	# Method 1: Check viewport's GUI focus
	var gui_focus = viewport.gui_get_focus_owner()
	
	# Method 2: Walk the tree and find Controls under mouse
	var hits: Array[Dictionary] = []
	_find_controls_at_position(get_tree().root, mouse_pos, hits)
	
	print("🔬 [DragDebug] Mouse at %s — %d Controls under cursor:" % [mouse_pos, hits.size()])
	
	for hit in hits:
		var ctrl: Control = hit.ctrl
		var mf_name = _mf(ctrl.mouse_filter)
		var is_action_field = ctrl is ActionField
		var marker = " 🎯" if is_action_field else ""
		var blocking = " ⛔ BLOCKING" if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and not is_action_field else ""
		print("    %s [%s] mf=%s z=%d visible=%s%s%s" % [
			ctrl.name, ctrl.get_class(), mf_name,
			ctrl.z_index, ctrl.visible, marker, blocking
		])
		
		if is_action_field:
			var af = ctrl as ActionField
			print("      → slots=%d, placed=%d, disabled=%s, charges=%s" % [
				af.die_slot_panels.size(), af.placed_dice.size(),
				af.is_disabled, af.has_charges()
			])

func _find_controls_at_position(node: Node, pos: Vector2, results: Array[Dictionary]):
	"""Recursively find all visible Controls that contain the given position"""
	if node is Control:
		var ctrl = node as Control
		if ctrl.visible and ctrl.get_global_rect().has_point(pos):
			results.append({"ctrl": ctrl})
	
	for child in node.get_children():
		_find_controls_at_position(child, pos, results)

func _mf(filter: int) -> String:
	match filter:
		Control.MOUSE_FILTER_STOP: return "STOP"
		Control.MOUSE_FILTER_PASS: return "PASS"
		Control.MOUSE_FILTER_IGNORE: return "IGNORE"
		_: return "?(%d)" % filter
