# ============================================================================
# CHUNK 3 — TIERS 5–10
# ============================================================================
#
# INSTRUCTIONS: In the generator file from Chunk 2, REPLACE the stub functions
# (the ones that just say "pass  # CHUNK 3") with the full implementations
# below. Copy each function body over its stub.
#
# Skills in this chunk:
#   T5:  Inferno, Eruption (Action), Tempered Steel                    = 3
#   T6:  Burning Vengeance (Action), ★Flashpoint, Firestorm,
#        ★Forge Bond, Cauterize (Action)                               = 5
#   T7:  Detonate (Action), Cinder Storm (Action),
#        Radiance (Action), Ember Link                                  = 4
#   T8:  ★Pyroclastic Flow, Volcanic Core (Action), ★Crucible's Gift  = 3
#   T9:  Eternal Flame (Action), Ironfire Stance (Action)              = 2
#   T10: Conflagration                                                  = 1
#                                                                Total = 18
# ============================================================================


# ============================================================================
# TIER 5 — Inferno, Eruption, Tempered Steel (3 skills)
# ============================================================================

func _create_tier_5():
	print("\n🔥 Tier 5...")

	# --- Inferno (Col 1): D10 unlock. Burn threshold 4→3→2. 3 ranks. ---
	var inf_size := _make_affix("Inferno: D10 Unlock", "Unlocks D10 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"], 0.0, {"die_size": 10})
	_save_affix(inf_size, "inferno", "inferno_r1_size_affix")

	var inf_thresh_r1 := _make_affix("Inferno I: Threshold -1",
		"Burn explodes at 4 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r1, "inferno", "inferno_r1_thresh_affix")

	var inf_thresh_r2 := _make_affix("Inferno II: Threshold -2",
		"Burn explodes at 3 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r2, "inferno", "inferno_r2_thresh_affix")

	var inf_thresh_r3 := _make_affix("Inferno III: Threshold -3",
		"Burn explodes at 2 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r3, "inferno", "inferno_r3_thresh_affix")

	var inferno := _make_skill(
		"flame_inferno", "Inferno",
		"Unlocks [color=orange]D10[/color]. Burn threshold reduced to [color=red]4/3/2[/color].",
		5, 1, _tier_pts(5),
		{1: [inf_size, inf_thresh_r1], 2: [inf_thresh_r2], 3: [inf_thresh_r3]})
	_save_skill(inferno, "flame_inferno")

	# --- Eruption (Col 3): ACTION — 2 dice, ALL_ENEMIES, fire ×0.6. 1 rank. ---
	var erupt_eff := _make_action_effect("Eruption Blast",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.6, 2)
	_save_effect(erupt_eff, "eruption_blast_eff")

	var erupt_act := _make_action("flame_eruption", "Eruption",
		"Hurl fire at all enemies for 60% dice damage.",
		2, [erupt_eff])
	_save_action(erupt_act, "eruption_action")

	var erupt_grant := _make_affix("Eruption: Grant Action",
		"Grants the Eruption action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action"], 0.0,
		{"action_id": "flame_eruption"})
	erupt_grant.granted_action = erupt_act
	_save_affix(erupt_grant, "eruption", "eruption_r1_affix")

	var eruption := _make_skill(
		"flame_eruption", "Eruption",
		"[color=yellow]ACTION:[/color] 2 dice → [color=orange]fire[/color] damage to ALL enemies (×0.6).",
		5, 3, _tier_pts(5),
		{1: [erupt_grant]})
	_save_skill(eruption, "flame_eruption")

	# --- Tempered Steel (Col 5): +2/+4/+6 armor per fire die used. 3 ranks. ---
	var ts_r1 := _make_affix("Tempered Steel I", "+2 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r1, "tempered_steel", "tempered_steel_r1_affix")

	var ts_r2 := _make_affix("Tempered Steel II", "+4 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r2, "tempered_steel", "tempered_steel_r2_affix")

	var ts_r3 := _make_affix("Tempered Steel III", "+6 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r3, "tempered_steel", "tempered_steel_r3_affix")

	var tempered_steel := _make_skill(
		"flame_tempered_steel", "Tempered Steel",
		"+2/+4/+6 [color=gray]armor[/color] per fire die used.",
		5, 5, _tier_pts(5),
		{1: [ts_r1], 2: [ts_r2], 3: [ts_r3]})
	_save_skill(tempered_steel, "flame_tempered_steel")


# ============================================================================
# TIER 6 — Burning Vengeance, ★Flashpoint, Firestorm, ★Forge Bond, Cauterize
# ============================================================================

func _create_tier_6():
	print("\n🔥 Tier 6...")

	# --- Burning Vengeance (Col 0): ACTION — 1 die, SINGLE_ENEMY, fire ×0.5
	#     + apply Burn stacks = die value. 1 rank. ---
	var bv_dmg_eff := _make_action_effect("Burning Vengeance: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.5, 1)
	_save_effect(bv_dmg_eff, "burning_vengeance_dmg_eff")

	# Load burn status for the ADD_STATUS effect
	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var bv_burn_eff := _make_action_effect("Burning Vengeance: Apply Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 1)  # stack_count=1 as base; design says "stacks = die value"
	# NOTE: The stack_count here is a base of 1. The design intends stacks = die_total.
	# This requires the combat_manager to resolve value_source: DICE_TOTAL at runtime.
	# For now we set stack_count to a baseline; the exact dynamic resolution depends
	# on your ActionEffect execution pipeline supporting value_source on stack_count.
	_save_effect(bv_burn_eff, "burning_vengeance_burn_eff")

	var bv_act := _make_action("flame_burning_vengeance", "Burning Vengeance",
		"Strike an enemy for 50% fire damage and inflict Burn stacks equal to die value.",
		1, [bv_dmg_eff, bv_burn_eff],
		Action.ChargeType.LIMITED_PER_TURN, 2)
	_save_action(bv_act, "burning_vengeance_action")

	var bv_grant := _make_affix("Burning Vengeance: Grant Action",
		"Grants Burning Vengeance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_burning_vengeance"})
	bv_grant.granted_action = bv_act
	_save_affix(bv_grant, "burning_vengeance", "burning_vengeance_r1_affix")

	var burning_vengeance := _make_skill(
		"flame_burning_vengeance", "Burning Vengeance",
		"[color=yellow]ACTION:[/color] 1 die → 50% [color=orange]fire[/color] + [color=red]Burn[/color] stacks = die value.",
		6, 0, _tier_pts(6),
		{1: [bv_grant]})
	_save_skill(burning_vengeance, "flame_burning_vengeance")

	# --- ★ Flashpoint (Col 2): Burn explosion → 50% splash to others. 1 rank. ---
	# Crossover: Requires Inferno r1 + Pyroclasm
	# Implementation: tag-based proc in combat_manager (Chunk 1 Patch 7)
	var flash_affix := _make_affix("Flashpoint",
		"When Burn explodes, splash 50% burst damage to other enemies.",
		Affix.Category.PROC,
		["mage", "flame", "flashpoint", "burn_explosion_splash"], 0.5)
	_save_affix(flash_affix, "flashpoint", "flashpoint_r1_affix")

	var flashpoint := _make_skill(
		"flame_flashpoint", "★ Flashpoint",
		"Burn explosions splash [color=yellow]50%[/color] burst damage to other enemies.",
		6, 2, _tier_pts(6),
		{1: [flash_affix]})
	_save_skill(flashpoint, "flame_flashpoint")

	# --- Firestorm (Col 3): Fire dice chain 20%/35% to 2 enemies. 2 ranks. ---
	var da_chain_r1 := _make_dice_affix(
		"Firestorm I: Chain", "Fire dice chain 20% to 2 enemies.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.2,
		{"element": "FIRE", "chains": 2, "decay": 1.0})
	_save(da_chain_r1, DICE_AFFIX_DIR + "da_firestorm_r1.tres")

	var fs_r1 := _make_mana_die_affix_wrapper(
		"Firestorm I", "Fire dice chain 20% damage to 2 enemies.",
		["mage", "flame", "mana_die_affix", "chain"], da_chain_r1)
	_save_affix(fs_r1, "firestorm", "firestorm_r1_affix")

	var da_chain_r2 := _make_dice_affix(
		"Firestorm II: Chain", "Fire dice chain 35% to 2 enemies.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.35,
		{"element": "FIRE", "chains": 2, "decay": 1.0})
	_save(da_chain_r2, DICE_AFFIX_DIR + "da_firestorm_r2.tres")

	var fs_r2 := _make_mana_die_affix_wrapper(
		"Firestorm II", "Fire dice chain 35% damage to 2 enemies.",
		["mage", "flame", "mana_die_affix", "chain"], da_chain_r2)
	_save_affix(fs_r2, "firestorm", "firestorm_r2_affix")

	var firestorm := _make_skill(
		"flame_firestorm", "Firestorm",
		"Fire dice chain [color=yellow]20%/35%[/color] damage to 2 enemies.",
		6, 3, _tier_pts(6),
		{1: [fs_r1], 2: [fs_r2]})
	_save_skill(firestorm, "flame_firestorm")

	# --- ★ Forge Bond (Col 4): Fire dice in FIRST/LAST +25% damage. 1 rank. ---
	# Crossover: Requires Conflagrant Surge r2 + Kindling
	var da_forge_bond := _make_dice_affix(
		"Forge Bond: Position Bonus",
		"Fire die in first or last position deals +25% damage.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 0.25,
		{"element": "FIRE", "percent": 0.25})
	# Position: FIRST or LAST — we use two sub-effects or a compound approach.
	# Simplest: create two DiceAffixes, one per position.
	da_forge_bond.position_requirement = DiceAffix.PositionRequirement.FIRST
	_save(da_forge_bond, DICE_AFFIX_DIR + "da_forge_bond_first.tres")

	var da_forge_bond_last := _make_dice_affix(
		"Forge Bond: Last Position Bonus",
		"Fire die in last position deals +25% damage.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 0.25,
		{"element": "FIRE", "percent": 0.25})
	da_forge_bond_last.position_requirement = DiceAffix.PositionRequirement.LAST
	_save(da_forge_bond_last, DICE_AFFIX_DIR + "da_forge_bond_last.tres")

	var fb_wrap_first := _make_mana_die_affix_wrapper(
		"Forge Bond: First", "+25% damage in first slot.",
		["mage", "flame", "mana_die_affix", "forge_bond"], da_forge_bond)
	_save_affix(fb_wrap_first, "forge_bond", "forge_bond_r1_first_affix")

	var fb_wrap_last := _make_mana_die_affix_wrapper(
		"Forge Bond: Last", "+25% damage in last slot.",
		["mage", "flame", "mana_die_affix", "forge_bond"], da_forge_bond_last)
	_save_affix(fb_wrap_last, "forge_bond", "forge_bond_r1_last_affix")

	var forge_bond := _make_skill(
		"flame_forge_bond", "★ Forge Bond",
		"Fire dice in [color=yellow]first/last[/color] position deal +25% damage.",
		6, 4, _tier_pts(6),
		{1: [fb_wrap_first, fb_wrap_last]})
	_save_skill(forge_bond, "flame_forge_bond")

	# --- Cauterize (Col 6): ACTION — 1 die, SELF, heal die×1.5 + barrier = die. ---
	var caut_heal_eff := _make_action_effect("Cauterize: Heal",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,
		ActionEffect.DamageType.FIRE,
		0, 1.5, 1, 0, 1.5, true)
	_save_effect(caut_heal_eff, "cauterize_heal_eff")

	# Barrier as a separate ADD_STATUS or MISC effect.
	# Using a simple barrier affix approach:
	var caut_barrier_affix := _make_affix("Cauterize: Barrier",
		"Grants barrier equal to die value.",
		Affix.Category.BARRIER_BONUS,
		["mage", "flame", "cauterize", "barrier"], 0.0,
		{"value_source": "DICE_TOTAL"})
	_save_affix(caut_barrier_affix, "cauterize", "cauterize_barrier_affix")

	var caut_act := _make_action("flame_cauterize", "Cauterize",
		"Heal for die×1.5 and gain barrier equal to die value.",
		1, [caut_heal_eff],
		Action.ChargeType.LIMITED_PER_TURN, 1)
	_save_action(caut_act, "cauterize_action")

	var caut_grant := _make_affix("Cauterize: Grant Action",
		"Grants Cauterize action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_cauterize"})
	caut_grant.granted_action = caut_act
	_save_affix(caut_grant, "cauterize", "cauterize_r1_affix")

	var cauterize := _make_skill(
		"flame_cauterize", "Cauterize",
		"[color=yellow]ACTION:[/color] 1 die → [color=green]heal[/color] die×1.5 + [color=cyan]barrier[/color] = die.",
		6, 6, _tier_pts(6),
		{1: [caut_grant]})
	_save_skill(cauterize, "flame_cauterize")


# ============================================================================
# TIER 7 — Detonate, Cinder Storm, Radiance, Ember Link (4 skills)
# ============================================================================

func _create_tier_7():
	print("\n🔥 Tier 7...")

	# --- Detonate (Col 1): ACTION — 1 die, consume all Burn → damage = stacks×3 + die ---
	var det_dmg_eff := _make_action_effect("Detonate: Consume Burn Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1)
	# NOTE: The ×3 per stack multiplier on consumed burn stacks requires runtime
	# resolution via value_source on base_damage. Store intent in effect_data.
	det_dmg_eff.effect_data = {"value_source": "TARGET_STATUS_STACKS",
		"status_id": "burn", "per_stack_bonus": 3}
	_save_effect(det_dmg_eff, "detonate_dmg_eff")

	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var det_remove_eff := _make_action_effect("Detonate: Remove Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.REMOVE_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 0)  # stack_count 0 = remove all
	_save_effect(det_remove_eff, "detonate_remove_eff")

	var det_act := _make_action("flame_detonate", "Detonate",
		"Consume all Burn on target. Deal die + (stacks × 3) fire damage.",
		1, [det_dmg_eff, det_remove_eff],
		Action.ChargeType.LIMITED_PER_TURN, 2)
	_save_action(det_act, "detonate_action")

	var det_grant := _make_affix("Detonate: Grant Action",
		"Grants Detonate action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_detonate"})
	det_grant.granted_action = det_act
	_save_affix(det_grant, "detonate", "detonate_r1_affix")

	var detonate := _make_skill(
		"flame_detonate", "Detonate",
		"[color=yellow]ACTION:[/color] 1 die → consume [color=red]Burn[/color], damage = stacks×3 + die.",
		7, 1, _tier_pts(7),
		{1: [det_grant]})
	_save_skill(detonate, "flame_detonate")

	# --- Cinder Storm (Col 2): ACTION — 3 dice, ALL_ENEMIES, fire ×0.5 + 2 Burn ---
	var cs_dmg_eff := _make_action_effect("Cinder Storm: AoE Damage",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.5, 3)
	_save_effect(cs_dmg_eff, "cinder_storm_dmg_eff")

	var cs_burn_eff := _make_action_effect("Cinder Storm: Apply Burn",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 2)
	_save_effect(cs_burn_eff, "cinder_storm_burn_eff")

	var cs_act := _make_action("flame_cinder_storm", "Cinder Storm",
		"Barrage all enemies with fire for 50% damage and apply 2 Burn.",
		3, [cs_dmg_eff, cs_burn_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(cs_act, "cinder_storm_action")

	var cs_grant := _make_affix("Cinder Storm: Grant Action",
		"Grants Cinder Storm action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "crucible"], 0.0,
		{"action_id": "flame_cinder_storm"})
	cs_grant.granted_action = cs_act
	_save_affix(cs_grant, "cinder_storm", "cinder_storm_r1_affix")

	var cinder_storm := _make_skill(
		"flame_cinder_storm", "Cinder Storm",
		"[color=yellow]ACTION:[/color] 3 dice → [color=orange]fire[/color] ×0.5 to ALL + 2 [color=red]Burn[/color]. Per combat.",
		7, 2, _tier_pts(7),
		{1: [cs_grant]})
	_save_skill(cinder_storm, "flame_cinder_storm")

	# --- Radiance (Col 4): ACTION — 1 die, SELF, armor=die×2, barrier=die,
	#     +fire damage=die for 2 turns. ---
	# This is a complex self-buff. We model it as multiple effects.
	var rad_armor_eff := _make_action_effect("Radiance: Armor Buff",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,  # Using HEAL with 0 heal to trigger barrier/armor via effect_data
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false)
	rad_armor_eff.effect_data = {"grant_armor_mult": 2.0, "grant_barrier_mult": 1.0,
		"grant_fire_damage_mult": 1.0, "duration_turns": 2,
		"value_source": "DICE_TOTAL"}
	_save_effect(rad_armor_eff, "radiance_buff_eff")

	var rad_act := _make_action("flame_radiance", "Radiance",
		"Self-buff: armor = die×2, barrier = die, +fire damage = die for 2 turns.",
		1, [rad_armor_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(rad_act, "radiance_action")

	var rad_grant := _make_affix("Radiance: Grant Action",
		"Grants Radiance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_radiance"})
	rad_grant.granted_action = rad_act
	_save_affix(rad_grant, "radiance", "radiance_r1_affix")

	var radiance := _make_skill(
		"flame_radiance", "Radiance",
		"[color=yellow]ACTION:[/color] 1 die → [color=gray]armor[/color] ×2, [color=cyan]barrier[/color], +[color=orange]fire dmg[/color] for 2 turns.",
		7, 4, _tier_pts(7),
		{1: [rad_grant]})
	_save_skill(radiance, "flame_radiance")

	# --- Ember Link (Col 5): Fire dice copy 15%/25% from neighbors. 2 ranks. ---
	var da_link_r1 := _make_dice_affix(
		"Ember Link I: Copy Neighbor", "Copy 15% of neighbor's value.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.COPY_NEIGHBOR_VALUE, 0.15,
		{"percent": 0.15},
		null,
		DiceAffix.PositionRequirement.ANY,
		DiceAffix.NeighborTarget.BOTH_NEIGHBORS)
	_save(da_link_r1, DICE_AFFIX_DIR + "da_ember_link_r1.tres")

	var el_r1 := _make_mana_die_affix_wrapper(
		"Ember Link I", "Fire dice copy 15% from neighbors.",
		["mage", "flame", "mana_die_affix", "copy_value"], da_link_r1)
	_save_affix(el_r1, "ember_link", "ember_link_r1_affix")

	var da_link_r2 := _make_dice_affix(
		"Ember Link II: Copy Neighbor", "Copy 25% of neighbor's value.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.COPY_NEIGHBOR_VALUE, 0.25,
		{"percent": 0.25},
		null,
		DiceAffix.PositionRequirement.ANY,
		DiceAffix.NeighborTarget.BOTH_NEIGHBORS)
	_save(da_link_r2, DICE_AFFIX_DIR + "da_ember_link_r2.tres")

	var el_r2 := _make_mana_die_affix_wrapper(
		"Ember Link II", "Fire dice copy 25% from neighbors.",
		["mage", "flame", "mana_die_affix", "copy_value"], da_link_r2)
	_save_affix(el_r2, "ember_link", "ember_link_r2_affix")

	var ember_link := _make_skill(
		"flame_ember_link", "Ember Link",
		"Fire dice copy [color=yellow]15%/25%[/color] of neighbors' values.",
		7, 5, _tier_pts(7),
		{1: [el_r1], 2: [el_r2]})
	_save_skill(ember_link, "flame_ember_link")


# ============================================================================
# TIER 8 — ★Pyroclastic Flow, Volcanic Core, ★Crucible's Gift (3 skills)
# ============================================================================

func _create_tier_8():
	print("\n🔥 Tier 8...")

	# --- ★ Pyroclastic Flow (Col 2): Burn explosion → 3 Burn to all others ---
	# Crossover: Requires Inferno r1 + Firestorm r1
	# Implementation: tag-based proc in combat_manager (Chunk 1 Patch 7)
	var pf_affix := _make_affix("Pyroclastic Flow",
		"When Burn explodes, apply 3 Burn stacks to all other enemies.",
		Affix.Category.PROC,
		["mage", "flame", "pyroclastic_flow", "burn_explosion_spread"], 3.0)
	_save_affix(pf_affix, "pyroclastic_flow", "pyroclastic_flow_r1_affix")

	var pyroclastic_flow := _make_skill(
		"flame_pyroclastic_flow", "★ Pyroclastic Flow",
		"Burn explosions apply [color=red]3 Burn[/color] to ALL other enemies.",
		8, 2, _tier_pts(8),
		{1: [pf_affix]})
	_save_skill(pyroclastic_flow, "flame_pyroclastic_flow")

	# --- Volcanic Core (Col 3): ACTION — 3 dice, SINGLE_ENEMY, fire ×1.0,
	#     EXECUTE (×2.0 if <30% HP). ---
	var vc_dmg_eff := _make_action_effect("Volcanic Core: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 3)
	vc_dmg_eff.effect_data = {"execute_threshold": 0.3, "execute_multiplier": 2.0}
	_save_effect(vc_dmg_eff, "volcanic_core_dmg_eff")

	var vc_act := _make_action("flame_volcanic_core", "Volcanic Core",
		"Massive fire strike. Deals double damage if target is below 30% HP.",
		3, [vc_dmg_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(vc_act, "volcanic_core_action")

	var vc_grant := _make_affix("Volcanic Core: Grant Action",
		"Grants Volcanic Core action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "crucible"], 0.0,
		{"action_id": "flame_volcanic_core"})
	vc_grant.granted_action = vc_act
	_save_affix(vc_grant, "volcanic_core", "volcanic_core_r1_affix")

	var volcanic_core := _make_skill(
		"flame_volcanic_core", "Volcanic Core",
		"[color=yellow]ACTION:[/color] 3 dice → [color=orange]fire[/color] ×1.0. [color=red]EXECUTE:[/color] ×2 if below 30% HP.",
		8, 3, _tier_pts(8),
		{1: [vc_grant]})
	_save_skill(volcanic_core, "flame_volcanic_core")

	# --- ★ Crucible's Gift (Col 4): After hitting 2+ enemies, next pull −2 mana ---
	# Crossover: Requires Eruption + Tempered Steel r1
	# Implementation: combat_manager multi-target tracking (Chunk 1 Patch 7d)
	var cg_affix := _make_affix("Crucible's Gift",
		"After hitting 2+ enemies, next mana pull costs 2 less.",
		Affix.Category.PROC,
		["mage", "flame", "crucibles_gift", "mana_discount"], 2.0,
		{"proc_trigger": "ON_MULTI_TARGET_HIT", "proc_effect": "reduce_next_pull_cost",
		 "min_targets": 2, "cost_reduction": 2})
	_save_affix(cg_affix, "crucibles_gift", "crucibles_gift_r1_affix")

	var crucibles_gift := _make_skill(
		"flame_crucibles_gift", "★ Crucible's Gift",
		"After hitting 2+ enemies, next mana pull costs [color=cyan]2 less[/color].",
		8, 4, _tier_pts(8),
		{1: [cg_affix]})
	_save_skill(crucibles_gift, "flame_crucibles_gift")


# ============================================================================
# TIER 9 — Eternal Flame, Ironfire Stance (2 skills)
# ============================================================================

func _create_tier_9():
	print("\n🔥 Tier 9...")

	# --- Eternal Flame (Col 1): ACTION — 2 dice, SINGLE_ENEMY, fire ×1.0
	#     + Burn = die total, Burn can't expire 3 turns. ---
	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var ef_dmg_eff := _make_action_effect("Eternal Flame: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 2)
	_save_effect(ef_dmg_eff, "eternal_flame_dmg_eff")

	var ef_burn_eff := _make_action_effect("Eternal Flame: Apply Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 1)
	# Design: stacks = dice total. Same pattern as Burning Vengeance.
	ef_burn_eff.effect_data = {"value_source": "DICE_TOTAL"}
	_save_effect(ef_burn_eff, "eternal_flame_burn_eff")

	# Create the eternal_flame_mark StatusAffix
	var ef_mark := StatusAffix.new()
	ef_mark.status_id = "eternal_flame_mark"
	ef_mark.affix_name = "Eternal Flame"
	ef_mark.description = "Burn cannot expire while this mark is active."
	ef_mark.duration_type = StatusAffix.DurationType.TURN_BASED
	ef_mark.default_duration = 3
	ef_mark.tick_timing = StatusAffix.TickTiming.END_OF_TURN
	ef_mark.category = Affix.Category.MISC
	ef_mark.tags = ["mage", "flame", "eternal_flame", "mark"]
	ef_mark.show_in_summary = true
	ef_mark.cleanse_tags = ["buff", "fire"]
	_save(ef_mark, STATUS_DIR + "eternal_flame_mark.tres")
	_created_statuses += 1

	var ef_mark_eff := _make_action_effect("Eternal Flame: Apply Mark",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		ef_mark, 1)
	_save_effect(ef_mark_eff, "eternal_flame_mark_eff")

	var ef_act := _make_action("flame_eternal_flame", "Eternal Flame",
		"Deal fire damage and inflict massive Burn that cannot expire for 3 turns.",
		2, [ef_dmg_eff, ef_burn_eff, ef_mark_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(ef_act, "eternal_flame_action")

	var ef_grant := _make_affix("Eternal Flame: Grant Action",
		"Grants Eternal Flame action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_eternal_flame"})
	ef_grant.granted_action = ef_act
	_save_affix(ef_grant, "eternal_flame", "eternal_flame_r1_affix")

	var eternal_flame := _make_skill(
		"flame_eternal_flame", "Eternal Flame",
		"[color=yellow]ACTION:[/color] 2 dice → [color=orange]fire[/color] ×1.0 + [color=red]Burn[/color] = dice total. Burn can't expire 3 turns.",
		9, 1, _tier_pts(9),
		{1: [ef_grant]})
	_save_skill(eternal_flame, "flame_eternal_flame")

	# --- Ironfire Stance (Col 5): ACTION — 2 dice, SELF, 25% damage reduction
	#     + 30% fire reflect + heal = die total, 2 turns. ---
	var ifs_eff := _make_action_effect("Ironfire Stance: Buff",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 2, 0, 1.0, true)
	ifs_eff.effect_data = {"damage_reduction_percent": 0.25,
		"fire_reflect_percent": 0.30,
		"duration_turns": 2,
		"value_source": "DICE_TOTAL"}
	_save_effect(ifs_eff, "ironfire_stance_buff_eff")

	var ifs_act := _make_action("flame_ironfire_stance", "Ironfire Stance",
		"25% damage reduction, 30% fire reflect, heal = dice total. Lasts 2 turns.",
		2, [ifs_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(ifs_act, "ironfire_stance_action")

	var ifs_grant := _make_affix("Ironfire Stance: Grant Action",
		"Grants Ironfire Stance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_ironfire_stance"})
	ifs_grant.granted_action = ifs_act
	_save_affix(ifs_grant, "ironfire_stance", "ironfire_stance_r1_affix")

	var ironfire_stance := _make_skill(
		"flame_ironfire_stance", "Ironfire Stance",
		"[color=yellow]ACTION:[/color] 2 dice → 25% [color=gray]damage reduction[/color], 30% [color=orange]fire reflect[/color], [color=green]heal[/color]. 2 turns.",
		9, 5, _tier_pts(9),
		{1: [ifs_grant]})
	_save_skill(ironfire_stance, "flame_ironfire_stance")


# ============================================================================
# TIER 10 — Conflagration (1 skill, capstone)
# ============================================================================

func _create_tier_10():
	print("\n🔥 Tier 10 — CAPSTONE...")

	# Conflagration: D12 unlock. Ignore fire resist. If Burning, double die value.
	# Compound DiceAffix: IGNORE_RESISTANCE + MODIFY_VALUE_PERCENT ×2.0 conditional

	var conf_size := _make_affix("Conflagration: D12 Unlock",
		"Unlocks D12 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"], 0.0,
		{"die_size": 12})
	_save_affix(conf_size, "conflagration", "conflagration_r1_size_affix")

	# DiceAffix 1: Ignore fire resistance
	var da_ignore_resist := _make_dice_affix(
		"Conflagration: Ignore Resist",
		"Fire dice ignore enemy fire resistance.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.IGNORE_RESISTANCE, 1.0,
		{"element": "FIRE"})
	_save(da_ignore_resist, DICE_AFFIX_DIR + "da_conflagration_ignore_resist.tres")

	var conf_resist := _make_mana_die_affix_wrapper(
		"Conflagration: Ignore Resist",
		"Fire dice ignore fire resistance.",
		["mage", "flame", "mana_die_affix", "capstone"], da_ignore_resist)
	_save_affix(conf_resist, "conflagration", "conflagration_r1_resist_affix")

	# DiceAffix 2: Double value if target is Burning
	var da_double_burn := _make_dice_affix(
		"Conflagration: Double vs Burn",
		"Fire dice deal double damage to burning targets.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.MODIFY_VALUE_PERCENT, 2.0, {},
		_cond_target_burn)
	_save(da_double_burn, DICE_AFFIX_DIR + "da_conflagration_double_burn.tres")

	var conf_double := _make_mana_die_affix_wrapper(
		"Conflagration: Double vs Burn",
		"Double die value against burning targets.",
		["mage", "flame", "mana_die_affix", "capstone"], da_double_burn)
	_save_affix(conf_double, "conflagration", "conflagration_r1_double_affix")

	var conflagration := _make_skill(
		"flame_conflagration", "Conflagration",
		"Unlocks [color=orange]D12[/color]. Ignore fire resist. [color=red]Double[/color] die value vs burning targets.",
		10, 3, _tier_pts(10),
		{1: [conf_size, conf_resist, conf_double]})
	_save_skill(conflagration, "flame_conflagration")
