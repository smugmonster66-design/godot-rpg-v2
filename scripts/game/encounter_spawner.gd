# res://scripts/game/encounter_spawner.gd
# Spawns enemies from a CombatEncounter resource
extends Node
class_name EncounterSpawner

# ============================================================================
# SIGNALS
# ============================================================================
signal enemies_spawned(enemies: Array[Combatant])
signal spawn_failed(reason: String)

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var combatant_scene: PackedScene = null
@export var enemy_container_path: NodePath = ".."

# ============================================================================
# STATE
# ============================================================================
var spawned_enemies: Array[Combatant] = []
var current_encounter: CombatEncounter = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Try to load default combatant scene if not set
	if not combatant_scene:
		combatant_scene = load("res://scenes/entities/combatant.tscn")
		if not combatant_scene:
			push_warning("EncounterSpawner: No combatant scene set and default not found")

# ============================================================================
# SPAWNING
# ============================================================================

func spawn_encounter(encounter: CombatEncounter) -> Array[Combatant]:
	"""Spawn all enemies from an encounter resource"""
	current_encounter = encounter
	spawned_enemies.clear()
	
	if not encounter:
		push_error("EncounterSpawner: No encounter provided")
		spawn_failed.emit("No encounter provided")
		return []
	
	# Validate encounter
	var warnings = encounter.validate()
	for warning in warnings:
		push_warning("EncounterSpawner: %s" % warning)
	
	if encounter.enemies.size() == 0:
		push_error("EncounterSpawner: Encounter has no enemies")
		spawn_failed.emit("Encounter has no enemies")
		return []
	
	print("⚔️ EncounterSpawner: Spawning '%s' (%d enemies)" % [
		encounter.encounter_name, encounter.enemies.size()
	])
	
	# Get container node
	var container = get_node_or_null(enemy_container_path)
	if not container:
		container = get_parent()
	
	# Spawn each enemy
	for i in range(encounter.enemies.size()):
		var enemy_data = encounter.enemies[i]
		if not enemy_data:
			push_warning("  Skipping null enemy at index %d" % i)
			continue
		
		var enemy = _spawn_single_enemy(enemy_data, i, container)
		if enemy:
			spawned_enemies.append(enemy)
	
	print("  ✅ Spawned %d enemies" % spawned_enemies.size())
	enemies_spawned.emit(spawned_enemies)
	
	return spawned_enemies

func _spawn_single_enemy(enemy_data: EnemyData, index: int, container: Node) -> Combatant:
	"""Spawn a single enemy combatant"""
	var enemy: Combatant = null
	
	# Try to instance from scene
	if combatant_scene:
		enemy = combatant_scene.instantiate() as Combatant
	
	# Fallback: create Combatant node directly
	if not enemy:
		enemy = Combatant.new()
	
	# Configure the enemy
	enemy.name = "Enemy%d" % (index + 1)
	enemy.enemy_data = enemy_data
	enemy.is_player_controlled = false
	
	# Set position
	#enemy.position = current_encounter.get_enemy_position(index)
	
	# Apply stat scaling if needed
	if current_encounter.stat_multiplier != 1.0:
		_apply_stat_scaling(enemy, enemy_data)
	
	# Add to scene
	container.add_child(enemy)
	enemy.visible = false
	
	print("    [%d] %s at %s" % [index, enemy_data.enemy_name, enemy.position])
	
	return enemy

func _apply_stat_scaling(enemy: Combatant, enemy_data: EnemyData):
	"""Apply difficulty scaling to enemy stats"""
	var mult = current_encounter.stat_multiplier
	enemy.max_health = int(enemy_data.max_health * mult)
	enemy.current_health = enemy.max_health

# ============================================================================
# UTILITY
# ============================================================================

func get_spawned_enemies() -> Array[Combatant]:
	"""Get array of spawned enemy combatants"""
	return spawned_enemies

func clear_spawned_enemies():
	"""Remove all spawned enemies"""
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

func get_current_encounter() -> CombatEncounter:
	"""Get the current encounter resource"""
	return current_encounter
