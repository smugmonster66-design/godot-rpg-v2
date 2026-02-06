# res://resources/data/set_tracker.gd
# Tracks equipped set pieces and manages activation/deactivation of set bonuses.
# Lives on Player alongside affix_manager. Listens to equipment_changed signals.
#
# When equipment changes:
#   1. Scans all equipped items for set_definition references
#   2. Counts pieces per set_id
#   3. Compares to previous counts
#   4. Deactivates old threshold affixes, activates new ones
#   5. Applies dice_affixes to dice granted by set items only
#
# Affixes are registered with source "set:SetName" for clean removal.
extends RefCounted
class_name SetTracker

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when any set bonus activates or deactivates.
## UI can connect to this to update set displays.
signal set_bonus_changed(set_id: StringName, equipped_count: int, total_pieces: int)

# ============================================================================
# STATE
# ============================================================================

## Reference to the player (set during initialization)
var player: Player = null

## Current piece counts per set: { set_id: int }
var _equipped_counts: Dictionary = {}

## Active SetDefinitions by set_id: { set_id: SetDefinition }
var _known_sets: Dictionary = {}

## Currently active thresholds per set: { set_id: Array[SetBonusThreshold] }
var _active_thresholds: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(p_player: Player):
	"""Initialize with player reference and connect to equipment changes."""
	player = p_player
	
	if player.has_signal("equipment_changed"):
		if not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)
	
	# Do an initial scan in case equipment is already populated
	recalculate_all()
	
	print("🛡️ SetTracker initialized")

# ============================================================================
# EQUIPMENT CHANGE HANDLER
# ============================================================================

func _on_equipment_changed(_slot: String, _item):
	"""Called whenever the player equips or unequips any item."""
	recalculate_all()

func recalculate_all():
	"""Full recalculation of all set bonuses.
	
	Scans every equipment slot, counts set pieces, and activates/deactivates
	thresholds as needed. Safe to call at any time.
	"""
	if not player:
		return
	
	# ── Step 1: Count pieces per set ──
	var new_counts: Dictionary = {}  # { set_id: int }
	var new_known: Dictionary = {}   # { set_id: SetDefinition }
	
	for slot_name in player.equipment:
		var item = player.equipment[slot_name]
		if not item:
			continue
		
		# Get set_definition from the item dictionary
		var set_def: SetDefinition = _get_set_definition(item)
		if not set_def:
			continue
		
		var sid: StringName = set_def.set_id
		new_known[sid] = set_def
		new_counts[sid] = new_counts.get(sid, 0) + 1
	
	# ── Step 2: Find what changed ──
	# Collect all set_ids that existed before or exist now
	var all_set_ids: Dictionary = {}
	for sid in _equipped_counts:
		all_set_ids[sid] = true
	for sid in new_counts:
		all_set_ids[sid] = true
	
	# ── Step 3: Update each set ──
	for sid in all_set_ids:
		var old_count: int = _equipped_counts.get(sid, 0)
		var new_count: int = new_counts.get(sid, 0)
		
		if old_count == new_count:
			continue  # No change for this set
		
		var set_def: SetDefinition = new_known.get(sid, _known_sets.get(sid))
		if not set_def:
			continue
		
		print("🛡️ Set '%s': %d → %d pieces" % [set_def.set_name, old_count, new_count])
		
		# Deactivate all current thresholds for this set
		_deactivate_set(set_def)
		
		# Activate thresholds for new count
		if new_count > 0:
			_activate_set(set_def, new_count)
		
		# Notify UI
		set_bonus_changed.emit(sid, new_count, set_def.get_total_pieces())
	
	# ── Step 4: Update stored state ──
	_equipped_counts = new_counts
	_known_sets = new_known

# ============================================================================
# ACTIVATION / DEACTIVATION
# ============================================================================

func _activate_set(set_def: SetDefinition, equipped_count: int):
	"""Activate all thresholds met by the current piece count."""
	var source_name: String = set_def.get_affix_source_name()
	var active: Array[SetBonusThreshold] = set_def.get_active_thresholds(equipped_count)
	
	for threshold in active:
		# Register item-level affixes with AffixPoolManager
		for affix in threshold.affixes:
			var copy = affix.duplicate_with_source(source_name, "set") if affix.has_method("duplicate_with_source") else affix.duplicate()
			if copy is Affix:
				copy.source = source_name
				copy.source_type = "set"
				player.affix_manager.add_affix(copy)
				print("  ✅ Set affix activated: %s (from %s %d-piece)" % [
					copy.affix_name, set_def.set_name, threshold.required_pieces
				])
		
		# Apply dice-level affixes to dice from set items ONLY
		for dice_affix in threshold.dice_affixes:
			_apply_dice_affix_to_set_dice(set_def, dice_affix)
			print("  🎲 Set dice affix activated: %s (from %s %d-piece)" % [
				dice_affix.affix_name, set_def.set_name, threshold.required_pieces
			])
	
	_active_thresholds[set_def.set_id] = active

func _deactivate_set(set_def: SetDefinition):
	"""Remove all active affixes for a set."""
	var source_name: String = set_def.get_affix_source_name()
	
	# Remove item-level affixes from AffixPoolManager
	player.affix_manager.remove_affixes_by_source(source_name)
	
	# Remove dice-level affixes from set dice
	_remove_dice_affixes_for_set(set_def)
	
	_active_thresholds.erase(set_def.set_id)

# ============================================================================
# DICE AFFIX APPLICATION (Set items only)
# ============================================================================

func _apply_dice_affix_to_set_dice(set_def: SetDefinition, dice_affix: DiceAffix):
	"""Apply a DiceAffix to all dice in the player's pool that came from set items."""
	if not player or not player.dice_pool:
		return
	
	var set_item_names: Array[String] = _get_equipped_set_item_names(set_def)
	
	for die in player.dice_pool.dice:
		if die.source in set_item_names:
			# Tag the affix so we can find and remove it later
			var copy = dice_affix.duplicate()
			copy.source = set_def.get_affix_source_name()
			copy.source_type = "set"
			die.add_affix(copy)

func _remove_dice_affixes_for_set(set_def: SetDefinition):
	"""Remove all dice affixes that were applied by this set."""
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
	"""Get names of all currently equipped items belonging to this set."""
	var names: Array[String] = []
	for slot_name in player.equipment:
		var item = player.equipment[slot_name]
		if not item:
			continue
		var item_set_def = _get_set_definition(item)
		if item_set_def and item_set_def.set_id == set_def.set_id:
			names.append(item.get("name", ""))
	return names

# ============================================================================
# ITEM HELPERS
# ============================================================================

func _get_set_definition(item) -> SetDefinition:
	"""Extract SetDefinition from an item (handles both Dictionary and Resource)."""
	if item is Dictionary:
		return item.get("set_definition", null) as SetDefinition
	elif item is EquippableItem:
		return item.set_definition
	elif item is Resource and "set_definition" in item:
		return item.set_definition
	return null

# ============================================================================
# QUERY API (for UI)
# ============================================================================

func get_active_sets() -> Dictionary:
	"""Get all sets with at least one equipped piece.
	
	Returns:
		Dictionary of { set_id: { definition: SetDefinition, count: int, 
		                          active_thresholds: Array, next_threshold: SetBonusThreshold } }
	"""
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
	"""Get info for a specific set. Returns empty dict if not equipped."""
	var sets = get_active_sets()
	return sets.get(set_id, {})

func get_equipped_count(set_id: StringName) -> int:
	"""Get how many pieces of a specific set are equipped."""
	return _equipped_counts.get(set_id, 0)

func is_threshold_active(set_id: StringName, required_pieces: int) -> bool:
	"""Check if a specific threshold is currently active."""
	var active = _active_thresholds.get(set_id, [])
	for threshold in active:
		if threshold.required_pieces == required_pieces:
			return true
	return false

# ============================================================================
# DEBUG
# ============================================================================

func print_status():
	"""Debug: print all tracked sets and their status."""
	print("=== Set Tracker Status ===")
	if _equipped_counts.is_empty():
		print("  No sets equipped")
		return
	
	for sid in _equipped_counts:
		var count = _equipped_counts[sid]
		var set_def = _known_sets.get(sid)
		var name = set_def.set_name if set_def else str(sid)
		var active = _active_thresholds.get(sid, [])
		print("  %s: %d/%d pieces, %d active bonuses" % [
			name, count, set_def.get_total_pieces() if set_def else 0, active.size()
		])
		for threshold in active:
			print("    ✓ %s" % threshold.get_summary())
		var next = set_def.get_next_threshold(count) if set_def else null
		if next:
			print("    → Next: %s" % next.get_summary())
