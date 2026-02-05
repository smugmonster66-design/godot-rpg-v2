# equip_slot_button.gd
class_name EquipSlotButton
extends Control

# ============================================================================
# EXPORTS
# ============================================================================
@export var slot_name: String = ""

@export var slot_size: Vector2 = Vector2(128, 128):
	set(value):
		slot_size = value
		if is_node_ready():
			_apply_size()

@export var slot_texture: Texture2D:
	set(value):
		slot_texture = value
		if is_node_ready() and panel:
			var style = StyleBoxTexture.new()
			style.texture = value
			panel.add_theme_stylebox_override("panel", style)

# ============================================================================
# SIGNALS
# ============================================================================
signal slot_clicked(slot: String)

# ============================================================================
# REFERENCES
# ============================================================================
@onready var panel: Panel = $Panel
@onready var slot_button: Button = $SlotButton

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready():
	_apply_size()
	
	if slot_texture and panel:
		var style = StyleBoxTexture.new()
		style.texture = slot_texture
		panel.add_theme_stylebox_override("panel", style)
	
	slot_button.pressed.connect(func(): slot_clicked.emit(slot_name))
	_apply_empty_visual()

func _apply_size():
	# Set our own size so parent containers know how big we are
	custom_minimum_size = slot_size
	size = slot_size
	
	# Reset Panel to fill this control exactly
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.position = Vector2.ZERO
	panel.size = slot_size
	
	# Reset SlotButton to fill this control exactly (on top of Panel)
	slot_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_button.position = Vector2.ZERO
	slot_button.size = slot_size
	slot_button.custom_minimum_size = slot_size

# ============================================================================
# PUBLIC API
# ============================================================================
func apply_item(item: Dictionary):
	slot_button.text = ""
	slot_button.icon = null
	_clear_style_overrides()

	if item.has("icon") and item.icon:
		slot_button.icon = item.icon
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.expand_icon = true
	else:
		var item_name = item.get("name", "?")
		slot_button.text = item_name[0] if item_name.length() > 0 else "?"
		slot_button.add_theme_font_size_override("font_size", 24)

	# Transparent button so Panel texture shows through
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0)
	slot_button.add_theme_stylebox_override("normal", bg)
	slot_button.add_theme_stylebox_override("hover", bg)
	slot_button.add_theme_stylebox_override("pressed", bg)

func clear():
	_apply_empty_visual()

# ============================================================================
# PRIVATE
# ============================================================================
func _apply_empty_visual():
	slot_button.icon = null
	slot_button.text = ""
	_clear_style_overrides()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	slot_button.add_theme_stylebox_override("normal", style)
	slot_button.add_theme_stylebox_override("hover", style)
	slot_button.add_theme_stylebox_override("pressed", style)

func _clear_style_overrides():
	slot_button.remove_theme_stylebox_override("normal")
	slot_button.remove_theme_stylebox_override("hover")
	slot_button.remove_theme_stylebox_override("pressed")
	slot_button.remove_theme_font_size_override("font_size")
