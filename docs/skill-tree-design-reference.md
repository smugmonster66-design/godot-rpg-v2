# Skill Tree Designer

You are designing skill trees for a dice-based RPG built in Godot 4.5. Skills are **containers for Affixes** — they never have custom logic. Every mechanical effect is an Affix (equipment) or DiceAffix (dice) that gets duplicated and added to the player's AffixPoolManager when learned.

## Scope

This skill handles:
- **Single tree**: Design one skill tree within a class
- **Full class**: Design all 3 trees + class action + cross-tree synergy

Adapt scope to what the user requests.

## Workflow

### Phase 1 — Gather Inputs
Ask the user for:
- Class name (e.g., Mage, Warrior, Rogue)
- Tree name and element (e.g., Flame/FIRE, Storm/SHOCK, Frost/ICE)
- Primary status effect (e.g., Burn, Static, Freeze)
- Fantasy theme / power fantasy description
- Any specific mechanics they want

### Phase 2 — Design Overview
Produce a structured design document with:
1. ASCII grid layout (tier × column)
2. Skill list table (name, tier, column, ranks, category, synopsis)
3. Prerequisite map (directed graph as text)
4. Synergy chain narrative

Present this for user review and iteration.

### Phase 3 — .tres-Ready Specs
After the user approves the design, generate complete resource definitions for each skill with:
- Exact enum integer values
- Full effect_data dictionaries
- Sub-resource nesting for MANA_DIE_AFFIX and NEW_ACTION skills
- Prerequisite references

---

## Design Philosophy

### 2.1 The Uniqueness Principle

**Litmus test** — every skill must pass ALL THREE:
1. "Does this skill care about game state?" (references a runtime condition)
2. "Does this skill create a decision?" (player plays better/worse because it exists)
3. "Can I explain what makes this different from every other skill in one sentence?"

A skill **qualifies as uniquely impactful** when it meets 2+ of these criteria:
- **Conditional**: Effect strength depends on game state (position, element, status stacks, neighbors)
- **Interactive**: Changes how the player places dice, sequences actions, or manages mana
- **Synergistic**: Becomes meaningfully better when combined with specific other skills
- **Transformative**: Changes a core rule or unlocks a new capability

**Stat bonus embedding patterns** (no standalone stat sticks — EVERY numerical bonus must use one of these):
- **Conditional**: +N when [position/status/neighbor condition]
- **Scaling**: +N per [element die used / status stack / qualifying neighbor]
- **Positional**: +N when die is in [first/last/even/odd] position
- **Trigger**: +N stat for N turns when [combat event] occurs
- **Compound**: stat bonus is a rider on a multi-effect skill

### 2.2 Eight-Tier Structure

| Tier | Points Req | Die Size | Skills | Feel |
|------|-----------|----------|--------|------|
| 1 | 0 | D4 | 1 (root) | Identity — unlock element + status + class action mod |
| 2 | 1 | D6 | 3 (one/branch) | Foundation — each branch plants its flag |
| 3 | 3 | — | 3 (one/branch) | Development — branches deepen, first status synergy |
| 4 | 6 | D8 | 3 (one/branch) | Specialization — skills reference other skills' outputs |
| 5 | 9 | — | 2-3 (+ first weave) | Convergence — first weave point, cross-pollination |
| 6 | 12 | D10 | 2-3 (+ optional weave) | Mastery — deep investment payoff |
| 7 | 16 | — | 2 | Apex — final pre-capstone power |
| 8 | 20 | D12 | 1-2 | Capstone — tree-defining ultimate |

**Die sizes are tier rewards, NOT skills.** Use `MANA_SIZE_UNLOCK` (cat=38) attached to tier progression, not individual skill resources. When a player unlocks a tier that grants a die size, the unlock is automatic.

### 2.3 Three-Branch Architecture

Every tree has three branches with distinct mechanical identities:

**Branch A — The Applier** (columns 0-1): How do I get the status onto targets? Application rates, spread, stack acceleration. Owns the Applicator action.

**Branch B — The Exploiter** (columns 5-6): What happens when the status is there? Conditional damage, threshold triggers, burst payoff. Owns the Exploiter action.

**Branch C — The Manipulator** (columns 2-4): How do my dice work differently? Position bonuses, element-specific mana economy, dice-to-dice interactions. Owns the class action modifier (no separate action grant).

**Root** (Tier 1, column 3): Always 1 skill. Unlocks element (cat=37) + class action mod (cat=54) + optional size unlock.

**Capstone** (Tier 8): 1-2 skills, **never 3**. Must reference at least two branches. Two competing capstones create a meaningful final choice.

### 2.4 Skill Type Budget (for ~20 skills)

| Type | Count | Notes |
|------|-------|-------|
| Root | 1 | Element unlock + class action mod |
| Dice interaction (MANA_DIE_AFFIX, cat=39) | 5-7 | Bread and butter, mostly Branch C |
| Status synergy (PROC/ON_HIT/MISC) | 3-4 | Apply (A), payoff (B), cross-branch (weave) |
| Action grants (NEW_ACTION, cat=31) | 3 | Applicator (A, T3-4), Exploiter (B, T5-6), Signature (T7-8) |
| Proc/trigger (cat=33-35) | 2-3 | Combat event reactions |
| Class action mod (cat=53-57) | 1-2 | Branch C territory |
| Weave points | 1-2 | Cross-branch, count toward dice/status total |
| Capstone | 1-2 | Tree-defining |

**NOT allowed as standalone skills**: Pure stat sticks (0), die size unlocks (0), bridge filler (0).

### 2.5 Action Design (3-Action Budget)

Each tree grants exactly 3 actions:

1. **Applicator** (Branch A, Tier 3-4): 1-2 dice, unlimited or per-turn, moderate damage + reliable status application. This is the workhorse.
2. **Exploiter** (Branch B, Tier 5-6): 2-3 dice, per-turn(1) or per-combat(2-3), high damage scaling off status stacks/presence. The payoff.
3. **Signature** (Tier 7-8): 2-3 dice, per-combat(1), AoE or ultimate, references the full build. The finisher.

**Rules:**
- No two actions share die count AND charge type
- No two actions target the same audience (e.g., two single-target nukes)
- Every action references the tree's signature status effect

### 2.6 Weave Point Design

Weave points are cross-branch skills that reward breadth of investment:

- Appear at **Tier 5** (mandatory, 1 skill) and optionally **Tier 6**
- Require one specific skill from Branch X + one from Branch Y (both at Tier 3-4)
- Sit at column between parent branches (column 2, 3, or 4)
- Create an **emergent interaction**, NOT "skill A + skill B stapled together"
- **NOT mandatory** for reaching capstone — a side path rewarding breadth

**Weave patterns:**
- **Status-to-Dice bridge**: Status from Branch A makes Branch C dice work differently
- **Payoff-to-Economy bridge**: Branch B damage event triggers Branch C mana/economy effect
- **Applicator-to-Exploiter bridge**: Branch A application enables Branch B conditional at lower threshold

### 2.7 Anti-Patterns (7 Prohibitions)

1. **NEVER: Pure Stat Stick** — No unconditional flat/mult bonuses as standalone skills. Every numerical bonus must be gated by condition, position, trigger, or scaling. (See embedding patterns in 2.1)
2. **NEVER: Die Size as Skill** — Die sizes are baked into tier progression. Do not create skills whose primary purpose is unlocking D6/D8/D10/D12.
3. **NEVER: Redundant Status Application** — Max 2 skills applying the same status, and they must use distinct mechanisms (e.g., one on-hit proc, one dice affix trigger — not two on-hit procs with different percentages).
4. **NEVER: Action Flood** — Max 4 actions per tree (3 standard + at most 1 conditional/utility). Players have limited action bar slots.
5. **NEVER: Bridge Filler** — Every skill must be worth taking on its own merits. No skills that exist solely as prerequisites. If a skill is only valuable as a gateway, merge its effect into the skill it gates.
6. **NEVER: Mana Economy Over-Specification** — Max 2 mana-economy skills per tree (cost reduction, refund, regen). More creates analysis paralysis and diminishes each one's impact.
7. **NEVER: Linear Prerequisite Chain** — Every branch must fork at least once by Tier 4. No single chain of 4+ skills with no branching.

### 2.8 Design Checklist

Before adding ANY skill, answer YES to all:
1. Passes 2+ uniqueness criteria (conditional, interactive, synergistic, transformative)?
2. Mechanically distinct from every other skill in the tree?
3. Implements through existing affix systems (no custom logic needed)?
4. Numerical bonuses gated by condition/position/trigger/scaling?
5. Doesn't violate any anti-pattern from 2.7?
6. Fits within the type budget from 2.4?
7. Creates at least one decision the player wouldn't have without it?

### Core Principles (Summary)
- Skills are affix containers — never invent custom logic outside the affix system
- The dice placement system (position, neighbors, element) is the game's unique mechanic — the best skills interact with it
- Skills should create synergy chains ("if you invested in X, then Y becomes much better")
- Every skill must be uniquely impactful — no filler, no stat sticks, no redundancy

---

## System Constraints (Hard Rules)

### Grid
- **8 tiers** (rows), **7 columns** (0-6). Column 3 = center.
- No two skills may share the same (tier, column) position.
- `tier` range: 1-8. `column` range: 0-6.

### Tier Unlock Thresholds
Points that must be spent in THIS tree before skills in each tier become available:

| Tier | Points Required | Auto Die Size |
|------|----------------|---------------|
| 1 | 0 | D4 |
| 2 | 1 | D6 |
| 3 | 3 | — |
| 4 | 6 | D8 |
| 5 | 9 | — |
| 6 | 12 | D10 |
| 7 | 16 | — |
| 8 | 20 | D12 |

**Rule:** Each skill's `tree_points_required` MUST match its tier's threshold from this table.
**Rule:** Die size unlocks are tier rewards, not skills. Attach `MANA_SIZE_UNLOCK` (cat=38) to the tier progression system, never as a skill's primary purpose.

### Prerequisites
- Same-tree only — never cross-tree prerequisites
- Each prerequisite is a `SkillPrerequisite` with `required_skill` + `required_rank` (default 1)
- Weave points (Tier 5-6) require prerequisites from 2 different branches
- `skill_point_cost` is always 1 unless specifically justified

### Ranks
- Each skill has 1-5 ranks. Each rank = array of Affixes.
- System behavior: when ranking up, OLD rank affixes are removed, NEW rank affixes are applied
- Therefore each rank's affixes must be the COMPLETE set for that rank (not incremental deltas)
- Multi-rank skills with system unlocks: REPEAT the unlock affixes in every rank (see Storm Spark pattern)

### Skills Per Tree
- Target range: **18-22 skills** per tree
- Tier 1: 1 (root). Tier 2: 3. Tier 3: 3. Tier 4: 3. Tier 5: 2-3. Tier 6: 2-3. Tier 7: 2. Tier 8: 1-2.
- Branch distribution: A (columns 0-1), C (columns 2-4), B (columns 5-6)

---

## Mechanical Building Blocks

Skills grant affixes. Each affix has a `category` (integer enum) that determines its mechanical effect. Below is the complete catalog of what skills can do.

### System Unlocks

**MANA_ELEMENT_UNLOCK (cat=37)**
Unlocks an element for the mana die. Required in every tree's root skill.
```
category = 37
effect_data = {"element": "FIRE"}  # or "ICE", "SHOCK", "POISON", "SHADOW"
```

**MANA_SIZE_UNLOCK (cat=38)**
Unlocks a die size for mana die. **Baked into tier progression** — die sizes are automatic tier rewards, NOT individual skills. D4=T1, D6=T2, D8=T4, D10=T6, D12=T8. A skill may include this as a rider on a multi-effect affix set, but NEVER as its primary purpose.
```
category = 38
effect_data = {"die_size": 6}  # 4, 6, 8, 10, 12, 20
```

### Stat Passives

Flat bonuses and multipliers. **WARNING: These must NEVER be standalone skills.** Always embed stat bonuses inside a conditional, scaling, positional, trigger, or compound pattern (see Design Philosophy §2.1). These categories exist for equipment affixes and as riders on multi-effect skills.

| Category | Int | Name | effect_number meaning |
|----------|-----|------|----------------------|
| STRENGTH_BONUS | 1 | +STR | Flat strength add |
| AGILITY_BONUS | 2 | +AGI | Flat agility add |
| INTELLECT_BONUS | 3 | +INT | Flat intellect add |
| LUCK_BONUS | 4 | +LCK | Flat luck add |
| STRENGTH_MULTIPLIER | 5 | ×STR | Multiply (1.1 = +10%) |
| AGILITY_MULTIPLIER | 6 | ×AGI | Multiply |
| INTELLECT_MULTIPLIER | 7 | ×INT | Multiply |
| LUCK_MULTIPLIER | 8 | ×LCK | Multiply |
| DAMAGE_BONUS | 9 | +DMG | Global flat damage |
| DAMAGE_MULTIPLIER | 10 | ×DMG | Global damage mult |
| DEFENSE_BONUS | 11 | +DEF | Global flat defense |
| DEFENSE_MULTIPLIER | 12 | ×DEF | Global defense mult |
| ARMOR_BONUS | 13 | +Armor | Flat armor |
| FIRE_RESIST_BONUS | 14 | +Fire Res | Flat fire resistance |
| ICE_RESIST_BONUS | 15 | +Ice Res | Flat ice resistance |
| SHOCK_RESIST_BONUS | 16 | +Shock Res | Flat shock resistance |
| POISON_RESIST_BONUS | 17 | +Poison Res | Flat poison resistance |
| SHADOW_RESIST_BONUS | 18 | +Shadow Res | Flat shadow resistance |
| SLASHING_DAMAGE_BONUS | 19 | +Slash DMG | Type-specific damage |
| BLUNT_DAMAGE_BONUS | 20 | +Blunt DMG | Type-specific damage |
| PIERCING_DAMAGE_BONUS | 21 | +Pierce DMG | Type-specific damage |
| FIRE_DAMAGE_BONUS | 22 | +Fire DMG | Type-specific damage |
| ICE_DAMAGE_BONUS | 23 | +Ice DMG | Type-specific damage |
| SHOCK_DAMAGE_BONUS | 24 | +Shock DMG | Type-specific damage |
| POISON_DAMAGE_BONUS | 25 | +Poison DMG | Type-specific damage |
| SHADOW_DAMAGE_BONUS | 26 | +Shadow DMG | Type-specific damage |
| BARRIER_BONUS | 27 | +Barrier | Flat barrier |
| HEALTH_BONUS | 28 | +HP | Flat health |
| MANA_BONUS | 29 | +Mana | Flat mana |

### Elemental Combat Modifiers

| Category | Int | Name | effect_data |
|----------|-----|------|-------------|
| ELEMENTAL_DAMAGE_MULTIPLIER | 41 | ×Element DMG | `{"element": "FIRE"}` — multiplies all damage of that element |
| STATUS_DAMAGE_MULTIPLIER | 42 | ×Status DMG | `{"status_id": "burn"}` — multiplies damage to targets with status |
| RESISTANCE_BYPASS | 43 | Resist Bypass | Flat resistance bypass for an element |

### Mana Die Affixes (cat=39)

The most mechanically interesting category. Wraps a DiceAffix inside an Affix.

**Template:**
```
category = 39
tags = ["class", "tree", "mana_die_affix"]
effect_data = {
    "dice_affix": <DiceAffix resource>
}
```

**DiceAffix structure:**
```
affix_name = "Skill: Effect Description"
trigger = <int>           # 0=ON_ROLL, 1=ON_USE, 2=PASSIVE
position_requirement = <int>  # 0=ANY, 1=FIRST, 2=LAST, etc.
neighbor_target = <int>   # 0=SELF, 1=LEFT, 2=RIGHT, 3=BOTH, etc.
condition = <DiceAffixCondition or null>
effect_type = <int>       # See DiceAffix.EffectType enum
effect_value = <float>
value_source = <int>      # 0=STATIC (default)
effect_data = { ... }     # Type-specific data
```

**Common MANA_DIE_AFFIX patterns (from existing trees):**

| Pattern | trigger | effect_type | Example |
|---------|---------|-------------|---------|
| Value boost to neighbors | 1 (ON_USE) | 0 (MODIFY_VALUE_FLAT) | Kindling: +1 to adjacent fire dice |
| Conditional status on use | 1 (ON_USE) | 16 (GRANT_STATUS_EFFECT) | Ember Dice: max roll → Burn |
| Splash damage | 1 (ON_USE) | 23 (EMIT_SPLASH_DAMAGE) | Pyroclasm: 50% splash |
| Chain damage | 1 (ON_USE) | 24 (EMIT_CHAIN_DAMAGE) | Firestorm: chain to 2 enemies |
| Bonus damage vs status | 1 (ON_USE) | 26 (EMIT_BONUS_DAMAGE) | Fuel the Fire: +2 vs Burn |
| Auto-reroll low | 1 (ON_USE) | 10 (AUTO_REROLL_LOW) | Heat Shimmer: reroll below threshold |
| Mana refund | 1 (ON_USE) | 27 (MANA_REFUND) | Mana Flare: refund on low roll |
| Copy neighbor value | 1 (ON_USE) | 14 (COPY_NEIGHBOR_VALUE) | Ember Link: copy 15% of neighbor |

### Action Grants (cat=31)

Grants a combat action to the player.

**Template:**
```
category = 31
effect_data = {"action_id": "action_id_here"}
granted_action = <Action resource>
```

**Action resource structure:**
```
action_id = "unique_action_id"
action_name = "Display Name"
die_slots = 2                    # How many dice it accepts
min_dice_required = 1            # Minimum to execute
damage_element = 3               # DamageType enum (3=FIRE)
charge_type = 0                  # 0=UNLIMITED, 1=LIMITED_PER_TURN, 2=LIMITED_PER_COMBAT
max_charges = 0                  # Only for limited types
effects = [<ActionEffect>, ...]  # Effect chain
```

**ActionEffect structure:**
```
effect_type = 0        # 0=DAMAGE, 1=HEAL, 2=ADD_STATUS, etc.
target = 1             # 0=SELF, 1=SINGLE_ENEMY, 2=ALL_ENEMIES, etc.
base_damage = 0        # Base before dice
damage_multiplier = 1.0  # Scales dice contribution
value_source = 1       # 1=DICE_TOTAL (most common)
damage_type = 3        # 3=FIRE
```

**Common action patterns:**
- Single-target nuke: 2 dice, SINGLE_ENEMY, ×1.0-1.5 multiplier
- AoE blast: 2-3 dice, ALL_ENEMIES, ×0.5-0.8 multiplier (reduced for multi-target)
- Status applicator: 1 die, applies stacks = die value
- Utility: 1-2 dice, self-target, grants shield/armor/heal
- Per-combat charge: charge_type=1 or 2, max_charges=1-3

### Proc/Trigger Effects

**PROC (cat=35):** General proc on combat triggers.
```
category = 35
proc_trigger = <int>   # See ProcTrigger enum
proc_chance = 0.3      # 30% chance
effect_data = {
    "effect_type": "apply_status",
    "status_id": "burn",
    "stacks": 1
}
```

**PER_TURN (cat=33):** Triggers each turn.
```
category = 33
effect_data = {
    "trigger": "turn_start",  # or "turn_end"
    "effect_type": "gain_barrier",
    "value": 3
}
```

**ON_HIT (cat=34):** Specifically on dealing damage.

### Class Action Modifiers (cat=53-57)

Modify the class's base action (e.g., Chromatic Bolt for Mage).

**CLASS_ACTION_STAT_MOD (cat=53):**
```
category = 53
effect_number = 0.2     # Value to add/multiply
effect_data = {"property": "damage_multiplier", "operation": "add"}
```

**CLASS_ACTION_EFFECT_ADD (cat=54):**
```
category = 54
effect_data = {
    "action_effect": <ActionEffect resource>,
    "shock_die_condition": true  # Optional: only when using shock die
}
```

**CLASS_ACTION_EFFECT_REPLACE (cat=55):**
```
category = 55
effect_data = {"effect_index": 0, "action_effect": <ActionEffect resource>}
```

**CLASS_ACTION_UPGRADE (cat=56):**
```
category = 56
granted_action = <Action resource>  # Wholesale replacement
```

**CLASS_ACTION_CONDITIONAL (cat=57):**
```
category = 57
effect_data = {"condition": <AffixCondition>, "action_effect": <ActionEffect>}
```

### Action-Scoped Bonuses (cat=48-52)

Modify a specific action (by action_id).

| Category | Int | Name | effect_data |
|----------|-----|------|-------------|
| ACTION_DAMAGE_BONUS | 48 | +Flat to action | `{"action_id": "fireball"}` |
| ACTION_DAMAGE_MULTIPLIER | 49 | ×Damage to action | `{"action_id": "fireball"}` |
| ACTION_BASE_DAMAGE_BONUS | 50 | +Base to action | `{"action_id": "fireball"}` |
| ACTION_DIE_SLOT_BONUS | 51 | +Slots to action | `{"action_id": "fireball"}` |
| ACTION_EFFECT_UPGRADE | 52 | Add/modify effect | `{"action_id": "...", "extra_effect": <ActionEffect>}` |

### Skill Rank Bonuses (cat=44-47)

Equipment-granted bonuses to skill ranks. Rarely used IN skills themselves, but available.

| Category | Int | Name | effect_data |
|----------|-----|------|-------------|
| SKILL_RANK_BONUS | 44 | +N to specific skill | `{"skill_id": "flame_inferno"}` |
| TREE_SKILL_RANK_BONUS | 45 | +N to all tree skills | `{"tree_id": "mage_flame"}` |
| CLASS_SKILL_RANK_BONUS | 46 | +N to all class skills | `{"class_id": "mage"}` |
| TAG_SKILL_RANK_BONUS | 47 | +N to tagged skills | `{"tag": "fire"}` |

### Miscellaneous (cat=36)

Custom mechanics processed by specific game systems.
```
category = 36
effect_data = {"burn_threshold_reduction": 1}  # Example: reduce burn explosion threshold
```

---

## Scaling Guidelines

### Rank Progression Patterns

**Linear Flat (most common):**
Each rank adds a fixed increment.
- Rank 1: +3, Rank 2: +6, Rank 3: +9 → increment = 3 per rank
- Remember: each rank's affix has the FULL value, not the delta

**Multiplicative:**
Small increments per rank.
- Rank 1: ×1.05, Rank 2: ×1.10, Rank 3: ×1.15 → increment = 0.05

**Proc Chance:**
- Rank 1: 15%, Rank 2: 30%, Rank 3: 45% → increment = 15%

### Value Magnitude Guidelines

| Category | Low Tier (2-3) | Mid Tier (4-5) | High Tier (6+) |
|----------|---------------|----------------|----------------|
| Flat damage bonus | +2-3/rank | +3-5/rank | +4-8/rank |
| Damage multiplier | ×1.03-1.05/rank | ×1.05-1.08/rank | ×1.08-1.15/rank |
| Proc chance | 10-15%/rank | 15-20%/rank | 20-25%/rank |
| Bonus vs status | +2-3/rank | +3-5/rank | +4-6/rank |
| Splash/chain % | 20-30% base | 30-50% base | 50-75% base |
| Resistance | +3-5/rank | +5-8/rank | +8-12/rank |
| Flat stat | +2-3/rank | +3-5/rank | +5-8/rank |

### When to Use Multi-Rank

| Ranks | Use For | Examples |
|-------|---------|---------|
| 1 | Binary unlocks, transformative effects, action grants, capstones | Ignite, Eruption, Pyroclastic Flow |
| 2 | Moderate scaling, effects with natural breakpoints | Firestorm (20%→35%), Accelerant (+1→+2 stacks) |
| 3 | Standard scaling passives, core identity skills | Searing Force, Immolate, Conflagrant Surge |
| 5 | Deep investment rewards (rare) | Reserved for cornerstone skills |

---

## Naming & Theming Conventions

### Skill IDs
`{tree_element}_{snake_case_name}` — e.g., `flame_ignite`, `storm_spark`, `frost_glaciate`

### Affix Names
`"{SkillName}: {Effect Description}"` — e.g., `"Kindling: Fire Adjacency"`, `"Pyroclasm: Splash 50%"`

### Descriptions (BBCode)
- Element colors: `[color=orange]fire[/color]`, `[color=cyan]ice[/color]`, `[color=yellow]shock[/color]`, `[color=green]poison[/color]`, `[color=purple]shadow[/color]`
- Status names: `[color=red]Burn[/color]`, `[color=cyan]Static[/color]`, `[color=blue]Freeze[/color]`
- Action grants prefix: `[color=yellow]ACTION:[/color] Description`
- Values in descriptions: `[color=yellow]N[/color]` for scaling values

### Tags
Always include: `["{class}", "{tree_element}", "{functional_tags}"]`
Functional tags: `"element_unlock"`, `"size_unlock"`, `"mana_die_affix"`, `"granted_action"`, `"fire_damage"`, `"vs_burn"`, `"splash"`, `"chain"`, `"class_action_mod"`, etc.

### File Paths
- Skills: `resources/skills/classes/{class}/{tree_element}/{skill_id}.tres`
- External affixes: `resources/affixes/classes/{class}/{tree_element}/{skill_name}/{affix_name}.tres`
- Actions: `resources/actions/{class}/{tree_element}/{action_id}.tres`

---

## Output Templates

### Design Overview

```
## {Tree Name} Tree — {Element} ({Class})
Theme: {fantasy description}
Status Effect: {name} — {brief mechanic description}

### Grid Layout (8 tiers × 7 columns)
         Col 0    Col 1    Col 2    Col 3    Col 4    Col 5    Col 6
         ←Branch A→        ←——Branch C——→        ←Branch B→
Tier 1:                              [Root]
Tier 2:           [A-1]              [C-1]              [B-1]
Tier 3:  [A-2]             [C-2]              [C-3]              [B-2]
Tier 4:           [A-3]    [C-4]              [C-5]    [B-3]
Tier 5:  [A-4]                       [Weave]                     [B-4]
Tier 6:           [A-5]              [Weave?]           [B-5]
Tier 7:                    [Apex-1]           [Apex-2]
Tier 8:                              [Cap]

### Skill List
| # | Skill Name | ID | Tier | Col | Ranks | Category | Synopsis |
|---|------------|----|------|-----|-------|----------|----------|
| 1 | Root       | tree_root | 1 | 3 | 1 | MANA_ELEMENT_UNLOCK | Unlock element |
| 2 | ...        | ...       | 2 | 1 | 3 | MANA_DIE_AFFIX      | ... |

### Prerequisites
root → skill_a
root → skill_b
skill_a → skill_c
skill_b + skill_c → skill_d (convergence)

### Synergy Chains
Chain 1: A applies Status → B bonus vs Status → C lowers threshold → D spreads on trigger
Chain 2: ...
```

### .tres-Ready Spec (per skill)

```
### {skill_name} ({skill_id})
tier: {N}, column: {N}, cost: 1, tree_points_required: {N}
prerequisites: [{prereq_skill_id} rank {N}]
tags: ["{class}", "{tree}", "{functional}"]
description: "{BBCode description}"

Rank 1:
  Affix: "{affix_name}"
    category = {int} ({NAME})
    effect_number = {N}
    tags = ["{class}", "{tree}", "{functional}"]
    effect_data = { ... }

  [If MANA_DIE_AFFIX (cat=39):]
  Affix: "{affix_name}"
    category = 39
    effect_data.dice_affix:
      affix_name = "{name}"
      trigger = {int} ({NAME})
      position_requirement = {int} ({NAME})
      neighbor_target = {int} ({NAME})
      condition:
        type = {int} ({NAME})
        threshold = {N}
        condition_element = "{ELEMENT}"
      effect_type = {int} ({NAME})
      effect_value = {N}
      value_source = {int} ({NAME})
      effect_data = { ... }

  [If NEW_ACTION (cat=31):]
  Affix: "{affix_name}"
    category = 31
    effect_data = {"action_id": "{id}"}
    granted_action:
      action_id = "{id}"
      action_name = "{name}"
      die_slots = {N}
      min_dice_required = {N}
      damage_element = {int} ({NAME})
      charge_type = {int}
      max_charges = {int}
      effects:
        [0] type={int}({NAME}), target={int}({NAME}), base={N}, mult={N}, value_source={int}
        [1] ...

Rank 2: (if multi-rank — FULL replacement set, not delta)
  ...
```

---

## Enum Quick Reference

### Affix.Category
```
 0 NONE                    27 BARRIER_BONUS
 1 STRENGTH_BONUS          28 HEALTH_BONUS
 2 AGILITY_BONUS           29 MANA_BONUS
 3 INTELLECT_BONUS         30 ELEMENTAL
 4 LUCK_BONUS              31 NEW_ACTION
 5 STRENGTH_MULTIPLIER     32 DICE
 6 AGILITY_MULTIPLIER      33 PER_TURN
 7 INTELLECT_MULTIPLIER    34 ON_HIT
 8 LUCK_MULTIPLIER         35 PROC
 9 DAMAGE_BONUS            36 MISC
10 DAMAGE_MULTIPLIER       37 MANA_ELEMENT_UNLOCK
11 DEFENSE_BONUS           38 MANA_SIZE_UNLOCK
12 DEFENSE_MULTIPLIER      39 MANA_DIE_AFFIX
13 ARMOR_BONUS             40 MANA_COST_MULTIPLIER
14 FIRE_RESIST_BONUS       41 ELEMENTAL_DAMAGE_MULTIPLIER
15 ICE_RESIST_BONUS        42 STATUS_DAMAGE_MULTIPLIER
16 SHOCK_RESIST_BONUS      43 RESISTANCE_BYPASS
17 POISON_RESIST_BONUS     44 SKILL_RANK_BONUS
18 SHADOW_RESIST_BONUS     45 TREE_SKILL_RANK_BONUS
19 SLASHING_DAMAGE_BONUS   46 CLASS_SKILL_RANK_BONUS
20 BLUNT_DAMAGE_BONUS      47 TAG_SKILL_RANK_BONUS
21 PIERCING_DAMAGE_BONUS   48 ACTION_DAMAGE_BONUS
22 FIRE_DAMAGE_BONUS       49 ACTION_DAMAGE_MULTIPLIER
23 ICE_DAMAGE_BONUS        50 ACTION_BASE_DAMAGE_BONUS
24 SHOCK_DAMAGE_BONUS      51 ACTION_DIE_SLOT_BONUS
25 POISON_DAMAGE_BONUS     52 ACTION_EFFECT_UPGRADE
26 SHADOW_DAMAGE_BONUS     53 CLASS_ACTION_STAT_MOD
                           54 CLASS_ACTION_EFFECT_ADD
                           55 CLASS_ACTION_EFFECT_REPLACE
                           56 CLASS_ACTION_UPGRADE
                           57 CLASS_ACTION_CONDITIONAL
```

### Affix.ValueSource
```
0 STATIC                  5 EQUIPMENT_RARITY_SUM
1 PLAYER_STAT             6 DICE_POOL_SIZE
2 PLAYER_HEALTH_PERCENT   7 COMBAT_TURN_NUMBER
3 EQUIPPED_ITEM_COUNT     8 UNIQUE_ELEMENTS_USED
4 ACTIVE_AFFIX_COUNT
```

### Affix.ProcTrigger
```
 0 NONE               7 ON_DIE_USED
 1 ON_DEAL_DAMAGE     8 ON_ACTION_USED
 2 ON_TAKE_DAMAGE     9 ON_KILL
 3 ON_TURN_START     10 ON_DEFEND
 4 ON_TURN_END       11 ON_MANA_PULL
 5 ON_COMBAT_START   12 ON_STATUS_APPLIED
 6 ON_COMBAT_END
```

### DiceAffix.Trigger
```
0 ON_ROLL          3 ON_REORDER
1 ON_USE           4 ON_COMBAT_START
2 PASSIVE          5 ON_COMBAT_END
```

### DiceAffix.PositionRequirement
```
0 ANY              4 NOT_LAST
1 FIRST            5 SPECIFIC_SLOT
2 LAST             6 EVEN_SLOTS
3 NOT_FIRST        7 ODD_SLOTS
```

### DiceAffix.NeighborTarget
```
0 SELF             4 ALL_LEFT
1 LEFT             5 ALL_RIGHT
2 RIGHT            6 ALL_OTHERS
3 BOTH_NEIGHBORS   7 ALL_DICE
```

### DiceAffix.EffectType
```
 0 MODIFY_VALUE_FLAT       16 GRANT_STATUS_EFFECT
 1 MODIFY_VALUE_PERCENT    17 CONDITIONAL
 2 SET_MINIMUM_VALUE       18 RANDOMIZE_ELEMENT
 3 SET_MAXIMUM_VALUE       19 LEECH_HEAL
 4 SET_ROLL_VALUE          20 DESTROY_SELF
 5 ADD_TAG                 21 SET_ELEMENT
 6 REMOVE_TAG              22 CREATE_COMBAT_MODIFIER
 7 COPY_TAGS               23 EMIT_SPLASH_DAMAGE
 8 REMOVE_ALL_TAGS         24 EMIT_CHAIN_DAMAGE
 9 GRANT_REROLL            25 EMIT_AOE_DAMAGE
10 AUTO_REROLL_LOW         26 EMIT_BONUS_DAMAGE
11 DUPLICATE_ON_MAX        27 MANA_REFUND
12 LOCK_DIE                28 MANA_GAIN
13 CHANGE_DIE_TYPE         29 ROLL_KEEP_HIGHEST
14 COPY_NEIGHBOR_VALUE     30 GRANT_EXTRA_ROLL
15 ADD_DAMAGE_TYPE         31 IGNORE_RESISTANCE
```

### DiceAffix.ValueSource
```
 0 STATIC                   7 PARENT_TARGET_VALUE
 1 SELF_VALUE               8 PARENT_TARGET_PERCENT
 2 SELF_VALUE_FRACTION      9 SNAPSHOT_TARGET_VALUE
 3 NEIGHBOR_VALUE          10 SNAPSHOT_TARGET_PERCENT
 4 NEIGHBOR_PERCENT        11 CONTEXT_ELEMENT_DICE_USED
 5 CONTEXT_USED_COUNT      12 CONTEXT_DICE_PLACED
 6 SELF_TAGS
```

### DiceAffixCondition.Type
```
 0 NONE                    13 SELF_ELEMENT_IS
 1 SELF_VALUE_ABOVE        14 SELF_ELEMENT_NOT
 2 SELF_VALUE_BELOW        15 NEIGHBOR_HAS_ELEMENT
 3 SELF_VALUE_BELOW_HALF   16 ALL_NEIGHBORS_HAVE_ELEMENT
 4 SELF_VALUE_IS_MAX       17 NEIGHBOR_ELEMENT_DIFFERS
 5 SELF_VALUE_IS_MIN       18 MIN_ELEMENT_DICE_USED
 6 NEIGHBOR_VALUE_ABOVE    19 PER_ELEMENT_DIE_USED
 7 ALL_NEIGHBORS_ABOVE     20 PER_DIE_PLACED_THIS_TURN
 8 NEIGHBORS_USED          21 TARGET_HAS_STATUS
 9 MIN_DICE_USED           22 TARGET_STATUS_STACKS_ABOVE
10 MAX_DICE_USED           23 SELF_DIE_TYPE_IS
11 PER_USED_DIE            24 SELF_DIE_TYPE_ABOVE
12 PER_QUALIFYING_NEIGHBOR
```

### ActionEffect.EffectType
```
 0 DAMAGE              12 ECHO
 1 HEAL                13 SPLASH
 2 ADD_STATUS          14 CHAIN
 3 REMOVE_STATUS       15 RANDOM_STRIKES
 4 CLEANSE             16 MANA_MANIPULATE
 5 SHIELD              17 MODIFY_COOLDOWN
 6 ARMOR_BUFF          18 REFUND_CHARGES
 7 DAMAGE_REDUCTION    19 GRANT_TEMP_ACTION
 8 REFLECT             20 CHANNEL
 9 LIFESTEAL           21 COUNTER_SETUP
10 EXECUTE             22 SUMMON_COMPANION
11 COMBO_MARK
```

### ActionEffect.TargetType
```
0 SELF           3 SINGLE_ALLY
1 SINGLE_ENEMY   4 ALL_ALLIES
2 ALL_ENEMIES
```

### ActionEffect.DamageType
```
0 SLASHING   4 ICE
1 BLUNT      5 SHOCK
2 PIERCING   6 POISON
3 FIRE       7 SHADOW
```

### ActionEffect.ValueSource
```
 0 STATIC                  10 ACTIVE_STATUS_COUNT
 1 DICE_TOTAL              11 MANA_PERCENT
 2 DICE_COUNT              12 SOURCE_CURRENT_HP
 3 SOURCE_STAT             13 SOURCE_MAX_HP
 4 SOURCE_HP_PERCENT       14 SOURCE_DEFENSE_STAT
 5 SOURCE_MISSING_HP       15 TARGET_CURRENT_HP
 6 TARGET_HP_PERCENT       16 TARGET_MAX_HP
 7 TARGET_MISSING_HP       17 ALIVE_ENEMY_COUNT
 8 TARGET_STATUS_STACKS    18 ALIVE_COMPANION_COUNT
 9 TURN_NUMBER             19 TRIGGER_DAMAGE_AMOUNT
```

### ActionEffectCondition.ConditionType
```
 0 NONE                 8 DICE_TOTAL_ABOVE
 1 SOURCE_HP_ABOVE      9 DICE_TOTAL_BELOW
 2 SOURCE_HP_BELOW     10 DICE_COUNT_ABOVE
 3 TARGET_HP_ABOVE     11 TURN_NUMBER_ABOVE
 4 TARGET_HP_BELOW     12 MANA_ABOVE
 5 TARGET_HAS_STATUS   13 MANA_BELOW
 6 TARGET_MISSING_STATUS 14 RANDOM_CHANCE
 7 SOURCE_HAS_STATUS
```

---

## Existing Tree Reference (Legacy — Pre-Philosophy)

> **These trees were designed before the design philosophy was established.** They contain known anti-patterns: pure stat sticks (Searing Force, Capacitance, Charged Strikes), redundant status applicators, action flooding (6-8 actions per tree), die size unlock filler, and bridge skills. Use as reference for .tres structure and affix patterns, NOT as design templates. New trees should follow the philosophy in §2.

### Mage — Flame Tree (31 skills)

| Skill | Tier | Col | Ranks | Categories | Synopsis |
|-------|------|-----|-------|------------|---------|
| Ignite | 1 | 3 | 1 | 37 | Unlock FIRE element |
| Ember Dice | 2 | 1 | 1 | 38,39 | Unlock D6; max roll → Burn |
| Searing Force | 2 | 3 | 3 | 22 | +3/6/9 fire damage |
| Kindling | 2 | 5 | 1 | 39 | Adjacent fire dice +1 |
| Fuel the Fire | 3 | 0 | 3 | 39 | +2/4/6 bonus vs Burn |
| Pyroclasm | 3 | 2 | 1 | 38,39 | Unlock D8; splash 50% |
| Heat Shimmer | 3 | 4 | 3 | 39 | Auto-reroll below 2/3/4 |
| Flame Ward | 3 | 6 | 3 | 35 | +3/6/9 barrier/turn |
| Accelerant | 4 | 0 | 2 | 36 | Burn apps +1/2 bonus stacks |
| Immolate | 4 | 1 | 3 | 35 | 15/30/45% Burn on fire damage |
| Conflagrant Surge | 4 | 3 | 3 | 41 | Fire ×1.05/1.10/1.15 |
| Mana Flare | 4 | 5 | 1 | 39 | Refund 1 mana on low roll |
| Hearthfire | 4 | 6 | 2 | 39 | +1/2 to fire dice next to non-fire |
| Inferno | 5 | 1 | 3 | 38,36 | Unlock D10; Burn threshold -1/-2/-3 |
| Eruption | 5 | 3 | 1 | 31 | ACTION: 2 dice → all enemies 60% fire |
| Tempered Steel | 5 | 5 | 3 | 35 | +2/4/6 armor per fire die used |
| Burning Vengeance | 6 | 0 | 1 | 31 | ACTION: 1 die → 50% fire + Burn=value |
| Flashpoint | 6 | 2 | 1 | 35 | Burn explosions splash 50% |
| Firestorm | 6 | 3 | 2 | 39 | Fire dice chain 20/35% to 2 enemies |
| Forge Bond | 6 | 4 | 1 | 39 | First/last position +25% damage |
| Detonate | 7 | 1 | 1 | 31 | ACTION: consume Burn, dmg=stacks×3 |
| Cinder Storm | 7 | 2 | 1 | 31 | ACTION: 3 dice → all enemies 50% + 2 Burn |
| Radiance | 7 | 4 | 1 | 31 | ACTION: armor, barrier, +fire dmg |
| Ember Link | 7 | 5 | 2 | 39 | Copy 15/25% of neighbor values |
| Crucible's Gift | 8 | 4 | 1 | 35 | 2+ targets hit → mana discount |
| Pyroclastic Flow | 8 | 2 | 1 | 35 | Burn explosion → 3 Burn to all enemies |
| Volcanic Core | 8 | 3 | 1 | 31 | ACTION: 3 dice, execute ×2 below 30% |
| Eternal Flame | 9 | 1 | 1 | 31 | ACTION: 2 dice, Burn=total, can't expire 3t |
| Ironfire Stance | 9 | 5 | 1 | 31 | ACTION: 25% reduction, 30% reflect, heal |
| Conflagration | 10 | 3 | 1 | 38,39 | Unlock D12; ignore resist; ×2 vs Burn |

### Mage — Storm Tree (33 skills)

| Skill | Tier | Col | Ranks | Categories | Synopsis |
|-------|------|-----|-------|------------|---------|
| Spark | 1 | 3 | 3 | 37,38,54 | Unlock SHOCK; Bolt applies 1/2/3 Static |
| Arc Pulse | 2 | 1 | 3 | 39 | Shock dice apply 1/2/3 Static on use |
| Crackling Force | 2 | 3 | 3 | 41 | Shock ×1.05/1.10/1.15 |
| Capacitance | 2 | 5 | 3 | 3 | +2/4/6 Intellect |
| Ionize | 3 | 0 | 3 | 39 | Pull shock die → 1/2/3 Static to random |
| Charged Strikes | 3 | 2 | 3 | 24 | +2/4/6 shock damage |
| Conjure Storm Sprite | 3 | 3 | 1 | 31 | ACTION: summon Storm Sprite |
| Surge Efficiency | 3 | 4 | 3 | 40 | Shock pull cost -1/2/3 |
| Live Wire | 4 | 1 | 2 | 39 | +1/2 Static if target has Static |
| Thunderclap | 4 | 2 | 1 | 31 | ACTION: 2 dice → ×1.2 shock + 3 Static |
| Static Cling | 4 | 0 | 3 | 33 | Static duration +1/2/3 turns |
| Voltaic Surge | 4 | 3 | 3 | 41 | +1/2/3% shock dmg per Static stack |
| Mana Siphon | 4 | 5 | 3 | 33 | Shock kill → restore 3/5/7 mana |
| Storm Charge | 5 | 1 | 3 | 39 | 10+ Static → splash 1/2/3 to all |
| Tempest Sprite | 5 | 2 | 2 | 54 | Sprite chains to 1/2; explodes on death |
| Lightning Bolt | 5 | 3 | 1 | 31 | ACTION: 2 dice → ×1.5, chain 1 for 50% |
| Conduit Sprite | 5 | 4 | 2 | 54,33 | Sprite restores mana; free die per 2 turns |
| Conduit Flow | 5 | 5 | 3 | 38,33 | Unlock D6; +1/2/3 mana regen |
| Voltaic Sprite | 5 | 0 | 2 | 39 | Sprite applies 2/3 Static; fires on turn start |
| Persistent Field | 6 | 0 | 2 | 36 | Static max stacks +5/10 |
| Arc Conduit | 6 | 2 | 2 | 39 | Shock dice chain 40/60% to 1 enemy |
| Grounded Circuit | 6 | 4 | 2 | 33 | Shock dmg to Static targets → 1/2 mana |
| Galvanic Renewal | 6 | 6 | 2 | 31 | Shock kill → free shock die 1/2 per turn |
| Overcharge | 7 | 1 | 1 | 31 | ACTION: dmg = Static stacks × 3 |
| Chain Lightning | 7 | 2 | 1 | 31 | ACTION: 2 dice → ×1.0, chain 2 for 60% |
| Dynamo | 7 | 4 | 2 | 38,39 | Unlock D8; shock dice +1/2 |
| Static Discharge | 7 | 5 | 1 | 31 | Static target dies → AoE + half as Static |
| Tesla Coil | 8 | 1 | 1 | 39 | Chain +1 target; 2 Static per bounce |
| Storm Surge | 8 | 3 | 1 | 31 | ACTION: 3 dice → all enemies ×0.8 + 3 Static |
| Feedback Loop | 8 | 5 | 2 | 54,39 | Double mana restore; +3/6 shock bonus |
| Thunderhead | 9 | 1 | 2 | 39 | Turn start → 2/3 Static to all enemies |
| Stormcaller | 9 | 4 | 2 | 39,54 | Static bonus +2/3; Bolt chains all enemies |
| Eye of the Storm | 10 | 3 | 1 | 36,39 | Double max Static; chains return to origin |

---

## Key Implementation Files

| File | Purpose |
|------|---------|
| `scripts/resources/skill_resource.gd` | SkillResource data model |
| `scripts/data/skill_tree.gd` | SkillTree container (8 tiers × 7 cols) |
| `resources/data/affix.gd` | Affix with Category enum |
| `resources/data/dice_affix.gd` | DiceAffix with all enums |
| `resources/data/dice_affix_condition.gd` | DiceAffixCondition.Type |
| `scripts/resources/action_effect.gd` | ActionEffect system |
| `scripts/resources/action_effect_condition.gd` | Effect conditions |
| `resources/data/player_class.gd` | PlayerClass structure |
| `scripts/combat/class_action_resolver.gd` | Class action resolution |
| `resources/skills/classes/mage/flame/*.tres` | Flame tree (31 skills) |
| `resources/skills/classes/mage/storm/*.tres` | Storm tree (33 skills) |
