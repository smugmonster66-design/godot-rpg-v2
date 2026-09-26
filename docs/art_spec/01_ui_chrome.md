# 01: UI Chrome Kit

Every screen is built from one **shared kit**. Draw each piece once; the game reuses it everywhere. Each piece lists the screens that use it, so you can see how far it has to stretch.

Before starting, read the README sections on **9-slice rules** (9-slice art is delivered at **1× on-screen scale**) and **button states**.

Status legend: **REDO** means it's currently a placeholder texture. **NEW** means it's currently a flat colour box drawn in code, or nothing at all.

---

## 1. Panels (UI-PNL)

| ID | Deliver as | Used by | On-screen size range | Source | 9-slice L/T/R/B | States / variants | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-PNL-01 | `assets/ui/panels/panel_modal.png` | **Main popup frame.** Item info (85% screen height), smithing (75%), stash (90%), companion info, party management, dungeon selection (480×500), post-combat summary (650 wide), consumable die select (420 wide), all dungeon popups (340×200 to 420×300), skill popup (400×500), confirmation dialog (400×200) | 340×200 → 1000×1630 | 256×256 | 48/48/48/48 (corners must fit the **340×200** minimum) | — | | P0 | NEW |
| UI-PNL-02 | `assets/ui/panels/panel_menu.png` | Player-menu content area (Character, Skills, Companions, Inventory, Quests tabs), below the tab bar | ~1000×1500 | 400×400 | 66/48/48/48 (current values; may change) | — | | P0 | REDO (`9P plain new 400x400.png`) |
| UI-PNL-03 | `assets/ui/panels/panel_card.png` + `_selected` + `_disabled` | List cards: dungeon-selection rows (h 80), run-affix choice cards (h 100), loot/treasure cards (140×60), companion cards, quest detail panel, shop rows | 140×60 → 1000×120 | 128×128 | 20/20/20/20 | normal, selected (highlighted border), disabled/locked (dimmed) | | P1 | NEW |
| UI-PNL-04 | `assets/ui/panels/panel_tooltip.png` | Die tooltip, status tooltip, generic tooltips (min 216×256, 400 wide) | 216×120 → 400×600 | 128×128 | 24/24/24/24 | — | | P1 | NEW |
| UI-PNL-05 | `assets/ui/panels/panel_hud_bottom.png` | Persistent bottom HUD behind the portrait, bars, dice grid and buttons | 1080×342 (wider on wide phones) | 1080×360 | **L/R only**: 120/0/120/0, so it stretches horizontally | — | | P0 | REDO (`9patch_bones.png`) |
| UI-PNL-06 | `assets/ui/panels/panel_nameplate.png` | Enemy name under each enemy portrait | 189×101 | 192×104 | 16/24/16/24 | — | | P0 | REDO (`panel_red.png`) |
| UI-PNL-07 | `assets/ui/panels/ribbon_header.png` | Map top bar showing the current location name. The ribbon hangs 40 px below the bar | 1080×72 (+40 overhang) | 1080×112 | 100/0/100/40 | — | | P1 | REDO (`headerBow_yellow.png`) |
| UI-PNL-08 | `assets/ui/panels/ribbon_notification.png` | Map notification banner under the top bar (32 px icon + one line of text) | ~900×52 | 512×80 | 48/28/48/12 | — | | P1 | REDO (`notebook_yellow.png`) |
| UI-PNL-09 | `assets/ui/panels/panel_section_header.png` | Section headers inside menus ("Stats", "Equipment", "Party"…) and popup title strips | 300×48 → 1000×60 | 256×64 | 32/0/32/0 | — | | P2 | NEW |
| UI-PNL-10 | `assets/ui/panels/panel_inset.png` + `_hover` + `_filled` | Recessed "well" areas: dice pool tray (700×180), enemy dice hand, consumable die drop zone (h 200), shop row bodies | 200×64 → 1000×200 | 128×128 | 24/24/24/24 | normal, hover (drop target), filled | | P1 | NEW |

> **Overlay dimmers** (the black overlay behind popups) are drawn by code. No art is needed.

---

## 2. Buttons (UI-BTN)

All states go on the same canvas. The text is drawn by the game, so **don't put text in the art**. Leave the centre clear for labels at 28–40 px.

| ID | Deliver as | Used by | On-screen size | Source | 9-slice L/T/R/B | States | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-BTN-01 | `assets/ui/buttons/btn_primary_{state}.png` | Positive actions: Confirm, Begin, Continue, Collect, Learn, Upgrade, Rest, Accept, Buy, Return to Map | 120–400 × 44–64 | 192×64 | 24/20/24/24 | normal, hover, pressed, disabled, focus (overlay) | | P0 | NEW |
| UI-BTN-02 | `assets/ui/buttons/btn_secondary_{state}.png` | Neutral or negative actions: Cancel, Close, Back, Skip, Decline, End Turn, MENU | 120–300 × 40–64 | 192×64 | 24/20/24/24 | same as BTN-01 | | P0 | NEW |
| UI-BTN-03 | `assets/ui/buttons/btn_danger_{state}.png` | Destructive actions: Salvage, confirm-destroy, Escape | 120–300 × 44–64 | 192×64 | 24/20/24/24 | same as BTN-01 | | P2 | NEW |
| UI-BTN-04 | `assets/ui/buttons/btn_roll_{state}.png` | **"ROLL THE BONES!"**, the main call to action in the bottom HUD at the start of each turn | ~400×96 | 440×112 | 48/32/48/32 | normal, hover, pressed, disabled | | P0 | NEW |
| UI-BTN-05 | `assets/ui/buttons/btn_square_{state}.png` | Square icon buttons: action-field Confirm/Cancel (~96), inventory category filters (100×100), the mana-die selector's 4 arrow buttons (48×48). An icon from `02_ui_icons.md` sits on top | 48 → 100 | 96×96 | 24/12/12/12 (current stone button: 23/10/10/10) | normal, hover, pressed, disabled, **selected** (as a filter toggle) | | P0 | REDO (`inv_button_base_stone.png`) |
| UI-BTN-06 | `assets/ui/buttons/btn_list_{state}.png` | Full-width text rows: dungeon event choices, rest blessing options, quest list headers (h 52), shop "Buy" rows, companion list entries | 300–1000 × 44–64 | 256×64 | 20/16/20/16 | normal, hover, pressed, disabled, selected | | P1 | NEW |
| UI-BTN-07 | `assets/ui/buttons/btn_radial_{state}.png` | World-map radial menu. The circle sits behind a 160 px category icon | 256×256 | 256×256 (not 9-slice) | — | normal, pressed, disabled/locked, **new-content** (optional glow ring) | | P1 | REDO (`buttonCircle_black.png` 219×236) |
| UI-BTN-08 | `assets/ui/buttons/btn_close_{state}.png` | Small "X" close button in popup corners (**NEEDS HOOKUP**: popups currently use a text "Close" button) | 64×64 | 64×64 | — | normal, pressed | | P2 | NEW |
| UI-BTN-09 | `assets/ui/buttons/btn_back_{state}.png` | Map "Leave zone" (140×40) and radial menu "Back" (120×40): a small pill | 120–140 × 40 | 160×48 | 20/12/20/12 | normal, pressed | | P2 | NEW |

---

## 3. Tabs and toggles (UI-TAB)

| ID | Deliver as | Used by | On-screen size | Source | 9-slice | States | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-TAB-01 | `assets/ui/tabs/tab_main_{state}.png` | Player-menu tab bar: 5 tabs (Character, Skills, Companions, Inventory, Quests) in a 916×130 strip. A 128 px icon sits on top | ~180×130 | 184×136 (not 9-slice) | — | normal, pressed, **selected**, disabled | | P0 | REDO (`tab_tombstone_smallest.png`; has no selected state) |
| UI-TAB-02 | `assets/ui/tabs/tab_tree_{state}.png` | Skills tab: 3 skill-tree tabs (Flame / Frost / Storm), icon + name | 310×~96 | 96×96 | 15/5/15/15 (current) | normal, pressed, **selected** | | P1 | REDO (`skill_tab_button_base_stone.png`) |
| UI-TAB-03 | `assets/ui/tabs/toggle_pill_{state}.png` | Text filter toggles: quest filters (Active / Completed / Bounties, h 44), smithing and stash category tabs (text, 5 columns) | 120–200 × 44–56 | 128×56 | 24/16/24/16 | normal, pressed, **selected** | | P1 | NEW |

---

## 4. Slots and cells (UI-SLOT)

| ID | Deliver as | Used by | On-screen size | Source | 9-slice | States / variants | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-SLOT-01 | `assets/ui/slots/slot_item_{state}.png` | Item grid cell behind every item icon: inventory (180), stash and smithing (144), post-combat loot (80). The icon and shader rarity glow sit on top | 80–180 | 180×180 | 24/24/24/24 | normal, selected, empty | | P0 | NEW |
| UI-SLOT-02 | `assets/ui/slots/slot_equip_{state}.png` | 7 equipment slots on the Inventory tab. Holds an empty-slot silhouette (`02_ui_icons.md` §3) or the equipped item icon | 144×144 | 144×144 (not 9-slice) | — | empty, filled, selected, disabled | | P0 | REDO (tinted stone) |
| UI-SLOT-03 | `assets/ui/slots/slot_die_{state}.png` | Die sockets inside an action field (holds a 62 px die) and in the dice grids | 24–72 | 80×80 | 16/16/16/16 | empty, hover (valid drop), filled, invalid (red) | | P0 | NEW |
| UI-SLOT-04 | `assets/ui/action_field/field_fill.png` + `field_stroke.png` | **Action field card**: one per available action in combat (3-column grid, 120×100 minimum, grows; expands to about 900×600 when opened). **Both layers are tinted** per element by shader | 120×100 → 900×600 | 400×400 | 80/100/80/100 (current) | fill + stroke as separate layers; highlighted and disabled are done by shader and modulate | ✔ | P0 | REDO (`9patch fill/stroke basic.png`) |
| UI-SLOT-05 | `assets/ui/action_field/field_header_plate.png` | Action name plate at the top of the action field | ~300×48 | 256×56 | 24/0/24/0 | — | | P1 | NEW |
| UI-SLOT-06 | `assets/ui/action_field/charge_pip_{full,empty}.png` | Charge counters on limited-use actions | 20×20 | 32×32 | — | full, empty | ✔ | P1 | NEW (currently text) |
| UI-SLOT-07 | `assets/ui/action_field/field_preview_{fill,stroke}.png` | Hover preview of an action field (256×256) with action-type and target-count icons | 256×256 | 256×256 | — | fill + stroke | ✔ | P2 | REDO |

---

## 5. Bars (UI-BAR)

Bars are Godot TextureProgressBars made of three layers: **under** (background), **progress** (fill) and **over** (frame or stroke). All three are 9-slices that stretch horizontally.

**Two heights are needed**, because 9-slice margins don't scale down.

| ID | Deliver as | Used by | On-screen | Source | 9-slice L/T/R/B | Variants | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-BAR-01 | `assets/ui/bars/bar_lg_{under,over}.png` | HUD Health, Mana and XP bars (300×40); mana selector bar (h 48); character-tab bars (h 40); post-combat XP (h 22 → use `sm`) | 300×40–48 | 256×48 | 16/12/16/12 | under, over | | P0 | REDO (`progress_bar_fill_bg/stroke_basic.png`) |
| UI-BAR-02 | `assets/ui/bars/bar_lg_fill.png` | Fill for the large bar. **Greyscale**: the game tints it for HP (green, or red when low), mana (blue), XP (purple), armor and barrier | as above | 256×48 | 16/12/16/12 | one file (optional sheen overlay `bar_lg_fill_sheen.png`) | ✔ | P0 | REDO (per-colour fills) |
| UI-BAR-03 | `assets/ui/bars/bar_sm_{under,over,fill}.png` | Enemy health bars (300×24, under each portrait), companion HP (128×24), post-combat XP (h 22), map dice-panel bars | 128–300 × 22–24 | 128×24 | 8/6/8/6 | under, over, fill | fill ✔ | P0 | REDO |
| UI-BAR-04 | `assets/ui/bars/bar_vertical_{under,over,fill}.png` | Dungeon floor-progress bar (20×200, vertical fill) | 20×200 | 24×200 | 0/16/0/16 | under, over, fill | fill ✔ | P2 | NEW (currently has no texture) |
| UI-BAR-05 | `assets/ui/bars/bar_alignment_{track,marker}.png` | Character tab alignment axes (−100 ↔ +100, 32 high, centre marker). The track should show the two poles | ~800×32 | 512×32 | 16/8/16/8 | track, centre marker (4×40) | | P2 | NEW |

---

## 6. Frames (UI-FRM)

| ID | Deliver as | Used by | On-screen | Source | States / notes | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|
| UI-FRM-01 | `assets/ui/frames/frame_player_{back,front}.png` | Player portrait, bottom-left of the HUD, always visible. **back** sits behind the bust; **front** overlays it with a transparent window. A shader adds a rarity-coloured glow that follows the front frame's alpha | 400×400 | 400×400 | back + front layers. Leave room around the rim for the status-icon row (28 px) and a level badge | | P0 | REDO (`placeholder_frame_front.png`) |
| UI-FRM-02 | `assets/ui/frames/portrait_mask_player.png` | Mask that clips the bust to the frame window: white = visible, black = hidden | 360×360 | 360×360 | greyscale, soft edge OK | ✔ | P0 | NEW |
| UI-FRM-03 | `assets/ui/frames/frame_enemy_{back,front}.png` | Enemy portrait slot (3 across the top of combat). Portrait **300×300** inside a 300×316 section (the scene overrides the script default of 180). A shader adds a turn glow and targeting outline | 300×316 | 320×336 (stretched to fit; not a 9-slice) | back + front. **Tier variants** depend on style decision S10: `_trash`, `_elite`, `_miniboss`, `_boss`, `_worldboss` | | P0 (base) / P1 (tiers) | REDO (`darkModalSimple_dark.png`; unused `enemy_portrait_frame.png` exists) |
| UI-FRM-04 | `assets/ui/frames/frame_companion_{back,front}_{npc,summon,empty}.png` | 4 companion slots on the left side in combat, plus companion cards | 128×128 | 256×256 | NPC (gold), summon (purple), empty. Death is a code overlay | | P1 | NEW (texture slots exist but are empty) |
| UI-FRM-05 | `assets/ui/frames/frame_item_detail.png` | Large item icon in the item info popup and the smithing popup (160 icon in a 200 box) | 200×200 | 200×200 | clean window; the rarity glow shader sits inside | | P1 | NEW |
| UI-FRM-06 | `assets/ui/frames/badge_level.png` | Player level badge on the portrait frame (40×40, with the number drawn by code) | 40×40 | 64×64 | — | | P1 | NEW |

---

## 7. Dialogue (UI-DLG)

| ID | Deliver as | Used by | On-screen | Source | 9-slice L/T/R/B | Notes | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-DLG-01 | `assets/ui/dialogue/bubble_main.png` | Main speech bubble (960 wide, about 200–500 tall). Text is **black** at 36 px; the speaker name is yellow at 45 px, so the bubble must be light | 960×200–500 | 192×192 | 40/40/40/40 | light background | | P1 | NEW (flat white) |
| UI-DLG-02 | `assets/ui/dialogue/tail_main.png` | Speech tail pointing to the speaking bust; must join the bubble edge seamlessly | 32×24 | 64×48 | — | matches BUB-01 | | P1 | REDO |
| UI-DLG-03 | `assets/ui/dialogue/bubble_choice_{state}.png` | Player choice bubbles arranged in a ring (220×64, text 40 px) | 220×64 | 128×64 | 28/24/28/24 | normal, pressed, locked (condition unmet) | | P1 | NEW |
| UI-DLG-04 | `assets/ui/dialogue/tail_choice.png` | Choice bubble tail | 24×18 | 48×36 | — | | | P2 | REDO |
| UI-DLG-05 | `assets/ui/dialogue/bubble_bark.png` | Small combat and map "bark" bubbles over portraits (about 200 wide, 1–2 lines) | 200×60–100 | 128×64 | 24/20/24/20 | | | P2 | NEW |

---

## 8. Standard controls (UI-CTL)

| ID | Deliver as | Used by | On-screen | Source | 9-slice | States | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|---|---|
| UI-CTL-01 | `assets/ui/controls/scroll_{track,grabber}_{state}.png` | Vertical scrollbars in every scrolling list | 12–16 wide | 16×64 | 0/16/0/16 | grabber: normal, hover, pressed | | P1 | NEW |
| UI-CTL-02 | `assets/ui/controls/checkbox_{on,off}.png` | Quest objectives (currently the text "[x]" and "[ ]"), settings | 32×32 | 48×48 | — | on, off | | P1 | NEW |
| UI-CTL-03 | `assets/ui/controls/slider_{track,fill,grabber}.png` | Rest popup HP/blessing slider | ~300×24 | track 128×16 (8/0/8/0); grabber 40×40 | — | grabber normal, pressed | fill ✔ | P2 | NEW |
| UI-CTL-04 | `assets/ui/controls/separator_h.png` | Horizontal dividers in popups and menus | full width × 2–8 | 256×8 | 32/0/32/0 | — | | P2 | NEW |
| UI-CTL-05 | `assets/ui/controls/fold_{closed,open}.png` | Expand/collapse arrow on the shop's collapsible rows and on character-tab collapsible sections (currently text "[+]") | 24×24 | 48×48 | — | closed, open | | P2 | NEW |

---

## 9. Screen-level art (UI-SCR)

| ID | Deliver as | Used by | On-screen | Source | Notes | Prio | Status |
|---|---|---|---|---|---|---|---|
| UI-SCR-01 | `assets/ui/screens/app_icon.png` | Store and launcher icon | — | 1024×1024 (plus an adaptive-icon foreground and background at 432×432 each for Android) | No text. Must read at 48 px | P2 | NEW (Godot default `icon.svg`) |
| UI-SCR-02 | `assets/ui/screens/splash.png` | Boot splash | 1080×1920 | 1080×1920 (keep key art inside the central 1080×1600, because wide phones crop it) | | P2 | NEW |
| UI-SCR-03 | `assets/ui/screens/logo.png` | Game logo "Roll The Bones" (splash, future title screen, store page) | ~900 wide | 1800×900 | transparent background | P2 | NEW |

> The game has no title or main-menu screen yet. When one is designed it will get its own rows.
