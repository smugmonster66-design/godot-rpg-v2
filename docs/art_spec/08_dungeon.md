# 08: Dungeon Runs

A dungeon run is a **vertical, Slay-the-Spire-style node map**: rows of rooms from the entrance at the bottom to the boss at the top, joined by curved paths. The player picks a route and taps rooms to fight, shop, rest and so on. Each room opens a popup built from the UI kit (`01_ui_chrome.md`).

- The per-asset list is in [manifest/dungeon.md](manifest/dungeon.md).
- Paths, fog and node glows are drawn by code.
- The older first-person corridor view (walls, doors, floor textures) is **retired and out of scope**.

---

## 1. Room node icons (DGN-NODE)
The same 9 icons are used in every dungeon.

| Spec | Value |
|---|---|
| Deliver as | `assets/dungeon/icons/{type}.png`. **Keep these exact names**: the code builds the path from the room type |
| Source | **256×256**, transparent |
| Where shown | On a circular node about 80 px across (a 40 px-radius plate with a glow), icon at **about 77 px**. States (visited, available, locked, current) are shown by the code with tint and glow |
| Readability | The 9 types must be told apart **at 48 px and in greyscale**, because locked rooms are greyed out |

| ID | File | Room type | Prio | Status |
|---|---|---|---|---|
| DGN-NODE-01 | `start.png` | Entrance | P0 | REDO |
| DGN-NODE-02 | `combat.png` | Normal fight | P0 | REDO |
| DGN-NODE-03 | `elite.png` | Elite fight (stronger, better loot) | P0 | REDO |
| DGN-NODE-04 | `boss.png` | Boss | P0 | REDO |
| DGN-NODE-05 | `shop.png` | Merchant | P0 | REDO |
| DGN-NODE-06 | `rest.png` | Rest site (heal or blessing) | P0 | REDO |
| DGN-NODE-07 | `event.png` | Random event ("?") | P0 | REDO |
| DGN-NODE-08 | `treasure.png` | Treasure chest | P0 | REDO |
| DGN-NODE-09 | `shrine.png` | Shrine (blessing plus curse) | P0 | REDO |

## 2. Node plate and player token (DGN-UI)

| ID | Deliver as | Use | Source | Prio | Status |
|---|---|---|---|---|---|
| DGN-UI-01 | `assets/dungeon/node/node_plate.png` | Round plate behind each room icon. **NEEDS HOOKUP**: currently a code-drawn circle. Greyscale so it can be tinted per state | 192×192 | P1 | NEW |
| DGN-UI-02 | `assets/dungeon/node/node_plate_boss.png` | Larger, ornate plate for the boss room | 256×256 | P2 | NEW |
| DGN-UI-03 | `assets/dungeon/node/player_token.png` | Bones' marker on the current room (currently a placeholder D4 die). A static sprite; the code handles the bob | 128×128 | P1 | REDO |
| DGN-UI-04 | `assets/dungeon/node/path_dot.png` | Optional texture for the paths between rooms (dotted trail), repeated along the path | 32×32 | P3 | NEW |

## 3. Per-dungeon art (DGN)
Listed per dungeon in [manifest/dungeon.md](manifest/dungeon.md). The current dungeons are **Sanctum Navy Fortress** (P1) and **Baseline Test** (P3, test content), plus the chain **"The Endless Test"**.

| Asset | Spec | Prio |
|---|---|---|
| **Dungeon icon** | Shown on the dungeon-selection list, **56 px**. Source 256×256, the dungeon's emblem or entrance. NEEDS HOOKUP (the list is not yet opened in-game) | P1 |
| **Map background** (NEEDS HOOKUP) | The backdrop behind the node map, 1080 wide and scrolling vertically. Deliver as **three pieces**: `_bottom.png` 1080×960 (the entrance, bottom of the run), `_tile.png` 1080×1024 (**tiles seamlessly top to bottom**, repeated to fit the number of floors), `_top.png` 1080×960 (the boss approach). Keep the central 700 px column low-contrast, because rooms and paths sit on it | P1 |
| **Node plate override** | Optional per-dungeon room plate, replacing DGN-UI-01 | P3 |

## 4. Events, shrines and run affixes

| Group | Count | Where shown | Source | Prio |
|---|---|---|---|---|
| **Event illustrations** (DEV) | 6 (Navy events: e.g. Storm Warning) | Header image at the top of the event popup, about 320×160. **NEEDS HOOKUP** | 640×320 | P2 |
| **Shrine icons** (DSH) | 4 | Shrine popup header, about 128 px. The shrine grants a blessing and a curse, so its motif can suggest both. **NEEDS HOOKUP** | 256×256 | P2 |
| **Run-affix icons** (RAF) | 12 | Cards on the "choose a run affix" screen, **64 px**, full colour. The card shows rarity separately | 128×128 | P2 |

## 5. Node-type popup banners (optional, DGN-BAN)
There's one popup per room type (rest, shop, treasure, shrine, dungeon complete). An optional header illustration makes each room feel distinct: `assets/dungeon/banners/banner_{rest,shop,treasure,shrine,complete}.png`, **640×320**, **P3**, **NEEDS HOOKUP**.
