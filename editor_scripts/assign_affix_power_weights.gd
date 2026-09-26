# res://editor_scripts/assign_affix_power_weights.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# Assigns power_weight values to all base equipment affixes.
# Baseline: ARMOR_BONUS at max roll (80 armor) = 100 power_weight.
# Weights represent power at MAX roll; get_affix_power() scales by position and proc_chance.
@tool
extends EditorScript

# ============================================================================
# WEIGHT MAP: resource path → power_weight
# ============================================================================
const WEIGHT_MAP: Dictionary = {
	# ═══════════════════════════════════════════════════════════════════════
	# OFFENSE TIER 1 — Flat stat/damage bonuses
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/offense/tier_1/strength_bonus.tres": 62.0,
	"res://resources/affixes/base/offense/tier_1/agility_bonus.tres": 62.0,
	"res://resources/affixes/base/offense/tier_1/intellect_bonus.tres": 62.0,
	"res://resources/affixes/base/offense/tier_1/luck_bonus.tres": 62.0,
	"res://resources/affixes/base/offense/tier_1/global_damage_bonus.tres": 55.0,
	"res://resources/affixes/base/offense/tier_1/slashing_damage_bonus.tres": 40.0,
	"res://resources/affixes/base/offense/tier_1/blunt_damage_bonus.tres": 40.0,
	"res://resources/affixes/base/offense/tier_1/piercing_damage_bonus.tres": 40.0,

	# ═══════════════════════════════════════════════════════════════════════
	# OFFENSE TIER 2 — Elemental damage, status-on-hit procs, damage procs
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/offense/tier_2/fire_damage_bonus.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/ice_damage_bonus.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/shock_damage_bonus.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/poison_damage_bonus.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/shadow_damage_bonus.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/bonus_flat_damage_on_hit.tres": 45.0,
	"res://resources/affixes/base/offense/tier_2/apply_burn_on_hit.tres": 85.0,
	"res://resources/affixes/base/offense/tier_2/apply_bleed_on_hit.tres": 85.0,
	"res://resources/affixes/base/offense/tier_2/apply_chill_on_hit.tres": 85.0,
	"res://resources/affixes/base/offense/tier_2/apply_poison_on_hit.tres": 80.0,
	"res://resources/affixes/base/offense/tier_2/bonus_damage_per_die_used.tres": 55.0,
	"res://resources/affixes/base/offense/tier_2/bonus_damage_per_action.tres": 50.0,
	"res://resources/affixes/base/offense/tier_2/bonus_damage_on_kill.tres": 40.0,
	# Stat multipliers — currently in T2 file path, moving to T3 table
	"res://resources/affixes/base/offense/tier_2/strength_multiplier.tres": 130.0,
	"res://resources/affixes/base/offense/tier_2/agility_multiplier.tres": 130.0,
	"res://resources/affixes/base/offense/tier_2/intellect_multiplier.tres": 130.0,
	"res://resources/affixes/base/offense/tier_2/luck_multiplier.tres": 130.0,

	# ═══════════════════════════════════════════════════════════════════════
	# OFFENSE TIER 3 — Multipliers, % damage, T3 debuffs, complex procs
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/offense/tier_3/global_damage_multiplier.tres": 160.0,
	"res://resources/affixes/base/offense/tier_3/lifesteal.tres": 140.0,
	"res://resources/affixes/base/offense/tier_3/bonus_pct_damage_on_hit.tres": 120.0,
	"res://resources/affixes/base/offense/tier_3/apply_corrode_on_hit.tres": 110.0,
	"res://resources/affixes/base/offense/tier_3/apply_enfeeble_on_hit.tres": 110.0,
	"res://resources/affixes/base/offense/tier_3/apply_expose_on_hit.tres": 110.0,
	"res://resources/affixes/base/offense/tier_3/apply_shadow_on_hit.tres": 100.0,
	"res://resources/affixes/base/offense/tier_3/apply_slowed_on_hit.tres": 95.0,
	"res://resources/affixes/base/offense/tier_3/apply_status_per_action.tres": 100.0,
	"res://resources/affixes/base/offense/tier_3/apply_status_per_die_used.tres": 105.0,

	# ═══════════════════════════════════════════════════════════════════════
	# DEFENSE TIER 1 — Flat defensive stats
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/defense/tier_1/armor_bonus.tres": 100.0,
	"res://resources/affixes/base/defense/tier_1/defense_bonus.tres": 75.0,
	"res://resources/affixes/base/defense/tier_1/health_bonus.tres": 110.0,
	"res://resources/affixes/base/defense/tier_1/heal_after_combat_flat.tres": 35.0,

	# ═══════════════════════════════════════════════════════════════════════
	# DEFENSE TIER 2 — Sustain procs, reactive defense
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/defense/tier_2/barrier_bonus.tres": 90.0,
	"res://resources/affixes/base/defense/tier_2/heal_on_hit_taken_flat.tres": 55.0,
	"res://resources/affixes/base/defense/tier_2/gain_armor_on_hit_taken.tres": 50.0,
	"res://resources/affixes/base/defense/tier_2/gain_barrier_on_hit_taken.tres": 50.0,
	"res://resources/affixes/base/defense/tier_2/hp_regen_on_turn_start.tres": 65.0,
	"res://resources/affixes/base/defense/tier_2/barrier_regen_on_turn_start.tres": 50.0,
	"res://resources/affixes/base/defense/tier_2/armor_regen_on_turn_start.tres": 50.0,
	"res://resources/affixes/base/defense/tier_2/heal_on_turn_end.tres": 55.0,
	"res://resources/affixes/base/defense/tier_2/barrier_on_turn_end.tres": 45.0,
	"res://resources/affixes/base/defense/tier_2/starting_armor.tres": 60.0,
	"res://resources/affixes/base/defense/tier_2/starting_barrier.tres": 45.0,
	"res://resources/affixes/base/defense/tier_2/bonus_armor_on_defend.tres": 55.0,
	"res://resources/affixes/base/defense/tier_2/heal_on_defend.tres": 55.0,
	"res://resources/affixes/base/defense/tier_2/heal_on_kill_flat.tres": 40.0,
	"res://resources/affixes/base/defense/tier_2/armor_on_kill.tres": 35.0,
	"res://resources/affixes/base/defense/tier_2/barrier_on_kill.tres": 35.0,
	"res://resources/affixes/base/defense/tier_2/heal_after_combat_pct.tres": 45.0,

	# ═══════════════════════════════════════════════════════════════════════
	# DEFENSE TIER 3 — Multipliers, % heals, thorns
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/defense/tier_3/defense_multiplier.tres": 150.0,
	"res://resources/affixes/base/defense/tier_3/heal_on_hit_taken_pct.tres": 130.0,
	"res://resources/affixes/base/defense/tier_3/barrier_on_defend.tres": 90.0,
	"res://resources/affixes/base/defense/tier_3/heal_on_kill_pct.tres": 85.0,
	"res://resources/affixes/base/defense/tier_3/thorns_corrode.tres": 100.0,
	"res://resources/affixes/base/defense/tier_3/thorns_enfeeble.tres": 100.0,
	"res://resources/affixes/base/defense/tier_3/thorns_chill.tres": 95.0,
	"res://resources/affixes/base/defense/tier_3/thorns_slowed.tres": 90.0,
	"res://resources/affixes/base/defense/tier_3/thorns_apply_status.tres": 85.0,

	# ═══════════════════════════════════════════════════════════════════════
	# UTILITY TIER 1 — Mana, exploration bonuses
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/utility/tier_1/mana_bonus.tres": 70.0,
	"res://resources/affixes/base/utility/tier_1/gold_find_bonus.tres": 25.0,
	"res://resources/affixes/base/utility/tier_1/xp_find_bonus.tres": 25.0,
	"res://resources/affixes/base/utility/tier_1/loot_find_bonus.tres": 30.0,
	"res://resources/affixes/base/utility/tier_1/rarity_find_bonus.tres": 30.0,
	# Elemental D4 grants — file lives in tier_1 but assigned to T3 table
	"res://resources/affixes/base/utility/tier_1/grant_fire_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_ice_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_shock_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_poison_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_shadow_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_slashing_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_blunt_d4.tres": 20.0,
	"res://resources/affixes/base/utility/tier_1/grant_piercing_d4.tres": 20.0,

	# ═══════════════════════════════════════════════════════════════════════
	# UTILITY TIER 2 — Mana management, dice manipulation
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/utility/tier_2/mana_regen_per_turn.tres": 75.0,
	"res://resources/affixes/base/utility/tier_2/mana_cost_reduction.tres": 90.0,
	"res://resources/affixes/base/utility/tier_2/mana_on_kill.tres": 55.0,
	"res://resources/affixes/base/utility/tier_2/mana_on_die_used.tres": 65.0,
	"res://resources/affixes/base/utility/tier_2/reroll_lowest_die.tres": 65.0,
	"res://resources/affixes/base/utility/tier_2/bonus_die_value_flat.tres": 60.0,
	"res://resources/affixes/base/utility/tier_2/starting_mana.tres": 50.0,
	"res://resources/affixes/base/utility/tier_2/extra_die_on_turn_start.tres": 80.0,
	"res://resources/affixes/base/utility/tier_2/heal_after_combat_mana.tres": 30.0,
	# Elemental D6 grants — file lives in tier_2 but assigned to T3 table
	"res://resources/affixes/base/utility/tier_2/grant_fire_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_ice_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_shock_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_poison_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_shadow_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_slashing_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_blunt_d6.tres": 35.0,
	"res://resources/affixes/base/utility/tier_2/grant_piercing_d6.tres": 35.0,

	# ═══════════════════════════════════════════════════════════════════════
	# UTILITY TIER 3 — Advanced manipulation, die grants D8-D12
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base/utility/tier_3/bonus_die_value_pct.tres": 130.0,
	"res://resources/affixes/base/utility/tier_3/duplicate_die_on_max.tres": 120.0,
	"res://resources/affixes/base/utility/tier_3/reroll_any_die.tres": 80.0,
	"res://resources/affixes/base/utility/tier_3/convert_die_element.tres": 60.0,
	"res://resources/affixes/base/utility/tier_3/granted_utility_action.tres": 100.0,
	# D8 grants
	"res://resources/affixes/base/utility/tier_3/grant_fire_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_ice_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_shock_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_poison_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_shadow_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_slashing_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_blunt_d8.tres": 50.0,
	"res://resources/affixes/base/utility/tier_3/grant_piercing_d8.tres": 50.0,
	# D10 grants
	"res://resources/affixes/base/utility/tier_3/grant_fire_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_ice_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_shock_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_poison_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_shadow_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_slashing_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_blunt_d10.tres": 70.0,
	"res://resources/affixes/base/utility/tier_3/grant_piercing_d10.tres": 70.0,
	# D12 grants
	"res://resources/affixes/base/utility/tier_3/grant_fire_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_ice_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_shock_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_poison_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_shadow_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_slashing_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_blunt_d12.tres": 90.0,
	"res://resources/affixes/base/utility/tier_3/grant_piercing_d12.tres": 90.0,

	# ═══════════════════════════════════════════════════════════════════════
	# MISC / SPECIAL
	# ═══════════════════════════════════════════════════════════════════════
	"res://resources/affixes/base_stats/inherent_defense.tres": 100.0,
	"res://resources/affixes/weapon/legendary/flareburst_affix.tres": 120.0,
	"res://resources/affixes/gloves/second/fire_fist_affix.tres": 80.0,
}


func _run() -> void:
	var updated: int = 0
	var skipped: int = 0
	var errors: int = 0
	var not_found: int = 0

	print("\n" + "=".repeat(60))
	print("  ASSIGNING AFFIX POWER WEIGHTS")
	print("=".repeat(60))

	for path in WEIGHT_MAP:
		if not ResourceLoader.exists(path):
			push_warning("NOT FOUND: %s" % path)
			not_found += 1
			continue

		var res = load(path)
		if not res:
			push_error("LOAD FAILED: %s" % path)
			errors += 1
			continue

		var weight: float = WEIGHT_MAP[path]

		# Check if already set to this value
		if is_equal_approx(res.power_weight, weight):
			skipped += 1
			continue

		res.power_weight = weight
		var err = ResourceSaver.save(res, path)
		if err != OK:
			push_error("SAVE FAILED: %s (error %d)" % [path, err])
			errors += 1
		else:
			updated += 1
			print("  SET %s → %.1f" % [path.get_file(), weight])

	print("\n" + "-".repeat(60))
	print("  RESULTS: %d updated, %d unchanged, %d not found, %d errors" % [
		updated, skipped, not_found, errors])
	print("  Total entries in map: %d" % WEIGHT_MAP.size())
	print("=".repeat(60) + "\n")
