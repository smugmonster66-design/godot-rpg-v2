# res://editor_scripts/update_dice_affix_descriptions.gd
# Batch-updates rollable dice affix descriptions for tooltip clarity.
# Run once from Editor > Run EditorScript, then verify in-game.
#
# TYPE SAFETY: no := from load()/Dictionary access. No emoji in print().
@tool
extends EditorScript

const BASE: String = "res://resources/dice_affixes/rollable/"

var _updated: int = 0
var _skipped: int = 0
var _missing: int = 0


func _run() -> void:
	print("")
	print("=".repeat(60))
	print("  DICE AFFIX DESCRIPTION AUDIT")
	print("=".repeat(60))

	# ── Value Tier 1 ────────────────────────────────────────────────
	_update(BASE + "value/tier_1/flat_value_bonus_small.tres",
		"+N to rolled value", "+N")
	_update(BASE + "value/tier_1/flat_value_bonus_first.tres",
		"+N if in first slot", "+N in first slot")
	_update(BASE + "value/tier_1/flat_value_bonus_last.tres",
		"+N if in last slot", "+N in last slot")
	_update(BASE + "value/tier_1/set_minimum_low.tres",
		"Always rolls at least N", "Min roll N")
	_update(BASE + "value/tier_1/grant_reroll.tres",
		"Grants a reroll", "1 reroll")

	# ── Value Tier 2 ────────────────────────────────────────────────
	_update(BASE + "value/tier_2/flat_value_bonus_medium.tres",
		"+N to rolled value", "+N")
	_update(BASE + "value/tier_2/auto_reroll_low.tres",
		"Auto-reroll below N", "Reroll if below N")
	_update(BASE + "value/tier_2/neighbor_value_boost.tres",
		"+N to both neighbors' values", "+N to neighbors")
	_update(BASE + "value/tier_2/roll_keep_highest.tres",
		"Roll extra, keep highest", "Roll twice, keep best")
	_update(BASE + "value/tier_2/copy_neighbor_value_flat.tres",
		"+N equal to half of left neighbor's value",
		"+50% of left die's value")

	# ── Value Tier 3 ────────────────────────────────────────────────
	_update(BASE + "value/tier_3/big_percent_bonus.tres",
		"+N% to rolled value", "+N%")
	_update(BASE + "value/tier_3/set_minimum_high.tres",
		"Always rolls at least N", "Min roll N")
	_update(BASE + "value/tier_3/duplicate_on_max.tres",
		"If max value rolled, duplicate this die",
		"Max roll: duplicate die")
	_update(BASE + "value/tier_3/boost_all_dice.tres",
		"+N to all dice values", "+N to all dice")

	# ── Positional Tier 1 ──────────────────────────────────────────
	_update(BASE + "positional/tier_1/boost_right_neighbor.tres",
		"+N to right neighbor's value", "+N to right die")
	_update(BASE + "positional/tier_1/boost_left_neighbor.tres",
		"+N to left neighbor's value", "+N to left die")
	_update(BASE + "positional/tier_1/even_slot_bonus.tres",
		"+N in even slots", "+N in even slots")
	_update(BASE + "positional/tier_1/odd_slot_bonus.tres",
		"+N in odd slots", "+N in odd slots")
	_update(BASE + "positional/tier_1/combat_start_boost.tres",
		"+N value at combat start", "+N on turn 1")

	# ── Positional Tier 2 ──────────────────────────────────────────
	_update(BASE + "positional/tier_2/element_match_bonus.tres",
		"+N if neighbor shares element", "+N if neighbor matches element")
	_update(BASE + "positional/tier_2/grant_extra_roll_on_use.tres",
		"Grant extra roll on use", "Reroll on use")
	_update(BASE + "positional/tier_2/copy_tags_from_neighbor.tres",
		"Copy tags from left neighbor", "Copy left die's tags")
	_update(BASE + "positional/tier_2/set_element_on_roll.tres",
		"Set element on roll", "Set element on roll")
	_update(BASE + "positional/tier_2/mana_gain_on_use.tres",
		"+N mana on use", "+N mana on use")

	# ── Positional Tier 3 ──────────────────────────────────────────
	_update(BASE + "positional/tier_3/boost_both_neighbors_percent.tres",
		"+N% to both neighbors' values", "+N% to neighbors")
	_update(BASE + "positional/tier_3/change_die_type_up.tres",
		"Upgrade die size by 1 step", "Upgrade die size")

	print("")
	print("=".repeat(60))
	print("  RESULTS: %d updated, %d skipped (already correct), %d missing" % [
		_updated, _skipped, _missing])
	print("=".repeat(60))


func _update(path: String, expected_old: String, new_desc: String) -> void:
	if not ResourceLoader.exists(path):
		print("  MISSING: %s" % path)
		_missing += 1
		return

	var res: Resource = load(path)
	if not res:
		print("  LOAD FAIL: %s" % path)
		_missing += 1
		return

	var current: String = res.get("description")
	if current == new_desc:
		_skipped += 1
		return

	if current != expected_old:
		# Description doesn't match what we expected -- update anyway but warn
		print("  WARN: %s" % path)
		print("    expected: \"%s\"" % expected_old)
		print("    found:    \"%s\"" % current)
		print("    setting:  \"%s\"" % new_desc)

	res.description = new_desc
	var err: int = ResourceSaver.save(res, path)
	if err == OK:
		print("  OK: %s -> \"%s\"" % [res.affix_name, new_desc])
		_updated += 1
	else:
		print("  SAVE ERR %d: %s" % [err, path])
		_missing += 1
