# 04: Characters

This file covers portraits and busts: the player, enemies, companions, NPCs and dialogue speakers. The per-asset lists are in [manifest/enemies.md](manifest/enemies.md) and [manifest/characters.md](manifest/characters.md). Settle style decisions S2, S7, S10, S11 and S12 first.

---

## 1. Player: Bones (CHR-PLR)

| ID | Deliver as | Used by | On-screen | Source | Notes | Prio | Status |
|---|---|---|---|---|---|---|---|
| CHR-PLR-01 | `assets/busts/bones/bones_portrait.png` | HUD portrait, bottom-left, always visible in every mode. Sits between frame layers UI-FRM-01 and is clipped by mask UI-FRM-02 | 360×360 | 720×720 | Head and shoulders, centred. A shader desaturates it when knocked out, so the colours must survive going greyscale | P0 | REDO (`bones_base.png` 360²) |
| CHR-PLR-02 | `assets/busts/bones/bust_bones_{mood}.png` | Dialogue bust when the player speaks | 400×640 | 400×640 | Moods: **base, angry, sad** (these exist as placeholders) + **amused, surprised, determined** (new). Same framing rules as §4 | P1 | REDO (3) + NEW (3) |

## 2. Enemy portraits (CHR-ENM): 137 assets
The full list, with names, tiers and archetypes, is in **[manifest/enemies.md](manifest/enemies.md)**.

| Spec | Value |
|---|---|
| Deliver as | `assets/characters/enemies/{faction}/{tier}/enemy_{id}.png` (given per row) |
| Where shown | Combat top bar: up to 3 enemies side by side, **300×300** each, inside the enemy frame (UI-FRM-03), with a nameplate and health bar under each |
| Source | **512×512**, PNG with transparent background (the frame's back layer supplies the background) |
| Framing | Head and shoulders to mid-torso. The subject fills about 80% of the height and is centred, facing the viewer or in ¾ view, looking slightly down or toward the player (bottom of screen). Keep the bottom 16 px clear: the health bar overlaps it |
| Readability | Must be identifiable at **150 px**. Give each enemy a clear silhouette and one dominant prop or colour |
| Tier escalation | 5 tiers: Trash, Elite, Mini Boss, Boss, World Boss. Ornament, scale and menace should rise with tier (style decision S10) |
| Faction | **Sanctum Navy** (85 enemies, 17 per tier). Shared uniform language across the faction (S11) |
| Shader interplay | Shaders add a turn glow, a targeting outline and a damage flash from the portrait's alpha, so the silhouette edge must be clean |

**Fallback portrait:** `CHR-ENM-00`, delivered as `assets/characters/enemies/enemy_unknown.png` (512×512, P1, REDO; currently `test_dummy_512.png`). It's a hooded or shadowed generic silhouette, used whenever an enemy has no portrait yet (`EnemySlot.default_portrait`). It lets the game ship with partial enemy art.

**Content groups:**

| Group | Count | Priority | Notes |
|---|---|---|---|
| Sanctum Navy: Trash | 17 | **P0** | The first enemies the player fights |
| Sanctum Navy: Elite | 17 | **P0** | |
| Sanctum Navy: Mini Boss / Boss / World Boss | 51 | P2 | |
| Baseline archetypes (archmage, brute, duelist… × 5 tiers) | 50 | P3 | **Confirm first**: these are test and template enemies used by the "Baseline Test" dungeon |
| Goblin, Test Dummy | 2 | P3 | Test content |

> **Cost saver (optional):** Navy enemies that share a role across tiers (e.g. arcanist → arcanist commander) can share a base design with tier-specific upgrades. Tell the artist which rows share a base before quoting.

## 3. Companions (CHR-CMP)
Listed individually in [manifest/characters.md](manifest/characters.md).

| Spec | Value |
|---|---|
| Deliver as | `assets/characters/companions/cmp_{id}.png` |
| Where shown | Combat companion slots, **128×128** (UI-FRM-04, left side); companion cards (64); companion info popup (160) |
| Source | **256×256**, transparent background |
| Framing | Head and shoulders, centred, readable at 64 px |
| Content | **Manne** (NPC companion) and **Storm Sprite** (summoned by the mage storm tree). Summons should read as magical or elemental rather than people |
| Priority | P1 |

## 4. NPCs and dialogue busts (CHR-NPC)
Listed individually in [manifest/characters.md](manifest/characters.md).

### 4a. NPC radial portrait
| Spec | Value |
|---|---|
| Deliver as | `assets/characters/npcs/npc_{id}_portrait.png` |
| Where shown | The world-map radial menu: an NPC's portrait **replaces the icon** on the round radial button (160 px inside a 256 circle) |
| Source | 256×256. Keep the face inside a **centred circle 80% of the canvas wide**, because it's shown in a round button |
| Content | **Cate** (Embergate). P1 |

### 4b. Dialogue busts
| Spec | Value |
|---|---|
| Deliver as | `assets/busts/{speaker}/bust_{speaker}_{mood}.png` |
| Where shown | The dialogue overlay. Up to 3 busts stand behind the speech bubble at left, centre and right positions, anchored to the **bottom** edge of a 960-wide dialogue area |
| Source | **400×640**. **Busts are drawn at their native pixel size** (see appendix, code note C-06), so this size is the on-screen size |
| Framing | Waist-up. The figure is cut off by the bottom edge, and the head sits in the top third. Transparent background. **Every mood of a speaker uses the same canvas and position**, so swapping moods doesn't make the bust jump |
| Facing | Draw facing **right**, toward the centre when standing at the left. Busts at the right-hand position will be mirrored in code (appendix C-09), so avoid asymmetric text, insignia or handedness that would look wrong flipped. No text or effects in the image |
| Moods | Available: base, amused, angry, laughing, frowning, sad, surprised, worried, smug, embarrassed, determined, tired, skeptical, excited, afraid, disgusted, thoughtful, pleading, stern, sly. **Minimum per speaking character: base + 3.** Extra moods are P3 |

**Current speakers and busts:**

| Character | Status | Moods needed (minimum) | Prio |
|---|---|---|---|
| Cate (NPC, Embergate) | Speaker exists. Placeholder busts: base, "yawn" (mapped to *amused*) | base, amused, annoyed→*frowning*, surprised | P1 |
| Bones (player) | See CHR-PLR-02 | | P1 |
| Hilda, Marcus, Gatekeeper | Placeholder busts exist but **no speaker or NPC data uses them** | **Confirm** whether they're in the current story before commissioning | P3 |

> The design notes also mention "Hilda the merchant" as a story flag. Confirm with the narrative vault which NPCs are planned for region 1.
