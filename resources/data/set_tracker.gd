# set_tracker.gd - Tracks equipped set pieces and manages set bonuses
# v3 — Simplified for EquippableItem-based equipment (no more Dictionary checks).
extends RefCounted
class_name SetTracker

# ============================================================================
# SIGNALS
# ============================================================================
signal set_bonus_changed(set_id: StringName, equipped_count: int, total_pieces: int)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var _equipped_counts: Dictionary = {}
var _known_sets: Dictionary = {}
var _active_thresholds: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(p_player: Player):
	player = p_player
	
	if player.has_signal("equipment_changed"):
		if not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)
	
	recalculate_all()
	print("🛡️ SetTracker initialized")

# ============================================================================
# EQUIPMENT CHANGE HANDLER
# ============================================================================

func _on_equipment_changed(_slot: String, _item):
	recalculate_all()

func recalculate_all():
	if not player:
		return
	
	# Step 1: Count pieces per set
	var new_counts: Dictionary = {}
	var new_known: Dictionary = {}
	
	for slot_name in player.equipment:
		var item: EquippableItem = player.equipment[slot_name]
		if not item or not item.set_definition:
			continue
		
		var set_def: SetDefinition = item.set_definition
		var sid: StringName = set_def.set_id
		new_known[sid] = set_def
		new_counts[sid] = new_counts.get(sid, 0) + 1
	
	# Step 2: Find what changed
	var all_set_ids: Dictionary = {}
	for sid in _equipped_counts:
		all_set_ids[sid] = true
	for sid in new_counts:
		all_set_ids[sid] = true
	
	# Step 3: Update each set
	for sid in all_set_ids:
		var old_count: int = _equipped_counts.get(sid, 0)
		var new_count: int = new_counts.get(sid, 0)
		
		if old_count == new_count:
			continue
		
		var set_def: SetDefinition = new_known.get(sid, _known_sets.get(sid))
		if not set_def:
			continue
		
		print("🛡️ Set '%s': %d → %d pieces" % [set_def.set_name, old_count, new_count])
		
		_deactivate_set(set_def)
		
		if new_count > 0:
			_activate_set(set_def, new_count)
		
		set_bonus_changed.emit(sid, new_count, set_def.get_total_pieces())
	
	# Step 4: Update stored state
	_equipped_counts = new_counts
	_known_sets = new_known
	
	# Step 5: Recalculate stats
	player.recalculate_stats()

# ============================================================================
# ACTIVATION / DEACTIVATION
# ============================================================================

func _activate_set(set_def: SetDefinition, equipped_count: int):
	var active: Array = []
	for threshold in set_def.thresholds:
		if equipped_count >= threshold.required_pieces:
			_apply_threshold(set_def, threshold)
			active.append(threshold)
	_active_thresholds[set_def.set_id] = active

func _deactivate_set(set_def: SetDefinition):
	var source_name: String = set_def.get_affix_source_name()
	if player.affix_manager:
		player.affix_manager.remove_affixes_by_source(source_name)
	_remove_dice_affixes_for_set(set_def)
	_active_thresholds.erase(set_def.set_id)

func _apply_threshold(set_def: SetDefinition, threshold):
	var source_name: String = set_def.get_affix_source_name()
	
	for affix in threshold.affixes:
		if affix:
			var copy = affix.duplicate_with_source(source_name, "set")
			player.affix_manager.add_affix(copy)
	
	if threshold.has("dice_affix") and threshold.dice_affix:
		_apply_dice_affixes_for_set(set_def, threshold.dice_affix)

func _apply_dice_affixes_for_set(set_def: SetDefinition, dice_affix):
	if not player or not player.dice_pool:
		return
	
	var set_item_names: Array[String] = _get_equipped_set_item_names(set_def)
	
	for die in player.dice_pool.dice:
		if die.source in set_item_names:
			var copy = dice_affix.duplicate()
			copy.source = set_def.get_affix_source_name()
			copy.source_type = "set"
			die.add_affix(copy)

func _remove_dice_affixes_for_set(set_def: SetDefinition):
	if not player or not player.dice_pool:
		return
	
	var source_name: String = set_def.get_affix_source_name()
	
	for die in player.dice_pool.dice:
		var to_remove: Array[DiceAffix] = []
		for affix in die.applied_affixes:
			if affix.source == source_name:
				to_remove.append(affix)
		for affix in to_remove:
			die.remove_affix(affix)

func _get_equipped_set_item_names(set_def: SetDefinition) -> Array[String]:
	"""Get names of all equipped items belonging to this set."""
	var names: Array[String] = []
	for slot_name in player.equipment:
		var item: EquippableItem = player.equipment[slot_name]
		if not item:
			continue
		if item.set_definition and item.set_definition.set_id == set_def.set_id:
			names.append(item.item_name)
	return names

# ============================================================================
# QUERY API
# ============================================================================

func is_threshold_active(set_id: StringName, required_pieces: int) -> bool:
	var active = _active_thresholds.get(set_id, [])
	for threshold in active:
		if threshold.required_pieces == required_pieces:
			return true
	return false

func get_active_sets() -> Dictionary:
	var result: Dictionary = {}
	for sid in _equipped_counts:
		var count: int = _equipped_counts[sid]
		if count <= 0:
			continue
		var set_def: SetDefinition = _known_sets.get(sid)
		if not set_def:
			continue
		result[sid] = {
			"definition": set_def,
			"count": count,
			"total": set_def.get_total_pieces(),
			"active_thresholds": _active_thresholds.get(sid, []),
			"next_threshold": set_def.get_next_threshold(count),
		}
	return result

func get_set_info(set_id: StringName) -> Dictionary:
	if not _equipped_counts.has(set_id):
		return {}
	return get_active_sets().get(set_id, {})
