# res://editor_scripts/generate_dice_affix_pool.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Creates rollable DiceAffix .tres files + DiceAffixTable .tres files.
# These are the DiceAffixes that DieGenerator rolls onto equipment-granted dice,
# organized into 3 families × 3 tiers = 9 tables.
#
# Families:
#   value      — Flat/percent value mods, set min/max, reroll mechanics
#   combat     — Elemental damage, status effects, leech, element conversion
#   positional — Neighbor interactions, conditional bonuses, position-based
#
# Tiers (gated by item rarity):
#   T1 (Uncommon) — Simple, self-only, no conditions, flat values
#   T2 (Rare)     — Conditional, multi-target, introduces keywords, flat values
#   T3 (Epic)     — Build-defining, rule-breaking, big percentages
#
# TIERING RULES (Hybrid framework):
#   T1: Unconditional, single-target, predictable. Won't warp strategy.
#   T2: Introduces conditions OR multi-target OR a new keyword. Moderate power.
#   T3: Build-defining, breaks a fundamental rule, or high power budget.
#        If an effect would be build-defining at ANY value, it's T3.
#
# VALUE RULES:
#   T1/T2: Flat values only. Percentages on small die values are meaningless.
#   T3: Big percentages (50%+). At this tier they need to be felt.
#
# RARITY → TIER ACCESS (Option A — tier escalation):
#   Common:    []           — no rolled affixes
#   Uncommon:  [T1]         — one basic bonus
#   Rare:      [T1, T2]     — basic + conditional
#   Epic:      [T2, T3]     — two strong, no filler
#   Legendary: [T2, T3]     — two strong + unique inherent (separate system)
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
# AFTER RUNNING: Register DiceAffixTableRegistry as an autoload.
@tool
extends EditorScript

const AFFIX_DIR := "res://resources/dice_affixes/rollable/"
const TABLE_DIR := "res://resources/dice_affix_tables/"

var _created := 0
var _tables_created := 0
var _errors := 0

# Shorthand aliases
const T = DiceAffix.Trigger
const E = DiceAffix.EffectType
const P = DiceAffix.PositionRequirement
const N = DiceAffix.NeighborTarget
const VS = DiceAffix.ValueSource

func _run() -> void:
	print("══════════════════════════════════════════════════════")
	print("🎲  ROLLABLE DICE AFFIX POOL GENERATOR")
	print("══════════════════════════════════════════════════════")

	_ensure_dirs()
	var catalog := _build_catalog()

	print("\n📊 Catalog: %d affixes across 9 tables" % catalog.size())

	# Create affix .tres files and collect per-table arrays
	var table_contents: Dictionary = {}
	for family in ["value", "combat", "positional"]:
		for tier in [1, 2, 3]:
			table_contents["%s_%d" % [family, tier]] = []

	for entry in catalog:
		var affix := _create_affix(entry)
		if affix:
			var key := "%s_%d" % [entry.family, entry.tier]
			table_contents[key].append(affix)

	# Create DiceAffixTable .tres files
	print("\n── Creating DiceAffixTables ──")
	for key in table_contents:
		_create_table(key, table_contents[key])

	print("\n══════════════════════════════════════════════════════")
	print("✅  Affixes created: %d" % _created)
	print("✅  Tables created:  %d" % _tables_created)
	if _errors > 0:
		print("❌  Errors: %d" % _errors)
	print("══════════════════════════════════════════════════════")

	EditorInterface.get_resource_filesystem().scan()


# ============================================================================
# CATALOG
# ============================================================================

func _build_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []

	# ════════════════════════════════════════════════════════════════════
	# VALUE FAMILY
	# ════════════════════════════════════════════════════════════════════

	# ── Value Tier 1: Simple flat bonuses ──

	catalog.append({
		"file_name": "flat_value_bonus_small",
		"affix_name": "Sturdy", "family": "value", "tier": 1,
		"description": "+N to rolled value",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})
	catalog.append({
		"file_name": "flat_value_bonus_first",
		"affix_name": "Vanguard", "family": "value", "tier": 1,
		"description": "+N value when in first slot",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.FIRST,
		"effect_value_min": 2.0, "effect_value_max": 5.0,
	})
	catalog.append({
		"file_name": "flat_value_bonus_last",
		"affix_name": "Anchor", "family": "value", "tier": 1,
		"description": "+N value when in last slot",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.LAST,
		"effect_value_min": 2.0, "effect_value_max": 5.0,
	})
	catalog.append({
		"file_name": "set_minimum_low",
		"affix_name": "Dependable", "family": "value", "tier": 1,
		"description": "Always rolls at least N",
		"trigger": T.ON_ROLL, "effect_type": E.SET_MINIMUM_VALUE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 2.0, "effect_value_max": 3.0,
	})
	catalog.append({
		"file_name": "grant_reroll",
		"affix_name": "Lucky", "family": "value", "tier": 1,
		"description": "Grants a reroll",
		"trigger": T.ON_ROLL, "effect_type": E.GRANT_REROLL,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})

	# ── Value Tier 2: Higher flat budgets, conditions, multi-target ──

	catalog.append({
		"file_name": "flat_value_bonus_medium",
		"affix_name": "Bolstered", "family": "value", "tier": 2,
		"description": "+N to rolled value",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 2.0, "effect_value_max": 5.0,
	})
	catalog.append({
		"file_name": "auto_reroll_low",
		"affix_name": "Resolute", "family": "value", "tier": 2,
		"description": "Auto-reroll if below N",
		"trigger": T.ON_ROLL, "effect_type": E.AUTO_REROLL_LOW,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 2.0, "effect_value_max": 4.0,
	})
	catalog.append({
		"file_name": "neighbor_value_boost",
		"affix_name": "Inspiring", "family": "value", "tier": 2,
		"description": "+N to both neighbors' values",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.BOTH_NEIGHBORS, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})
	catalog.append({
		"file_name": "roll_keep_highest",
		"affix_name": "Fortunate", "family": "value", "tier": 2,
		"description": "Roll extra, keep highest",
		"trigger": T.ON_ROLL, "effect_type": E.ROLL_KEEP_HIGHEST,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})
	catalog.append({
		"file_name": "copy_neighbor_value_flat",
		"affix_name": "Mirrored", "family": "value", "tier": 2,
		"description": "+N equal to half of left neighbor's value",
		"trigger": T.ON_ROLL, "effect_type": E.COPY_NEIGHBOR_VALUE,
		"target": N.LEFT, "position": P.NOT_FIRST,
		"effect_value_min": 1.0, "effect_value_max": 4.0,
		"value_source": VS.NEIGHBOR_PERCENT,
		"effect_data": {"percent": 0.5},
	})

	# ── Value Tier 3: Big percentages, rule-breakers ──

	catalog.append({
		"file_name": "big_percent_bonus",
		"affix_name": "Titanic", "family": "value", "tier": 3,
		"description": "+N% to rolled value",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_PERCENT,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 0.50, "effect_value_max": 1.00,
	})
	catalog.append({
		"file_name": "set_minimum_high",
		"affix_name": "Ironclad", "family": "value", "tier": 3,
		"description": "Always rolls at least N",
		"trigger": T.ON_ROLL, "effect_type": E.SET_MINIMUM_VALUE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 4.0, "effect_value_max": 8.0,
	})
	catalog.append({
		"file_name": "duplicate_on_max",
		"affix_name": "Fracturing", "family": "value", "tier": 3,
		"description": "If max value rolled, duplicate this die",
		"trigger": T.ON_ROLL, "effect_type": E.DUPLICATE_ON_MAX,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})
	catalog.append({
		"file_name": "boost_all_dice",
		"affix_name": "Rallying", "family": "value", "tier": 3,
		"description": "+N to ALL other dice on roll",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.ALL_OTHERS, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})


	# ════════════════════════════════════════════════════════════════════
	# COMBAT FAMILY
	# ════════════════════════════════════════════════════════════════════

	# ── Combat Tier 1: Flat elemental damage, flat bonus ──

	catalog.append({
		"file_name": "add_fire_damage_flat",
		"affix_name": "Smoldering", "family": "combat", "tier": 1,
		"description": "+N flat fire damage on use",
		"trigger": T.ON_USE, "effect_type": E.ADD_DAMAGE_TYPE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
		"effect_data": {"type": "fire"},
	})
	catalog.append({
		"file_name": "add_ice_damage_flat",
		"affix_name": "Chilling", "family": "combat", "tier": 1,
		"description": "+N flat ice damage on use",
		"trigger": T.ON_USE, "effect_type": E.ADD_DAMAGE_TYPE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
		"effect_data": {"type": "ice"},
	})
	catalog.append({
		"file_name": "add_shock_damage_flat",
		"affix_name": "Sparking", "family": "combat", "tier": 1,
		"description": "+N flat shock damage on use",
		"trigger": T.ON_USE, "effect_type": E.ADD_DAMAGE_TYPE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
		"effect_data": {"type": "shock"},
	})
	catalog.append({
		"file_name": "add_poison_damage_flat",
		"affix_name": "Venomous", "family": "combat", "tier": 1,
		"description": "+N flat poison damage on use",
		"trigger": T.ON_USE, "effect_type": E.ADD_DAMAGE_TYPE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
		"effect_data": {"type": "poison"},
	})
	catalog.append({
		"file_name": "bonus_damage_flat",
		"affix_name": "Keen", "family": "combat", "tier": 1,
		"description": "+N bonus damage on use",
		"trigger": T.ON_USE, "effect_type": E.EMIT_BONUS_DAMAGE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 4.0,
		"effect_data": {"element": "NONE"},
	})

	# ── Combat Tier 2: Status effects, flat heals, flat splash ──

	catalog.append({
		"file_name": "grant_burn_status",
		"affix_name": "Igniting", "family": "combat", "tier": 2,
		"description": "Apply Burn on use",
		"trigger": T.ON_USE, "effect_type": E.GRANT_STATUS_EFFECT,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"status": "burn", "duration": 2, "stacks": 1},
	})
	catalog.append({
		"file_name": "grant_chill_status",
		"affix_name": "Freezing", "family": "combat", "tier": 2,
		"description": "Apply Chill on use",
		"trigger": T.ON_USE, "effect_type": E.GRANT_STATUS_EFFECT,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"status": "chill", "duration": 2, "stacks": 1},
	})
	catalog.append({
		"file_name": "grant_shock_status",
		"affix_name": "Jolting", "family": "combat", "tier": 2,
		"description": "Apply Shock on use",
		"trigger": T.ON_USE, "effect_type": E.GRANT_STATUS_EFFECT,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"status": "shock", "duration": 2, "stacks": 1},
	})
	catalog.append({
		"file_name": "heal_on_use_flat",
		"affix_name": "Siphoning", "family": "combat", "tier": 2,
		"description": "Heal N on use",
		"trigger": T.ON_USE, "effect_type": E.LEECH_HEAL,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
		"effect_data": {"mode": "flat"},
	})
	catalog.append({
		"file_name": "splash_damage_flat",
		"affix_name": "Erupting", "family": "combat", "tier": 2,
		"description": "+N splash damage to adjacent enemies",
		"trigger": T.ON_USE, "effect_type": E.EMIT_SPLASH_DAMAGE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 2.0, "effect_value_max": 5.0,
		"effect_data": {"element": "NONE", "mode": "flat"},
	})

	# ── Combat Tier 3: Big percentages, rule-breakers ──

	catalog.append({
		"file_name": "leech_heal_percent",
		"affix_name": "Vampiric", "family": "combat", "tier": 3,
		"description": "Heal N% of damage dealt",
		"trigger": T.ON_USE, "effect_type": E.LEECH_HEAL,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 0.30, "effect_value_max": 0.60,
		"effect_data": {"mode": "percent"},
	})
	catalog.append({
		"file_name": "chain_damage_percent",
		"affix_name": "Arcing", "family": "combat", "tier": 3,
		"description": "Chain N% damage to additional targets",
		"trigger": T.ON_USE, "effect_type": E.EMIT_CHAIN_DAMAGE,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 0.50, "effect_value_max": 0.80,
		"effect_data": {"element": "NONE", "chains": 1, "decay": 0.5},
	})
	catalog.append({
		"file_name": "ignore_resistance",
		"affix_name": "Penetrating", "family": "combat", "tier": 3,
		"description": "Bypass target resistance on use",
		"trigger": T.ON_USE, "effect_type": E.IGNORE_RESISTANCE,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"element": "ALL"},
	})
	catalog.append({
		"file_name": "mana_refund_on_use",
		"affix_name": "Attuned", "family": "combat", "tier": 3,
		"description": "Refund N% of last mana pull cost on use",
		"trigger": T.ON_USE, "effect_type": E.MANA_REFUND,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 0.25, "effect_value_max": 0.50,
	})


	# ════════════════════════════════════════════════════════════════════
	# POSITIONAL FAMILY
	# ════════════════════════════════════════════════════════════════════

	# ── Positional Tier 1: Simple position/neighbor, flat values ──

	catalog.append({
		"file_name": "boost_right_neighbor",
		"affix_name": "Leading", "family": "positional", "tier": 1,
		"description": "+N to right neighbor's value",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.RIGHT, "position": P.NOT_LAST,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})
	catalog.append({
		"file_name": "boost_left_neighbor",
		"affix_name": "Supporting", "family": "positional", "tier": 1,
		"description": "+N to left neighbor's value",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.LEFT, "position": P.NOT_FIRST,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})
	catalog.append({
		"file_name": "even_slot_bonus",
		"affix_name": "Rhythmic", "family": "positional", "tier": 1,
		"description": "+N value in even-numbered slots",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.EVEN_SLOTS,
		"effect_value_min": 2.0, "effect_value_max": 4.0,
	})
	catalog.append({
		"file_name": "odd_slot_bonus",
		"affix_name": "Syncopated", "family": "positional", "tier": 1,
		"description": "+N value in odd-numbered slots",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.ODD_SLOTS,
		"effect_value_min": 2.0, "effect_value_max": 4.0,
	})
	catalog.append({
		"file_name": "combat_start_boost",
		"affix_name": "Steadfast", "family": "positional", "tier": 1,
		"description": "+N value at combat start",
		"trigger": T.ON_COMBAT_START, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 3.0,
	})

	# ── Positional Tier 2: Conditional, keywords, flat values ──

	catalog.append({
		"file_name": "element_match_bonus",
		"affix_name": "Harmonized", "family": "positional", "tier": 2,
		"description": "+N if neighbor shares element",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_FLAT,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 2.0, "effect_value_max": 5.0,
		"condition_type": "NEIGHBOR_HAS_ELEMENT",
		"condition_element": "MATCH_SELF",
	})
	catalog.append({
		"file_name": "grant_extra_roll_on_use",
		"affix_name": "Echoing", "family": "positional", "tier": 2,
		"description": "Grant extra roll on use",
		"trigger": T.ON_USE, "effect_type": E.GRANT_EXTRA_ROLL,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})
	catalog.append({
		"file_name": "copy_tags_from_neighbor",
		"affix_name": "Absorbent", "family": "positional", "tier": 2,
		"description": "Copy tags from left neighbor",
		"trigger": T.ON_ROLL, "effect_type": E.COPY_TAGS,
		"target": N.LEFT, "position": P.NOT_FIRST,
		"effect_value": 1.0,
		"value_source": VS.SELF_TAGS,
	})
	catalog.append({
		"file_name": "set_element_on_roll",
		"affix_name": "Volatile", "family": "positional", "tier": 2,
		"description": "Randomize element each roll",
		"trigger": T.ON_ROLL, "effect_type": E.RANDOMIZE_ELEMENT,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"elements": ["FIRE", "ICE", "SHOCK", "POISON"]},
	})
	catalog.append({
		"file_name": "mana_gain_on_use",
		"affix_name": "Channeling", "family": "positional", "tier": 2,
		"description": "+N mana on use",
		"trigger": T.ON_USE, "effect_type": E.MANA_GAIN,
		"target": N.SELF, "position": P.ANY,
		"effect_value_min": 1.0, "effect_value_max": 5.0,
	})

	# ── Positional Tier 3: Big percentages, rule-breakers ──

	catalog.append({
		"file_name": "boost_both_neighbors_percent",
		"affix_name": "Commanding", "family": "positional", "tier": 3,
		"description": "+N% to both neighbors' values",
		"trigger": T.ON_ROLL, "effect_type": E.MODIFY_VALUE_PERCENT,
		"target": N.BOTH_NEIGHBORS, "position": P.ANY,
		"effect_value_min": 0.50, "effect_value_max": 0.80,
	})
	catalog.append({
		"file_name": "change_die_type_up",
		"affix_name": "Ascendant", "family": "positional", "tier": 3,
		"description": "On combat start, upgrade die type",
		"trigger": T.ON_COMBAT_START, "effect_type": E.CHANGE_DIE_TYPE,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
		"effect_data": {"upgrade_steps": 1},
	})
	catalog.append({
		"file_name": "destroy_for_power",
		"affix_name": "Sacrificial", "family": "positional", "tier": 3,
		"description": "Destroy self on use, boost all other dice",
		"trigger": T.ON_USE, "effect_type": E.DESTROY_SELF,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})
	catalog.append({
		"file_name": "lock_die",
		"affix_name": "Persistent", "family": "positional", "tier": 3,
		"description": "This die is not consumed on use",
		"trigger": T.PASSIVE, "effect_type": E.LOCK_DIE,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})
	catalog.append({
		"file_name": "lock_die_and_boost",
		"affix_name": "Eternal", "family": "positional", "tier": 3,
		"description": "Not consumed + stacking bonus per reuse",
		"trigger": T.PASSIVE, "effect_type": E.LOCK_DIE,
		"target": N.SELF, "position": P.ANY,
		"effect_value": 1.0,
	})


	# ── VERIFICATION ──

	var counts := {}
	for entry in catalog:
		var key := "%s_%d" % [entry.family, entry.tier]
		counts[key] = counts.get(key, 0) + 1

	print("\n📊 Catalog breakdown:")
	for key in counts:
		print("  %s: %d" % [key, counts[key]])
	print("  TOTAL: %d" % catalog.size())

	return catalog


# ============================================================================
# AFFIX CREATION
# ============================================================================

func _create_affix(entry: Dictionary) -> DiceAffix:
	var family: String = entry.family
	var tier: int = entry.tier
	var file_name: String = entry.file_name
	var dir_path := "%s%s/tier_%d/" % [AFFIX_DIR, family, tier]
	var path := dir_path + file_name + ".tres"

	var affix: DiceAffix = null
	if ResourceLoader.exists(path):
		affix = load(path)
	if affix == null:
		affix = DiceAffix.new()

	# Core
	affix.affix_name = entry.affix_name
	affix.description = entry.description
	affix.affix_tier = tier
	affix.show_in_summary = true

	# Trigger
	affix.trigger = entry.get("trigger", T.ON_ROLL)

	# Position
	affix.position_requirement = entry.get("position", P.ANY)

	# Target
	affix.neighbor_target = entry.get("target", N.SELF)

	# Effect
	affix.effect_type = entry.get("effect_type", E.MODIFY_VALUE_FLAT)

	# Value — static or scaled
	if entry.has("effect_value_min"):
		affix.effect_value_min = entry.effect_value_min
		affix.effect_value_max = entry.effect_value_max
		affix.effect_value = (entry.effect_value_min + entry.effect_value_max) / 2.0
	elif entry.has("effect_value"):
		affix.effect_value = entry.effect_value
		affix.effect_value_min = 0.0
		affix.effect_value_max = 0.0

	# Value source
	affix.value_source = entry.get("value_source", VS.STATIC)

	# Effect data
	if entry.has("effect_data"):
		affix.effect_data = entry.effect_data

	# Condition
	if entry.has("condition_type"):
		var cond := DiceAffixCondition.new()
		var cond_name: String = entry.condition_type
		for ct in DiceAffixCondition.Type.values():
			if DiceAffixCondition.Type.keys()[ct] == cond_name:
				cond.type = ct
				break
		if entry.has("condition_element"):
			cond.condition_element = entry.condition_element
		if entry.has("condition_threshold"):
			cond.threshold = entry.condition_threshold
		affix.condition = cond

	# Save
	var err := ResourceSaver.save(affix, path)
	if err == OK:
		_created += 1
		print("  ✅ %s → %s" % [entry.affix_name, path.get_file()])
		return affix
	else:
		_errors += 1
		push_error("Failed to save: %s (%s)" % [path, error_string(err)])
		return null


# ============================================================================
# TABLE CREATION
# ============================================================================

func _create_table(key: String, affixes: Array) -> void:
	var parts := key.split("_")
	var path := "%s%s_tier_%s.tres" % [TABLE_DIR, parts[0], parts[1]]

	var table: DiceAffixTable = null
	if ResourceLoader.exists(path):
		table = load(path)
	if table == null:
		table = DiceAffixTable.new()

	var family_name: String = parts[0]
	var tier_num: String = parts[1]

	table.table_name = "%s Tier %s" % [family_name.capitalize(), tier_num]
	table.description = "Rollable dice affixes — %s family, tier %s." % [family_name, tier_num]

	var typed_affixes: Array[DiceAffix] = []
	typed_affixes.assign(affixes)
	table.available_affixes = typed_affixes

	var err := ResourceSaver.save(table, path)
	if err == OK:
		_tables_created += 1
		print("  📋 %s: %d affixes → %s" % [table.table_name, affixes.size(), path.get_file()])
	else:
		_errors += 1
		push_error("Failed to save table: %s" % path)


# ============================================================================
# DIRECTORY SETUP
# ============================================================================

func _ensure_dirs() -> void:
	for family in ["value", "combat", "positional"]:
		for tier in [1, 2, 3]:
			DirAccess.make_dir_recursive_absolute(
				"%s%s/tier_%d/" % [AFFIX_DIR, family, tier])
	DirAccess.make_dir_recursive_absolute(TABLE_DIR)
