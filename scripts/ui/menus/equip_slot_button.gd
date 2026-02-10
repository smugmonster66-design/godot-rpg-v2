# equip_slot_button.gd
# v3 — Accepts EquippableItem directly via apply_equippable().
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
	custom_minimum_size = slot_size
	size = slot_size
	
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.position = Vector2.ZERO
	panel.size = slot_size
	
	slot_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_button.position = Vector2.ZERO
	slot_button.size = slot_size
	slot_button.custom_minimum_size = slot_size

# ============================================================================
# PUBLIC API
# ============================================================================

func apply_equippable(item: EquippableItem):
	"""Display an EquippableItem in this slot."""
	slot_button.text = ""
	slot_button.icon = null
	_clear_style_overrides()
	
	if item.icon:
		slot_button.icon = item.icon
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.expand_icon = true
	else:
		var first_char = item.item_name[0] if item.item_name.length() > 0 else "?"
		slot_button.text = first_char
	
	slot_button.tooltip_text = "%s (%s %s)" % [item.item_name, item.get_rarity_name(), item.get_slot_name()]

func apply_item(item):
	"""Apply an EquippableItem to this slot's display."""
	if item is EquippableItem:
		apply_equippable(item)
	else:
		push_warning("EquipSlotButton.apply_item() received non-EquippableItem: %s" % str(item))

func clear():
	slot_button.text = ""
	slot_button.icon = null
	slot_button.tooltip_text = slot_name
	_apply_empty_visual()

# ============================================================================
# PRIVATE
# ============================================================================

func _apply_empty_visual():
	slot_button.text = ""
	slot_button.tooltip_text = slot_name

func _clear_style_overrides():
	slot_button.remove_theme_stylebox_override("normal")
	slot_button.remove_theme_stylebox_override("hover")
	slot_button.remove_theme_stylebox_override("pressed")
