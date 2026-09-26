# res://resources/data/companion_bond_rules.gd
# The numbers behind the companion bond (Companion System, approved 2026-09-26):
# relationship tiers, the bond die, Wounded, and how each temperament reacts.
# One file for the whole game: res://resources/companions/companion_bond_rules.tres
# (the defaults below apply when that file is missing).
extends Resource
class_name CompanionBondRules

const RULES_PATH := "res://resources/companions/companion_bond_rules.tres"

# ============================================================================
# TIERS
# ============================================================================
@export_group("Tiers")
## Tier names, lowest first. Index = tier number (0 = Acquaintance).
@export var tier_names: Array[String] = ["Acquaintance", "Trusted", "Close", "Devoted"]
## Relationship needed for each tier (same thresholds as Relationships:
## FRIENDLY 20, ALLIED 50, DEVOTED 80).
@export var tier_thresholds: Array[int] = [0, 20, 50, 80]
## Bond die sides at each tier.
@export var tier_die_sides: Array[int] = [4, 6, 8, 10]
## Bond die after the companion's personal quest upgrades them
## (CompanionInstance.bond_upgraded).
@export var upgraded_die_sides: int = 12
## Tier that unlocks the Reaction (a companion's second trigger).
@export var reaction_min_tier: int = 1
## Tier that unlocks the Bond ability (once per fight by default).
@export var bond_ability_min_tier: int = 3
## Tier at which the personal quest can open (read by conditions:
## companion_tier:<id>:>=:2).
@export var quest_min_tier: int = 2

# ============================================================================
# FALLING
# ============================================================================
@export_group("Downed and Wounded")
## Max HP while Wounded (revived mid-fight), until the next proper rest.
@export_range(0.1, 1.0) var wounded_max_hp_percent: float = 0.75
## HP a mid-fight revive restores when the effect doesn't say (of max HP).
@export_range(0.05, 1.0) var revive_hp_percent: float = 0.3

# ============================================================================
# RELATIONSHIP
# ============================================================================
@export_group("Relationship")
## Relationship each active, standing companion gains per dungeon fight won.
@export var dungeon_fight_relationship: int = 2
## Temperament reactions: { temperament: { event: relationship delta } }.
## Events: downed, revived_mid_fight, revived_by_player,
## player_downed_while_standing, fight_end_downed, rest_while_downed,
## bonded_downed. A companion's own temperament_overrides win.
@export var temperament_reactions: Dictionary = {
	"proud": {"downed": -3, "revived_mid_fight": 5},
	"steadfast": {"player_downed_while_standing": -3},
	"loyal": {"revived_by_player": 3},
	"wary": {"fight_end_downed": -3, "rest_while_downed": -2},
	"bonded": {"bonded_downed": -2},
}

# ============================================================================
# API
# ============================================================================

static var _cached: CompanionBondRules = null

static func get_rules() -> CompanionBondRules:
	if _cached == null:
		if ResourceLoader.exists(RULES_PATH):
			_cached = load(RULES_PATH) as CompanionBondRules
		if _cached == null:
			_cached = CompanionBondRules.new()
	return _cached


func tier_for(relationship: int) -> int:
	var tier := 0
	for i in tier_thresholds.size():
		if relationship >= tier_thresholds[i]:
			tier = i
	return tier


func tier_name(tier: int) -> String:
	if tier >= 0 and tier < tier_names.size():
		return tier_names[tier]
	return "?"


func die_sides_for(tier: int, upgraded: bool = false) -> int:
	if upgraded and upgraded_die_sides > 0:
		return upgraded_die_sides
	if tier_die_sides.is_empty():
		return 4
	return tier_die_sides[clampi(tier, 0, tier_die_sides.size() - 1)]


func reaction_delta(temperament: String, event: String, overrides: Dictionary = {}) -> int:
	if overrides.has(event):
		return int(overrides[event])
	var table: Dictionary = temperament_reactions.get(temperament, {})
	return int(table.get(event, 0))
