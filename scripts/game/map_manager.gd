# map_manager.gd - Map exploration scene manager
# Handles map nodes, player movement, and map-specific logic only.
# UI (menu, buttons, post-combat summary) is owned by GameRoot/PersistentUILayer.
extends Node2D

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var is_initialized: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================
var map_dice_panel: MapDicePanel = null

# ============================================================================
# SIGNALS
# ============================================================================
signal start_combat()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🗺️ MapScene _ready called")
	_find_map_nodes()
	print("🗺️ MapScene ready - waiting for initialization")

func _find_map_nodes():
	"""Find map-specific nodes in the scene tree"""
	print("🔍 Finding map nodes...")

	# Find MapDicePanel (if it lives in this scene)
	map_dice_panel = find_child("MapDicePanel", true, false)
	if map_dice_panel:
		print("  ✅ MapDicePanel found")
	else:
		print("  ⚠️ MapDicePanel not found")

func initialize_map(p_player: Player):
	"""Initialize with player reference"""
	print("🗺️ Initializing map with player")
	player = p_player
	is_initialized = true

	print("  Player HP: %d/%d" % [player.current_hp, player.max_hp])

	# Initialize MapDicePanel
	if map_dice_panel:
		map_dice_panel.initialize(player)
		print("  ✅ MapDicePanel initialized")

	print("🗺️ Map initialization complete")
