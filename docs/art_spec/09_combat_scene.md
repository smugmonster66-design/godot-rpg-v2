# 09: Combat Scene

This page shows how the combat screen is put together and which assets from the other files appear in it. The only **new** assets on this page are the combat backgrounds.

## Screen layout (1080×1920, top to bottom)

| Zone | Approx. y | Contents | Assets (see file) |
|---|---|---|---|
| Top bar | 40–400 | Up to **3 enemy slots** side by side. Each has a 300 px portrait in a frame, a nameplate, a health bar, a status row (icons at 64 px), and the enemy's dice (24–36 px) | CHR-ENM (04), UI-FRM-03, UI-PNL-06, UI-BAR-03, ICN-STS (02), dice (03) |
| Left edge | 950–1500 | **4 companion slots**, 128 px each | UI-FRM-04, CHR-CMP (04), UI-BAR-03 |
| Middle | ~500–1100 | **Action fields**: a 3-column grid of cards (tinted 9-slice), each with die sockets, name and charge pips. An opened card grows to about 900×600 over a dimmed background | UI-SLOT-03…07 (01), ICN-ACT (02), ACT (06) |
| Lower middle | ~1100–1300 | **Dice hand** tray, 700×180 (dice at 124 px); mana-die selector with 4 arrow buttons | UI-PNL-10, dice (03), UI-BTN-05, ICN-GLY arrows |
| Bottom HUD | 1578–1920 | Player portrait (400 px) with frame, status row and level badge; HP, Mana and XP bars; **ROLL THE BONES!** button; End Turn and Menu buttons | UI-PNL-05, UI-FRM-01/02, CHR-PLR-01, UI-BAR-01/02, UI-BTN-02/04 |
| Floating | anywhere | Damage and heal numbers, and "barks" (speech bubbles over portraits) | Floaters are text only; UI-DLG-05 |

## Combat backgrounds (CBG): NEEDS HOOKUP
Combat currently uses a flat grey background. Each encounter already has a background field; the code needs a background node to display it (appendix C-02).

| Spec | Value |
|---|---|
| Deliver as | `assets/backgrounds/combat/cbg_{setting}.png` |
| Source | **1080×1920**, with a safe margin so wide and tall phones can crop it (keep key content inside the central 1080×1700). Deliver at **1200×2100** if bleed is wanted |
| Composition | **Low contrast and low detail in the middle band** (y 400–1400), where the action cards and dice sit. Atmosphere and interest go at the top (behind the enemies) and the far edges. No characters |
| Settings for region 1 | (1) **Sanctum Navy fortress interior**, (2) **Harbour / docks**, (3) **Coastal road / patrol grounds**, (4) **Boss chamber** (the Navy flagship deck or admiralty hall) |
| Priority | P1 for (1) (all current dungeon fights), P2 for the rest |

## Not needed from the artist
These are shaders or particles and need no art:
- Enemy turn glow, targeting reticle and selection outline
- Damage flash, cracked-ice and water-wave overlays
- Element tint on the dice and action cards
- All cast, projectile and impact VFX (out of scope)
