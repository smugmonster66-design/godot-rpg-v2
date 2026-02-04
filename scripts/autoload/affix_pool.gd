# affix_pool.gd - Automatically loads affixes organized by slot and tier
extends Node

# Three-tier affix pools per slot
# First tier: Common/basic affixes (always available)
# Second tier: Uncommon/better affixes
# Third tier: Rare/powerful affixes

# HEAD AFFIXES
var head_affixes_first: Array[Affix] = []
var head_affixes_second: Array[Affix] = []
var head_affixes_third: Array[Affix] = []

# TORSO AFFIXES
var torso_affixes_first: Array[Affix] = []
var torso_affixes_second: Array[Affix] = []
var torso_affixes_third: Array[Affix] = []

# GLOVES AFFIXES
var gloves_affixes_first: Array[Affix] = []
var gloves_affixes_second: Array[Affix] = []
var gloves_affixes_third: Array[Affix] = []

# BOOTS AFFIXES
var boots_affixes_first: Array[Affix] = []
var boots_affixes_second: Array[Affix] = []
var boots_affixes_third: Array[Affix] = []

# WEAPON AFFIXES
var weapon_affixes_first: Array[Affix] = []
var weapon_affixes_second: Array[Affix] = []
var weapon_affixes_third: Array[Affix] = []

# ACCESSORY AFFIXES
var accessory_affixes_first: Array[Affix] = []
var accessory_affixes_second: Array[Affix] = []
var accessory_affixes_third: Array[Affix] = []

# Master lookup - all affixes by name for dynamic access
var affixes_by_name: Dictionary = {}

func _ready():
	print("✨ Affix Pool initializing...")
	_load_all_affixes()
	print("✨ Affix Pool ready - loaded %d total affixes" % affixes_by_name.size())

func _load_all_affixes():
	"""Load affixes from three-tier directory structure"""
	# Head
	_load_affixes_from_directory("res://resources/affixes/head/first/", head_affixes_first, "Head-First")
	_load_affixes_from_directory("res://resources/affixes/head/second/", head_affixes_second, "Head-Second")
	_load_affixes_from_directory("res://resources/affixes/head/third/", head_affixes_third, "Head-Third")
	
	# Torso
	_load_affixes_from_directory("res://resources/affixes/torso/first/", torso_affixes_first, "Torso-First")
	_load_affixes_from_directory("res://resources/affixes/torso/second/", torso_affixes_second, "Torso-Second")
	_load_affixes_from_directory("res://resources/affixes/torso/third/", torso_affixes_third, "Torso-Third")
	
	# Gloves
	_load_affixes_from_directory("res://resources/affixes/gloves/first/", gloves_affixes_first, "Gloves-First")
	_load_affixes_from_directory("res://resources/affixes/gloves/second/", gloves_affixes_second, "Gloves-Second")
	_load_affixes_from_directory("res://resources/affixes/gloves/third/", gloves_affixes_third, "Gloves-Third")
	
	# Boots
	_load_affixes_from_directory("res://resources/affixes/boots/first/", boots_affixes_first, "Boots-First")
	_load_affixes_from_directory("res://resources/affixes/boots/second/", boots_affixes_second, "Boots-Second")
	_load_affixes_from_directory("res://resources/affixes/boots/third/", boots_affixes_third, "Boots-Third")
	
	# Weapons
	_load_affixes_from_directory("res://resources/affixes/weapons/first/", weapon_affixes_first, "Weapons-First")
	_load_affixes_from_directory("res://resources/affixes/weapons/second/", weapon_affixes_second, "Weapons-Second")
	_load_affixes_from_directory("res://resources/affixes/weapons/third/", weapon_affixes_third, "Weapons-Third")
	
	# Accessories
	_load_affixes_from_directory("res://resources/affixes/accessories/first/", accessory_affixes_first, "Accessories-First")
	_load_affixes_from_directory("res://resources/affixes/accessories/second/", accessory_affixes_second, "Accessories-Second")
	_load_affixes_from_directory("res://resources/affixes/accessories/third/", accessory_affixes_third, "Accessories-Third")

func _load_affixes_from_directory(dir_path: String, target_array: Array[Affix], category_name: String):
	"""Load all .tres affix files from a directory"""
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		# Silently skip missing directories (not all tiers may exist yet)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = dir_path + file_name
			var affix = load(full_path)
			
			if affix and affix is Affix:
				target_array.append(affix)
				affixes_by_name[affix.affix_name] = affix
				loaded_count += 1
				print("    ✓ %s: %s" % [category_name, affix.affix_name])
			else:
				print("    ✗ Failed to load: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		print("  📦 %s: %d affixes" % [category_name, loaded_count])

# ============================================================================
# QUERY FUNCTIONS - THREE POOLS PER SLOT
# ============================================================================

func get_affix_pool(slot: EquippableItem.EquipSlot, tier: int) -> Array[Affix]:
	"""Get affix pool for a specific slot and tier
	
	Args:
		slot: Equipment slot enum
		tier: 1 = First, 2 = Second, 3 = Third
	
	Returns:
		Array of affixes for that slot/tier combination
	"""
	match slot:
		EquippableItem.EquipSlot.HEAD:
			match tier:
				1: return head_affixes_first
				2: return head_affixes_second
				3: return head_affixes_third
		
		EquippableItem.EquipSlot.TORSO:
			match tier:
				1: return torso_affixes_first
				2: return torso_affixes_second
				3: return torso_affixes_third
		
		EquippableItem.EquipSlot.GLOVES:
			match tier:
				1: return gloves_affixes_first
				2: return gloves_affixes_second
				3: return gloves_affixes_third
		
		EquippableItem.EquipSlot.BOOTS:
			match tier:
				1: return boots_affixes_first
				2: return boots_affixes_second
				3: return boots_affixes_third
		
		EquippableItem.EquipSlot.MAIN_HAND, EquippableItem.EquipSlot.OFF_HAND, EquippableItem.EquipSlot.HEAVY:
			match tier:
				1: return weapon_affixes_first
				2: return weapon_affixes_second
				3: return weapon_affixes_third
		
		EquippableItem.EquipSlot.ACCESSORY:
			match tier:
				1: return accessory_affixes_first
				2: return accessory_affixes_second
				3: return accessory_affixes_third
	
	return []

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

func get_affixes_for_slot(slot: EquippableItem.EquipSlot) -> Array[Affix]:
	"""Get ALL affixes for a slot (combines all three tiers)
	
	For backward compatibility with existing code
	"""
	var all_affixes: Array[Affix] = []
	all_affixes.append_array(get_affix_pool(slot, 1))
	all_affixes.append_array(get_affix_pool(slot, 2))
	all_affixes.append_array(get_affix_pool(slot, 3))
	return all_affixes

# ============================================================================
# DYNAMIC ACCESS
# ============================================================================

func get_affix_by_name(affix_name: String) -> Affix:
	"""Get a specific affix by name"""
	return affixes_by_name.get(affix_name, null)

func has_affix(affix_name: String) -> bool:
	"""Check if an affix exists"""
	return affixes_by_name.has(affix_name)

func get_all_affixes() -> Array[Affix]:
	"""Get all loaded affixes"""
	var result: Array[Affix] = []
	for affix in affixes_by_name.values():
		result.append(affix)
	return result
