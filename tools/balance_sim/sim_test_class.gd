# res://tools/balance_sim/sim_test_class.gd
# TEST-ONLY class for the balance simulator. Not game content: built in code,
# never saved, never offered to the player.
#
# It measures the raw system without Mage-specific artefacts:
#   - symmetric stat growth: the build's main stat (Strength or Intellect)
#     grows +2.5 per level, the other +0.5 (the Mage's numbers, mirrored);
#     the class's main stat is the build's, so neutral dice use it too;
#   - HP, Agility and Luck as the Mage (80 + 6 per level);
#   - three basic actions that take any die, any element, any size:
#       Test Strike (class action; slashing for neutral dice),
#       Test Bolt (fire for neutral dice), Test Guard (1 Braced per die).
#     A die keeps its own element; neither attack has an element-match bonus.
#   So every weapon, die and dice affix is usable by both builds.
extends RefCounted

static var _cache: Dictionary = {}


static func make_class(build: String) -> PlayerClass:
	var pc := PlayerClass.new()
	pc.class_id = "sim_test_" + build
	pc.player_class_name = "Sim Test (%s)" % build
	pc.main_stat = PlayerClass.MainStat.STRENGTH if build == "str" else PlayerClass.MainStat.INTELLECT
	pc.base_health = 80
	pc.health_per_level = 6
	pc.base_mana = 0
	pc.mana_per_level = 0
	pc.base_agility = 8
	pc.agility_per_level = 0.5
	pc.base_luck = 10
	pc.luck_per_level = 1.0
	if build == "str":
		pc.base_strength = 14
		pc.strength_per_level = 2.5
		pc.base_intellect = 6
		pc.intellect_per_level = 0.5
	else:
		pc.base_strength = 6
		pc.strength_per_level = 0.5
		pc.base_intellect = 14
		pc.intellect_per_level = 2.5
	pc.class_action = _action("strike")
	pc.class_action_tag = "sim_test_class_action"
	pc.mana_pool_template = null
	return pc


static func extra_action_affixes() -> Array[Affix]:
	"""Test Bolt and Test Guard, granted like any NEW_ACTION affix."""
	var out: Array[Affix] = []
	for kind in ["bolt", "guard"]:
		var a := Affix.new()
		a.affix_name = "Sim Test " + kind
		a.category = Affix.Category.NEW_ACTION
		a.granted_action = _action(kind)
		a.source = "Sim Test Class"
		a.source_type = "class"
		out.append(a)
	return out


static func _action(kind: String) -> Action:
	if _cache.has(kind):
		return _cache[kind]
	var act := Action.new()
	var eff := ActionEffect.new()
	eff.dice_count = 1
	act.die_slots = 1
	act.min_dice_required = 1
	act.charge_type = Action.ChargeType.UNLIMITED
	match kind:
		"strike":
			act.action_id = "sim_test_strike"
			act.action_name = "Test Strike"
			act.action_type = 0
			act.action_category = Action.ActionCategory.ATTACK
			eff.effect_type = ActionEffect.EffectType.DAMAGE
			eff.target = ActionEffect.TargetType.SINGLE_ENEMY
			eff.damage_type = ActionEffect.DamageType.SLASHING
		"bolt":
			act.action_id = "sim_test_bolt"
			act.action_name = "Test Bolt"
			act.action_type = 0
			act.action_category = Action.ActionCategory.ATTACK
			eff.effect_type = ActionEffect.EffectType.DAMAGE
			eff.target = ActionEffect.TargetType.SINGLE_ENEMY
			eff.damage_type = ActionEffect.DamageType.FIRE
		"guard":
			act.action_id = "sim_test_guard"
			act.action_name = "Test Guard"
			act.action_type = 1
			act.action_category = Action.ActionCategory.BUFF
			eff.effect_type = ActionEffect.EffectType.ADD_STATUS
			eff.target = ActionEffect.TargetType.SELF
			eff.status_affix = load("res://resources/statuses/braced.tres")
			eff.stack_count = 1
	var effects: Array[ActionEffect] = [eff]
	act.effects = effects
	# No element-match bonus: -1 is outside the DamageType range, and the
	# damage calculation only applies the bonus for an element >= 0.
	act.set("damage_element", -1)
	act.reset_charges_for_combat()
	_cache[kind] = act
	return act
