# res://editor_scripts/generate_base_affix_system.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   1. Creates ~130 base Affix .tres files in resources/affixes/base/
#      with full-game effect_min/effect_max ranges (Option A wide scaling)
#   2. Creates 9 AffixTable .tres files in resources/affix_tables/base/
#      (offense/defense/utility × tier 1/2/3)
#   3. Creates the AffixScalingConfig .tres with a linear curve
#   4. Prints a summary of what was created
#
# SAFE TO RE-RUN: Existing files are updated, not duplicated.
# Affixes with manually-set granted_dice or granted_action are preserved.
#
@tool
extends EditorScript

# ============================================================================
# CONFIGURATION
# ============================================================================

const AFFIX_BASE_DIR := "res://resources/affixes/base/"
const TABLE_BASE_DIR := "res://resources/affix_tables/base/"
const SCALING_DIR := "res://resources/scaling/"

# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	print("\n" + "═".repeat(60))
	print("  GENERATING BASE AFFIX SYSTEM")
	print("═".repeat(60))
	
	# Ensure directories exist
	_ensure_dirs()
	
	# Get full affix catalog
	var catalog := _build_catalog()
	print("\n📦 Catalog contains %d affix definitions" % catalog.size())
	
	# Create/update affix .tres files
	var affixes_by_key: Dictionary = {}  # "family/tier/filename" → Affix resource
	var created := 0
	var updated := 0
	
	for entry in catalog:
		var result = _create_or_update_affix(entry)
		if result.resource:
			var key := "%s_%d" % [entry.family, entry.tier]
			if not affixes_by_key.has(key):
				affixes_by_key[key] = []
			affixes_by_key[key].append(result.resource)
			
			if result.was_created:
				created += 1
			else:
				updated += 1
	
	print("\n✅ Affixes: %d created, %d updated" % [created, updated])
	
	# Create the 9 AffixTables
	var tables_created := 0
	for family in ["offense", "defense", "utility"]:
		for tier in [1, 2, 3]:
			var key := "%s_%d" % [family, tier]
			var affix_list: Array = affixes_by_key.get(key, [])
			if _create_affix_table(family, tier, affix_list):
				tables_created += 1
	
	print("✅ Tables: %d created" % tables_created)
	
	# Create scaling config
	_create_scaling_config()
	
	# Summary
	print("\n" + "═".repeat(60))
	print("  GENERATION COMPLETE")
	print("═".repeat(60))
	print("  Affix .tres files: %s" % AFFIX_BASE_DIR)
	print("  Table .tres files: %s" % TABLE_BASE_DIR)
	print("  Scaling config:    %s" % (SCALING_DIR + "affix_scaling_config.tres"))
	print("═".repeat(60) + "\n")
	
	# Force reimport
	EditorInterface.get_resource_filesystem().scan()

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

func _ensure_dirs() -> void:
	for family in ["offense", "defense", "utility"]:
		for tier in [1, 2, 3]:
			var dir_path := "%s%s/tier_%d/" % [AFFIX_BASE_DIR, family, tier]
			DirAccess.make_dir_recursive_absolute(dir_path)
	DirAccess.make_dir_recursive_absolute(TABLE_BASE_DIR)
	DirAccess.make_dir_recursive_absolute(SCALING_DIR)

# ============================================================================
# AFFIX CREATION
# ============================================================================

func _create_or_update_affix(entry: Dictionary) -> Dictionary:
	var family: String = entry.family
	var tier: int = entry.tier
	var file_name: String = entry.file_name
	var path := "%s%s/tier_%d/%s.tres" % [AFFIX_BASE_DIR, family, tier, file_name]
	
	var affix: Affix = null
	var was_created := false
	
	if ResourceLoader.exists(path):
		affix = load(path)
	
	if affix == null:
		affix = Affix.new()
		was_created = true
	
	# Set/update core properties
	affix.affix_name = entry.affix_name
	affix.description = entry.description
	affix.category = entry.category
	
	# Set scaling range (the key addition)
	affix.effect_min = entry.get("effect_min", 0.0)
	affix.effect_max = entry.get("effect_max", 0.0)
	
	# Static fallback for non-scaling affixes
	if entry.has("effect_number"):
		affix.effect_number = entry.effect_number
	
	# Proc configuration
	if entry.has("proc_trigger"):
		affix.proc_trigger = entry.proc_trigger
	if entry.has("proc_chance_min"):
		# For procs, we scale proc_chance via effect_min/max
		# effect_number gets rolled between these at item creation
		affix.effect_min = entry.proc_chance_min
		affix.effect_max = entry.proc_chance_max
	if entry.has("effect_data") and affix.effect_data.is_empty():
		affix.effect_data = entry.effect_data
	
	# Tags
	if entry.has("tags"):
		affix.tags = entry.tags
	
	# Save
	var err := ResourceSaver.save(affix, path)
	if err != OK:
		push_error("Failed to save affix: %s (error %d)" % [path, err])
		return {"resource": null, "was_created": false}
	
	return {"resource": affix, "was_created": was_created}

# ============================================================================
# TABLE CREATION
# ============================================================================

func _create_affix_table(family: String, tier: int, affixes: Array) -> bool:
	var path := "%s%s_tier_%d.tres" % [TABLE_BASE_DIR, family, tier]
	
	var table: AffixTable = null
	if ResourceLoader.exists(path):
		table = load(path)
	if table == null:
		table = AffixTable.new()
	
	table.table_name = "%s Tier %d" % [family.capitalize(), tier]
	table.description = "Base %s affixes, tier %d. Auto-generated." % [family, tier]
	
	# Build typed array
	var typed_affixes: Array[Affix] = []
	for a in affixes:
		if a is Affix:
			typed_affixes.append(a)
	table.available_affixes = typed_affixes
	
	var err := ResourceSaver.save(table, path)
	if err != OK:
		push_error("Failed to save table: %s" % path)
		return false
	
	print("  📋 %s: %d affixes" % [table.table_name, typed_affixes.size()])
	return true

# ============================================================================
# SCALING CONFIG CREATION
# ============================================================================

func _create_scaling_config() -> void:
	var path := SCALING_DIR + "affix_scaling_config.tres"
	
	var config: AffixScalingConfig = null
	if ResourceLoader.exists(path):
		config = load(path)
		print("📈 Scaling config already exists — preserving")
		return
	
	config = AffixScalingConfig.new()
	
	# Create a linear curve (simplest starting point)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	config.global_scaling_curve = curve
	
	config.max_item_level = 100
	config.default_fuzz_percent = 0.2
	config.min_absolute_fuzz = 1.0
	
	# Region bounds (overlapping for smooth transitions)
	config.region_1_min_level = 1
	config.region_1_max_level = 18
	config.region_2_min_level = 15
	config.region_2_max_level = 35
	config.region_3_min_level = 30
	config.region_3_max_level = 52
	config.region_4_min_level = 48
	config.region_4_max_level = 68
	config.region_5_min_level = 65
	config.region_5_max_level = 85
	config.region_6_min_level = 80
	config.region_6_max_level = 100
	
	var err := ResourceSaver.save(config, path)
	if err == OK:
		print("📈 Created scaling config with linear curve")
	else:
		push_error("Failed to save scaling config: %d" % err)

# ============================================================================
# AFFIX CATALOG — All 151 archetypes with full-game ranges
# ============================================================================
#
# Range philosophy (Option A — wide ranges, item_level does the work):
#   Flat stats:      1–50    (Str/Agi/Int/Luck)
#   Flat damage:     1–30    (typed and global)
#   Armor/Defense:   2–80 / 1–60
#   Resists:         2–40
#   Health:          5–250
#   Barrier:         3–120
#   Mana:            3–80
#   Multipliers:     1.02–1.50 (stat), 1.05–1.60 (damage/defense)
#   Proc flat:       1–30    (heal/damage/armor/barrier gains)
#   Proc %:          0.03–0.25 (lifesteal, % heal, % damage)
#   Proc chance:     0.10–0.50 (status application probability)
#   Stacking buffs:  1–10    (per-stack value)
#   Dice/Actions:    no scaling (0/0)
#

func _build_catalog() -> Array:
	var C := Affix.Category
	var P := Affix.ProcTrigger
	var catalog: Array = []
	
	# ── OFFENSE TIER 1 (8 affixes) ──────────────────────────────────────
	
	catalog.append({
		"id": 1, "file_name": "strength_bonus",
		"affix_name": "Strength Bonus", "description": "+N Strength",
		"family": "offense", "tier": 1, "category": C.STRENGTH_BONUS,
		"effect_min": 1.0, "effect_max": 50.0,
		"tags": ["stat", "physical"]
	})
	catalog.append({
		"id": 2, "file_name": "agility_bonus",
		"affix_name": "Agility Bonus", "description": "+N Agility",
		"family": "offense", "tier": 1, "category": C.AGILITY_BONUS,
		"effect_min": 1.0, "effect_max": 50.0,
		"tags": ["stat", "physical"]
	})
	catalog.append({
		"id": 3, "file_name": "intellect_bonus",
		"affix_name": "Intellect Bonus", "description": "+N Intellect",
		"family": "offense", "tier": 1, "category": C.INTELLECT_BONUS,
		"effect_min": 1.0, "effect_max": 50.0,
		"tags": ["stat", "magical"]
	})
	catalog.append({
		"id": 4, "file_name": "luck_bonus",
		"affix_name": "Luck Bonus", "description": "+N Luck",
		"family": "offense", "tier": 1, "category": C.LUCK_BONUS,
		"effect_min": 1.0, "effect_max": 50.0,
		"tags": ["stat"]
	})
	catalog.append({
		"id": 9, "file_name": "global_damage_bonus",
		"affix_name": "Global Damage Bonus", "description": "+N damage to all attacks",
		"family": "offense", "tier": 1, "category": C.DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage"]
	})
	catalog.append({
		"id": 11, "file_name": "slashing_damage_bonus",
		"affix_name": "Slashing Damage Bonus", "description": "+N Slashing damage",
		"family": "offense", "tier": 1, "category": C.SLASHING_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 25.0,
		"tags": ["damage", "physical", "slashing"]
	})
	catalog.append({
		"id": 12, "file_name": "blunt_damage_bonus",
		"affix_name": "Blunt Damage Bonus", "description": "+N Blunt damage",
		"family": "offense", "tier": 1, "category": C.BLUNT_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 25.0,
		"tags": ["damage", "physical", "blunt"]
	})
	catalog.append({
		"id": 13, "file_name": "piercing_damage_bonus",
		"affix_name": "Piercing Damage Bonus", "description": "+N Piercing damage",
		"family": "offense", "tier": 1, "category": C.PIERCING_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 25.0,
		"tags": ["damage", "physical", "piercing"]
	})
	
	# ── OFFENSE TIER 2 (17 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 5, "file_name": "strength_multiplier",
		"affix_name": "Strength Multiplier", "description": "×N Strength",
		"family": "offense", "tier": 2, "category": C.STRENGTH_MULTIPLIER,
		"effect_min": 1.02, "effect_max": 1.50,
		"tags": ["stat", "multiplier", "physical"]
	})
	catalog.append({
		"id": 6, "file_name": "agility_multiplier",
		"affix_name": "Agility Multiplier", "description": "×N Agility",
		"family": "offense", "tier": 2, "category": C.AGILITY_MULTIPLIER,
		"effect_min": 1.02, "effect_max": 1.50,
		"tags": ["stat", "multiplier", "physical"]
	})
	catalog.append({
		"id": 7, "file_name": "intellect_multiplier",
		"affix_name": "Intellect Multiplier", "description": "×N Intellect",
		"family": "offense", "tier": 2, "category": C.INTELLECT_MULTIPLIER,
		"effect_min": 1.02, "effect_max": 1.50,
		"tags": ["stat", "multiplier", "magical"]
	})
	catalog.append({
		"id": 8, "file_name": "luck_multiplier",
		"affix_name": "Luck Multiplier", "description": "×N Luck",
		"family": "offense", "tier": 2, "category": C.LUCK_MULTIPLIER,
		"effect_min": 1.02, "effect_max": 1.50,
		"tags": ["stat", "multiplier"]
	})
	catalog.append({
		"id": 14, "file_name": "fire_damage_bonus",
		"affix_name": "Fire Damage Bonus", "description": "+N Fire damage",
		"family": "offense", "tier": 2, "category": C.FIRE_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage", "elemental", "fire"]
	})
	catalog.append({
		"id": 15, "file_name": "ice_damage_bonus",
		"affix_name": "Ice Damage Bonus", "description": "+N Ice damage",
		"family": "offense", "tier": 2, "category": C.ICE_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage", "elemental", "ice"]
	})
	catalog.append({
		"id": 16, "file_name": "shock_damage_bonus",
		"affix_name": "Shock Damage Bonus", "description": "+N Shock damage",
		"family": "offense", "tier": 2, "category": C.SHOCK_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage", "elemental", "shock"]
	})
	catalog.append({
		"id": 17, "file_name": "poison_damage_bonus",
		"affix_name": "Poison Damage Bonus", "description": "+N Poison damage",
		"family": "offense", "tier": 2, "category": C.POISON_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage", "elemental", "poison"]
	})
	catalog.append({
		"id": 18, "file_name": "shadow_damage_bonus",
		"affix_name": "Shadow Damage Bonus", "description": "+N Shadow damage",
		"family": "offense", "tier": 2, "category": C.SHADOW_DAMAGE_BONUS,
		"effect_min": 1.0, "effect_max": 30.0,
		"tags": ["damage", "elemental", "shadow"]
	})
	catalog.append({
		"id": 20, "file_name": "bonus_flat_damage_on_hit",
		"affix_name": "Bonus Flat Damage on Hit", "description": "+N bonus damage on each hit",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"effect_min": 1.0, "effect_max": 25.0,
		"effect_data": {"effect": "bonus_damage_flat"},
		"tags": ["proc", "damage", "on_hit"]
	})
	catalog.append({
		"id": 24, "file_name": "apply_poison_on_hit",
		"affix_name": "Apply Poison on Hit", "description": "N% chance to Poison on hit",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.10, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "poison"},
		"tags": ["proc", "status", "poison", "on_hit"]
	})
	catalog.append({
		"id": 25, "file_name": "apply_burn_on_hit",
		"affix_name": "Apply Burn on Hit", "description": "N% chance to Burn on hit",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.10, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "burn"},
		"tags": ["proc", "status", "fire", "on_hit"]
	})
	catalog.append({
		"id": 26, "file_name": "apply_bleed_on_hit",
		"affix_name": "Apply Bleed on Hit", "description": "N% chance to Bleed on hit",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.10, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "bleed"},
		"tags": ["proc", "status", "physical", "on_hit"]
	})
	catalog.append({
		"id": 28, "file_name": "apply_chill_on_hit",
		"affix_name": "Apply Chill on Hit", "description": "N% chance to Chill on hit",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.10, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "chill"},
		"tags": ["proc", "status", "ice", "on_hit"]
	})
	catalog.append({
		"id": 33, "file_name": "bonus_damage_per_die_used",
		"affix_name": "Bonus Damage per Die Used", "description": "+N damage each time a die is consumed",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DIE_USED,
		"effect_min": 1.0, "effect_max": 15.0,
		"effect_data": {"effect": "bonus_damage_flat"},
		"tags": ["proc", "damage", "dice"]
	})
	catalog.append({
		"id": 36, "file_name": "bonus_damage_per_action",
		"affix_name": "Bonus Damage per Action", "description": "+N damage per action executed",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_ACTION_USED,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "bonus_damage_flat"},
		"tags": ["proc", "damage"]
	})
	catalog.append({
		"id": 39, "file_name": "bonus_damage_on_kill",
		"affix_name": "Bonus Damage on Kill", "description": "+N damage on next attack after kill",
		"family": "offense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 2.0, "effect_max": 30.0,
		"effect_data": {"effect": "bonus_damage_flat"},
		"tags": ["proc", "damage", "on_kill"]
	})
	
	# ── OFFENSE TIER 3 (17 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 10, "file_name": "global_damage_multiplier",
		"affix_name": "Global Damage Multiplier", "description": "×N all damage dealt",
		"family": "offense", "tier": 3, "category": C.DAMAGE_MULTIPLIER,
		"effect_min": 1.05, "effect_max": 1.60,
		"tags": ["damage", "multiplier"]
	})
	catalog.append({
		"id": 19, "file_name": "lifesteal",
		"affix_name": "Lifesteal", "description": "Heal N% of damage dealt on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.03, "proc_chance_max": 0.20,
		"effect_data": {"effect": "heal_percent_damage"},
		"tags": ["proc", "heal", "on_hit"]
	})
	catalog.append({
		"id": 21, "file_name": "bonus_pct_damage_on_hit",
		"affix_name": "Bonus % Damage on Hit", "description": "+N% bonus damage on each hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.05, "proc_chance_max": 0.25,
		"effect_data": {"effect": "bonus_damage_percent"},
		"tags": ["proc", "damage", "on_hit"]
	})
	catalog.append({
		"id": 22, "file_name": "stacking_damage_buff_on_hit",
		"affix_name": "Stacking Damage Buff on Hit", "description": "+N damage per hit, stacks",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"effect_min": 1.0, "effect_max": 10.0,
		"effect_data": {"effect": "stacking_buff", "buff_category": "DAMAGE_BONUS"},
		"tags": ["proc", "damage", "stacking", "on_hit"]
	})
	catalog.append({
		"id": 23, "file_name": "temp_dice_affix_on_hit",
		"affix_name": "Temp Dice Affix on Hit", "description": "Grant temp dice modifier on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"effect_number": 1.0,
		"effect_data": {"effect": "grant_temp_dice_affix"},
		"tags": ["proc", "dice", "on_hit"]
	})
	catalog.append({
		"id": 27, "file_name": "apply_shadow_on_hit",
		"affix_name": "Apply Shadow on Hit", "description": "N% chance to Shadow on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.08, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status", "status": "shadow"},
		"tags": ["proc", "status", "shadow", "on_hit"]
	})
	catalog.append({
		"id": 29, "file_name": "apply_slowed_on_hit",
		"affix_name": "Apply Slowed on Hit", "description": "N% chance to Slow on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.08, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status", "status": "slowed"},
		"tags": ["proc", "status", "on_hit"]
	})
	catalog.append({
		"id": 30, "file_name": "apply_corrode_on_hit",
		"affix_name": "Apply Corrode on Hit", "description": "N% chance to Corrode on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.08, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status", "status": "corrode"},
		"tags": ["proc", "status", "on_hit"]
	})
	catalog.append({
		"id": 31, "file_name": "apply_enfeeble_on_hit",
		"affix_name": "Apply Enfeeble on Hit", "description": "N% chance to Enfeeble on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.08, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status", "status": "enfeeble"},
		"tags": ["proc", "status", "on_hit"]
	})
	catalog.append({
		"id": 32, "file_name": "apply_expose_on_hit",
		"affix_name": "Apply Expose on Hit", "description": "N% chance to Expose on hit",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEAL_DAMAGE,
		"proc_chance_min": 0.08, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status", "status": "expose"},
		"tags": ["proc", "status", "on_hit"]
	})
	catalog.append({
		"id": 34, "file_name": "stacking_buff_per_die_used",
		"affix_name": "Stacking Buff per Die Used", "description": "+N damage stack per die used",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DIE_USED,
		"effect_min": 1.0, "effect_max": 8.0,
		"effect_data": {"effect": "stacking_buff"},
		"tags": ["proc", "stacking", "dice"]
	})
	catalog.append({
		"id": 35, "file_name": "apply_status_per_die_used",
		"affix_name": "Apply Status per Die Used", "description": "Apply status when consuming dice",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DIE_USED,
		"proc_chance_min": 0.10, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status"},
		"tags": ["proc", "status", "dice"]
	})
	catalog.append({
		"id": 37, "file_name": "apply_status_per_action",
		"affix_name": "Apply Status per Action", "description": "Chance to apply status per action",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_ACTION_USED,
		"proc_chance_min": 0.10, "proc_chance_max": 0.40,
		"effect_data": {"effect": "apply_status"},
		"tags": ["proc", "status"]
	})
	catalog.append({
		"id": 38, "file_name": "temp_buff_per_action",
		"affix_name": "Temp Buff per Action", "description": "Gain temp buff after each action",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_ACTION_USED,
		"effect_number": 1.0,
		"effect_data": {"effect": "temp_affix"},
		"tags": ["proc", "buff"]
	})
	catalog.append({
		"id": 40, "file_name": "stacking_buff_on_kill",
		"affix_name": "Stacking Buff on Kill", "description": "Gain stacking damage buff on kill",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 1.0, "effect_max": 10.0,
		"effect_data": {"effect": "stacking_buff"},
		"tags": ["proc", "stacking", "on_kill"]
	})
	catalog.append({
		"id": 41, "file_name": "temp_buff_on_kill",
		"affix_name": "Temp Buff on Kill", "description": "Gain temporary combat buff on kill",
		"family": "offense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_number": 1.0,
		"effect_data": {"effect": "temp_affix"},
		"tags": ["proc", "buff", "on_kill"]
	})
	catalog.append({
		"id": 42, "file_name": "granted_offensive_action",
		"affix_name": "Granted Offensive Action", "description": "Grants a bonus attack action",
		"family": "offense", "tier": 3, "category": C.NEW_ACTION,
		"effect_number": 1.0,
		"tags": ["action_grant", "offensive"]
	})
	
	# ── DEFENSE TIER 1 (9 affixes) ──────────────────────────────────────
	
	catalog.append({
		"id": 43, "file_name": "armor_bonus",
		"affix_name": "Armor Bonus", "description": "+N Armor",
		"family": "defense", "tier": 1, "category": C.ARMOR_BONUS,
		"effect_min": 2.0, "effect_max": 80.0,
		"tags": ["defense", "armor", "physical"]
	})
	catalog.append({
		"id": 44, "file_name": "defense_bonus",
		"affix_name": "Defense Bonus", "description": "+N Defense",
		"family": "defense", "tier": 1, "category": C.DEFENSE_BONUS,
		"effect_min": 1.0, "effect_max": 60.0,
		"tags": ["defense"]
	})
	catalog.append({
		"id": 46, "file_name": "fire_resist",
		"affix_name": "Fire Resist", "description": "+N Fire resistance",
		"family": "defense", "tier": 1, "category": C.FIRE_RESIST_BONUS,
		"effect_min": 2.0, "effect_max": 40.0,
		"tags": ["resist", "elemental", "fire"]
	})
	catalog.append({
		"id": 47, "file_name": "ice_resist",
		"affix_name": "Ice Resist", "description": "+N Ice resistance",
		"family": "defense", "tier": 1, "category": C.ICE_RESIST_BONUS,
		"effect_min": 2.0, "effect_max": 40.0,
		"tags": ["resist", "elemental", "ice"]
	})
	catalog.append({
		"id": 48, "file_name": "shock_resist",
		"affix_name": "Shock Resist", "description": "+N Shock resistance",
		"family": "defense", "tier": 1, "category": C.SHOCK_RESIST_BONUS,
		"effect_min": 2.0, "effect_max": 40.0,
		"tags": ["resist", "elemental", "shock"]
	})
	catalog.append({
		"id": 49, "file_name": "poison_resist",
		"affix_name": "Poison Resist", "description": "+N Poison resistance",
		"family": "defense", "tier": 1, "category": C.POISON_RESIST_BONUS,
		"effect_min": 2.0, "effect_max": 40.0,
		"tags": ["resist", "elemental", "poison"]
	})
	catalog.append({
		"id": 50, "file_name": "shadow_resist",
		"affix_name": "Shadow Resist", "description": "+N Shadow resistance",
		"family": "defense", "tier": 1, "category": C.SHADOW_RESIST_BONUS,
		"effect_min": 2.0, "effect_max": 40.0,
		"tags": ["resist", "elemental", "shadow"]
	})
	catalog.append({
		"id": 51, "file_name": "health_bonus",
		"affix_name": "Health Bonus", "description": "+N maximum health",
		"family": "defense", "tier": 1, "category": C.HEALTH_BONUS,
		"effect_min": 5.0, "effect_max": 250.0,
		"tags": ["defense", "health"]
	})
	catalog.append({
		"id": 79, "file_name": "heal_after_combat_flat",
		"affix_name": "Heal after Combat", "description": "Heal N after combat",
		"family": "defense", "tier": 1, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_END,
		"effect_min": 3.0, "effect_max": 50.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "out_of_combat"]
	})
	
	# ── DEFENSE TIER 2 (17 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 52, "file_name": "barrier_bonus",
		"affix_name": "Barrier Bonus", "description": "+N Barrier",
		"family": "defense", "tier": 2, "category": C.BARRIER_BONUS,
		"effect_min": 3.0, "effect_max": 120.0,
		"tags": ["defense", "barrier"]
	})
	catalog.append({
		"id": 53, "file_name": "heal_on_hit_taken_flat",
		"affix_name": "Heal on Hit Taken", "description": "Heal N when hit",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"effect_min": 1.0, "effect_max": 30.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "defensive"]
	})
	catalog.append({
		"id": 55, "file_name": "gain_armor_on_hit_taken",
		"affix_name": "Gain Armor on Hit Taken", "description": "+N armor when hit",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_armor"},
		"tags": ["proc", "armor", "defensive"]
	})
	catalog.append({
		"id": 56, "file_name": "gain_barrier_on_hit_taken",
		"affix_name": "Gain Barrier on Hit Taken", "description": "+N barrier when hit",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "defensive"]
	})
	catalog.append({
		"id": 64, "file_name": "hp_regen_on_turn_start",
		"affix_name": "HP Regen on Turn Start", "description": "Heal N at start of turn",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_min": 1.0, "effect_max": 25.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "regen"]
	})
	catalog.append({
		"id": 65, "file_name": "barrier_regen_on_turn_start",
		"affix_name": "Barrier Regen on Turn Start", "description": "+N barrier at start of turn",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "regen"]
	})
	catalog.append({
		"id": 66, "file_name": "armor_regen_on_turn_start",
		"affix_name": "Armor Regen on Turn Start", "description": "+N armor at start of turn",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_min": 1.0, "effect_max": 15.0,
		"effect_data": {"effect": "gain_armor"},
		"tags": ["proc", "armor", "regen"]
	})
	catalog.append({
		"id": 67, "file_name": "heal_on_turn_end",
		"affix_name": "Heal on Turn End", "description": "Heal N at end of turn",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_END,
		"effect_min": 1.0, "effect_max": 25.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "regen"]
	})
	catalog.append({
		"id": 68, "file_name": "barrier_on_turn_end",
		"affix_name": "Barrier on Turn End", "description": "+N barrier at end of turn",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_END,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "regen"]
	})
	catalog.append({
		"id": 69, "file_name": "starting_armor",
		"affix_name": "Starting Armor", "description": "+N armor at combat start",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_START,
		"effect_min": 2.0, "effect_max": 40.0,
		"effect_data": {"effect": "gain_armor"},
		"tags": ["proc", "armor", "combat_start"]
	})
	catalog.append({
		"id": 70, "file_name": "starting_barrier",
		"affix_name": "Starting Barrier", "description": "+N barrier at combat start",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_START,
		"effect_min": 2.0, "effect_max": 30.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "combat_start"]
	})
	catalog.append({
		"id": 71, "file_name": "bonus_armor_on_defend",
		"affix_name": "Bonus Armor on Defend", "description": "+N extra armor when defending",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEFEND,
		"effect_min": 2.0, "effect_max": 25.0,
		"effect_data": {"effect": "gain_armor"},
		"tags": ["proc", "armor", "defend"]
	})
	catalog.append({
		"id": 72, "file_name": "heal_on_defend",
		"affix_name": "Heal on Defend", "description": "Heal N when defending",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DEFEND,
		"effect_min": 2.0, "effect_max": 25.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "defend"]
	})
	catalog.append({
		"id": 75, "file_name": "heal_on_kill_flat",
		"affix_name": "Heal on Kill", "description": "Heal N on kill",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 2.0, "effect_max": 30.0,
		"effect_data": {"effect": "heal_flat"},
		"tags": ["proc", "heal", "on_kill"]
	})
	catalog.append({
		"id": 77, "file_name": "armor_on_kill",
		"affix_name": "Armor on Kill", "description": "+N armor on kill",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_armor"},
		"tags": ["proc", "armor", "on_kill"]
	})
	catalog.append({
		"id": 78, "file_name": "barrier_on_kill",
		"affix_name": "Barrier on Kill", "description": "+N barrier on kill",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 1.0, "effect_max": 20.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "on_kill"]
	})
	catalog.append({
		"id": 80, "file_name": "heal_after_combat_pct",
		"affix_name": "Heal after Combat (% HP)", "description": "Heal N% max HP after combat",
		"family": "defense", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_END,
		"proc_chance_min": 0.03, "proc_chance_max": 0.20,
		"effect_data": {"effect": "heal_percent_max_hp"},
		"tags": ["proc", "heal", "out_of_combat"]
	})
	
	# ── DEFENSE TIER 3 (13 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 45, "file_name": "defense_multiplier",
		"affix_name": "Defense Multiplier", "description": "×N defense",
		"family": "defense", "tier": 3, "category": C.DEFENSE_MULTIPLIER,
		"effect_min": 1.05, "effect_max": 1.50,
		"tags": ["defense", "multiplier"]
	})
	catalog.append({
		"id": 54, "file_name": "heal_on_hit_taken_pct",
		"affix_name": "Heal on Hit Taken (% HP)", "description": "Heal N% max HP when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.02, "proc_chance_max": 0.15,
		"effect_data": {"effect": "heal_percent_max_hp"},
		"tags": ["proc", "heal", "defensive"]
	})
	catalog.append({
		"id": 57, "file_name": "thorns_apply_status",
		"affix_name": "Thorns", "description": "Apply debuff to attacker when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.15, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "target": "attacker"},
		"tags": ["proc", "thorns", "defensive"]
	})
	catalog.append({
		"id": 58, "file_name": "temp_buff_on_hit_taken",
		"affix_name": "Temp Buff on Hit Taken", "description": "Gain temp defensive buff when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"effect_number": 1.0,
		"effect_data": {"effect": "temp_affix"},
		"tags": ["proc", "buff", "defensive"]
	})
	catalog.append({
		"id": 59, "file_name": "stacking_buff_on_hit_taken",
		"affix_name": "Stacking Buff on Hit Taken", "description": "+N defense per hit taken",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"effect_min": 1.0, "effect_max": 10.0,
		"effect_data": {"effect": "stacking_buff"},
		"tags": ["proc", "stacking", "defensive"]
	})
	catalog.append({
		"id": 60, "file_name": "thorns_chill",
		"affix_name": "Thorns: Chill", "description": "Apply Chill to attacker when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.15, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "chill", "target": "attacker"},
		"tags": ["proc", "thorns", "status", "ice"]
	})
	catalog.append({
		"id": 61, "file_name": "thorns_slowed",
		"affix_name": "Thorns: Slowed", "description": "Apply Slowed to attacker when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.15, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "slowed", "target": "attacker"},
		"tags": ["proc", "thorns", "status"]
	})
	catalog.append({
		"id": 62, "file_name": "thorns_corrode",
		"affix_name": "Thorns: Corrode", "description": "Apply Corrode to attacker when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.15, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "corrode", "target": "attacker"},
		"tags": ["proc", "thorns", "status"]
	})
	catalog.append({
		"id": 63, "file_name": "thorns_enfeeble",
		"affix_name": "Thorns: Enfeeble", "description": "Apply Enfeeble to attacker when hit",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TAKE_DAMAGE,
		"proc_chance_min": 0.15, "proc_chance_max": 0.50,
		"effect_data": {"effect": "apply_status", "status": "enfeeble", "target": "attacker"},
		"tags": ["proc", "thorns", "status"]
	})
	catalog.append({
		"id": 73, "file_name": "barrier_on_defend",
		"affix_name": "Barrier on Defend", "description": "+N barrier when defending",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEFEND,
		"effect_min": 2.0, "effect_max": 30.0,
		"effect_data": {"effect": "gain_barrier"},
		"tags": ["proc", "barrier", "defend"]
	})
	catalog.append({
		"id": 74, "file_name": "temp_buff_on_defend",
		"affix_name": "Temp Buff on Defend", "description": "Gain temp buff after defending",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DEFEND,
		"effect_number": 1.0,
		"effect_data": {"effect": "temp_affix"},
		"tags": ["proc", "buff", "defend"]
	})
	catalog.append({
		"id": 76, "file_name": "heal_on_kill_pct",
		"affix_name": "Heal on Kill (% HP)", "description": "Heal N% max HP on kill",
		"family": "defense", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"proc_chance_min": 0.03, "proc_chance_max": 0.20,
		"effect_data": {"effect": "heal_percent_max_hp"},
		"tags": ["proc", "heal", "on_kill"]
	})
	catalog.append({
		"id": 81, "file_name": "granted_defensive_action",
		"affix_name": "Granted Defensive Action", "description": "Grants a bonus defend/heal action",
		"family": "defense", "tier": 3, "category": C.NEW_ACTION,
		"effect_number": 1.0,
		"tags": ["action_grant", "defensive"]
	})
	
	# ── UTILITY TIER 1 (16 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 82, "file_name": "mana_bonus",
		"affix_name": "Mana Bonus", "description": "+N maximum mana",
		"family": "utility", "tier": 1, "category": C.MANA_BONUS,
		"effect_min": 3.0, "effect_max": 80.0,
		"tags": ["mana"]
	})
	
	# Neutral dice grants (no scaling — you get the die or you don't)
	catalog.append({
		"id": 86, "file_name": "grant_d4_neutral",
		"affix_name": "Grant D4 (Neutral)", "description": "Add a neutral D4 to your dice pool",
		"family": "utility", "tier": 1, "category": C.DICE,
		"effect_number": 1.0,
		"tags": ["dice_grant", "neutral"]
	})
	catalog.append({
		"id": 87, "file_name": "grant_d6_neutral",
		"affix_name": "Grant D6 (Neutral)", "description": "Add a neutral D6 to your dice pool",
		"family": "utility", "tier": 1, "category": C.DICE,
		"effect_number": 1.0,
		"tags": ["dice_grant", "neutral"]
	})
	
	# Elemental D4 grants
	var _elem_d4 := [
		[91,  "fire",     "Fire"],
		[94,  "ice",      "Ice"],
		[97,  "shock",    "Shock"],
		[100, "poison",   "Poison"],
		[103, "shadow",   "Shadow"],
		[106, "slashing", "Slashing"],
		[109, "blunt",    "Blunt"],
		[112, "piercing", "Piercing"],
	]
	for data in _elem_d4:
		catalog.append({
			"id": data[0], "file_name": "grant_%s_d4" % data[1],
			"affix_name": "Grant %s D4" % data[2],
			"description": "Add a %s D4 to your dice pool" % data[2],
			"family": "utility", "tier": 1, "category": C.DICE,
			"effect_number": 1.0,
			"tags": ["dice_grant", data[1]]
		})
	
	# Additional T1 utility (dice manipulation / out-of-combat)
	catalog.append({
		"id": 131, "file_name": "gold_find_bonus",
		"affix_name": "Gold Find Bonus", "description": "+N% gold from encounters",
		"family": "utility", "tier": 1, "category": C.MISC,
		"effect_min": 0.05, "effect_max": 0.50,
		"tags": ["out_of_combat", "gold"]
	})
	catalog.append({
		"id": 132, "file_name": "xp_find_bonus",
		"affix_name": "XP Find Bonus", "description": "+N% experience from encounters",
		"family": "utility", "tier": 1, "category": C.MISC,
		"effect_min": 0.05, "effect_max": 0.40,
		"tags": ["out_of_combat", "xp"]
	})
	catalog.append({
		"id": 133, "file_name": "loot_find_bonus",
		"affix_name": "Loot Find Bonus", "description": "+N% loot drop chance",
		"family": "utility", "tier": 1, "category": C.MISC,
		"effect_min": 0.05, "effect_max": 0.35,
		"tags": ["out_of_combat", "loot"]
	})
	catalog.append({
		"id": 134, "file_name": "rarity_find_bonus",
		"affix_name": "Rarity Find Bonus", "description": "+N% chance for higher rarity drops",
		"family": "utility", "tier": 1, "category": C.MISC,
		"effect_min": 0.03, "effect_max": 0.25,
		"tags": ["out_of_combat", "loot", "rarity"]
	})
	
	# ── UTILITY TIER 2 (25 affixes) ─────────────────────────────────────
	
	catalog.append({
		"id": 83, "file_name": "mana_regen_per_turn",
		"affix_name": "Mana Regen per Turn", "description": "+N mana at start of each turn",
		"family": "utility", "tier": 2, "category": C.PER_TURN,
		"effect_min": 1.0, "effect_max": 15.0,
		"tags": ["mana", "regen"]
	})
	catalog.append({
		"id": 84, "file_name": "mana_cost_reduction",
		"affix_name": "Mana Cost Reduction", "description": "Reduce action mana costs by N",
		"family": "utility", "tier": 2, "category": C.MISC,
		"effect_min": 1.0, "effect_max": 10.0,
		"tags": ["mana"]
	})
	catalog.append({
		"id": 85, "file_name": "mana_on_kill",
		"affix_name": "Mana on Kill", "description": "+N mana on kill",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_KILL,
		"effect_min": 1.0, "effect_max": 15.0,
		"effect_data": {"effect": "mana_restore"},
		"tags": ["proc", "mana", "on_kill"]
	})
	
	# Neutral D8/D10
	catalog.append({
		"id": 88, "file_name": "grant_d8_neutral",
		"affix_name": "Grant D8 (Neutral)", "description": "Add a neutral D8 to your dice pool",
		"family": "utility", "tier": 2, "category": C.DICE,
		"effect_number": 1.0,
		"tags": ["dice_grant", "neutral"]
	})
	catalog.append({
		"id": 89, "file_name": "grant_d10_neutral",
		"affix_name": "Grant D10 (Neutral)", "description": "Add a neutral D10 to your dice pool",
		"family": "utility", "tier": 2, "category": C.DICE,
		"effect_number": 1.0,
		"tags": ["dice_grant", "neutral"]
	})
	
	# Elemental D6 grants
	var _elem_d6 := [
		[92,  "fire",     "Fire"],
		[95,  "ice",      "Ice"],
		[98,  "shock",    "Shock"],
		[101, "poison",   "Poison"],
		[104, "shadow",   "Shadow"],
		[107, "slashing", "Slashing"],
		[110, "blunt",    "Blunt"],
		[113, "piercing", "Piercing"],
	]
	for data in _elem_d6:
		catalog.append({
			"id": data[0], "file_name": "grant_%s_d6" % data[1],
			"affix_name": "Grant %s D6" % data[2],
			"description": "Add a %s D6 to your dice pool" % data[2],
			"family": "utility", "tier": 2, "category": C.DICE,
			"effect_number": 1.0,
			"tags": ["dice_grant", data[1]]
		})
	
	# Dice manipulation T2
	catalog.append({
		"id": 135, "file_name": "reroll_lowest_die",
		"affix_name": "Reroll Lowest Die", "description": "Reroll your lowest die once per turn",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_number": 1.0,
		"effect_data": {"effect": "reroll_lowest"},
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 136, "file_name": "bonus_die_value_flat",
		"affix_name": "Bonus Die Value", "description": "+N to all rolled die values",
		"family": "utility", "tier": 2, "category": C.MISC,
		"effect_min": 1.0, "effect_max": 3.0,
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 137, "file_name": "starting_mana",
		"affix_name": "Starting Mana", "description": "+N mana at combat start",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_START,
		"effect_min": 2.0, "effect_max": 20.0,
		"effect_data": {"effect": "mana_restore"},
		"tags": ["proc", "mana", "combat_start"]
	})
	catalog.append({
		"id": 138, "file_name": "extra_die_on_turn_start",
		"affix_name": "Extra Die on Turn Start", "description": "Roll one additional die at turn start",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_number": 1.0,
		"effect_data": {"effect": "grant_extra_die"},
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 139, "file_name": "heal_after_combat_mana",
		"affix_name": "Mana after Combat", "description": "+N mana after combat",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_COMBAT_END,
		"effect_min": 2.0, "effect_max": 20.0,
		"effect_data": {"effect": "mana_restore"},
		"tags": ["proc", "mana", "out_of_combat"]
	})
	catalog.append({
		"id": 140, "file_name": "mana_on_die_used",
		"affix_name": "Mana on Die Used", "description": "+N mana when a die is consumed",
		"family": "utility", "tier": 2, "category": C.PROC,
		"proc_trigger": P.ON_DIE_USED,
		"effect_min": 1.0, "effect_max": 8.0,
		"effect_data": {"effect": "mana_restore"},
		"tags": ["proc", "mana", "dice"]
	})
	
	# ── UTILITY TIER 3 (29 affixes) ─────────────────────────────────────
	
	# Neutral D12
	catalog.append({
		"id": 90, "file_name": "grant_d12_neutral",
		"affix_name": "Grant D12 (Neutral)", "description": "Add a neutral D12 to your dice pool",
		"family": "utility", "tier": 3, "category": C.DICE,
		"effect_number": 1.0,
		"tags": ["dice_grant", "neutral"]
	})
	
	# Elemental D8 grants
	var _elem_d8 := [
		[93,  "fire",     "Fire"],
		[96,  "ice",      "Ice"],
		[99,  "shock",    "Shock"],
		[102, "poison",   "Poison"],
		[105, "shadow",   "Shadow"],
		[108, "slashing", "Slashing"],
		[111, "blunt",    "Blunt"],
		[114, "piercing", "Piercing"],
	]
	for data in _elem_d8:
		catalog.append({
			"id": data[0], "file_name": "grant_%s_d8" % data[1],
			"affix_name": "Grant %s D8" % data[2],
			"description": "Add a %s D8 to your dice pool" % data[2],
			"family": "utility", "tier": 3, "category": C.DICE,
			"effect_number": 1.0,
			"tags": ["dice_grant", data[1]]
		})
	
	# Elemental D10 grants
	var _elem_d10 := [
		[115, "fire",     "Fire"],
		[117, "ice",      "Ice"],
		[119, "shock",    "Shock"],
		[121, "poison",   "Poison"],
		[123, "shadow",   "Shadow"],
		[125, "slashing", "Slashing"],
		[127, "blunt",    "Blunt"],
		[129, "piercing", "Piercing"],
	]
	for data in _elem_d10:
		catalog.append({
			"id": data[0], "file_name": "grant_%s_d10" % data[1],
			"affix_name": "Grant %s D10" % data[2],
			"description": "Add a %s D10 to your dice pool" % data[2],
			"family": "utility", "tier": 3, "category": C.DICE,
			"effect_number": 1.0,
			"tags": ["dice_grant", data[1]]
		})
	
	# Elemental D12 grants
	var _elem_d12 := [
		[116, "fire",     "Fire"],
		[118, "ice",      "Ice"],
		[120, "shock",    "Shock"],
		[122, "poison",   "Poison"],
		[124, "shadow",   "Shadow"],
		[126, "slashing", "Slashing"],
		[128, "blunt",    "Blunt"],
		[130, "piercing", "Piercing"],
	]
	for data in _elem_d12:
		catalog.append({
			"id": data[0], "file_name": "grant_%s_d12" % data[1],
			"affix_name": "Grant %s D12" % data[2],
			"description": "Add a %s D12 to your dice pool" % data[2],
			"family": "utility", "tier": 3, "category": C.DICE,
			"effect_number": 1.0,
			"tags": ["dice_grant", data[1]]
		})
	
	# Advanced dice manipulation T3
	catalog.append({
		"id": 141, "file_name": "reroll_any_die",
		"affix_name": "Reroll Any Die", "description": "Reroll one die of your choice per turn",
		"family": "utility", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_number": 1.0,
		"effect_data": {"effect": "reroll_any"},
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 142, "file_name": "bonus_die_value_pct",
		"affix_name": "Bonus Die Value %", "description": "+N% to all rolled die values",
		"family": "utility", "tier": 3, "category": C.MISC,
		"effect_min": 0.05, "effect_max": 0.30,
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 143, "file_name": "duplicate_die_on_max",
		"affix_name": "Duplicate Die on Max Roll", "description": "N% chance to duplicate die on max value",
		"family": "utility", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_DIE_USED,
		"proc_chance_min": 0.10, "proc_chance_max": 0.35,
		"effect_data": {"effect": "duplicate_die", "condition": "max_roll"},
		"tags": ["dice_manipulation"]
	})
	catalog.append({
		"id": 144, "file_name": "convert_die_element",
		"affix_name": "Convert Die Element", "description": "Convert one die per turn to equipped element",
		"family": "utility", "tier": 3, "category": C.PROC,
		"proc_trigger": P.ON_TURN_START,
		"effect_number": 1.0,
		"effect_data": {"effect": "convert_element"},
		"tags": ["dice_manipulation", "elemental"]
	})
	catalog.append({
		"id": 145, "file_name": "granted_utility_action",
		"affix_name": "Granted Utility Action", "description": "Grants a bonus utility action",
		"family": "utility", "tier": 3, "category": C.NEW_ACTION,
		"effect_number": 1.0,
		"tags": ["action_grant", "utility"]
	})
	
	# ────────────────────────────────────────────────────────────────────
	# VERIFICATION
	# ────────────────────────────────────────────────────────────────────
	var counts := {"offense_1": 0, "offense_2": 0, "offense_3": 0,
				   "defense_1": 0, "defense_2": 0, "defense_3": 0,
				   "utility_1": 0, "utility_2": 0, "utility_3": 0}
	for entry in catalog:
		var key := "%s_%d" % [entry.family, entry.tier]
		counts[key] += 1
	
	print("\n📊 Catalog breakdown:")
	for key in counts:
		print("  %s: %d" % [key, counts[key]])
	print("  TOTAL: %d" % catalog.size())
	
	return catalog
