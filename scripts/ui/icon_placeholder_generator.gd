# icon_placeholder_generator.gd
# Tool script to generate placeholder icons
@tool
extends EditorScript

# Run this script from Script Editor → File → Run
func _run():
	print("Generating placeholder icons...")
	
	# Navigation icons
	create_icon("res://assets/ui/icons/navigation/character.png", Color(0.8, 0.3, 0.3), "C")
	create_icon("res://assets/ui/icons/navigation/skills.png", Color(0.3, 0.3, 0.8), "S")
	create_icon("res://assets/ui/icons/navigation/equipment.png", Color(0.3, 0.8, 0.3), "E")
	create_icon("res://assets/ui/icons/navigation/inventory.png", Color(0.8, 0.8, 0.3), "I")
	create_icon("res://assets/ui/icons/navigation/quests.png", Color(0.8, 0.3, 0.8), "Q")
	
	# Category icons
	create_icon("res://assets/ui/icons/categories/all.png", Color(0.5, 0.5, 0.5), "A")
	create_icon("res://assets/ui/icons/categories/head.png", Color(0.6, 0.4, 0.4), "H")
	create_icon("res://assets/ui/icons/categories/torso.png", Color(0.4, 0.6, 0.4), "T")
	create_icon("res://assets/ui/icons/categories/gloves.png", Color(0.4, 0.4, 0.6), "G")
	create_icon("res://assets/ui/icons/categories/boots.png", Color(0.5, 0.5, 0.3), "B")
	create_icon("res://assets/ui/icons/categories/weapon.png", Color(0.7, 0.3, 0.3), "W")
	create_icon("res://assets/ui/icons/categories/shield.png", Color(0.3, 0.5, 0.5), "S")
	create_icon("res://assets/ui/icons/categories/accessory.png", Color(0.6, 0.3, 0.6), "A")
	create_icon("res://assets/ui/icons/categories/potion.png", Color(0.3, 0.6, 0.6), "P")
	
	print("✅ Placeholder icons created!")
	print("You can now replace these with real icons later")

func create_icon(path: String, color: Color, letter: String = ""):
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(color)
	
	# Add border
	for x in range(128):
		for y in range(128):
			if x < 8 or x > 119 or y < 8 or y > 119:
				img.set_pixel(x, y, Color.WHITE)
	
	# Save
	img.save_png(path)
	print("  Created: %s" % path)
