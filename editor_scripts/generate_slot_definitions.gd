# res://editor_scripts/generate_slot_definitions.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# Creates 8 SlotDefinition .tres files based on the master matrix:
#   - Head:      Defense + Utility only
#   - Torso:     Defense + Utility only
#   - Gloves:    Offense + Defense + Utility (all families)
#   - Boots:     Defense + Utility only
#   - Main Hand: Offense + Defense + Utility (all families)
#   - Off Hand:  Offense + Defense + Utility (all families)
#   - Heavy:     Offense + Defense + Utility (all families) + double rolls
#   - Accessory: Offense + Defense + Utility (all families)
#
# Safe to re-run. Existing files are updated, not duplicated.
#
@tool
extends EditorScript

const SLOT_DIR := "res://resources/slot_definitions/"

func _run() -> void:
	print("\n" + "═".repeat(50))
	print("  GENERATING SLOT DEFINITIONS")
	print("═".repeat(50))
	
	DirAccess.make_dir_recursive_absolute(SLOT_DIR)
	
	var slots := _build_slot_configs()
	var created := 0
	var updated := 0
	
	for config in slots:
		var path: String = SLOT_DIR + config.file_name + ".tres"
		var slot_def: SlotDefinition = null
		var is_new := false
		
		if ResourceLoader.exists(path):
			slot_def = load(path)
		if slot_def == null:
			slot_def = SlotDefinition.new()
			is_new = true
		
		# Core identity
		slot_def.slot_name = config.slot_name
		slot_def.slot_type = config.slot_type
		
		# Tier 1 families
		slot_def.tier_1_offense = config.t1_offense
		slot_def.tier_1_defense = config.t1_defense
		slot_def.tier_1_utility = config.t1_utility
		
		# Tier 2 families
		slot_def.tier_2_offense = config.t2_offense
		slot_def.tier_2_defense = config.t2_defense
		slot_def.tier_2_utility = config.t2_utility
		
		# Tier 3 families
		slot_def.tier_3_offense = config.t3_offense
		slot_def.tier_3_defense = config.t3_defense
		slot_def.tier_3_utility = config.t3_utility
		
		# Base stats
		slot_def.base_armor = config.get("base_armor", 0)
		slot_def.base_barrier = config.get("base_barrier", 0)
		slot_def.base_health = config.get("base_health", 0)
		slot_def.base_mana = config.get("base_mana", 0)
		
		# Heavy weapon flag
		slot_def.double_affix_rolls = config.get("double_rolls", false)
		
		var err := ResourceSaver.save(slot_def, path)
		if err == OK:
			if is_new:
				created += 1
			else:
				updated += 1
			
			var families_str := _families_string(slot_def)
			print("  %s %s → %s" % [
				"✨" if is_new else "🔄",
				config.slot_name,
				families_str
			])
		else:
			push_error("Failed to save: %s (error %d)" % [path, err])
	
	print("\n✅ Slot definitions: %d created, %d updated" % [created, updated])
	print("   Location: %s" % SLOT_DIR)
	print("═".repeat(50) + "\n")
	
	EditorInterface.get_resource_filesystem().scan()


func _families_string(sd: SlotDefinition) -> String:
	var parts: Array[String] = []
	var t1 := sd.get_tier_families(1)
	var t2 := sd.get_tier_families(2)
	var t3 := sd.get_tier_families(3)
	parts.append("T1:[%s]" % "/".join(t1))
	parts.append("T2:[%s]" % "/".join(t2))
	parts.append("T3:[%s]" % "/".join(t3))
	return " ".join(parts)


func _build_slot_configs() -> Array:
	var E := EquippableItem.EquipSlot
	
	return [
		# ── HEAD: Defense + Utility ──────────────────────────────
		{
			"file_name": "head_slot",
			"slot_name": "Head",
			"slot_type": E.HEAD,
			"t1_offense": false, "t1_defense": true, "t1_utility": true,
			"t2_offense": false, "t2_defense": true, "t2_utility": true,
			"t3_offense": false, "t3_defense": true, "t3_utility": true,
			"base_armor": 8,
			"base_health": 10,
		},
		
		# ── TORSO: Defense + Utility ─────────────────────────────
		{
			"file_name": "torso_slot",
			"slot_name": "Torso",
			"slot_type": E.TORSO,
			"t1_offense": false, "t1_defense": true, "t1_utility": true,
			"t2_offense": false, "t2_defense": true, "t2_utility": true,
			"t3_offense": false, "t3_defense": true, "t3_utility": true,
			"base_armor": 15,
			"base_health": 15,
		},
		
		# ── GLOVES: All families ─────────────────────────────────
		{
			"file_name": "gloves_slot",
			"slot_name": "Gloves",
			"slot_type": E.GLOVES,
			"t1_offense": true, "t1_defense": true, "t1_utility": true,
			"t2_offense": true, "t2_defense": true, "t2_utility": true,
			"t3_offense": true, "t3_defense": true, "t3_utility": true,
			"base_armor": 5,
		},
		
		# ── BOOTS: Defense + Utility ─────────────────────────────
		{
			"file_name": "boots_slot",
			"slot_name": "Boots",
			"slot_type": E.BOOTS,
			"t1_offense": false, "t1_defense": true, "t1_utility": true,
			"t2_offense": false, "t2_defense": true, "t2_utility": true,
			"t3_offense": false, "t3_defense": true, "t3_utility": true,
			"base_armor": 6,
		},
		
		# ── MAIN HAND: All families ──────────────────────────────
		{
			"file_name": "main_hand_slot",
			"slot_name": "Main Hand",
			"slot_type": E.MAIN_HAND,
			"t1_offense": true, "t1_defense": true, "t1_utility": true,
			"t2_offense": true, "t2_defense": true, "t2_utility": true,
			"t3_offense": true, "t3_defense": true, "t3_utility": true,
		},
		
		# ── OFF HAND: All families ───────────────────────────────
		{
			"file_name": "off_hand_slot",
			"slot_name": "Off Hand",
			"slot_type": E.OFF_HAND,
			"t1_offense": true, "t1_defense": true, "t1_utility": true,
			"t2_offense": true, "t2_defense": true, "t2_utility": true,
			"t3_offense": true, "t3_defense": true, "t3_utility": true,
			"base_armor": 4,
		},
		
		# ── HEAVY: All families + double rolls ───────────────────
		{
			"file_name": "heavy_slot",
			"slot_name": "Heavy (Two-Handed)",
			"slot_type": E.HEAVY,
			"t1_offense": true, "t1_defense": true, "t1_utility": true,
			"t2_offense": true, "t2_defense": true, "t2_utility": true,
			"t3_offense": true, "t3_defense": true, "t3_utility": true,
			"double_rolls": true,
		},
		
		# ── ACCESSORY: All families ──────────────────────────────
		{
			"file_name": "accessory_slot",
			"slot_name": "Accessory",
			"slot_type": E.ACCESSORY,
			"t1_offense": true, "t1_defense": true, "t1_utility": true,
			"t2_offense": true, "t2_defense": true, "t2_utility": true,
			"t3_offense": true, "t3_defense": true, "t3_utility": true,
			"base_mana": 5,
		},
	]
