# res://scripts/ui/rarity_glow_helper.gd
class_name RarityGlowHelper

static var _rarity_colors: RarityColors = null
static var _glow_shader: Shader = null

## Create or update a soft radial glow behind a target Control.
static func apply_glow(
	target: Control,
	tex: Texture2D,
	rarity_name: String,
	config: RarityGlowConfig = null
) -> TextureRect:
	if not target or not tex:
		clear_glow(target)
		return null
	
	if rarity_name == "Common" or rarity_name == "":
		clear_glow(target)
		return null
	
	if not config:
		config = RarityGlowConfig.new()
	
	var glow: TextureRect = target.get_node_or_null("RarityGlow") as TextureRect
	if not glow:
		glow = TextureRect.new()
		glow.name = "RarityGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		target.add_child(glow)
	
	
	
	# White pixel as base — shader does all the visuals
	if not glow.texture:
		var img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		glow.texture = ImageTexture.create_from_image(img)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	
	
	# Use minimum size as fallback when layout hasn't happened yet
	var target_size = target.size
	if target_size == Vector2.ZERO:
		target_size = target.custom_minimum_size
	
	glow.position = Vector2(-config.padding, -config.padding)
	glow.size = target_size + Vector2(config.padding * 2, config.padding * 2)
	
	# Update when target gets resized by container layout
	if not target.resized.is_connected(_on_target_resized.bind(target, glow, config)):
		target.resized.connect(_on_target_resized.bind(target, glow, config))
	
	if not _rarity_colors:
		_rarity_colors = load("res://resources/data/rarity_colors.tres") as RarityColors
	var color = Color.WHITE
	if _rarity_colors:
		color = _rarity_colors.get_color_for_rarity(rarity_name)
	
	if not _glow_shader:
		_glow_shader = load("res://shaders/rarity_glow.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow_alpha", config.alpha)
	mat.set_shader_parameter("glow_softness", config.softness)
	mat.set_shader_parameter("pulse_speed", config.pulse_speed)
	mat.set_shader_parameter("pulse_amount", config.pulse_amount)
	mat.set_shader_parameter("glow_width", config.glow_width)
	glow.material = mat
	glow.modulate = Color.WHITE
	
	glow.show()
	return glow

static func _on_target_resized(target: Control, glow: TextureRect, config: RarityGlowConfig):
	"""Reposition glow when target gets laid out"""
	if not is_instance_valid(glow) or not is_instance_valid(target):
		return
	glow.position = Vector2(-config.padding, -config.padding)
	glow.size = target.size + Vector2(config.padding * 2, config.padding * 2)


static func clear_glow(target: Control):
	"""Remove glow from a target if it exists"""
	if not target:
		return
	var glow = target.get_node_or_null("RarityGlow")
	if glow:
		glow.hide()
