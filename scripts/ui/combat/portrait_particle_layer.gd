# res://scripts/ui/combat/portrait_particle_layer.gd
# Manages status-effect particle scenes overlaid on a combatant portrait.
#
# Attach to a Control node that is a full-rect child of the portrait container.
# Call bind_tracker(tracker) when a combatant is assigned to the portrait.
#
# Two particle tracks per status:
#   apply_particle_scene  — one-shot burst on application
#   active_particle_scene — looping ambient while the status is alive
#
# Node2D-based particle scenes (GPUParticles2D, CPUParticles2D) are positioned
# at the layer's center. Control-based scenes are anchored full-rect.
extends Control
class_name PortraitParticleLayer

# ============================================================================
# CONSTANTS
# ============================================================================

## Duration of the fade-out tween when an active particle is removed.
const FADE_OUT_DURATION: float = 0.4

# ============================================================================
# STATE
# ============================================================================

## Active looping particle nodes keyed by status_id.
var _active_loops: Dictionary = {}

## The bound StatusTracker (kept as a weak reference via is_instance_valid).
var _tracker: StatusTracker = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

# ============================================================================
# PUBLIC API
# ============================================================================

func bind_tracker(tracker: StatusTracker) -> void:
	_unbind()
	if not tracker:
		push_warning("PortraitParticleLayer: bind_tracker called with null tracker")
		return
	_tracker = tracker
	_tracker.status_applied.connect(_on_status_applied)
	_tracker.status_removed.connect(_on_status_removed)
	print("PortraitParticleLayer [%s]: bound to tracker %s" % [name, tracker])

func unbind() -> void:
	"""Disconnect from the current tracker and clear all active particles."""
	_unbind()
	_clear_all_loops()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_status_applied(status_id: String, instance: Dictionary) -> void:
	print("PortraitParticleLayer [%s]: _on_status_applied fired for '%s'" % [name, status_id])
	var affix: StatusAffix = instance.get("status_affix")
	if not affix:
		print("  -> affix is NULL")
		return
	print("  -> apply_particle_scene: %s" % affix.apply_particle_scene)
	print("  -> active_particle_scene: %s" % affix.active_particle_scene)
	print("  -> layer size: %s" % size)

	# --- One-shot apply burst ---
	if affix.apply_particle_scene:
		_spawn_oneshot(affix.apply_particle_scene)

	# --- Looping ambient (one instance per status_id) ---
	if affix.active_particle_scene and not _active_loops.has(status_id):
		var loop_node = _spawn_loop(affix.active_particle_scene)
		if loop_node:
			_active_loops[status_id] = loop_node

func _on_status_removed(status_id: String) -> void:
	if not _active_loops.has(status_id):
		return
	var node: Node = _active_loops[status_id]
	_active_loops.erase(status_id)
	if is_instance_valid(node):
		_fade_and_free(node)

# ============================================================================
# SPAWN HELPERS
# ============================================================================

func _spawn_oneshot(scene: PackedScene) -> void:
	var node = scene.instantiate()
	add_child(node)
	_center_node(node)

	# --- Priority 1: CombatEffectBase family ---
	if node.has_signal("effect_finished"):
		node.effect_finished.connect(node.queue_free, CONNECT_ONE_SHOT)
		if node.has_method("play"):
			print("PortraitParticleLayer: calling play() on %s (type: %s)" % [node.name, node.get_class()])
			node.play()
			print("PortraitParticleLayer: play() returned")
		return

	# --- Priority 2: Generic "finished" signal ---
	if node.has_signal("finished"):
		node.finished.connect(node.queue_free, CONNECT_ONE_SHOT)
		if node.has_method("play"):
			node.play()
		return

	# --- Priority 3: Bare GPU/CPU particle root ---
	if node is GPUParticles2D:
		var p := node as GPUParticles2D
		p.one_shot = true
		p.emitting = true
		await get_tree().create_timer(p.lifetime + 0.1).timeout
		if is_instance_valid(node):
			node.queue_free()
		return

	if node is CPUParticles2D:
		var p := node as CPUParticles2D
		p.one_shot = true
		p.emitting = true
		await get_tree().create_timer(p.lifetime + 0.1).timeout
		if is_instance_valid(node):
			node.queue_free()
		return

	# --- Priority 4: Safety fallback ---
	if node.has_method("play"):
		node.play()
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(node):
		node.queue_free()

func _spawn_loop(scene: PackedScene) -> Node:
	var node = scene.instantiate()
	add_child(node)
	_center_node(node)

	if node is GPUParticles2D:
		var p := node as GPUParticles2D
		p.one_shot = false
		p.emitting = true
	elif node is CPUParticles2D:
		var p := node as CPUParticles2D
		p.one_shot = false
		p.emitting = true
	elif node.has_method("play"):
		# CombatEffectBase subclasses and custom scenes with a play() entry point.
		# Note: looping scenes should set auto_free = false if extending CombatEffectBase.
		node.play()

	return node

func _fade_and_free(node: Node) -> void:
	"""Fade out a node's modulate alpha then free it."""
	if not is_instance_valid(node):
		return
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(node.queue_free)

func _center_node(node: Node) -> void:
	if node is Control:
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif node is Node2D:
		var ref: Control = null
		var p: Node = get_parent()
		while p != null:
			if p is Control and (p as Control).size.length_squared() > 0.0:
				ref = p as Control
				break
			p = p.get_parent()
		if ref:
			var target_pos = ref.global_position + ref.size * 0.5
			node.global_position = target_pos
			print("PortraitParticleLayer: centering Node2D at %s (from ancestor '%s' size=%s gpos=%s)" % [target_pos, ref.name, ref.size, ref.global_position])
		else:
			push_warning("PortraitParticleLayer: could not find sized ancestor for Node2D centering")

# ============================================================================
# CLEANUP
# ============================================================================

func _unbind() -> void:
	if not is_instance_valid(_tracker):
		_tracker = null
		return
	if _tracker.status_applied.is_connected(_on_status_applied):
		_tracker.status_applied.disconnect(_on_status_applied)
	if _tracker.status_removed.is_connected(_on_status_removed):
		_tracker.status_removed.disconnect(_on_status_removed)
	_tracker = null

func _clear_all_loops() -> void:
	for node in _active_loops.values():
		if is_instance_valid(node):
			node.queue_free()
	_active_loops.clear()
