@tool
extends EditorScript
## ══════════════════════════════════════════════════════════════════════════════
## CLERIC CLASS GENERATOR — Nayru's Divination / Arcanaeum / Conviction Tree
## ══════════════════════════════════════════════════════════════════════════════
##
## RUN:  Script > Run (Ctrl+Shift+X) in the Godot editor.
##
## PREREQUISITES — Apply cleric_integration_guide.md FIRST:
##   1. SkillTree + SkillResource upgraded to 10 tiers
##   2. DieResource.Element.FAITH enum value added
##   3. DieResource.is_duplicate: bool flag added
##   4. Affix.ValueSource.UNIQUE_ELEMENTS_USED enum value added
##   5. New proc effects in AffixProcProcessor
##   6. DiceAffixProcessor updated for use_die_max + LEAST_USED element
##
## GENERATES ~137 resource files across:
##   dice_affixes/, dice/, actions/, affixes/, skills/, skill_trees/, player_classes/

const BASE       = "res://resources/cleric"
const SKILL_DIR  = BASE + "/skills/nayru"
const AFFIX_DIR  = BASE + "/affixes/nayru"
const DA_DIR     = BASE + "/dice_affixes"
const DICE_DIR   = BASE + "/dice"
const ACTION_DIR = BASE + "/actions"
const TREE_DIR   = "res://resources/skill_trees"
const CLASS_DIR  = "res://resources/player_classes"

var _count: int = 0
var _skill_map: Dictionary = {}
var _affix_map: Dictionary = {}
var _dice_res: Dictionary = {}
var _action_res: Dictionary = {}
var _da_res: Dictionary = {}

func _run():
	print("══════════════════════════════════════════════════════")
	print("🛐  CLERIC CLASS GENERATOR — Nayru's Skill Tree")
	print("══════════════════════════════════════════════════════")
	_ensure_dirs()
	_phase_1_foundation()
	_phase_2_skill_affixes()
	_phase_3_skills()
	_phase_4_prerequisites()
	var tree = _phase_5_tree()
	_phase_6_class(tree)
	print("══════════════════════════════════════════════════════")
	print("✅  Generated %d resources total." % _count)
	print("══════════════════════════════════════════════════════")

func _ensure_dirs():
	for d in [SKILL_DIR, AFFIX_DIR, DA_DIR, DICE_DIR, ACTION_DIR, TREE_DIR, CLASS_DIR]:
		DirAccess.make_dir_recursive_absolute(d)

func _save(res: Resource, path: String):
	var err = ResourceSaver.save(res, path)
	if err != OK:
		push_error("❌ Failed to save %s: %s" % [path, error_string(err)])
	else:
		_count += 1

# ════════════════════════════════════════════════════════════════════════════
# PHASE 1 — Foundation: DiceAffixes, Dice, Actions
# ════════════════════════════════════════════════════════════════════════════
func _phase_1_foundation():
	print("\n── Phase 1: Foundation ──")
	_create_dice_affixes()
	_create_dice()
	_create_actions()

func _create_dice_affixes():
	var da_portent = DiceAffix.new()
	da_portent.affix_name = "Portent — Foreseen Outcome"
	da_portent.description = "This die always rolls its maximum value."
	da_portent.trigger = DiceAffix.Trigger.ON_ROLL
	da_portent.position_requirement = DiceAffix.PositionRequirement.ANY
	da_portent.neighbor_target = DiceAffix.NeighborTarget.SELF
	da_portent.effect_type = DiceAffix.EffectType.SET_ROLL_VALUE
	da_portent.value_source = DiceAffix.ValueSource.STATIC
	da_portent.effect_value = 0.0
	da_portent.effect_data = {"use_die_max": true}
	_save(da_portent, DA_DIR + "/portent_always_max.tres")
	_da_res["portent"] = da_portent

	var cond_max = DiceAffixCondition.new()
	cond_max.type = DiceAffixCondition.Type.SELF_VALUE_IS_MAX
	var da_calc = DiceAffix.new()
	da_calc.affix_name = "Annihilation — Precision Strike"
	da_calc.description = "If at maximum value when used, gain +4."
	da_calc.trigger = DiceAffix.Trigger.ON_USE
	da_calc.position_requirement = DiceAffix.PositionRequirement.ANY
	da_calc.neighbor_target = DiceAffix.NeighborTarget.SELF
	da_calc.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	da_calc.effect_value = 4.0
	da_calc.condition = cond_max
	_save(da_calc, DA_DIR + "/calc_annihilation_bonus.tres")
	_da_res["calc"] = da_calc

	var da_nav = DiceAffix.new()
	da_nav.affix_name = "Navigator's Eye — Pathfinding"
	da_nav.description = "On roll, element becomes your least-used element this combat."
	da_nav.trigger = DiceAffix.Trigger.ON_ROLL
	da_nav.position_requirement = DiceAffix.PositionRequirement.ANY
	da_nav.neighbor_target = DiceAffix.NeighborTarget.SELF
	da_nav.effect_type = DiceAffix.EffectType.SET_ELEMENT
	da_nav.effect_data = {"element": "LEAST_USED"}
	_save(da_nav, DA_DIR + "/navigators_eye_element.tres")
	_da_res["navigator"] = da_nav

	var da_fore = DiceAffix.new()
	da_fore.affix_name = "Forewarned — Opening Gambit"
	da_fore.description = "+2 to die value (first turn)."
	da_fore.trigger = DiceAffix.Trigger.ON_ROLL
	da_fore.position_requirement = DiceAffix.PositionRequirement.ANY
	da_fore.neighbor_target = DiceAffix.NeighborTarget.SELF
	da_fore.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	da_fore.effect_value = 2.0
	_save(da_fore, DA_DIR + "/forewarned_value_boost.tres")
	_da_res["forewarned"] = da_fore
	print("  💾 4 DiceAffixes")

func _create_dice():
	var portent = DieResource.new()
	portent.display_name = "Portent Die"
	portent.die_type = DieResource.DieType.D6
	portent.element = DieResource.Element.FAITH
	portent.is_mana_die = false
	portent.inherent_affixes = [_da_res["portent"]]
	_save(portent, DICE_DIR + "/portent_d6.tres")
	_dice_res["portent"] = portent

	var calc = DieResource.new()
	calc.display_name = "Annihilation Die"
	calc.die_type = DieResource.DieType.D8
	calc.element = DieResource.Element.NONE
	calc.is_mana_die = false
	calc.inherent_affixes = [_da_res["calc"]]
	_save(calc, DICE_DIR + "/calculated_annihilation_d8.tres")
	_dice_res["calc"] = calc

	var nav = DieResource.new()
	nav.display_name = "Navigator's Eye"
	nav.die_type = DieResource.DieType.D10
	nav.element = DieResource.Element.FAITH
	nav.is_mana_die = false
	nav.inherent_affixes = [_da_res["navigator"]]
	_save(nav, DICE_DIR + "/navigators_eye_d10.tres")
	_dice_res["navigator"] = nav
	print("  💾 3 DieResources")

func _create_actions():
	var heal_fx = ActionEffect.new()
	heal_fx.effect_name = "Blessed Healing"
	heal_fx.target = ActionEffect.TargetType.SELF
	heal_fx.effect_type = ActionEffect.EffectType.HEAL
	heal_fx.base_heal = 0
	heal_fx.heal_multiplier = 1.5
	heal_fx.heal_uses_dice = true
	heal_fx.dice_count = 1
	var blessed = Action.new()
	blessed.action_id = "cleric_blessed_hands"
	blessed.action_name = "Blessed Hands"
	blessed.action_description = "Channel faith through touch. Heal self for 1.5× die value."
	blessed.die_slots = 1
	blessed.effects = [heal_fx]
	_save(blessed, ACTION_DIR + "/blessed_hands.tres")
	_action_res["blessed_hands"] = blessed

	var cleanse_fx = ActionEffect.new()
	cleanse_fx.effect_name = "Purifying Light"
	cleanse_fx.target = ActionEffect.TargetType.SELF
	cleanse_fx.effect_type = ActionEffect.EffectType.CLEANSE
	cleanse_fx.cleanse_tags = ["debuff"]
	var bene_heal = ActionEffect.new()
	bene_heal.effect_name = "Benediction Heal"
	bene_heal.target = ActionEffect.TargetType.SELF
	bene_heal.effect_type = ActionEffect.EffectType.HEAL
	bene_heal.base_heal = 0
	bene_heal.heal_multiplier = 2.0
	bene_heal.heal_uses_dice = true
	bene_heal.dice_count = 2
	var bene = Action.new()
	bene.action_id = "cleric_benediction"
	bene.action_name = "Benediction"
	bene.action_description = "Purify and restore. Cleanse all debuffs, then heal for 2× dice total."
	bene.die_slots = 2
	bene.effects = [cleanse_fx, bene_heal]
	_save(bene, ACTION_DIR + "/benediction.tres")
	_action_res["benediction"] = bene
	print("  💾 2 Actions")

# ════════════════════════════════════════════════════════════════════════════
# PHASE 2 — Per-Rank Affixes
# ════════════════════════════════════════════════════════════════════════════
func _phase_2_skill_affixes():
	print("\n── Phase 2: Skill Affixes ──")
	var total = 0
	for entry in _get_skill_catalog():
		var id: String = entry["id"]
		_affix_map[id] = {}
		for rank in range(1, entry.get("max_rank", 1) + 1):
			var affixes: Array[Affix] = _build_affixes(entry, rank)
			_affix_map[id][rank] = affixes
			for i in range(affixes.size()):
				var suffix = "" if affixes.size() == 1 else "_sub%d" % i
				_save(affixes[i], "%s/%s_r%d%s.tres" % [AFFIX_DIR, id, rank, suffix])
				total += 1
	print("  💾 %d Affixes" % total)

func _build_affixes(entry: Dictionary, rank: int) -> Array[Affix]:
	var result: Array[Affix] = []
	match entry.get("mechanic", ""):
		"stat":
			var a = _ba(entry, rank)
			a.category = entry["category"]
			a.effect_number = entry["values"][rank - 1]
			result.append(a)
		"proc":
			var a = _ba(entry, rank)
			a.category = Affix.Category.PROC
			a.proc_trigger = entry["trigger"]
			a.effect_number = entry["values"][rank - 1]
			a.proc_chance = _pc(entry, rank)
			a.effect_data = entry.get("effect_data", {}).duplicate()
			if entry.has("value_source"): a.value_source = entry["value_source"]
			result.append(a)
		"dice_grant":
			var a = _ba(entry, rank)
			a.category = Affix.Category.DICE
			a.granted_dice = [_dice_res[entry["dice_key"]]]
			result.append(a)
		"action_grant":
			var a = _ba(entry, rank)
			a.category = Affix.Category.NEW_ACTION
			a.granted_action = _action_res[entry["action_key"]]
			result.append(a)
		"dice_manip":
			var a = _ba(entry, rank)
			a.category = Affix.Category.DICE
			a.effect_number = entry["values"][rank - 1]
			a.effect_data = entry.get("effect_data", {}).duplicate()
			result.append(a)
		"stacking":
			var a = _ba(entry, rank)
			a.category = Affix.Category.PROC
			a.proc_trigger = entry["trigger"]
			a.effect_number = entry["values"][rank - 1]
			a.effect_data = {
				"proc_effect": "stacking_buff",
				"buff_id": entry.get("buff_id", entry["id"]),
				"buff_category": entry.get("buff_category", "DAMAGE_BONUS"),
				"max_stacks": entry.get("max_stacks", 10),
			}
			result.append(a)
		"custom":
			var a = _ba(entry, rank)
			a.category = entry.get("category", Affix.Category.MISC)
			a.effect_number = _vl(entry, rank)
			a.effect_data = entry.get("effect_data", {}).duplicate()
			if entry.has("proc_trigger"): a.proc_trigger = entry["proc_trigger"]
			if entry.has("value_source"): a.value_source = entry["value_source"]
			result.append(a)
		"compound":
			var a = _ba(entry, rank)
			a.category = entry.get("category", Affix.Category.MISC)
			a.effect_number = _vl(entry, rank)
			a.effect_data = entry.get("effect_data", {}).duplicate()
			if entry.has("proc_trigger"): a.proc_trigger = entry["proc_trigger"]
			result.append(a)
			if entry.has("secondary"):
				var s = entry["secondary"]
				var b = _ba(s, rank)
				b.category = s.get("category", Affix.Category.MISC)
				b.effect_number = _vl(s, rank)
				b.effect_data = s.get("effect_data", {}).duplicate()
				result.append(b)
	return result

func _ba(entry: Dictionary, rank: int) -> Affix:
	var a = Affix.new()
	a.affix_name = "%s (Rank %d)" % [entry["name"], rank]
	a.description = entry.get("desc", "")
	a.source = entry["name"]
	a.source_type = "skill"
	if entry.has("tags"): a.tags = entry["tags"].duplicate()
	return a

func _vl(e: Dictionary, r: int) -> float:
	if not e.has("values"): return 0.0
	return e["values"][mini(r - 1, e["values"].size() - 1)]

func _pc(e: Dictionary, r: int) -> float:
	if not e.has("proc_chances"): return 1.0
	return e["proc_chances"][mini(r - 1, e["proc_chances"].size() - 1)]

# ════════════════════════════════════════════════════════════════════════════
# SKILL CATALOG — 30 Skills, 10 Tiers
# ════════════════════════════════════════════════════════════════════════════
func _get_skill_catalog() -> Array[Dictionary]:
	var C = Affix.Category
	var P = Affix.ProcTrigger
	var VS_UE: int = 8  # ValueSource.UNIQUE_ELEMENTS_USED

	return [
		# TIER 1
		{"id":"nayrus_whisper","name":"Nayru's Whisper","desc":"+N Intellect.","tier":1,"col":3,"max_rank":5,"mechanic":"stat","category":C.INTELLECT_BONUS,"values":[2,4,6,8,10]},
		# TIER 2
		{"id":"third_eye","name":"Third Eye","desc":"Auto-reroll dice below N.","tier":2,"col":1,"max_rank":3,"mechanic":"dice_manip","values":[1,2,3],"effect_data":{"manip_type":"auto_reroll_threshold"},"tags":["dice_manipulation","divination"]},
		{"id":"arcane_foundation","name":"Arcane Foundation","desc":"+N max mana.","tier":2,"col":3,"max_rank":3,"mechanic":"stat","category":C.MANA_BONUS,"values":[3,6,10]},
		{"id":"quiet_devotion","name":"Quiet Devotion","desc":"Heal N at end of turn.","tier":2,"col":5,"max_rank":3,"mechanic":"proc","trigger":P.ON_TURN_END,"values":[3,6,10],"effect_data":{"proc_effect":"heal_flat"},"tags":["heal","faith"]},
		# TIER 3
		{"id":"portent","name":"Portent","desc":"Gain a Faith D6 that always rolls max.","tier":3,"col":0,"max_rank":1,"mechanic":"dice_grant","dice_key":"portent","prereqs":[{"skill":"third_eye","rank":1}]},
		{"id":"charted_waters","name":"Charted Waters","desc":"+N reroll charges per combat.","tier":3,"col":2,"max_rank":3,"mechanic":"dice_manip","values":[1,2,3],"effect_data":{"manip_type":"reroll_charges"},"tags":["dice_manipulation","reroll"]},
		{"id":"sacred_text","name":"Sacred Text","desc":"+N mana regen per turn.","tier":3,"col":4,"max_rank":3,"mechanic":"custom","category":C.PER_TURN,"values":[1,1,2],"effect_data":{"per_turn_type":"mana_regen"},"tags":["mana","regen"]},
		{"id":"guiding_light","name":"Guiding Light","desc":"Gain N barrier on defend.","tier":3,"col":6,"max_rank":3,"mechanic":"proc","trigger":P.ON_DEFEND,"values":[4,8,12],"effect_data":{"proc_effect":"gain_barrier"},"tags":["barrier","faith","defend"],"prereqs":[{"skill":"quiet_devotion","rank":1}]},
		# TIER 4
		{"id":"prescience","name":"Prescience","desc":"+N to D4 and D6 values.","tier":4,"col":0,"max_rank":2,"mechanic":"custom","category":C.MISC,"values":[1,2],"effect_data":{"custom_id":"die_size_value_bonus","die_sizes":[4,6]},"tags":["dice_manipulation","divination"],"prereqs":[{"skill":"portent","rank":1}]},
		{"id":"forewarned","name":"Forewarned","desc":"All dice +N value on turn 1.","tier":4,"col":1,"max_rank":2,"mechanic":"proc","trigger":P.ON_COMBAT_START,"values":[2,4],"effect_data":{"proc_effect":"grant_temp_dice_affix","dice_affix_key":"forewarned","duration_turns":1},"tags":["divination","temp_buff"],"prereqs":[{"skill":"third_eye","rank":1}]},
		{"id":"tome_of_infinite_pages","name":"Tome of Infinite Pages","desc":"Max-roll dice duplicate for this turn.","tier":4,"col":3,"max_rank":1,"mechanic":"dice_manip","values":[1],"effect_data":{"manip_type":"duplicate_on_max_global"},"tags":["dice_manipulation","duplicate"]},
		{"id":"martyrs_resolve","name":"Martyr's Resolve","desc":"On hit, heal N% max HP (more at low HP).","tier":4,"col":5,"max_rank":3,"mechanic":"proc","trigger":P.ON_TAKE_DAMAGE,"values":[0.03,0.05,0.08],"effect_data":{"proc_effect":"heal_percent_max_hp","inverse_hp_scaling":true},"tags":["heal","faith","adversity"],"prereqs":[{"skill":"quiet_devotion","rank":1}]},
		{"id":"consecrated_ground","name":"Consecrated Ground","desc":"Gain N × turn number armor at turn start.","tier":4,"col":6,"max_rank":2,"mechanic":"proc","trigger":P.ON_TURN_START,"values":[1,2],"value_source":Affix.ValueSource.COMBAT_TURN_NUMBER,"effect_data":{"proc_effect":"gain_armor"},"tags":["armor","faith","endurance"],"prereqs":[{"skill":"guiding_light","rank":1}]},
		# TIER 5 — KEYSTONES
		{"id":"oracle","name":"Oracle","desc":"Gain N oracle charges: set any die to max.","tier":5,"col":1,"max_rank":3,"mechanic":"dice_manip","values":[2,3,4],"effect_data":{"manip_type":"oracle_charges"},"tags":["dice_manipulation","oracle","divination"],"prereqs":[{"skill":"forewarned","rank":1}]},
		{"id":"breadth_of_study","name":"Breadth of Study","desc":"+N damage per unique element this turn.","tier":5,"col":3,"max_rank":3,"mechanic":"custom","category":C.PROC,"proc_trigger":P.ON_ACTION_USED,"values":[3,5,7],"value_source":VS_UE,"effect_data":{"proc_effect":"bonus_damage_flat"},"tags":["damage","diversity","knowledge"]},
		{"id":"testament","name":"Testament","desc":"On defend, +N Conviction stacks (dmg+heal).","tier":5,"col":5,"max_rank":3,"mechanic":"stacking","trigger":P.ON_DEFEND,"values":[3,5,8],"buff_id":"conviction","buff_category":"DAMAGE_AND_HEAL_BONUS","max_stacks":10,"tags":["faith","stacking","defend"],"prereqs":[{"skill":"martyrs_resolve","rank":1}]},
		# TIER 6 — CROSSOVERS
		{"id":"augury","name":"Augury","desc":"All dice roll at least N.","tier":6,"col":0,"max_rank":3,"mechanic":"dice_manip","values":[2,3,4],"effect_data":{"manip_type":"minimum_die_value"},"tags":["dice_manipulation","divination"],"prereqs":[{"skill":"oracle","rank":1}]},
		{"id":"foreseen_convergence","name":"Foreseen Convergence","desc":"Oracle'd dice count as 2 elements for diversity.","tier":6,"col":2,"max_rank":1,"mechanic":"custom","category":C.MISC,"values":[1],"effect_data":{"custom_id":"oracle_double_element"},"tags":["crossover","divination","knowledge"],"prereqs":[{"skill":"oracle","rank":1},{"skill":"breadth_of_study","rank":1}]},
		{"id":"deans_authority","name":"Dean's Authority","desc":"Mana cheaper + mana dice one size larger.","tier":6,"col":3,"max_rank":2,"mechanic":"compound","category":C.MANA_COST_MULTIPLIER,"values":[0.8,0.6],"effect_data":{"mana_die_size_bonus":1},"secondary":{"name":"Dean's Authority","desc":"Mana dice +1 size.","category":C.MISC,"values":[1,1],"effect_data":{"custom_id":"mana_die_size_upgrade","size_bonus":1},"tags":["mana"]},"tags":["mana","knowledge"],"prereqs":[{"skill":"breadth_of_study","rank":1}]},
		{"id":"scholastic_faith","name":"Scholastic Faith","desc":"Heal N on die duplication.","tier":6,"col":4,"max_rank":3,"mechanic":"custom","category":C.PROC,"values":[5,10,16],"effect_data":{"proc_effect":"heal_flat","custom_trigger":"on_die_duplicated"},"tags":["crossover","heal","divination","faith"],"prereqs":[{"skill":"tome_of_infinite_pages","rank":1},{"skill":"testament","rank":1}]},
		{"id":"divine_aegis","name":"Divine Aegis","desc":"N% chance to Enfeeble attacker.","tier":6,"col":6,"max_rank":3,"mechanic":"proc","trigger":P.ON_TAKE_DAMAGE,"values":[1,1,1],"proc_chances":[0.25,0.50,0.75],"effect_data":{"proc_effect":"apply_status","status_id":"enfeeble","status_target":"attacker"},"tags":["thorns","faith","status"],"prereqs":[{"skill":"consecrated_ground","rank":1}]},
		# TIER 7 — DEEP POWER
		{"id":"prophecy_fulfilled","name":"Prophecy Fulfilled","desc":"+N damage on max-value die use.","tier":7,"col":1,"max_rank":3,"mechanic":"proc","trigger":P.ON_DIE_USED,"values":[6,10,15],"effect_data":{"proc_effect":"bonus_damage_flat","condition":"die_was_at_max"},"tags":["damage","divination","max_roll"],"prereqs":[{"skill":"oracle","rank":1}]},
		{"id":"calculated_annihilation","name":"Calculated Annihilation","desc":"Gain a D8 with +4 on max value.","tier":7,"col":2,"max_rank":1,"mechanic":"dice_grant","dice_key":"calc","prereqs":[{"skill":"augury","rank":1}]},
		{"id":"blessed_hands","name":"Blessed Hands","desc":"Heal action: 1.5× die value.","tier":7,"col":4,"max_rank":1,"mechanic":"action_grant","action_key":"blessed_hands","prereqs":[{"skill":"testament","rank":1}]},
		{"id":"unbreakable_covenant","name":"Unbreakable Covenant","desc":"+N stacking armor per hit taken.","tier":7,"col":5,"max_rank":3,"mechanic":"stacking","trigger":P.ON_TAKE_DAMAGE,"values":[2,3,5],"buff_id":"covenant_armor","buff_category":"ARMOR_BONUS","max_stacks":20,"tags":["armor","faith","stacking"],"prereqs":[{"skill":"divine_aegis","rank":1}]},
		# TIER 8 — MASTERY
		{"id":"navigators_eye","name":"The Navigator's Eye","desc":"Gain Faith D10: auto-selects least-used element.","tier":8,"col":2,"max_rank":1,"mechanic":"dice_grant","dice_key":"navigator","prereqs":[{"skill":"prophecy_fulfilled","rank":1},{"skill":"scholastic_faith","rank":1}]},
		{"id":"infinite_curriculum","name":"Infinite Curriculum","desc":"Combat start: dice +N per unique pool element.","tier":8,"col":3,"max_rank":2,"mechanic":"custom","category":C.PROC,"proc_trigger":P.ON_COMBAT_START,"values":[1,2],"effect_data":{"proc_effect":"custom","custom_id":"unique_element_combat_modifier"},"tags":["combat_modifier","diversity","knowledge"],"prereqs":[{"skill":"deans_authority","rank":1}]},
		{"id":"benediction","name":"Benediction","desc":"Cleanse all debuffs + heal 2× dice.","tier":8,"col":4,"max_rank":1,"mechanic":"action_grant","action_key":"benediction","prereqs":[{"skill":"blessed_hands","rank":1},{"skill":"deans_authority","rank":1}]},
		# TIER 9 — PENULTIMATE
		{"id":"omniscience","name":"Omniscience","desc":"One die per combat is reusable.","tier":9,"col":1,"max_rank":1,"mechanic":"dice_manip","values":[1],"effect_data":{"manip_type":"lock_die_charges"},"tags":["dice_manipulation","divination","ultimate"],"prereqs":[{"skill":"prophecy_fulfilled","rank":2}]},
		{"id":"eternal_vigil","name":"Eternal Vigil","desc":"Heal N% max HP + barrier at turn start.","tier":9,"col":5,"max_rank":2,"mechanic":"proc","trigger":P.ON_TURN_START,"values":[0.04,0.07],"effect_data":{"proc_effect":"compound","sub_effects":[{"type":"heal_percent_max_hp"},{"type":"gain_barrier","amount":6}]},"tags":["heal","barrier","faith","endurance"],"prereqs":[{"skill":"unbreakable_covenant","rank":2}]},
		# TIER 10 — CAPSTONE
		{"id":"nayrus_ascension","name":"Nayru's Ascension","desc":"Barrier = missing HP. +2 random dice. Min value +2.","tier":10,"col":3,"max_rank":1,"mechanic":"custom","category":C.PROC,"proc_trigger":P.ON_COMBAT_START,"values":[1],"effect_data":{"proc_effect":"custom","custom_id":"nayrus_ascension","barrier_from_missing_hp":true,"grant_random_dice_count":2,"grant_random_dice_min_size":8,"grant_random_dice_max_size":12,"min_die_value_bonus":2},"tags":["capstone","faith","divination","knowledge"],"prereqs":[{"skill":"infinite_curriculum","rank":1}]},
	]

# ════════════════════════════════════════════════════════════════════════════
# PHASE 3 — SkillResources
# ════════════════════════════════════════════════════════════════════════════
func _phase_3_skills():
	print("\n── Phase 3: Skills ──")
	for entry in _get_skill_catalog():
		var skill = SkillResource.new()
		skill.skill_id = entry["id"]
		skill.skill_name = entry["name"]
		skill.description = entry.get("desc", "")
		skill.tier = entry["tier"]
		skill.column = entry["col"]
		skill.skill_point_cost = entry.get("cost", 1)
		skill.tree_points_required = _tg(entry["tier"])
		var ranks = _affix_map.get(entry["id"], {})
		if ranks.has(1): skill.rank_1_affixes = _ta(ranks[1])
		if ranks.has(2): skill.rank_2_affixes = _ta(ranks[2])
		if ranks.has(3): skill.rank_3_affixes = _ta(ranks[3])
		if ranks.has(4): skill.rank_4_affixes = _ta(ranks[4])
		if ranks.has(5): skill.rank_5_affixes = _ta(ranks[5])
		_save(skill, "%s/%s.tres" % [SKILL_DIR, entry["id"]])
		_skill_map[entry["id"]] = skill
	print("  💾 %d Skills" % _skill_map.size())

func _ta(arr: Array) -> Array[Affix]:
	var r: Array[Affix] = []
	for a in arr: r.append(a)
	return r

func _tg(tier: int) -> int:
	match tier:
		1: return 0;  2: return 1;  3: return 3;  4: return 5
		5: return 8;  6: return 11; 7: return 15; 8: return 20
		9: return 25; 10: return 28
		_: return 0

# ════════════════════════════════════════════════════════════════════════════
# PHASE 4 — Prerequisites
# ════════════════════════════════════════════════════════════════════════════
func _phase_4_prerequisites():
	print("\n── Phase 4: Prerequisites ──")
	var wired = 0
	for entry in _get_skill_catalog():
		if not entry.has("prereqs") or entry["prereqs"].is_empty(): continue
		var skill = _skill_map[entry["id"]]
		var prereqs: Array[SkillPrerequisite] = []
		for p in entry["prereqs"]:
			var ps = _skill_map.get(p["skill"])
			if ps == null:
				push_warning("⚠️ Prereq '%s' not found" % p["skill"])
				continue
			var sp = SkillPrerequisite.new()
			sp.required_skill = ps
			sp.required_rank = p.get("rank", 1)
			prereqs.append(sp)
			wired += 1
		skill.prerequisites = prereqs
		_save(skill, "%s/%s.tres" % [SKILL_DIR, entry["id"]])
	print("  🔗 %d links" % wired)

# ════════════════════════════════════════════════════════════════════════════
# PHASE 5 — Skill Tree
# ════════════════════════════════════════════════════════════════════════════
func _phase_5_tree() -> SkillTree:
	print("\n── Phase 5: Skill Tree ──")
	var tree = SkillTree.new()
	tree.tree_id = "nayru"
	tree.tree_name = "Nayru"
	tree.description = "Goddess of Knowledge, Magic, and Faith."
	for entry in _get_skill_catalog():
		var s = _skill_map[entry["id"]]
		match entry["tier"]:
			1:  tree.tier_1_skills.append(s)
			2:  tree.tier_2_skills.append(s)
			3:  tree.tier_3_skills.append(s)
			4:  tree.tier_4_skills.append(s)
			5:  tree.tier_5_skills.append(s)
			6:  tree.tier_6_skills.append(s)
			7:  tree.tier_7_skills.append(s)
			8:  tree.tier_8_skills.append(s)
			9:  tree.tier_9_skills.append(s)
			10: tree.tier_10_skills.append(s)
	tree.tier_2_points_required = 1
	tree.tier_3_points_required = 3
	tree.tier_4_points_required = 5
	tree.tier_5_points_required = 8
	tree.tier_6_points_required = 11
	tree.tier_7_points_required = 15
	tree.tier_8_points_required = 20
	tree.tier_9_points_required = 25
	tree.tier_10_points_required = 28
	_save(tree, TREE_DIR + "/cleric_nayru.tres")
	return tree

# ════════════════════════════════════════════════════════════════════════════
# PHASE 6 — Player Class
# ════════════════════════════════════════════════════════════════════════════
func _phase_6_class(tree: SkillTree):
	print("\n── Phase 6: Player Class ──")
	# FAITH mana element unlock
	var faith_unlock = Affix.new()
	faith_unlock.affix_name = "Faith Element Unlock"
	faith_unlock.description = "Unlocks Faith as a mana element."
	faith_unlock.category = Affix.Category.MANA_ELEMENT_UNLOCK
	faith_unlock.effect_data = {"element": "FAITH"}
	faith_unlock.source = "Cleric Class"
	faith_unlock.source_type = "class"
	_save(faith_unlock, BASE + "/affixes/faith_element_unlock.tres")
	# D4 + D6 size unlocks
	for size in [4, 6]:
		var su = Affix.new()
		su.affix_name = "Mana Size D%d" % size
		su.description = "Unlocks D%d mana dice." % size
		su.category = Affix.Category.MANA_SIZE_UNLOCK
		su.effect_data = {"die_size": size}
		su.source = "Cleric Class"
		su.source_type = "class"
		_save(su, BASE + "/affixes/mana_size_d%d.tres" % size)
	# Class resource
	var cleric = PlayerClass.new()
	cleric.class_id = "cleric"
	cleric.player_class_name = "Cleric"
	cleric.description = "Servant of the divine. Channel deity power through dice mastery, arcane knowledge, and unwavering faith."
	cleric.main_stat = PlayerClass.MainStat.INTELLIGENCE
	cleric.base_health = 90
	cleric.base_mana = 3
	cleric.base_strength = 6
	cleric.base_agility = 6
	cleric.base_intelligence = 12
	cleric.base_luck = 10
	cleric.health_per_level = 8
	cleric.mana_per_level = 0
	cleric.strength_per_level = 0.5
	cleric.agility_per_level = 0.5
	cleric.intelligence_per_level = 2.0
	cleric.luck_per_level = 1.0
	cleric.skill_tree_1 = tree
	var mana = ManaPool.new()
	mana.base_max_mana = 20
	mana.int_mana_ratio = 0.5
	mana.max_level = 50.0
	cleric.mana_pool_template = mana
	_save(cleric, CLASS_DIR + "/cleric.tres")
	print("  🛐 Cleric created!")
