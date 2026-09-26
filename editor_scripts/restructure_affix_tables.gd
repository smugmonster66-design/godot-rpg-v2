# res://editor_scripts/restructure_affix_tables.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# Rewrites all 9 base affix table .tres files with restructured compositions.
# Uses pure text manipulation (no ResourceLoader) to avoid placeholder issues.
@tool
extends EditorScript

const AFFIX_SCRIPT_UID := "uid://c8ianog20smkw"  # affix.gd
const TABLE_SCRIPT_UID := "uid://b4fnmvnwdl0i2"  # affix_table.gd
const TABLE_DIR := "res://resources/affix_tables/base/"

# ============================================================================
# TABLE DEFINITIONS — restructured compositions
# ============================================================================

const TABLES: Dictionary = {
	"offense_tier_1": {
		"name": "Offense Tier 1",
		"description": "Flat stat and physical damage bonuses.",
		"affixes": [
			"res://resources/affixes/base/offense/tier_1/strength_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/agility_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/intellect_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/luck_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/global_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/slashing_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/blunt_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_1/piercing_damage_bonus.tres",
		],
	},
	"offense_tier_2": {
		"name": "Offense Tier 2",
		"description": "Elemental damage bonuses, status-on-hit procs, conditional damage.",
		"affixes": [
			"res://resources/affixes/base/offense/tier_2/fire_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_2/ice_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_2/shock_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_2/poison_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_2/shadow_damage_bonus.tres",
			"res://resources/affixes/base/offense/tier_2/bonus_flat_damage_on_hit.tres",
			"res://resources/affixes/base/offense/tier_2/apply_burn_on_hit.tres",
			"res://resources/affixes/base/offense/tier_2/apply_bleed_on_hit.tres",
			"res://resources/affixes/base/offense/tier_2/apply_chill_on_hit.tres",
			"res://resources/affixes/base/offense/tier_2/apply_poison_on_hit.tres",
			"res://resources/affixes/base/offense/tier_2/bonus_damage_per_die_used.tres",
			"res://resources/affixes/base/offense/tier_2/bonus_damage_per_action.tres",
			"res://resources/affixes/base/offense/tier_2/bonus_damage_on_kill.tres",
		],
	},
	"offense_tier_3": {
		"name": "Offense Tier 3",
		"description": "Multipliers, percentage damage, T3 debuffs, stat multipliers.",
		"affixes": [
			# Stat multipliers (promoted from T2)
			"res://resources/affixes/base/offense/tier_2/strength_multiplier.tres",
			"res://resources/affixes/base/offense/tier_2/agility_multiplier.tres",
			"res://resources/affixes/base/offense/tier_2/intellect_multiplier.tres",
			"res://resources/affixes/base/offense/tier_2/luck_multiplier.tres",
			# Original T3
			"res://resources/affixes/base/offense/tier_3/global_damage_multiplier.tres",
			"res://resources/affixes/base/offense/tier_3/lifesteal.tres",
			"res://resources/affixes/base/offense/tier_3/bonus_pct_damage_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_corrode_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_enfeeble_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_expose_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_slowed_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_shadow_on_hit.tres",
			"res://resources/affixes/base/offense/tier_3/apply_status_per_action.tres",
			"res://resources/affixes/base/offense/tier_3/apply_status_per_die_used.tres",
		],
	},
	"defense_tier_1": {
		"name": "Defense Tier 1",
		"description": "Flat defensive stats and starting resources.",
		"affixes": [
			"res://resources/affixes/base/defense/tier_1/armor_bonus.tres",
			"res://resources/affixes/base/defense/tier_1/defense_bonus.tres",
			"res://resources/affixes/base/defense/tier_1/health_bonus.tres",
			# Promoted from T2
			"res://resources/affixes/base/defense/tier_2/barrier_bonus.tres",
			"res://resources/affixes/base/defense/tier_1/heal_after_combat_flat.tres",
			"res://resources/affixes/base/defense/tier_2/starting_armor.tres",
			"res://resources/affixes/base/defense/tier_2/starting_barrier.tres",
		],
	},
	"defense_tier_2": {
		"name": "Defense Tier 2",
		"description": "Sustain procs, reactive defense, on-hit/kill healing.",
		"affixes": [
			"res://resources/affixes/base/defense/tier_2/heal_on_hit_taken_flat.tres",
			"res://resources/affixes/base/defense/tier_2/gain_armor_on_hit_taken.tres",
			"res://resources/affixes/base/defense/tier_2/gain_barrier_on_hit_taken.tres",
			"res://resources/affixes/base/defense/tier_2/hp_regen_on_turn_start.tres",
			"res://resources/affixes/base/defense/tier_2/barrier_regen_on_turn_start.tres",
			"res://resources/affixes/base/defense/tier_2/armor_regen_on_turn_start.tres",
			"res://resources/affixes/base/defense/tier_2/heal_on_turn_end.tres",
			"res://resources/affixes/base/defense/tier_2/barrier_on_turn_end.tres",
			"res://resources/affixes/base/defense/tier_2/bonus_armor_on_defend.tres",
			"res://resources/affixes/base/defense/tier_2/heal_on_defend.tres",
			"res://resources/affixes/base/defense/tier_2/heal_on_kill_flat.tres",
			"res://resources/affixes/base/defense/tier_2/armor_on_kill.tres",
			"res://resources/affixes/base/defense/tier_2/barrier_on_kill.tres",
			"res://resources/affixes/base/defense/tier_2/heal_after_combat_pct.tres",
		],
	},
	"defense_tier_3": {
		"name": "Defense Tier 3",
		"description": "Defense multiplier, percentage heals, thorns.",
		"affixes": [
			"res://resources/affixes/base/defense/tier_3/defense_multiplier.tres",
			"res://resources/affixes/base/defense/tier_3/heal_on_hit_taken_pct.tres",
			"res://resources/affixes/base/defense/tier_3/barrier_on_defend.tres",
			"res://resources/affixes/base/defense/tier_3/heal_on_kill_pct.tres",
			"res://resources/affixes/base/defense/tier_3/thorns_corrode.tres",
			"res://resources/affixes/base/defense/tier_3/thorns_enfeeble.tres",
			"res://resources/affixes/base/defense/tier_3/thorns_chill.tres",
			"res://resources/affixes/base/defense/tier_3/thorns_slowed.tres",
			"res://resources/affixes/base/defense/tier_3/thorns_apply_status.tres",
		],
	},
	"utility_tier_1": {
		"name": "Utility Tier 1",
		"description": "Mana and exploration bonuses.",
		"affixes": [
			"res://resources/affixes/base/utility/tier_1/mana_bonus.tres",
			"res://resources/affixes/base/utility/tier_1/gold_find_bonus.tres",
			"res://resources/affixes/base/utility/tier_1/xp_find_bonus.tres",
			"res://resources/affixes/base/utility/tier_1/loot_find_bonus.tres",
			"res://resources/affixes/base/utility/tier_1/rarity_find_bonus.tres",
		],
	},
	"utility_tier_2": {
		"name": "Utility Tier 2",
		"description": "Mana management and dice manipulation.",
		"affixes": [
			"res://resources/affixes/base/utility/tier_2/mana_regen_per_turn.tres",
			"res://resources/affixes/base/utility/tier_2/mana_cost_reduction.tres",
			"res://resources/affixes/base/utility/tier_2/mana_on_kill.tres",
			"res://resources/affixes/base/utility/tier_2/reroll_lowest_die.tres",
			"res://resources/affixes/base/utility/tier_2/bonus_die_value_flat.tres",
			"res://resources/affixes/base/utility/tier_2/heal_after_combat_mana.tres",
			"res://resources/affixes/base/utility/tier_2/mana_on_die_used.tres",
			"res://resources/affixes/base/utility/tier_2/extra_die_on_turn_start.tres",
		],
	},
	"utility_tier_3": {
		"name": "Utility Tier 3",
		"description": "Advanced dice manipulation and all elemental die grants.",
		"affixes": [
			# Manipulation / utility
			"res://resources/affixes/base/utility/tier_3/bonus_die_value_pct.tres",
			"res://resources/affixes/base/utility/tier_3/duplicate_die_on_max.tres",
			"res://resources/affixes/base/utility/tier_3/reroll_any_die.tres",
			"res://resources/affixes/base/utility/tier_3/convert_die_element.tres",
			"res://resources/affixes/base/utility/tier_3/granted_utility_action.tres",
			# D4 grants (files in tier_1/)
			"res://resources/affixes/base/utility/tier_1/grant_fire_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_ice_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_shock_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_poison_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_shadow_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_slashing_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_blunt_d4.tres",
			"res://resources/affixes/base/utility/tier_1/grant_piercing_d4.tres",
			# D6 grants (files in tier_2/)
			"res://resources/affixes/base/utility/tier_2/grant_fire_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_ice_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_shock_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_poison_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_shadow_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_slashing_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_blunt_d6.tres",
			"res://resources/affixes/base/utility/tier_2/grant_piercing_d6.tres",
			# D8 grants
			"res://resources/affixes/base/utility/tier_3/grant_fire_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_ice_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shock_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_poison_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shadow_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_slashing_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_blunt_d8.tres",
			"res://resources/affixes/base/utility/tier_3/grant_piercing_d8.tres",
			# D10 grants
			"res://resources/affixes/base/utility/tier_3/grant_fire_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_ice_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shock_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_poison_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shadow_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_slashing_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_blunt_d10.tres",
			"res://resources/affixes/base/utility/tier_3/grant_piercing_d10.tres",
			# D12 grants
			"res://resources/affixes/base/utility/tier_3/grant_fire_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_ice_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shock_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_poison_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_shadow_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_slashing_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_blunt_d12.tres",
			"res://resources/affixes/base/utility/tier_3/grant_piercing_d12.tres",
		],
	},
}


# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("  RESTRUCTURING AFFIX TABLES")
	print("=".repeat(60))

	var saved := 0
	var errors := 0

	for table_key in TABLES:
		var def: Dictionary = TABLES[table_key]
		var table_path: String = TABLE_DIR + table_key + ".tres"
		var affix_paths: Array = def["affixes"]

		# Read existing file to preserve the table UID
		var existing_text := _read_file(table_path)
		var table_uid := ""
		if not existing_text.is_empty():
			table_uid = _extract_uid_from_header(existing_text)

		# Validate all affix paths exist
		var missing := []
		for path in affix_paths:
			if not FileAccess.file_exists(path):
				missing.append(path)
		if not missing.is_empty():
			push_error("TABLE %s — missing affix files:" % table_key)
			for m in missing:
				push_error("  %s" % m)
			errors += 1
			continue

		# Read UIDs from each affix file
		var affix_uids: Array[Dictionary] = []
		var uid_ok := true
		for i in range(affix_paths.size()):
			var path: String = affix_paths[i]
			var affix_text := _read_file(path)
			var uid := _extract_uid_from_header(affix_text)
			affix_uids.append({"path": path, "uid": uid, "id": "affix_%d" % (i + 1)})
			if uid.is_empty():
				push_warning("  No UID for: %s" % path)

		# Build the .tres file text
		var load_steps: int = affix_uids.size() + 2  # +1 affix.gd script, +1 affix_table.gd script
		var uid_attr := ' uid="%s"' % table_uid if not table_uid.is_empty() else ""
		var lines: PackedStringArray = []

		lines.append('[gd_resource type="Resource" script_class="AffixTable" load_steps=%d format=3%s]' % [load_steps, uid_attr])
		lines.append("")

		# ext_resources: affix.gd script first
		lines.append('[ext_resource type="Script" uid="%s" path="res://resources/data/affix.gd" id="affix_script"]' % AFFIX_SCRIPT_UID)
		# affix_table.gd script
		lines.append('[ext_resource type="Script" uid="%s" path="res://resources/data/affix_table.gd" id="table_script"]' % TABLE_SCRIPT_UID)

		# Each affix resource
		for entry in affix_uids:
			var uid_part := ' uid="%s"' % entry["uid"] if not entry["uid"].is_empty() else ""
			lines.append('[ext_resource type="Resource"%s path="%s" id="%s"]' % [uid_part, entry["path"], entry["id"]])

		lines.append("")

		# [resource] section
		lines.append("[resource]")
		lines.append('script = ExtResource("table_script")')
		lines.append('table_name = "%s"' % def["name"])
		lines.append('description = "%s"' % def["description"])

		# Build the available_affixes array
		var refs: PackedStringArray = []
		for entry in affix_uids:
			refs.append('ExtResource("%s")' % entry["id"])
		lines.append('available_affixes = Array[ExtResource("affix_script")]([%s])' % ", ".join(refs))
		lines.append("")

		var text := "\n".join(lines)
		if _write_file(table_path, text):
			print("  %s: %d affixes" % [table_key, affix_paths.size()])
			saved += 1
		else:
			errors += 1

	print("\n" + "-".repeat(60))
	print("  RESULTS: %d tables written, %d errors" % [saved, errors])
	print("=".repeat(60) + "\n")


# ============================================================================
# HELPERS
# ============================================================================

func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _write_file(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Cannot write: %s" % path)
		return false
	f.store_string(text)
	f.close()
	return true


func _extract_uid_from_header(text: String) -> String:
	var idx := text.find('uid="')
	if idx == -1:
		return ""
	var start := idx + 5
	var end := text.find('"', start)
	if end == -1:
		return ""
	return text.substr(start, end - start)
