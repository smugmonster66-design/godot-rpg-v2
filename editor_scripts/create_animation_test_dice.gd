# res://editor_scripts/create_animation_test_dice.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Creates 3 test dice with affixes that trigger the new animations:
#   - Test Die: Locked (golden flash on lock)
#   - Test Die: Reroller (bright flash on reroll)
#   - Test Die: Destroyer (shrink to zero on destruction)
#
# Usage:
#   1. Run this script
#   2. In-game, open console and run: add_test_dice()
#   3. Enter combat and use the dice to see animations
@tool
extends EditorScript

const OUTPUT_DIR := "res://resources/dice/test_animation_dice/"

# Preload scripts to avoid class_name resolution issues in @tool
var _die_script = load("res://resources/data/die_resource.gd")
var _affix_script = load("res://resources/data/dice_affix.gd")

# Load D6 visual assets
var _d6_fill = load("res://assets/dice/D6s/d6-basic-fill.png")
var _d6_stroke = load("res://assets/dice/D6s/d6-basic-stroke.png")
var _d6_combat_scene = load("res://scenes/ui/components/dice/combat/combat_die_d6.tscn")
var _d6_pool_scene = load("res://scenes/ui/components/dice/pool/pool_die_d6.tscn")

func _make_affix(name: String, desc: String, trig: int, eff_type: int, target: int, data: Dictionary = {}) -> Resource:
	"""Factory helper to create a DiceAffix with all properties set."""
	var affix = _affix_script.new()
	affix.set("affix_name", name)
	affix.set("description", desc)
	affix.set("trigger", trig)
	affix.set("effect_type", eff_type)
	affix.set("neighbor_target", target)
	affix.set("show_in_summary", true)
	if not data.is_empty():
		affix.set("effect_data", data)
	return affix

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	print("Creating test dice for animation verification...")
	
	if not _die_script or not _affix_script:
		print("Failed to load required scripts")
		return
	
	print("Scripts loaded successfully")
	print("DieResource script: %s" % _die_script)
	print("DiceAffix script: %s" % _affix_script)
	
	var counter = 0
	
	# ================================================================
	# TEST DIE 1: LOCKED (DIE_LOCKED animation)
	# ================================================================
	
	print("Creating die_locked...")
	var die_locked = _die_script.new(6, "Animation Test")
	print("  Die created: %s" % die_locked)
	die_locked.display_name = "Test Die: Locked"
	die_locked.color = Color(1.0, 0.9, 0.3)
	die_locked.fill_texture = _d6_fill
	die_locked.stroke_texture = _d6_stroke
	die_locked.combat_die_scene = _d6_combat_scene
	die_locked.pool_die_scene = _d6_pool_scene
	print("  Properties set")
	
	# Create LOCK_DIE affix
	print("Creating lock_affix...")
	var lock_affix = _make_affix("Test Lock", "Locks this die when rolled (for animation test)", 2, 12, 0)
	print("  Affix created and configured")
	
	# Use .assign() for typed array to avoid silent abort
	print("Assigning affix to die...")
	var locked_affixes: Array = [lock_affix]
	print("  Untyped array created with %d elements" % locked_affixes.size())
	die_locked.inherent_affixes.assign(locked_affixes)
	print("  Array assigned, inherent_affixes size: %d" % die_locked.inherent_affixes.size())
	
	if _save(die_locked, OUTPUT_DIR + "test_die_locked.tres"):
		counter += 1
	
	# ================================================================
	# TEST DIE 2: REROLLER (DIE_ROLLED animation)
	# ================================================================
	
	print("Creating die_reroll...")
	var die_reroll = _die_script.new(6, "Animation Test")
	die_reroll.display_name = "Test Die: Reroller"
	die_reroll.color = Color(1.2, 1.2, 1.5)
	die_reroll.fill_texture = _d6_fill
	die_reroll.stroke_texture = _d6_stroke
	die_reroll.combat_die_scene = _d6_combat_scene
	die_reroll.pool_die_scene = _d6_pool_scene
	
	var reroll_affix = _make_affix("Test Reroll", "Rerolls if 1-3 (for animation test)", 0, 10, 0, {"threshold": 3})
	var reroll_affixes: Array = [reroll_affix]
	die_reroll.inherent_affixes.assign(reroll_affixes)
	
	if _save(die_reroll, OUTPUT_DIR + "test_die_reroller.tres"):
		counter += 1
	
	# ================================================================
	# TEST DIE 3: DESTROYER (DIE_DESTROYED animation)
	# ================================================================
	
	print("Creating die_destroy...")
	var die_destroy = _die_script.new(6, "Animation Test")
	die_destroy.display_name = "Test Die: Destroyer"
	die_destroy.color = Color(0.8, 0.2, 0.2)
	die_destroy.fill_texture = _d6_fill
	die_destroy.stroke_texture = _d6_stroke
	die_destroy.combat_die_scene = _d6_combat_scene
	die_destroy.pool_die_scene = _d6_pool_scene
	
	var destroy_affix = _make_affix("Test Destroy", "Permanently destroys this die when used (for animation test)", 1, 20, 0)
	var destroy_affixes: Array = [destroy_affix]
	die_destroy.inherent_affixes.assign(destroy_affixes)
	
	if _save(die_destroy, OUTPUT_DIR + "test_die_destroyer.tres"):
		counter += 1
	
	# ================================================================
	# SUMMARY
	# ================================================================
	
	print("")
	if counter == 3:
		print("Created 3 test dice!")
	else:
		print("Created %d/3 test dice" % counter)
	
	print("   Output: %s" % OUTPUT_DIR)
	print("")
	print("To test animations:")
	print("  1. Start the game")
	print("  2. Open the debug console (or use Player.dice_pool in code)")
	print("  3. Add test dice:")
	print("     player.dice_pool.add_die(load('%stest_die_locked.tres'))" % OUTPUT_DIR)
	print("     player.dice_pool.add_die(load('%stest_die_reroller.tres'))" % OUTPUT_DIR)
	print("     player.dice_pool.add_die(load('%stest_die_destroyer.tres'))" % OUTPUT_DIR)
	print("  4. Enter combat and watch for:")
	print("     - Golden flash when 'Test Die: Locked' is rolled")
	print("     - Bright flash when 'Test Die: Reroller' rolls 1-3")
	print("     - Shrink to zero when 'Test Die: Destroyer' is used")
	print("")
	print("Console should show:")
	print("  Emitted DIE_LOCKED for hand[X]")
	print("  Emitted DIE_ROLLED for hand[X]: 2 -> 5")
	print("  Emitted DIE_DESTROYED for pool[X]")


func _save(resource: Resource, path: String) -> bool:
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		print("  Saved: %s" % path)
		return true
	else:
		print("  Save failed: %s (error %d)" % [path, err])
		return false
