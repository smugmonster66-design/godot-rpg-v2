# res://scripts/effects/combat_effect_target.gd
# Lightweight target descriptor for combat visual effects.
# Wraps different target types (die, action field, combatant, raw position)
# so CombatEffectPlayer can resolve any of them to a global position
# and optional CanvasItem reference for shader targeting.
#
# Usage:
#   var from = CombatEffectTarget.die(2)                    # hand die at slot 2
#   var to = CombatEffectTarget.enemy(0)                    # enemy slot 0 portrait
#   var at = CombatEffectTarget.action_field(my_field)      # action field center
#   var pos = CombatEffectTarget.position(Vector2(500, 300))# raw screen position
#   var node = CombatEffectTarget.node(any_control)         # any Control's center
#
#   await effect_player.play_scatter_converge(preset, from, to, appearance)
class_name CombatEffectTarget

# ============================================================================
# TARGET TYPE
# ============================================================================

enum TargetType {
	POSITION,       ## Raw Vector2 global position
	NODE,           ## Any Control or Node2D — uses center
	DIE,            ## Hand die by slot index — resolved via DicePoolDisplay
	ACTION_FIELD,   ## ActionField reference — uses center
	ENEMY_SLOT,     ## Enemy slot by index — uses portrait center
	PLAYER,         ## Player health/portrait area
}

# ============================================================================
# DATA
# ============================================================================

var type: TargetType = TargetType.POSITION
var global_pos: Vector2 = Vector2.ZERO      ## For POSITION type
var node_ref: Node = null                    ## For NODE, ACTION_FIELD types
var slot_index: int = -1                     ## For DIE, ENEMY_SLOT types

# ============================================================================
# STATIC CONSTRUCTORS
# ============================================================================

## Target a specific hand die by its slot index in the DicePoolDisplay.
static func die(p_slot_index: int) -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.DIE
	t.slot_index = p_slot_index
	return t


## Target an ActionField (uses its visual center).
static func action_field(field: ActionField) -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.ACTION_FIELD
	t.node_ref = field
	return t


## Target an enemy by their slot index in the EnemyPanel.
static func enemy(p_slot_index: int) -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.ENEMY_SLOT
	t.slot_index = p_slot_index
	return t


## Target the player (health bar / portrait area).
static func player() -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.PLAYER
	return t


## Target a raw global position.
static func position(pos: Vector2) -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.POSITION
	t.global_pos = pos
	return t


## Target any Control or Node2D node (uses its center).
static func node(p_node: Node) -> CombatEffectTarget:
	var t = CombatEffectTarget.new()
	t.type = TargetType.NODE
	t.node_ref = p_node
	return t


# ============================================================================
# DEBUG
# ============================================================================

func _to_string() -> String:
	match type:
		TargetType.POSITION:
			return "CombatEffectTarget(POSITION: %s)" % global_pos
		TargetType.NODE:
			return "CombatEffectTarget(NODE: %s)" % (node_ref.name if node_ref else "null")
		TargetType.DIE:
			return "CombatEffectTarget(DIE: slot %d)" % slot_index
		TargetType.ACTION_FIELD:
			var fname = node_ref.action_name if node_ref and "action_name" in node_ref else "?"
			return "CombatEffectTarget(ACTION_FIELD: %s)" % fname
		TargetType.ENEMY_SLOT:
			return "CombatEffectTarget(ENEMY: slot %d)" % slot_index
		TargetType.PLAYER:
			return "CombatEffectTarget(PLAYER)"
		_:
			return "CombatEffectTarget(UNKNOWN)"
