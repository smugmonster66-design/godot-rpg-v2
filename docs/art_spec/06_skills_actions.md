# 06: Skills, Skill Trees, Classes and Actions

Per-asset lists: [manifest/skills.md](manifest/skills.md), [manifest/actions.md](manifest/actions.md).

---

## 1. Skill icons (SKL): 60 rows
The mage class has three trees (**Flame, Frost, Storm**), each with 20 skills over 8 tiers. Rows are listed per tree and tier in **[manifest/skills.md](manifest/skills.md)**. **Priority P1.**

**How skill icons are drawn.** This drives the spec. In the skill tree, the game **ignores the icon's colours**:
- It reads **only the alpha (shape)** and renders it as an engraving carved into the tree background, bevelled by the light direction.
- As the player puts ranks into a skill, a coloured fill **sweeps up from the bottom** of the carved shape.
- A pulsing glow outline in the skill-category colour surrounds skills that can be learned.

| Spec | Value |
|---|---|
| Deliver as | `assets/icons/skills/{class}/{tree}/skill_{id}.png` (given per row) |
| Source | **256×256** |
| Format | A **solid white silhouette** on transparent. **All the design lives in the shape**: interior detail must be **cut-outs** (fully transparent gaps at least 6 px wide at source size), not painted lines. Avoid semi-transparent pixels except anti-aliased edges |
| Where shown | Skill tree button, **48 px** icon inside a 64 px cell (engraved); skill detail popup, 64 px |
| Readability | Test by filling the silhouette black on mid-grey at 48 px. It must still read |
| Tree identity | Each tree should share motifs: **Flame** (embers, braziers, sun), **Frost** (shards, crystals, breath), **Storm** (bolts, clouds, coils). Skills in one tree should look like a family |
| Existing | Flame has 20 icons at 64×64 (marked REVIEW; redo at 256 to the new rules). Frost has none (NEW). Storm has 5 unassigned 64×64 drafts in `assets/icons/classes/mage/storm/` (NEW) |

**Fallback skill icon:** `SKL-00`, delivered as `assets/icons/skills/skill_default.png` (256×256 silhouette, P1, REDO; currently `default skill icon 48.png`). It's used by skill buttons and the skill popup when a skill has no icon.

> **Skill categories**: Passive, Trigger, Action, Signature, Weave, Capstone. They're shown by the glow colour, not by the icon. Capstone and Signature skills (tiers 7–8) deserve the boldest silhouettes. There's an optional category emblem set in `02_ui_icons.md` §12.

## 2. Skill tree tab icons (TREE)
| Spec | Value |
|---|---|
| Rows | 6 in the manifest: 3 mage (**P1**) and 3 warrior (**P3, out of scope**: future content) |
| Where shown | Skills tab tree selector (UI-TAB-02), about 96 px, next to the tree name |
| Source | 256×256, full colour allowed (not engraved) |
| Content | The emblem of each tree: Flame, Frost, Storm |

## 3. Class icon and portrait (CLS)
| Spec | Value |
|---|---|
| Rows | Mage: `icon` and `portrait` (**NEEDS HOOKUP**, P2). The HUD currently hardcodes the Bones bust instead |
| Source | Icon 256×256; portrait 512×512 |
| Use | Class selection and the character sheet header (future) |

## 4. Action icons (ACT): 118 rows, NEEDS HOOKUP
See **[manifest/actions.md](manifest/actions.md)**.

Actions are the abilities placed on the action-field cards in combat (e.g. "Chromatic Bolt", "Shield Bash", "Arcane Barrage"). Every action has an `icon` field, but **the action card doesn't display it yet** (appendix C-03). Specs are given now so the art and the hookup can proceed in parallel.

| Spec | Value |
|---|---|
| Deliver as | `assets/icons/actions/{group}/act_{id}.png` (given per row) |
| Source | **256×256** |
| Format | **White silhouette** (Tint ✔). The action card is element-tinted, and the icon will be tinted to match. Same cut-out rules as skill icons |
| Where shown (planned) | Action-field card header, about 64 px; action preview, 48 px; enemy "current action" banner, 48 px |
| Content cue | The **category** (Attack, Buff, Debuff, Heal, Summon, Escape) and the **element** are listed per row. The icon should depict the verb (slash, bolt, shield, heal) |

| Group | Count | Priority |
|---|---|---|
| Player: item-granted actions | 19 | P2 |
| Player: mage tree actions (flame, frost, storm) | 10 | P2 |
| Player: class actions (Chromatic Bolt etc.) | 2 | P2 |
| Player: misc and test (`root`) | 5 | P3 (confirm) |
| Enemy: Sanctum Navy | 51 | P3 |
| Enemy: generic base actions | 30 | P3 |
| Enemy: goblin | 1 | P3 |

> **Cost saver:** many enemy actions share a verb (several "salvo", "slash" and "guard" actions). Enemy action icons can come from a **generic verb set** of about 25 icons that the developer maps onto the 82 enemy actions, instead of one icon each. Agree this before quoting.
