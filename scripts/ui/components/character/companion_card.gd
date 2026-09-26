# companion_card.gd - Compact companion display with portrait and HP
extends PanelContainer

signal clicked(instance)

var portrait_rect: TextureRect
var name_label: Label
var hp_bar  # resource_bar instance
var _instance = null

func _ready():
	_discover_nodes()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("companion_card_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"portrait": portrait_rect = child
			"companion_name": name_label = child
			"hp_bar": hp_bar = child

func get_instance():
	return _instance

func set_companion(instance, player_max_hp: int, player_level: int):
	_instance = instance
	visible = true
	if not instance or not instance.companion_data:
		clear()
		return

	# Initialize HP if uninitialized (-1 means never entered combat)
	if instance.current_hp < 0:
		instance.initialize_hp(player_max_hp, player_level)

	if portrait_rect and instance.companion_data.portrait:
		portrait_rect.texture = instance.companion_data.portrait

	if name_label:
		name_label.text = instance.get_display_name()

	if hp_bar:
		var max_hp = instance.get_max_hp(player_max_hp, player_level)
		hp_bar.set_values("HP", instance.current_hp, max_hp,
			ThemeManager.PALETTE.health, ThemeManager.PALETTE.health_low)

func clear():
	_instance = null
	visible = false
	if portrait_rect:
		portrait_rect.texture = null
	if name_label:
		name_label.text = ""
