# res://scripts/entities/companion_combatant.gd
# A Combatant subclass for companions (NPC and Summon).
# Does NOT take turns — reactive only. Managed by CompanionManager.
extends Combatant
class_name CompanionCombatant

# ============================================================================
# COMPANION DATA
# ============================================================================
var companion_data: CompanionData = null
var companion_instance: CompanionInstance = null  # null for summons
var slot_index: int = -1  # 0-1 = NPC, 2-3 = Summon

# ============================================================================
# COMPANION FLAGS
# ============================================================================
var is_companion: bool = true
var is_summon: bool = false

# ============================================================================
# COMBAT STATE
# ============================================================================
var turns_active: int = 0     # for duration tracking (summons)
var rounds_active: int = 0    # rounds on the field (taunt duration)
## Per ability slot (&"signature", &"reaction", &"bond"):
## { cooldown: int, uses: int (-1 unlimited), seen_first: bool }
var ability_state: Dictionary = {}
## Revived during this fight (Wounded).
var revived_this_fight: bool = false

## Legacy mirrors of the Signature's state (older callers read these).
var cooldown_remaining: int:
	get: return int(ability_state.get(&"signature", {}).get("cooldown", 0))
var uses_remaining: int:
	get: return int(ability_state.get(&"signature", {}).get("uses", -1))

var status_tracker: StatusTracker = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize_from_data(data: CompanionData, p_slot_index: int,
		player_max_hp: int, player_level: int,
		instance: CompanionInstance = null) -> void:
	"""Set up this combatant from a CompanionData resource."""
	companion_data = data
	companion_instance = instance
	slot_index = p_slot_index
	is_summon = (data.companion_type == CompanionData.CompanionType.SUMMON)
	is_player_controlled = false  # companions are AI-driven (reactive)

	# Identity
	combatant_name = data.companion_name

	# Statuses, DoTs, buffs, Braced, taunt state (Gap 76)
	if not has_node("StatusTracker"):
		status_tracker = StatusTracker.new()
		status_tracker.name = "StatusTracker"
		add_child(status_tracker)
	else:
		status_tracker = get_node("StatusTracker")

	# Health (Wounded companions have a reduced max)
	if instance:
		max_health = instance.get_max_hp(player_max_hp, player_level)
	else:
		max_health = data.calculate_max_hp(player_max_hp, player_level)
	if instance and instance.is_dead:
		current_health = 0  # downed: sits in the slot, can be revived mid-fight
	elif instance and instance.current_hp > 0:
		current_health = mini(instance.current_hp, max_health)
	else:
		current_health = max_health

	turns_active = 0
	rounds_active = 0
	revived_this_fight = false
	reset_abilities()

	update_display()
	print("  [Companion] CompanionCombatant initialized: %s (slot %d, HP %d/%d, %s)" % [
		combatant_name, slot_index, current_health, max_health,
		"summon" if is_summon else "NPC"])


func reset_abilities() -> void:
	ability_state.clear()
	if companion_data == null:
		return
	for entry in companion_data.get_abilities():
		var ab: CompanionAbility = entry["ability"]
		var uses := ab.uses_per_combat if ab.uses_per_combat > 0 else -1
		if entry["slot"] == &"bond" and uses < 0:
			uses = 1  # the Bond ability is once per fight unless it says otherwise
		ability_state[entry["slot"]] = {"cooldown": 0, "uses": uses, "seen_first": false}


func get_status_tracker() -> StatusTracker:
	return status_tracker

# ============================================================================
# HEALTH
# ============================================================================

func take_damage(amount: int):
	# A downed companion can't be hit again (no second "died").
	if not is_alive():
		return
	super.take_damage(amount)


func revive(hp: int, wounded: bool) -> void:
	"""Bring a downed companion back mid-fight. Wounded lowers max HP until
	the next proper rest."""
	if is_alive():
		return
	if wounded and companion_instance:
		companion_instance.is_wounded = true
		var gm_player = GameManager.player if GameManager else null
		if gm_player:
			max_health = companion_instance.get_max_hp(gm_player.max_hp, gm_player.level)
	revived_this_fight = true
	current_health = clampi(hp, 1, max_health)
	if companion_instance:
		companion_instance.is_dead = false
		companion_instance.current_hp = current_health
	health_changed.emit(current_health, max_health)
	update_display()
	print("  [Companion] %s revived at %d/%d%s" % [combatant_name, current_health, max_health,
		" (Wounded)" if wounded else ""])

# ============================================================================
# TAUNT
# ============================================================================

func is_taunting() -> bool:
	"""True while this companion's has_taunt is in force, or it carries the
	taunt status itself."""
	if not is_alive():
		return false
	if status_tracker and status_tracker.has_status("taunt"):
		return true
	return taunt_active()


func taunt_active() -> bool:
	"""has_taunt: taunt_duration 0 = the whole fight, N = the first N rounds."""
	if companion_data == null or not companion_data.has_taunt or not is_alive():
		return false
	return companion_data.taunt_duration <= 0 or rounds_active <= companion_data.taunt_duration

# ============================================================================
# ABILITIES: UNLOCKS, COOLDOWN & USAGE
# ============================================================================

func get_tier() -> int:
	if is_summon or companion_data == null:
		return 99
	return CompanionRoster.get_tier(companion_data.companion_id)


func is_ability_unlocked(slot: StringName, ability: CompanionAbility) -> bool:
	"""Signature always; Reaction from Trusted; Bond ability from Devoted
	(CompanionBondRules). Summons have no relationship: everything is open."""
	if is_summon or slot == &"signature":
		return true
	var need := ability.min_tier
	if need < 0:
		var rules := CompanionBondRules.get_rules()
		need = rules.bond_ability_min_tier if slot == &"bond" else rules.reaction_min_tier
	return get_tier() >= need


func can_fire_ability(slot: StringName) -> bool:
	if not is_alive():
		return false
	var st: Dictionary = ability_state.get(slot, {})
	if st.is_empty():
		return false
	if int(st.get("cooldown", 0)) > 0:
		return false
	if int(st.get("uses", -1)) == 0:
		return false
	return true


func on_ability_fired(slot: StringName, ability: CompanionAbility) -> void:
	var st: Dictionary = ability_state.get(slot, {})
	if st.is_empty():
		return
	if ability.cooldown_turns > 0:
		st["cooldown"] = ability.cooldown_turns
	if int(st.get("uses", -1)) > 0:
		st["uses"] = int(st["uses"]) - 1


func consume_first_skip(slot: StringName, ability: CompanionAbility) -> bool:
	"""fires_on_first_turn = false: returns true (skip) the first time the
	ability's trigger matches in this fight."""
	if ability.fires_on_first_turn:
		return false
	var st: Dictionary = ability_state.get(slot, {})
	if st.is_empty() or st.get("seen_first", false):
		return false
	st["seen_first"] = true
	return true


func can_fire() -> bool:
	"""Legacy: the Signature can fire."""
	return can_fire_ability(&"signature")


func on_fired() -> void:
	"""Legacy: the Signature fired."""
	if companion_data:
		on_ability_fired(&"signature", companion_data.get_signature())


func tick_cooldown() -> void:
	"""Reduce every ability's cooldown by 1. Called once per round."""
	rounds_active += 1
	for slot in ability_state:
		var st: Dictionary = ability_state[slot]
		if int(st.get("cooldown", 0)) > 0:
			st["cooldown"] = int(st["cooldown"]) - 1

# ============================================================================
# DURATION (summons)
# ============================================================================

func tick_duration() -> bool:
	"""Tick summon duration. Returns true if the summon has expired."""
	if not is_summon:
		return false
	if companion_data.duration_turns <= 0:
		return false  # infinite duration
	turns_active += 1
	return turns_active >= companion_data.duration_turns

# ============================================================================
# SYNC TO INSTANCE
# ============================================================================

func sync_to_instance() -> void:
	"""Write current combat state back to the persistent CompanionInstance.
	Called at combat end (and when downed) for NPC companions."""
	if companion_instance:
		companion_instance.current_hp = current_health
		companion_instance.is_dead = not is_alive()

# ============================================================================
# FIGHT SAVE
# ============================================================================

func to_fight_state() -> Dictionary:
	var abilities: Dictionary = {}
	for slot in ability_state:
		abilities[String(slot)] = ability_state[slot].duplicate()
	return {"hp": current_health, "max_hp": max_health, "alive": is_alive(),
		"rounds": rounds_active, "turns": turns_active, "abilities": abilities,
		"revived": revived_this_fight}


func apply_fight_state(s: Dictionary) -> void:
	max_health = int(s.get("max_hp", max_health))
	current_health = clampi(int(s.get("hp", current_health)), 0, max_health)
	if not bool(s.get("alive", true)):
		current_health = 0
	rounds_active = int(s.get("rounds", rounds_active))
	turns_active = int(s.get("turns", turns_active))
	revived_this_fight = bool(s.get("revived", false))
	var abilities: Dictionary = s.get("abilities", {})
	for key in abilities:
		var slot := StringName(key)
		if ability_state.has(slot):
			var saved: Dictionary = abilities[key]
			for k in saved:
				ability_state[slot][k] = saved[k]
	if companion_instance:
		companion_instance.is_dead = not is_alive()
	update_display()
