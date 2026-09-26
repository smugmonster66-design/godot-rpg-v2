# res://scripts/ui/bark_manager.gd
# Manages speech bubble barks on characters.
# Two input paths:
#   1. Reactive: listens to GameEventBus, evaluates companion BarkSets
#   2. Direct: show_bark() called by CombatManager for action-attached barks
#
# Add as child of PersistentUILayer in game_root.tscn.
extends Node
class_name BarkManager

# ============================================================================
# CONFIGURATION
# ============================================================================

## CanvasLayer index for bark bubbles (above all UI, layer 300)
@export var bark_layer_index: int = 300

## Maximum simultaneous bark bubbles across all anchors
@export var max_simultaneous: int = 2

## Global cooldown between barks in seconds (action barks bypass this)
@export var global_cooldown: float = 1.5

## Whether to log bark activity in debug builds
@export var debug_logging: bool = false

# ============================================================================
# INTERNAL STATE
# ============================================================================

var _bark_layer: CanvasLayer = null
var _bark_container: Control = null
var _active_barks: Dictionary = {}  # anchor_instance_id -> BarkBubble
var _active_count: int = 0
var _last_global_bark: float = 0.0

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	_bark_layer = CanvasLayer.new()
	_bark_layer.name = "BarkLayer"
	_bark_layer.layer = bark_layer_index
	add_child(_bark_layer)

	_bark_container = Control.new()
	_bark_container.name = "BarkContainer"
	_bark_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	if ThemeManager and ThemeManager.theme:
		_bark_container.theme = ThemeManager.theme
	_bark_layer.add_child(_bark_container)

	GameEventBus.game_event.connect(_on_game_event)

# ============================================================================
# REACTIVE PATH — personality barks from companion BarkSets
# ============================================================================

func _on_game_event(event: GameEvent) -> void:
	# Global cooldown check
	var now = Time.get_ticks_msec()
	if (now - _last_global_bark) < global_cooldown * 1000.0:
		return

	if _active_count >= max_simultaneous:
		return

	# Iterate active companions' bark sets
	var companions = _get_active_companions()
	for i in companions.size():
		var companion = companions[i]
		var companion_data: CompanionData = null
		if companion is CompanionInstance:
			if companion.is_dead:
				continue  # downed companions don't bark (Gap 80)
			companion_data = companion.companion_data
		elif companion is CompanionData:
			companion_data = companion
		else:
			continue

		if not companion_data.bark_set:
			continue

		var bark_set: BarkSet = companion_data.bark_set
		for reaction in bark_set.reactions:
			if reaction.matches(event):
				# Fire chance check
				if reaction.fire_chance < 1.0 and randf() > reaction.fire_chance:
					reaction.mark_fired()
					continue

				var bark = reaction.pick_bark()
				if not bark:
					continue

				# Resolve anchor — companion's portrait slot
				var anchor = _get_companion_slot(i)
				if not anchor:
					continue

				# Resolve speaker
				var speaker_id = bark.speaker_id if bark.speaker_id != &"" else bark_set.speaker_id

				_show_bark_internal(bark, anchor, speaker_id, false)
				reaction.mark_fired()
				return  # First companion to match wins

# ============================================================================
# DIRECT PATH — action-attached barks
# ============================================================================

func show_bark(entry: BarkEntry, anchor: Node) -> void:
	"""Public API for action-attached barks. Bypasses global cooldown."""
	if not entry or not anchor or not is_instance_valid(anchor):
		return
	_show_bark_internal(entry, anchor, entry.speaker_id, true)

# ============================================================================
# BARK DISPLAY
# ============================================================================

func _show_bark_internal(entry: BarkEntry, anchor: Node,
		speaker_id: StringName, bypass_cooldown: bool) -> void:
	var anchor_id = anchor.get_instance_id()

	# Replacement logic: if existing bark on this anchor
	if _active_barks.has(anchor_id):
		var existing = _active_barks[anchor_id]
		if is_instance_valid(existing):
			# Only replace if new bark has higher priority
			if entry.priority <= existing.get_meta("bark_priority", 0):
				return
			existing.fade_out(0.15)
			_active_count -= 1

	# Cap check
	if _active_count >= max_simultaneous:
		return

	# Create bark bubble
	var bubble = BarkBubble.new()
	bubble.set_meta("bark_priority", entry.priority)
	_bark_container.add_child(bubble)
	bubble.show_bark(entry, anchor, speaker_id)

	_active_barks[anchor_id] = bubble
	_active_count += 1
	if not bypass_cooldown:
		_last_global_bark = Time.get_ticks_msec()

	if debug_logging and OS.is_debug_build():
		print("  💬 Bark: \"%s\" on %s" % [entry.text, anchor.name if anchor else "null"])

	# Clean up when bark fades
	bubble.faded_out.connect(func():
		if _active_barks.get(anchor_id) == bubble:
			_active_barks.erase(anchor_id)
		_active_count = maxi(0, _active_count - 1)
	)

# ============================================================================
# ANCHOR RESOLUTION
# ============================================================================

func _get_player_portrait() -> Control:
	if GameManager and GameManager.game_root:
		return GameManager.game_root.get_node_or_null(
			"PersistentUILayer/PortraitVBox/PortraitContainer/PortraitTexture")
	return null


func _get_companion_slot(index: int) -> Control:
	if GameManager and GameManager.game_root:
		var slot_name = "CompanionSlot%d" % (index + 1)
		return GameManager.game_root.get_node_or_null(
			"PersistentUILayer/CombatCompanionVBox/CombatCompanionPanelVBox/%s" % slot_name)
	return null


func _get_active_companions() -> Array:
	if GameManager and GameManager.player:
		return GameManager.player.active_companions
	return []
