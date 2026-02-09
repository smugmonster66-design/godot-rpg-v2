# portrait_controller.gd - Component managing portrait display
# Attach to: PortraitContainer (Control node)
# Handles: mask, rarity frame glow, status icons, level badge, click-to-open
extends Control
class_name PortraitController

# ============================================================================
# SIGNALS
# ============================================================================
signal portrait_clicked()

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Resources")
@export var rarity_colors: RarityColors = null
@export var portrait_mask_shader: Shader = null
@export var frame_glow_shader: Shader = null

@export_group("Mask")
@export var default_mask: Texture2D = null

@export_group("Rarity Glow")
## Base intensity when only 1 item of highest rarity is equipped
@export_range(0.1, 0.5) var base_glow_intensity: float = 0.2
## Maximum intensity when all slots have highest rarity
@export_range(0.5, 1.0) var max_glow_intensity: float = 1.0
## Number of equipment slots used for intensity scaling
@export var total_equipment_slots: int = 7

@export_group("Status Icons")
## Maximum number of visible status icons around the portrait
@export var max_status_icons: int = 8
## Size of each status icon
@export var status_icon_size: Vector2 = Vector2(28, 28)

@export_group("Level Badge")
@export var badge_font_size: int = 14

# ============================================================================
# NODE REFERENCES (discovered or created)
# ============================================================================
var portrait_texture: TextureRect = null
var back_panel: Panel = null
var front_panel: Panel = null
var status_container: HBoxContainer = null
var level_badge_label: Label = null
var level_badge_bg: Panel = null

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var _current_mask: Texture2D = null
var _portrait_material: ShaderMaterial = null
var _frame_material: ShaderMaterial = null
var _is_ko: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_setup_shaders()
	_create_status_container()
	_create_level_badge()
	_setup_click_input()
	print("🖼️ PortraitController ready")

func _discover_nodes():
	"""Find existing portrait nodes in the scene tree."""
	# Look for children by name or type
	for child in get_children():
		if child is Panel:
			if child.name == "BackPanel":
				back_panel = child
			elif child.name == "FrontPanel":
				front_panel = child
		elif child is TextureRect and child.name == "PortraitTexture":
			portrait_texture = child

	if not portrait_texture:
		push_warning("PortraitController: No PortraitTexture found!")
	if not front_panel:
		push_warning("PortraitController: No FrontPanel found!")

	var found = []
	if portrait_texture: found.append("PortraitTexture")
	if back_panel: found.append("BackPanel")
	if front_panel: found.append("FrontPanel")
	print("  🖼️ Discovered: %s" % ", ".join(found))

func _setup_shaders():
	"""Apply shader materials to portrait and frame."""
	# Portrait mask shader
	if portrait_texture and portrait_mask_shader:
		_portrait_material = ShaderMaterial.new()
		_portrait_material.shader = portrait_mask_shader
		portrait_texture.material = _portrait_material

		if default_mask:
			set_mask(default_mask)
		print("  🖼️ Portrait mask shader applied")

	# Frame glow shader
	if front_panel and frame_glow_shader:
		_frame_material = ShaderMaterial.new()
		_frame_material.shader = frame_glow_shader
		front_panel.material = _frame_material
		# Start with no glow
		_frame_material.set_shader_parameter("glow_intensity", 0.0)
		print("  🖼️ Frame glow shader applied")

func _create_status_container():
	"""Create an HBoxContainer for status effect icons, positioned below the portrait."""
	status_container = HBoxContainer.new()
	status_container.name = "StatusIcons"
	status_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_container.anchor_top = 1.0
	status_container.anchor_bottom = 1.0
	status_container.offset_top = 4  # Small gap below portrait
	status_container.offset_bottom = 4 + status_icon_size.y
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	status_container.add_theme_constant_override("separation", 2)
	status_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_container)
	print("  🖼️ Status icon container created")

func _create_level_badge():
	"""Create a level badge in the bottom-right corner of the portrait."""
	# Background panel
	level_badge_bg = Panel.new()
	level_badge_bg.name = "LevelBadgeBG"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	level_badge_bg.add_theme_stylebox_override("panel", style)
	level_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position bottom-right
	level_badge_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	level_badge_bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	level_badge_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	level_badge_bg.offset_left = -40
	level_badge_bg.offset_top = -24
	level_badge_bg.offset_right = -4
	level_badge_bg.offset_bottom = -4
	add_child(level_badge_bg)

	# Label
	level_badge_label = Label.new()
	level_badge_label.name = "LevelLabel"
	level_badge_label.text = "Lv.1"
	level_badge_label.add_theme_font_size_override("font_size", badge_font_size)
	level_badge_label.add_theme_color_override("font_color", Color.WHITE)
	level_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge_bg.add_child(level_badge_label)

	print("  🖼️ Level badge created")

func _setup_click_input():
	"""Enable click detection on the portrait container."""
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

# ============================================================================
# PUBLIC API - PORTRAIT
# ============================================================================

func set_portrait_texture(texture: Texture2D):
	"""Set the character portrait image."""
	if portrait_texture:
		portrait_texture.texture = texture

func set_mask(mask: Texture2D):
	"""Swap the portrait mask texture."""
	_current_mask = mask
	if _portrait_material:
		_portrait_material.set_shader_parameter("mask_texture", mask)

func set_ko(is_ko: bool):
	"""Toggle death/KO grayscale effect."""
	_is_ko = is_ko
	if _portrait_material:
		_portrait_material.set_shader_parameter("grayscale_amount", 1.0 if is_ko else 0.0)

# ============================================================================
# PUBLIC API - PLAYER BINDING
# ============================================================================

func set_player(p_player: Player):
	"""Bind to a player and connect signals for live updates."""
	# Disconnect old player
	if player:
		_disconnect_player_signals()

	player = p_player

	if player:
		_connect_player_signals()
		refresh()

func refresh():
	"""Full refresh of all portrait elements."""
	_update_level_badge()
	_update_rarity_glow()
	_update_status_icons()
	_update_ko_state()

# ============================================================================
# RARITY GLOW
# ============================================================================

func _update_rarity_glow():
	"""Calculate and apply rarity glow based on equipped items."""
	if not _frame_material or not player:
		return

	var highest_rarity: int = -1  # EquippableItem.Rarity enum value
	var highest_count: int = 0

	for slot_name in player.equipment:
		var item = player.equipment[slot_name]
		if not item:
			continue

		var item_rarity: int = _get_item_rarity(item)
		if item_rarity > highest_rarity:
			highest_rarity = item_rarity
			highest_count = 1
		elif item_rarity == highest_rarity:
			highest_count += 1

	# No equipment or only common = no glow
	if highest_rarity <= EquippableItem.Rarity.COMMON:
		_frame_material.set_shader_parameter("glow_intensity", 0.0)
		return

	# Get color from RarityColors resource
	var glow_color: Color = Color.WHITE
	if rarity_colors:
		glow_color = rarity_colors.get_color_for_rarity_enum(highest_rarity)
	else:
		# Fallback colors
		match highest_rarity:
			EquippableItem.Rarity.UNCOMMON: glow_color = Color(0.2, 0.8, 0.2)
			EquippableItem.Rarity.RARE: glow_color = Color(0.2, 0.5, 1.0)
			EquippableItem.Rarity.EPIC: glow_color = Color(0.7, 0.2, 0.9)
			EquippableItem.Rarity.LEGENDARY: glow_color = Color(1.0, 0.6, 0.0)

	# Intensity scales: base + proportional to count of highest rarity items
	var count_ratio: float = float(highest_count) / float(total_equipment_slots)
	var intensity: float = lerp(base_glow_intensity, max_glow_intensity, count_ratio)

	# Higher rarities get slightly faster pulse
	var pulse_speed: float = 1.0 + float(highest_rarity) * 0.25

	_frame_material.set_shader_parameter("glow_color", glow_color)
	_frame_material.set_shader_parameter("glow_intensity", intensity)
	_frame_material.set_shader_parameter("pulse_speed", pulse_speed)

func _get_item_rarity(item) -> int:
	"""Extract rarity int from an item (EquippableItem or legacy Dictionary)."""
	if item is EquippableItem:
		return item.rarity
	elif item is Dictionary:
		# Legacy fallback
		var rarity_str = item.get("rarity", "Common")
		match rarity_str:
			"Common": return EquippableItem.Rarity.COMMON
			"Uncommon": return EquippableItem.Rarity.UNCOMMON
			"Rare": return EquippableItem.Rarity.RARE
			"Epic": return EquippableItem.Rarity.EPIC
			"Legendary": return EquippableItem.Rarity.LEGENDARY
	return EquippableItem.Rarity.COMMON
# ============================================================================
# STATUS ICONS
# ============================================================================

func _update_status_icons():
	"""Refresh status effect icons from player state."""
	if not status_container or not player:
		return

	# Clear existing icons
	for child in status_container.get_children():
		child.queue_free()

	# Collect active status effects
	var active_effects: Array[Dictionary] = _get_active_effects()

	# Create icons (capped at max)
	var count: int = mini(active_effects.size(), max_status_icons)
	for i in count:
		var effect = active_effects[i]
		var icon_rect = _create_status_icon(effect)
		status_container.add_child(icon_rect)

func _get_active_effects() -> Array[Dictionary]:
	"""Collect active status effects from player's StatusTracker."""
	var effects: Array[Dictionary] = []

	if not player or not player.status_tracker:
		return effects

	var active_statuses = player.status_tracker.get_all_active()
	for instance in active_statuses:
		var status_affix: StatusAffix = instance.get("status_affix")
		var stacks: int = instance.get("current_stacks", 0)
		var remaining_turns: int = instance.get("remaining_turns", -1)
		var status_id: String = status_affix.status_id if status_affix else "unknown"

		if stacks > 0:
			effects.append({
				"name": status_id,
				"stacks": stacks,
				"turns": remaining_turns,
				"status_affix": status_affix,
			})

	return effects


func _create_status_icon(effect: Dictionary) -> TextureRect:
	"""Create a single status effect icon."""
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = status_icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var status_name: String = effect.get("name", "")
	var stacks: int = effect.get("stacks", 0)
	var turns: int = effect.get("turns", -1)
	var status_affix: StatusAffix = effect.get("status_affix")

	# Build tooltip
	var tooltip: String = status_name.capitalize()
	if stacks > 1:
		tooltip += " x%d" % stacks
	if turns > 0:
		tooltip += " (%d turns)" % turns
	icon_rect.tooltip_text = tooltip

	# Use icon from StatusAffix resource if available
	if status_affix and status_affix.icon:
		icon_rect.texture = status_affix.icon
	else:
		# Fallback: try file path
		var icon_path = "res://assets/icons/status/%s.png" % status_name
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		else:
			# Fallback: colored placeholder
			icon_rect.modulate = _get_status_color(status_name)
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			icon_rect.texture = ImageTexture.create_from_image(img)

	return icon_rect



func _get_status_color(effect_name: String) -> Color:
	"""Get a representative color for a status effect."""
	match effect_name:
		"poison": return Color(0.4, 0.85, 0.25)
		"burn": return Color(1.0, 0.4, 0.1)
		"bleed": return Color(0.8, 0.1, 0.1)
		"chill": return Color(0.5, 0.8, 1.0)
		"stunned": return Color(1.0, 1.0, 0.2)
		"slowed": return Color(0.4, 0.4, 0.8)
		"corrode": return Color(0.6, 0.5, 0.1)
		"shadow": return Color(0.3, 0.1, 0.4)
		"block": return Color(0.6, 0.6, 0.6)
		"dodge": return Color(0.2, 0.9, 0.6)
		"overhealth": return Color(0.9, 0.9, 0.2)
		"expose": return Color(1.0, 0.5, 0.5)
		"enfeeble": return Color(0.5, 0.3, 0.5)
		"ignition": return Color(1.0, 0.6, 0.0)
		_: return Color.WHITE

# ============================================================================
# LEVEL BADGE
# ============================================================================

func _update_level_badge():
	"""Update level badge text from player class."""
	if not level_badge_label or not player:
		return

	if player.active_class:
		level_badge_label.text = "Lv.%d" % player.active_class.level
	else:
		level_badge_label.text = "Lv.1"

# ============================================================================
# KO STATE
# ============================================================================

func _update_ko_state():
	"""Check if player is KO'd and update grayscale."""
	if not player:
		return
	set_ko(player.current_hp <= 0)

# ============================================================================
# INPUT
# ============================================================================

func _on_gui_input(event: InputEvent):
	"""Handle click on portrait to open character sheet."""
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		portrait_clicked.emit()
		accept_event()

# ============================================================================
# PLAYER SIGNAL CONNECTIONS
# ============================================================================

func _connect_player_signals():
	"""Connect to player signals for live updates."""
	if player.has_signal("equipment_changed"):
		if not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)

	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)

	if player.has_signal("class_changed"):
		if not player.class_changed.is_connected(_on_class_changed):
			player.class_changed.connect(_on_class_changed)

	# Status updates via the parameterless status_changed signal
	if player.has_signal("status_changed"):
		if not player.status_changed.is_connected(_on_status_changed):
			player.status_changed.connect(_on_status_changed)




func _disconnect_player_signals():
	"""Disconnect from previous player signals."""
	if player.has_signal("equipment_changed") and player.equipment_changed.is_connected(_on_equipment_changed):
		player.equipment_changed.disconnect(_on_equipment_changed)
	if player.has_signal("hp_changed") and player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.disconnect(_on_hp_changed)
	if player.has_signal("class_changed") and player.class_changed.is_connected(_on_class_changed):
		player.class_changed.disconnect(_on_class_changed)
	if player.has_signal("status_changed") and player.status_changed.is_connected(_on_status_changed):
		player.status_changed.disconnect(_on_status_changed)



func _on_equipment_changed(_slot: String, _item):
	_update_rarity_glow()

func _on_hp_changed(_current: int, _maximum: int):
	_update_ko_state()

func _on_class_changed(_new_class):
	_update_level_badge()

func _on_status_changed():
	_update_status_icons()
