# Dungeon Editor Plugin

Visual graph editor for building **Slay-the-Spire-style** dungeon floors in the Godot Editor.

## Setup

1. **Copy files** into your project:
   - `addons/dungeon_editor/` → `res://addons/dungeon_editor/`
   - `resources/data/dungeon/` → `res://resources/data/dungeon/`
   - `editor_scripts/generate_sample_dungeon.gd` → `res://editor_scripts/`
   - `editor_scripts/test_dungeon_system.gd` → `res://editor_scripts/`

2. **Enable the plugin**: Project → Project Settings → Plugins → **Dungeon Editor** → ✅ Enable

3. **Open the editor**: Click the **"Dungeon Editor"** tab in the bottom panel (next to Output, Debugger, etc.)

## Quick Start

1. Click **"New"** to create an empty dungeon, or **"Generate Template"** to auto-build a standard floor
2. Use the **colored buttons** in the node type bar to add nodes (⚔️ Combat, 💀 Elite, 🛒 Shop, etc.)
3. **Drag connections** from one node's output port (right) to another's input port (left)
4. **Select nodes** to edit their properties in the right sidebar
5. Click **"Save"** to export as a `.tres` resource file

## Data Resources

### DungeonConfig (`dungeon_config.gd`)
Top-level container. Holds an ordered list of `DungeonFloor` resources plus dungeon-wide settings (region, encounter pools, loot tables, completion rewards).

### DungeonFloor (`dungeon_floor.gd`)  
One floor/level. Contains an array of `DungeonNodeData` resources that form a connected graph. Provides traversal helpers (`get_reachable_from()`, `get_nodes_in_row()`) and full validation with reachability analysis.

### DungeonNodeData (`dungeon_node_data.gd`)
A single room/node. Supports 10 node types:

| Type | Icon | Purpose |
|------|------|---------|
| COMBAT | ⚔️ | Standard enemy encounter |
| ELITE | 💀 | Harder fight, better rewards |
| BOSS | 👹 | Floor boss, must defeat to proceed |
| EVENT | ❓ | Random event / dialogue choice |
| SHOP | 🛒 | Buy/sell items |
| REST | 🔥 | Heal, upgrade, or cleanse |
| TREASURE | 💎 | Free loot chest |
| ENTRANCE | 🚪 | Starting node (auto-generated) |
| EXIT | 🏁 | Floor exit (auto-generated) |
| MYSTERY | ❔ | Unknown until visited |

Each type has dedicated `@export` fields (encounter pools, shop config, rest healing %, etc.) editable in both the plugin sidebar and the Inspector.

## Editor Features

- **Visual GraphEdit** with color-coded nodes and connection drawing
- **Properties sidebar** with type-specific editors (combat encounters, shop config, rest settings, etc.)
- **Floor selector** to switch between floors in a multi-floor dungeon
- **Auto-Layout** arranges nodes in a clean grid by row/column
- **Generate Template** creates a standard 7-row StS layout with entrance → branching paths → boss
- **Validation** checks for missing encounters, unreachable nodes, duplicate IDs, and dangling connections
- **Save/Load** as standard Godot `.tres` resources

## Editor Scripts

### `generate_sample_dungeon.gd`
Run via **Editor → Script → Run** to create a sample 2-floor "Whispering Woods" dungeon at `res://resources/dungeons/`. Wires up connections and populates encounter pools from existing goblin encounters.

### `test_dungeon_system.gd`
Run via **Editor → Script → Run** to execute the full test suite covering node creation, floor traversal, validation, mystery resolution, encounter picking, and reachability analysis.

## Integration with Existing Systems

The dungeon resources integrate with your existing architecture:

- **CombatEncounter**: Dragged into `encounter_pool` arrays on COMBAT/ELITE/BOSS nodes
- **LootTable**: Referenced by `shop_loot_table`, `treasure_loot_table`, and `completion_loot_table` string IDs
- **AffixScalingConfig**: Region/level settings on floors drive item level scaling through the existing pipeline
- **GameManager**: `start_combat_encounter()` reads from `DungeonNodeData.pick_encounter()`

## Runtime (Future)

The data resources are designed for a future `DungeonRunner` system that:
1. Loads a `DungeonConfig` and presents the floor map
2. Lets the player select available nodes (using `DungeonNodeData.is_available`)
3. Resolves MYSTERY nodes via `resolve_mystery()`
4. Triggers encounters via `pick_encounter()` → `GameManager.start_combat_encounter()`
5. Tracks visited state and advances through floors
