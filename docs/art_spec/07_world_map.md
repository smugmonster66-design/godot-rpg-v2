# 07: World Map

The world map is a large illustrated canvas that the player **pans and pinch-zooms (0.5× to 2×)**. It is dotted with location nodes; tapping a node opens the radial menu (icons in `02_ui_icons.md` §4).

- **Lighting, vignette, god rays and decor drop shadows are done by shaders.** Don't bake them in.
- The per-asset list is in [manifest/world.md](manifest/world.md).

> **Content warning:** both current maps are **test maps** ("Test World" and "The Docks"). The final region-1 layout (which locations, and where) should be agreed before painting backgrounds. The developer repositions nodes in the in-game map editor to fit the painting, not the other way round.

---

## 1. Map backgrounds (MAP)

| ID | Deliver as | Map | Source | Prio | Status |
|---|---|---|---|---|---|
| MAP-test_world_map | `assets/map_locations/backgrounds/map_test_world_map.png` | Region 1 overworld: the coast around **Embergate**, with the Crossroads, the Sanctum Navy's fortress ("Dungeon Testing Facility" / navy sanctum), Patrol Grounds, and the gate to the Docks | **3840×3840** | P1 | REDO (placeholder) |
| MAP-test_docks_zone | `assets/map_locations/backgrounds/map_test_docks_zone.png` | **The Docks** sub-zone: Dockside Camp, Harbor Watch Post | **3840×3840** (or 2160×3840 if the zone is narrow) | P1 | NEW |

| Spec | Value |
|---|---|
| Size limit | **Never larger than 4096** on either side (mobile GPU limit). The image size sets the pannable area |
| View | Top-down or high oblique (illustrated map), matching the decor kit |
| Zoom | At 1× the screen shows about 1080×1580 of the map; at 2× it shows about 540×790 upscaled. Keep **broad, readable shapes**, because fine texture goes soft at 2× |
| Clear zones | Leave space at each location for its landmark icon (§2), its node plate and a text label about 300 px wide under it |
| Top and bottom | The top **164 px** of the screen is covered by the top bar, and the bottom **342 px** by the HUD, so nothing important may sit only at the map's extreme top or bottom edge |
| Layers (master) | Keep terrain, water, paths and details on separate layers. Paths may be redrawn if nodes move |

## 2. Location icons and landmarks (LOC)

**Per-location landmark (8 rows):** see [manifest/world.md](manifest/world.md). **P1.**

| Spec | Value |
|---|---|
| Where shown | Location node on the map: an 80 px button drawn at half scale, so **40 px at 1× zoom and 80 px at 2×**. Sits on the node plate (§3) with the name label below |
| Source | **256×256**, transparent |
| Content | A miniature landmark of the place: a town silhouette for Embergate, a signpost for Crossroads, a fortress for the Navy sanctum, a tent for Dockside Camp, a watchtower for Harbor Watch, a camp for Patrol Grounds, a gate for the zone gate |
| Style | Same view and light as the background, so it looks painted **onto** the map, but with a clear silhouette to show it's tappable |

**Generic type icons (fallback)**: used when a location has no landmark. **P2.**

| ID | Deliver as | Type |
|---|---|---|
| LOC-TYPE-01…09 | `assets/map_locations/icons/loctype_{town,camp,dungeon,boss,event,shrine,treasure,crossroads,hidden}.png` | The nine location types (256×256) |

## 3. Node chrome (MAPN)

| ID | Deliver as | Use | Source | States | Prio | Status |
|---|---|---|---|---|---|---|
| MAPN-01 | `assets/map_locations/node/node_plate.png` | Ground plate or base under each location icon (currently a 64×38 placeholder ellipse) | 256×152 | one file (locked is greyed by code) | P1 | REDO |
| MAPN-02 | `assets/map_locations/node/node_selection_ring.png` | Ring showing the selected location, or the player's current location | 256×152 | one file (pulsed by code) | P1 | NEW |
| MAPN-03 | `assets/map_locations/node/node_fog.png` | Fog cloud over undiscovered (FOG-state) locations | 384×384 | one file | P2 | NEW (a plain rectangle today) |
| MAPN-04 | `assets/map_locations/node/label_plate.png` | Optional backing plate behind location names (9-slice, 24/12/24/12) | 256×48 | — | P3 | NEW |

## 4. Player map token (MAPT)

| ID | Deliver as | Use | Source | Prio | Status |
|---|---|---|---|---|---|
| MAPT-01 | `assets/spriteframes/map/player_token_idle.png` | Bones' marker standing at the current location. **Sprite sheet**: 8 frames in a row, 128×128 each (1024×128) | 1024×128 | P1 | REDO (uses an effect sheet) |
| MAPT-02 | `assets/spriteframes/map/player_token_walk.png` | Travelling between locations: 8 frames, 128×128. Faces right; mirroring for leftward travel is a code task (see appendix C-09) | 1024×128 | P2 | NEW |

## 5. Decor kit (MAPD)
The map editor can scatter decor sprites over the background. They get automatic drop shadows and are sorted by depth. **None are placed yet**, and the 44 Kenney placeholder structures in `assets/map_locations/test_map/structures/` are unused. **P3** (P2 if the background is painted simply).

| Spec | Value |
|---|---|
| Deliver as | `assets/map_locations/decor/decor_{name}.png` |
| Source | 256–512 px on the longest side, transparent, **no baked shadow** |
| Suggested set (coastal region 1) | Pine and oak trees (×3 variants each), rocks (×3), cliffs (×2), shrubs, a lighthouse (the story has a "lighthouse lit" flag), docks and piers, moored ships (×2), a navy warship, ruins, a watchtower, tents, a bridge, a signpost, gulls, and a fog bank (soft, semi-transparent) |
| Count | About 25–30 sprites |
