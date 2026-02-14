extends Resource
class_name DungeonDefinition

# ============================================================================
# IDENTITY
# ============================================================================
@export var dungeon_name: String = "New Dungeon"
@export var dungeon_id: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================================
# STRUCTURE
# ============================================================================
@export_group("Structure")
@export_range(6, 15) var floor_count: int = 10
@export var dungeon_level: int = 10
@export_range(1, 6) var dungeon_region: int = 1

# ============================================================================
# ENCOUNTER POOLS
# ============================================================================
@export_group("Encounters")
@export var combat_encounters: Array[CombatEncounter] = []
@export var elite_encounters: Array[CombatEncounter] = []
@export var boss_encounters: Array[CombatEncounter] = []

# ============================================================================
# EVENT / SHRINE POOLS
# ============================================================================
@export_group("Events & Shrines")
@export var event_pool: Array[DungeonEvent] = []
@export var shrine_pool: Array[DungeonShrine] = []

# ============================================================================
# LOOT & ECONOMY
# ============================================================================
@export_group("Loot & Economy")
@export var loot_pool: Array[EquippableItem] = []
@export var shop_pool: Array[EquippableItem] = []
@export var rest_affix_pool: Array[DiceAffix] = []
@export var gold_per_combat: int = 15
@export var gold_per_elite: int = 30
@export var exp_per_combat: int = 20
@export var exp_per_elite: int = 50

# ============================================================================
# FIRST CLEAR BONUS
# ============================================================================
@export_group("First Clear")
@export var first_clear_item: EquippableItem = null
@export var first_clear_gold: int = 100
@export var first_clear_exp: int = 200

# ============================================================================
# THEMING (corridor visuals — textures dragged in Inspector)
# ============================================================================
@export_group("Theme")
@export var wall_texture: Texture2D = null
@export var door_texture: Texture2D = null
@export var floor_texture: Texture2D = null
@export var fog_color: Color = Color(0.1, 0.08, 0.15, 1.0)
@export var ambient_color: Color = Color(0.8, 0.7, 0.6, 1.0)
@export var torch_color: Color = Color(1.0, 0.7, 0.3, 1.0)

# ============================================================================
# MAP VISUALS (Slay the Spire-style flowchart map)
# ============================================================================
@export_group("Map Visuals")
@export var map_background: Texture2D = null       ## cross-section stone/earth bg
@export var map_node_backing: Texture2D = null     ## chamber circle behind icons
@export var map_path_color: Color = Color(0.55, 0.45, 0.3, 0.7)
## 0 = desaturate (dim locked nodes), 1 = hard fog (hide behind overlay)
@export_range(0, 1) var map_fog_mode: int = 0
# Under @export_group("Theme"), add alongside existing entries:
@export var side_wall_texture: Texture2D = null
@export var ceiling_texture: Texture2D = null
@export var frame_texture: Texture2D = null


# ============================================================================
# FLOOR LAYOUT RULES
# ============================================================================
@export_group("Floor Rules")
@export_range(1, 4) var min_nodes_per_floor: int = 2
@export_range(1, 4) var max_nodes_per_floor: int = 3
@export var safe_floor_before_boss: bool = true
@export var mid_safe_floor: bool = true

# ============================================================================
# HELPERS — all item creation goes through LootManager pipeline
# ============================================================================

func get_mid_floor() -> int:
	return floor_count / 2

func get_random_combat() -> CombatEncounter:
	if combat_encounters.size() == 0: return null
	return combat_encounters[randi() % combat_encounters.size()]

func get_random_elite() -> CombatEncounter:
	if elite_encounters.size() == 0: return null
	return elite_encounters[randi() % elite_encounters.size()]

func get_random_boss() -> CombatEncounter:
	if boss_encounters.size() == 0: return null
	return boss_encounters[randi() % boss_encounters.size()]

func get_random_event(floor_num: int) -> DungeonEvent:
	var valid: Array[DungeonEvent] = []
	for event in event_pool:
		if event.is_valid_for_floor(floor_num):
			valid.append(event)
	if valid.size() == 0: return null
	return valid[randi() % valid.size()]

func get_random_shrine() -> DungeonShrine:
	if shrine_pool.size() == 0: return null
	return shrine_pool[randi() % shrine_pool.size()]

func generate_loot_item() -> EquippableItem:
	if loot_pool.size() == 0: return null
	var template = loot_pool[randi() % loot_pool.size()]
	var result = LootManager.generate_drop(template, dungeon_level, dungeon_region)
	return result.get("item") as EquippableItem

func generate_shop_item() -> EquippableItem:
	if shop_pool.size() == 0: return null
	var template = shop_pool[randi() % shop_pool.size()]
	var result = LootManager.generate_drop(template, dungeon_level, dungeon_region)
	return result.get("item") as EquippableItem

func generate_first_clear_item() -> EquippableItem:
	if not first_clear_item: return null
	var result = LootManager.generate_drop(first_clear_item, dungeon_level, dungeon_region)
	return result.get("item") as EquippableItem

func validate() -> Array[String]:
	var warnings: Array[String] = []
	if dungeon_id == "": warnings.append("Missing dungeon_id")
	if combat_encounters.size() == 0: warnings.append("No combat encounters")
	if boss_encounters.size() == 0: warnings.append("No boss encounters")
	if floor_count < 6: warnings.append("Floor count below minimum (6)")
	return warnings
