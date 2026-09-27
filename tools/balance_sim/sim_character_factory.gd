# res://tools/balance_sim/sim_character_factory.gd
# Builds the reference players for the balance simulator with the real
# loot code: EquippableItem.initialize_affixes() (the same call
# LootManager.generate_drop makes) rolls base stats, rolled affixes from the
# AffixTableRegistry slot tables, and gear dice with dice affixes from
# DieGenerator / DiceAffixTableRegistry.
#
# Profiles (Balance Targets "Reference players"), per equipment slot:
#   undergeared  item level L-5, every item Common (no rolled affixes, plain dice)
#   on_curve     item level L-3..L, rarity rolled with the Elite drop weights
#                (Common 20 / Uncommon 45 / Rare 25 / Epic 10), one drop per slot
#   well_geared  item level L, rarity rolled with the Boss drop weights
#                (Uncommon 15 / Rare 40 / Epic 45), best of 3 drops per slot
#   min_maxed    item level L, every item Epic, best of 10 drops per slot
# "Best" = the build score below (affix power, build stats counted double).
# Every slot is filled. The weapon is drawn uniformly from the build's weapon
# list; a one-handed weapon gets a random off-hand. Class: Mage (the only
# class in the game) for both builds; no skill points are spent.
extends RefCounted

const R1 := "res://resources/items/region_1/"
const SLOT_TEMPLATES := {
	"Head": ["arcane_circlet", "iron_helm", "leather_cap", "marine_helm", "plated_circlet", "runed_iron_helm", "scholars_circlet", "scouts_half_helm", "warded_leather_cap"],
	"Torso": ["arcane_robe", "iron_cuirass", "leather_jerkin", "marine_cuirass", "plated_robe", "runed_iron_cuirass", "scholars_robe", "scouts_jerkin", "warded_leather_jerkin"],
	"Gloves": ["arcane_wraps", "iron_gauntlets", "leather_gloves", "marine_gauntlets", "plated_wraps", "runed_iron_gauntlets", "scholars_wraps", "scouts_gloves", "warded_leather_gloves"],
	"Boots": ["arcane_shoes", "iron_boots", "leather_boots", "marine_boots", "plated_shoes", "runed_iron_boots", "scholars_shoes", "scouts_boots", "warded_leather_boots"],
	"Accessory": ["arcane_pendant", "iron_signet", "naval_medallion", "riders_pendant", "scholars_ring", "scouts_band"],
	"Off Hand": ["naval_shield_armor", "naval_shield_barrier", "naval_shield_hybrid", "parrying_blade", "scouts_buckler_armor", "scouts_buckler_barrier", "scouts_buckler_hybrid", "worn_tome_armor", "worn_tome_barrier", "worn_tome_hybrid"],
}
const SLOT_DIR := {"Head": "head", "Torso": "torso", "Gloves": "gloves", "Boots": "boots", "Accessory": "accessory", "Off Hand": "off_hand"}

## Weapons by build: [template, folder]
const WEAPONS := {
	"str": [["sanctum_stiletto", "main_hand"], ["officers_rapier", "main_hand"], ["iron_mace", "main_hand"], ["naval_cutlass", "main_hand"],
		["longbow", "heavy"], ["marine_halberd", "heavy"], ["iron_warhammer", "heavy"], ["naval_greatsword", "heavy"]],
	"int": [["cinder_wand", "main_hand"], ["frost_wand", "main_hand"], ["spark_wand", "main_hand"],
		["ember_staff", "heavy"], ["frost_staff_region1", "heavy"], ["storm_staff", "heavy"], ["venom_staff", "heavy"], ["shadow_staff", "heavy"]],
}

const PROFILES := {
	"undergeared": {"ilvl_min": -5, "ilvl_max": -5, "weights": [1, 0, 0, 0], "candidates": 1},
	"on_curve": {"ilvl_min": -3, "ilvl_max": 0, "weights": [20, 45, 25, 10], "candidates": 1},
	"well_geared": {"ilvl_min": 0, "ilvl_max": 0, "weights": [0, 15, 40, 45], "candidates": 3},
	"min_maxed": {"ilvl_min": 0, "ilvl_max": 0, "weights": [0, 0, 0, 1], "candidates": 10},
}
const PROFILE_ORDER := ["undergeared", "on_curve", "well_geared", "min_maxed"]

## Pre-fight consumables by profile (combat preps last one fight).
##   undergeared: none. on_curve: a damage prep before elite, mini-boss and
##   boss fights. well_geared: damage prep + Ironbark before elite+.
##   min_maxed: damage prep + Slayer's Draft + Fortification Elixir every fight.
const CONS := "res://resources/consumables/region_1/"
const ELEMENT_PREP := {"fire": "oil_of_burning", "ice": "frost_resin", "shock": "voltaic_paste", "poison": "toxin_extract", "shadow": "shadow_pitch"}

var holder: Node = null
var _template_cache: Dictionary = {}
var _class_res: PlayerClass = null


func _init(p_holder: Node) -> void:
	holder = p_holder
	_class_res = load("res://resources/player_classes/mage.tres")


func _template(path: String) -> EquippableItem:
	if not _template_cache.has(path):
		_template_cache[path] = load(path)
	return _template_cache[path]


func _roll_rarity(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var r := randi() % maxi(1, total)
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return 0


func make_item(path: String, item_level: int, rarity: int) -> EquippableItem:
	"""The body of LootManager.generate_drop with an exact item level."""
	var item: EquippableItem = _template(path).duplicate(true)
	item.rarity = rarity
	item.item_level = clampi(item_level, 1, 100)
	item.required_level = 1
	item.initialize_affixes()
	return item


static func build_score(item: EquippableItem, build: String) -> float:
	var s := 0.0
	for a in item.item_affixes:
		if a is Affix:
			s += a.get_affix_power() * _relevance(a.category, build)
	for d in item.get_runtime_dice():
		if d is DieResource:
			for da in d.get_all_affixes():
				s += da.get_affix_power()
	return s


static func _relevance(cat: int, build: String) -> float:
	var C = Affix.Category
	var phys := [C.SLASHING_DAMAGE_BONUS, C.BLUNT_DAMAGE_BONUS, C.PIERCING_DAMAGE_BONUS]
	var magic := [C.FIRE_DAMAGE_BONUS, C.ICE_DAMAGE_BONUS, C.SHOCK_DAMAGE_BONUS, C.POISON_DAMAGE_BONUS, C.SHADOW_DAMAGE_BONUS]
	if cat in [C.DAMAGE_BONUS, C.DAMAGE_MULTIPLIER]:
		return 2.0
	if build == "str":
		if cat in [C.STRENGTH_BONUS, C.STRENGTH_MULTIPLIER]:
			return 2.5
		if cat in phys:
			return 2.0
		if cat in [C.INTELLECT_BONUS, C.INTELLECT_MULTIPLIER] or cat in magic:
			return 0.3
	else:
		if cat in [C.INTELLECT_BONUS, C.INTELLECT_MULTIPLIER]:
			return 2.5
		if cat in magic:
			return 2.0
		if cat in [C.STRENGTH_BONUS, C.STRENGTH_MULTIPLIER] or cat in phys:
			return 0.3
	return 1.0


func _pick_item(paths: Array, level: int, profile: Dictionary, build: String) -> EquippableItem:
	var best: EquippableItem = null
	var best_s := -1.0
	for i in int(profile["candidates"]):
		var path: String = paths[randi() % paths.size()]
		var ilvl := level + randi_range(int(profile["ilvl_min"]), int(profile["ilvl_max"]))
		var item := make_item(path, ilvl, _roll_rarity(profile["weights"]))
		var s := build_score(item, build)
		if best == null or s > best_s:
			best = item
			best_s = s
	return best


func new_player(level: int) -> Player:
	var p := Player.new()
	holder.add_child(p.dice_pool)
	holder.add_child(p.status_tracker)
	var pc: PlayerClass = _class_res.duplicate()
	p.add_class(pc.player_class_name, pc)
	p.switch_class(pc.player_class_name)
	pc.level = level
	p.level = level
	p.recalculate_stats()
	p.current_hp = p.max_hp
	return p


func free_player(p: Player) -> void:
	if p == null:
		return
	for n in [p.dice_pool, p.status_tracker]:
		if is_instance_valid(n) and n.get_parent() == holder:
			holder.remove_child(n)
			n.queue_free()


func build_character(level: int, profile_name: String, build: String, weapon_index: int = -1) -> Dictionary:
	"""A geared reference player. Returns {player, weapon, profile, build, level}."""
	var profile: Dictionary = PROFILES[profile_name]
	var p := new_player(level)
	var weapons: Array = WEAPONS[build]
	var w: Array = weapons[weapon_index if weapon_index >= 0 else randi() % weapons.size()]
	var wpath: String = R1 + w[1] + "/" + w[0] + ".tres"
	var weapon := _pick_item([wpath], level, profile, build)
	p.equip_item(weapon)
	var slots := ["Head", "Torso", "Gloves", "Boots", "Accessory"]
	if not weapon.is_heavy_weapon():
		slots.append("Off Hand")
	for slot in slots:
		var paths: Array = []
		for t in SLOT_TEMPLATES[slot]:
			paths.append(R1 + SLOT_DIR[slot] + "/" + t + ".tres")
		var item := _pick_item(paths, level, profile, build)
		p.equip_item(item, slot)
	p.recalculate_stats()
	p.current_hp = p.max_hp
	var elem := ""
	var ident := weapon.get_elemental_identity()
	if ident >= 0:
		elem = str(ActionEffect.DamageType.keys()[ident]).to_lower()
	return {"player": p, "weapon": w[0], "weapon_element": elem, "profile": profile_name, "build": build, "level": level}


func apply_preps(ch: Dictionary, tier: String) -> void:
	"""Use the profile's pre-fight consumables (real ConsumableItem.use)."""
	var p: Player = ch["player"]
	var names: Array = []
	var elite_plus := tier != "trash"
	var dmg_prep := "whetstone_fine"
	if ch["build"] == "int" and ELEMENT_PREP.has(ch["weapon_element"]):
		dmg_prep = ELEMENT_PREP[ch["weapon_element"]]
	match ch["profile"]:
		"on_curve":
			if elite_plus:
				names = [dmg_prep]
		"well_geared":
			if elite_plus:
				names = [dmg_prep, "ironbark_tincture"]
		"min_maxed":
			names = [dmg_prep, "slayers_draft", "fortification_elixir"]
	for n in names:
		var c: ConsumableItem = load(CONS + "combat_preps/" + n + ".tres")
		if c:
			c.duplicate().use(p, {})
