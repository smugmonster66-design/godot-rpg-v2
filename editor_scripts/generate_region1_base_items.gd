@tool
extends EditorScript
# ============================================================================
# generate_region1_base_items.gd
# Region 1 (Sanctum) — Base EquippableItem Template Generator
#
# Creates 68 base item templates across all 8 equipment slots.
# Each template has:
#   - Inherent primary stat affix (STR/AGI/INT)
#   - Inherent secondary stat affix (varied per slot)
#   - Defense affix for armor/off-hand slots (Armor/Barrier/Hybrid)
#   - Granted dice for weapons
#   - Elemental identity for weapons
#   - Sanctum-themed names, descriptions, flavor text
#
# Items are stamped at item_level=1, region=1. LootManager re-stamps
# item_level at drop time. Rarity is set to UNCOMMON as the minimum
# drop tier; LootManager overrides rarity at generation time.
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
# ============================================================================

const BASE_DIR := "res://resources/items/region_1"

# Affix Category shortcuts
const C := Affix.Category
# EquipSlot shortcuts
const ES := EquippableItem.EquipSlot
# DamageType shortcuts
const DT := ActionEffect.DamageType
# DieType shortcuts
const DIE := DieResource.DieType
# Element shortcuts
const EL := DieResource.Element

var _count := 0

func _run():
	print("=" .repeat(60))
	print("  REGION 1 BASE ITEM GENERATOR")
	print("=" .repeat(60))

	_ensure_dirs()
	_generate_armor_items()
	_generate_main_hand_items()
	_generate_off_hand_items()
	_generate_heavy_items()
	_generate_accessory_items()

	print("")
	print("=" .repeat(60))
	print("  DONE — %d items generated" % _count)
	print("=" .repeat(60))

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

func _ensure_dirs():
	var da := DirAccess.open("res://")
	# FIX: Type loop var — array literal yields Variant
	for folder: String in ["head", "torso", "gloves", "boots", "main_hand", "off_hand", "heavy", "accessory"]:
		# FIX: Explicit type — Variant + String can't infer
		var path: String = BASE_DIR + "/" + folder
		if not da.dir_exists(path):
			da.make_dir_recursive(path)
			print("  📁 Created %s" % path)

# ============================================================================
# ARMOR ITEMS  (Head, Torso, Gloves, Boots × 3 stats × 3 defense = 36)
# ============================================================================

func _generate_armor_items():
	print("\n── ARMOR ──")

	# [slot_enum, folder, slot_label, secondary_map]
	# secondary_map: {primary_stat_category: secondary_stat_category}
	var armor_slots := [
		[ES.HEAD, "head", "Head", {
			C.STRENGTH_BONUS: C.HEALTH_BONUS,
			C.AGILITY_BONUS:  C.MANA_BONUS,
			C.INTELLECT_BONUS: C.MANA_BONUS,
		}],
		[ES.TORSO, "torso", "Torso", {
			C.STRENGTH_BONUS: C.HEALTH_BONUS,
			C.AGILITY_BONUS:  C.HEALTH_BONUS,
			C.INTELLECT_BONUS: C.HEALTH_BONUS,
		}],
		[ES.GLOVES, "gloves", "Gloves", {
			C.STRENGTH_BONUS: C.DAMAGE_BONUS,
			C.AGILITY_BONUS:  C.DAMAGE_BONUS,
			C.INTELLECT_BONUS: C.DAMAGE_BONUS,
		}],
		[ES.BOOTS, "boots", "Boots", {
			C.STRENGTH_BONUS: C.DEFENSE_BONUS,
			C.AGILITY_BONUS:  C.HEALTH_BONUS,
			C.INTELLECT_BONUS: C.MANA_BONUS,
		}],
	]

	for slot_data in armor_slots:
		var slot_enum: int = slot_data[0]
		var folder: String = slot_data[1]
		var slot_label: String = slot_data[2]
		var secondary_map: Dictionary = slot_data[3]

		# FIX: Type loop var — array literal yields Variant
		for primary_cat: int in [C.STRENGTH_BONUS, C.AGILITY_BONUS, C.INTELLECT_BONUS]:
			var secondary_cat: int = secondary_map[primary_cat]
			var stat_key: String = _stat_key(primary_cat)

			# FIX: Type loop var — array literal yields Variant
			for defense_type: String in ["armor", "barrier", "hybrid"]:
				var naming := _armor_name(slot_label, stat_key, defense_type)
				var item := _create_base_item(naming.name, slot_enum)
				item.description = naming.desc
				item.flavor_text = naming.flavor

				# Base stat affixes (separate from rolled affix slots)
				# Pure armor/barrier: stat + secondary + defense
				# Hybrid: stat + half-armor + half-barrier (trades secondary for balanced defense)
				var affixes: Array[Affix] = []
				affixes.append(_make_stat_affix(primary_cat))
				if defense_type == "hybrid":
					affixes.append(_make_half_armor_affix())
					affixes.append(_make_half_barrier_affix())
				else:
					affixes.append(_make_stat_affix(secondary_cat))
					affixes.append(_make_defense_affix(defense_type))
				# FIX: .assign() for @export typed array
				item.base_stat_affixes.assign(affixes)

				var file_name: String = _sanitize(naming.name)
				_save_item(item, folder, file_name)

# ============================================================================
# MAIN HAND WEAPONS  (7 archetypes)
# ============================================================================

func _generate_main_hand_items():
	print("\n── MAIN HAND ──")

	# [name, file, element, die_type, die_element, primary, secondary, desc, flavor]
	var weapons := [
		{
			"name": "Naval Cutlass",
			"file": "naval_cutlass",
			"element": DT.SLASHING,
			"die_size": DIE.D6,
			"die_element": EL.SLASHING,
			"primary": C.STRENGTH_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "Standard-issue naval sidearm. Approved for deck combat, corridor fighting, and aggressive negotiation.",
			"flavor": "Requisition Form 14-C: 'One (1) cutlass, regulation. Not to be used for opening coconuts. Again.'",
		},
		{
			"name": "Officer's Rapier",
			"file": "officers_rapier",
			"element": DT.PIERCING,
			"die_size": DIE.D6,
			"die_element": EL.PIERCING,
			"primary": C.AGILITY_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "A gentleman's weapon for a gentleman's duel. Sanctum officers carry these as a matter of tradition and mild intimidation.",
			"flavor": "The Officer's Handbook, Section 7: 'Dueling is technically prohibited. Technically.'",
		},
		{
			"name": "Iron Mace",
			"file": "iron_mace",
			"element": DT.BLUNT,
			"die_size": DIE.D6,
			"die_element": EL.BLUNT,
			"primary": C.STRENGTH_BONUS,
			"secondary": C.HEALTH_BONUS,
			"desc": "Heavy, blunt, and remarkably persuasive. Popular among dock enforcers and people who prefer their arguments concise.",
			"flavor": "Some problems can't be solved with paperwork. For everything else, there's the mace.",
		},
		{
			"name": "Sanctum Stiletto",
			"file": "sanctum_stiletto",
			"element": DT.PIERCING,
			"die_size": DIE.D4,
			"die_element": EL.PIERCING,
			"primary": C.AGILITY_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "A slim blade favored by those who solve problems quietly. Not technically listed in any naval inventory.",
			"flavor": "It's a letter opener. A very sharp, very concealable letter opener.",
		},
		{
			"name": "Cinder Wand",
			"file": "cinder_wand",
			"element": DT.FIRE,
			"die_size": DIE.D4,
			"die_element": EL.FIRE,
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "A slender wand that smells faintly of smoke. Academy-standard for pyromantic exercises.",
			"flavor": "Warranty void if used to light cigars. (It will be used to light cigars.)",
		},
		{
			"name": "Frost Wand",
			"file": "frost_wand",
			"element": DT.ICE,
			"die_size": DIE.D4,
			"die_element": EL.ICE,
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "Cold to the touch and occasionally to the personality. Standard-issue for cryomantic cadets.",
			"flavor": "Also useful for keeping drinks cold at officer's mess. Unofficially.",
		},
		{
			"name": "Spark Wand",
			"file": "spark_wand",
			"element": DT.SHOCK,
			"die_size": DIE.D4,
			"die_element": EL.SHOCK,
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "Crackles with static even when idle. The Academy recommends rubber gloves, which no one wears.",
			"flavor": "Side effects may include involuntary hair styling and an inability to pet cats.",
		},
	]

	# FIX: Type loop var — Dictionary array yields Variant
	for w: Dictionary in weapons:
		var item := _create_base_item(w.name, ES.MAIN_HAND)
		item.description = w.desc
		item.flavor_text = w.flavor
		item.has_elemental_identity = true
		item.elemental_identity = w.element
		var affixes: Array[Affix] = []
		affixes.append(_make_stat_affix(w.primary))
		affixes.append(_make_stat_affix(w.secondary))
		# FIX: .assign() for @export typed arrays
		item.base_stat_affixes.assign(affixes)
		item.grants_dice.assign(_make_dice_array(w.die_size, w.die_element, w.name))
		item.base_value = 15 if w.die_size == DIE.D6 else 10
		_save_item(item, "main_hand", w.file)

# ============================================================================
# OFF HAND  (3 archetypes × 3 defense + 1 parrying blade = 10)
# ============================================================================

func _generate_off_hand_items():
	print("\n── OFF HAND ──")

	# Shield (STR), Buckler (AGI), Tome (INT) — each with 3 defense variants
	var off_hand_archetypes := [
		{
			"base_name": "Naval Shield",
			"file_prefix": "naval_shield",
			"primary": C.STRENGTH_BONUS,
			"secondary": C.HEALTH_BONUS,
			"base_desc": "A broad shield bearing Sanctum's anchor emblem. Designed for holding formation on a pitching deck.",
			"flavors": {
				"armor": "Stops swords. Stops arrows. Does not stop superior officers from assigning extra watch duty.",
				"barrier": "The enchantment glows faintly when struck. The enchanter's invoice glows considerably brighter.",
				"hybrid": "Half steel, half sorcery. Sanctum's military budget in physical form.",
			},
		},
		{
			"base_name": "Scout's Buckler",
			"file_prefix": "scouts_buckler",
			"primary": C.AGILITY_BONUS,
			"secondary": C.HEALTH_BONUS,
			"base_desc": "A light round shield strapped to the forearm. Favored by griffin riders and anyone who needs a free hand.",
			"flavors": {
				"armor": "Small enough to not slow you down. Large enough to matter.",
				"barrier": "The ward shimmers when you move quickly. The faster you go, the better it works.",
				"hybrid": "Light steel rim, magical core. The rider's compromise.",
			},
		},
		{
			"base_name": "Worn Tome",
			"file_prefix": "worn_tome",
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"base_desc": "A thick reference manual that doubles as a focus. The marginalia is in three languages, two of which may not exist.",
			"flavors": {
				"armor": "Reinforced binding. Some spells require a blunt instrument, and this qualifies.",
				"barrier": "The pages themselves are warded. Try to read them too fast and they ward you off.",
				"hybrid": "Metal clasps and arcane ink. Knowledge is power, and so is getting hit with this.",
			},
		},
	]

	# FIX: Type loop var — Dictionary array yields Variant
	for archetype: Dictionary in off_hand_archetypes:
		# FIX: Type loop var — array literal yields Variant
		for defense_type: String in ["armor", "barrier", "hybrid"]:
			var suffix: String = _defense_name_suffix(defense_type)
			var name_str: String
			if defense_type == "armor":
				name_str = archetype.base_name
			else:
				name_str = suffix + " " + archetype.base_name

			var item := _create_base_item(name_str, ES.OFF_HAND)
			item.description = archetype.base_desc
			item.flavor_text = archetype.flavors[defense_type]
			var affixes: Array[Affix] = []
			affixes.append(_make_stat_affix(archetype.primary))
			if defense_type == "hybrid":
				affixes.append(_make_half_armor_affix())
				affixes.append(_make_half_barrier_affix())
			else:
				affixes.append(_make_stat_affix(archetype.secondary))
				affixes.append(_make_defense_affix(defense_type))
			# FIX: .assign() for @export typed array
			item.base_stat_affixes.assign(affixes)
			item.base_value = 12

			var file_name: String = archetype.file_prefix + "_" + defense_type
			_save_item(item, "off_hand", file_name)

	# Parrying Blade — no defense variant, grants a die instead
	var parry := _create_base_item("Parrying Blade", ES.OFF_HAND)
	parry.description = "A long dagger designed for catching and deflecting blows. Also surprisingly good at catching and deflecting arguments."
	parry.flavor_text = "The best defense is a good offense. The second best defense is a blade in the other hand."
	parry.has_elemental_identity = true
	parry.elemental_identity = DT.PIERCING
	var parry_affixes: Array[Affix] = []
	parry_affixes.append(_make_stat_affix(C.AGILITY_BONUS))
	parry_affixes.append(_make_stat_affix(C.DAMAGE_BONUS))
	# FIX: .assign() for @export typed arrays
	parry.base_stat_affixes.assign(parry_affixes)
	parry.grants_dice.assign(_make_dice_array(DIE.D4, EL.PIERCING, "Parrying Blade"))
	parry.base_value = 12
	_save_item(parry, "off_hand", "parrying_blade")

# ============================================================================
# HEAVY WEAPONS  (9 archetypes)
# ============================================================================

func _generate_heavy_items():
	print("\n── HEAVY ──")

	var heavies := [
		# STR weapons — single D8
		{
			"name": "Naval Greatsword",
			"file": "naval_greatsword",
			"element": DT.SLASHING,
			"dice": [[DIE.D8, EL.SLASHING]],
			"primary": C.STRENGTH_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "A two-handed blade that makes a statement. The statement is usually 'get out of my way.'",
			"flavor": "Requisition Form 14-C (Heavy): 'Approval required from two officers. Neither of whom wants to argue with someone holding this.'",
		},
		{
			"name": "Iron Warhammer",
			"file": "iron_warhammer",
			"element": DT.BLUNT,
			"dice": [[DIE.D8, EL.BLUNT]],
			"primary": C.STRENGTH_BONUS,
			"secondary": C.HEALTH_BONUS,
			"desc": "What it lacks in subtlety, it makes up for in everything else. Popular in the naval yards for resolving structural and interpersonal disputes.",
			"flavor": "Maintenance log: 'Used to repair hull breach. Also caused hull breach. Net positive.'",
		},
		{
			"name": "Marine Halberd",
			"file": "marine_halberd",
			"element": DT.PIERCING,
			"dice": [[DIE.D8, EL.PIERCING]],
			"primary": C.STRENGTH_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "The preferred weapon of Sanctum's marine boarding parties. Excellent reach for keeping enemies at exactly the distance you want them.",
			"flavor": "Boarding Protocol, Step 1: Point halberd at enemy. Step 2: Advance. Step 3: There is no step 3.",
		},
		# AGI weapon — two D6s
		{
			"name": "Longbow",
			"file": "longbow",
			"element": DT.PIERCING,
			"dice": [[DIE.D6, EL.PIERCING], [DIE.D6, EL.PIERCING]],
			"primary": C.AGILITY_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "A tall bow of yew and sinew. Sanctum's watchtower sentries carry these, along with an unhealthy sense of superiority over ground troops.",
			"flavor": "Effective range: very far. Effective smugness: even farther.",
		},
		# INT staves — two D6s each
		{
			"name": "Ember Staff",
			"file": "ember_staff",
			"element": DT.FIRE,
			"dice": [[DIE.D6, EL.FIRE], [DIE.D6, EL.FIRE]],
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "A blackened staff that trails sparks. The Academy classifies it as 'moderately hazardous,' which is Academy-speak for 'exciting.'",
			"flavor": "Fire Safety Regulation 12: 'Do not store near flammable materials.' This includes most of the Academy.",
		},
		{
			"name": "Frost Staff",
			"file": "frost_staff_region1",
			"element": DT.ICE,
			"dice": [[DIE.D6, EL.ICE], [DIE.D6, EL.ICE]],
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "Perpetually cold, occasionally frosted. Leaving it near beverages is considered a perk, not a malfunction.",
			"flavor": "The Academy's cooling budget dropped significantly after issuing these. Coincidence, surely.",
		},
		{
			"name": "Storm Staff",
			"file": "storm_staff",
			"element": DT.SHOCK,
			"dice": [[DIE.D6, EL.SHOCK], [DIE.D6, EL.SHOCK]],
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "The air around it smells of ozone and poor decisions. Banned from use during thunderstorms after the Incident.",
			"flavor": "We don't talk about the Incident. Except in the safety manual. Pages 47 through 83.",
		},
		{
			"name": "Venom Staff",
			"file": "venom_staff",
			"element": DT.POISON,
			"dice": [[DIE.D6, EL.POISON], [DIE.D6, EL.POISON]],
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "Carved from a toxic wood that probably shouldn't have been carved. The green sheen is either magical or a health hazard.",
			"flavor": "Handling instructions: gloves recommended. Tasting instructions: absolutely not.",
		},
		{
			"name": "Shadow Staff",
			"file": "shadow_staff",
			"element": DT.SHADOW,
			"dice": [[DIE.D6, EL.SHADOW], [DIE.D6, EL.SHADOW]],
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "The shadows around it seem slightly too deep and slightly too interested in what you're doing. The Academy keeps these under lock and key.",
			"flavor": "Access requires Form 91-Blackout, signed by three department heads, two of whom deny it exists.",
		},
	]

	# FIX: Type loop var — Dictionary array yields Variant
	for h: Dictionary in heavies:
		var item := _create_base_item(h.name, ES.HEAVY)
		item.description = h.desc
		item.flavor_text = h.flavor
		item.has_elemental_identity = true
		item.elemental_identity = h.element
		var affixes: Array[Affix] = []
		affixes.append(_make_stat_affix(h.primary))
		affixes.append(_make_stat_affix(h.secondary))
		# FIX: .assign() for @export typed array
		item.base_stat_affixes.assign(affixes)
		item.base_value = 25

		var dice_arr: Array[DieResource] = []
		# FIX: Type loop var — nested array yields Variant
		for die_data: Array in h.dice:
			var die := _make_die(die_data[0], die_data[1], h.name)
			dice_arr.append(die)
		# FIX: .assign() for @export typed array
		item.grants_dice.assign(dice_arr)

		_save_item(item, "heavy", h.file)

# ============================================================================
# ACCESSORIES  (6 templates)
# ============================================================================

func _generate_accessory_items():
	print("\n── ACCESSORY ──")

	var accessories := [
		{
			"name": "Iron Signet",
			"file": "iron_signet",
			"primary": C.STRENGTH_BONUS,
			"secondary": C.HEALTH_BONUS,
			"desc": "A heavy ring bearing an anchor seal. Worn by naval enlisted to prove their service, and occasionally to improve their punches.",
			"flavor": "The seal reads 'SERVICE, DUTY, PAPERWORK.' The last word is worn away on most examples.",
		},
		{
			"name": "Scout's Band",
			"file": "scouts_band",
			"primary": C.AGILITY_BONUS,
			"secondary": C.HEALTH_BONUS,
			"desc": "A slim ring worn by griffin riders and scouts. Enchanted to stay on during aerial maneuvers, which says something about the maneuvers.",
			"flavor": "Officially classified as 'retention jewelry.' No one calls it that.",
		},
		{
			"name": "Scholar's Ring",
			"file": "scholars_ring",
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "A ring set with a cloudy crystal that hums when near magical texts. The Academy awards these upon completion of basic studies.",
			"flavor": "Completion of basic studies takes six years. 'Basic' is relative.",
		},
		{
			"name": "Naval Medallion",
			"file": "naval_medallion",
			"primary": C.STRENGTH_BONUS,
			"secondary": C.DAMAGE_BONUS,
			"desc": "A bronze medallion stamped with Sanctum's crest. Officers who distinguish themselves in combat receive one. Officers who distinguish themselves in paperwork receive two.",
			"flavor": "Wear it over your heart. It won't stop an arrow, but the dramatic irony might slow one down.",
		},
		{
			"name": "Rider's Pendant",
			"file": "riders_pendant",
			"primary": C.AGILITY_BONUS,
			"secondary": C.HEALTH_BONUS,
			"desc": "A feather-shaped charm worn by the griffin corps. Said to bring luck in the air. At minimum, it brings a sense of belonging.",
			"flavor": "Griffin riders are superstitious. This is the most tasteful expression of that.",
		},
		{
			"name": "Arcane Pendant",
			"file": "arcane_pendant",
			"primary": C.INTELLECT_BONUS,
			"secondary": C.MANA_BONUS,
			"desc": "A pendant of interlocking geometric shapes that glow faintly. Used as both a focus and a conversation starter at academic functions.",
			"flavor": "At the last faculty dinner, three pendants in close proximity set off the fire ward. Twice.",
		},
	]

	# FIX: Type loop var — Dictionary array yields Variant
	for a: Dictionary in accessories:
		var item := _create_base_item(a.name, ES.ACCESSORY)
		item.description = a.desc
		item.flavor_text = a.flavor
		var affixes: Array[Affix] = []
		affixes.append(_make_stat_affix(a.primary))
		affixes.append(_make_stat_affix(a.secondary))
		# FIX: .assign() for @export typed array
		item.base_stat_affixes.assign(affixes)
		item.base_value = 12
		_save_item(item, "accessory", a.file)

# ============================================================================
# ARMOR NAMING
# ============================================================================

func _armor_name(slot_label: String, stat_key: String, defense_type: String) -> Dictionary:
	# Name pieces per stat archetype
	var prefix_map := {
		"str": {
			"armor":   { "prefix": "Iron",   "style": "heavy" },
			"barrier": { "prefix": "Runed Iron", "style": "enchanted_heavy" },
			"hybrid":  { "prefix": "Marine",  "style": "military" },
		},
		"agi": {
			"armor":   { "prefix": "Leather", "style": "light" },
			"barrier": { "prefix": "Warded Leather", "style": "enchanted_light" },
			"hybrid":  { "prefix": "Scout's", "style": "military_light" },
		},
		"int": {
			"armor":   { "prefix": "Plated",  "style": "reinforced_cloth" },
			"barrier": { "prefix": "Arcane",   "style": "magical" },
			"hybrid":  { "prefix": "Scholar's", "style": "academic" },
		},
	}

	# Slot-specific nouns
	var slot_nouns := {
		"Head":   { "heavy": "Helm",   "light": "Cap",    "cloth": "Circlet",
					"enchanted_heavy": "Helm", "enchanted_light": "Cap",
					"military": "Helm", "military_light": "Half-Helm",
					"reinforced_cloth": "Circlet", "magical": "Circlet", "academic": "Circlet" },
		"Torso":  { "heavy": "Cuirass", "light": "Jerkin",  "cloth": "Robe",
					"enchanted_heavy": "Cuirass", "enchanted_light": "Jerkin",
					"military": "Cuirass", "military_light": "Jerkin",
					"reinforced_cloth": "Robe", "magical": "Robe", "academic": "Robe" },
		"Gloves": { "heavy": "Gauntlets", "light": "Gloves", "cloth": "Wraps",
					"enchanted_heavy": "Gauntlets", "enchanted_light": "Gloves",
					"military": "Gauntlets", "military_light": "Gloves",
					"reinforced_cloth": "Wraps", "magical": "Wraps", "academic": "Wraps" },
		"Boots":  { "heavy": "Boots",  "light": "Boots",   "cloth": "Shoes",
					"enchanted_heavy": "Boots", "enchanted_light": "Boots",
					"military": "Boots", "military_light": "Boots",
					"reinforced_cloth": "Shoes", "magical": "Shoes", "academic": "Shoes" },
	}

	var info: Dictionary = prefix_map[stat_key][defense_type]
	var noun: String = slot_nouns[slot_label][info.style]
	var full_name: String = info.prefix + " " + noun

	# Descriptions and flavor text
	var desc: String = _armor_desc(stat_key, defense_type, slot_label)
	var flavor: String = _armor_flavor(stat_key, defense_type, slot_label)

	return { "name": full_name, "desc": desc, "flavor": flavor }


func _armor_desc(stat: String, defense: String, slot: String) -> String:
	var descs := {
		"str_armor": "Solid iron construction, built to absorb punishment. Standard issue for Sanctum's front-line infantry.",
		"str_barrier": "Iron plate inscribed with protective runes. The enchantment work isn't cheap, but neither is replacing soldiers.",
		"str_hybrid": "Regulation naval armor balancing physical and magical protection. Designed by committee, which explains the color.",
		"agi_armor": "Hardened leather shaped for mobility. Griffin riders and scouts swear by it, though they disagree on the proper way to lace it.",
		"agi_barrier": "Light leather infused with defensive wards. Moves like cloth, protects like it has opinions about your survival.",
		"agi_hybrid": "Scout-issue gear combining leather and light enchantment. Keeps you alive and fast, in that order.",
		"int_armor": "Cloth reinforced with thin metal plates. The Academy compromise between 'protected' and 'able to cast without clanking.'",
		"int_barrier": "Pure arcane weave that hums with protective energy. The preferred attire of those who consider armor gauche.",
		"int_hybrid": "Academic-issue gear balancing mundane and magical defense. Required reading not included.",
	}
	var key: String = stat + "_" + defense
	var base: String = descs.get(key, "Equipment of uncertain provenance.")

	# Slot-specific additions
	match slot:
		"Head": return base.replace("construction", "headgear").replace("armor", "headgear").replace("gear", "headgear").replace("leather", "headgear") if false else base
		_: return base


func _armor_flavor(stat: String, defense: String, slot: String) -> String:
	# Each combo gets unique flavor text
	var flavors := {
		"str_armor_Head": "The dent in the front is either battle damage or quality control. Nobody's sure.",
		"str_barrier_Head": "The runes glow when struck. The wearer glows with satisfaction.",
		"str_hybrid_Head": "Regulation 4.2.1: All marine helms must be polished on Tuesdays. Compliance is... variable.",
		"agi_armor_Head": "Shaped to not interfere with griffin riding. Or with hearing sergeants yell. Mostly the griffin thing.",
		"agi_barrier_Head": "The ward activates faster than your reflexes. Which says more about the ward than your reflexes.",
		"agi_hybrid_Head": "Scouting Division motto: 'We saw it first.' The half-helm helps with the seeing part.",
		"int_armor_Head": "Metal plates arranged to not interfere with thinking. The Academy tested this. At length.",
		"int_barrier_Head": "Hums gently during deep concentration. Hums aggressively during exams.",
		"int_hybrid_Head": "Scholars who venture into the field wear these. 'The field' being anywhere outside the library.",

		"str_armor_Torso": "They make them tough in Sanctum. The cuirass, that is. Also the people.",
		"str_barrier_Torso": "The enchantment was added after the third repair. Prevention is cheaper than metalwork.",
		"str_hybrid_Torso": "Standard naval issue. The anchor stamped on the chest is mandatory. The pride is optional but common.",
		"agi_armor_Torso": "Tanned with a proprietary process the leatherworkers refuse to discuss. It smells fine. Mostly.",
		"agi_barrier_Torso": "The wards are stitched into the lining. Invisible protection for those who prefer to be invisible.",
		"agi_hybrid_Torso": "Scout Quartermaster note: 'Serviceable. Not fashionable. Scouts have complained. Scouts always complain.'",
		"int_armor_Torso": "The metal plates are arranged in a pattern that is technically a spell diagram. Technically.",
		"int_barrier_Torso": "The robe's protective aura gently discourages physical contact. Very popular at faculty meetings.",
		"int_hybrid_Torso": "Academy dress code, Section 3: 'Robes must be functional AND dignified.' This achieves one of those.",

		"str_armor_Gloves": "The knuckles are reinforced. For protection. Definitely just for protection.",
		"str_barrier_Gloves": "The runes across the fingers make punching things produce a satisfying shimmer.",
		"str_hybrid_Gloves": "Marine issue. Grip-tested for climbing, fighting, and holding onto things in rough seas.",
		"agi_armor_Gloves": "Thin enough to pick a lock. Nobody said that. These are for legitimate scouting purposes.",
		"agi_barrier_Gloves": "The ward makes your fingers tingle. Riders say it improves their grip. The tingling does not improve their grip.",
		"agi_hybrid_Gloves": "Scout-issue gloves. Good for climbing, signaling, and rude gestures at safe distances.",
		"int_armor_Gloves": "Plated finger guards that somehow don't interfere with somatic components. The Academy is still publishing papers on why.",
		"int_barrier_Gloves": "Arcane wraps that channel ambient magical energy. Also keep your wrists warm.",
		"int_hybrid_Gloves": "Required for laboratory work. The stains are from alchemy. Probably.",

		"str_armor_Boots": "Heavy, loud, and built to kick doors. The infantry's favorite multitool.",
		"str_barrier_Boots": "The runes help you stand firm against magical force. And regular force. And sergeants.",
		"str_hybrid_Boots": "Marine boots: waterproof, magicproof, and proof that someone in logistics has taste.",
		"agi_armor_Boots": "Soft-soled for stealth. Hard-toed for when stealth fails.",
		"agi_barrier_Boots": "The ward cushions falls from moderate heights. 'Moderate' being the operative word.",
		"agi_hybrid_Boots": "Scout-issue boots. The sole pattern is classified, which seems excessive for footwear.",
		"int_armor_Boots": "Reinforced enough for fieldwork. Comfortable enough for lectures. Good at neither, adequate at both.",
		"int_barrier_Boots": "They say mages draw power from the earth. These help with the signal reception.",
		"int_hybrid_Boots": "Academy standard. The enchantment keeps them clean, which is the real magic.",
	}

	var key: String = stat + "_" + defense + "_" + slot
	return flavors.get(key, "Sanctum makes them sturdy, if not stylish.")

# ============================================================================
# RESOURCE CREATION HELPERS
# ============================================================================

func _create_base_item(item_name: String, slot: EquippableItem.EquipSlot) -> EquippableItem:
	var item := EquippableItem.new()
	item.item_name = item_name
	item.rarity = EquippableItem.Rarity.UNCOMMON  # Minimum drop tier; overridden at drop time
	item.equip_slot = slot
	item.item_level = 1
	item.region = 1
	item.base_value = 10
	item.grants_action = false
	return item


func _make_stat_affix(category: int) -> Affix:
	var affix := Affix.new()
	match category:
		C.STRENGTH_BONUS:
			affix.affix_name = "Inherent Strength"
			affix.description = "+{value} Strength"
			affix.category = C.STRENGTH_BONUS
			affix.tags = PackedStringArray(["stat", "inherent", "physical"])
			affix.effect_min = 1.0
			affix.effect_max = 50.0
		C.AGILITY_BONUS:
			affix.affix_name = "Inherent Agility"
			affix.description = "+{value} Agility"
			affix.category = C.AGILITY_BONUS
			affix.tags = PackedStringArray(["stat", "inherent", "physical"])
			affix.effect_min = 1.0
			affix.effect_max = 50.0
		C.INTELLECT_BONUS:
			affix.affix_name = "Inherent Intellect"
			affix.description = "+{value} Intellect"
			affix.category = C.INTELLECT_BONUS
			affix.tags = PackedStringArray(["stat", "inherent", "magical"])
			affix.effect_min = 1.0
			affix.effect_max = 50.0
		C.HEALTH_BONUS:
			affix.affix_name = "Inherent Health"
			affix.description = "+{value} Health"
			affix.category = C.HEALTH_BONUS
			affix.tags = PackedStringArray(["defense", "inherent", "health"])
			affix.effect_min = 5.0
			affix.effect_max = 250.0
		C.MANA_BONUS:
			affix.affix_name = "Inherent Mana"
			affix.description = "+{value} Mana"
			affix.category = C.MANA_BONUS
			affix.tags = PackedStringArray(["mana", "inherent"])
			affix.effect_min = 3.0
			affix.effect_max = 80.0
		C.DAMAGE_BONUS:
			affix.affix_name = "Inherent Damage"
			affix.description = "+{value} Damage"
			affix.category = C.DAMAGE_BONUS
			affix.tags = PackedStringArray(["damage", "inherent"])
			affix.effect_min = 1.0
			affix.effect_max = 30.0
		C.DEFENSE_BONUS:
			affix.affix_name = "Inherent Defense"
			affix.description = "+{value} Defense"
			affix.category = C.DEFENSE_BONUS
			affix.tags = PackedStringArray(["defense", "inherent"])
			affix.effect_min = 1.0
			affix.effect_max = 50.0
		C.ARMOR_BONUS:
			affix.affix_name = "Inherent Armor"
			affix.description = "+{value} Armor"
			affix.category = C.ARMOR_BONUS
			affix.tags = PackedStringArray(["defense", "inherent", "armor"])
			affix.effect_min = 2.0
			affix.effect_max = 60.0
		C.BARRIER_BONUS:
			affix.affix_name = "Inherent Barrier"
			affix.description = "+{value} Barrier"
			affix.category = C.BARRIER_BONUS
			affix.tags = PackedStringArray(["defense", "inherent", "barrier"])
			affix.effect_min = 3.0
			affix.effect_max = 120.0
	affix.show_in_summary = true
	affix.show_in_active_list = true
	affix.source = "item_base"
	affix.source_type = "item_base"
	return affix


func _make_defense_affix(defense_type: String) -> Affix:
	match defense_type:
		"armor":
			return _make_stat_affix(C.ARMOR_BONUS)
		"barrier":
			return _make_stat_affix(C.BARRIER_BONUS)
	return null


func _make_half_armor_affix() -> Affix:
	var affix := Affix.new()
	affix.affix_name = "Inherent Armor (Hybrid)"
	affix.description = "+{value} Armor"
	affix.category = C.ARMOR_BONUS
	affix.tags = PackedStringArray(["defense", "inherent", "armor", "hybrid"])
	affix.effect_min = 1.0
	affix.effect_max = 30.0  # Half of pure armor's 60
	affix.show_in_summary = true
	affix.show_in_active_list = true
	affix.source = "item_base"
	affix.source_type = "item_base"
	return affix


func _make_half_barrier_affix() -> Affix:
	var affix := Affix.new()
	affix.affix_name = "Inherent Barrier (Hybrid)"
	affix.description = "+{value} Barrier"
	affix.category = C.BARRIER_BONUS
	affix.tags = PackedStringArray(["defense", "inherent", "barrier", "hybrid"])
	affix.effect_min = 1.5
	affix.effect_max = 60.0  # Half of pure barrier's 120
	affix.show_in_summary = true
	affix.show_in_active_list = true
	affix.source = "item_base"
	affix.source_type = "item_base"
	return affix


func _make_die(die_type: DieResource.DieType, element: DieResource.Element, source_name: String) -> DieResource:
	var die := DieResource.new()
	die.die_type = die_type
	die.element = element
	die.display_name = "D%d" % die_type
	die.source = source_name

	# Try to load existing element affix
	var elem_path: String = _element_affix_path(element)
	if elem_path != "" and ResourceLoader.exists(elem_path):
		die.element_affix = load(elem_path)

	# Try to load base textures for this die size
	var size_str: String = str(die_type)
	var fill_path: String = "res://assets/dice/D%ss/d%s-basic-fill.png" % [size_str, size_str.to_lower()]
	var stroke_path: String = "res://assets/dice/D%ss/d%s-basic-stroke.png" % [size_str, size_str.to_lower()]
	if ResourceLoader.exists(fill_path):
		die.fill_texture = load(fill_path)
	if ResourceLoader.exists(stroke_path):
		die.stroke_texture = load(stroke_path)

	return die


func _make_dice_array(die_type: DieResource.DieType, element: DieResource.Element, source: String) -> Array[DieResource]:
	var arr: Array[DieResource] = []
	arr.append(_make_die(die_type, element, source))
	return arr


func _element_affix_path(element: DieResource.Element) -> String:
	match element:
		EL.SLASHING: return "res://resources/affixes/elements/slashing_element.tres"
		EL.BLUNT:    return "res://resources/affixes/elements/blunt_element.tres"
		EL.PIERCING: return "res://resources/affixes/elements/piercing_element.tres"
		EL.FIRE:     return "res://resources/affixes/elements/fire_element.tres"
		EL.ICE:      return "res://resources/affixes/elements/ice_element.tres"
		EL.SHOCK:    return "res://resources/affixes/elements/shock_element.tres"
		EL.POISON:   return "res://resources/affixes/elements/poison_element.tres"
		EL.SHADOW:   return "res://resources/affixes/elements/shadow_element.tres"
	return ""

# ============================================================================
# NAMING HELPERS
# ============================================================================

func _stat_key(category: int) -> String:
	match category:
		C.STRENGTH_BONUS: return "str"
		C.AGILITY_BONUS:  return "agi"
		C.INTELLECT_BONUS: return "int"
	return "str"


func _defense_name_suffix(defense_type: String) -> String:
	match defense_type:
		"armor":   return ""
		"barrier": return "Warded"
		"hybrid":  return "Reinforced"
	return ""


func _sanitize(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace("'", "").replace("-", "_")

# ============================================================================
# SAVE
# ============================================================================

func _save_item(item: EquippableItem, folder: String, file_name: String):
	var path: String = "%s/%s/%s.tres" % [BASE_DIR, folder, file_name]
	var err := ResourceSaver.save(item, path)
	if err == OK:
		_count += 1
		print("  ✅ %s → %s" % [item.item_name, path])
	else:
		push_error("  ❌ Failed to save %s: %s" % [path, error_string(err)])
