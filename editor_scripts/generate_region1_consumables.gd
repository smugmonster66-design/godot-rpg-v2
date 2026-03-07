@tool
extends EditorScript
# ============================================================================
# generate_region1_consumables.gd
# Region 1 (Sanctum) — ConsumableItem Resource Generator
#
# Creates 65 consumable .tres templates across T1-T4, plus all supporting
# Affix and DiceAffix sub-resources they reference.
# T5 Curios are hand-authored — each needs a unique ConsumableEffect script.
#
# Mirrors the pattern from generate_region1_base_items.gd:
#   - All sub-resources saved to disk FIRST (save-before-reference)
#   - Parent ConsumableItem resources reference saved children via load()
#   - Typed arrays use .assign()
#   - No emoji in print()
#   - Explicit typing on all Variant sources
#
# Execution order:
#   1. Create directories
#   2. Generate + save shared Affix resources (T2 combat preps)
#   3. Generate + save shared DiceAffix resources (T3/T4)
#   4. Generate + save ConsumableItem resources referencing saved children
#
# Run: Editor -> File -> Run (or Ctrl+Shift+X with this script open)
# ============================================================================

const BASE := "res://resources/consumables/region_1"
const AFFIX_DIR := "res://resources/consumables/region_1/affixes"
const DICE_AFFIX_DIR := "res://resources/consumables/region_1/dice_affixes"

# Shortcuts
const C := Affix.Category
const DA_T := DiceAffix.Trigger
const DA_E := DiceAffix.EffectType
const DA_P := DiceAffix.PositionRequirement
const DA_N := DiceAffix.NeighborTarget
const CT := ConsumableItem.ConsumableTier
const UC := ConsumableItem.UseContext
const TT := ConsumableItem.TargetType

var _count: int = 0
var _affix_count: int = 0
var _dice_affix_count: int = 0

func _run():
	print("=" .repeat(60))
	print("  REGION 1 CONSUMABLE GENERATOR")
	print("=" .repeat(60))

	_ensure_dirs()

	# Phase 1: Sub-resources
	print("")
	print("-- Phase 1: Affix sub-resources --")
	_generate_t2_affixes()
	print("  Affixes created: %d" % _affix_count)

	print("")
	print("-- Phase 2: DiceAffix sub-resources --")
	_generate_dice_affixes()
	print("  DiceAffixes created: %d" % _dice_affix_count)

	# Phase 2: Consumable items
	print("")
	print("-- Phase 3: T1 Restoratives --")
	_generate_t1_restoratives()

	print("")
	print("-- Phase 4: T2 Combat Preparations --")
	_generate_t2_combat_preps()

	print("")
	print("-- Phase 5: T3 Dice Elixirs --")
	_generate_t3_dice_elixirs()

	print("")
	print("-- Phase 6: T4 Inscriptions --")
	_generate_t4_inscriptions()

	print("")
	print("=" .repeat(60))
	print("  DONE -- %d consumables, %d affixes, %d dice affixes" % [
		_count, _affix_count, _dice_affix_count])
	print("=" .repeat(60))


# ============================================================================
# DIRECTORY SETUP
# ============================================================================

func _ensure_dirs():
	for folder: String in [
		"restoratives", "combat_preps", "dice_elixirs",
		"inscriptions", "affixes", "dice_affixes"
	]:
		var path: String = BASE + "/" + folder
		DirAccess.make_dir_recursive_absolute(path)


# ============================================================================
# HELPERS — Save
# ============================================================================

func _save(res: Resource, path: String):
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save: %s (error %d)" % [path, err])


# ============================================================================
# HELPERS — Affix Creation
# ============================================================================

func _make_affix(p_name: String, p_desc: String, p_category: int,
		p_value: float, p_tags: Array = []) -> Affix:
	var a: Affix = Affix.new()
	a.affix_name = p_name
	a.description = p_desc
	a.category = p_category
	a.effect_number = p_value
	a.value_source = Affix.ValueSource.STATIC
	a.show_in_summary = true
	if p_tags.size() > 0:
		a.tags.assign(p_tags)
	return a


func _make_proc_affix(p_name: String, p_desc: String,
		p_trigger: int, p_chance: float, p_status_id: String,
		p_stacks: int = 1) -> Affix:
	var a: Affix = Affix.new()
	a.affix_name = p_name
	a.description = p_desc
	a.category = C.PROC
	a.proc_trigger = p_trigger
	a.proc_chance = p_chance
	a.effect_number = float(p_stacks)
	a.effect_data = {"status_id": p_status_id, "stacks": p_stacks}
	a.show_in_summary = true
	return a


func _save_affix(affix: Affix, filename: String) -> Affix:
	var path: String = AFFIX_DIR + "/" + filename + ".tres"
	_save(affix, path)
	_affix_count += 1
	var loaded: Affix = load(path) as Affix
	return loaded


# ============================================================================
# HELPERS — DiceAffix Creation
# ============================================================================

func _make_dice_affix(p_name: String, p_desc: String,
		p_trigger: int, p_effect: int, p_value: float = 0.0,
		p_pos: int = DA_P.ANY, p_target: int = DA_N.SELF,
		p_data: Dictionary = {}) -> DiceAffix:
	var da: DiceAffix = DiceAffix.new()
	da.affix_name = p_name
	da.description = p_desc
	da.trigger = p_trigger
	da.effect_type = p_effect
	da.effect_value = p_value
	da.position_requirement = p_pos
	da.neighbor_target = p_target
	da.effect_data = p_data
	da.show_in_summary = true
	return da


func _save_dice_affix(da: DiceAffix, filename: String) -> DiceAffix:
	var path: String = DICE_AFFIX_DIR + "/" + filename + ".tres"
	_save(da, path)
	_dice_affix_count += 1
	var loaded: DiceAffix = load(path) as DiceAffix
	return loaded


# ============================================================================
# HELPERS — ConsumableItem Creation
# ============================================================================

func _make_consumable(p_name: String, p_desc: String, p_flavor: String,
		p_tier: int, p_rarity: int, p_context: int,
		p_value: int, p_stack: int = 10) -> ConsumableItem:
	var ci: ConsumableItem = ConsumableItem.new()
	ci.item_name = p_name
	ci.description = p_desc
	ci.flavor_text = p_flavor
	ci.tier = p_tier
	ci.rarity = p_rarity
	ci.use_context = p_context
	ci.base_value = p_value
	ci.max_stack = p_stack
	ci.region = 1
	return ci


func _save_consumable(ci: ConsumableItem, subfolder: String, filename: String):
	var path: String = BASE + "/" + subfolder + "/" + filename + ".tres"
	_save(ci, path)
	_count += 1
	print("  [%d] %s" % [_count, ci.item_name])


# ============================================================================
# T2 AFFIX SUB-RESOURCES
# ============================================================================

var _aff: Dictionary = {}  # filename -> loaded Affix

func _generate_t2_affixes():
	# Offensive
	_aff["dmg_5"] = _save_affix(
		_make_affix("Sharpened Edge", "+5 Damage", C.DAMAGE_BONUS, 5.0), "dmg_bonus_5")
	_aff["dmg_10"] = _save_affix(
		_make_affix("Honed Edge", "+10 Damage", C.DAMAGE_BONUS, 10.0), "dmg_bonus_10")
	_aff["fire_8"] = _save_affix(
		_make_affix("Burning Oil", "+8 Fire Damage", C.FIRE_DAMAGE_BONUS, 8.0, ["fire"]), "fire_dmg_8")
	_aff["ice_8"] = _save_affix(
		_make_affix("Frost Coating", "+8 Ice Damage", C.ICE_DAMAGE_BONUS, 8.0, ["ice"]), "ice_dmg_8")
	_aff["shock_8"] = _save_affix(
		_make_affix("Voltaic Charge", "+8 Shock Damage", C.SHOCK_DAMAGE_BONUS, 8.0, ["shock"]), "shock_dmg_8")
	_aff["poison_8"] = _save_affix(
		_make_affix("Toxin Layer", "+8 Poison Damage", C.POISON_DAMAGE_BONUS, 8.0, ["poison"]), "poison_dmg_8")
	_aff["shadow_8"] = _save_affix(
		_make_affix("Shadow Coating", "+8 Shadow Damage", C.SHADOW_DAMAGE_BONUS, 8.0, ["shadow"]), "shadow_dmg_8")
	_aff["dmg_mult"] = _save_affix(
		_make_affix("Slayer's Fury", "x1.15 All Damage", C.DAMAGE_MULTIPLIER, 1.15), "dmg_mult_115")

	# Proc: status on hit
	_aff["proc_poison"] = _save_affix(
		_make_proc_affix("Venom Coat", "30% Poison on Hit", Affix.ProcTrigger.ON_DEAL_DAMAGE, 0.3, "poison", 2),
		"proc_poison_30")
	_aff["proc_burn"] = _save_affix(
		_make_proc_affix("Incendiary Coat", "30% Burn on Hit", Affix.ProcTrigger.ON_DEAL_DAMAGE, 0.3, "burn", 2),
		"proc_burn_30")
	_aff["proc_bleed"] = _save_affix(
		_make_proc_affix("Serrated Coat", "30% Bleed on Hit", Affix.ProcTrigger.ON_DEAL_DAMAGE, 0.3, "bleed", 2),
		"proc_bleed_30")

	# Defensive
	_aff["armor_8"] = _save_affix(
		_make_affix("Ironbark", "+8 Armor", C.ARMOR_BONUS, 8.0), "armor_8")
	_aff["armor_15"] = _save_affix(
		_make_affix("Marine Hardening", "+15 Armor", C.ARMOR_BONUS, 15.0), "armor_15")
	_aff["barrier_20"] = _save_affix(
		_make_affix("Aegis Layer", "+20 Barrier", C.BARRIER_BONUS, 20.0), "barrier_20")
	_aff["fire_res"] = _save_affix(
		_make_affix("Fireward", "+15 Fire Resist", C.FIRE_RESIST_BONUS, 15.0), "fire_resist_15")
	_aff["ice_res"] = _save_affix(
		_make_affix("Frostward", "+15 Ice Resist", C.ICE_RESIST_BONUS, 15.0), "ice_resist_15")
	_aff["shock_res"] = _save_affix(
		_make_affix("Stormward", "+15 Shock Resist", C.SHOCK_RESIST_BONUS, 15.0), "shock_resist_15")
	_aff["poison_res"] = _save_affix(
		_make_affix("Antivenin", "+15 Poison Resist", C.POISON_RESIST_BONUS, 15.0), "poison_resist_15")
	_aff["shadow_res"] = _save_affix(
		_make_affix("Shadowward", "+15 Shadow Resist", C.SHADOW_RESIST_BONUS, 15.0), "shadow_resist_15")
	_aff["health_30"] = _save_affix(
		_make_affix("Vitality", "+30 Health", C.HEALTH_BONUS, 30.0), "health_30")
	_aff["fort_armor"] = _save_affix(
		_make_affix("Fortification Armor", "+10 Armor", C.ARMOR_BONUS, 10.0), "fort_armor_10")
	_aff["fort_barrier"] = _save_affix(
		_make_affix("Fortification Barrier", "+10 Barrier", C.BARRIER_BONUS, 10.0), "fort_barrier_10")
	_aff["fort_health"] = _save_affix(
		_make_affix("Fortification Health", "+15 Health", C.HEALTH_BONUS, 15.0), "fort_health_15")

	# Utility
	_aff["luck_5"] = _save_affix(
		_make_affix("Lucky Dust", "+5 Luck", C.LUCK_BONUS, 5.0), "luck_5")
	_aff["int_5"] = _save_affix(
		_make_affix("Stimulant", "+5 Intellect", C.INTELLECT_BONUS, 5.0), "intellect_5")
	_aff["str_5"] = _save_affix(
		_make_affix("Berserker's Might", "+5 Strength", C.STRENGTH_BONUS, 5.0), "strength_5")
	_aff["agi_5"] = _save_affix(
		_make_affix("Fleet Foot", "+5 Agility", C.AGILITY_BONUS, 5.0), "agility_5")
	_aff["gold_find"] = _save_affix(
		_make_affix("Prospector's Eye", "+25% Gold Find", C.MISC, 0.25, ["gold_find"]), "gold_find_25")
	_aff["mana_cost"] = _save_affix(
		_make_affix("Mana Catalyst", "x0.8 Mana Costs", C.MANA_COST_MULTIPLIER, 0.8), "mana_cost_80")


# ============================================================================
# T3/T4 DICE AFFIX SUB-RESOURCES
# ============================================================================

var _da: Dictionary = {}  # filename -> loaded DiceAffix

func _generate_dice_affixes():
	# T3 temp dice affixes
	_da["roll_plus1"] = _save_dice_affix(
		_make_dice_affix("Gambler's Nudge", "+1 to all rolls",
			DA_T.ON_ROLL, DA_E.MODIFY_VALUE_FLAT, 1.0),
		"roll_plus1")

	_da["roll_plus3_first"] = _save_dice_affix(
		_make_dice_affix("Volatile Surge", "+3 to first die",
			DA_T.ON_ROLL, DA_E.MODIFY_VALUE_FLAT, 3.0, DA_P.FIRST),
		"roll_plus3_first")

	_da["use_plus2_right"] = _save_dice_affix(
		_make_dice_affix("Chain Reaction", "+2 to right neighbor on use",
			DA_T.ON_USE, DA_E.MODIFY_VALUE_FLAT, 2.0, DA_P.ANY, DA_N.RIGHT),
		"use_plus2_right")

	_da["copy_left_50"] = _save_dice_affix(
		_make_dice_affix("Mirror Polish", "Copy 50% of left neighbor value",
			DA_T.ON_ROLL, DA_E.COPY_NEIGHBOR_VALUE, 0.5, DA_P.NOT_FIRST, DA_N.LEFT,
			{"percent": 0.5}),
		"copy_left_50")

	# Element inks (temp) — ON_ROLL so element is set before display
	for elem: String in ["fire", "ice", "shock", "poison", "shadow"]:
		_da["set_%s" % elem] = _save_dice_affix(
			_make_dice_affix("%s Ink" % elem.capitalize(), "Set element to %s" % elem,
				DA_T.ON_ROLL, DA_E.SET_ELEMENT, 0.0, DA_P.ANY, DA_N.SELF,
				{"element": elem.to_upper()}),
			"set_element_%s" % elem)

	_da["leech_15"] = _save_dice_affix(
		_make_dice_affix("Leech Draught", "15% lifesteal on die use",
			DA_T.ON_USE, DA_E.LEECH_HEAL, 0.15, DA_P.ANY, DA_N.SELF,
			{"percent": 0.15}),
		"leech_15")

	_da["min_3"] = _save_dice_affix(
		_make_dice_affix("Stabilizer", "Dice can't roll below 3",
			DA_T.ON_ROLL, DA_E.SET_MINIMUM_VALUE, 3.0),
		"set_min_3")

	_da["random_elem"] = _save_dice_affix(
		_make_dice_affix("Chaos Capsule", "Random element on roll",
			DA_T.ON_ROLL, DA_E.RANDOMIZE_ELEMENT, 0.0),
		"randomize_element")

	_da["use_plus4_last"] = _save_dice_affix(
		_make_dice_affix("Duelist's Focus", "+4 to last die on use",
			DA_T.ON_USE, DA_E.MODIFY_VALUE_FLAT, 4.0, DA_P.LAST, DA_N.SELF),
		"use_plus4_last")

	# T4 permanent inscriptions
	_da["perm_plus1"] = _save_dice_affix(
		_make_dice_affix("Rune of Fortification", "+1 to all rolls (permanent)",
			DA_T.ON_ROLL, DA_E.MODIFY_VALUE_FLAT, 1.0),
		"perm_roll_plus1")

	for elem: String in ["fire", "ice", "shock", "poison", "shadow"]:
		_da["perm_%s" % elem] = _save_dice_affix(
			_make_dice_affix("Rune of %s" % elem.capitalize(), "Permanently set element to %s" % elem,
				DA_T.ON_ROLL, DA_E.SET_ELEMENT, 0.0, DA_P.ANY, DA_N.SELF,
				{"element": elem.to_upper()}),
			"perm_set_%s" % elem)

	_da["perm_leech"] = _save_dice_affix(
		_make_dice_affix("Sigil of Vampirism", "10% lifesteal on use (permanent)",
			DA_T.ON_USE, DA_E.LEECH_HEAL, 0.1, DA_P.ANY, DA_N.SELF,
			{"percent": 0.1}),
		"perm_leech_10")

	_da["perm_right2"] = _save_dice_affix(
		_make_dice_affix("Sigil of Conduction", "+2 to right neighbor (permanent)",
			DA_T.ON_USE, DA_E.MODIFY_VALUE_FLAT, 2.0, DA_P.ANY, DA_N.RIGHT),
		"perm_use_plus2_right")

	_da["perm_anchor"] = _save_dice_affix(
		_make_dice_affix("Sigil of the Anchor", "+3 in first position",
			DA_T.ON_ROLL, DA_E.MODIFY_VALUE_FLAT, 3.0, DA_P.FIRST, DA_N.SELF),
		"perm_anchor_first3")

	_da["perm_stern"] = _save_dice_affix(
		_make_dice_affix("Sigil of the Stern", "+3 in last position",
			DA_T.ON_ROLL, DA_E.MODIFY_VALUE_FLAT, 3.0, DA_P.LAST, DA_N.SELF),
		"perm_stern_last3")

	_da["perm_burn"] = _save_dice_affix(
		_make_dice_affix("Sigil of Ignition", "Apply 2 Burn on use",
			DA_T.ON_USE, DA_E.GRANT_STATUS_EFFECT, 2.0, DA_P.ANY, DA_N.SELF,
			{"status": {"status_id": "burn", "stacks": 2}}),
		"perm_burn_2")

	_da["perm_bleed"] = _save_dice_affix(
		_make_dice_affix("Sigil of Fracture", "Apply 2 Bleed on use",
			DA_T.ON_USE, DA_E.GRANT_STATUS_EFFECT, 2.0, DA_P.ANY, DA_N.SELF,
			{"status": {"status_id": "bleed", "stacks": 2}}),
		"perm_bleed_2")


# ============================================================================
# T1 RESTORATIVES
# ============================================================================

func _generate_t1_restoratives():
	var sub: String = "restoratives"

	var ci: ConsumableItem

	ci = _make_consumable("Navy Ration Biscuit", "Heal 15 HP",
		"Technically food. The Navy promises.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 5, 20)
	ci.heal_amount = 15
	_save_consumable(ci, sub, "navy_ration_biscuit")

	ci = _make_consumable("Hardtack Surplus", "Heal 30 HP",
		"Rejected by the Navy for being too hard. For the Navy.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 12, 20)
	ci.heal_amount = 30
	_save_consumable(ci, sub, "hardtack_surplus")

	ci = _make_consumable("Sanctum Tonic", "Heal 50 HP",
		"Prescribed by licensed apothecaries. License pending.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 25, 15)
	ci.heal_amount = 50
	_save_consumable(ci, sub, "sanctum_tonic")

	ci = _make_consumable("Officer's Brandy", "Heal 80 HP",
		"Reserved for commissioned officers. You look commissioned enough.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 45, 10)
	ci.heal_amount = 80
	_save_consumable(ci, sub, "officers_brandy")

	ci = _make_consumable("Admiralty Reserve", "Heal 120 HP, cleanse 1 debuff",
		"From the Grand Admiral's personal stock. Don't ask how we got it.", CT.RESTORATIVE, 1, UC.OUT_OF_COMBAT, 80, 5)
	ci.heal_amount = 120
	ci.cleanse_debuffs = true
	ci.cleanse_count = 1
	_save_consumable(ci, sub, "admiralty_reserve")

	ci = _make_consumable("Minor Mana Draught", "Restore 10 Mana",
		"Tastes like concentrated focus. Also paint thinner.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 8, 20)
	ci.mana_amount = 10
	_save_consumable(ci, sub, "minor_mana_draught")

	ci = _make_consumable("Mana Draught", "Restore 25 Mana",
		"The Arcanaeum's recipe, probably.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 20, 15)
	ci.mana_amount = 25
	_save_consumable(ci, sub, "mana_draught")

	ci = _make_consumable("Greater Mana Draught", "Restore 50 Mana",
		"Brewed from imported arcane reagents. Import duties included.", CT.RESTORATIVE, 1, UC.OUT_OF_COMBAT, 50, 10)
	ci.mana_amount = 50
	_save_consumable(ci, sub, "greater_mana_draught")

	ci = _make_consumable("Quarterdeck Barrier Salve", "+20 Barrier",
		"Naval-grade protective wax. Also works on ship hulls.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 15, 15)
	ci.barrier_amount = 20
	_save_consumable(ci, sub, "quarterdeck_barrier_salve")

	ci = _make_consumable("Bulwark Salve", "+40 Barrier",
		"Thick enough to stop a blade. Or at least slow it down.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 35, 10)
	ci.barrier_amount = 40
	_save_consumable(ci, sub, "bulwark_salve")

	ci = _make_consumable("Antidote Tablet", "Cleanse all debuffs",
		"Standard Navy issue. Form 14-C required for reimbursement.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 20, 15)
	ci.cleanse_debuffs = true
	ci.cleanse_count = 0
	_save_consumable(ci, sub, "antidote_tablet")

	ci = _make_consumable("Restorative Bundle", "Heal 40 HP + Restore 15 Mana",
		"A little of everything. The bureaucratic approach to healing.", CT.RESTORATIVE, 0, UC.OUT_OF_COMBAT, 30, 15)
	ci.heal_amount = 40
	ci.mana_amount = 15
	_save_consumable(ci, sub, "restorative_bundle")


# ============================================================================
# T2 COMBAT PREPARATIONS
# ============================================================================

func _generate_t2_combat_preps():
	var sub: String = "combat_preps"

	# Helper: single-affix combat prep
	var ci: ConsumableItem

	# -- Offensive --
	ci = _make_t2("Whetstone (Fine)", "+5 Damage for next combat",
		"Sharpens blades. Also works on blunt weapons somehow.", 1, 40, [_aff["dmg_5"]])
	_save_consumable(ci, sub, "whetstone_fine")

	ci = _make_t2("Whetstone (Naval Grade)", "+10 Damage for next combat",
		"Admiralty specification: must produce visible sparks.", 1, 80, [_aff["dmg_10"]])
	_save_consumable(ci, sub, "whetstone_naval")

	ci = _make_t2("Oil of Burning", "+8 Fire Damage for next combat",
		"Flammable. Very flammable. Concerningly flammable.", 1, 50, [_aff["fire_8"]])
	_save_consumable(ci, sub, "oil_of_burning")

	ci = _make_t2("Frost Resin", "+8 Ice Damage for next combat",
		"Imported from somewhere cold.", 1, 50, [_aff["ice_8"]])
	_save_consumable(ci, sub, "frost_resin")

	ci = _make_t2("Voltaic Paste", "+8 Shock Damage for next combat",
		"Apply to weapon. Do not apply to yourself.", 1, 50, [_aff["shock_8"]])
	_save_consumable(ci, sub, "voltaic_paste")

	ci = _make_t2("Toxin Extract", "+8 Poison Damage for next combat",
		"Harvested from local fauna. They did not consent.", 1, 50, [_aff["poison_8"]])
	_save_consumable(ci, sub, "toxin_extract")

	ci = _make_t2("Shadow Pitch", "+8 Shadow Damage for next combat",
		"Darkness in a jar. Opens in darkness.", 1, 50, [_aff["shadow_8"]])
	_save_consumable(ci, sub, "shadow_pitch")

	ci = _make_t2("Slayer's Draft", "x1.15 All Damage for next combat",
		"Makes you hit harder. Side effects include overconfidence.", 2, 120, [_aff["dmg_mult"]])
	_save_consumable(ci, sub, "slayers_draft")

	ci = _make_t2("Venom Applicator", "30% Poison on Hit for next combat",
		"Coat your weapons in something deeply unpleasant.", 2, 90, [_aff["proc_poison"]])
	_save_consumable(ci, sub, "venom_applicator")

	ci = _make_t2("Incendiary Lacquer", "30% Burn on Hit for next combat",
		"Sets things on fire. That is literally all it does.", 2, 90, [_aff["proc_burn"]])
	_save_consumable(ci, sub, "incendiary_lacquer")

	ci = _make_t2("Serrated Edge Compound", "30% Bleed on Hit for next combat",
		"Your weapon will need re-sharpening afterward.", 2, 90, [_aff["proc_bleed"]])
	_save_consumable(ci, sub, "serrated_edge_compound")

	# -- Defensive --
	ci = _make_t2("Ironbark Tincture", "+8 Armor for next combat",
		"Drink it and your skin gets a bit... woody.", 1, 40, [_aff["armor_8"]])
	_save_consumable(ci, sub, "ironbark_tincture")

	ci = _make_t2("Marine Hardening Wax", "+15 Armor for next combat",
		"Standard hull treatment. Also works on skeletons.", 1, 80, [_aff["armor_15"]])
	_save_consumable(ci, sub, "marine_hardening_wax")

	ci = _make_t2("Aegis Elixir", "+20 Barrier for next combat",
		"Creates a magical barrier. Duration: one fight. Quality: adequate.", 1, 60, [_aff["barrier_20"]])
	_save_consumable(ci, sub, "aegis_elixir")

	ci = _make_t2("Fireward Tincture", "+15 Fire Resist for next combat",
		"Grants fire resistance. Does not grant immunity. Note the distinction.", 1, 45, [_aff["fire_res"]])
	_save_consumable(ci, sub, "fireward_tincture")

	ci = _make_t2("Frostward Tincture", "+15 Ice Resist for next combat",
		"For when you know something cold is coming.", 1, 45, [_aff["ice_res"]])
	_save_consumable(ci, sub, "frostward_tincture")

	ci = _make_t2("Stormward Tincture", "+15 Shock Resist for next combat",
		"Insulates against electrical damage.", 1, 45, [_aff["shock_res"]])
	_save_consumable(ci, sub, "stormward_tincture")

	ci = _make_t2("Antivenin Tincture", "+15 Poison Resist for next combat",
		"Pre-emptive antivenom. Beats the alternative.", 1, 45, [_aff["poison_res"]])
	_save_consumable(ci, sub, "antivenin_tincture")

	ci = _make_t2("Shadowward Tincture", "+15 Shadow Resist for next combat",
		"Wards against dark magic. The jar glows faintly.", 1, 45, [_aff["shadow_res"]])
	_save_consumable(ci, sub, "shadowward_tincture")

	ci = _make_t2("Vitality Brew", "+30 Max HP for next combat",
		"Temporarily increases maximum health. You will feel it wear off.", 1, 55, [_aff["health_30"]])
	_save_consumable(ci, sub, "vitality_brew")

	ci = _make_t2("Fortification Elixir", "+10 Armor, +10 Barrier, +15 HP for next combat",
		"The complete defensive package. Comes in a very large bottle.", 2, 150,
		[_aff["fort_armor"], _aff["fort_barrier"], _aff["fort_health"]])
	_save_consumable(ci, sub, "fortification_elixir")

	# -- Utility --
	ci = _make_t2("Lucky Charm Dust", "+5 Luck for next combat",
		"Ground-up four-leaf clovers. Probably.", 1, 35, [_aff["luck_5"]])
	_save_consumable(ci, sub, "lucky_charm_dust")

	ci = _make_t2("Scholar's Stimulant", "+5 Intellect for next combat",
		"Think faster. Think harder. Think too much.", 1, 35, [_aff["int_5"]])
	_save_consumable(ci, sub, "scholars_stimulant")

	ci = _make_t2("Berserker's Draft", "+5 Strength for next combat",
		"Hit harder. Think less. It balances out.", 1, 35, [_aff["str_5"]])
	_save_consumable(ci, sub, "berserkers_draft")

	ci = _make_t2("Fleet-Foot Tonic", "+5 Agility for next combat",
		"Makes you quicker. Not more graceful.", 1, 35, [_aff["agi_5"]])
	_save_consumable(ci, sub, "fleet_foot_tonic")

	ci = _make_t2("Prospector's Draught", "+25% Gold Find for next combat",
		"You will notice coins you would normally miss.", 1, 40, [_aff["gold_find"]])
	_save_consumable(ci, sub, "prospectors_draught")

	ci = _make_t2("Mana Catalyst", "-20% Mana Costs for next combat",
		"Reduces mana costs. Side effects: blue tongue.", 2, 65, [_aff["mana_cost"]])
	_save_consumable(ci, sub, "mana_catalyst")


func _make_t2(p_name: String, p_desc: String, p_flavor: String,
		p_rarity: int, p_value: int, p_affixes: Array) -> ConsumableItem:
	var ci: ConsumableItem = _make_consumable(p_name, p_desc, p_flavor,
		CT.COMBAT_PREP, p_rarity, UC.PRE_COMBAT, p_value, 5)
	ci.granted_affixes.assign(p_affixes)
	ci.combat_duration = 1
	return ci


# ============================================================================
# T3 DICE ELIXIRS
# ============================================================================

func _generate_t3_dice_elixirs():
	var sub: String = "dice_elixirs"
	var ci: ConsumableItem

	ci = _make_t3("Gambler's Blessing", "+1 to all die rolls for next combat",
		"Every roll gets a nudge. Today you are the house.", 2, 100,
		[_da["roll_plus1"]], "all")
	_save_consumable(ci, sub, "gamblers_blessing")

	ci = _make_t3("Volatile Flask", "+3 to first die roll",
		"Opening roll hits harder. After that, your problem.", 2, 80,
		[_da["roll_plus3_first"]], "first")
	_save_consumable(ci, sub, "volatile_flask")

	ci = _make_t3("Chain Reaction Tonic", "+2 to right neighbor on use",
		"Each die boosts its neighbor. Positioning matters.", 2, 120,
		[_da["use_plus2_right"]], "all")
	_save_consumable(ci, sub, "chain_reaction_tonic")

	ci = _make_t3("Mirror Polish", "Copy 50% of left neighbor value",
		"Dice mirror the die to their left.", 2, 110,
		[_da["copy_left_50"]], "all")
	_save_consumable(ci, sub, "mirror_polish")

	for elem: String in ["fire", "ice", "shock", "poison", "shadow"]:
		var pretty: String = elem.capitalize()
		ci = _make_t3("%s Ink (Temp)" % pretty, "Set a die's element to %s for next combat" % pretty,
			"Coats a die in %s. Overrides its existing element." % elem, 2, 75,
			[_da["set_%s" % elem]], "all")
		ci.target_type = TT.SINGLE_DIE
		_save_consumable(ci, sub, "%s_ink_temp" % elem)

	ci = _make_t3("Leech Draught", "15% lifesteal on all dice used",
		"Heal for damage dealt by each die. Vampiric, but legal.", 2, 130,
		[_da["leech_15"]], "all")
	_save_consumable(ci, sub, "leech_draught")

	ci = _make_t3("Stabilizer Compound", "Dice cannot roll below 3",
		"Consistency over excitement.", 2, 90,
		[_da["min_3"]], "type:D6+")
	_save_consumable(ci, sub, "stabilizer_compound")

	ci = _make_t3("Chaos Capsule", "Random element on every die roll",
		"Embrace the chaos.", 1, 60,
		[_da["random_elem"]], "all")
	_save_consumable(ci, sub, "chaos_capsule")

	ci = _make_t3("Duelist's Focus", "+4 to last die on use",
		"Save the best for last.", 2, 95,
		[_da["use_plus4_last"]], "last")
	_save_consumable(ci, sub, "duelists_focus")


func _make_t3(p_name: String, p_desc: String, p_flavor: String,
		p_rarity: int, p_value: int,
		p_dice_affixes: Array, p_filter: String) -> ConsumableItem:
	var ci: ConsumableItem = _make_consumable(p_name, p_desc, p_flavor,
		CT.DICE_ELIXIR, p_rarity, UC.PRE_COMBAT, p_value, 5)
	ci.granted_dice_affixes.assign(p_dice_affixes)
	ci.dice_target_filter = p_filter
	ci.combat_duration = 1
	return ci


# ============================================================================
# T4 INSCRIPTIONS
# ============================================================================

func _generate_t4_inscriptions():
	var sub: String = "inscriptions"
	var ci: ConsumableItem

	ci = _make_t4("Rune of Fortification", "+1 to all rolls (permanent)",
		"Etches a rune of power. Permanent. Choose wisely.", 3, 250,
		_da["perm_plus1"])
	_save_consumable(ci, sub, "rune_of_fortification")

	for elem: String in ["fire", "ice", "shock", "poison", "shadow"]:
		var names: Dictionary = {
			"fire": "Inferno", "ice": "Glacier", "shock": "Tempest",
			"poison": "Venom", "shadow": "Twilight"
		}
		var flavors: Dictionary = {
			"fire": "This die burns now. Forever.",
			"ice": "Permanent frost coating. Cold to the touch.",
			"shock": "Sparks when you touch it. Always.",
			"poison": "The green tint never fades. Neither does the smell.",
			"shadow": "Absorbs light. Difficult to find in dim rooms.",
		}
		ci = _make_t4("Rune of the %s" % names[elem],
			"Permanently set element to %s" % elem.capitalize(),
			flavors[elem], 3, 300,
			_da["perm_%s" % elem])
		_save_consumable(ci, sub, "rune_of_%s" % elem)

	ci = _make_t4("Sigil of Vampirism", "10% lifesteal on die use (permanent)",
		"Every hit with this die heals you.", 3, 400, _da["perm_leech"])
	_save_consumable(ci, sub, "sigil_of_vampirism")

	ci = _make_t4("Sigil of Conduction", "+2 to right neighbor on use (permanent)",
		"This die makes its neighbor better.", 3, 350, _da["perm_right2"])
	_save_consumable(ci, sub, "sigil_of_conduction")

	ci = _make_t4("Sigil of the Anchor", "+3 when in first position (permanent)",
		"Strongest in the lead. A natural first mate.", 3, 350, _da["perm_anchor"])
	_save_consumable(ci, sub, "sigil_of_the_anchor")

	ci = _make_t4("Sigil of the Stern", "+3 when in last position (permanent)",
		"Strongest at the rear. Every fleet needs a rearguard.", 3, 350, _da["perm_stern"])
	_save_consumable(ci, sub, "sigil_of_the_stern")

	ci = _make_t4("Sigil of Ignition", "Apply 2 Burn stacks on use (permanent)",
		"Fire dice apply burn. Every time.", 3, 350, _da["perm_burn"], ["element:FIRE"])
	_save_consumable(ci, sub, "sigil_of_ignition")

	ci = _make_t4("Sigil of Fracture", "Apply 2 Bleed stacks on use (permanent)",
		"Sharp dice draw blood. Reliably.", 3, 350, _da["perm_bleed"],
		["element:SLASHING", "element:PIERCING"])
	_save_consumable(ci, sub, "sigil_of_fracture")

	# Erasure Solvent — special: removes an inscription
	ci = _make_consumable("Erasure Solvent", "Remove one inscribed affix from a die",
		"Undoes a previous inscription. The rune fights back.", CT.INSCRIPTION, 2, UC.OUT_OF_COMBAT, 150, 5)
	ci.target_type = TT.SINGLE_DIE
	ci.can_overwrite = true
	# No inscription_affix — the use() logic for erasure is handled specially
	_save_consumable(ci, sub, "erasure_solvent")


func _make_t4(p_name: String, p_desc: String, p_flavor: String,
		p_rarity: int, p_value: int,
		p_dice_affix: DiceAffix,
		p_die_filter: Array = []) -> ConsumableItem:
	var ci: ConsumableItem = _make_consumable(p_name, p_desc, p_flavor,
		CT.INSCRIPTION, p_rarity, UC.OUT_OF_COMBAT, p_value, 3)
	ci.target_type = TT.SINGLE_DIE
	ci.inscription_affix = p_dice_affix
	if p_die_filter.size() > 0:
		ci.inscription_die_filter.assign(p_die_filter)
	return ci
