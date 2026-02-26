# res://scripts/ui/combat/companion_panel.gd
# Manages the 4 companion slots in the combat UI.
# Attach to CombatCompanionPanelVBox in combat_ui.tscn.
# Discovers CompanionSlot children and assigns internal indices.
extends VBoxContainer
class_name CompanionPanel

# ============================================================================
# SLOT INDEX MAPPING
# ============================================================================
# Scene node name -> Internal index (fill order)
#
# CompanionSlot4 (bottom) -> 0  NPC first-to-fill
# CompanionSlot3           -> 1  NPC second-to-fill
# CompanionSlot2           -> 2  Summon first-to-fill
# CompanionSlot1 (top)     -> 3  Summon second-to-fill
#
# Formula: internal_index = 4 - scene_number
# Reverse: scene_number   = 4 - internal_index
# ============================================================================

var companion_slots: Array[CompanionSlot] = []
var _effects_layer: CanvasLayer = null
# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_slots()
	print("[Companion] CompanionPanel ready with %d slots" % companion_slots.size())

func _discover_slots() -> void:
	"""Find all CompanionSlot children and assign internal indices."""
	companion_slots.clear()
	for child in get_children():
		if not child is CompanionSlot:
			continue
		# Extract scene number from node name (e.g. "CompanionSlot4" -> 4)
		var num_str = child.name.replace("CompanionSlot", "")
		if num_str.is_valid_int():
			var scene_number := int(num_str)
			child.slot_index = 4 - scene_number
			child.is_npc_slot = (child.slot_index < 2)
			companion_slots.append(child)
		else:
			push_warning("CompanionPanel: unexpected child name: %s" % child.name)

	# Sort by internal index for consistent ordering
	companion_slots.sort_custom(func(a, b): return a.slot_index < b.slot_index)

# ============================================================================
# PERSISTENT DISPLAY
# ============================================================================

func refresh_from_player(player) -> void:
	clear_all()
	if not player or not "active_companions" in player:
		return
	var slot_idx := 0
	for instance in player.active_companions:
		if slot_idx >= companion_slots.size():
			break
		if instance and instance.companion_data:
			var slot = _get_slot(slot_idx)
			if slot:
				slot.set_companion_data(instance.companion_data)
				# Sync persisted HP state from instance
				if instance.is_dead:
					slot.update_health(0, instance.get_max_hp(player.max_hp, player.level))
					slot.show_dead()
				elif instance.current_hp > 0:
					slot.update_health(
						instance.current_hp,
						instance.get_max_hp(player.max_hp, player.level))
				print("  [Companion] Panel slot %d <- %s (HP: %d, dead: %s)" % [
					slot_idx, instance.companion_data.companion_name,
					instance.current_hp, instance.is_dead])
			slot_idx += 1

# ============================================================================
# COMPANION MANAGEMENT
# ============================================================================
func set_companion(slot_index: int, companion: CompanionCombatant) -> void:
	"""Set a companion into a specific slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.set_companion(companion)
		print("  [Companion] Panel slot %d (scene %s) <- %s" % [
			slot_index, slot.name, companion.combatant_name])

func set_effects_layer(layer: CanvasLayer) -> void:
	_effects_layer = layer

func clear_slot(slot_index: int) -> void:
	"""Clear a specific slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.set_empty()

func clear_all() -> void:
	"""Clear all slots."""
	for slot in companion_slots:
		slot.set_empty()

func update_health(slot_index: int, current: int, maximum: int) -> void:
	"""Update HP display for a specific slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.update_health(current, maximum)

func show_slot_dead(slot_index: int) -> void:
	"""Show death state for a specific slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.show_dead()

func play_slot_fire(slot_index: int) -> void:
	"""Play the firing animation on a slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.play_fire_animation()

func show_taunt(slot_index: int, is_taunting: bool) -> void:
	"""Show/hide taunt indicator on a slot."""
	var slot = _get_slot(slot_index)
	if slot:
		slot.show_taunt_indicator(is_taunting)

# ============================================================================
# SUMMON ANIMATIONS
# ============================================================================

func play_summon_enter(slot_index: int) -> void:
	"""Play the swirl-in animation for a new summon."""
	var slot = _get_slot(slot_index)
	if not slot:
		return

	# Pull entry emanate preset from the companion's data
	var entry_emanate: EmanatePreset = null
	if slot.companion and slot.companion.companion_data:
		entry_emanate = slot.companion.companion_data.entry_emanate_preset

	await slot.play_summon_enter(entry_emanate, _effects_layer)

func play_summon_exit(slot_index: int) -> void:
	"""Play the dissolve-out animation for a departing summon."""
	var slot = _get_slot(slot_index)
	if slot:
		await slot.play_summon_exit()
		slot.set_empty()

func play_summon_replace(slot_index: int, new_companion: CompanionCombatant) -> void:
	"""Dissolve old → swirl in new (~1s total)."""
	var slot = _get_slot(slot_index)
	if not slot:
		return
	await slot.play_summon_exit()
	slot.set_companion(new_companion)

	var entry_emanate: EmanatePreset = null
	if new_companion and new_companion.companion_data:
		entry_emanate = new_companion.companion_data.entry_emanate_preset

	await slot.play_summon_enter(entry_emanate, _effects_layer)

# ============================================================================
# QUERIES
# ============================================================================

func get_slot(slot_index: int) -> CompanionSlot:
	"""Get a slot by internal index (0-3)."""
	return _get_slot(slot_index)

func get_slot_center_global(slot_index: int) -> Vector2:
	"""Get the global center position of a slot (for effect targeting)."""
	var slot = _get_slot(slot_index)
	if slot:
		return slot.global_position + slot.size / 2.0
	return Vector2.ZERO

# ============================================================================
# PRIVATE
# ============================================================================

func _get_slot(internal_index: int) -> CompanionSlot:
	"""Find slot by internal index. Slots are sorted by index after discovery."""
	for slot in companion_slots:
		if slot.slot_index == internal_index:
			return slot
	return null
