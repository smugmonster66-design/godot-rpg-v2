# Companion Builder — Designer's Guide

## What This Addon Does

The Companion Builder is an in-editor tool for creating and editing companion characters. Companions are allies that fight alongside the player — they don't take turns like enemies do. Instead, they **react** to events (player damaged, turn start, enemy killed, etc.) and automatically fire their action when triggered.

Everything is configured through the editor addon. No scripting required. You fill in fields, pick from dropdowns, browse for resources, and save `.tres` files.

---

## Opening the Addon

The Companion Builder lives in the **bottom panel** of the Godot editor (same row as Output, Debugger, etc.). Click the **"Companions"** tab to open it.

You'll see two panels:
- **Left — Browser:** Lists all companion `.tres` files found under `res://resources/companions/`. Click one to load it into the editor.
- **Right — Detail Editor:** Five tabs for editing the selected companion.

### Creating a New Companion

Click **"New"** in the browser toolbar. A dropdown offers templates:

| Template | What it sets up |
|----------|----------------|
| Blank | Empty companion, 50 HP, FLAT scaling |
| Healer NPC | Heals lowest-HP ally at end of player turn, HP scales with player% |
| DPS NPC | Damages random enemy at start of player turn, HP scales with player level |
| Tank NPC | Taunts and damages all enemies |
| Temp DPS Summon | 3-turn summon, damages random enemy, skips first turn |
| Reactive Protector | Shields player when they take damage, 1-turn cooldown |
| Death Rattle Summon | Damages all enemies when it dies |

Templates are starting points — change anything you want after picking one.

### Saving

Click **"Save"** in the toolbar. The companion is written as a `.tres` resource file. Companions are saved to `res://resources/companions/` by default.

Click **"Validate"** to check for common errors (missing name, zero HP, etc.) before saving.

---

## Tab 1: Identity

The basics of who this companion is.

### Name
**Field:** Text input
**Maps to:** `companion_name`

The display name shown in combat UI, party management, and info popups. Examples: "Manne", "Frost Spirit", "Shadow Wolf".

### Companion ID
**Field:** Text input + Auto button
**Maps to:** `companion_id`

A unique `StringName` identifier used for two systems:
- **Relationships** — The game tracks a -100 to +100 relationship value per companion_id. This is how the player builds trust with companions over time.
- **Explicit synergies** — Synergy definitions can require specific companion_ids to be active together.

Click **"Auto"** to generate an ID from the name (lowercased, spaces replaced with underscores). Example: "Frost Spirit" → `frost_spirit`.

Must be unique across all companions. Leave empty only for generic summons that don't need relationships.

### Description
**Field:** Multi-line text
**Maps to:** `description`

Lore and flavour text displayed in the companion info popup. Supports BBCode formatting.

### Action Name
**Field:** Text input
**Maps to:** `action_name`

The name of this companion's triggered action, shown in combat log and UI. Examples: "Manneslaughter", "Frost Mend", "Shadow Bite".

### Action Description
**Field:** Multi-line text
**Maps to:** `action_description`

Narrative description of the action shown in the companion info popup. Tell the player what the companion does in plain language. Example: "Manne leaps forward and strikes all enemies, then taunts them to attack him instead."

### Portrait
**Field:** Browse / Clear buttons + preview
**Maps to:** `portrait`

A `Texture2D` used as the companion's portrait in all UI (combat slots, party management cards, info popups). Browse to pick an image from the project.

### Type
**Field:** Dropdown
**Maps to:** `companion_type`

| Value | Meaning |
|-------|---------|
| **NPC** | A persistent party member. Survives between combats with persistent HP. The player recruits, activates, and manages them through the party screen. Limited to 2 active NPC slots. |
| **Summon** | A temporary companion created by a skill, item, or effect during combat. May expire after N turns. Removed when it dies. Limited to 2 active summon slots. |

Choose **NPC** for story characters, recruited allies, and permanent followers.
Choose **SUMMON** for conjured creatures, temporary spirits, and spell effects.

### Synergy Tags
**Field:** Text input (comma-separated)
**Maps to:** `synergy_tags`

Tags used by the companion synergy system for tag-based matching. Enter tags separated by commas:

```
frost, healer, undead
```

Tags are freeform — invent whatever categories make sense for your design. Common patterns:
- **Element tags:** `frost`, `fire`, `shadow`, `holy`
- **Role tags:** `healer`, `tank`, `dps`, `support`
- **Faction tags:** `undead`, `beast`, `spirit`, `demon`
- **Thematic tags:** `noble`, `outcast`, `ancient`

A companion can have any number of tags. Tags are used by `CompanionSynergyDefinition` resources to create bonuses when certain tag combinations are active together. See the **Synergies** section below for details.

---

## Tab 2: Combat

How the companion behaves in combat.

### Health

#### Base Max HP
**Field:** Spin box (1+)
**Maps to:** `base_max_hp`

The companion's base HP before scaling. Default: 50. This is the starting point — the actual max HP depends on the scaling mode.

#### HP Scaling Mode
**Field:** Dropdown
**Maps to:** `hp_scaling`

| Mode | Formula | Use when... |
|------|---------|-------------|
| **Flat** | `max_hp = base_max_hp` | You want fixed HP. Good for summons with predetermined durability. The scaling value field is ignored. |
| **Player Percent** | `max_hp = player_max_hp × scaling_value` | You want the companion's HP to be a fraction of the player's. A scaling value of 0.3 means 30% of whatever the player has. Scales naturally as the player grows. |
| **Player Level** | `max_hp = base_max_hp + (player_level × scaling_value)` | You want a fixed base that grows linearly with level. A base of 30 with scaling 5.0 gives 30 HP at level 0, 80 HP at level 10, 130 HP at level 20. |

The HP Preview widget below the fields shows what the HP would be at various player levels and HP values so you can sanity-check your scaling.

#### HP Scaling Value
**Field:** Spin box (float)
**Maps to:** `hp_scaling_value`

The coefficient for the scaling formula. Meaning depends on scaling mode:
- **Flat:** Ignored.
- **Player Percent:** 0.3 = 30% of player HP. Keep between 0.1 (fragile summon) and 0.6 (beefy tank).
- **Player Level:** HP gained per player level. 3.0–8.0 is a reasonable range.

### Trigger

#### Trigger Type
**Field:** Dropdown
**Maps to:** `trigger`

This is the core of companion behaviour — **when** does this companion act?

| Trigger | When it fires | Good for... |
|---------|--------------|-------------|
| **Player Turn Start** | Start of the player's turn, before dice are rolled | Buffs, shields, stat boosts — things you want active before the player acts |
| **Player Turn End** | After the player finishes their turn | Heals, follow-up attacks, cleanup effects |
| **Enemy Turn Start** | When any enemy begins their turn | Reactive shields, interrupts |
| **Player Damaged** | Every time the player takes damage | Reactive heals, counter-attacks, revenge effects |
| **Player Damaged Threshold** | When player HP drops below a %. Fires once per threshold crossing, not on every hit. | Emergency heals, "last stand" effects |
| **Ally Damaged** | Any ally takes damage (player OR other companions) | Protective abilities, group healing |
| **Companion Damaged** | THIS companion takes damage | Self-heals, thorns effects, rage mechanics |
| **Other Companion Damaged** | A DIFFERENT companion takes damage | Empathy heals, avenger counter-attacks |
| **Enemy Killed** | Any enemy dies | Kill-triggered buffs, soul harvest effects |
| **Companion Killed** | Any companion dies | Avenger rage, resurrection effects |
| **Round Start** | Once per combat round (before anyone acts) | Passive auras, per-round ticking effects |
| **On Summon** | Once, when this companion enters combat | Entry effects — damage, buffs, area denial. Only meaningful for summons. |
| **On Death** | Once, when this companion dies | Death rattle effects — explosions, last-gasp heals, curses |
| **Player Hit Hard** | One hit took at least `trigger_data.min_percent` (default 0.2) of the player's max HP | Protector cover, revenge strikes |
| **Hand Rolled** | Right after the player rolls their hand, before they place dice | Dice-shaper effects (see below) |

All triggers fire (engine/companions, 2026-09-26). Reactions that happen in the middle of another action (damage, falls, kills) fire at once with a slot flash; turn-boundary triggers (turn start/end, Enemy Turn Start, Hand Rolled) play the full animation. **Companion Damaged** and **On Death** answer only for the companion itself; **Other Companion Damaged** and **Companion Killed** only for the others. **Player Damaged Threshold** fires when a hit takes the player from above the threshold to at or below it.

#### Threshold Percent
**Field:** Spin box (only visible when trigger = Player Damaged Threshold)
**Maps to:** `trigger_data["threshold_percent"]`

The HP percentage that triggers the ability. Range: 0.01 to 1.0. Example: 0.25 means the companion fires when player HP drops below 25%.

### Targeting

#### Target Rule
**Field:** Dropdown
**Maps to:** `target_rule`

Who does the companion's action affect?

| Target | Who it hits | Common pairings |
|--------|------------|-----------------|
| **Random Enemy** | One random living enemy | Basic damage companions |
| **All Enemies** | Every living enemy | AoE damage, mass debuffs |
| **Lowest HP Enemy** | Enemy with lowest current HP | Finisher/execute-style companions |
| **Player** | The player character | Heals, buffs, shields |
| **Self** | This companion itself | Self-heals, self-buffs |
| **Other Companion** | Another living companion (not this one) | Companion-to-companion support |
| **Lowest HP Ally** | Ally (player or companion) with lowest HP | Smart heals |
| **All Allies** | Player + all living companions | Group heals, party buffs |
| **Triggering Source** | Whatever caused the trigger event | Counter-attacks (target the enemy that hit the player) |
| **Damaged Ally** | The specific ally that was just damaged | Reactive shields/heals on the wounded target |
| **Downed Companion** | A downed (0 HP) NPC companion other than this one | Mender revives: a HEAL on a downed companion brings them back, Wounded |

### Condition
**Field:** Browse / Clear / Inspect buttons
**Maps to:** `condition`

An optional `AffixCondition` resource that must be satisfied for the companion to fire, even when triggered. If no condition is set, the companion always fires when triggered (subject to cooldown/uses).

Conditions are the same system used by equipment affixes. Examples:
- **Health Below Percent (0.5):** Only fire when the target is below 50% HP
- **Has Status ("burning"):** Only fire if a specific status is active
- **Turn Number Above (3):** Only fire after turn 3
- **Stat Above ("shield", 10):** Only fire when shield is above a threshold

Browse to pick an existing condition `.tres`, or create a new one in the Inspector.

### Cooldown
**Field:** Spin box (0+)
**Maps to:** `cooldown_turns`

After the companion fires, it waits this many turns before it can fire again. 0 = no cooldown (fires every time the trigger occurs).

Examples:
- **0:** Fires every trigger. Good for passive effects or low-impact actions.
- **1:** Fires every other turn at most. Good for moderate-impact abilities.
- **3:** Fires roughly once every 3 rounds. Good for powerful effects.

### Uses Per Combat
**Field:** Spin box (0+)
**Maps to:** `uses_per_combat`

Total times the companion can fire in a single combat. 0 = unlimited.

Examples:
- **0:** Unlimited uses (subject to cooldown). Most companions use this.
- **1:** One-shot ability. Good for powerful openers or emergency saves.
- **3:** Limited resource. Good for "ammo-like" abilities.

### Fires On First Turn
**Field:** Checkbox
**Maps to:** `fires_on_first_turn`

If unchecked, the companion skips the first time this ability's trigger matches in a fight. Useful for summons that shouldn't act immediately on entry (gives enemies a chance to respond). Works for NPC companions and summons, per ability.

### Taunt

#### Has Taunt
**Field:** Checkbox
**Maps to:** `has_taunt`

When checked, this companion draws enemy attacks: at the start of each enemy's turn, while the companion stands, the enemy gets one Taunted stack pointing at it and targets it with its attacks (self-buffs and heals are not redirected).

#### Taunt Duration
**Field:** Spin box (only visible when Has Taunt is checked)
**Maps to:** `taunt_duration`

How many rounds the taunt lasts. 0 = the whole fight while the companion stands.

---

## Tab 3: Effects

The actual gameplay effects of the companion's action. This uses the same **ActionEffect** system as enemy actions and player abilities.

Click **"Add Effect"** to add an effect row. Each row defines one step in the action's effect chain.

### Effect Row Fields

Each effect row maps to one `ActionEffect` resource with these key fields:

- **Effect Type:** What happens (Damage, Heal, Add Status, Shield, Chain Damage, Summon Companion, etc.)
- **Target:** Who this effect hits (see target types below)
- **Value Source:** How the effect's value is calculated (Static number, Dice Total, Source Stat, Target HP Percent, etc.)
- **Base Value:** The base number for the effect

### ActionEffect Target Types

Each ActionEffect has its own target field. For synergy bonus actions, this is the **only** targeting — each effect resolves its own targets independently.

| Target | Who it hits |
|--------|------------|
| **Self** | The source (the companion firing the action) |
| **Single Enemy** | One enemy from the caller's target list (legacy, used by player/enemy actions) |
| **All Enemies** | Every living enemy |
| **Single Ally** | One ally from the caller's target list (legacy, used by player/enemy actions) |
| **All Allies** | Player + all living companions |
| **Random Enemy** | One random living enemy |
| **Lowest HP Enemy** | Enemy with lowest current HP |
| **Lowest HP Ally** | Ally (player or companion) with lowest current HP |
| **Other Companion** | First alive companion that isn't the source |
| **Triggering Source** | The combatant that caused the trigger (e.g., enemy that dealt damage). Falls back to random enemy. |
| **Damaged Ally** | The ally that was just damaged (for reactive triggers like Player Damaged). Falls back to lowest HP ally. |

For **companion actions** (not synergy bonuses), the companion's `target_rule` field still resolves targets that are passed to all effects. The effect's own target field is used by the animation system for AoE detection.

For **synergy bonus actions**, each effect's target field is the actual targeting — there is no synergy-level target rule.

A companion can have multiple effects that fire in sequence. Example — Manne's action:
1. Effect 1: Damage All Enemies (20% of target's current HP)
2. Effect 2: Apply 2 stacks of Taunt to Self

Effects are edited inline in the addon using the same effect row widget used by the action effect editor.

---

## Tab 4: Visuals

Animation and personality resources for the companion.

### Animation Set
**Field:** Browse / Clear / Inspect
**Maps to:** `animation_set`

A `CombatAnimationSet` resource defining the cast → travel → impact animation sequence when the companion fires its action. If left empty, the system falls back to a simple slot flash.

### Idle Animation
**Field:** Browse / Clear / Inspect
**Maps to:** `idle_animation`

A `SpriteFrames` resource for the companion's idle animation in the combat portrait slot. Optional — if empty, a static portrait is used.

### Summon Enter Preset
**Field:** Browse / Clear / Inspect
**Maps to:** `summon_enter_preset`

A `SummonPreset` defining the entry animation when the companion appears in combat. Primarily for summons — a burst of particles, a portal opening, etc.

### Entry Emanate Preset
**Field:** Browse / Clear / Inspect
**Maps to:** `entry_emanate_preset`

An `EmanatePreset` for a radiating particle effect on entry. Stacks with the summon enter preset for dramatic appearances.

### Bark Set
**Field:** Browse / Clear / Inspect
**Maps to:** `bark_set`

A `BarkSet` resource that defines the companion's personality through speech bubble reactions to game events. This is how companions feel alive — they comment on what's happening in combat.

A `BarkSet` contains:
- **speaker_id:** Which dialogue speaker this companion uses (for name color and voice blip)
- **reactions:** An array of `BarkReaction` entries, each mapping a game event to possible barks

Each `BarkReaction` has:
- **event_type:** Which event triggers this bark (Player Damaged, Enemy Killed, Combat Start, etc.)
- **fire_chance:** Probability of speaking (0.0–1.0). Keep low (0.2–0.4) to avoid chatter spam.
- **cooldown:** Minimum seconds between this reaction firing.
- **barks:** Array of `BarkEntry` options (one is picked randomly):
  - **text:** What they say (supports BBCode)
  - **duration:** How long the bubble stays (seconds, default 2.0)
  - **priority:** Higher priority barks replace lower ones on the same character

BarkSets are created as separate `.tres` resources and browsed into the companion. Multiple companions can share a BarkSet, or each can have a unique one.

---

## Tab 5: Summon

Settings specific to summoned companions.

### Duration Turns
**Field:** Spin box (disabled for NPC type)
**Maps to:** `duration_turns`

How many combat rounds the summon lasts. After this many rounds, the summon is automatically removed (no death trigger — it just expires).

- **0:** Lasts the entire combat (until killed or combat ends).
- **3:** Lasts 3 rounds. Good for temporary conjurations.
- **1:** One-round wonder. Fires once, then vanishes.

This field is only editable when Companion Type is set to **Summon**. NPC companions persist across combats and don't expire.

---

## Synergies: How They Work

The companion synergy system provides bonuses when specific combinations of companions are active together. Synergies are defined as separate `CompanionSynergyDefinition` resources, NOT inside individual companions. The companion's role is just to carry **synergy tags** that the definitions match against.

### The Two Sides

1. **On the companion** (what you set in the builder): `synergy_tags` — a list of category tags like `frost`, `healer`, `undead`.
2. **In a synergy definition** (a separate `.tres` resource): The rules for when a synergy activates and what bonuses it grants.

### Creating Synergy Definitions

Synergy definitions are saved to `res://resources/companions/synergies/`. Create a new `CompanionSynergyDefinition` resource in the Godot Inspector.

#### Synergy Definition Fields

| Field | Type | Purpose |
|-------|------|---------|
| **synergy_id** | StringName | Unique identifier (e.g., `&"frost_duo"`) |
| **synergy_name** | String | Display name (e.g., "Frost Bond") |
| **description** | String | Shown in companion info popup |
| **match_mode** | Enum | TAGS or EXPLICIT |
| **required_tags** | Array[StringName] | For TAGS mode: tags a companion must have |
| **required_count** | int | For TAGS mode: how many tagged companions needed |
| **required_companion_ids** | Array[StringName] | For EXPLICIT mode: specific companion IDs |
| **min_relationship** | int | Minimum relationship value to activate (-1 = no requirement) |
| **granted_affixes** | Array[Affix] | Stat bonuses applied to the player |
| **granted_dice_affixes** | Array[DiceAffix] | Dice bonuses applied to all dice |
| **bonus_trigger** | CompanionTrigger | When the bonus action fires |
| **bonus_action_effects** | Array[ActionEffect] | Bonus effects (empty = no bonus action) |
| **bonus_condition** | AffixCondition | Optional gate for the bonus action |
| **bonus_cooldown_turns** | int | Cooldown between bonus fires (0 = every trigger) |
| **bonus_animation_set** | CombatAnimationSet | Animation for the bonus (null = instant) |

### Match Mode: TAGS

The most flexible approach. Instead of naming specific companions, you define a category and require N companions with that category to be active.

**Example — "Frost Bond":**
- `match_mode = TAGS`
- `required_tags = [&"frost"]`
- `required_count = 2`
- Activates when 2+ active companions both have the `frost` tag.

**Example — "Undead Healer Synergy":**
- `match_mode = TAGS`
- `required_tags = [&"undead", &"healer"]`
- `required_count = 2`
- Activates when 2+ active companions each have BOTH the `undead` AND `healer` tags.

**How it works internally:** The system scans all active companions. For each one, it checks if that companion has ALL of the `required_tags`. It counts how many companions pass. If the count is ≥ `required_count`, the synergy activates.

This means:
- A companion tagged `frost, healer` satisfies both a "frost" synergy and a "healer" synergy independently.
- A synergy requiring `[frost, healer]` with `required_count = 2` needs TWO companions that each have BOTH tags.

### Match Mode: EXPLICIT

For named-pair synergies between specific characters.

**Example — "Manne & Sigrid":**
- `match_mode = EXPLICIT`
- `required_companion_ids = [&"manne", &"sigrid"]`
- Activates only when both Manne and Sigrid are in the active party.

ALL listed companion_ids must be present. This is for story-driven, character-specific bonuses.

### Relationship Gating

The `min_relationship` field adds a relationship requirement:
- **-1** (default): No relationship check. The synergy works regardless of how much the companions like the player.
- **20:** Requires at least Friendly tier (relationship value ≥ 20).
- **50:** Requires Allied tier or higher.
- **80:** Requires Devoted tier.

When set, the system checks if the player has the required relationship value with ALL companions involved in the synergy. A newly recruited companion with low relationship won't trigger high-tier synergies even if the tags match.

### Synergy Bonuses

Synergies can grant two kinds of bonuses:

**granted_affixes** — Standard `Affix` resources applied to the player's affix pool. These are the same affixes used on equipment. Examples:
- +10% damage
- +5 armor
- Heal 2 HP per turn

**granted_dice_affixes** — `DiceAffix` resources applied to all the player's dice. Examples:
- +1 to all roll values
- Element conversion
- On-roll triggers

Bonuses are automatically applied when the synergy activates and removed when it deactivates (companion removed from party, dies, etc.). They use source tags (`"synergy:frost_bond"`) so they're cleanly tracked and removed.

### Bonus Actions

Beyond passive stat bonuses, synergies can define **bonus combat actions** — additional effect chains that fire automatically during combat. These act like an extra companion action triggered by combat events, representing a team combo that only happens when the right companions fight together.

Bonus action fields are in the **Bonus Actions** group on the synergy definition:

| Field | Type | Purpose |
|-------|------|---------|
| **bonus_trigger** | CompanionTrigger | When the bonus fires (same trigger types as companions) |
| **bonus_action_effects** | Array[ActionEffect] | The effect chain to execute (same system as companion/enemy actions) |
| **bonus_condition** | AffixCondition | Optional condition gate |
| **bonus_cooldown_turns** | int | Turns between fires (0 = every trigger) |
| **bonus_animation_set** | CombatAnimationSet | Animation to play (null = instant, no visual) |

Leave `bonus_action_effects` empty for passive-only synergies. The bonus action fields are ignored when the effects array is empty.

**Each effect handles its own targeting.** There is no synergy-level target rule — instead, each ActionEffect in the chain uses its own `target` field. This means a single synergy bonus can do multiple things to different targets:

- Effect 1: Damage → All Enemies
- Effect 2: Heal → Lowest HP Ally
- Effect 3: Add Status → Self (the source companion)

**Example — "Frost Bond" with bonus action:**
- `bonus_trigger = PLAYER_TURN_START`
- `bonus_action_effects = [Damage 8 (target: All Enemies), Shield 5 (target: Self)]`
- `bonus_cooldown_turns = 1`
- When active: every other player turn, a frost wave hits all enemies for 8 and shields the source companion for 5.

**Example — "Manne & Sigrid" explicit pair:**
- `bonus_trigger = PLAYER_DAMAGED`
- `bonus_action_effects = [Shield 15 (target: Damaged Ally)]`
- `bonus_cooldown_turns = 2`
- When the player takes damage with both active, the damaged ally gets a 15-point shield (every 3rd trigger).

**How it works in combat:**
1. A trigger fires (e.g., Player Turn Start).
2. Normal companion actions fire first, in slot order.
3. Then active synergy bonus actions fire for any synergies whose `bonus_trigger` matches.
4. Each effect in the bonus resolves its own targets independently.
5. The "source" for all effects is the first alive synergy member (used for Self targeting, HP scaling, animation origin).
6. Results go through the same pipeline as companion results — damage numbers appear, statuses apply, etc.

**Cooldown:** Works the same as companion cooldowns. After firing, the bonus skips N turns before it can fire again. Cooldowns tick once per combat round and reset when the synergy deactivates.

### Designing Good Synergy Tags

Think of tags as overlapping circles in a Venn diagram. A companion can belong to multiple categories:

```
Frost Healer Spirit:    synergy_tags = frost, healer, spirit
Frost Warrior Undead:   synergy_tags = frost, warrior, undead
Fire Healer Beast:      synergy_tags = fire, healer, beast
Shadow Warrior Spirit:  synergy_tags = shadow, warrior, spirit
```

With these tags, you can create synergies for:
- **"Frost Bond"** (2× frost) — Frost Healer + Frost Warrior
- **"Brotherhood of Arms"** (2× warrior) — Frost Warrior + Shadow Warrior
- **"Spirit Link"** (2× spirit) — Frost Healer + Shadow Warrior
- **"Frost Healer + Shadow Warrior"** (explicit pair) — Named character synergy

This gives designers a combinatorial design space. Adding one new tagged companion can unlock synergies with multiple existing companions.

### Where Synergies Appear

Active synergies are displayed in the **companion info popup** — when viewing a companion that participates in a synergy, you'll see the synergy name and description listed. Active synergies show in full color; inactive ones that could be possible show dimmed.

Synergies recalculate automatically when:
- The player activates, deactivates, or swaps companions in party management
- Combat starts (CompanionManager.initialize)
- Combat ends (CompanionManager.on_combat_end)

---

## Relationships

Each companion with a `companion_id` has a relationship value tracked by the game. This is the system that makes companions feel like they grow closer to the player over time.

### How Relationships Work

- **Range:** -100 (hostile) to +100 (devoted)
- **Starting value:** 0 (neutral) by default
- **Combat XP:** Active, standing companions earn **+2 relationship points** per dungeon fight won (`dungeon_fight_relationship` in the bond rules).
- A notice shows when a recruited companion's relationship changes, and when they reach a new companion tier (see "Abilities, the bond die and falling" below).

### Relationship Tiers

| Tier | Value Range | Color in UI |
|------|------------|-------------|
| **Hostile** | -100 to -50 | Red |
| **Unfriendly** | -49 to -20 | Orange |
| **Neutral** | -19 to +19 | Gray |
| **Friendly** | +20 to +49 | Green |
| **Allied** | +50 to +79 | Cyan |
| **Devoted** | +80 to +100 | Gold |

The current relationship tier and value are displayed in the companion info popup as colored text (e.g., "[cyan]Allied[/cyan] (62/100)").

### Design Implications

- Companions the player uses frequently will naturally reach higher tiers.
- Relationship tiers can gate synergy activation via `min_relationship`.
- Relationship tiers effectively replace companion "levels" — they ARE the progression system for companions.
- A companion that's never taken into combat will stay at Neutral forever.

---

## Abilities, the bond die and falling (engine 2026-09-26)

The approved Companion System (PLOT `Companions/Companion System.md`) added fields the builder has no UI for yet. Edit them in the **Inspector**; the builder keeps them when it saves.

### Three abilities
- **Signature:** the fields above (Trigger, Target, Effects, Cooldown...). Always available.
- **Reaction** (`reaction`, a `CompanionAbility`): a second trigger. Unlocks at **Trusted**.
- **Bond ability** (`bond_ability`, a `CompanionAbility`): unlocks at **Devoted**; once per fight unless its `uses_per_combat` says otherwise.

A `CompanionAbility` has its own trigger, trigger_data, action_effects, dice_effects, target_rule, condition, cooldown, uses, fires_on_first_turn, `min_tier` (-1 = the slot's default) and animation_set. Summons have no relationship, so all their abilities are open.

### Relationship tiers and the bond die
Companion tiers come from `res://resources/companions/companion_bond_rules.tres`:

| Tier | Relationship | Bond die |
|---|---|---|
| Acquaintance | 0+ | d4 |
| Trusted | 20+ | d6 |
| Close | 50+ | d8 |
| Devoted | 80+ | d10 |
| Personal quest upgrade | (bond_upgraded) | d12 |

Every time an ability fires it rolls the bond die and adds the player's primary-stat bonus (+1 per 20, the same rule as the player's dice). That value is the effects' die: DAMAGE with `dice_count` 1+, HEAL with `heal_uses_dice`, SHIELD with `shield_uses_dice` use it. Turn off `uses_bond_die` to opt out; set `fixed_die_sides` to roll a fixed die (summons roll nothing unless this is set).

### The shared pipeline
Companion damage goes through the same pipeline as everyone's: armour/barrier by element, the target's dodge, Braced, block and overhealth, Expose crits, Empowered/Enfeeble on the companion, and threat. **SHIELD** gives the target Overhealth. Companions carry a StatusTracker: statuses, DoTs and buffs on them tick with the player's turn.

### Dice-shaper effects
`dice_effects` (on the Signature or any ability) work on the player's rolled hand, only while it's live (best with **Hand Rolled**): **Raise** (+amount, 0 = the bond roll; lowest/highest/random; capped at the die's top face), **Reroll Minimum** (the 1s), **Set Max**, **Add Die** (a temporary die, gone at the next roll; 0 sides = the bond die's size).

### Downed, Wounded, temperament
- At 0 HP a companion is **downed**, not dead: out for the fight (still in its slot), no synergies, no barks. Rests, a revive consumable (`revive_companions`), a Mender (HEAL on **Downed Companion**) or the shellkeeper rescue bring them back.
- Revived mid-fight = **Wounded**: max HP x0.75 until the next proper (map) rest.
- `temperament` (Proud, Steadfast, Loyal, Wary, Bonded + `bonded_to`) changes relationship on falls and revives; numbers in the bond rules file, per-companion `temperament_overrides`.

### Trail perk
`trail_perk` + `trail_perk_value` (+ `trail_perk_min_tier`): **Gold Find** (+x fight gold), **Rest Healing** (+x companion rest healing). Only active, standing companions count.

### Recruiting from story
- Dialogue action 10 `RECRUIT_COMPANION`: `game_action:10:res://resources/companions/x.tres` (or a companion_id). Add `:camp` to skip the party.
- Dialogue action 11 `DISMISS_COMPANION`: `game_action:11:<companion_id>` (`:force` for a permanent one).
- GameEventEffect `RECRUIT_COMPANION` / `DISMISS_COMPANION` / `UPGRADE_COMPANION_BOND`; QuestRewards `recruit_companions` / `dismiss_companions` / `upgrade_companion_bonds`.
- Conditions (CUSTOM): `companion_recruited:<id>`, `companion_in_party:<id>`, `companion_downed:<id>`, `companion_tier:<id>:>=:2`.

---

## Workflow: Building a Companion From Scratch

Here's a step-by-step walkthrough for creating a new companion.

### 1. Concept
Decide on the companion's role. A reactive healer? An aggressive counter-attacker? A tanky bodyguard? A temporary summon with a big entry effect?

### 2. Identity Tab
1. Give it a **Name** and click **Auto** to generate the **ID**.
2. Write a **Description** for the info popup.
3. Name the **Action** and describe what it does narratively.
4. Pick a **Portrait** image.
5. Set **Type** (NPC or Summon).
6. Add **Synergy Tags** — think about what categories this companion belongs to.

### 3. Combat Tab
1. Set **HP** — pick a scaling mode and tune the numbers. Use the preview widget.
2. Choose a **Trigger** — when should this companion act?
3. Choose a **Target** — who should the action affect?
4. Optionally set a **Condition** — any special requirements to fire?
5. Set **Cooldown** and **Uses** if the ability shouldn't fire every single trigger.
6. Decide on **Taunt** if this is a tank.

### 4. Effects Tab
1. Click **Add Effect** and configure the actual gameplay effect.
2. Add multiple effects for compound actions (damage + apply status, heal + shield, etc.).

### 5. Visuals Tab
1. Browse for an **Animation Set** (or leave empty for default).
2. Optionally set **Summon Enter** / **Emanate** presets for flashy entrances.
3. Create and assign a **Bark Set** for personality.

### 6. Summon Tab (if Type = Summon)
1. Set **Duration** — how many turns before it vanishes.

### 7. Save
Click **Validate** to check for issues, then **Save**.

---

## Design Tips

**Trigger + Target combos define the archetype:**
- Healer: `Player Turn End` + `Lowest HP Ally`
- Counter-attacker: `Player Damaged` + `Triggering Source`
- Guardian: `Player Turn Start` + `Player` (applies shield)
- Avenger: `Companion Killed` + `All Enemies`
- Death rattle: `On Death` + `All Enemies`

**Cooldowns prevent spam but create rhythm:**
- A 2-cooldown healer fires every 3rd round. The player has to survive the gap.
- A 0-cooldown buff on `Round Start` provides a reliable passive aura.

**Uses create scarcity:**
- A companion with 1 use and the `On Death` trigger is a one-time insurance policy.
- A companion with 3 uses and `Player Damaged` gives the player three "free" reactive heals.

**Synergy tags create team-building incentives:**
- Give overlapping tags to encourage meaningful party composition choices.
- Don't over-tag — 2-3 tags per companion is the sweet spot.
- Tag names should be intuitive enough that players can guess synergies from companion descriptions.

**Relationship gating on synergies creates progression:**
- Early synergies: `min_relationship = -1` (no gate) — reward just having the right team.
- Mid-game synergies: `min_relationship = 20` (Friendly) — reward investing time with companions.
- Late-game synergies: `min_relationship = 50` (Allied) — reward long-term loyalty to specific companions.
