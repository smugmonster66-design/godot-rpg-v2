# Enemy AI System — Designer's Manual

## What This System Does

The enemy AI decides two things every turn: **which action to use** and **which dice to put in it**. Before this system, every enemy just picked the highest-damage action and stuffed in the biggest dice. Now, enemies can care about elements, heal themselves when hurt, avoid wasting status effects, coordinate with allies, and shift strategies mid-fight.

Everything is configured through the Godot Inspector — no scripting required. You drag resources, flip dropdowns, and slide sliders.

---

## The Building Blocks

There are three new resource types you'll work with:

| Resource | What it does | Where it goes |
|----------|-------------|---------------|
| **EnemyAIConfig** | Personality sliders (how smart, how cautious) | Drag into EnemyData → AI Settings → Ai Config |
| **ActionAIHint** | "Use this action when X happens" rules | Add to Action → AI Hints array |
| **AIEscalationRule** | "Switch strategy when X happens" triggers | Add to EnemyData → AI Settings → Strategy Escalation |

Plus two checkboxes on EnemyData:
- **Team Aware** — Should this enemy pay attention to what its allies are doing?
- **AI Strategy** — The base personality (Aggressive / Defensive / Balanced / Random), same as before.

---

## EnemyAIConfig — The Personality Panel

Create one: right-click in FileSystem → New Resource → EnemyAIConfig → save as `.tres`.

### Sliders

**Element Preference** (0.0 – 1.0)
- At 0: The enemy ignores dice elements entirely. A fire skeleton will happily stuff ice dice into its Fireball.
- At 0.5 (default): Mild preference for matching dice. It'll use fire dice for fire actions when available, but won't go out of its way.
- At 1.0: Strong preference. The enemy will always pick matching-element dice first, and its scoring heavily favours actions that match its dice.

**Heal Urgency** (0.0 – 1.0)
- At 0: The enemy never boosts heal/defend actions when damaged. A berserker that fights to the death.
- At 0.5: Moderate. Starts caring about heals when HP drops below the heal threshold.
- At 1.0: Very cautious. Large score bonus for heals/defends even at moderate damage.

**Heal Threshold** (0.1 – 0.8)
- The HP% where the enemy starts thinking about healing. At 0.5, the enemy starts considering heals when below 50% HP.

**Critical Threshold** (0.05 – 0.5)
- The HP% where heal urgency goes to maximum. At 0.3, an enemy below 30% HP gets the strongest heal bonus.

**Status Awareness** (0.0 – 1.0)
- At 0: The enemy will happily re-apply Poison to a target that's already Poisoned.
- At 1.0: Strong penalty for re-applying statuses. The enemy switches to a different action instead.

**Coordination Preference** (0.0 – 1.0)
- Only matters when Team Aware is checked on the EnemyData.
- At 0: Ignores what allies have done.
- At 1.0: Strong bonus for follow-up attacks that combo with ally-applied statuses. If an ally applied Burn, this enemy's fire attacks get a big score boost.

### Tips
- You can share one EnemyAIConfig across multiple enemies. A "cautious_healer" config works for any enemy with heal actions.
- Leaving Ai Config as null (empty) on an EnemyData gives you default behaviour (all sliders at 0.5).

---

## ActionAIHint — Teaching Actions When to Shine

These go directly on Action resources. Open any Action `.tres`, find the **AI Hints** group, and add elements to the array.

Each hint has three parts: a **Condition**, an **Effect**, and optional **Invert**.

### Conditions (the "when" dropdown)

| Condition | What it checks | Shows threshold? | Shows status_id? |
|-----------|---------------|-------------------|-------------------|
| None | Always active | No | No |
| Self HP Below | Enemy's own HP% < threshold | Yes | No |
| Self HP Above | Enemy's own HP% >= threshold | Yes | No |
| Target HP Below | Player's HP% < threshold | Yes | No |
| Target HP Above | Player's HP% >= threshold | Yes | No |
| Target Has Status | Player has a specific status | No | Yes |
| Target Missing Status | Player doesn't have a status | No | Yes |
| Self Has Status | Enemy has a specific status | No | Yes |
| Self Missing Status | Enemy doesn't have a status | No | Yes |
| Ally Count Above | Alive allied enemies >= threshold | Yes | No |
| Ally Count Below | Alive allied enemies < threshold | Yes | No |
| Turn Number Above | Current turn >= threshold | Yes | No |

The inspector automatically hides fields you don't need. Pick "Target Has Status" and the threshold field disappears, replaced by a status_id text field.

### Effects (the "what happens" dropdown)

| Effect | What it does | Uses which field? |
|--------|-------------|-------------------|
| Score Bonus | Adds a flat number to the action's score | bonus_value (default 30) |
| Score Multiplier | Multiplies the action's score | multiplier_value (default 1.5) |
| Force Action | Score becomes 9999 — the AI always picks this | Neither |

### Invert checkbox
Flips the condition. "Self HP Below 0.3 + Invert" means "Self HP is NOT below 0.3" (i.e., above 30%).

### Example: Heal action that activates when hurt
- Condition: **Self HP Below**
- Threshold: **0.5**
- Effect: **Score Bonus**
- Bonus Value: **50**

Result: When the enemy drops below 50% HP, this heal action gets +50 to its score, making it very likely to be chosen over attacks.

### Example: Finisher move for low-HP targets
- Condition: **Target HP Below**
- Threshold: **0.25**
- Effect: **Force Action**

Result: When the player is below 25% HP, the enemy always uses this finishing move.

### Example: Opening gambit (turn 1 only)
- Condition: **Turn Number Above**
- Threshold: **2**
- Effect: **Score Multiplier**
- Multiplier: **0.1**
- Invert: **checked**

Result: On turn 1 (turn is NOT above 2), the score is multiplied by 0.1 — wait, that's backwards. Let's flip it:

- Condition: **Turn Number Above**
- Threshold: **2**
- Effect: **Score Bonus**
- Bonus: **-100**

This penalises the action after turn 1. For the opposite (boost on turn 1), use a second hint with Invert.

Simpler approach: just use **Force Action** with Turn Number Above = 1 (not inverted) — forces it on turn 1.

---

## AIEscalationRule — Mid-Fight Strategy Shifts

These go on EnemyData under **AI Settings → Strategy Escalation**. Add elements to the array.

Each rule has a **Trigger**, a **Threshold**, and a **New Strategy**.

### Triggers

| Trigger | What it checks | Uses threshold? |
|---------|---------------|-----------------|
| Self HP Below | Own HP% < threshold | Yes |
| Self HP Above | Own HP% >= threshold | Yes |
| Ally Died | Any allied enemy has died | No (hidden) |
| All Allies Dead | This enemy is the last one standing | No (hidden) |
| Turn Number Above | Current turn >= threshold | Yes |

### How it works
Every turn, before the AI makes its decision, escalation rules are checked top-to-bottom. **First match wins.** The matching rule's New Strategy overrides the base AI Strategy for that turn only.

### Example: Enrage at low HP
- Trigger: **Self HP Below**
- Threshold: **0.3**
- New Strategy: **Aggressive**

A Balanced enemy becomes Aggressive when below 30% HP. It stops considering heals and goes all-in on damage.

### Example: Last stand
- Trigger: **All Allies Dead**
- New Strategy: **Aggressive**

When all allies are dead, the enemy goes berserk.

### Example: Slow ramp-up
Add two rules in this order:
1. Trigger: **Turn Number Above**, Threshold: **6**, New Strategy: **Aggressive**
2. Trigger: **Turn Number Above**, Threshold: **3**, New Strategy: **Balanced**

Base strategy: Defensive. Turns 1–2: Defensive. Turns 3–5: Balanced. Turn 6+: Aggressive.

**Important:** Put more specific rules first — first match wins!

---

## Team Aware — Multi-Enemy Coordination

The **Team Aware** checkbox on EnemyData enables coordination. When checked, the enemy can see what statuses its allies have applied to the player and factor that into its decisions.

### What it does automatically
- If an ally applied **Burn** and this enemy has a fire damage action, that action gets a synergy score bonus.
- If the player has any debuffs and this enemy has **Combo Mark** or **Execute** effects, those get boosted.
- The synergy strength is controlled by **Coordination Preference** in the EnemyAIConfig.

### When to use it
- **Trash mobs:** Leave unchecked. They fight independently.
- **Elite packs:** Check it on all enemies in the encounter. They'll naturally combo off each other.
- **Boss + adds:** Check it on the boss. Leave the adds unchecked (or check them too for a harder fight).

---

## Putting It All Together — Recipes

### Recipe 1: Trash Mob (Goblin Grunt)

**EnemyData settings:**
- AI Strategy: **Random**
- Ai Config: **null** (empty)
- Team Aware: **unchecked**
- Escalation Rules: **empty**

**Actions:** One basic attack, no AI Hints.

**Result:** Picks randomly. Dumb as a rock. Perfect for easy encounters.

### Recipe 2: Basic Enemy (Skeleton Warrior)

**EnemyData settings:**
- AI Strategy: **Aggressive**
- Ai Config: **null** (use defaults)
- Team Aware: **unchecked**
- Escalation Rules: **empty**

**Actions:** Slash (attack), Shield Bash (defend). No AI Hints needed — the Aggressive strategy already prefers attacks.

**Result:** Always goes for damage. Uses the highest-value dice. Occasionally shields if the score happens to be close. Simple but predictable.

### Recipe 3: Smart Healer (Cultist Priest)

**EnemyAIConfig** (`cautious_healer.tres`):
- Element Preference: **0.3** (mild)
- Heal Urgency: **0.9** (very cautious)
- Heal Threshold: **0.6** (starts healing early)
- Critical Threshold: **0.4**
- Status Awareness: **0.7**

**EnemyData settings:**
- AI Strategy: **Defensive**
- Ai Config: → drag `cautious_healer.tres`
- Team Aware: **unchecked**

**Actions:**
- Shadow Bolt (attack) — no hints
- Dark Heal (heal) — AI Hint: Self HP Below 0.6 → Score Bonus 40
- Curse (ADD_STATUS: poison) — AI Hint: Target Has Status "poison" → Score Bonus -60 (penalty to avoid wasting it)

**Result:** Prefers defending. When hurt, strongly favours healing. Won't re-apply Curse if the player is already poisoned.

### Recipe 4: Elemental Duo (Fire Mage + Ice Mage)

**Shared EnemyAIConfig** (`elemental_smart.tres`):
- Element Preference: **1.0** (always match elements)
- Status Awareness: **0.8**
- Coordination Preference: **0.8**

**Both EnemyData:**
- AI Strategy: **Balanced**
- Ai Config: → drag `elemental_smart.tres`
- Team Aware: **checked**

**Fire Mage Actions:**
- Fireball (fire damage) — uses fire dice
- Ignite (ADD_STATUS: burn)

**Ice Mage Actions:**
- Ice Lance (ice damage) — uses ice dice
- Frost Nova (ADD_STATUS: freeze)

**Result:** Each mage uses matching-element dice for their spells. If the Fire Mage applies Burn, the Ice Mage doesn't benefit (wrong element) — but if you pair two Fire enemies, the second one gets a synergy bonus for fire attacks against a Burning target.

### Recipe 5: Elite Pack Leader (Bandit Captain)

**EnemyAIConfig** (`tactical_leader.tres`):
- Element Preference: **0.5**
- Heal Urgency: **0.6**
- Heal Threshold: **0.4**
- Status Awareness: **0.9**
- Coordination Preference: **1.0**

**EnemyData:**
- AI Strategy: **Balanced**
- Team Aware: **checked**
- Escalation Rules:
  1. All Allies Dead → **Aggressive**
  2. Self HP Below 0.3 → **Aggressive**

**Actions:**
- Slash (attack)
- Rally (heal, targets self) — AI Hint: Self HP Below 0.4 → Force Action
- War Cry (ADD_STATUS: "vulnerability" on player) — AI Hint: Target Has Status "vulnerability" → Score Bonus -80

**Result:** Fights tactically with allies, using War Cry to set up combos. Won't re-apply vulnerability. Force-heals when critically hurt. When all allies die or HP drops below 30%, goes berserk.

### Recipe 6: World Boss (The Kraken)

This is where the system shines. Multi-phase boss with complex behaviour.

**EnemyAIConfig** (`kraken_intelligence.tres`):
- Element Preference: **0.8**
- Heal Urgency: **0.4** (not too cautious — it's a boss)
- Heal Threshold: **0.3**
- Critical Threshold: **0.15**
- Status Awareness: **1.0** (never wastes statuses)
- Coordination Preference: **0.0** (solo boss)

**EnemyData:**
- AI Strategy: **Balanced**
- Team Aware: **unchecked** (solo boss, no allies)
- Escalation Rules (ordered, first match wins):
  1. Self HP Below **0.25** → **Aggressive** (Phase 3: Frenzy)
  2. Self HP Below **0.50** → **Defensive** (Phase 2: Submerge)
  3. Turn Number Above **8** → **Aggressive** (Enrage timer)

**Actions (6+ actions for variety):**

*Phase 1 actions (100–50% HP):*
- **Tentacle Slam** (high damage, 2 dice) — No hints (always good)
- **Ink Cloud** (ADD_STATUS: "blind") — AI Hint: Target Has Status "blind" → Score Bonus -100
- **Tidal Wave** (AoE, 3 dice) — AI Hint: Turn Number Above 3 → Score Bonus 20 (saved for later)

*Phase 2 actions (50–25% HP — Defensive strategy active via escalation):*
- **Regenerate** (heal) — AI Hint: Self HP Below 0.4 → Score Multiplier 2.0
- **Whirlpool** (ADD_STATUS: "slow" + damage) — AI Hint: Self HP Below 0.5 → Score Bonus 30

*Phase 3 actions (below 25% — Aggressive strategy active):*
- **Kraken's Fury** (massive damage, 4 dice) — AI Hint: Self HP Below 0.25 → Force Action

**How the fight plays out:**
1. **Turns 1–2 (Balanced):** The Kraken mixes Tentacle Slam and Ink Cloud. Doesn't use Tidal Wave yet.
2. **Turn 3+ (still Balanced):** Tidal Wave becomes available (hint kicks in). Rotates between all phase 1 actions. Won't re-apply Blind.
3. **HP drops below 50% (Defensive):** Escalation rule fires. Now prefers Regenerate and Whirlpool. Still uses Tentacle Slam but at lower priority.
4. **HP drops below 25% (Aggressive):** Second escalation rule fires. Kraken's Fury is Force Action'd — the boss uses its ultimate every turn. Regenerate drops off because Aggressive strategy penalises heals.
5. **Turn 8+ (if not already Aggressive):** Enrage timer kicks in as a safety net. If the fight drags, the boss goes Aggressive regardless of HP.

**Key design insight:** The escalation rules create "phases" without any phase system. The rules are checked top-to-bottom, and the most specific ones (lowest HP thresholds) are listed first so they take priority. The actions themselves use AI Hints to become more or less relevant depending on the enemy's state, creating emergent phase transitions.

---

## Quick Reference — What Goes Where

```
EnemyData (.tres)
├── AI Settings
│   ├── AI Strategy        ← Base personality (dropdown)
│   ├── Ai Config          ← Drag an EnemyAIConfig .tres here
│   ├── Coordination
│   │   └── Team Aware     ← Checkbox
│   └── Strategy Escalation
│       └── Rules[]        ← Array of AIEscalationRule
│
├── Combat Actions
│   └── Action (.tres)
│       └── AI Hints[]     ← Array of ActionAIHint
```

## Defaults When Nothing Is Set

If you don't touch any of this, enemies behave exactly as before:
- No EnemyAIConfig → all sliders default to 0.5
- No AI Hints → actions scored purely by damage + strategy
- No Escalation Rules → strategy never changes
- Team Aware unchecked → no coordination

The system is fully opt-in. Existing enemies won't change behaviour unless you add configs to them.
