# rarity_colors.gd - Resource for defining rarity colors
extends Resource
class_name RarityColors

# ============================================================================
# RARITY COLOR CONFIGURATION
# ============================================================================
@export_group("Rarity Colors")
@export var common_color: Color = Color(0.7, 0.7, 0.7, 1.0)        # Gray
@export var uncommon_color: Color = Color(0.2, 0.8, 0.2, 1.0)      # Green
@export var rare_color: Color = Color(0.2, 0.5, 1.0, 1.0)          # Blue
@export var epic_color: Color = Color(0.7, 0.2, 0.9, 1.0)          # Purple
@export var legendary_color: Color = Color(1.0, 0.6, 0.0, 1.0)     # Orange/Gold

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_color_for_rarity(rarity_name: String) -> Color:
	"""Get color for a rarity name string"""
	match rarity_name.to_lower():
		"common": return common_color
		"uncommon": return uncommon_color
		"rare": return rare_color
		"epic": return epic_color
		"legendary": return legendary_color
		_: return common_color

func get_color_for_rarity_enum(rarity: int) -> Color:
	"""Get color for EquippableItem.Rarity enum value"""
	match rarity:
		0: return common_color      # COMMON
		1: return uncommon_color    # UNCOMMON
		2: return rare_color        # RARE
		3: return epic_color        # EPIC
		4: return legendary_color   # LEGENDARY
		_: return common_color
