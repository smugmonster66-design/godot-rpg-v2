# res://scripts/ui/components/combat_button.gd
# A button that starts a specific combat encounter when pressed
# Attach to any Button node and drag an encounter resource to the Inspector
extends Button
class_name CombatButton

# ============================================================================
# CONFIGURATION
# ============================================================================
@export_group("Encounter")
## The encounter to start when this button is pressed. Drag a CombatEncounter resource here.
@export var encounter: CombatEncounter = null

@export_group("Behavior")
## If true, button disables itself after being pressed
@export var disable_on_press: bool = false
## If true, shows encounter name as button text
@export var show_encounter_name: bool = false
## Optional prefix for encounter name display
@export var name_prefix: String = "Fight: "

@export_group("Validation")
## If true, validates encounter on ready and disables if invalid
@export var validate_on_ready: bool = true
## If true, shows warning in console if encounter is missing
@export var warn_if_missing: bool = true

# ============================================================================
# INITIALIZATION
# ============================================================================



func _ready():
	print("🔴 CombatButton._ready()")
	
	# Test loading the scripts
	var encounter_script = load("res://resources/data/combat_encounter.gd")
	print("   combat_encounter.gd: %s" % encounter_script)
	
	var enemy_script = load("res://resources/data/enemy_data.gd")
	print("   enemy_data.gd: %s" % enemy_script)
	
	# Test loading the enemy resource
	var goblin = load("res://resources/enemies/goblin.tres")
	print("   goblin.tres: %s" % goblin)
	
	# Test loading the encounter
	var encounter_res = load("res://resources/encounters/goblins_basic.tres")
	print("   goblins_basic.tres: %s" % encounter_res)
	
	if encounter_res and not encounter:
		encounter = encounter_res
		print("   FORCE ASSIGNED!")
	
	# Connect button press
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	
	# Update display if configured
	if show_encounter_name and encounter:
		text = name_prefix + encounter.encounter_name
	
	# Validate encounter
	if validate_on_ready:
		_validate_encounter()



func _validate_encounter():
	"""Validate the encounter configuration"""
	if not encounter:
		if warn_if_missing:
			push_warning("CombatButton '%s': No encounter assigned" % name)
		disabled = true
		return
	
	var warnings = encounter.validate()
	if warnings.size() > 0:
		for warning in warnings:
			push_warning("CombatButton '%s': %s" % [name, warning])

# ============================================================================
# BUTTON PRESS
# ============================================================================

func _on_pressed():
	"""Handle button press - start the encounter"""
	print("🔴 CombatButton._on_pressed() called")
	print("   encounter: %s" % encounter)
	print("   GameManager: %s" % GameManager)
	
	if not encounter:
		push_error("CombatButton: No encounter assigned!")
		return
	
	if not GameManager:
		push_error("CombatButton: GameManager not found!")
		return
	
	print("🔴 CombatButton: Starting encounter '%s'" % encounter.encounter_name)
	
	if disable_on_press:
		disabled = true
	
	GameManager.start_combat_encounter(encounter)


# ============================================================================
# PUBLIC API
# ============================================================================

func set_encounter(new_encounter: CombatEncounter):
	"""Set the encounter at runtime"""
	encounter = new_encounter
	
	if show_encounter_name and encounter:
		text = name_prefix + encounter.encounter_name
	
	if validate_on_ready:
		_validate_encounter()

func get_encounter() -> CombatEncounter:
	"""Get the assigned encounter"""
	return encounter
