# res://scripts/ui/map/map_radial_button.gd
# A single action button inside the map node radial menu.
extends Button

signal action_requested(button_def: MapNodeButtonDef)

## Fixed size of the button. Textures are constrained to this; nothing can expand it.
@export var button_size: Vector2 = Vector2(80, 80)
## Size of the icon drawn in the centre of the button.
@export var icon_size: Vector2 = Vector2(40, 40)
## Final fallback icon when no per-button or category icon is set.
@export var fallback_icon: Texture2D = null

@export_group("Category Icons")
@export var icon_travel: Texture2D = null
@export var icon_enter_dungeon: Texture2D = null
@export var icon_enter_zone: Texture2D = null
@export var icon_rest: Texture2D = null
@export var icon_npcs: Texture2D = null
@export var icon_quests: Texture2D = null
@export var icon_party: Texture2D = null
@export var icon_stash: Texture2D = null

## Texture for the "new content" indicator badge (top-left corner).
## Leave null to use a fallback colored circle.
@export var new_content_icon: Texture2D = null

var _button_def: MapNodeButtonDef = null
var _new_indicator: Control = null

@onready var _button_texture_rect: TextureRect = $ButtonTexture
@onready var _icon_rect: TextureRect = $Icon

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	custom_minimum_size = button_size
	size = button_size
	if _icon_rect:
		# Bypass anchor math entirely — position and size are fully known at this point.
		_icon_rect.anchor_left   = 0.0
		_icon_rect.anchor_top    = 0.0
		_icon_rect.anchor_right  = 0.0
		_icon_rect.anchor_bottom = 0.0
		_icon_rect.position = (button_size - icon_size) * 0.5
		_icon_rect.size     = icon_size
	_create_new_indicator()

# ============================================================================
# SETUP
# ============================================================================

func setup(button_def: MapNodeButtonDef, player) -> void:
	_button_def = button_def

	# Background plate — only override scene default when the def supplies one
	if _button_texture_rect and button_def.button_texture:
		_button_texture_rect.texture = button_def.button_texture

	# Icon — per-button override → category default → global fallback
	if _icon_rect:
		_icon_rect.texture = button_def.icon if button_def.icon else _get_category_icon(button_def.button_category)

	# Tooltip
	tooltip_text = button_def.tooltip

	# Condition check
	var condition_met = button_def.is_condition_met(player)
	if not condition_met:
		if button_def.hide_when_condition_fails:
			visible = false
		else:
			disabled = true

# ============================================================================
# SIGNALS
# ============================================================================

func _get_category_icon(category: MapNodeButtonDef.ButtonCategory) -> Texture2D:
	match category:
		MapNodeButtonDef.ButtonCategory.TRAVEL:        return icon_travel
		MapNodeButtonDef.ButtonCategory.ENTER_DUNGEON: return icon_enter_dungeon
		MapNodeButtonDef.ButtonCategory.ENTER_ZONE:    return icon_enter_zone
		MapNodeButtonDef.ButtonCategory.REST:          return icon_rest
		MapNodeButtonDef.ButtonCategory.NPCS:          return icon_npcs
		MapNodeButtonDef.ButtonCategory.QUESTS:        return icon_quests
		MapNodeButtonDef.ButtonCategory.PARTY:         return icon_party
		MapNodeButtonDef.ButtonCategory.STASH:         return icon_stash
	return fallback_icon

func get_button_def() -> MapNodeButtonDef:
	return _button_def

func _on_pressed() -> void:
	if _button_def:
		action_requested.emit(_button_def)

# ============================================================================
# NEW CONTENT INDICATOR
# ============================================================================

func _create_new_indicator() -> void:
	if new_content_icon:
		var tex_rect = TextureRect.new()
		tex_rect.texture = new_content_icon
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_new_indicator = tex_rect
	else:
		# Fallback: small colored circle drawn via a Control
		var dot = _NewContentDot.new()
		_new_indicator = dot
	_new_indicator.size = Vector2(28, 28)
	_new_indicator.position = Vector2(-4, -4)
	_new_indicator.visible = false
	_new_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_indicator.z_index = 1
	add_child(_new_indicator)

func set_new_content_visible(show: bool) -> void:
	"""Show or hide the new content indicator badge."""
	if _new_indicator:
		_new_indicator.visible = show

## Simple fallback indicator — a colored circle with "!" text.
class _NewContentDot extends Control:
	func _draw() -> void:
		var center = size * 0.5
		var radius = min(size.x, size.y) * 0.5
		draw_circle(center, radius, Color(0.9, 0.2, 0.15, 1.0))
		draw_circle(center, radius - 2.0, Color(1.0, 0.35, 0.25, 1.0))
		# Draw "!" in center
		var font = ThemeDB.fallback_font
		if font:
			var font_size := 18
			var text_size = font.get_string_size("!", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = center - text_size * 0.5 + Vector2(0, text_size.y * 0.35)
			draw_string(font, text_pos, "!", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
