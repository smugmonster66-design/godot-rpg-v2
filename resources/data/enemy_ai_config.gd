# res://resources/data/enemy_ai_config.gd
# Tunable AI personality resource. Attach to EnemyData to override default
# scoring weights. Follows the AffixScalingConfig / RoleTierBudget pattern:
# a small, inspector-friendly Resource with @export_range sliders.
#
# When null on EnemyData, enemy_ai.gd uses hardcoded defaults equivalent to
# all sliders at 0.5.
extends Resource
class_name EnemyAIConfig

# ============================================================================
# ELEMENT AWARENESS
# ============================================================================
@export_group("Element Awareness")

## How strongly the AI prefers dice whose element matches the action's damage
## type. 0 = ignore elements entirely, 1 = heavily favour matching dice.
@export_range(0.0, 1.0, 0.05) var element_preference: float = 0.5

# ============================================================================
# SELF-PRESERVATION
# ============================================================================
@export_group("Self-Preservation")

## How aggressively the AI prioritises healing/defending when damaged.
## 0 = never boost heal score, 1 = large heal bonus at the slightest damage.
@export_range(0.0, 1.0, 0.05) var heal_urgency: float = 0.5

## HP% below which the heal/defend score bonus kicks in.
@export_range(0.1, 0.8, 0.05) var heal_threshold: float = 0.5

## HP% below which the heal bonus is at maximum strength.
@export_range(0.05, 0.5, 0.05) var critical_threshold: float = 0.3

# ============================================================================
# TACTICAL AWARENESS
# ============================================================================
@export_group("Tactical Awareness")

## How much the AI avoids wasting status-application actions on targets that
## already carry the status. 0 = happily reapply, 1 = strong score penalty.
@export_range(0.0, 1.0, 0.05) var status_awareness: float = 0.5

## How much the AI values synergy with allied enemies' applied statuses.
## Only used when team_aware is true on EnemyData.
## 0 = ignore ally statuses, 1 = strong bonus for combo follow-ups.
@export_range(0.0, 1.0, 0.05) var coordination_preference: float = 0.5
