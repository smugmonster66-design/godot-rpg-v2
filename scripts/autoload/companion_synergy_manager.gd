# res://scripts/autoload/companion_synergy_manager.gd
# Autoload that tracks active companion synergies and applies/removes bonuses.
# Loads synergy definitions from resources/companions/synergies/.
# Call recalculate(player) whenever active_companions changes.
extends Node

signal synergy_changed(synergy_id: StringName, is_active: bool)

# ============================================================================
# STATE
# ============================================================================

var _definitions: Array[CompanionSynergyDefinition] = []
var _active_synergies: Dictionary = {}  # synergy_id → CompanionSynergyDefinition
var _bonus_cooldowns: Dictionary = {}   # synergy_id → remaining cooldown turns
var _player: Player = null

const SYNERGY_DIR := "res://resources/companions/synergies/"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_definitions()

func _load_definitions() -> void:
	_definitions.clear()
	if not DirAccess.dir_exists_absolute(SYNERGY_DIR):
		return
	var dir = DirAccess.open(SYNERGY_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path = SYNERGY_DIR + file_name
			var res = load(path)
			if res is CompanionSynergyDefinition:
				_definitions.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

	if _definitions.size() > 0:
		print("[CompanionSynergyManager] Loaded %d synergy definitions" % _definitions.size())

# ============================================================================
# PUBLIC API
# ============================================================================

func recalculate(player: Player) -> void:
	"""Evaluate all synergies against current active companions."""
	_player = player
	if not player:
		_deactivate_all()
		return

	# Downed companions don't count toward synergies (Gap 80)
	var active: Array = []
	for inst in (player.active_companions if player.active_companions else []):
		if inst and not inst.is_dead:
			active.append(inst)

	for def in _definitions:
		var should_be_active = _is_synergy_met(def, active)
		var currently_active = _active_synergies.has(def.synergy_id)

		if should_be_active and not currently_active:
			_activate_synergy(def)
		elif not should_be_active and currently_active:
			_deactivate_synergy(def)


func get_active_synergies() -> Array[CompanionSynergyDefinition]:
	"""Get all currently active synergy definitions."""
	var result: Array[CompanionSynergyDefinition] = []
	for syn in _active_synergies.values():
		result.append(syn)
	return result


func get_synergies_for_companion(data: CompanionData) -> Array[CompanionSynergyDefinition]:
	"""Get all synergy definitions that involve this companion (active or not)."""
	var result: Array[CompanionSynergyDefinition] = []
	for def in _definitions:
		if _companion_is_in_synergy(def, data):
			result.append(def)
	return result


func is_synergy_active(synergy_id: StringName) -> bool:
	return _active_synergies.has(synergy_id)


func get_all_definitions() -> Array[CompanionSynergyDefinition]:
	return _definitions

# ============================================================================
# BONUS ACTION COOLDOWNS
# ============================================================================

func get_bonus_cooldown(synergy_id: StringName) -> int:
	"""Get remaining cooldown turns for a synergy's bonus action."""
	return _bonus_cooldowns.get(synergy_id, 0)


func set_bonus_cooldown(synergy_id: StringName, value: int) -> void:
	"""Set the cooldown for a synergy's bonus action."""
	_bonus_cooldowns[synergy_id] = value


func tick_bonus_cooldowns() -> void:
	"""Decrement all bonus action cooldowns by 1. Called once per round."""
	for sid in _bonus_cooldowns.keys():
		if _bonus_cooldowns[sid] > 0:
			_bonus_cooldowns[sid] -= 1


func reset_bonus_cooldowns() -> void:
	"""Clear all bonus cooldowns (combat end, deactivate all)."""
	_bonus_cooldowns.clear()

# ============================================================================
# MATCHING
# ============================================================================

func _is_synergy_met(def: CompanionSynergyDefinition, active: Array) -> bool:
	match def.match_mode:
		CompanionSynergyDefinition.MatchMode.TAGS:
			return _check_tags(def, active)
		CompanionSynergyDefinition.MatchMode.EXPLICIT:
			return _check_explicit(def, active)
	return false


func _check_tags(def: CompanionSynergyDefinition, active: Array) -> bool:
	if def.required_tags.is_empty():
		return false

	# Count active companions that have ALL required tags
	var matching_count := 0
	for inst in active:
		if not inst or not inst.companion_data:
			continue
		if _has_all_tags(inst.companion_data, def.required_tags):
			# Optional relationship check
			if def.min_relationship >= 0:
				var comp_id = inst.companion_data.companion_id
				if comp_id == &"" or GameState.get_relationship(comp_id) < def.min_relationship:
					continue
			matching_count += 1

	return matching_count >= def.required_count


func _check_explicit(def: CompanionSynergyDefinition, active: Array) -> bool:
	if def.required_companion_ids.is_empty():
		return false

	# All required companion_ids must be present in active
	for required_id in def.required_companion_ids:
		var found := false
		for inst in active:
			if not inst or not inst.companion_data:
				continue
			if inst.companion_data.companion_id == required_id:
				# Optional relationship check
				if def.min_relationship >= 0:
					if GameState.get_relationship(required_id) < def.min_relationship:
						return false
				found = true
				break
		if not found:
			return false
	return true


func _has_all_tags(data: CompanionData, required: Array[StringName]) -> bool:
	for tag in required:
		if tag not in data.synergy_tags:
			return false
	return true


func _companion_is_in_synergy(def: CompanionSynergyDefinition, data: CompanionData) -> bool:
	"""Check if a companion participates in a synergy definition (regardless of active state)."""
	match def.match_mode:
		CompanionSynergyDefinition.MatchMode.TAGS:
			return _has_all_tags(data, def.required_tags)
		CompanionSynergyDefinition.MatchMode.EXPLICIT:
			return data.companion_id in def.required_companion_ids
	return false

# ============================================================================
# ACTIVATION / DEACTIVATION
# ============================================================================

func _activate_synergy(def: CompanionSynergyDefinition) -> void:
	var source_name = def.get_affix_source_name()
	_active_synergies[def.synergy_id] = def

	# Apply stat affixes to player
	if _player and _player.affix_manager:
		for affix in def.granted_affixes:
			if affix:
				var copy = affix.duplicate_with_source(source_name, "synergy")
				_player.affix_manager.add_affix(copy)

	# Apply dice affixes to all dice
	if _player and _player.dice_pool:
		for da in def.granted_dice_affixes:
			if da:
				for die in _player.dice_pool.dice:
					var copy = da.duplicate_with_source(source_name, "synergy")
					die.add_affix(copy)

	synergy_changed.emit(def.synergy_id, true)
	print("[CompanionSynergyManager] Activated: %s" % def.synergy_name)


func _deactivate_synergy(def: CompanionSynergyDefinition) -> void:
	var source_name = def.get_affix_source_name()
	_active_synergies.erase(def.synergy_id)

	# Remove stat affixes
	if _player and _player.affix_manager:
		_player.affix_manager.remove_affixes_by_source(source_name)

	# Remove dice affixes
	if _player and _player.dice_pool:
		for die in _player.dice_pool.dice:
			var to_remove: Array[DiceAffix] = []
			for da in die.applied_affixes:
				if da.source == source_name:
					to_remove.append(da)
			for da in to_remove:
				die.applied_affixes.erase(da)

	# Clear bonus cooldown for this synergy
	_bonus_cooldowns.erase(def.synergy_id)

	synergy_changed.emit(def.synergy_id, false)
	print("[CompanionSynergyManager] Deactivated: %s" % def.synergy_name)


func _deactivate_all() -> void:
	var ids = _active_synergies.keys()
	for sid in ids:
		var def = _active_synergies[sid]
		_deactivate_synergy(def)
	reset_bonus_cooldowns()
