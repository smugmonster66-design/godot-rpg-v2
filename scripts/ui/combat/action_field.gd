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

@export_group("Animation")
@export var snap_duration: float = 0.25
@export var return_duration: float = 0.3

# Source tracking
var source: String = ""
var action_resource: Action = null

@export_group("Rarity Glow")
@export var badge_glow_config: RarityGlowConfig

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
var dmg_preview_label: RichTextLabel = null
var fill_texture: NinePatchRect = null
var stroke_texture: NinePatchRect = null
var mult_label: Label = null
var source_badge: TextureRect = null
var damage_floater: DamagePreviewFloater = null
# Chromatic (multi-element) shader support
var _chromatic_fill_material: ShaderMaterial = null
var _chromatic_stroke_material: ShaderMaterial = null
var _is_chromatic_action: bool = false
@export var _chromatic_stroke_enabled: bool = true
## Per-element stroke shader toggle. Missing keys default to true.
@export var _element_stroke_overrides: Dictionary = {}
# Example: { ActionEffect.DamageType.FIRE: false } disables fire stroke only
var damage_formula_label: RichTextLabel = null
var charge_container: PanelContainer = null
var charge_rich_label: RichTextLabel = null


# ============================================================================
# STATE
# ============================================================================
var placed_dice: Array[DieResource] = []
var dice_visuals: Array[Control] = []
var die_slot_panels: Array[Panel] = []
var is_disabled: bool = false
var dice_source_info: Array[Dictionary] = []
# Source item visual data (for badge display)
var source_icon: Texture2D = null
var source_rarity: String = "Common"
var damage_formula_text: String = ""

const SLOT_SIZE = Vector2(62, 62)
const DIE_SCALE = 0.5

# ============================================================================
# ELEMENT COLORS — resolved via ThemeManager.get_element_color_enum()
# ============================================================================ActionEffect.DamageType.SHADOW: Color(0.5, 0.3, 0.7),


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
	_setup_source_badge()

func _discover_nodes():
	name_label = find_child("NameLabel", true, false) as Label
	charge_label = find_child("ChargeLabel", true, false) as Label
	icon_container = find_child("IconContainer", true, false) as PanelContainer
	icon_rect = find_child("IconRect", true, false) as TextureRect
	die_slots_grid = find_child("DieSlotsGrid", true, false) as GridContainer
	description_label = find_child("DescriptionLabel", true, false) as RichTextLabel
	if description_label:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.fit_content = true
	
	_discover_and_swap_dmg_label()
	
	damage_formula_label = find_child("DamageFormulaLabel", true, false) as RichTextLabel
	if damage_formula_label:
		damage_formula_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		damage_formula_label.fit_content = true
	charge_container = find_child("ChargeContainer", true, false) as PanelContainer
	charge_rich_label = charge_container.find_child("ChargeLabel", true, false) as RichTextLabel if charge_container else null
	fill_texture = find_child("FillTexture", true, false) as NinePatchRect
	stroke_texture = find_child("StrokeTexture", true, false) as NinePatchRect
	mult_label = find_child("MultLabel", true, false) as Label
	source_badge = find_child("SourceBadge", true, false) as TextureRect
	damage_floater = find_child("DamagePreviewFloater", true, false) as DamagePreviewFloater  


func _set_children_mouse_pass():
	_set_mouse_pass_recursive(self)

func _set_mouse_pass_recursive(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_mouse_pass_recursive(child)

func _discover_and_swap_dmg_label():
	"""Find DmgPreviewLabel and swap from Label to RichTextLabel if needed."""
	var found = find_child("DmgPreviewLabel", true, false)
	
	if found is RichTextLabel:
		dmg_preview_label = found as RichTextLabel
		dmg_preview_label.bbcode_enabled = true
		return
	
	if not found is Label:
		push_warning("ActionField: DmgPreviewLabel not found")
		return
	
	var old_label: Label = found as Label
	var parent = old_label.get_parent()
	var idx = old_label.get_index()
	
	var rtl = RichTextLabel.new()
	rtl.name = "DmgPreviewLabel"
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.size_flags_horizontal = old_label.size_flags_horizontal
	rtl.size_flags_vertical = old_label.size_flags_vertical
	rtl.custom_minimum_size = old_label.custom_minimum_size
	
	# Copy font size override if present
	if old_label.has_theme_font_size_override("font_size"):
		rtl.add_theme_font_size_override("normal_font_size",
			old_label.get_theme_font_size("font_size"))
	
	# Outline for readability on dark backgrounds
	rtl.add_theme_constant_override("outline_size", 2)
	rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	
	parent.remove_child(old_label)
	parent.add_child(rtl)
	parent.move_child(rtl, idx)
	old_label.queue_free()
	
	dmg_preview_label = rtl
	dmg_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dmg_preview_label.fit_content = true

func setup_drop_target():
	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================================
# ELEMENT SHADER
# ============================================================================

func _apply_element_shader():
	"""Apply fill + stroke shader materials from central element config.
	Chromatic (multi-element) actions get the prismatic shader instead."""
	
	# Check if this is a chromatic action
	_detect_chromatic()
	
	# If chromatic and no dice placed yet, use the prismatic shader
	if _is_chromatic_action and placed_dice.is_empty():
		_apply_chromatic_shader()
		return
	
	# If chromatic with dice placed, use the placed die's element
	if _is_chromatic_action and not placed_dice.is_empty():
		var die = placed_dice[0] as DieResource
		if die:
			var die_elem = die.get_effective_element()
			if die_elem != DieResource.Element.NONE:
				var dt = DieResource.ELEMENT_TO_DAMAGE_TYPE.get(die_elem, -1)
				if dt >= 0:
					_swap_to_element_shader(dt)
					return
		# Fallback to chromatic if die has no element
		_apply_chromatic_shader()
		return
	
	# Standard single-element behavior (unchanged)
	if not GameManager or not GameManager.ELEMENT_VISUALS:
		if fill_texture:
			fill_texture.modulate = ThemeManager.get_element_color_enum(element) * Color(0.5, 0.5, 0.5)
		return
	
	var config = GameManager.ELEMENT_VISUALS
	
	# Fill material — darkened 50%
	if fill_texture:
		var fill_mat = config.get_fill_material(element)
		if fill_mat:
			fill_texture.material = fill_mat
			fill_texture.modulate = Color(1, 1, 1, 0.5)
		else:
			fill_texture.material = null
			fill_texture.modulate = config.get_tint_color(element) * Color(0.5, 0.5, 0.5)
	
	# Stroke material — full brightness (per-element toggle)
	if stroke_texture:
		if _element_stroke_overrides.get(element, false):
			var stroke_mat = config.get_stroke_material(element)
			if stroke_mat:
				stroke_texture.material = stroke_mat
			else:
				stroke_texture.material = null
		else:
			stroke_texture.material = null

func set_element(new_element: ActionEffect.DamageType):
	"""Change the element and update visuals"""
	element = new_element
	_apply_element_shader()
	_setup_source_badge()
	_update_damage_preview()


# ============================================================================
# CHROMATIC (MULTI-ELEMENT) SHADER SUPPORT
# ============================================================================

func _detect_chromatic():
	"""Check if this action accepts multiple elements (e.g. Chromatic Bolt).
	If so, load the chromatic prismatic shader materials."""
	_is_chromatic_action = false
	
	if not action_resource:
		return
	
	# An action is "chromatic" if it accepts 2+ elements
	if action_resource.accepted_elements.size() >= 2:
		_is_chromatic_action = true
		
		# Lazy-load chromatic materials
		if not _chromatic_fill_material:
			if ResourceLoader.exists("res://resources/materials/dice/chromatic_fill.tres"):
				_chromatic_fill_material = load("res://resources/materials/dice/chromatic_fill.tres").duplicate()
		if not _chromatic_stroke_material:
			if ResourceLoader.exists("res://resources/materials/dice/chromatic_stroke.tres"):
				_chromatic_stroke_material = load("res://resources/materials/dice/chromatic_stroke.tres").duplicate()


func _apply_chromatic_shader():
	"""Apply the prismatic chromatic shader (all three elements blended)."""
	if fill_texture:
		if _chromatic_fill_material:
			fill_texture.material = _chromatic_fill_material
			fill_texture.modulate = Color(1, 1, 1, 0.5) # Darkened like normal element shaders
		else:
			# Fallback: purple-ish tint to signal multi-element
			fill_texture.material = null
			fill_texture.modulate = Color(1, 1, 1, 0.5)
	
	if stroke_texture:
		if _chromatic_stroke_material and _chromatic_stroke_enabled:
			stroke_texture.material = _chromatic_stroke_material
		else:
			stroke_texture.material = null


func _swap_to_element_shader(die_element: int):
	"""Swap the action field shader to match a specific die's element.
	Called when a die is placed into a chromatic action field."""
	if not GameManager or not GameManager.ELEMENT_VISUALS:
		return
	
	var config = GameManager.ELEMENT_VISUALS
	var elem := die_element as ActionEffect.DamageType
	
	if fill_texture:
		var fill_mat = config.get_fill_material(elem)
		if fill_mat:
			fill_texture.material = fill_mat
			fill_texture.modulate = Color(1, 1, 1, 0.5)
		else:
			fill_texture.material = null
			fill_texture.modulate = config.get_tint_color(elem) * Color(0.5, 0.5, 0.5)
	
	if stroke_texture:
		if _element_stroke_overrides.get(elem, false):
			var stroke_mat = config.get_stroke_material(elem)
			if stroke_mat:
				stroke_texture.material = stroke_mat
			else:
				stroke_texture.material = null
		else:
			stroke_texture.material = null


func _restore_chromatic_shader():
	"""Restore the prismatic chromatic shader after dice are removed."""
	if _is_chromatic_action:
		_apply_chromatic_shader()
# ============================================================================
# DAMAGE PREVIEW
# ============================================================================

func _update_damage_preview():
	"""Update damage preview with Balatro-style Power × Mult breakdown."""
	if not dmg_preview_label:
		return
	
	# Non-damage actions
	if action_type == ActionType.DEFEND:
		dmg_preview_label.text = ""
		dmg_preview_label.append_text("[center]Defense[/center]")
		return
	elif action_type == ActionType.HEAL:
		_update_heal_preview()
		return
	elif action_type == ActionType.SPECIAL:
		dmg_preview_label.text = ""
		dmg_preview_label.append_text("[center]Special[/center]")
		return
	
	var element_name: String = ELEMENT_NAMES.get(element, "")
	var element_color: Color = ThemeManager.get_element_color_enum(element)
	var elem_hex: String = element_color.to_html(false)
	
	# Clear previous content
	dmg_preview_label.text = ""
	
	if placed_dice.size() == 0:
		# Formula mode: "2D+5 Fire" in element color
		var formula: String = _get_damage_formula()
		dmg_preview_label.append_text(
			"[center][color=#%s]%s[/color][/center]" % [elem_hex, formula])
	else:
		# breakdown mode
		var power: int = _calculate_preview_power()
		var mult: float = _calculate_preview_mult()
		var total: int = maxi(0, roundi(power * mult))
		
		if mult > 1.001 or mult < 0.999:
			# Full breakdown: "17 × 2.0x = 34 Fire"
			dmg_preview_label.append_text(
				"[center]" +
				"[color=#ffffff]%d[/color]" % power +
				"[color=#888888] × [/color]" +
				"[color=#ff6666]%.1fx[/color]" % mult +
				"[color=#888888] = [/color]" +
				"[color=#%s]%d %s[/color]" % [elem_hex, total, element_name] +
				"[/center]"
			)
		else:
			# No meaningful mult: "→ 17 Fire"
			dmg_preview_label.append_text(
				"[center][color=#%s]→ %d %s[/color][/center]" % [
					elem_hex, total, element_name])
	
	_update_damage_formula_label()
	
	# Update floating element chips (unchanged)
	if damage_floater:
		var attacker_affixes: AffixPoolManager = null
		if GameManager and GameManager.player:
			attacker_affixes = GameManager.player.affix_manager
		damage_floater.update_preview(
			placed_dice, element, base_damage, damage_multiplier,
			action_resource, attacker_affixes
		)

func _update_damage_formula_label():
	"""Update DamageFormulaLabel: shows damage_formula when empty, per-element breakdown with dice."""
	if not damage_formula_label:
		return
	
	damage_formula_label.text = ""
	
	if placed_dice.is_empty():
		# No dice — show the action's static formula text
		if damage_formula_text != "":
			damage_formula_label.append_text("[center]%s[/center]" % damage_formula_text)
			damage_formula_label.show()
		else:
			damage_formula_label.hide()
		return
	
	# Dice placed — compute per-element breakdown and show as rich text
	var damages: Dictionary = _calculate_element_breakdown()
	
	if damages.is_empty():
		damage_formula_label.hide()
		return
	
	# Build "6 Fire + 2 Ice + 1 Shock" string with colored elements
	var parts: Array[String] = []
	for dt_int in DamagePreviewFloater.ELEMENT_ORDER:
		var dt = dt_int as ActionEffect.DamageType
		var value = roundi(damages.get(dt, 0.0))
		if value <= 0:
			continue
		var elem_name = ELEMENT_NAMES.get(dt, "Unknown")
		var elem_color = ThemeManager.get_element_color_enum(dt)
		var hex = elem_color.to_html(false)
		parts.append("[color=#%s]%d %s[/color]" % [hex, value, elem_name])
	
	if parts.is_empty():
		damage_formula_label.hide()
		return
	
	var joined = " [color=#888888]+[/color] ".join(parts)
	damage_formula_label.append_text("[center]%s[/center]" % joined)
	damage_formula_label.show()


func _calculate_element_breakdown() -> Dictionary:
	"""Calculate per-element damage dict using the same logic as DamagePreviewFloater."""
	var damages: Dictionary = {}
	
	if action_resource and not action_resource.effects.is_empty():
		# Use effect-aware calculation
		var dice_index: int = 0
		for effect in action_resource.effects:
			if effect.effect_type != ActionEffect.EffectType.DAMAGE:
				continue
			var effect_element = effect.damage_type
			var effect_damages: Dictionary = {}
			for i in range(effect.dice_count):
				if dice_index >= placed_dice.size():
					break
				var die = placed_dice[dice_index]
				dice_index += 1
				if die is DieResource:
					var die_value = float(die.get_total_value())
					var die_damage_type = die.get_effective_damage_type(effect_element)
					var is_match: bool
					if action_resource.accepted_elements.size() > 0:
						var die_elem = die.get_effective_element()
						is_match = (die_elem != DieResource.Element.NONE
							and die_elem in action_resource.accepted_elements)
					else:
						is_match = die.is_element_match(effect_element)
					if is_match:
						die_value *= CombatCalculator.ELEMENT_MATCH_BONUS
					effect_damages[die_damage_type] = effect_damages.get(die_damage_type, 0.0) + die_value
			if effect.base_damage > 0:
				effect_damages[effect_element] = effect_damages.get(effect_element, 0.0) + float(effect.base_damage)
			if effect.damage_multiplier != 1.0:
				for dt in effect_damages:
					effect_damages[dt] *= effect.damage_multiplier
			for dt in effect_damages:
				damages[dt] = damages.get(dt, 0.0) + effect_damages[dt]
	else:
		# Legacy single-element fallback
		damages = CombatCalculator.calculate_preview_damage(
			placed_dice, element, base_damage, damage_multiplier
		)
	
	# Apply attacker affix bonuses
	if GameManager and GameManager.player:
		var affixes = GameManager.player.affix_manager
		if affixes:
			var primary = element
			if action_resource and not action_resource.effects.is_empty():
				for eff in action_resource.effects:
					if eff.effect_type == ActionEffect.EffectType.DAMAGE:
						primary = eff.damage_type
						break
			# Global flat bonus
			var global_bonus: float = 0.0
			for affix in affixes.get_pool(Affix.Category.DAMAGE_BONUS):
				global_bonus += affix.apply_effect()
			if global_bonus > 0:
				damages[primary] = damages.get(primary, 0.0) + global_bonus
			# Type-specific
			for damage_type in DamagePreviewFloater.TYPE_BONUS_CATEGORIES:
				var cat_name = DamagePreviewFloater.TYPE_BONUS_CATEGORIES[damage_type]
				if cat_name in Affix.Category:
					var cat = Affix.Category.get(cat_name)
					var bonus: float = 0.0
					for affix in affixes.get_pool(cat):
						bonus += affix.apply_effect()
					if bonus > 0:
						damages[damage_type] = damages.get(damage_type, 0.0) + bonus
			# Global multiplier
			var mult: float = 1.0
			for affix in affixes.get_pool(Affix.Category.DAMAGE_MULTIPLIER):
				mult *= affix.apply_effect()
			if action_resource and action_resource.action_id != "":
				mult *= affixes.get_action_damage_multiplier(action_resource.action_id)
			if mult != 1.0:
				for dt in damages:
					damages[dt] *= mult
	
	return damages

func _update_heal_preview():
	"""Update preview for heal actions using RichTextLabel BBCode."""
	if not dmg_preview_label:
		return
	
	var heal_hex: String = ThemeManager.PALETTE.success.to_html(false)
	
	dmg_preview_label.text = ""
	
	if placed_dice.size() == 0:
		var formula: String = _get_heal_formula()
		dmg_preview_label.append_text(
			"[center][color=#%s]%s[/color][/center]" % [heal_hex, formula])
	else:
		var total_heal: int = _calculate_preview_heal()
		dmg_preview_label.append_text(
			"[center][color=#%s]→ %d HP[/color][/center]" % [heal_hex, total_heal])

func _calculate_preview_power() -> int:
	"""Calculate pre-mult power: dice values + element match + base damage + flat bonuses.
	This is the 'Chips' in Balatro terms — everything that gets multiplied."""
	var dice_total: float = 0.0
	
	for die in placed_dice:
		if die is DieResource:
			var die_value: float = float(die.get_total_value())
			
			# Element match bonus is part of power (amplifies the die contribution)
			var is_match: bool = false
			if action_resource and action_resource is Action:
				var accepted: Array[int] = action_resource.accepted_elements
				if accepted.size() > 0:
					var die_elem = die.get_effective_element()
					is_match = (die_elem != DieResource.Element.NONE
						and die_elem in accepted)
				else:
					is_match = die.is_element_match(element)
			else:
				is_match = die.is_element_match(element)
			
			if is_match:
				die_value *= CombatCalculator.ELEMENT_MATCH_BONUS
			
			dice_total += die_value
	
	var power: float = dice_total + float(base_damage)
	
	# Flat damage bonuses from affixes (mirrors CombatCalculator._apply_damage_bonuses)
	if GameManager and GameManager.player:
		var affixes: AffixPoolManager = GameManager.player.affix_manager
		if affixes:
			# Global flat bonus
			for affix in affixes.get_pool(Affix.Category.DAMAGE_BONUS):
				power += affix.apply_effect()
			
			# Type-specific flat bonus
			var type_cat_name: String = DamagePreviewFloater.TYPE_BONUS_CATEGORIES.get(element, "")
			if type_cat_name != "" and type_cat_name in Affix.Category:
				var cat = Affix.Category.get(type_cat_name)
				for affix in affixes.get_pool(cat):
					power += affix.apply_effect()
			
			# Action-scoped flat bonus (v6)
			if action_resource and action_resource is Action:
				var action_flat = affixes.get_action_base_damage_bonus(action_resource.action_id)
				power += action_flat
	
	return maxi(0, roundi(power))



func _calculate_preview_mult() -> float:
	"""Calculate total damage multiplier from action base + affixes.
	This is the 'Mult' in Balatro terms — scales all power."""
	var mult: float = damage_multiplier  # Action's own multiplier
	
	if GameManager and GameManager.player:
		var affixes: AffixPoolManager = GameManager.player.affix_manager
		if affixes:
			# Global damage multiplier affixes
			for affix in affixes.get_pool(Affix.Category.DAMAGE_MULTIPLIER):
				mult *= affix.apply_effect()
			
			# Action-scoped multiplier (v6)
			if action_resource and action_resource is Action:
				var action_mult = affixes.get_action_damage_multiplier(
					action_resource.action_id)
				mult *= action_mult
	
	return mult


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
	"""Legacy convenience — returns power × mult."""
	return maxi(0, roundi(_calculate_preview_power() * _calculate_preview_mult()))

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
	damage_formula_text = action_data.get("damage_formula", "")
	if damage_formula_text == "" and action_resource and action_resource.damage_formula != "":
		damage_formula_text = action_resource.damage_formula
	# Source item visual data
	source_icon = action_data.get("source_icon", null)
	source_rarity = action_data.get("source_rarity", "Common")
	
	# Element resolution — priority chain:
	# 1. Source item's affix elemental identity
	# 2. Action resource's explicit element
	# 3. Dict "element" key
	# 4. Inferred from first damage effect
	if action_data.has("source_element"):
		element = action_data["source_element"] as ActionEffect.DamageType
	elif action_resource and action_resource.get("element") != null:
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
		_setup_source_badge()



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
	if description_label:
		if action_description != "":
			description_label.text = ""
			description_label.append_text("[center][i]%s[/i][/center]" % action_description)
			description_label.show()
		else:
			description_label.hide()
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
	_update_damage_formula_label()


func _setup_source_badge():
	"""Configure the source badge — item icon with rarity glow, or element icon fallback"""
	if not source_badge:
		return
	
	RarityGlowHelper.clear_glow(source_badge)
	
	if source_icon:
		source_badge.texture = source_icon
		source_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		source_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		source_badge.custom_minimum_size = Vector2(64, 64)
		_apply_rarity_shader_to_badge(source_badge, source_rarity)
		source_badge.show()
		RarityGlowHelper.apply_glow(source_badge, source_icon, source_rarity, badge_glow_config)
	elif GameManager and GameManager.ELEMENT_VISUALS:
		var elem_icon = GameManager.ELEMENT_VISUALS.get_icon(element)
		if elem_icon:
			source_badge.texture = elem_icon
			source_badge.material = null
			source_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			source_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			source_badge.custom_minimum_size = Vector2(64, 64)
			source_badge.show()
		else:
			source_badge.hide()
	else:
		source_badge.hide()


func _apply_rarity_shader_to_badge(tex_rect: TextureRect, rarity_name: String):
	"""Apply rarity border glow shader to the source badge"""
	var shader = load("res://shaders/rarity_border.gdshader")
	if not shader:
		return
	
	var color = ThemeManager.get_rarity_color(rarity_name)
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("border_color", color)
	mat.set_shader_parameter("glow_radius", 3.0)
	mat.set_shader_parameter("glow_softness", 2.0)
	mat.set_shader_parameter("glow_width", 0.6)
	mat.set_shader_parameter("glow_strength", 1.5)
	mat.set_shader_parameter("glow_blend", 0.6)
	mat.set_shader_parameter("glow_saturation", 1.0)
	mat.set_shader_parameter("pulse_speed", 1.0)
	mat.set_shader_parameter("pulse_amount", 0.15)
	
	tex_rect.material = mat


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
	var style = ThemeManager._flat_box(
		Color(ThemeManager.PALETTE.bg_input.r, ThemeManager.PALETTE.bg_input.g,
			ThemeManager.PALETTE.bg_input.b, 0.8),
		ThemeManager.PALETTE.border_subtle, 4, 2)
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
	"""Update both legacy ChargeLabel and new ChargeContainer/RichTextLabel."""
	# Legacy label (FooterRow)
	if charge_label and charge_label is Label:
		if action_resource and action_resource.charge_type != Action.ChargeType.UNLIMITED:
			charge_label.text = "%d/%d" % [action_resource.current_charges, action_resource.max_charges]
			charge_label.show()
		else:
			charge_label.hide()
	
	# New rich text charge display
	if charge_rich_label and charge_container:
		if action_resource and action_resource.charge_type != Action.ChargeType.UNLIMITED:
			charge_rich_label.text = ""
			var charges_text = "%d/%d" % [action_resource.current_charges, action_resource.max_charges]
			var type_label = action_resource.get_charge_type_label()
			if type_label != "":
				charges_text += " [i]%s[/i]" % type_label
			charge_rich_label.append_text(charges_text)
			charge_container.show()
		else:
			charge_container.hide()

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

	# Only one action field can hold dice at a time
	if placed_dice.size() == 0:
		# This field is empty — reject if any other field has dice
		for sibling in get_parent().get_children():
			if sibling is ActionField and sibling != self and sibling.placed_dice.size() > 0:
				return false

	# Check accepted elements (from Action resource)
	if action_resource and action_resource.accepted_elements.size() > 0:
		var die = data.get("die") as DieResource
		if die:
			var die_element: int = die.get_effective_element()
			if die_element not in action_resource.accepted_elements:
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
	
	# ── Chromatic shader swap: match the placed die's element ──
	if _is_chromatic_action and die:
		var die_elem = die.get_effective_element()
		if die_elem != DieResource.Element.NONE:
			var dt = DieResource.ELEMENT_TO_DAMAGE_TYPE.get(die_elem, -1)
			if dt >= 0:
				_swap_to_element_shader(dt)
	
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
		icon_rect.modulate = ThemeManager.PALETTE.locked
	elif placed_dice.size() > 0:
		icon_rect.modulate = ThemeManager.PALETTE.text_muted
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
		var from_pos = Vector2.ZERO
		if i < die_slot_panels.size():
			var slot = die_slot_panels[i]
			from_pos = slot.global_position + slot.size / 2
		dice_returned.emit(die, from_pos)
	
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
	
	# ── NEW: Instant-clear the floater ──
	if damage_floater:
		damage_floater.clear()
	
	# Restore chromatic shader if this is a multi-element action
	_restore_chromatic_shader()
	

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
