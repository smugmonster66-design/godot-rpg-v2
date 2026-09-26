# 02: UI Icons

This file covers system icons that are **not** tied to a content item. Content icons (items, skills, actions, enemies and so on) are listed per asset in `manifest/`.

**Shared rules for this file:**
- Square canvas with transparent padding and a 90% safe area (README → File format).
- **"White silhouette"** means solid white shapes on transparent, with interior detail cut out as transparency or drawn in mid-grey. The game adds colour and outline with a shader, so no outline is needed in the art.
- Everything must read at the **smallest** listed size. Check it at 100% zoom at that size.

---

## 1. Menu navigation (ICN-NAV)
The five player-menu tab icons sit on UI-TAB-01.

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-NAV-01 | `assets/ui/icons/navigation/nav_character.png` | Character sheet (currently a skull face, "bonesface") | 128 | 256×256 | | P0 | REDO |
| ICN-NAV-02 | `assets/ui/icons/navigation/nav_skills.png` | Skill trees | 128 | 256×256 | | P0 | REDO |
| ICN-NAV-03 | `assets/ui/icons/navigation/nav_companions.png` | Companions / party (currently lamellar armour) | 128 | 256×256 | | P0 | REDO |
| ICN-NAV-04 | `assets/ui/icons/navigation/nav_inventory.png` | Inventory (currently a knapsack) | 128 | 256×256 | | P0 | REDO |
| ICN-NAV-05 | `assets/ui/icons/navigation/nav_quests.png` | Quest journal | 128 | 256×256 | | P0 | REDO |

## 2. Item categories (ICN-CAT)
Filter buttons on the Inventory tab (on UI-BTN-05, 100×100). The Stash and Smithing popups will use the same set when their text tabs are replaced.

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-CAT-01 | `assets/ui/icons/categories/cat_all.png` | All items | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-02 | `…/cat_head.png` | Head | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-03 | `…/cat_torso.png` | Torso | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-04 | `…/cat_gloves.png` | Gloves | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-05 | `…/cat_boots.png` | Boots | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-06 | `…/cat_main_hand.png` | Main-hand weapon | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-07 | `…/cat_off_hand.png` | Off-hand (shield or focus) | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-08 | `…/cat_heavy.png` | Two-handed weapon | 64–80 | 128×128 | | P1 | NEW |
| ICN-CAT-09 | `…/cat_accessory.png` | Accessory (ring or amulet) | 64–80 | 128×128 | | P0 | REDO |
| ICN-CAT-10 | `…/cat_consumables.png` | Consumables | 64–80 | 128×128 | | P0 | REDO |

## 3. Empty equipment-slot silhouettes (ICN-SLOT)
Shown at 50% opacity inside empty UI-SLOT-02 slots (112 px inside a 144 slot). **White silhouettes.**

| ID | Deliver as | Slot | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-SLOT-01…07 | `assets/ui/icons/slots/slot_{head,torso,gloves,boots,main_hand,off_hand,accessory}.png` | One per slot (7 files) | 112 | 128×128 | ✔ | P0 | REDO (reuses the 64 px category icons) |

## 4. World-map radial menu (ICN-MAP)
160 px icons on UI-BTN-07. Tapping a map location opens this ring.

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-MAP-01 | `assets/ui/icons/mapbuttons/map_travel.png` | Travel here | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-02 | `…/map_enter_dungeon.png` | Enter dungeon | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-03 | `…/map_enter_zone.png` | Enter sub-zone | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-04 | `…/map_rest.png` | Rest / heal | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-05 | `…/map_npcs.png` | Talk to NPCs (fallback when an NPC has no portrait) | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-06 | `…/map_quests.png` | Quest board | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-07 | `…/map_party.png` | Party management | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-08 | `…/map_stash.png` | Stash | 160 | 256×256 | | P1 | NEW (none assigned) |
| ICN-MAP-09 | `…/map_smithing.png` | Smithing | 160 | 256×256 | | P1 | REDO |
| ICN-MAP-10 | `…/map_shop.png` | Shop (the shop UI is planned; see TODO) | 160 | 256×256 | | P3 | NEW |

## 5. Elements (ICN-ELM)
Used for: the element row in item popups (24 px), damage-preview chips (16 px), inline in rules text (30 px), the action-card fallback badge (64 px). The game currently has **no element icons**.

Deliver **two versions of each**:
- **Coloured**, filled with the element colour from README → Colour, for use without a shader.
- **White silhouette**, with a `_white` suffix, for tinted use.

| ID | Deliver as | Element | On-screen | Source | Prio | Status |
|---|---|---|---|---|---|---|
| ICN-ELM-01 | `assets/icons/elements/element_slashing.png` (+ `_white`) | Slashing | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-02 | `…/element_blunt.png` | Blunt | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-03 | `…/element_piercing.png` | Piercing | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-04 | `…/element_fire.png` | Fire | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-05 | `…/element_ice.png` | Ice | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-06 | `…/element_shock.png` | Shock | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-07 | `…/element_poison.png` | Poison | 16–64 | 128×128 | P0 | NEW |
| ICN-ELM-08 | `…/element_shadow.png` | Shadow | 16–64 | 128×128 | P0 | NEW |

> Must be distinguishable **at 16 px and without colour** (style question S9).

## 6. Status effects (ICN-STS)
There are 27 status icons, listed individually in **[manifest/statuses.md](manifest/statuses.md)**.

- **White silhouettes, 128×128.** A shader tints each one with its status colour and adds a black outline, so don't draw an outline.
- Shown at **64 px** on combatants, **28 px** around the player portrait, **30 px** inline in text.
- The existing icons are 36×36 and upscaled, so every one is a REDO.
- Deliver to `assets/icons/status/status_{id}.png`, the path the game already looks in.
- Status colours are listed in `scripts/ui/theme_manager.gd` → `get_status_color()`. They're fixed, so shapes must stay distinct when several of them share a colour family (burn, ignition and fire).

## 7. Stats and resources (ICN-STAT)
**NEEDS HOOKUP**: the character tab and tooltips currently show text only.

| ID | Deliver as | Meaning | On-screen | Source | Prio | Status |
|---|---|---|---|---|---|---|
| ICN-STAT-01…04 | `assets/icons/stats/stat_{strength,agility,intellect,luck}.png` | Primary stats | 24–48 | 128×128 | P2 | NEW |
| ICN-STAT-05…09 | `assets/icons/stats/stat_{health,mana,armor,barrier,xp}.png` | Health, mana, armor, barrier, experience (also used next to HUD bars) | 24–48 | 128×128 | P1 | NEW |
| ICN-STAT-10 | `assets/icons/stats/stat_crit.png` | Critical chance | 24–48 | 128×128 | P3 | NEW |

## 8. Currency and rewards (ICN-CUR)

| ID | Deliver as | Meaning / replaces | On-screen | Source | Prio | Status |
|---|---|---|---|---|---|---|
| ICN-CUR-01 | `assets/icons/currency/cur_gold.png` | Gold. Replaces the emoji 💰 and 🪙 in post-combat, the character tab, shop, treasure and dungeon-complete screens, and item sell value | 16–32 | 128×128 | P0 | REDO (`coins_icon.png`) |
| ICN-CUR-02 | `assets/icons/currency/cur_xp.png` | Experience. Replaces the emoji ⚔️ XP (post-combat, dungeon complete) | 16–32 | 128×128 | P0 | NEW |
| ICN-CUR-03 | `assets/icons/currency/fx_level_up.png` | Level-up banner or emblem. Replaces the text "✨ LEVEL UP ✨" | ~400×120 | 800×240 | P2 | NEW |

Crafting-component icons are listed individually in [manifest/misc.md](manifest/misc.md).

## 9. Action and targeting icons (ICN-ACT)
Shown on the action field preview and on action cards.

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-ACT-01…06 | `assets/ui/icons/actionfields/actcat_{attack,buff,debuff,heal,summon,escape}.png` | Action categories (`Action.ActionCategory`) | 36–64 | 128×128 | ✔ | P1 | REDO (attack and heal exist at 36×36) |
| ICN-ACT-07 | `…/act_targets.png` | Target count (a number is drawn on top) | 36–48 | 128×128 | ✔ | P1 | REDO |
| ICN-ACT-08 | `…/act_single_target.png`, `act_all_enemies.png`, `act_self.png`, `act_ally.png` | Targeting type | 36–48 | 128×128 | ✔ | P2 | NEW |

## 10. Quests (ICN-QST)
**NEEDS HOOKUP**: the quest tab currently uses coloured text and prefixes like [NEW] and [TURN IN].

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-QST-01…07 | `assets/icons/quests/qtype_{main,side,companion,bounty,collection,exploration,hidden}.png` | Quest type | 32–48 | 128×128 | ✔ | P2 | NEW |
| ICN-QST-08…11 | `assets/icons/quests/qstate_{new,turn_in,done,failed}.png` | Quest state badges | 24–32 | 64×64 | | P2 | NEW |
| ICN-QST-12…13 | `assets/icons/quests/marker_{available,turn_in}.png` | Map markers over locations ("!" and "?" style) | 48 | 128×128 | | P2 | NEW |

## 11. Badges, glyphs and indicators (ICN-GLY)
These replace emoji and text glyphs used as icons today.

| ID | Deliver as | Replaces / used by | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-GLY-01 | `assets/ui/icons/glyphs/glyph_continue.png` | "▼" dialogue continue indicator (animated bounce by code) | 32 | 64×64 | | P1 | NEW |
| ICN-GLY-02 | `…/glyph_affix.png` | "◆" marker on dice that have affixes | 16–24 | 64×64 | ✔ | P1 | NEW |
| ICN-GLY-03 | `…/glyph_lock.png` | Lock: locked dice, dialogue choices, locked dungeons, smithing affix locks | 24–48 | 64×64 | | P1 | NEW |
| ICN-GLY-04 | `…/glyph_add.png` | "+" on empty die slots | 24 | 64×64 | ✔ | P2 | NEW |
| ICN-GLY-05 | `…/glyph_skull.png` | Companion death overlay (text skull today) | 48 | 128×128 | | P2 | NEW |
| ICN-GLY-06 | `…/badge_equipped.png` | "E" badge on equipped items in grids (20×20 green box today) | 24 | 64×64 | | P1 | NEW |
| ICN-GLY-07 | `…/badge_new.png` | New-content dot on map radial buttons (red dot drawn in code, 28 px) | 28 | 64×64 | | P2 | NEW |
| ICN-GLY-08 | `…/badge_stack.png` | Background plate behind consumable stack counts | 28 | 64×64 | | P2 | NEW |
| ICN-GLY-09…12 | `…/arrow_{up,down,left,right}.png` | "▲ ▼ ◄ ►" on the mana-die selector (on UI-BTN-05 at 48 px) | 32 | 64×64 | ✔ | P1 | NEW |
| ICN-GLY-13 | `…/glyph_check.png` | Confirm tick (action-field confirm button, objectives) | 32–64 | 128×128 | ✔ | P0 | NEW |
| ICN-GLY-14 | `…/glyph_cross.png` | Cancel / close cross | 32–64 | 128×128 | ✔ | P0 | NEW |
| ICN-GLY-15 | `…/glyph_info.png` | "i" info or tooltip affordance | 24–32 | 64×64 | ✔ | P3 | NEW |
| ICN-GLY-16 | `…/notif_{info,quest,item,level}.png` | Map notification banner icons | 32 | 64×64 | | P2 | NEW |

## 12. Dialogue choice and topic icons (ICN-DLG)
The 24 px icon on dialogue choice bubbles (UI-DLG-03) and on NPC conversation topics in the radial sub-menu (`DialogueChoice.icon`, `NPCDialogueEntry.icon`). The slots exist but are empty.

| ID | Deliver as | Meaning | On-screen | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|---|
| ICN-DLG-01…07 | `assets/ui/icons/dialogue/dlg_{talk,quest,shop,fight,smithing,leave,gift}.png` | Choice or topic intent | 24–64 | 128×128 | ✔ | P2 | NEW |
| ICN-DLG-08 | `assets/ui/icons/mapbuttons/map_fallback.png` | Fallback radial icon when a button has no category icon (`MapRadialButton.fallback_icon`) | 160 | 256×256 | | P3 | NEW |

## 13. Skill-category emblems (optional, ICN-SKC)
Skill buttons are currently told apart by a coloured glow shader only. An optional emblem per category improves readability:
- Passive, Trigger, Action, Signature, Weave, Capstone
- Deliver to `assets/ui/icons/skills/skc_{category}.png`, 64×64, white silhouette (✔), P3, NEW.
