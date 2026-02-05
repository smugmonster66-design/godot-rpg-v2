# res://scripts/ui/combat/action_field.gd
# Action field - accepts dice drops for combat actions
extends PanelContainer
class_name ActionField

# ============================================================================
# DEBUG TOGGLE - set to false to silence drag/drop debug prints
# ============================================================================
const DEBUG_DROP: bool = true

# ============================================================================
# ENUMS
# ============================================================================
enum ActionType { ATTACK, DEFEND, HEAL, BUFF, DEBUFF, SPECIAL }

# ============================================================================
# EXPORTS
# ============================================================================
@export var action_name: String = "Action"
@export var action_description: String = ""
@export var action_icon: Texture2D = null
@export var action_type: ActionType = ActionType.ATTACK

@export_group("Combat")
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
	# FIX #2: Use recursive version instead of direct-children-only
	_set_children_mouse_pass_recursive(self)
	setup_drop_target()
	create_die_slots()
	refresh_ui()
	_apply_element_shader()
	_update_damage_preview()
	
	if DEBUG_DROP:
		print("🎯 ActionField._ready() complete: '%s'" % action_name)
		print("    mouse_filter = %s" % _mouse_filter_name(mouse_filter))
		print("    die_slots_grid = %s" % ("found" if die_slots_grid else "NULL ⚠️"))
		print("    die_slot_panels.size() = %d" % die_slot_panels.size())
		print("    die_slots (export) = %d" % die_slots)
		_debug_print_mouse_filter_tree(self, "    ")

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
	
	if DEBUG_DROP and not die_slots_grid:
		push_warning("ActionField '%s': DieSlotsGrid NOT FOUND! Die slots cannot be created." % action_name)
		# Try to find anything grid-like as fallback
		var possible = find_child("*Grid*", true, false)
		if possible:
			push_warning("  Found possible alternative: %s (%s)" % [possible.name, possible.get_class()])


func _set_children_mouse_pass_recursive(node: Node):
	"""FIX #2: Recursively set all Control descendants to MOUSE_FILTER_PASS
	so they don't intercept drops intended for the ActionField itself.
	Skips the ActionField root (which needs MOUSE_FILTER_STOP)."""
	for child in node.get_children():
		if child is Control and child != self:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_mouse_pass_recursive(child)


func setup_drop_target():
	mouse_filter = Control.MOUSE_FILTER_STOP
	if DEBUG_DROP:
		print("🎯 ActionField.setup_drop_target(): mouse_filter = STOP")

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
		element = _infer_element_from_effects(action_data)
	
	if action_resource:
		action_resource.reset_charges_for_combat()
	
	if is_node_ready():
		refresh_ui()
		_apply_element_shader()
		_update_damage_preview()

func _infer_element_from_effects(action_data: Dictionary) -> ActionEffect.DamageType:
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
	if description_label:
		description_label.text = action_description
	
	create_die_slots()
	update_charge_display()
	update_disabled_state()
	_update_damage_preview()

# ============================================================================
# DIE SLOTS
# ============================================================================

func create_die_slots():
	if not die_slots_grid:
		if DEBUG_DROP:
			push_warning("ActionField '%s': Cannot create die slots - die_slots_grid is null!" % action_name)
		return
	
	# Clear existing
	for child in die_slots_grid.get_children():
		child.queue_free()
	die_slot_panels.clear()
	
	for i in range(die_slots):
		var slot = Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		# FIX: MOUSE_FILTER_PASS so drops pass through to ActionField
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_setup_empty_slot(slot)
		die_slots_grid.add_child(slot)
		die_slot_panels.append(slot)
	
	if DEBUG_DROP:
		print("🎯 ActionField '%s': Created %d die slot panels" % [action_name, die_slot_panels.size()])

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
# DRAG AND DROP — with full debug instrumentation
# ============================================================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	# =========================================================================
	# DEBUG: This is the critical function. If this never prints, the
	# ActionField is never even being considered as a drop target.
	# Possible causes:
	#   - mouse_filter on this node or an ancestor is IGNORE
	#   - A sibling/overlay Control (like the drag preview) is blocking
	#   - This node is invisible or has zero size
	#   - A ScrollContainer parent is intercepting the drag
	# =========================================================================
	
	if DEBUG_DROP:
		print("=" .repeat(60))
		print("🎯 ActionField._can_drop_data() CALLED on '%s'" % action_name)
		print("    Position: %s" % _pos)
		print("    Data type: %s" % type_string(typeof(data)))
		print("    Data is Dictionary: %s" % (data is Dictionary))
		if data is Dictionary:
			print("    Data keys: %s" % str(data.keys()))
			print("    Data.type = '%s'" % data.get("type", "<missing>"))
			print("    Data.die = %s" % (data.get("die").display_name if data.get("die") else "null"))
		print("    --- Field State ---")
		print("    is_disabled: %s" % is_disabled)
		print("    placed_dice.size(): %d" % placed_dice.size())
		print("    die_slot_panels.size(): %d" % die_slot_panels.size())
		print("    has_charges(): %s" % has_charges())
		print("    mouse_filter: %s" % _mouse_filter_name(mouse_filter))
		print("    visible: %s, size: %s" % [visible, size])
	
	# --- Actual checks with per-check debug ---
	
	if is_disabled:
		if DEBUG_DROP:
			print("    ❌ REJECTED: is_disabled")
		return false
	
	if not data is Dictionary:
		if DEBUG_DROP:
			print("    ❌ REJECTED: data is not Dictionary (type=%s)" % type_string(typeof(data)))
		return false
	
	var data_type = data.get("type", "")
	if data_type != "combat_die" and data_type != "die_slot":
		if DEBUG_DROP:
			print("    ❌ REJECTED: type='%s' (expected 'combat_die' or 'die_slot')" % data_type)
		return false
	
	# FIX #3: Guard against empty die_slot_panels
	if die_slot_panels.size() == 0:
		if DEBUG_DROP:
			print("    ❌ REJECTED: die_slot_panels is EMPTY (slots not created!)")
			print("    💡 Check that DieSlotsGrid node exists in scene and die_slots > 0")
		return false
	
	if placed_dice.size() >= die_slot_panels.size():
		if DEBUG_DROP:
			print("    ❌ REJECTED: slots full (%d/%d)" % [placed_dice.size(), die_slot_panels.size()])
		return false
	
	if not has_charges():
		if DEBUG_DROP:
			print("    ❌ REJECTED: no charges remaining")
		return false
	
	if DEBUG_DROP:
		print("    ✅ ACCEPTED - ready to receive die!")
	
	# Visual feedback: highlight the drop target
	_show_drop_highlight(true)
	
	return true


func _drop_data(_pos: Vector2, data: Variant):
	if DEBUG_DROP:
		print("=" .repeat(60))
		print("🎯 ActionField._drop_data() CALLED on '%s'" % action_name)
	
	_show_drop_highlight(false)
	
	if not data is Dictionary:
		if DEBUG_DROP:
			print("    ❌ data is not Dictionary, aborting")
		return
	
	var die = data.get("die") as DieResource
	var source_obj = data.get("die_object")
	var source_visual = data.get("visual")
	var source_pos = data.get("source_position", global_position) as Vector2
	var source_idx = data.get("slot_index", -1) as int
	
	if DEBUG_DROP:
		print("    die: %s" % (die.display_name if die else "null"))
		print("    source_obj: %s" % (source_obj != null))
		print("    source_visual: %s" % (source_visual != null))
		print("    source_pos: %s" % source_pos)
		print("    source_idx: %d" % source_idx)
	
	# Mark the source die as placed so it knows not to snap back
	if source_obj and source_obj.has_method("mark_as_placed"):
		source_obj.mark_as_placed()
		if DEBUG_DROP:
			print("    ✅ Marked source_obj as placed")
	elif source_visual and source_visual.has_method("mark_as_placed"):
		source_visual.mark_as_placed()
		if DEBUG_DROP:
			print("    ✅ Marked source_visual as placed")
	
	place_die_animated(die, source_pos, source_visual, source_idx)


func _show_drop_highlight(show: bool):
	"""Visual feedback when hovering over valid drop target"""
	if show:
		modulate = Color(1.2, 1.2, 0.9)
	else:
		if not is_disabled:
			modulate = Color.WHITE


# ============================================================================
# DEBUG HELPERS
# ============================================================================

func _mouse_filter_name(mf: int) -> String:
	match mf:
		Control.MOUSE_FILTER_STOP: return "STOP"
		Control.MOUSE_FILTER_PASS: return "PASS"
		Control.MOUSE_FILTER_IGNORE: return "IGNORE"
		_: return "UNKNOWN(%d)" % mf


func _debug_print_mouse_filter_tree(node: Node, indent: String = ""):
	"""Print the mouse_filter of every Control in the tree (for debugging)"""
	if not DEBUG_DROP:
		return
	if node is Control:
		var ctrl = node as Control
		print("%s%s [%s] mouse_filter=%s size=%s visible=%s" % [
			indent,
			ctrl.name,
			ctrl.get_class(),
			_mouse_filter_name(ctrl.mouse_filter),
			ctrl.size,
			ctrl.visible
		])
	for child in node.get_children():
		_debug_print_mouse_filter_tree(child, indent + "  ")


# ============================================================================
# DIE PLACEMENT
# ============================================================================

func place_die_animated(die: DieResource, from_pos: Vector2, source_visual: Control = null, source_idx: int = -1):
	if placed_dice.size() >= die_slot_panels.size():
		if DEBUG_DROP:
			print("    ⚠️ place_die_animated: no slots available!")
		return
	
	placed_dice.append(die)
	dice_source_info.append({
		"visual": source_visual,
		"position": from_pos,
		"slot_index": source_idx
	})
	
	var slot_idx = placed_dice.size() - 1
	var slot = die_slot_panels[slot_idx]
	
	# Clear existing children in slot
	for child in slot.get_children():
		child.queue_free()
	
	var visual = _create_placed_visual(die)
	if visual:
		slot.add_child(visual)
		dice_visuals.append(visual)
		_animate_placement(visual, slot, from_pos)
		if DEBUG_DROP:
			print("    ✅ Die placed in slot %d, visual created" % slot_idx)
	else:
		if DEBUG_DROP:
			print("    ⚠️ Failed to create placed visual for %s" % die.display_name)
	
	update_icon_state()
	_update_damage_preview()
	die_placed.emit(self, die)
	
	if is_ready_to_confirm():
		action_ready.emit(self)
		action_selected.emit(self)

func place_die(die: DieResource):
	place_die_animated(die, global_position, null, -1)

func _create_placed_visual(die: DieResource) -> Control:
	# Try new DieObject system
	if die.has_method("instantiate_combat_visual"):
		var obj = die.instantiate_combat_visual()
		if obj:
			obj.draggable = false
			obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
			obj.set_display_scale(DIE_SCALE)
			obj.position = (SLOT_SIZE - obj.base_size * DIE_SCALE) / 2
			return obj
	
	# Fallback to DieVisual
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
	visual.scale = Vector2(1.3 * DIE_SCALE, 1.3 * DIE_SCALE)
	visual.modulate = Color(1.2, 1.2, 0.9)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector2(DIE_SCALE, DIE_SCALE), snap_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "modulate", Color.WHITE, snap_duration)

# ============================================================================
# STATE QUERIES
# ============================================================================

func is_ready_to_confirm() -> bool:
	return placed_dice.size() > 0

func get_total_dice_value() -> int:
	var total = 0
	for die in placed_dice:
		total += die.get_total_value()
	return total

func calculate_damage() -> int:
	return base_damage + int(get_total_dice_value() * damage_multiplier)

# ============================================================================
# CLEAR / CANCEL
# ============================================================================

func clear_dice():
	"""Clear all placed dice without returning them"""
	placed_dice.clear()
	dice_visuals.clear()
	dice_source_info.clear()
	
	for slot in die_slot_panels:
		for child in slot.get_children():
			child.queue_free()
		_setup_empty_slot(slot)
	
	update_icon_state()
	_update_damage_preview()

func cancel_action():
	"""Return all dice to pool and clear"""
	for i in range(placed_dice.size()):
		var die = placed_dice[i]
		var info = dice_source_info[i] if i < dice_source_info.size() else {}
		var target_pos = info.get("position", Vector2.ZERO) as Vector2
		dice_returned.emit(die, target_pos)
	
	clear_dice()
	action_cancelled.emit(self)
	dice_return_complete.emit()

# ============================================================================
# VISUALS
# ============================================================================

func update_icon_state():
	"""Update icon opacity based on whether dice are placed"""
	if icon_rect:
		icon_rect.modulate.a = 0.3 if placed_dice.size() > 0 else 1.0

func _update_damage_preview():
	if not dmg_preview_label:
		return
	if placed_dice.size() > 0:
		dmg_preview_label.text = str(calculate_damage())
		dmg_preview_label.show()
	else:
		dmg_preview_label.hide()

func _apply_element_shader():
	"""Apply the appropriate element shader to fill/stroke textures"""
	var mat = _get_shader_for_element(element)
	if mat:
		if fill_texture:
			fill_texture.material = mat
		# Optionally also apply to stroke
	# Could also set element color label/border here

func _get_shader_for_element(elem: ActionEffect.DamageType) -> ShaderMaterial:
	match elem:
		ActionEffect.DamageType.SLASHING: return slashing_material
		ActionEffect.DamageType.BLUNT: return blunt_material
		ActionEffect.DamageType.PIERCING: return piercing_material
		ActionEffect.DamageType.FIRE: return fire_material
		ActionEffect.DamageType.ICE: return ice_material
		ActionEffect.DamageType.SHOCK: return shock_material
		ActionEffect.DamageType.POISON: return poison_material
		ActionEffect.DamageType.SHADOW: return shadow_material
		_: return null
