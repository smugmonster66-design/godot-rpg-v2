# res://editor_scripts/generate_base_dice.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Creates a base DieResource .tres for every Size × Element combination.
# These are reusable "building block" dice that enemies and other systems
# can reference directly — no need to create custom dice per enemy.
#
# OUTPUT:
#   res://resources/dice/base/d{size}_{element}.tres
#   e.g. d4_none.tres, d6_blunt.tres, d8_fire.tres, d12_shadow.tres
#
# TOTAL: 6 sizes × 10 elements = 60 dice
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
@tool
extends EditorScript

const DICE_DIR := "res://resources/dice/base/"

# Element affix paths — these provide visual shaders for each element.
# NONE and FAITH have no element affix (null).
const ELEMENT_AFFIX_PATHS := {
	DieResource.Element.SLASHING: "res://resources/affixes/elements/slashing_element.tres",
	DieResource.Element.BLUNT:    "res://resources/affixes/elements/blunt_element.tres",
	DieResource.Element.PIERCING: "res://resources/affixes/elements/piercing_element.tres",
	DieResource.Element.FIRE:     "res://resources/affixes/elements/fire_element.tres",
	DieResource.Element.ICE:      "res://resources/affixes/elements/ice_element.tres",
	DieResource.Element.SHOCK:    "res://resources/affixes/elements/shock_element.tres",
	DieResource.Element.POISON:   "res://resources/affixes/elements/poison_element.tres",
	DieResource.Element.SHADOW:   "res://resources/affixes/elements/shadow_element.tres",
}

# Fill texture paths per die size
const FILL_PATHS := {
	DieResource.DieType.D4:  "res://assets/dice/d4s/d4-fill-basic.png",
	DieResource.DieType.D6:  "res://assets/dice/D6s/d6-basic-fill.png",
	DieResource.DieType.D8:  "res://assets/dice/d8s/d8-fill-basic.png",
	DieResource.DieType.D10: "res://assets/dice/d10s/d10-fill-basic.png",
	DieResource.DieType.D12: "res://assets/dice/d12s/d12-basic-fill.png",
	DieResource.DieType.D20: "res://assets/dice/d20s/d20-fill-basic.png",
}

# Stroke texture paths per die size
const STROKE_PATHS := {
	DieResource.DieType.D4:  "res://assets/dice/d4s/d4-stroke-basic.png",
	DieResource.DieType.D6:  "res://assets/dice/D6s/d6-basic-stroke.png",
	DieResource.DieType.D8:  "res://assets/dice/d8s/d8-stroke-basic.png",
	DieResource.DieType.D10: "res://assets/dice/d10s/d10-stroke-basic.png",
	DieResource.DieType.D12: "res://assets/dice/d12s/d12-basic-stroke.png",
	DieResource.DieType.D20: "res://assets/dice/d20s/d20-stroke-basic.png",
}

# Human-readable names
const SIZE_NAMES := {
	DieResource.DieType.D4:  "D4",
	DieResource.DieType.D6:  "D6",
	DieResource.DieType.D8:  "D8",
	DieResource.DieType.D10: "D10",
	DieResource.DieType.D12: "D12",
	DieResource.DieType.D20: "D20",
}

const ELEMENT_NAMES := {
	DieResource.Element.NONE:     "none",
	DieResource.Element.SLASHING: "slashing",
	DieResource.Element.BLUNT:    "blunt",
	DieResource.Element.PIERCING: "piercing",
	DieResource.Element.FIRE:     "fire",
	DieResource.Element.ICE:      "ice",
	DieResource.Element.SHOCK:    "shock",
	DieResource.Element.POISON:   "poison",
	DieResource.Element.SHADOW:   "shadow",
	DieResource.Element.FAITH:    "faith",
}

const ELEMENT_DISPLAY := {
	DieResource.Element.NONE:     "",
	DieResource.Element.SLASHING: "Slashing ",
	DieResource.Element.BLUNT:    "Blunt ",
	DieResource.Element.PIERCING: "Piercing ",
	DieResource.Element.FIRE:     "Fire ",
	DieResource.Element.ICE:      "Ice ",
	DieResource.Element.SHOCK:    "Shock ",
	DieResource.Element.POISON:   "Poison ",
	DieResource.Element.SHADOW:   "Shadow ",
	DieResource.Element.FAITH:    "Faith ",
}

var _created := 0
var _skipped := 0
var _errors := 0

func _run() -> void:
	print("══════════════════════════════════════════════════════")
	print("🎲  BASE DICE GENERATOR")
	print("══════════════════════════════════════════════════════")

	DirAccess.make_dir_recursive_absolute(DICE_DIR)

	# Preload element affixes
	var element_affixes := {}
	for elem in ELEMENT_AFFIX_PATHS:
		var path: String = ELEMENT_AFFIX_PATHS[elem]
		if ResourceLoader.exists(path):
			element_affixes[elem] = load(path)
			print("  ✅ Loaded element affix: %s" % path.get_file())
		else:
			element_affixes[elem] = null
			print("  ⚠️ Missing element affix: %s (dice will have null element_affix)" % path.get_file())

	# Preload textures
	var fill_textures := {}
	var stroke_textures := {}
	for size in FILL_PATHS:
		if ResourceLoader.exists(FILL_PATHS[size]):
			fill_textures[size] = load(FILL_PATHS[size])
		else:
			fill_textures[size] = null
			print("  ⚠️ Missing fill texture for %s" % SIZE_NAMES[size])

		if ResourceLoader.exists(STROKE_PATHS[size]):
			stroke_textures[size] = load(STROKE_PATHS[size])
		else:
			stroke_textures[size] = null
			print("  ⚠️ Missing stroke texture for %s" % SIZE_NAMES[size])

	print("")

	# Generate all combinations
	var sizes := [
		DieResource.DieType.D4,
		DieResource.DieType.D6,
		DieResource.DieType.D8,
		DieResource.DieType.D10,
		DieResource.DieType.D12,
		DieResource.DieType.D20,
	]

	var elements := [
		DieResource.Element.NONE,
		DieResource.Element.SLASHING,
		DieResource.Element.BLUNT,
		DieResource.Element.PIERCING,
		DieResource.Element.FIRE,
		DieResource.Element.ICE,
		DieResource.Element.SHOCK,
		DieResource.Element.POISON,
		DieResource.Element.SHADOW,
		DieResource.Element.FAITH,
	]

	for size in sizes:
		var size_name: String = SIZE_NAMES[size]
		print("🎲 %s..." % size_name)

		for elem in elements:
			var elem_name: String = ELEMENT_NAMES[elem]
			var display_prefix: String = ELEMENT_DISPLAY[elem]
			var file_name := "%s_%s.tres" % [size_name.to_lower(), elem_name]
			var path := DICE_DIR + file_name

			var die := DieResource.new()
			die.display_name = "%s%s" % [display_prefix, size_name]
			die.die_type = size
			die.element = elem

			# Textures
			die.fill_texture = fill_textures.get(size)
			die.stroke_texture = stroke_textures.get(size)

			# Element affix (null for NONE and FAITH)
			if elem in element_affixes:
				die.element_affix = element_affixes[elem]
			else:
				die.element_affix = null

			var err := ResourceSaver.save(die, path)
			if err == OK:
				_created += 1
			else:
				_errors += 1
				push_error("❌ Failed to save: %s (%s)" % [path, error_string(err)])

	print("")
	print("══════════════════════════════════════════════════════")
	print("✅  Created: %d dice" % _created)
	if _errors > 0:
		print("❌  Errors: %d" % _errors)
	print("══════════════════════════════════════════════════════")
