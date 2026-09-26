# 05: Items, Consumables and Crafting

The per-asset lists are in [manifest/items.md](manifest/items.md), [manifest/consumables.md](manifest/consumables.md) and [manifest/misc.md](manifest/misc.md).

## Shared icon rules (all inventory objects)

| Spec | Value |
|---|---|
| Source | **360×360** PNG, transparent background. This matches the existing 360² item art |
| Where shown | Inventory grid (180), stash and smithing grids (144), equipment slots (144), item info popup (160), post-combat loot (80), action-card item badge (64) |
| Framing | A single object, centred, at about a 45° angle for weapons. Fill **75–85%** of the canvas. No background plate and no frame |
| Rarity | **Don't paint rarity.** A shader draws a coloured outline and glow from the icon's alpha: grey for common, green uncommon, blue rare, purple epic, orange legendary. So the alpha edge must be clean, with no soft shadow or halo baked in |
| Readability | The object type (sword, helm, boots…) must be recognisable at **80 px** |
| Light | Match the global light direction (style decision S5) |

## 1. Equipment icons (ITM): 81 rows
See **[manifest/items.md](manifest/items.md)**.

- **Region 1: 70 items** across Head 9, Torso 9, Gloves 9, Boots 9, Main Hand 7, Off Hand 10, Heavy (two-handed) 9, Accessory 6, and 1 debug item. **Priority P1.**
- **73 rows already have art** (360², marked REVIEW). Decide per row whether to **keep, touch up to the final style, or redo**. For a uniform style, redo the whole set once test piece T3 is approved.
- **Material families** repeat across slots: *Arcane, Iron, Leather, Marine, Plated, Runed Iron, Scholar's, Scout's, Warded Leather*. Items in one family (e.g. Iron Helm, Iron Gauntlets, Iron Greaves) must look like **a matching set**: same materials, trims and palette.
- Four off-hands (armor, barrier and hybrid variants) share a base item. They can share a design with a colour or trim variation.
- **Legacy and test items (11)** outside `region_1` are **P3**: confirm whether they're still used before commissioning.
- Note: `scholars_ring` has no icon assigned, although `assets/items/.../scholar's ring.png` exists. The appendix covers it.

## 2. Consumable icons (CON): 65 rows
See **[manifest/consumables.md](manifest/consumables.md)**. **Priority P2.** They follow the shared icon rules above.

| Tier | Count | What it is | Suggested visual family |
|---|---|---|---|
| Restorative | 12 | Instant heal, mana or barrier | Potions, draughts, salves, tablets |
| Combat Prep | 27 | Temporary buffs for the next fight | Oils, pitches, resins, whetstones, charms |
| Dice Elixir | 13 | Temporary dice modifications for the next fight | Vials with a die motif, or dice-shaped flasks |
| Inscription | 13 | Permanently engraves a rune on a die | Runes, carving tools, inked dice |

### Variant strategy (cost saver)
**13 consumables are element variants** of a few base items: *Rune of X* ×5, *Temporary Ink of X* ×5, pitch, resin, and so on. For each variant group:
- Draw **one base design**, then produce each element variant by **changing the liquid, glow or rune colour** to that element's colour (README → Colour).
- Each variant is still delivered as its own file under its own row name.

## 3. Crafting components (CMPT): 5 rows
See **[manifest/misc.md](manifest/misc.md)**. **Priority P2.**

| Spec | Value |
|---|---|
| Source | 128×128 |
| Where shown | Smithing popup cost rows (16–28 px) and the character tab currency rows (32 px) |
| Content | Common, Uncommon, Rare and Epic Component (one material in 4 escalating grades: shape and complexity must escalate, not just colour), plus **Threads of Fate** (the affix-lock currency) |

## 4. Equipment set icons (SET): 2 rows
**NEEDS HOOKUP**, **P3**. Set emblems are shown in set tooltips: 128×128 heraldic emblems, one per set. See [manifest/misc.md](manifest/misc.md).
