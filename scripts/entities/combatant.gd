# res://scripts/entities/combatant.gd
# Visual combatant (player or enemy) with dice and actions
extends Node2D
class_name Combatant

# ============================================================================
# EXPORTS
# ============================================================================
@export var max_health: int = 100
@export var combatant_name: String = "Combatant"
@export var is_player_controlled: bool = false

@export_group("Enemy Configuration")
## Drag an EnemyData resource here to configure this combatant
@export var enemy_data: EnemyData = null

@export_group("AI Settings (Override)")
## Override AI strategy (only if enemy_data is not set)
@export_enum("AGGRESSIVE", "DEFENSIVE", "BALANCED", "RANDOM") var ai_strategy: int = 0
@export var action_delay: float = 0.8
@export var dice_drag_duration: float = 0.4

# ============================================================================
# STATE
# ============================================================================
var current_health: int = 100
var armor: int = 0
var barrier: int = 0
var dice_collection: PlayerDiceCollection = null
var actions: Array[Dictionary] = []

# Current action state (for AI turns)
var current_action: Dictionary = {}
var current_action_dice: Array[DieResource] = []

# Selection shader for targeting
var selection_shader: ShaderMaterial = null
var is_target_selected: bool = false
var affix_manager: AffixPoolManager = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var name_label: Label = $NameLabel

# ============================================================================
# SIGNALS
# ============================================================================
signal health_changed(new_health: int, max_health: int)
signal died()
signal turn_completed()
signal action_executed(action: Dictionary, value: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# If we have enemy_data, initialize from it
	if enemy_data and not is_player_controlled:
		_initialize_from_enemy_data()
	else:
		current_health = max_health
	
	# Create dice collection for non-player combatants without enemy_data
	if not is_player_controlled and not dice_collection:
		_setup_dice_collection()
	
	# Setup selection shader for enemies
	if not is_player_controlled:
		setup_selection_shader()
	
	update_display()

func _initialize_from_enemy_data():
	"""Initialize all combatant properties from EnemyData resource"""
	print("🎲 Initializing combatant from EnemyData: %s" % enemy_data.enemy_name)
	
	# Identity
	combatant_name = enemy_data.enemy_name
	
	# Stats
	max_health = enemy_data.max_health
	current_health = max_health
	armor = enemy_data.base_armor
	barrier = enemy_data.base_barrier
	
	# AI settings
	ai_strategy = enemy_data.ai_strategy
	action_delay = enemy_data.action_delay
	dice_drag_duration = enemy_data.dice_drag_duration
	
	# Actions (convert from Action resources to dictionaries)
	actions = enemy_data.get_actions_as_dicts()
	
	# Dice collection
	_setup_dice_collection_from_enemy_data()
	
	# Sprite texture
	if enemy_data.sprite_texture and sprite:
		sprite.texture = enemy_data.sprite_texture
	
	# Create affix manager for this enemy
	affix_manager = AffixPoolManager.new()
	
	# If enemy_data has affixes, add them
	if enemy_data.has_method("get_affixes"):
		for affix in enemy_data.get_affixes():
			affix_manager.add_affix(affix)
	
	
	print("  ✅ %s: HP=%d, Armor=%d, Dice=%d, Actions=%d" % [
		combatant_name, max_health, armor, 
		dice_collection.get_pool_count() if dice_collection else 0, 
		actions.size()
	])

func get_affix_manager() -> AffixPoolManager:
	"""Get this combatant's affix manager"""
	if not affix_manager:
		affix_manager = AffixPoolManager.new()
	return affix_manager

func _setup_dice_collection_from_enemy_data():
	"""Setup dice collection from EnemyData"""
	dice_collection = PlayerDiceCollection.new()
	dice_collection.name = "DiceCollection"
	add_child(dice_collection)
	
	# Add copies of starting dice (not the originals!)
	var dice_copies = enemy_data.create_dice_copies()
	for die in dice_copies:
		dice_collection.add_die(die)
	
	print("  🎲 Dice collection: %d dice" % dice_collection.get_pool_count())

func _setup_dice_collection():
	"""Fallback: Setup empty dice collection"""
	if dice_collection:
		return
	
	dice_collection = PlayerDiceCollection.new()
	dice_collection.name = "DiceCollection"
	add_child(dice_collection)

func setup_from_data(data: Dictionary):
	"""Setup combatant from a data dictionary (legacy support)"""
	combatant_name = data.get("name", "Enemy")
	max_health = data.get("max_health", 100)
	current_health = max_health
	ai_strategy = data.get("ai_strategy", 0)
	actions = data.get("actions", [])
	
	# Setup dice
	if not dice_collection:
		_setup_dice_collection()
	else:
		dice_collection.clear_pool()
	
	var dice_types = data.get("dice", [])
	for die_type in dice_types:
		var die = DieResource.new(die_type, combatant_name)
		dice_collection.add_die(die)
	
	update_display()

# ============================================================================
# SELECTION SHADER
# ============================================================================

func setup_selection_shader():
	"""Setup the selection outline shader on the sprite"""
	if not sprite:
		return
	
	var shader = load("res://shaders/enemy_selection_outline.gdshader")
	if shader:
		selection_shader = ShaderMaterial.new()
		selection_shader.shader = shader
		selection_shader.set_shader_parameter("enabled", false)
		selection_shader.set_shader_parameter("outline_color", Color(1.0, 0.9, 0.2, 1.0))
		selection_shader.set_shader_parameter("outline_width", 3.0)
		selection_shader.set_shader_parameter("pulse_speed", 3.0)
		sprite.material = selection_shader
		print("  ✅ Selection shader setup for %s" % combatant_name)

func set_target_selected(selected: bool):
	"""Set whether this combatant is the selected target"""
	is_target_selected = selected
	
	if selection_shader:
		selection_shader.set_shader_parameter("enabled", selected)
	
	# Visual feedback even without shader
	if sprite:
		var tween = create_tween()
		if selected:
			tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.15)
		else:
			tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

func get_is_target_selected() -> bool:
	"""Check if this combatant is the selected target"""
	return is_target_selected

# ============================================================================
# TURN MANAGEMENT (for AI combatants)
# ============================================================================

func start_turn():
	"""Called when this combatant's turn begins"""
	if is_player_controlled:
		return  # Player turn handled by combat_ui
	
	print("🎲 %s starting turn..." % combatant_name)
	
	# Roll dice into hand
	if dice_collection:
		dice_collection.roll_hand()
		print("  Rolled hand:")
		for die in dice_collection.get_hand_dice():
			print("    %s: %d" % [die.get_display_name(), die.get_total_value()])

func end_turn():
	"""Called when this combatant's turn ends"""
	current_action = {}
	current_action_dice.clear()
	turn_completed.emit()

func prepare_action(action: Dictionary, dice: Array[DieResource]):
	"""Prepare an action with specific dice"""
	current_action = action
	current_action_dice = dice

func consume_action_die(die: DieResource):
	"""Consume a die from the prepared action"""
	if dice_collection:
		dice_collection.consume_from_hand(die)

func execute_prepared_action() -> int:
	"""Execute the prepared action and return result value"""
	if current_action.is_empty():
		return 0
	
	var total = 0
	for die in current_action_dice:
		total += die.get_total_value()
	
	var base_damage = current_action.get("base_damage", 0)
	var multiplier = current_action.get("damage_multiplier", 1.0)
	var result = int(base_damage + (total * multiplier))
	
	action_executed.emit(current_action, result)
	
	return result

func has_usable_dice() -> bool:
	"""Check if combatant has dice available to use"""
	if not dice_collection:
		return false
	return dice_collection.get_hand_count() > 0

func get_available_dice() -> Array[DieResource]:
	"""Get currently available dice (hand)"""
	if dice_collection:
		return dice_collection.get_hand_dice()
	return []

# ============================================================================
# COMBAT - HEALTH
# ============================================================================

func take_damage(amount: int):
	"""Take damage, applying armor reduction"""
	var reduced = max(0, amount - armor)
	current_health = max(0, current_health - reduced)
	
	print("  💥 %s takes %d damage (%d after armor), HP: %d/%d" % [
		combatant_name, amount, reduced, current_health, max_health
	])
	
	health_changed.emit(current_health, max_health)
	update_display()
	
	if current_health <= 0:
		_on_death()

func heal(amount: int):
	"""Heal for an amount"""
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	var healed = current_health - old_health
	
	print("  💚 %s heals for %d, HP: %d/%d" % [
		combatant_name, healed, current_health, max_health
	])
	
	health_changed.emit(current_health, max_health)
	update_display()

func is_alive() -> bool:
	"""Check if combatant is alive"""
	return current_health > 0

func _on_death():
	"""Handle death"""
	print("☠️ %s has been defeated!" % combatant_name)
	died.emit()

# ============================================================================
# DISPLAY
# ============================================================================

func update_display():
	"""Update visual display"""
	if health_label:
		health_label.text = "%d/%d" % [current_health, max_health]
	
	if name_label:
		name_label.text = combatant_name

# ============================================================================
# REWARDS (for enemies)
# ============================================================================

func get_rewards() -> Dictionary:
	"""Get rewards for defeating this enemy"""
	if enemy_data:
		return {
			"experience": enemy_data.experience_reward,
			"gold": enemy_data.get_gold_reward(),
			"loot_table": enemy_data.loot_table_id
		}
	return {
		"experience": 0,
		"gold": 0,
		"loot_table": ""
	}
