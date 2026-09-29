# res://scripts/shared/companion_roster.gd
# One place for the companion roster outside combat: recruit and dismiss
# (dialogue action, GameEvent effect, quest reward), the active party (2 NPC
# companions; summons are separate and combat-only), relationship tiers and
# the bond die, recovery (rest, revive, rescue), temperament reactions,
# relationship notices and Trail perks.
#
#   CompanionRoster.recruit(load("res://resources/companions/companion_manne.tres"))
#   CompanionRoster.recruit_ref("manne:camp")      # by id or path; ":camp" = don't join the party
#   CompanionRoster.dismiss(&"manne")
#   CompanionRoster.get_tier(&"manne")             # 0 Acquaintance .. 3 Devoted
#
# Numbers live in CompanionBondRules (res://resources/companions/companion_bond_rules.tres).
extends RefCounted
class_name CompanionRoster

const MAX_ACTIVE := 2
const COMPANION_ROOT := "res://resources/companions/"


static func _player():
	return GameManager.player if GameManager else null


static func rules() -> CompanionBondRules:
	return CompanionBondRules.get_rules()

# ============================================================================
# QUERIES
# ============================================================================

static func find(companion_id: StringName, player = null) -> CompanionInstance:
	var p = player if player else _player()
	if p == null or companion_id == &"":
		return null
	for inst in p.companion_roster:
		if inst and inst.companion_data and inst.companion_data.companion_id == companion_id:
			return inst
	return null


static func is_recruited(companion_id: StringName) -> bool:
	return find(companion_id) != null


static func is_in_party(companion_id: StringName) -> bool:
	var p = _player()
	if p == null:
		return false
	for inst in p.active_companions:
		if inst and inst.companion_data and inst.companion_data.companion_id == companion_id:
			return true
	return false


static func resolve_data(ref: String) -> CompanionData:
	"""A CompanionData from a res:// path or a companion_id (searched under
	res://resources/companions/)."""
	ref = ref.strip_edges()
	if ref.begins_with("res://"):
		return load(ref) as CompanionData if ResourceLoader.exists(ref) else null
	return _find_data_by_id(COMPANION_ROOT, StringName(ref))


static func _find_data_by_id(dir_path: String, companion_id: StringName) -> CompanionData:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return null
	for f in dir.get_files():
		var file: String = String(f).trim_suffix(".remap")
		if file.ends_with(".tres"):
			var res = load(dir_path.path_join(file))
			if res is CompanionData and res.companion_id == companion_id:
				return res
	for sub in dir.get_directories():
		var found := _find_data_by_id(dir_path.path_join(sub), companion_id)
		if found:
			return found
	return null

# ============================================================================
# RECRUIT / DISMISS / PARTY
# ============================================================================

static func recruit_ref(param: String, source: String = "story") -> CompanionInstance:
	"""Dialogue/event form: "<path or id>" joins the party if there's room,
	"<path or id>:camp" goes to camp."""
	var ref := param.strip_edges()
	var to_party := true
	if ref.ends_with(":camp"):
		ref = ref.trim_suffix(":camp")
		to_party = false
	elif ref.ends_with(":party"):
		ref = ref.trim_suffix(":party")
	var data := resolve_data(ref)
	if data == null:
		push_warning("CompanionRoster: no CompanionData for '%s'" % ref)
		return null
	return recruit(data, to_party, source)


static func recruit(data: CompanionData, join_party: bool = true, source: String = "story",
		permanent: bool = false, notify: bool = true) -> CompanionInstance:
	"""Add a companion to the roster (camp). Joins the active party if asked
	and there's room (2 max). Recruiting someone already in the roster returns
	them (and seats them if asked and there's room)."""
	var p = _player()
	if p == null or data == null:
		push_warning("CompanionRoster.recruit: no player or no data")
		return null
	if data.companion_type != CompanionData.CompanionType.NPC:
		push_warning("CompanionRoster.recruit: %s is a summon, not an NPC companion" % data.companion_name)
		return null
	var inst: CompanionInstance = find(data.companion_id, p) if data.companion_id != &"" else null
	var is_new := inst == null
	if is_new:
		inst = CompanionInstance.new()
		inst.companion_data = data
		inst.recruitment_source = source
		inst.is_permanent = permanent
		inst.initialize_hp(p.max_hp, p.level)
		p.companion_roster.append(inst)
	if join_party and not inst in p.active_companions and p.active_companions.size() < MAX_ACTIVE and not inst.is_dead:
		p.active_companions.append(inst)
	if is_new and data.companion_id != &"":
		_last_tiers[data.companion_id] = get_tier(data.companion_id)
		GameState.set_flag(StringName("companion_recruited_%s" % data.companion_id), true)
	if notify and is_new and NotificationManager:
		NotificationManager.notify_companion(data.companion_name)
	_after_party_change(p)
	return inst


static func dismiss(companion_id: StringName, force: bool = false) -> bool:
	"""Remove a companion from the roster. Permanent companions stay unless
	forced. Relationship is kept (in GameState), so they can be found again."""
	var p = _player()
	var inst := find(companion_id, p)
	if inst == null:
		return false
	if inst.is_permanent and not force:
		push_warning("CompanionRoster.dismiss: %s is permanent (use force)" % companion_id)
		return false
	p.active_companions.erase(inst)
	p.companion_roster.erase(inst)
	_after_party_change(p)
	return true


static func can_activate(inst: CompanionInstance, player = null) -> bool:
	var p = player if player else _player()
	if p == null or inst == null or inst.is_dead:
		return false
	return inst in p.active_companions or p.active_companions.size() < MAX_ACTIVE


static func set_active(inst: CompanionInstance, active: bool, player = null) -> bool:
	"""Seat or unseat a roster companion. A downed companion can't be seated."""
	var p = player if player else _player()
	if p == null or inst == null or not inst in p.companion_roster:
		return false
	if active:
		if inst in p.active_companions:
			return true
		if not can_activate(inst, p):
			return false
		p.active_companions.append(inst)
	else:
		p.active_companions.erase(inst)
	_after_party_change(p)
	return true


static func upgrade_bond(companion_id: StringName) -> bool:
	"""The personal quest's ending: the bond die becomes the top die."""
	var inst := find(companion_id)
	if inst == null:
		return false
	inst.bond_upgraded = true
	GameState.request_autosave()
	return true


static func _after_party_change(p) -> void:
	CompanionSynergyManager.recalculate(p)
	var gr = GameManager.game_root if GameManager else null
	if gr and gr.companion_panel and not gr.is_in_combat:
		gr.companion_panel.refresh_from_player(p)
	GameState.request_autosave()

# ============================================================================
# TIERS AND THE BOND DIE
# ============================================================================

static func get_tier(companion_id: StringName) -> int:
	if companion_id == &"":
		return 0
	return rules().tier_for(GameState.get_relationship(companion_id))


static func get_tier_name(companion_id: StringName) -> String:
	return rules().tier_name(get_tier(companion_id))


static func bond_die_sides(data: CompanionData, inst: CompanionInstance = null) -> int:
	"""0 = no bond die for this companion."""
	if data == null or not data.uses_bond_die:
		return 0
	if data.fixed_die_sides > 0:
		return data.fixed_die_sides
	if data.companion_type == CompanionData.CompanionType.SUMMON:
		return 0
	var upgraded: bool = inst.bond_upgraded if inst else false
	return rules().die_sides_for(get_tier(data.companion_id), upgraded)


static func primary_stat_bonus(player, face: int = 0) -> int:
	"""The class's primary stat on a die showing `face` (the dice formula,
	same rule as the player's dice)."""
	if player == null:
		return 0
	var stat := "strength"
	if player.active_class and player.active_class.has_method("get_main_stat_name"):
		stat = player.active_class.get_main_stat_name()
	return CombatTuning.die_stat_bonus(player.get_total_stat(stat), face)


static func roll_bond(data: CompanionData, inst: CompanionInstance = null, player = null) -> Dictionary:
	"""{sides, roll, bonus, value}. value 0 when the companion has no bond die."""
	var sides := bond_die_sides(data, inst)
	if sides <= 0:
		return {"sides": 0, "roll": 0, "bonus": 0, "value": 0}
	var r := randi_range(1, sides)
	var b := primary_stat_bonus(player if player else _player(), r)
	return {"sides": sides, "roll": r, "bonus": b, "value": r + b}

# ============================================================================
# TEMPERAMENT
# ============================================================================

static func apply_temperament(data: CompanionData, event: String) -> int:
	"""Relationship change for this companion's temperament reacting to an
	event. Returns the delta applied."""
	if data == null or data.companion_id == &"" or data.companion_type != CompanionData.CompanionType.NPC:
		return 0
	var delta := rules().reaction_delta(data.get_temperament_key(), event, data.temperament_overrides)
	if delta != 0:
		GameState.modify_relationship(data.companion_id, delta)
		print("  [Companion] %s (%s) reacts to %s: %+d" % [data.companion_name, data.get_temperament_key(), event, delta])
	return delta


static func on_companion_downed(fallen: CompanionData, party: Array) -> void:
	"""Temperaments react to a companion going down: the fallen one (Proud),
	and anyone Bonded to them."""
	apply_temperament(fallen, "downed")
	if fallen == null:
		return
	for other in party:
		var d: CompanionData = other.companion_data if other is CompanionInstance else other
		if d and d != fallen and d.temperament == CompanionData.Temperament.BONDED \
				and d.bonded_to != &"" and d.bonded_to == fallen.companion_id:
			apply_temperament(d, "bonded_downed")

# ============================================================================
# RECOVERY
# ============================================================================

static func revive_instance(inst: CompanionInstance, hp_percent: float, player = null,
		wounded: bool = false, by_player: bool = false) -> bool:
	"""Bring a downed companion back outside combat (or record a mid-fight
	revive). Returns false if they weren't downed."""
	var p = player if player else _player()
	if inst == null or not inst.is_dead or p == null:
		return false
	inst.is_dead = false
	if wounded:
		inst.is_wounded = true
	var mx := inst.get_max_hp(p.max_hp, p.level)
	inst.current_hp = maxi(1, roundi(mx * clampf(hp_percent, 0.0, 1.0)))
	if by_player:
		apply_temperament(inst.companion_data, "revived_by_player")
	return true


static func revive_downed(hp_percent: float, by_player: bool = true) -> int:
	"""Revive every downed roster companion (out of combat: not Wounded).
	In a fight, revives the downed companions on the field (Wounded) instead.
	Returns how many came back."""
	var gr = GameManager.game_root if GameManager else null
	if gr and gr.is_in_combat and gr.has_method("get_combat_manager"):
		var cm = gr.get_combat_manager()
		if cm and cm.has_method("revive_downed_companions"):
			return cm.revive_downed_companions(hp_percent, by_player)
	var p = _player()
	if p == null:
		return 0
	var n := 0
	for inst in p.companion_roster:
		if revive_instance(inst, hp_percent, p, false, by_player):
			n += 1
	if n > 0:
		_after_party_change(p)
	return n


static func rest(player, heal_ratio: float, proper: bool = false, party_only: bool = false) -> void:
	"""A rest: every roster companion (party and camp) recovers heal_ratio of
	their missing HP (the same share the player recovered), downed ones get
	back up (Wary ones grumble first), and a proper rest (not a dungeon
	campfire) ends Wounded. REST_HEALING Trail perks add to the ratio."""
	if player == null:
		return
	var ratio := clampf(heal_ratio * (1.0 + trail_bonus(CompanionData.TrailPerk.REST_HEALING, player)), 0.0, 1.0)
	var who: Array = player.active_companions if party_only else player.companion_roster
	for inst in who:
		if inst == null or inst.companion_data == null:
			continue
		if proper and inst.is_wounded:
			inst.is_wounded = false
		var mx: int = inst.get_max_hp(player.max_hp, player.level)
		if inst.current_hp < 0:
			inst.current_hp = mx
		if inst.is_dead:
			apply_temperament(inst.companion_data, "rest_while_downed")
			inst.is_dead = false
			inst.current_hp = maxi(1, int(mx * ratio))
			print("  [Rest] %s back up at %d/%d HP" % [inst.get_display_name(), inst.current_hp, mx])
		elif ratio > 0.0 and inst.current_hp < mx:
			inst.current_hp = mini(mx, inst.current_hp + maxi(1, int((mx - inst.current_hp) * ratio)))
		inst.current_hp = mini(inst.current_hp, mx)
	_after_party_change(player)


static func full_recovery(player) -> void:
	"""Everyone back to full, Wounded cleared (the shellkeeper rescue)."""
	if player == null:
		return
	for inst in player.companion_roster:
		if inst and inst.companion_data:
			inst.is_dead = false
			inst.is_wounded = false
			inst.current_hp = inst.get_max_hp(player.max_hp, player.level)

# ============================================================================
# RELATIONSHIP NOTICES
# ============================================================================

static var _last_tiers: Dictionary = {}

static func on_relationship_changed(npc_id: StringName, old_value: int, new_value: int) -> void:
	"""A simple notice when a recruited companion's relationship moves, and
	when they reach a new tier."""
	var inst := find(npc_id)
	if inst == null or NotificationManager == null:
		return
	var cname := inst.get_display_name()
	var old_tier: int = _last_tiers.get(npc_id, rules().tier_for(old_value))
	var new_tier := rules().tier_for(new_value)
	_last_tiers[npc_id] = new_tier
	if new_tier != old_tier:
		NotificationManager.notify("%s: %s" % [cname, rules().tier_name(new_tier)], &"companion")
	else:
		NotificationManager.notify("%s %+d" % [cname, new_value - old_value], &"companion")

# ============================================================================
# TRAIL PERKS
# ============================================================================

static func trail_bonus(perk: int, player = null) -> float:
	"""Sum of this Trail perk over the active, standing party."""
	var p = player if player else _player()
	if p == null:
		return 0.0
	var total := 0.0
	for inst in p.active_companions:
		if inst == null or inst.is_dead or inst.companion_data == null:
			continue
		var d: CompanionData = inst.companion_data
		if d.trail_perk == perk and get_tier(d.companion_id) >= d.trail_perk_min_tier:
			total += d.trail_perk_value
	return total
