# res://scripts/ui/combat/action_field_preview.gd
# Compact preview of an action - expands to full ActionField when tapped
extends PanelContainer
class_name ActionFieldPreview

# ============================================================================
# SIGNALS
# ============================================================================
signal preview_tapped(action_data: Dictionary, preview: ActionFieldPreview)

# ============================================================================
# NODE REFERENCES
# ============================================================================
var action_name_label: Label = null
var action_type_icon: TextureRect = null
var targets_icon: TextureRect = null
@onready var fill_texture: NinePatchRect = $FillTexture
@onready var stroke_texture: NinePatchRect = $StrokeTexture
@onready var charges_label: Label = $MarginContainer/VBoxContainer/BottomSection/ChargesLabel
@onready var targets_label: Label = $MarginContainer/VBoxContainer/BottomSection/TargetsIcon/TargetsLabel


# ============================================================================
# STATE
# ============================================================================
var action_data: Dictionary = {}
var action_name: String = ""
var action_resource: Action = null
var element: int = ActionEffect.DamageType.SLASHING
var is_disabled: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Make panel transparent - Fill/Stroke textures handle all visuals
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", transparent_style)
	
	_discover_nodes()
	_setup_interaction()
	refresh_ui()
	
	# DIAGNOSTIC: Log configuration after setup
	await get_tree().process_frame
	print("🔍 PREVIEW DIAGNOSTIC for '%s':" % action_name)
	print("  mouse_filter: %s" % mouse_filter)
	print("  size: %s" % size)
	print("  global_pos: %s" % global_position)
	print("  visible: %s" % visible)
	print("  modulate.a: %s" % modulate.a)
	if fill_texture:
		print("  fill_texture.mouse_filter: %s" % fill_texture.mouse_filter)
	if stroke_texture:
		print("  stroke_texture.mouse_filter: %s" % stroke_texture.mouse_filter)

func _discover_nodes():
	action_name_label = find_child("ActionNameLabel", true, false) as Label
	action_type_icon = find_child("ActionTypeIcon", true, false) as TextureRect
	targets_icon = find_child("TargetsIcon", true, false) as TextureRect
	targets_label = find_child("TargetsLabel", true, false) as Label
	# Optional shader nodes (may not exist in preview scene yet)
	fill_texture = find_child("FillTexture", true, false) as NinePatchRect
	stroke_texture = find_child("StrokeTexture", true, false) as NinePatchRect

func _setup_interaction():
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	
	# DEBUG: Check parent chain
	var node = get_parent()
	while node:
		if node is Control:
			print("  🔍 Parent '%s' [%s] mouse_filter=%s" % [
				node.name,
				node.get_class(),
				_mf_name(node.mouse_filter)
			])
		node = node.get_parent()

func _mf_name(mf: int) -> String:
	match mf:
		Control.MOUSE_FILTER_STOP: return "STOP"
		Control.MOUSE_FILTER_PASS: return "PASS"
		Control.MOUSE_FILTER_IGNORE: return "IGNORE"
		_: return "UNKNOWN(%d)" % mf

# ============================================================================
# CONFIGURATION
# ============================================================================

func _apply_element_shader(element: ActionEffect.DamageType, action_resource: Action = null):
	"""Copy shader from ActionField logic"""
	
	print("🎨 APPLYING SHADER to preview '%s':" % action_name)
	print("  element: %s" % element)
	print("  fill_texture exists: %s" % (fill_texture != null))
	print("  stroke_texture exists: %s" % (stroke_texture != null))
	
	# Check if chromatic action (accepts multiple elements)
	var is_chromatic = false
	if action_resource and action_resource.accepted_elements.size() >= 2:
		is_chromatic = true
		#print("  is_chromatic: true (accepted_elements: %s)" % action_resource.accepted_elements)
	
	if not GameManager or not GameManager.ELEMENT_VISUALS:
		print("  ⚠️ No GameManager or ELEMENT_VISUALS")
		if fill_texture:
			fill_texture.modulate = ThemeManager.get_element_color_enum(element) * Color(0.5, 0.5, 0.5)
		return
	
	var config = GameManager.ELEMENT_VISUALS
	print("  ✅ ELEMENT_VISUALS config found")
	
	# Use chromatic shader for multi-element actions
	if is_chromatic:
		if fill_texture:
			var chromatic_fill = load("res://resources/materials/dice/chromatic_fill.tres")
			if chromatic_fill:
				fill_texture.material = chromatic_fill.duplicate()
				fill_texture.modulate = Color(1, 1, 1, 0.5)
			else:
				fill_texture.material = null
				fill_texture.modulate = Color(1, 1, 1, 0.5)
		
		if stroke_texture:
			var chromatic_stroke = load("res://resources/materials/dice/chromatic_stroke.tres")
			if chromatic_stroke:
				stroke_texture.material = chromatic_stroke.duplicate()
			else:
				stroke_texture.material = null
	else:
		# Standard single-element shader
		if fill_texture:
			var fill_mat = config.get_fill_material(element)
			if fill_mat:
				fill_texture.material = fill_mat
				fill_texture.modulate = Color(1, 1, 1, 0.5)
			else:
				fill_texture.material = null
				fill_texture.modulate = config.get_tint_color(element) * Color(0.5, 0.5, 0.5)
		
		if stroke_texture:
			var stroke_mat = config.get_stroke_material(element)
			if stroke_mat:
				stroke_texture.material = stroke_mat
			else:
				stroke_texture.material = null
	# Final diagnostic
	if fill_texture:
		print("  fill_texture.material: %s" % fill_texture.material)
		print("  fill_texture.modulate: %s" % fill_texture.modulate)
	if stroke_texture:
		print("  stroke_texture.material: %s" % stroke_texture.material)

func configure_from_dict(data: Dictionary):
	"""Configure preview from action data (same format as ActionField)"""
	action_data = data
	action_name = data.get("name", "Unknown")
	action_resource = data.get("action_resource", null)
	
	# Element resolution — same priority chain as ActionField:
	# 1. Source item's affix elemental identity
	# 2. Action resource's explicit element
	# 3. Dict "element" key
	# 4. Inferred from first damage effect
	if data.has("source_element"):
		element = data["source_element"] as ActionEffect.DamageType
	elif action_resource and action_resource.get("element") != null:
		element = action_resource.element
	elif data.has("element"):
		element = data.get("element", ActionEffect.DamageType.SLASHING)
	else:
		element = _infer_element_from_effects(data)
	
	# Check if action is disabled (no charges, locked, etc.)
	if action_resource:
		var has_charges = action_resource.has_charges()
		is_disabled = not has_charges
		print("🔍 Preview '%s': has_charges=%s, is_disabled=%s, charge_type=%s" % [
			action_name,
			has_charges,
			is_disabled,
			action_resource.charge_type if "charge_type" in action_resource else "UNKNOWN"
		])
	else:
		print("⚠️ Preview '%s': NO action_resource!" % action_name)
		is_disabled = false  # If no resource, assume enabled
	
	# Ensure nodes are discovered before applying shader
	if not fill_texture:
		_discover_nodes()
	
	# Apply shader
	_apply_element_shader(element, action_resource)
	
	# Refresh UI (includes targets/charges if node is ready)
	refresh_ui()

func _infer_element_from_effects(action_data: Dictionary) -> ActionEffect.DamageType:
	"""Try to infer element from action effects"""
	var effects = action_data.get("effects", [])
	if action_resource and action_resource.effects.size() > 0:
		effects = action_resource.effects
	
	for effect in effects:
		if effect is ActionEffect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
			return effect.damage_type
	
	return ActionEffect.DamageType.SLASHING


# ============================================================================
# UI UPDATES
# ============================================================================


func _update_targets_label(action_resource: Action):
	"""Update targets label based on targeting mode"""
	if not targets_label or not action_resource:
		if targets_label:
			targets_label.text = "1"
		return
	
	var mode = action_resource.get_targeting_mode()
	var target_count = 1
	
	match mode:
		TargetingMode.Mode.SINGLE_ENEMY, \
		TargetingMode.Mode.SINGLE_ALLY, \
		TargetingMode.Mode.SINGLE_ANY, \
		TargetingMode.Mode.SELF_ONLY:
			target_count = 1
		
		TargetingMode.Mode.SPLASH_ENEMY, \
		TargetingMode.Mode.CHAIN_ENEMY, \
		TargetingMode.Mode.PIERCE_ENEMY:
			target_count = 2  # Primary + secondary targets
		
		TargetingMode.Mode.ALL_ENEMIES, \
		TargetingMode.Mode.ALL_ALLIES:
			target_count = 3  # AOE
		
		_:
			target_count = 1
	
	targets_label.text = str(target_count)
	
func _update_charges_label(action_resource: Action):
	"""Update charges label: 'X/Y per Turn' or 'X/Y per Combat'"""
	if not charges_label or not action_resource:
		if charges_label:
			charges_label.visible = false
		return
	
	match action_resource.charge_type:
		Action.ChargeType.UNLIMITED:
			charges_label.visible = false
		
		Action.ChargeType.LIMITED_PER_TURN:
			charges_label.text = "%d/%d\nper Turn" % [action_resource.current_charges, action_resource.max_charges]
			charges_label.visible = true
		
		Action.ChargeType.LIMITED_PER_COMBAT:
			charges_label.text = "%d/%d\nper Combat" % [action_resource.current_charges, action_resource.max_charges]
			charges_label.visible = true

func refresh_ui():
	if not is_node_ready():
		return
	
	_update_name()
	_update_icon()
	_update_targets()
	# Don't apply element styling to panel - shaders handle it
	_update_disabled_state()
	
	# Update dynamic labels
	_update_targets_label(action_resource)
	_update_charges_label(action_resource)

func _update_name():
	if action_name_label:
		action_name_label.text = action_name

func _update_icon():
	if not action_type_icon:
		return
	
	# Use action's icon if available, else fall back to type icon
	var icon: Texture2D = null
	
	if action_resource and action_resource.icon:
		icon = action_resource.icon
	elif action_data.has("icon") and action_data.icon:
		icon = action_data.icon
	else:
		# Fallback to action type icon (attack, heal, etc.)
		icon = _get_type_icon()
	
	action_type_icon.texture = icon

func _update_targets():
	if not targets_label:
		return
	
	# Get targeting mode from action resource
	var target_count = 1
	if action_resource:
		var mode = action_resource.get_targeting_mode()
		match mode:
			TargetingMode.Mode.SINGLE_ENEMY:
				target_count = 1
			TargetingMode.Mode.ALL_ENEMIES:
				target_count = 3  # Max enemies
			TargetingMode.Mode.SELF_ONLY:
				target_count = 0  # Self target (maybe show different icon)
			_:
				target_count = 1
	
	targets_label.text = str(target_count)
	
	# Hide targets section if self-only
	if targets_icon:
		targets_icon.visible = (target_count > 0)




func _update_disabled_state():
	if is_disabled:
		print("  🔒 Preview '%s' DISABLED - greying out" % action_name)
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		print("  ✅ Preview '%s' ENABLED - interactive" % action_name)
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================================
# INTERACTION
# ============================================================================

func _on_gui_input(event: InputEvent):
	print("🖱️ PREVIEW GUI INPUT: %s for '%s'" % [event, action_name])
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("  ✅ LEFT CLICK DETECTED")
		if is_disabled:
			print("⚠️ Preview '%s' click IGNORED: disabled" % action_name)
			return
		
		# Check if we're in the action phase (only time previews should be clickable)
		var combat_ui = get_tree().get_first_node_in_group("combat_ui")
		if combat_ui:
			# Don't allow clicks during enemy turn or prep phase
			if combat_ui.is_enemy_turn:
				print("⚠️ Preview '%s' click IGNORED: enemy turn" % action_name)
				return
			if combat_ui._refreshing_action_fields:
				print("⚠️ Preview '%s' click IGNORED: fields refreshing" % action_name)
				return
		
		_on_tapped()

func _on_tapped():
	"""Emit signal to expand this preview"""
	preview_tapped.emit(action_data, self)

# ============================================================================
# HELPERS
# ============================================================================

func _get_type_icon() -> Texture2D:
	"""Fallback icon based on action type"""
	# You can expand this to map action types to specific icons
	var action_type = action_data.get("action_type", 0)
	
	# For now, return the default attack icon
	# You could load different icons based on type:
	# match action_type:
	#     ActionField.ActionType.ATTACK:
	#         return load("res://assets/ui/icons/actionfields/attack_icon.png")
	#     ActionField.ActionType.HEAL:
	#         return load("res://assets/ui/icons/actionfields/heal_icon.png")
	#     ...
	
	return load("res://assets/ui/icons/actionfields/attack_icon.png")

func get_center_position() -> Vector2:
	"""Return global center position for expansion animation"""
	return global_position + (size / 2)
