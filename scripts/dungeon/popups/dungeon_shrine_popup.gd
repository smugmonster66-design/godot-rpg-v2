# res://scripts/dungeon/popups/dungeon_shrine_popup.gd
## Shrine popup. Displays a blessing (and optional curse). Player can
## accept both or decline and walk away.
##
## Data in:  { "node": DungeonNodeData, "shrine": DungeonShrine, "run": DungeonRun }
## Result:   { "accepted": bool }
extends DungeonPopupBase

var _shrine: DungeonShrine = null
var _accepted: bool = false

# ============================================================================
# NODE REFERENCES — match dungeon_shrine_popup.tscn paths exactly
# ============================================================================
@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var flavor_label: Label = $CenterContainer/Panel/VBox/FlavorLabel
@onready var blessing_section: VBoxContainer = $CenterContainer/Panel/VBox/BlessingSection
@onready var blessing_label: RichTextLabel = $CenterContainer/Panel/VBox/BlessingSection/BlessingLabel
@onready var curse_section: VBoxContainer = $CenterContainer/Panel/VBox/CurseSection
@onready var curse_label: RichTextLabel = $CenterContainer/Panel/VBox/CurseSection/CurseLabel
@onready var decline_button: Button = $CenterContainer/Panel/VBox/ButtonRow/DeclineButton

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	super._ready()
	if decline_button:
		decline_button.pressed.connect(_on_decline)

# ============================================================================
# ABSTRACT IMPLEMENTATION
# ============================================================================

func show_popup(data: Dictionary) -> void:
	_base_show(data, "shrine")
	_shrine = data.get("shrine") as DungeonShrine
	_accepted = false

	if not _shrine:
		push_warning("ShrinePopup: No shrine in data")
		_on_close()
		return

	# Title and flavor
	if title_label:
		title_label.text = _shrine.shrine_name
	if flavor_label:
		flavor_label.text = _shrine.description

	# Blessing display
	if _shrine.blessing_affix:
		if blessing_section: blessing_section.show()
		if blessing_label:
			blessing_label.text = _format_affix(_shrine.blessing_affix)
	else:
		if blessing_section: blessing_section.hide()

	# Curse display — hide section entirely if no curse
	if _shrine.has_curse():
		if curse_section: curse_section.show()
		if curse_label:
			var text = _format_affix(_shrine.curse_affix)
			if _shrine.curse_description != "":
				text = _shrine.curse_description
			curse_label.text = text
	else:
		if curse_section: curse_section.hide()

func _build_result() -> Dictionary:
	return {"accepted": _accepted}

# ============================================================================
# UI CALLBACKS
# ============================================================================

func _on_close():
	"""Override: CloseButton means Accept for shrine."""
	_accepted = true
	super._on_close()

func _on_decline():
	"""Walk away — no blessing, no curse."""
	_accepted = false
	var result = _build_result()
	result["type"] = _popup_type
	result["node_id"] = _node_id
	hide()
	popup_closed.emit(result)

# ============================================================================
# HELPERS
# ============================================================================

func _format_affix(affix) -> String:
	if affix == null: return ""
	if affix.has_method("get_display_text"):
		return affix.get_display_text()
	if "display_name" in affix and affix.display_name != "":
		return affix.display_name
	return str(affix)
