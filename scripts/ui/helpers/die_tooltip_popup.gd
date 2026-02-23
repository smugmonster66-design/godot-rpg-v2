# res://scripts/ui/helpers/die_tooltip_popup.gd
# Reusable floating die tooltip with full-screen backdrop for tap-to-dismiss.
# Scene-based — instance via DieTooltipPopup.show_die() or preload the .tscn.
# All styling comes from base_theme.tres (TooltipPanel / TooltipLabel variations).
extends CanvasLayer
class_name DieTooltipPopup

# ============================================================================
# SIGNALS
# ============================================================================
signal dismissed

# ============================================================================
# NODE REFERENCES — match scene tree
# ============================================================================
@onready var backdrop: ColorRect = $Backdrop
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var vbox: VBoxContainer = $TooltipPanel/VBox
@onready var header_label: Label = $TooltipPanel/VBox/HeaderLabel
@onready var subtitle_label: Label = $TooltipPanel/VBox/SubtitleLabel
@onready var flavor_label: Label = $TooltipPanel/VBox/FlavorLabel
@onready var affix_container: VBoxContainer = $TooltipPanel/VBox/AffixContainer

# ============================================================================
# STATE
# ============================================================================
var _source_ref: Control = null
var _die_res: DieResource = null
var _anchor_pos: Vector2 = Vector2.ZERO

# ============================================================================
# STATIC FACTORY
# ============================================================================

static var _scene: PackedScene = null

static func show_die(die_res: DieResource, anchor_pos: Vector2, parent: Node, source: Control = null) -> DieTooltipPopup:
	"""Create, populate, position, and return a DieTooltipPopup.
	Caller can store the reference to dismiss manually or connect to dismissed."""
	if not _scene:
		_scene = load("res://scenes/ui/helpers/die_tooltip_popup.tscn")
	var popup: DieTooltipPopup = _scene.instantiate()
	popup._die_res = die_res
	popup._anchor_pos = anchor_pos
	popup._source_ref = source
	parent.add_child(popup)
	return popup

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	backdrop.gui_input.connect(_on_input)
	tooltip_panel.gui_input.connect(_on_input)

	if _die_res:
		_populate(_die_res)
		_position_near.call_deferred(_anchor_pos)

# ============================================================================
# POPULATE
# ============================================================================

func _populate(die_res: DieResource):
	"""Fill labels from DieResource data."""
	var size_tag = "D%d" % die_res.die_type
	var is_unique = size_tag not in die_res.display_name

	# Header — always visible
	header_label.text = die_res.display_name

	# Subtitle — unique dice only
	if is_unique:
		var elem_name = die_res.get_element_name() if die_res.has_element() else ""
		subtitle_label.text = "%s %s" % [elem_name, size_tag] if elem_name else size_tag
		subtitle_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
		subtitle_label.show()
	else:
		subtitle_label.hide()

	# Flavor text — unique dice with flavor only
	if is_unique and die_res.has_method("get_flavor_text"):
		var flavor = die_res.get_flavor_text()
		if flavor and flavor != "":
			flavor_label.text = flavor
			flavor_label.add_theme_color_override("font_color", ThemeManager.PALETTE.danger)
			flavor_label.show()
		else:
			flavor_label.hide()
	else:
		flavor_label.hide()

	# Affix labels — dynamic
	var all_affixes = die_res.get_all_affixes()
	for dice_affix in all_affixes:
		if not dice_affix:
			continue

		var affix_label = Label.new()
		affix_label.theme_type_variation = "TooltipLabel"
		affix_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Get description text
		if dice_affix.has_method("get_formatted_description"):
			affix_label.text = dice_affix.get_formatted_description()
		else:
			affix_label.text = dice_affix.affix_name

		# Replace N placeholders with stamped values
		affix_label.text = _replace_placeholders(affix_label.text, dice_affix)

		affix_label.add_theme_color_override("font_color", ThemeManager.PALETTE.success)
		affix_container.add_child(affix_label)

# ============================================================================
# PLACEHOLDER REPLACEMENT
# ============================================================================

func _replace_placeholders(text: String, dice_affix: DiceAffix) -> String:
	"""Replace N / N% placeholders with formatted affix values."""
	if "N%" in text:
		var val = dice_affix.effect_value
		if dice_affix.effect_value_max <= 1.0 and dice_affix.effect_value_min >= 0.0 and dice_affix.effect_value_max > 0.0:
			var rounded = snappedf(val, 0.01)
			text = text.replace("N%", "%d%%" % int(rounded * 100))
		else:
			text = text.replace("N%", "%d%%" % int(val))
	elif "N" in text:
		var val = dice_affix.effect_value
		var val_min = dice_affix.effect_value_min
		var val_max = dice_affix.effect_value_max

		var formatted: String
		if val_max <= 1.0 and val_min >= 0.0 and val_max > 0.0:
			formatted = "%d%%" % int(snappedf(val, 0.01) * 100)
		elif val_max <= 5.0:
			var rounded = snappedf(val, 0.5)
			formatted = "+%d" % int(rounded) if rounded == int(rounded) else "+%.1f" % rounded
		else:
			formatted = "+%d" % int(roundf(val))
		text = text.replace("N", formatted)
	return text

# ============================================================================
# POSITIONING
# ============================================================================

func _position_near(anchor: Vector2):
	if not tooltip_panel or not is_instance_valid(tooltip_panel):
		return
		
	tooltip_panel.reset_size()

	var vp_size := get_viewport().get_visible_rect().size
	var popup_size := tooltip_panel.size

	# Default: centered above anchor
	var pos := Vector2(
		anchor.x - popup_size.x / 2.0,
		anchor.y - popup_size.y - 12.0
	)

	# If above screen, put below instead
	if pos.y < 8.0:
		pos.y = anchor.y + 20.0

	# Clamp
	pos.x = clampf(pos.x, 8.0, vp_size.x - popup_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp_size.y - popup_size.y - 8.0)

	tooltip_panel.position = pos

# ============================================================================
# INPUT
# ============================================================================

func _on_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		dismiss()

# ============================================================================
# PUBLIC API
# ============================================================================

func is_for_source(source: Control) -> bool:
	"""Check if this popup was opened for a specific source control."""
	return _source_ref == source

func dismiss():
	"""Clean up and remove from tree."""
	dismissed.emit()
	queue_free()
