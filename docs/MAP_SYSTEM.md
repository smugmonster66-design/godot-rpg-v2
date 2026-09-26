# Map System Guide

This guide covers how to create, configure, and edit maps using the in-game map editor and Godot inspector.

---

## Quick Start

1. Create a **MapDefinition** resource (`.tres`) and give it a `map_id` and `display_name`
2. Create one or more **LocationNode** resources for the places on your map
3. Drag them into the MapDefinition's `location_nodes` array
4. Set `starting_location_id` to the location the player begins at
5. Assign a `background_texture` (any size image works)
6. Point your GameRoot's `starting_map` export to your MapDefinition
7. Run the game — your map is live

Everything else below is optional polish.

---

## The Map Definition

Found at: **Resources > data > map_definition.gd**
Create new ones via: **Right-click in FileSystem > New Resource > MapDefinition**

### Identity

| Property | What it does |
|----------|-------------|
| `map_id` | Unique name for this map (e.g. `&"region_ashlands"`) |
| `display_name` | Human-readable name shown in the UI |
| `region_id` | Optional grouping tag for unlock logic |

### Content

| Property | What it does |
|----------|-------------|
| `location_nodes` | Array of LocationNode resources — every place on this map |
| `starting_location_id` | Where the player spawns on first entry. Leave blank to use the first node in the array |
| `return_location_id` | Where the player ends up when leaving a sub-map back to this one |

### Background

| Property | What it does |
|----------|-------------|
| `background_texture` | The map image. Can be any size — the system adapts zoom limits and pan boundaries automatically |
| `ambient_music_id` | Background music track ID |

### Unlock

| Property | What it does |
|----------|-------------|
| `unlock_condition` | A GameCondition that must be met before the player can enter this map |
| `locked_hint` | Text shown when the condition isn't met (e.g. "Complete the first quest") |

---

## Location Nodes

Found at: **Resources > data > location_node.gd**
These are the places on your map — towns, dungeons, crossroads, etc.

### Identity & Type

| Property | What it does |
|----------|-------------|
| `location_id` | Unique ID (e.g. `&"loc_embergate"`) |
| `display_name` | Name shown on the map and in menus |
| `node_type` | High-level category that affects the default icon style. Options: `TOWN`, `CAMP`, `DUNGEON`, `BOSS`, `EVENT`, `SHRINE`, `TREASURE`, `CROSSROADS`, `HIDDEN` |
| `map_node_category` | Controls the icon shape/style on the map button. Options: `TOWN`, `DUNGEON`, `ENCOUNTER`, `ZONE`, `OTHER` |

### Position

| Property | What it does |
|----------|-------------|
| `map_position` | Where this node sits on the map image, in pixel coordinates. You can set this by hand or drag it in the in-game editor |
| `depth_layer` | Visual layer for parallax effects (higher = further back) |

### Connections

| Property | What it does |
|----------|-------------|
| `connections` | List of location IDs this node connects to in both directions |
| `one_way_connections` | List of location IDs the player can travel TO from here, but not back |
| `connected_node_resources` | Inspector shortcut — drag LocationNode `.tres` files here instead of typing IDs. These get synced to `connections` |
| `one_way_connected_node_resources` | Same shortcut for one-way connections |

Connections appear as lines on the map. Bidirectional paths are drawn in muted gold; one-way paths are brighter orange.

### Visibility & Unlock

| Property | What it does |
|----------|-------------|
| `initial_visibility` | Starting state: `VISIBLE` (always shown), `HIDDEN` (invisible until revealed), or `FOG` (shows a "?" icon until visited) |
| `reveal_condition` | Condition that reveals a HIDDEN node |
| `unlock_condition` | Condition that must be met before the player can travel here |
| `locked_hint` | Text shown when the node is locked (e.g. "Requires Level 10") |

### Content

| Property | What it does |
|----------|-------------|
| `radial_buttons` | Array of MapNodeButtonDef resources — the actions available when the player taps this node (enter dungeon, talk to NPCs, rest, etc.) |
| `npc_ids` | NPCs present at this location |
| `shop_ids` | Shops available here |
| `available_quest_ids` | Quests that can start here |
| `encounter_table_id` | Random encounter table for this location |
| `first_visit_dialogue` | Dialogue triggered on first visit |
| `visit_dialogue` | Dialogue triggered on subsequent visits |

### Events

| Property | What it does |
|----------|-------------|
| `on_first_visit_events` | Event tags fired the first time the player arrives |
| `on_visit_events` | Event tags fired every time the player arrives |
| `set_flags_on_visit` | Story flags automatically set when visited |

### Visual

| Property | What it does |
|----------|-------------|
| `map_icon` | Custom icon texture for this node's button on the map |
| `node_circle_texture` | Custom base plate texture (the circle behind the icon). Leave blank to use the default |

### Gameplay

| Property | What it does |
|----------|-------------|
| `recommended_level` | Suggested player level (shown in UI) |
| `allows_rest` | Whether the player can rest here |
| `safe_zone` | If true, no random encounters |

---

## Radial Menu Buttons

Found at: **Resources > data > map_node_button_def.gd**
These define what happens when the player taps a location node.

| Property | What it does |
|----------|-------------|
| `button_category` | The action type. Options: `QUESTS` (open quest list), `NPCS` (show NPC menu), `ENTER_DUNGEON` (start a dungeon run), `ENTER_ZONE` (travel to a sub-map), `REST` (heal the player), `PARTY` (companion management), `TRAVEL` (auto-injected, moves the player) |
| `label` | Custom button text. Leave blank to use the default for that category |
| `icon` | Button icon texture |
| `tooltip` | Hover/long-press tooltip text |
| `condition` | GameCondition for showing/enabling this button |
| `hide_when_condition_fails` | If true, the button is hidden when condition fails instead of greyed out |
| `dungeon_definition` | The dungeon to enter (for ENTER_DUNGEON buttons) |
| `dungeon_chain` | A chain of dungeons (takes priority over single dungeon) |
| `sub_map` | The MapDefinition to load (for ENTER_ZONE buttons) |
| `rest_cost_gold` | Gold cost to rest (0 = free) |
| `rest_heal_percent` | Fraction of max HP restored (0.5 = 50%) |

---

## Decor Items

Found at: **Resources > data > map_decor_item.gd**
Decorative elements placed on the map — trees, rocks, fog patches, ruins, etc.

| Property | What it does |
|----------|-------------|
| `texture` | The image to display |
| `position` | Location on the map in pixel coordinates |
| `rotation_deg` | Rotation in degrees |
| `item_scale` | Size multiplier (1,1 = original size) |
| `tint` | Color tint applied to the texture. White = no tint |
| `z_offset` | Draw order within the decor layer (higher = on top of other decor) |
| `flip_h` | Flip the texture horizontally |

Decor items live in the MapDefinition's `decor_items` array. You can add them via the inspector or with the in-game editor's **Decor** tool.

---

## Lighting

The lighting system uses a shader overlay to create atmosphere — darkness, point lights, and vignette effects. It sits on top of everything (background, paths, decor, nodes, player marker) and tints the whole scene.

### Lighting Config

Found at: **Resources > data > map_lighting_config.gd**
Assigned to your MapDefinition's `lighting_config` property. If left as `null`, no lighting is applied.

| Property | What it does |
|----------|-------------|
| `ambient_color` | The color and intensity of the overall darkness tint. The RGB channels control the hue (purple, blue, black, etc.) and the alpha channel controls how opaque it is. `0.0` alpha = no dimming, `0.8` = very dark. Default is a dark purple at 60% |
| `vignette_strength` | How much the screen edges darken (0 = none, 1 = heavy). Creates a natural focus toward the center |
| `vignette_softness` | How gradually the vignette fades in (0.1 = sharp edge, 1.0 = very soft gradient) |
| `lights` | Array of MapLightEntry resources — the point lights on your map |

#### Common ambient_color recipes

| Feel | Color value |
|------|-------------|
| Neutral darkness | `Color(0.0, 0.0, 0.0, 0.5)` |
| Cool night | `Color(0.05, 0.05, 0.15, 0.6)` |
| Purple dusk (default) | `Color(0.15, 0.1, 0.2, 0.6)` |
| Warm sunset | `Color(0.15, 0.08, 0.02, 0.5)` |
| Light fog | `Color(0.2, 0.2, 0.2, 0.3)` |
| Deep dungeon | `Color(0.02, 0.02, 0.05, 0.85)` |

### Point Lights

Found at: **Resources > data > map_light_entry.gd**
These punch through the ambient darkness in a circular area.

| Property | What it does |
|----------|-------------|
| `position` | Where the light is on the map, in pixel coordinates |
| `color` | The light's color. Warm orange for torches, blue for magic, green for swamp, etc. |
| `radius` | How far the light reaches in map pixels. Bigger = wider pool of light |
| `energy` | Intensity multiplier (0.0 to 3.0). At 1.0 the light fully removes the ambient darkness at its center. Above 1.0 it brightens beyond neutral. Below 1.0 it only partially cuts through |

**Limit:** Up to 8 point lights per map. The shader supports a fixed array of 8 — if you add more to the array, only the first 8 are used.

### How lighting affects the map

The lighting overlay sits on top of all map content in the scene tree. It works like a tinted film:

- Areas with no nearby lights appear dimmed by the `ambient_color`
- Areas near a light have the dimming removed, revealing the natural colors of whatever is underneath (background, decor, location icons, paths, player marker)
- The lighting does not cast shadows — decor items don't block light from reaching things behind them

---

## Curved Paths (Waypoints)

Connections between nodes are straight lines by default. You can add **waypoints** to create curved paths using Catmull-Rom splines.

Waypoint data is stored in the MapDefinition's `connection_waypoints` dictionary. You don't need to edit this by hand — the in-game editor handles it.

### How the curves work

- Each waypoint is a control point that the path must pass through
- The system generates smooth curves using Catmull-Rom interpolation with ghost endpoints
- The player marker follows the curved path when traveling (not a straight line)
- More waypoints = more control over the path shape

---

## The In-Game Map Editor

The editor is only available in **debug builds**. An "Edit Map" button appears in the top-right corner.

### Toolbar

When you enter edit mode, a toolbar appears at the top of the screen with these tools:

| Button | What it does |
|--------|-------------|
| **+ Node** | Click anywhere on the map to place a new location node |
| **Connect** | Click two nodes in sequence to create a connection between them. A dialog asks if it should be bidirectional or one-way |
| **Decor** | Click to place decor items, drag to move them, right-click to delete or adjust |
| **Lighting** | Click to place point lights, drag to move them, right-click to delete |
| **Save All** | Saves all modified resources to disk. Shows a `*` when there are unsaved changes |
| **Discard** | Reverts unsaved changes |
| **Exit Edit** | Leaves edit mode |

The toolbar wraps its buttons if they would extend past the screen edges.

### Editing nodes

- **Select tool (default):** Click and drag a node to reposition it. Its `map_position` updates live
- **Right-click a node:** Opens a context menu to delete it (also removes all its connections and waypoints)

### Editing paths

- **Select tool:** Click on a connection line to insert a waypoint at that point. Drag the waypoint handle to shape the curve
- **Right-click a connection:** Context menu with options to delete the connection or clear all its waypoints

### Editing decor (Decor tool active)

- **Click empty space:** Places a new decor item (you'll need to assign a texture via the inspector or the context menu)
- **Click and drag:** Repositions an existing decor item
- **Right-click:** Context menu with delete and rotate options

### Editing lights (Lighting tool active)

- **Click empty space:** Places a new point light with default warm color and 200px radius
- **Click and drag:** Repositions an existing light
- **Right-click:** Context menu with delete and adjustment options

### Saving

Changes are only persisted when you click **Save All**. This writes modified `.tres` files to disk using Godot's `ResourceSaver`. If you close the game without saving, changes are lost.

---

## Camera & Navigation

### Panning

- **Right-click and drag** (or middle-click drag) to pan the map
- In normal play, panning is clamped so you can never scroll past the edges of the background texture
- In dev mode, panning is unclamped for full editor access

### Zooming

- **Scroll wheel** to zoom in and out, centered on the cursor position
- In normal play, the minimum zoom is calculated dynamically so the background always fills the entire screen — you can never zoom out far enough to see empty space
- In dev mode, the zoom floor drops to 0.4x for full map overview
- Maximum zoom is 2.0x

### Camera follow

- **On map load:** The camera centers on the player's current location
- **During travel:** The camera smoothly follows the player marker with an exponential ease. It starts soft and catches up gradually
- **After travel:** The camera stops following and you can pan freely

### Tunable parameters

These are `@export` properties on the MapScene node in `map_scene.tscn`:

| Property | Default | What it does |
|----------|---------|-------------|
| `travel_speed` | 800.0 | How fast the player marker moves along paths, in pixels per second. Lower = slower, more cinematic travel. Higher = snappier |
| `camera_follow_speed` | 3.0 | How quickly the camera catches up to the player during travel. Range 1.0–10.0. Lower values (1.5–2.0) give a lazy, cinematic pan. Higher values (6.0+) track almost instantly |

---

## Sub-Maps (Zones)

Maps can contain zones that lead to other maps, creating a hierarchy.

1. Create a second MapDefinition for the sub-map
2. On the parent map, create a **MapNodeButtonDef** with `button_category = ENTER_ZONE` and assign the sub-map to `sub_map`
3. Add that button to a LocationNode's `radial_buttons`
4. Set the sub-map's `return_location_id` to the location the player should return to when leaving

When the player enters a zone, the map view swaps to the sub-map. A "< Leave Zone" button appears to go back. The system maintains a map stack, so zones can nest.

---

## Dev Mode

Toggle `dev_mode` on the **GameRoot** node in the inspector. When enabled:

- Zoom and pan restrictions are removed so you can see the full map and pan freely
- Useful for editing large maps where you need to see and reach areas beyond what the player would normally view

Dev mode also applies other game-wide overrides (player level, starting items, etc.) — see the GameRoot inspector for the full list.

---

## Scene Tree Reference

```
MapScene (Control, map_scene.gd)
  MapContent (Control) ................... panned/zoomed container
    MapBackground (TextureRect) .......... your background_texture
    PathsDrawer (Control) ................ draws connection lines & curves
    DecorLayer (Control) ................. holds decor TextureRect children
    NodesLayer (Control) ................. holds MapNodeButton instances
    MarkersLayer (Control)
      PlayerMarker (Control) ............. animated player position
        MarkerDot (ColorRect) ............ blue 32x32 dot
    LightingOverlay (ColorRect) .......... shader-based atmospheric lighting
  UILayer (CanvasLayer, layer 10)
    LeaveZoneButton (Button) ............. shown in sub-maps only
```

Everything under **MapContent** moves together when you pan or zoom. The **UILayer** stays fixed on screen.

---

## File Organization

| What | Where |
|------|-------|
| Map definitions | `resources/maps/{region}/` |
| Location nodes | `resources/maps/{region}/` (alongside their map) |
| Radial button defs | `resources/maps/{region}/` |
| Map background textures | `assets/maps/` or wherever you keep art |
| Decor textures | `assets/maps/decor/` |
| Map scene | `scenes/game/map_scene.tscn` |
| Map scene script | `scripts/game/map_scene.gd` |
| Map editor toolbar | `scripts/ui/map/map_editor_toolbar.gd` |
| Path drawer | `scripts/ui/map/map_paths_drawer.gd` |
| Node button | `scripts/ui/map/map_node_button.gd` |
| MapManager autoload | `scripts/autoload/map_manager.gd` |
| Data classes | `resources/data/map_definition.gd`, `location_node.gd`, `map_decor_item.gd`, `map_lighting_config.gd`, `map_light_entry.gd`, `map_node_button_def.gd` |
| Lighting shader | `shaders/map_lighting.gdshader` |
