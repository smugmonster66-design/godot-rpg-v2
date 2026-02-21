# res://scripts/combat/targeting_mode.gd
# Central enum for target selection overlay behavior.
#
# Determines how the UI highlights enemies/allies when an action is selected.
# Derived from an Action's effects array via Action.get_targeting_mode().
class_name TargetingMode

# ============================================================================
# TARGETING MODE — Which overlay pattern to show
# ============================================================================
enum Mode {
	NONE,            ## No targeting needed (passive, self-only with no choice)
	SELF_ONLY,       ## Highlight player only — auto-selects, no click needed
	SINGLE_ENEMY,    ## One enemy highlighted, click to switch
	ALL_ENEMIES,     ## All living enemies highlighted uniformly
	SPLASH_ENEMY,    ## Primary + adjacent secondary highlights
	CHAIN_ENEMY,     ## Primary + bounce preview on eligible targets
	PIERCE_ENEMY,    ## Primary + "behind" targets in formation
	SINGLE_ALLY,     ## One ally highlighted (companions + self), click to switch
	ALL_ALLIES,      ## All allies highlighted uniformly
	SINGLE_ANY,      ## Both panels active, click any combatant
}

# ============================================================================
# HIGHLIGHT TYPE — Per-slot visual state
# ============================================================================
enum HighlightType {
	NONE,            ## No highlight
	PRIMARY,         ## Bright pulsing yellow — the main target
	SECONDARY,       ## Dimmer pulse — splash/chain/pierce secondary targets
	AOE,             ## Uniform highlight — all targets hit equally
}

# ============================================================================
# SIDE — Which panel(s) are interactive
# ============================================================================
enum TargetSide {
	NONE,            ## No panel active
	ENEMY,           ## Enemy panel only
	ALLY,            ## Companion panel + self
	BOTH,            ## Both panels (rare — SINGLE_ANY)
}

# ============================================================================
# HELPERS
# ============================================================================

static func get_target_side(mode: Mode) -> TargetSide:
	match mode:
		Mode.NONE:
			return TargetSide.NONE
		Mode.SELF_ONLY:
			return TargetSide.ALLY
		Mode.SINGLE_ENEMY, Mode.ALL_ENEMIES, Mode.SPLASH_ENEMY, \
		Mode.CHAIN_ENEMY, Mode.PIERCE_ENEMY:
			return TargetSide.ENEMY
		Mode.SINGLE_ALLY, Mode.ALL_ALLIES:
			return TargetSide.ALLY
		Mode.SINGLE_ANY:
			return TargetSide.BOTH
	return TargetSide.NONE

static func allows_enemy_click(mode: Mode) -> bool:
	match mode:
		Mode.SINGLE_ENEMY, Mode.SPLASH_ENEMY, Mode.CHAIN_ENEMY, \
		Mode.PIERCE_ENEMY, Mode.SINGLE_ANY:
			return true
	return false

static func allows_ally_click(mode: Mode) -> bool:
	match mode:
		Mode.SINGLE_ALLY, Mode.SINGLE_ANY:
			return true
	return false

static func needs_primary_target(mode: Mode) -> bool:
	match mode:
		Mode.SINGLE_ENEMY, Mode.SPLASH_ENEMY, Mode.CHAIN_ENEMY, \
		Mode.PIERCE_ENEMY, Mode.SINGLE_ALLY, Mode.SINGLE_ANY:
			return true
	return false

static func get_label(mode: Mode) -> String:
	match mode:
		Mode.NONE: return ""
		Mode.SELF_ONLY: return "Self"
		Mode.SINGLE_ENEMY: return "Target Enemy"
		Mode.ALL_ENEMIES: return "All Enemies"
		Mode.SPLASH_ENEMY: return "Splash"
		Mode.CHAIN_ENEMY: return "Chain"
		Mode.PIERCE_ENEMY: return "Pierce"
		Mode.SINGLE_ALLY: return "Target Ally"
		Mode.ALL_ALLIES: return "All Allies"
		Mode.SINGLE_ANY: return "Target Any"
	return ""
