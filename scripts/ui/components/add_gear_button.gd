# add_starting_gear_button.gd - Button to add configured starting items to player
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
	# Connect button press
	pressed.connect(_on_pressed)
	
	# Update button text with item count
	if starting_items.size() > 0:
		text = "Add Gear (%d)" % starting_items.size()
	else:
		text = "Add Gear (None)"
		disabled = true  # Disable if no items configured

# ============================================================================
# BUTTON LOGIC
# ============================================================================

func _on_pressed():
	"""Add all configured items to player inventory"""
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
		
		# Create a fresh copy (important for affixes)
		var item_copy = item_template.duplicate(true)
		
		# Initialize affixes (rolls or uses manual)
		item_copy.initialize_affixes(AffixPool)
		
		# Convert to dictionary
		var item_dict = item_copy.to_dict()
		
		# DEBUG: Print what to_dict returns
		print("  📋 to_dict() returned:")
		print("    name: %s" % item_dict.get("name", "MISSING"))
		print("    slot: %s" % item_dict.get("slot", "MISSING"))
		print("    icon: %s" % item_dict.get("icon", "MISSING"))
		print("    keys: " + str(item_dict.keys()))
		
		item_dict["item_affixes"] = item_copy.get_all_affixes()
		
		# Add to player inventory
		GameManager.player.add_to_inventory(item_dict)
		
		print("  ✅ Added %s (%s) to inventory" % [item_copy.item_name, item_copy.get_rarity_name()])
		items_added += 1
	
	print("🎒 Finished adding %d items" % items_added)
	
	# Disable button after use
	disabled = true
	text = "Gear Added!"
	
	# Notify any open menus to refresh
	if GameManager.player.has_signal("inventory_changed"):
		GameManager.player.inventory_changed.emit()
