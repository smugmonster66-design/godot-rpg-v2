# add_starting_gear_button.gd - Button to add configured starting items to player
# v3 — Adds EquippableItem directly to inventory (no Dictionary conversion).
extends Button

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================
@export_group("Starting Items")
@export var starting_items: Array[EquippableItem] = []

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
	"""Add all configured items to player inventory as EquippableItem instances."""
	if not GameManager or not GameManager.player:
		print("❌ No player found!")
		return
	
	if starting_items.size() == 0:
		print("⚠️  No starting items configured on button")
		return
	
	print("🎒 Adding starting gear from button...")
	
	var items_added = 0
	for item_template in starting_items:
		if not item_template:
			print("  ⚠️  Null item in array - skipping")
			continue
		
		# Create a fresh copy (important for independent affix rolls)
		var item_copy: EquippableItem = item_template.duplicate(true)
		
		# Initialize affixes (rolls values, creates runtime dice)
		item_copy.initialize_affixes()
		
		# Add directly to player inventory as EquippableItem
		GameManager.player.add_to_inventory(item_copy)
		
		print("  ✅ Added %s (%s) to inventory" % [item_copy.item_name, item_copy.get_rarity_name()])
		items_added += 1
	
	print("🎒 Finished adding %d items" % items_added)
	
	disabled = true
	text = "Gear Added!"
