# res://scripts/ui/rarity_display_helper.gd
# Shared utility for rarity-based visual display on items.
# Provides shader application, glow, color lookup, and affix display creation.
# Stateless — all methods are static. No instance needed.
extends RefCounted
class_name RarityDisplayHelper

# ============================================================================
# SHADER / GLOW
# ============================================================================

static func apply_rarity_shader(tex_rect: TextureRect, item: EquippableItem,
		settings: Dictionary = {}) -> void:
	"""Apply the rarity_border shader to a TextureRect.
	
	Optional settings keys (all have sane defaults):
		glow_radius, glow_softness, glow_width, glow_strength,
		glow_blend, glow_saturation, pulse_speed, pulse_amount
	"""
	var shader = load("res://shaders/rarity_border.gdshader")
	if not shader:
		tex_rect.material = null
		return

	var color = ThemeManager.get_rarity_color_enum(item.rarity)

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("border_color", color)
	mat.set_shader_parameter("glow_radius",    settings.get("glow_radius", 4.0))
	mat.set_shader_parameter("glow_softness",  settings.get("glow_softness", 2.0))
	mat.set_shader_parameter("glow_width",     settings.get("glow_width", 0.6))
	mat.set_shader_parameter("glow_strength",  settings.get("glow_strength", 1.5))
	mat.set_shader_parameter("glow_blend",     settings.get("glow_blend", 0.6))
	mat.set_shader_parameter("glow_saturation", settings.get("glow_saturation", 1.0))
	mat.set_shader_parameter("pulse_speed",    settings.get("pulse_speed", 1.0))
	mat.set_shader_parameter("pulse_amount",   settings.get("pulse_amount", 0.15))
	tex_rect.material = mat


static func apply_rarity_glow(tex_rect: TextureRect, item: EquippableItem,
		config: RarityGlowConfig = null) -> void:
	"""Apply the soft radial glow layer behind a TextureRect via RarityGlowHelper."""
	var rarity_name = item.get_rarity_name()
	RarityGlowHelper.apply_glow(tex_rect, tex_rect.texture, rarity_name, config)


static func clear_rarity_visuals(tex_rect: TextureRect) -> void:
	"""Remove both shader and glow from a TextureRect."""
	tex_rect.material = null
	RarityGlowHelper.clear_glow(tex_rect)

# ============================================================================
# COLOR LOOKUP
# ============================================================================

static func get_rarity_color(item: EquippableItem) -> Color:
	"""Get the theme color for an item's rarity."""
	return ThemeManager.get_rarity_color_enum(item.rarity)


static func get_rarity_name(item: EquippableItem) -> String:
	"""Get the rarity name string."""
	return item.get_rarity_name()

# ============================================================================
# AFFIX DISPLAY
# ============================================================================

static func create_affix_label(affix: Affix, name_color: Color = Color(0.9, 0.7, 0.3),
	name_size: int = ThemeManager.FONT_SIZES.normal,
	desc_size: int = ThemeManager.FONT_SIZES.caption) -> PanelContainer:
	"""Create a display panel for an Affix showing its resolved description."""
	var panel = PanelContainer.new()

	var desc_text: String = ""
	if affix.has_method("get_resolved_description"):
		desc_text = affix.get_resolved_description()
	elif affix.description and not affix.description.is_empty():
		desc_text = affix.description

	if not desc_text.is_empty():
		var desc_label = Label.new()
		desc_label.text = desc_text
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(desc_label)

	return panel


static func create_item_summary_card(item: EquippableItem, icon_size: float = 80.0) -> PanelContainer:
	"""Create a compact item display card with rarity-colored name and slot label.
	Used by dungeon popups and post-combat summary for loot grids."""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(icon_size + 20, icon_size + 50)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	


	# Rarity-tinted border style
	var rarity_color = ThemeManager.get_rarity_color_enum(item.rarity)
	var style = ThemeManager._flat_box(
		Color(0.08, 0.08, 0.12, 0.9),
		rarity_color, 6, 2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if item.icon:
		icon_rect.texture = item.icon
	else:
		# Colored placeholder
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(rarity_color * 0.5)
		icon_rect.texture = ImageTexture.create_from_image(img)

	# Apply rarity shader to icon
	apply_rarity_shader(icon_rect, item)
	vbox.add_child(icon_rect)

	# Name label
	var name_label = Label.new()
	name_label.text = item.item_name if item.item_name != "" else "Unknown Item"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", rarity_color)
	#name_label.add_theme_font_size_override("font_size", 11)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	return panel
