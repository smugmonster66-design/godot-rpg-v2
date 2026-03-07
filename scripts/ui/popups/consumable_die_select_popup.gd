# res://scripts/ui/popups/consumable_die_select_popup.gd
# Popup for selecting a die target when using inscription or die-targeted consumables.
# Player drags a die from the bottom UI pool into the drop zone, previews the
# result, then confirms.
#
# Opens as CanvasLayer 100 (above all game UI). Dimmed background click or
# Escape cancels. Confirm button is disabled until a valid die is dropped.
#
# All styling comes from base_theme.tres via theme_type_variation and
# ThemeManager.PALETTE — no hard-coded colors or StyleBoxes.
extends CanvasLayer
class_name ConsumableDieSelectPopup

signal die_confirmed(consumable: ConsumableItem, die: DieResource)
signal cancelled()

# ============================================================================
# NODE REFERENCES — match consumable_die_select_popup.tscn
# ============================================================================
@onready var dim_bg: ColorRect = $DimBackground
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var icon_rect: TextureRect = $CenterContainer/Panel/VBox/ConsumableInfo/IconRect
@onready var name_label: Label = $CenterContainer/Panel/VBox/ConsumableInfo/InfoVBox/NameLabel
@onready var desc_label: Label = $CenterContainer/Panel/VBox/ConsumableInfo/InfoVBox/DescLabel
@onready var drop_zone: DieDropZone = $CenterContainer/Panel/VBox/DropZone
@onready var drop_hint: Label = $CenterContainer/Panel/VBox/DropZone/DropVBox/DropHint
@onready var die_preview_container: CenterContainer = $CenterContainer/Panel/VBox/DropZone/DropVBox/DiePreviewContainer
@onready var die_info_label: Label = $CenterContainer/Panel/VBox/DropZone/DropVBox/DieInfoLabel
@onready var cancel_button: Button = $CenterContainer/Panel/VBox/ButtonRow/CancelButton
@onready var confirm_button: Button = $CenterContainer/Panel/VBox/ButtonRow/ConfirmButton

# ============================================================================
# STATE
# ============================================================================
var _consumable: ConsumableItem = null
var _selected_die: DieResource = null
var _die_visual: Control = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	layer = 15
	visible = false

	cancel_button.pressed.connect(_on_cancel)
	confirm_button.pressed.connect(_on_confirm)
	drop_zone.die_dropped.connect(_on_die_dropped)

	# Dim background is transparent + mouse-ignore so the player can
	# drag dice from the bottom UI panel underneath
	# Let input pass through to the bottom UI panel underneath so
	# the player can drag dice. Only the panel itself catches clicks.
	dim_bg.color = Color(0, 0, 0, 0)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_button.disabled = true


func open(consumable: ConsumableItem, player: Player):
	"""Show the popup for a specific consumable."""
	_consumable = consumable
	_selected_die = null
	_clear_die_preview()

	# Populate consumable info
	name_label.text = consumable.item_name
	desc_label.text = consumable.description
	if consumable.icon:
		icon_rect.texture = consumable.icon
		icon_rect.show()
	else:
		icon_rect.hide()

	# Title based on tier
	match consumable.tier:
		ConsumableItem.ConsumableTier.INSCRIPTION:
			title_label.text = "Inscribe Die"
		ConsumableItem.ConsumableTier.DICE_ELIXIR:
			title_label.text = "Apply to Die"
		_:
			title_label.text = "Select a Die"

	# Reset drop zone
	drop_zone.reset()
	drop_zone.accept_filter = _check_die_valid
	drop_hint.text = "Drag a die here from your pool"
	drop_hint.show()
	die_info_label.text = ""
	confirm_button.disabled = true

	visible = true


# ============================================================================
# DROP HANDLING
# ============================================================================

func _on_die_dropped(die: DieResource, _data: Dictionary):
	"""Die was dropped into the zone -- show preview and enable confirm."""
	_selected_die = die
	_show_die_preview(die)
	confirm_button.disabled = false


func _check_die_valid(data: Dictionary) -> bool:
	"""Filter callable passed to DieDropZone. Gates which dice are accepted."""
	var die: DieResource = data.get("die", null)
	if not die:
		return false

	if not _consumable:
		return true

	# Inscription filter: check die tags/element/type
	if _consumable.tier == ConsumableItem.ConsumableTier.INSCRIPTION:
		if not _consumable._die_matches_filter(die):
			return false
		# Check inscription slot capacity (unless overwrite allowed)
		if _consumable.inscription_affix:
			var max_slots: int = ConsumableItem._get_max_inscription_slots(die)
			var current: int = die.inscribed_affixes.size() if "inscribed_affixes" in die else 0
			if current >= max_slots and not _consumable.can_overwrite:
				return false

	return true


# ============================================================================
# DIE PREVIEW
# ============================================================================

func _show_die_preview(die: DieResource):
	"""Display the dropped die and what will happen to it."""
	_clear_die_preview()

	# Create pool visual for the die
	if die.has_method("instantiate_pool_visual"):
		_die_visual = die.instantiate_pool_visual()
	if _die_visual:
		_die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var val_label: Label = _die_visual.find_child("ValueLabel", true, false) as Label
		if val_label:
			val_label.hide()
		die_preview_container.add_child(_die_visual)
		die_preview_container.show()

	drop_hint.hide()

	# Build info text
	var lines: Array[String] = []
	lines.append("%s  (%s)" % [die.get_display_name(), die.get_type_string()])

	if die.element != DieResource.Element.NONE:
		var elem_name: String = DieResource.Element.keys()[die.element]
		lines.append("Element: %s" % elem_name.capitalize())

	# Tier-specific info
	if _consumable.tier == ConsumableItem.ConsumableTier.INSCRIPTION:
		# Show current inscriptions and what will be added
		var inscribed: Array = die.inscribed_affixes if "inscribed_affixes" in die else []
		var max_slots: int = ConsumableItem._get_max_inscription_slots(die)
		if inscribed.size() > 0:
			lines.append("")
			lines.append("Inscriptions (%d/%d):" % [inscribed.size(), max_slots])
			for affix: DiceAffix in inscribed:
				if affix:
					lines.append("  %s" % affix.affix_name)
		else:
			lines.append("")
			lines.append("Inscriptions: 0/%d (empty)" % max_slots)

		if _consumable.inscription_affix:
			lines.append("")
			lines.append("Will inscribe:")
			lines.append("  %s" % _consumable.inscription_affix.affix_name)
			if _consumable.inscription_affix.description:
				lines.append("  %s" % _consumable.inscription_affix.description)

	elif _consumable.tier == ConsumableItem.ConsumableTier.DICE_ELIXIR:
		# Show what temp dice affix will be applied
		lines.append("")
		lines.append("Will apply (next combat):")
		for da: DiceAffix in _consumable.granted_dice_affixes:
			if da:
				lines.append("  %s" % da.affix_name)
				if da.description:
					lines.append("  %s" % da.description)

	die_info_label.text = "\n".join(lines)


func _clear_die_preview():
	if _die_visual and is_instance_valid(_die_visual):
		_die_visual.queue_free()
		_die_visual = null
	for child in die_preview_container.get_children():
		child.queue_free()
	die_preview_container.hide()


# ============================================================================
# BUTTONS
# ============================================================================

func _on_confirm():
	if _consumable and _selected_die:
		die_confirmed.emit(_consumable, _selected_die)
	_close()


func _on_cancel():
	cancelled.emit()
	_close()





func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


func _close():
	_clear_die_preview()
	_selected_die = null
	_consumable = null
	visible = false
