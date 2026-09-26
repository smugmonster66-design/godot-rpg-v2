extends Node
## DescriptionParser — autoload that converts [status:id] / [element:id] tags in
## description strings into fully-rendered BBCode with inline icons and colors.
##
## Usage:
##   description_label.append_text(DescriptionParser.parse(raw_description))
##
## Tag syntax:
##   [status:burn]            → icon + colored "Burn"
##   [status:burn|Burning]    → icon + colored "Burning" (custom label)
##   [element:fire]           → icon + colored "Fire"
##   [element:fire|Fire Dmg]  → icon + colored "Fire Dmg"
##   [trigger:eot]            → colored "end of your turn"
##   [trigger:kill|slay]      → colored "slay" (custom label)


# ============================================================================
# CONSTANTS
# ============================================================================

const ICON_SIZE := 30
const STATUS_ICON_DIR := "res://assets/status_effects/"
const ELEMENT_ICON_DIR := "res://assets/icons/elements/"

const STATUS_NAMES: Dictionary = {
	"burn":        "Burn",
	"bleed":       "Bleed",
	"poison":      "Poison",
	"chill":       "Chill",
	"freeze":      "Freeze",
	"static":      "Static",
	"stunned":     "Stunned",
	"slowed":      "Slowed",
	"corrode":     "Corrode",
	"shadow":      "Shadow",
	"expose":      "Expose",
	"enfeeble":    "Enfeeble",
	"ignition":    "Ignition",
	"block":       "Block",
	"dodge":       "Dodge",
	"overhealth":  "Overhealth",
	"taunt":       "Taunt",
	"marked":      "Marked",
	"warded":      "Warded",
	"braced":      "Braced",
	"fortified":   "Fortified",
	"empowered":   "Empowered",
	"barrier":     "Barrier",
}

const ELEMENT_NAMES: Dictionary = {
	"fire":      "Fire",
	"ice":       "Ice",
	"shock":     "Shock",
	"poison":    "Poison",
	"shadow":    "Shadow",
	"slashing":  "Slashing",
	"blunt":     "Blunt",
	"piercing":  "Piercing",
}

## Trigger placeholders — shorthand IDs → readable phrases.
## Mirrors CompanionData.CompanionTrigger enum values.
const TRIGGER_NAMES: Dictionary = {
	"turn_start":              "start of your turn",
	"sot":                     "start of your turn",
	"player_turn_start":       "start of your turn",
	"turn_end":                "end of your turn",
	"eot":                     "end of your turn",
	"player_turn_end":         "end of your turn",
	"enemy_turn_start":        "start of the enemy turn",
	"player_damaged":          "you take damage",
	"player_damaged_threshold":"you drop below the HP threshold",
	"ally_damaged":            "an ally takes damage",
	"companion_damaged":       "this companion takes damage",
	"other_companion_damaged": "another companion takes damage",
	"kill":                    "kill an enemy",
	"enemy_killed":            "kill an enemy",
	"companion_killed":        "a companion dies",
	"round_start":             "start of each round",
	"on_summon":               "being summoned",
	"summon":                  "being summoned",
	"on_death":                "dying",
	"death":                   "dying",
}


# ============================================================================
# PRIVATE STATE
# ============================================================================

var _status_re: RegEx
var _element_re: RegEx
var _trigger_re: RegEx


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_status_re = RegEx.new()
	# Matches [status:id] or [status:id|custom label]
	_status_re.compile("\\[status:([^\\]|]+)(?:\\|([^\\]]+))?\\]")

	_element_re = RegEx.new()
	# Matches [element:id] or [element:id|custom label]
	_element_re.compile("\\[element:([^\\]|]+)(?:\\|([^\\]]+))?\\]")

	_trigger_re = RegEx.new()
	# Matches [trigger:id] or [trigger:id|custom label]
	_trigger_re.compile("\\[trigger:([^\\]|]+)(?:\\|([^\\]]+))?\\]")


# ============================================================================
# PUBLIC API
# ============================================================================

## Set parsed BBCode on a RichTextLabel (clear + parse + append in one call).
func set_bbcode(rtl: RichTextLabel, text: String) -> void:
	rtl.clear()
	rtl.append_text(parse(text))


## Factory: create a RichTextLabel with parsed BBCode, color, and autowrap.
func make_rich_label(text: String, color: Color = Color.WHITE) -> RichTextLabel:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color != Color.WHITE:
		rtl.add_theme_color_override("default_color", color)
	rtl.append_text(parse(text))
	return rtl


## Parse a raw description string and return BBCode-formatted text.
## Unrecognised tags and plain text pass through unchanged.
func parse(text: String) -> String:
	if text.is_empty():
		return text
	text = _replace_all(_status_re, text, _resolve_status)
	text = _replace_all(_element_re, text, _resolve_element)
	text = _replace_all(_trigger_re, text, _resolve_trigger)
	return text


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _replace_all(re: RegEx, text: String, resolver: Callable) -> String:
	var matches := re.search_all(text)
	if matches.is_empty():
		return text
	var result := ""
	var last_end := 0
	for m in matches:
		result += text.substr(last_end, m.get_start() - last_end)
		result += resolver.call(m)
		last_end = m.get_end()
	result += text.substr(last_end)
	return result


func _resolve_status(m: RegExMatch) -> String:
	var id: String = m.get_string(1).strip_edges().to_lower()
	var label: String = m.get_string(2).strip_edges()
	if label.is_empty():
		label = STATUS_NAMES.get(id, id.capitalize())

	var color: Color = ThemeManager.get_status_color(id)
	var hex: String = "#" + color.to_html(false)
	var icon_path: String = STATUS_ICON_DIR + id + "_status.png"

	if ResourceLoader.exists(icon_path):
		return "[color=%s][img=%dx%d color=%s]%s[/img] %s[/color]" % [hex, ICON_SIZE, ICON_SIZE, hex, icon_path, label]
	else:
		return "[color=%s]%s[/color]" % [hex, label]


func _resolve_element(m: RegExMatch) -> String:
	var id: String = m.get_string(1).strip_edges().to_lower()
	var label: String = m.get_string(2).strip_edges()
	if label.is_empty():
		label = ELEMENT_NAMES.get(id, id.capitalize())

	var color: Color = ThemeManager.get_element_color(id)
	var hex: String = "#" + color.to_html(false)
	var icon_path: String = ELEMENT_ICON_DIR + id + ".png"

	if ResourceLoader.exists(icon_path):
		return "[color=%s][img=%dx%d color=%s]%s[/img] %s[/color]" % [hex, ICON_SIZE, ICON_SIZE, hex, icon_path, label]
	else:
		return "[color=%s]%s[/color]" % [hex, label]


func _resolve_trigger(m: RegExMatch) -> String:
	var id: String = m.get_string(1).strip_edges().to_lower()
	var label: String = m.get_string(2).strip_edges()
	if label.is_empty():
		label = TRIGGER_NAMES.get(id, id.replace("_", " "))

	var color: Color = ThemeManager.get_trigger_color()
	var hex: String = "#" + color.to_html(false)
	return "[color=%s]%s[/color]" % [hex, label]
