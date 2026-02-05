# res://scripts/ui/combat/action_field.gd
# Action field with icon, die slots, element-based styling, and damage preview
# Updated to use CombatDieObject for placed dice
extends PanelContainer
class_name ActionField

# ============================================================================
# ENUMS
# ============================================================================
enum ActionType {
	ATTACK,
	DEFEND,
	HEAL,
	SPECIAL
}

# ============================================================================
# EXPORTS
# ============================================================================
@export var action_type: ActionType = ActionType.ATTACK
@export var action_name: String = "Action"
@export var action_icon: Texture2D = null
@export_multiline var action_description: String = "Does something."

@export var die_slots: int = 1
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var required_tags: Array = []
@export var restricted_tags: Array = []

@export_group("Element")
## Primary element/damage type of this action
@export var element: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

@export_group("Element Shaders")
## Shader materials for each element type - assign in inspector
@export var slashing_material: ShaderMaterial
@export var blunt_material: ShaderMaterial
@export var piercing_material: ShaderMaterial
@export var fire_material: ShaderMaterial
@export var ice_material: ShaderMaterial
@export var shock_material: ShaderMaterial
@export var poison_material: ShaderMaterial
@export var shadow_material: ShaderMaterial

@export_group("Animation")
@export var snap_duration: float = 0.25
@export var return_duration: float = 0.3

# Source tracking
var source: String = ""
var action_resource: Action = null

# ============================================================================
# SIGNALS
# ============================================================================
signal action_selected(field: ActionField)
signal action_confirmed(action_data: Dictionary)
signal action_ready(action_field: ActionField)
signal action_cancelled(action_field: ActionField)
signal die_placed(action_field: ActionField, die: DieResource)
signal die_removed(action_field: ActionField, die: DieResource)
signal dice_returned(die: DieResource, target_position: Vector2)
signal dice_return_complete()

# ============================================================================
# NODE REFERENCES
# ============================================================================
var name_label: Label = null
var charge_label: Label = null
var icon_container: PanelContainer = null
var icon_rect: TextureRect = null
var die_slots_grid: GridContainer = null
var description_label: RichTextLabel = null
var dmg_preview_label: Label = null
var fill_texture: NinePatchRect = null
var stroke_texture: NinePatchRect = null
var mult_label: Label = null
var element_icon: TextureRect = null

# ============================================================================
# STATE
# ============================================================================
var placed_dice: Array[DieResource] = []
var dice_visuals: Array[Control] = []
var die_slot_panels: Array[Panel] = []
var is_disabled: bool = false
var dice_source_info: Array[Dictionary] = []

const SLOT_SIZE = Vector2(62, 62)
const DIE_SCALE = 0.5

# ============================================================================
# ELEMENT COLORS (for fallback/labels)
# ============================================================================
const ELEMENT_COLORS = {
	ActionEffect.DamageType.SLASHING: Color(0.8, 0.8, 0.8),
	ActionEffect.DamageType.BLUNT: Color(0.6, 0.5, 0.4),
	ActionEffect.DamageType.PIERCING: Color(0.9, 0.9, 0.7),
	ActionEffect.DamageType.FIRE: Color(1.0, 0.4, 0.2),
	ActionEffect.DamageType.ICE: Color(0.4, 0.8, 1.0),
	ActionEffect.DamageType.SHOCK: Color(1.0, 1.0, 0.3),
	ActionEffect.DamageType.POISON: Color(0.4, 0.9, 0.3),
	ActionEffect.DamageType.SHADOW: Color(0.5, 0.3, 0.7),
}

const ELEMENT_NAMES = {
	ActionEffect.DamageType.SLASHING: "Slashing",
	ActionEffect.DamageType.BLUNT: "Blunt",
	ActionEffect.DamageType.PIERCING: "Piercing",
	ActionEffect.DamageType.FIRE: "Fire",
	ActionEffect.DamageType.ICE: "Ice",
	ActionEffect.DamageType.SHOCK: "Shock",
	ActionEffect.DamageType.POISON: "Poison",
	ActionEffect.DamageType.SHADOW: "Shadow",
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_set_children_mouse_pass()
	setup_drop_target()
	create_die_slots()
	refresh_ui()
	_apply_element_shader()
	_update_damage_preview()

func _discover_nodes():
	name_label = find_child("NameLabel", true, false) as Label
	charge_label = find_child("ChargeLabel", true, false) as Label
	icon_container = find_child("IconContainer", true, false) as PanelContainer
	icon_rect = find_child("IconRect", true, false) as TextureRect
	die_slots_grid = find_child("DieSlotsGrid", true, false) as GridContainer
	description_label = find_child("DescriptionLabel", true, false) as RichTextLabel
	dmg_preview_label = find_child("DmgPreviewLabel", true, false) as Label
	fill_texture = find_child("FillTexture", true, false) as NinePatchRect
	stroke_texture = find_child("StrokeTexture", true, false) as NinePatchRect
	mult_label = find_child("MultLabel", true, false) as Label
	element_icon = find_child("ElementIcon", true, false) as TextureRect

func _set_children_mouse_pass():
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

func setup_drop_target():
	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================================
# ELEMENT SHADER
# ============================================================================

func _apply_element_shader():
	"""Apply the appropriate shader material based on element type"""
	var material = _get_element_material(element)
	
	if fill_texture and material:
		fill_texture.material = material.duplicate()
	
	# Optionally tint if no shader available
	if fill_texture and not material:
		fill_texture.modulate = ELEMENT_COLORS.get(element, Color.WHITE)

func _get_element_material(elem: ActionEffect.DamageType) -> ShaderMaterial:
	"""Get the shader material for an element type"""
	match elem:
		ActionEffect.DamageType.SLASHING:
			return slashing_material
		ActionEffect.DamageType.BLUNT:
			return blunt_material
		ActionEffect.DamageType.PIERCING:
			return piercing_material
		ActionEffect.DamageType.FIRE:
			return fire_material
		ActionEffect.DamageType.ICE:
			return ice_material
		ActionEffect.DamageType.SHOCK:
			return shock_material
		ActionEffect.DamageType.POISON:
			return poison_material
		ActionEffect.DamageType.SHADOW:
			return shadow_material
		_:
			return null

func set_element(new_element: ActionEffect.DamageType):
	"""Change the element and update visuals"""
	element = new_element
	if element_icon:
		element_icon.modulate = ELEMENT_COLORS.get(element, Color.WHITE)
		element_icon.tooltip_text = ELEMENT_NAMES.get(element, "")
	_apply_element_shader()
	_update_damage_preview()

# ============================================================================
# DAMAGE PREVIEW
# ============================================================================

func _update_damage_preview():
	"""Update the damage preview label based on placed dice state"""
	if not dmg_preview_label:
		return
	
	# Non-damage actions show different text
	if action_type == ActionType.DEFEND:
		dmg_preview_label.text = "Defense"
		return
	elif action_type == ActionType.HEAL:
		_update_heal_preview()
		return
	elif action_type == ActionType.SPECIAL:
		dmg_preview_label.text = "Special"
		return
	
	var element_name = ELEMENT_NAMES.get(element, "")
	var element_color = ELEMENT_COLORS.get(element, Color.WHITE)
	
	if placed_dice.size() == 0:
		# Show formula: "2D+10 Fire"
		dmg_preview_label.text = _get_damage_formula()
	else:
		# Show calculated damage: "→ 28 Fire"
		var total_damage = _calculate_preview_damage()
		dmg_preview_label.text = "→ %d %s" % [total_damage, element_name]
	
	# Tint label with element color
	dmg_preview_label.add_theme_color_override("font_color", element_color)

func _update_heal_preview():
	"""Update preview for heal actions"""
	if placed_dice.size() == 0:
		dmg_preview_label.text = _get_heal_formula()
	else:
		var total_heal = _calculate_preview_heal()
		dmg_preview_label.text = "→ %d HP" % total_heal
	
	dmg_preview_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

func _get_damage_formula() -> String:
	"""Get the damage formula string (e.g., '2D+10 Fire')"""
	var parts: Array[String] = []
	var element_name = ELEMENT_NAMES.get(element, "")
	
	# Dice component
	if die_slots > 0:
		parts.append("%dD" % die_slots)
	
	# Base damage component
	if base_damage > 0:
		if parts.size() > 0:
			parts.append("+%d" % base_damage)
		else:
			parts.append(str(base_damage))
	elif parts.size() == 0:
		parts.append("0")
	
	var formula = "".join(parts)
	
	# Element name
	if element_name:
		formula += " %s" % element_name
	
	return formula

func _get_heal_formula() -> String:
	"""Get the heal formula string"""
	var parts: Array[String] = []
	
	if die_slots > 0:
		parts.append("%dD" % die_slots)
	
	if base_damage > 0:  # Using base_damage for heal amount
		if parts.size() > 0:
			parts.append("+%d" % base_damage)
		else:
			parts.append(str(base_damage))
	
	if parts.size() == 0:
		return "Heal"
	
	var formula = "".join(parts)
	return formula + " HP"

func _calculate_preview_damage() -> int:
	"""Calculate damage with currently placed dice"""
	var dice_total = get_total_dice_value()
	var raw_damage = (dice_total + base_damage) * damage_multiplier
	return int(raw_damage)

func _calculate_preview_heal() -> int:
	"""Calculate heal with currently placed dice"""
	var dice_total = get_total_dice_value()
	var raw_heal = (dice_total + base_damage) * damage_multiplier
	return int(raw_heal)

func get_total_dice_value() -> int:
	"""Get sum of all placed dice values"""
	var total = 0
	for die in placed_dice:
		if die:
			total += die.get_total_value()
	return total

# ============================================================================
# CONFIGURATION
# ============================================================================

func configure_from_dict(action_data: Dictionary):
	action_name = action_data.get("name", "Action")
	action_description = action_data.get("description", "")
	action_icon = action_data.get("icon", null)
	action_type = action_data.get("action_type", ActionType.ATTACK)
	die_slots = action_data.get("die_slots", 1)
	base_damage = action_data.get("base_damage", 0)
	damage_multiplier = action_data.get("damage_multiplier", 1.0)
	required_tags = action_data.get("required_tags", [])
	restricted_tags = action_data.get("restricted_tags", [])
	source = action_data.get("source", "")
	action_resource = action_data.get("action_resource", null)
	
	# Get element from action_resource or action_data
	if action_resource and action_resource.get("element") != null:
		element = action_resource.element
	elif action_data.has("element"):
		element = action_data.get("element", ActionEffect.DamageType.SLASHING)
	else:
		# Try to infer from first damage effect
		element = _infer_element_from_effects(action_data)
	
	if action_resource:
		action_resource.reset_charges_for_combat()
	
	if is_node_ready():
		refresh_ui()
		_apply_element_shader()
		_update_damage_preview()

func _infer_element_from_effects(action_data: Dictionary) -> ActionEffect.DamageType:
	"""Try to infer element from action effects"""
	var effects = action_data.get("effects", [])
	if action_resource and action_resource.effects.size() > 0:
		effects = action_resource.effects
	
	for effect in effects:
		if effect is ActionEffect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
			return effect.damage_type
	
	return ActionEffect.DamageType.SLASHING

func refresh_ui():
	if name_label:
		name_label.text = action_name
	if icon_rect:
		icon_rect.texture = action_icon
	if element_icon:
		element_icon.modulate = ELEMENT_COLORS.get(element, Color.WHITE)
		element_icon.tooltip_text = ELEMENT_NAMES.get(element, "")
	if mult_label:
		if damage_multiplier != 1.0:
			mult_label.text = "×%.1f" % damage_multiplier
			mult_label.show()
		else:
			mult_label.hide()
	
	create_die_slots()
	update_charge_display()
	update_disabled_state()
	_update_damage_preview()

# ============================================================================
# DIE SLOTS
# ============================================================================

func create_die_slots():
	if not die_slots_grid:
		return
	
	for child in die_slots_grid.get_children():
		child.queue_free()
	die_slot_panels.clear()
	
	for i in range(die_slots):
		var slot = Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_setup_empty_slot(slot)
		die_slots_grid.add_child(slot)
		die_slot_panels.append(slot)

func _setup_empty_slot(slot: Panel):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

# ============================================================================
# CHARGE SYSTEM
# ============================================================================

func has_charges() -> bool:
	if action_resource:
		return action_resource.has_charges()
	return true

func consume_charge():
	if action_resource:
		action_resource.consume_charge()
	update_charge_display()

func update_charge_display():
	if not charge_label:
		return
	
	if action_resource and action_resource.charge_type != Action.ChargeType.UNLIMITED:
		charge_label.text = "%d/%d" % [action_resource.current_charges, action_resource.max_charges]
		charge_label.show()
	else:
		charge_label.hide()

func update_disabled_state():
	is_disabled = not has_charges()
	if is_disabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
	update_icon_state()

func refresh_charge_state():
	update_charge_display()
	update_disabled_state()

# ============================================================================
# DRAG AND DROP
# ============================================================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if is_disabled:
		return false
	if not data is Dictionary:
		return false
	if data.get("type") != "combat_die" and data.get("type") != "die_slot":
		return false
	if placed_dice.size() >= die_slot_panels.size():
		return false
	if not has_charges():
		return false
	return true

func _drop_data(_pos: Vector2, data: Variant):
	if not data is Dictionary:
		return
	
	var die = data.get("die") as DieResource
	var source_obj = data.get("die_object")
	var source_visual = data.get("visual")
	var source_pos = data.get("source_position", global_position) as Vector2
	var source_idx = data.get("slot_index", -1) as int
	
	if source_obj and source_obj.has_method("mark_as_placed"):
		source_obj.mark_as_placed()
	elif source_visual and source_visual.has_method("mark_as_placed"):
		source_visual.mark_as_placed()
	
	place_die_animated(die, source_pos, source_visual, source_idx)

# ============================================================================
# DIE PLACEMENT
# ============================================================================

func place_die_animated(die: DieResource, from_pos: Vector2, source_visual: Control = null, source_idx: int = -1):
	if placed_dice.size() >= die_slot_panels.size():
		return
	
	placed_dice.append(die)
	dice_source_info.append({
		"visual": source_visual,
		"position": from_pos,
		"slot_index": source_idx
	})
	
	var slot_idx = placed_dice.size() - 1
	var slot = die_slot_panels[slot_idx]
	
	for child in slot.get_children():
		child.queue_free()
	
	var visual = _create_placed_visual(die)
	if visual:
		print_debug("=== PRE ADD_CHILD ===")
		print_debug("  visual type: ", visual.get_class(), " script: ", visual.get_script())
		print_debug("  visual size: ", visual.size)
		print_debug("  visual min_size: ", visual.custom_minimum_size)
		print_debug("  visual scale: ", visual.scale)
		print_debug("  slot size: ", slot.size)
		print_debug("  slot min_size: ", slot.custom_minimum_size)
		
		slot.add_child(visual)
		
		print_debug("=== POST ADD_CHILD (before fit) ===")
		print_debug("  visual size: ", visual.size)
		print_debug("  visual min_size: ", visual.custom_minimum_size)
		print_debug("  visual position: ", visual.position)
		print_debug("  visual scale: ", visual.scale)
		print_debug("  visual anchors: L=", visual.anchor_left, " T=", visual.anchor_top, " R=", visual.anchor_right, " B=", visual.anchor_bottom)
		print_debug("  visual offsets: L=", visual.offset_left, " T=", visual.offset_top, " R=", visual.offset_right, " B=", visual.offset_bottom)
		print_debug("  visual layout_mode: ", visual.get("layout_mode"))
		print_debug("  slot size now: ", slot.size)
		
		_fit_visual_to_slot(visual)
		
		print_debug("=== POST FIT ===")
		print_debug("  visual size: ", visual.size)
		print_debug("  visual min_size: ", visual.custom_minimum_size)
		print_debug("  visual position: ", visual.position)
		print_debug("  visual scale: ", visual.scale)
		print_debug("  visual anchors: L=", visual.anchor_left, " T=", visual.anchor_top, " R=", visual.anchor_right, " B=", visual.anchor_bottom)
		print_debug("  visual pivot: ", visual.pivot_offset)
		print_debug("  slot size now: ", slot.size)
		
		visual.ready.connect(func():
			print_debug("=== VISUAL _READY FIRED ===")
			print_debug("  visual size: ", visual.size)
			print_debug("  visual min_size: ", visual.custom_minimum_size)
			print_debug("  visual position: ", visual.position)
			print_debug("  visual scale: ", visual.scale)
			print_debug("  visual anchors: L=", visual.anchor_left, " T=", visual.anchor_top, " R=", visual.anchor_right, " B=", visual.anchor_bottom)
		, CONNECT_ONE_SHOT)
		
		get_tree().process_frame.connect(func():
			if is_instance_valid(visual) and is_instance_valid(slot):
				print_debug("=== NEXT FRAME ===")
				print_debug("  visual size: ", visual.size)
				print_debug("  visual min_size: ", visual.custom_minimum_size)
				print_debug("  visual position: ", visual.position)
				print_debug("  visual scale: ", visual.scale)
				print_debug("  slot size: ", slot.size)
		, CONNECT_ONE_SHOT)
		
		dice_visuals.append(visual)
		_animate_placement(visual, slot, from_pos)
	
	update_icon_state()
	_update_damage_preview()
	die_placed.emit(self, die)
	
	if is_ready_to_confirm():
		action_ready.emit(self)
		action_selected.emit(self)



func place_die(die: DieResource):
	place_die_animated(die, global_position, null, -1)

func _create_placed_visual(die: DieResource) -> Control:
	# Try to use new DieObject system
	if die.has_method("instantiate_combat_visual"):
		var obj = die.instantiate_combat_visual()
		if obj:
			obj.draggable = false
			obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
			#obj.custom_minimum_size = Vector2.ZERO
			#obj.set_display_scale(DIE_SCALE)
			#obj.position = (SLOT_SIZE - obj.base_size) / 2
			return obj
	
	# Fallback to old DieVisual if available
	var die_visual_scene = load("res://scenes/ui/components/die_visual.tscn")
	if die_visual_scene:
		var visual = die_visual_scene.instantiate()
		if visual.has_method("set_die"):
			visual.set_die(die)
		visual.can_drag = false
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.scale = Vector2(DIE_SCALE, DIE_SCALE)
		return visual
	
	# Final fallback
	var lbl = Label.new()
	lbl.text = str(die.get_total_value())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	return lbl


func _animate_placement(visual: Control, _slot: Panel, _from_pos: Vector2):
	# Pop animation using scale from center pivot
	visual.scale = Vector2(1.3, 1.3)
	visual.modulate = Color(1.2, 1.2, 0.9)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector2.ONE, snap_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "modulate", Color.WHITE, snap_duration)




func _fit_visual_to_slot(visual: Control):
	"""Force die visual to match slot size exactly"""
	var die_size: Vector2 = visual.base_size if "base_size" in visual else Vector2(124, 124)
	var fit_scale: float = min(SLOT_SIZE.x / die_size.x, SLOT_SIZE.y / die_size.y)
	
	# Tell layout system this control is slot-sized
	visual.custom_minimum_size = SLOT_SIZE
	visual.size = SLOT_SIZE
	
	# Break out of anchor-based layout
	visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	visual.set_anchor(SIDE_LEFT, 0)
	visual.set_anchor(SIDE_TOP, 0)
	visual.set_anchor(SIDE_RIGHT, 0)
	visual.set_anchor(SIDE_BOTTOM, 0)
	
	# Sit at origin of slot, no offset needed
	visual.position = Vector2.ZERO
	
	# No scale — children with FULL_RECT anchors will resize to slot size naturally
	visual.scale = Vector2.ONE
	visual.pivot_offset = SLOT_SIZE / 2
	
	# Scale down the value label to match the slot ratio
	var value_label = visual.find_child("ValueLabel", true, false) as Label
	if value_label:
		var original_font_size = value_label.get_theme_font_size("font_size")
		value_label.add_theme_font_size_override("font_size", int(original_font_size * fit_scale))
		
		var original_outline = value_label.get_theme_constant("outline_size")
		value_label.add_theme_constant_override("outline_size", int(original_outline * fit_scale))
		
		# Scale the label's offsets to match
		value_label.offset_left *= fit_scale
		value_label.offset_top *= fit_scale
		value_label.offset_right *= fit_scale
		value_label.offset_bottom *= fit_scale





func is_ready_to_confirm() -> bool:
	return placed_dice.size() >= die_slots and placed_dice.size() > 0

# ============================================================================
# UI UPDATES
# ============================================================================

func update_icon_state():
	if not icon_rect:
		return
	if is_disabled:
		icon_rect.modulate = Color(0.3, 0.3, 0.3)
	elif placed_dice.size() > 0:
		icon_rect.modulate = Color(0.5, 0.5, 0.5)
	else:
		icon_rect.modulate = Color.WHITE

func _gui_input(event: InputEvent):
	if is_disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_ready_to_confirm():
			action_selected.emit(self)

# ============================================================================
# CANCEL / CLEAR
# ============================================================================

func cancel_action():
	for i in range(placed_dice.size()):
		var die = placed_dice[i]
		var info = dice_source_info[i] if i < dice_source_info.size() else {}
		var target_pos = info.get("position", Vector2.ZERO)
		dice_returned.emit(die, target_pos)
	
	_clear_placed_dice()
	action_cancelled.emit(self)
	dice_return_complete.emit()

func _clear_placed_dice():
	for obj in dice_visuals:
		if is_instance_valid(obj):
			obj.queue_free()
	dice_visuals.clear()
	placed_dice.clear()
	dice_source_info.clear()
	
	for slot in die_slot_panels:
		_setup_empty_slot(slot)
	
	update_icon_state()
	_update_damage_preview()

func consume_dice():
	_clear_placed_dice()
	update_icon_state()

func clear_dice():
	"""Alias for consume_dice - clears placed dice from slots"""
	_clear_placed_dice()
	update_icon_state()

func reset_charges():
	if action_resource:
		action_resource.reset_charges_for_combat()
	refresh_charge_state()

# ============================================================================
# ACTION DATA
# ============================================================================

func get_action_data() -> Dictionary:
	return {
		"name": action_name,
		"action_type": action_type,
		"element": element,
		"base_damage": base_damage,
		"damage_multiplier": damage_multiplier,
		"placed_dice": placed_dice,
		"total_value": get_total_dice_value(),
		"source": source,
		"action_resource": action_resource
	}
