@tool
extends EditorScript

func _run():
	print("Generating UI textures...")
	
	# Dice background
	create_rounded_rect("res://assets/textures/ui/dice_bg.png", 
		Vector2i(90, 110), Color(0.2, 0.2, 0.3), 10)
	
	create_rounded_rect("res://assets/textures/ui/dice_bg_fire.png", 
		Vector2i(90, 110), Color(0.8, 0.3, 0.1), 10)
	
	# Action fields
	create_rounded_rect("res://assets/textures/ui/action_field_attack.png", 
		Vector2i(110, 120), Color(0.8, 0.2, 0.2), 10)
	
	create_rounded_rect("res://assets/textures/ui/action_field_defend.png", 
		Vector2i(110, 120), Color(0.2, 0.4, 0.8), 10)
	
	create_rounded_rect("res://assets/textures/ui/action_field_heal.png", 
		Vector2i(110, 120), Color(0.2, 0.8, 0.3), 10)
	
	print("✅ Textures generated!")

func create_rounded_rect(path: String, size: Vector2i, color: Color, radius: int):
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	# Draw rounded rectangle (simplified)
	for y in range(size.y):
		for x in range(size.x):
			var in_bounds = (
				x >= radius and x < size.x - radius and
				y >= radius and y < size.y - radius
			)
			if in_bounds:
				img.set_pixel(x, y, color)
	
	# Add border
	for y in range(size.y):
		for x in range(size.x):
			if x < 2 or x >= size.x - 2 or y < 2 or y >= size.y - 2:
				if img.get_pixel(x, y).a > 0:
					img.set_pixel(x, y, Color.WHITE)
	
	img.save_png(path)
	print("  Created: %s" % path)
