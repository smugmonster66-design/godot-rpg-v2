# add_starting_gear_button.gd - Button to add configured starting items to player
# v3 — Routes items through LootManager.generate_drop() for full pipeline.
extends Button

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================
@export_group("Starting Items")
@export var starting_items: Array[EquippableItem] = []

@export_group("Drop Settings")
## Item level for generated drops. Higher = stronger affix rolls.
@export_range(1, 100) var drop_item_level: int = 15
## Region stamp (1-6). Affects regional affix distribution when implemented.
@export_range(1, 6) var drop_region: int = 1

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready():
	pressed.connect(_on_pressed)
	
	if starting_items.size() > 0:
		text = "Add Gear (%d)" % starting_items.size()
	else:
		text = "Add Gear (None)"
		disabled = true

# ============================================================================
# BUTTON LOGIC
# ============================================================================
func _on_pressed():
	"""Add all configured items to player inventory via LootManager pipeline."""
	if not GameManager or not GameManager.player:
		print("❌ No player found!")
		return
	
	if starting_items.size() == 0:
		print("⚠️  No starting items configured on button")
		return
	
	print("🎒 Adding starting gear (Lv.%d, R%d)..." % [drop_item_level, drop_region])
	
	var items_added = 0
	for item_template in starting_items:
		if not item_template:
			print("  ⚠️  Null item in array - skipping")
			continue
		
		# Route through full loot pipeline: duplicate + stamp + roll
		var result = LootManager.generate_drop(item_template, drop_item_level, drop_region)
		var item: EquippableItem = result.get("item")
		
		if not item:
			print("  ❌ generate_drop failed for %s" % item_template.item_name)
			continue
		
		GameManager.player.add_to_inventory(item)
		
		var affix_count = item.item_affixes.size()
		print("  ✅ %s (Lv.%d, %s) — %d affixes" % [
			item.item_name, item.item_level,
			EquippableItem.Rarity.keys()[item.rarity], affix_count])
		for affix in item.item_affixes:
			if affix:
				print("      → %s: %s" % [affix.affix_name, affix.get_rolled_value_string()])
		items_added += 1
	
	print("🎒 Finished adding %d items" % items_added)
	
	disabled = true
	text = "Gear Added!"
