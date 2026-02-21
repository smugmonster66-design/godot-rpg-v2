# res://scripts/debug/equip_proc_diagnostic.gd
# Generates "Bones's Diagnostic Ring" — a test Accessory with one proc affix
# per hook, each healing a UNIQUE amount so you can identify which hooks
# fire from the Output panel.
#
# RUN: Editor → Script → Run (Ctrl+Shift+X)
# THEN: Play the game, open inventory, equip the ring, enter combat.
#
# The .tres is saved with all affixes embedded in base_stat_affixes (exported),
# so they persist across editor/runtime and get wired into item_affixes
# automatically when initialize_affixes() runs at equip time.
#
# EXPECTED OUTPUT PER COMBAT:
#   ┌─────────────────────┬──────────┬─────────────────────────────────┐
#   │ Hook                │ Heal Amt │ When You'll See It              │
#   ├─────────────────────┼──────────┼─────────────────────────────────┤
#   │ ON_DEAL_DAMAGE (dmg)│ +77 dmg  │ ⚡ Proc bonus damage: 77 → X   │
#   │ ON_DEAL_DAMAGE (hp) │ heal 11  │ After each attack lands         │
#   │ ON_KILL             │ heal 22  │ After enemy dies                │
#   │ ON_DEFEND           │ heal 33  │ After using Defend action       │
#   │ ON_ACTION_USED      │ heal 44  │ After ANY action (once/action)  │
#   │ ON_DIE_USED         │ heal 55  │ Per die consumed (N× per action)│
#   │ ON_TURN_END         │ heal 66  │ When you press End Turn         │
#   │ ON_COMBAT_END       │ heal 77  │ After Victory/Defeat            │
#   └─────────────────────┴──────────┴─────────────────────────────────┘
#
# WHAT TO LOOK FOR:
#   ✅ "💚 Proc heal: 22" after "☠️ EnemyName defeated!" = ON_KILL works
#   ✅ "⚡ Proc bonus damage: 77 → EnemyName" = bonus dmg application works
#   ❌ "logged — wire into damage calc" = Patch 1 not applied
#   ❌ "wire target selection" = Patch 2 not applied
@tool
extends EditorScript

const ITEM_NAME := "Bones's Diagnostic Ring"
const SAVE_PATH := "res://resources/items/debug/diagnostic_ring.tres"

func _run():
	print("\n" + "=".repeat(50))
	print("🔬 PROC DIAGNOSTIC RING GENERATOR")
	print("=".repeat(50))
	
	var item = _build_item()
	
	# Ensure directory exists
	var dir = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var err = ResourceSaver.save(item, SAVE_PATH)
	if err != OK:
		print("❌ Failed to save: %s (error %d)" % [SAVE_PATH, err])
		return
	
	print("\n💾 Saved: %s" % SAVE_PATH)
	print("📋 Next steps:")
	print("   1. Play the game")
	print("   2. Open inventory → find '%s'" % ITEM_NAME)
	print("   3. Equip it (Accessory slot)")
	print("   4. Enter combat and watch the Output panel for heal numbers")
	print("=".repeat(50) + "\n")


func _build_item() -> EquippableItem:
	var item = EquippableItem.new()
	item.item_name = ITEM_NAME
	item.description = "Debug ring. Each proc heals a unique amount to identify which combat hooks fire."
	item.flavor_text = "The bones remember everything."
	item.rarity = EquippableItem.Rarity.LEGENDARY
	item.equip_slot = EquippableItem.EquipSlot.ACCESSORY
	item.item_level = 1
	item.region = 1
	item.required_level = 0
	item.required_strength = 0
	item.required_agility = 0
	item.required_intellect = 0
	
	# ────────────────────────────────────────────────────────────────
	# Wire into base_stat_affixes — this is @exported and persists
	# to the .tres file. initialize_affixes() copies these into
	# item_affixes at equip time automatically.
	# ────────────────────────────────────────────────────────────────
	var affixes: Array[Affix] = []
	
	# 1. ON_DEAL_DAMAGE: Bonus damage 77 (tests Patch 1 — damage application)
	affixes.append(_make_proc(
		"DiagRing: +77 Bonus Dmg on Hit",
		Affix.ProcTrigger.ON_DEAL_DAMAGE,
		"bonus_damage_flat", 77.0))
	
	# 2. ON_DEAL_DAMAGE: Heal 11 (tests Patch 8 — target passthrough)
	affixes.append(_make_proc(
		"DiagRing: Heal 11 on Hit",
		Affix.ProcTrigger.ON_DEAL_DAMAGE,
		"heal_flat", 11.0))
	
	# 3. ON_KILL: Heal 22 (tests Patch 3)
	affixes.append(_make_proc(
		"DiagRing: Heal 22 on Kill",
		Affix.ProcTrigger.ON_KILL,
		"heal_flat", 22.0))
	
	# 4. ON_DEFEND: Heal 33 (tests Patch 4)
	affixes.append(_make_proc(
		"DiagRing: Heal 33 on Defend",
		Affix.ProcTrigger.ON_DEFEND,
		"heal_flat", 33.0))
	
	# 5. ON_ACTION_USED: Heal 44 (tests Patch 5a)
	affixes.append(_make_proc(
		"DiagRing: Heal 44 per Action",
		Affix.ProcTrigger.ON_ACTION_USED,
		"heal_flat", 44.0))
	
	# 6. ON_DIE_USED: Heal 55 (tests Patch 5b)
	affixes.append(_make_proc(
		"DiagRing: Heal 55 per Die",
		Affix.ProcTrigger.ON_DIE_USED,
		"heal_flat", 55.0))
	
	# 7. ON_TURN_END: Heal 66 (already wired — sanity check)
	affixes.append(_make_proc(
		"DiagRing: Heal 66 on Turn End",
		Affix.ProcTrigger.ON_TURN_END,
		"heal_flat", 66.0))
	
	# 8. ON_COMBAT_END: Heal 77 (tests Patch 6)
	affixes.append(_make_proc(
		"DiagRing: Heal 77 on Combat End",
		Affix.ProcTrigger.ON_COMBAT_END,
		"heal_flat", 77.0))
	
	item.base_stat_affixes = affixes
	
	print("🔧 Built '%s' with %d diagnostic affixes:" % [ITEM_NAME, affixes.size()])
	for a in affixes:
		print("   • %s (trigger=%d, effect=%s, value=%.0f)" % [
			a.affix_name, a.proc_trigger,
			a.effect_data.get("proc_effect", "?"), a.effect_number])
	
	return item


func _make_proc(affix_name: String, trigger: Affix.ProcTrigger,
		proc_effect: String, value: float) -> Affix:
	"""Create a single proc affix with 100% chance."""
	var affix = Affix.new()
	affix.affix_name = affix_name
	affix.description = "Debug: %s → %s %.0f" % [
		_trigger_name(trigger), proc_effect, value]
	affix.category = Affix.Category.PROC
	affix.source = ITEM_NAME
	affix.source_type = "item"
	affix.proc_trigger = trigger
	affix.proc_chance = 1.0
	affix.effect_number = value
	affix.effect_data = {
		"proc_effect": proc_effect,
	}
	return affix


func _trigger_name(t: Affix.ProcTrigger) -> String:
	match t:
		Affix.ProcTrigger.ON_DEAL_DAMAGE: return "ON_DEAL_DAMAGE"
		Affix.ProcTrigger.ON_TAKE_DAMAGE: return "ON_TAKE_DAMAGE"
		Affix.ProcTrigger.ON_TURN_START: return "ON_TURN_START"
		Affix.ProcTrigger.ON_TURN_END: return "ON_TURN_END"
		Affix.ProcTrigger.ON_COMBAT_START: return "ON_COMBAT_START"
		Affix.ProcTrigger.ON_COMBAT_END: return "ON_COMBAT_END"
		Affix.ProcTrigger.ON_DIE_USED: return "ON_DIE_USED"
		Affix.ProcTrigger.ON_ACTION_USED: return "ON_ACTION_USED"
		Affix.ProcTrigger.ON_KILL: return "ON_KILL"
		Affix.ProcTrigger.ON_DEFEND: return "ON_DEFEND"
	return "UNKNOWN_%d" % t
