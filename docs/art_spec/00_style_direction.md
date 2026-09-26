# 00: Style Direction (to be decided)

The style isn't locked yet. This file lists the questions to settle **before production starts**, what we already know about the game's tone, and a small set of paid test pieces that will lock the style.

## What we know
- **Title:** *Roll The Bones*. It's a dice RPG with roguelite dungeon runs, played in portrait on phones, one-handed.
- **Player character:** "Bones", a skeletal protagonist. The current placeholder UI leans on bone and grave motifs: tombstone tabs, a skull menu icon, a "9patch bones" frame.
- **First region:** a coastal fantasy setting. Embergate is the starting town, with a harbour and docks. The first enemy faction is the **Sanctum Navy**: marines, arcanists, griffin-riders, harbour sentinels and weather mages, led by admirals.
- **Main mechanics shown on screen:** dice (D4–D20, with 8 element treatments done by shaders), element colours, rarity glows, status effects, and stacked affixes on gear. **The UI is dense and icon-heavy**, so readability at small sizes matters more than detail.
- **Screen real estate:** 1080 × 1920. The bottom 342 px is the HUD; the top area shows up to 3 enemy portraits at 300 px. The playfield is mostly UI.

## Decisions to make

| # | Question | Options / notes | Decision |
|---|---|---|---|
| S1 | **Overall tone** | (a) dark and macabre (bones, graves, candle-light); (b) swashbuckling nautical fantasy (brass, rope, sailcloth); (c) a blend: bone-and-grave **UI chrome** framing a **nautical-fantasy world**. | |
| S2 | **Rendering level for illustrations** (portraits, busts, items) | Flat or cel-shaded / soft painterly / detailed painted. Consider cost across 137 enemies and ~150 icons. | |
| S3 | **Rendering level for UI chrome** | Flat vector / lightly textured (stone, parchment, bone) / fully rendered. It must work as 9-slices (see README). | |
| S4 | **Outline treatment** | No outline / dark coloured outline / heavy black outline. Icons must stay readable at **28 px** (status row) and **48 px** (skills). | |
| S5 | **Light direction** | Fix one direction for every asset (suggest top-left) so icons and portraits sit together. | |
| S6 | **Palette** | Keep the Endesga-64 palette the code uses today, or define a new master palette (element and rarity colours are fixed; see README → Colour). | |
| S7 | **Portrait framing** | Head and shoulders vs bust vs full upper body; front vs ¾ view; background (none / flat / vignette). The enemy portrait is shown square at 300 px inside a frame. | |
| S8 | **Icon framing** | Freestanding object on transparent (current items) vs icon on a backing plate. Equipment icons get a shader rarity outline, so freestanding is recommended. | |
| S9 | **Status and element iconography** | Pictograms (flame, snowflake) vs glyphs or runes. They must stay distinct at 28 px **without relying on colour** (colour-blind safety). | |
| S10 | **Enemy tier readability** | How tier is shown on a portrait (trash → world boss): a frame variant (a UI asset) or a size and pose escalation in the portrait itself? | |
| S11 | **Faction visual language** | Sanctum Navy motifs: uniform colours, insignia, materials. Needed before the enemy batch. | |
| S12 | **Player (Bones) look** | Final character design, and the mood set for the dialogue bust (see `04_characters.md`). | |

## Reference boards to collect
The developer and the artist each put together a board with 5–10 images for each of the following:
- Overall mood (S1)
- UI chrome (S3)
- Icon style (S4, S8)
- Portraits (S2, S7)
- Sanctum Navy (S11)

## Test pieces (commission first, paid)
Settle S1–S9 by producing one of each asset below. Test each one **in-engine** before going further.

| Test | Asset ID(s) | Why |
|---|---|---|
| T1 | `UI-BTN-01` primary button, all 4 states | Checks state readability and 9-slice behaviour |
| T2 | `UI-PNL-01` modal panel 9-slice | The frame used most often; checks stretch behaviour |
| T3 | One equipment icon (e.g. `ITM-main_hand-...` iron sword) | Checks icon detail at 80 and 160 px with the rarity glow |
| T4 | One enemy portrait (a Navy trash enemy) | Checks portrait style at 300 px inside the enemy frame |
| T5 | Three status icons (burn, chill, poison) | Checks readability at 28 px |

When T1–T5 are approved, fill in the Decision column above and treat this page as the style guide.
