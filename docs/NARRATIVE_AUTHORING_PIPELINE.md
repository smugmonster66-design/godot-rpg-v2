# Narrative Authoring Pipeline

How story gets from the Obsidian vault into the game.

- **Part 0** — the two-repo model and the bridge between them
- **Part 1** — what the engine can actually express (the vocabulary you write for)
- **Part 2** — what you write (built on the vault formats you already use)
- **Part 3** — the compile mapping: every piece of vault syntax → the engine construct it becomes
- **Part 4** — the session loop
- **Part 5** — known gaps and drift

Vault root: `D:\RTB WB\Obsidian Vault for World Building\Roll The Bones World-Building`
Game root: `D:\Games\dice-rpg-game-2026-new`

---

# Part 0 — The two-repo model

**The vault is canon. The game is a build artifact.**

You write fiction in the vault, in the formats you already have (`Quest Template`,
`dialogue-creator` encounter format, character/location/faction notes). Nothing
about the engine should leak into how you write a scene.

I compile vault notes into Godot `.tres` resources. When fiction and game data
disagree, **the vault wins** and I change the game files — unless the game data
represents playtested balance, in which case I flag the conflict instead of
silently overwriting.

## The bridge: `game_id`

Every vault template already has a `game_id` frontmatter field. It's mostly
empty. That field is the pipeline's single source of truth for "has this shipped".

```yaml
game_id: npc_cate          # built, and this is its id in the game
game_id: ""                # fiction only, not in the game yet
```

Rules:

1. **I fill in `game_id`** when I build something, never you.
2. `game_id` is the exact `quest_id` / `npc_id` / `location_id` / `encounter_id`
   in the Godot resource, and the `.tres` filename matches it.
3. If a note has a `game_id`, changing that note means the game files are now
   stale. Say "rebuild X" and I'll re-sync.
4. `status: stub → draft → built` — I bump it to `built` and stamp `updated`.

This makes "what's in the game vs. what's only written" a vault query, not a
memory exercise.

## Where the seam sits

| Lives in the vault | Lives in the game repo |
|---|---|
| Who a character is, how they talk, what they know | `NPCDefinition`, `DialogueSpeaker`, bust art |
| What a quest is *about*, its branches and stakes | `QuestDefinition`, objectives, rewards, conditions |
| Encounter scripts, choice consequences | `DialogueEncounter` graphs |
| Faction identity, ranks, how they fight | `EnemyData`, `Action`, `CombatEncounter` |
| Places, their character, what's there | `LocationNode`, `MapDefinition` |
| Balance numbers (XP, gold, HP, damage) | game repo only — the vault says "generous", the repo says "250" |

---

# Part 1 — What the engine can express

## 1.1 The one big idea

**A story beat is a DialogueEncounter graph.** It's the only primitive that can
read state, branch on it, write state, and fire gameplay in one authored unit.

| Capability | Mechanism |
|---|---|
| Read any game state | `GameCondition` on a Condition node or a choice |
| Set flags | `set_flags` on a line or choice |
| Move counters (incl. virtue/order) | `counter_changes` on a choice |
| Move relationship (**player-visible**) | `relationship_changes` |
| Move approval (**hidden**) | `approval_changes` |
| Start a fight | Action node → `START_COMBAT` |
| Start a dungeon run | Action node → `ENTER_DUNGEON` |
| Give / turn in a quest | Action node → `ACCEPT_QUEST` / `COMPLETE_QUEST` |
| Tick a specific objective | Action node → `REPORT_OBJECTIVE` (`quest_id:objective_id`) |
| Open shop / smithing | Action node → `OPEN_SHOP` / `OPEN_SMITHING` |
| Fire an arbitrary event | Action node → `CUSTOM_EVENT` |

Combat and dungeon actions **suspend** the conversation and resume on the next
line, so "talk → fight → talk about the fight" is one authored scene
(`scripts/autoload/dialogue_manager.gd:204`).

## 1.2 How a character decides what to say

`NPCDefinition.dialogue_table` is a **priority-ordered condition table**.
`NPCManager` walks it highest-priority-first and plays the first entry whose
condition passes, skipping `one_shot` entries already seen. Ties at the top
priority give the player a sub-radial to choose between conversations.

So a character isn't one branching mega-scene — it's a **stack of gated
conversations**. This is the main structural decision per character, and it's
the thing the vault format doesn't currently capture (see Part 2, Build Block).

## 1.3 The state ledger

| Store | Type | Range | Visible | Declared where |
|---|---|---|---|---|
| Story flags | bool | — | no | **`@export var` in `resources/data/story_flags.gd` — needs a code edit** |
| Counters | int | any | no | freeform |
| `virtue` | int | −100…+100 | no | evil ↔ good |
| `order` | int | −100…+100 | no | chaotic ↔ orderly |
| Relationships | int | −100…+100 | **yes** | freeform per `npc_id` — Hostile→Devoted |
| Approvals | int | −100…+100 | **no** | freeform per `npc_id` |
| Quest state | enum | locked/available/active/ready/complete/failed | yes | per quest |
| Objective progress | int | — | yes | per objective |
| Visited locations | bool | — | yes | automatic |
| Items held | count | — | yes | matched on `item_name` |
| Player / class level | int | — | yes | automatic |

**Flag = a fact about the world** (`lighthouse_lit`). **Counter = a quantity or
a dial** (`smugglers_spared`, `virtue`).

Relationship vs approval is a live authoring lever, and the vault's
`[APPROVAL: ±1]` tag already uses it: relationship is the number the player
sees and games; approval is what the character privately thinks. Use approval
for reveals, betrayals, and NPCs who are hiding their real opinion.

## 1.4 Conditions

Anything in 1.3, combined with nested AND / OR / NOT, operators
`== != > < >= <=`. Plus two composite quest checks:

- `quest_objective:<quest_id>:<objective_id>` — complete?
- `quest_objective_progress:<quest_id>:<obj_id>:<op>:<n>` — partial progress

## 1.5 Quests are a tracker, not content

`QuestDefinition` holds identity, objectives, rewards, prerequisites, giver and
turn-in. The drama lives in the dialogue.

| Objective type | Reported by | Works today |
|---|---|---|
| `TALK_TO` | dialogue tag `quest:talk:<npc>` | yes |
| `KILL` | automatic on victory — matched on **enemy tag** or **enemy .tres filename** | yes |
| `COLLECT` | `quest:collect:<item>` tag | yes (manual) |
| `VISIT` | automatic on entering a location | yes |
| `INTERACT` | `quest:interact:<id>` tag | yes |
| `CUSTOM` | `quest:custom:<id>` tag | yes |
| `DELIVER` / `ESCORT` / `SURVIVE` | — | **no reporting path exists** |

Objectives support ordering, optional objectives, and hidden-until-previous.
Rewards grant XP, gold, items, flags, location unlocks, follow-up quests,
relationship deltas and counter deltas. `auto_complete` skips turn-in (bounties);
`repeatable` works.

**Tag-based kill tracking is why `enemy_tags` matter.** Write kill objectives
against factions (`naval`, `smuggler`) unless you mean one specific named foe.

## 1.6 The world layer

- **LocationNode** — reveal condition, unlock condition, locked hint, radial
  buttons, connections, first-visit flags/events, rest and safe-zone flags.
- **MapDefinition** — nodes, background, lighting, decor, curved paths. Maps nest.
- **MapNodeButtonDef** — Quests, NPCs, Enter Dungeon, Enter Zone, Rest, Party, Travel.

Gating a node behind a flag is how completing a quest physically expands the map.

## 1.7 The combat layer

```
CombatEncounter  ← what a fight IS (1–3 enemies, slots, difficulty, boss flags)
   └ EnemyData   ← a creature (stats, dice, actions, affixes, tags, tier)
        ├ EnemyTemplate ← role × archetype budget (brute_str, support_int, …)
        ├ Action        ← an ability = ordered ActionEffect slots
        │    └ ActionAIHint ← "use when HP<30%", "force at turn 5"
        ├ DieResource   ← its dice, each with element + dice affixes
        └ Affix[]       ← stats, rolled against player level
```

- **Roles**: BRUTE, SKIRMISHER, CASTER, TANK, SUPPORT
- **Tiers**: TRASH, ELITE, MINI_BOSS, BOSS, WORLD_BOSS
- **Effects**: DAMAGE, HEAL, ADD_STATUS, REMOVE_STATUS, CLEANSE, SHIELD,
  ARMOR_BUFF, DAMAGE_REDUCTION, REFLECT, LIFESTEAL, EXECUTE, COMBO_MARK, ECHO,
  SPLASH, CHAIN, RANDOM_STRIKES, MANA_MANIPULATE, MODIFY_COOLDOWN,
  REFUND_CHARGES, GRANT_TEMP_ACTION, CHANNEL, COUNTER_SETUP, SUMMON_COMPANION
- **Damage types**: SLASHING, BLUNT, PIERCING, FIRE, ICE, SHOCK, POISON, SHADOW.
  Per-enemy `element_modifiers` give immunity / resistance / weakness.
- **Values can scale off** dice total, dice count, source or target HP, status
  stacks, turn number, ally count — so "stronger the longer the fight runs" or
  "hits harder with allies alive" are authorable without code.
- **Barks** (`barks_on_use`) — enemies shout lines on action use. Free
  characterisation, and the cheapest way to give a faction a voice in combat.

House rule: **enemies never get Execute mechanics.** Use status-scaling payoffs
for the same "you're in danger" pressure.

## 1.8 Dungeon runs

`DungeonDefinition` = floor count plus pools: combat / elite / boss encounters,
`DungeonEvent` (choice vignettes with risk rolls), `DungeonShrine`, loot, shop,
and run affixes offered between floors. Use a dungeon when a place needs a
*texture* rather than authored rooms — a wreck, a siege, a flooded quarter.

`DungeonEvent` is the micro-fiction slot: a paragraph, 2–4 choices, each with a
success chance, reward, and fail text. It's the closest thing to your Random
Encounter notes that has no NPC attached.

---

# Part 2 — What you write

**Keep writing in the vault formats you already have.** The `dialogue-creator`
skill's encounter format, the `Quest Template`, and the character/location/faction
templates all survive unchanged. The pipeline adds exactly one thing.

## 2.1 The Build Block

Fiction notes don't carry the engine-specific facts I'd otherwise have to guess:
delivery conditions, priorities, exact numbers, which encounter to reuse. So
when a note is ready to build, append a fenced **Build Block** at the bottom.

It is deliberately small. Everything in it is a decision only you can make.

### On a quest note

````markdown
## Build

```yaml
quest_id: harbor_masters_request
type: side                 # main|side|companion|bounty|collection|exploration|hidden
giver: cate @ loc_embergate
turn_in: cate              # or AUTO
available_when: flag met_cate
objectives:
  - id: defeat_naval_enemies
    kill: tag naval x5
  - id: report_harbor_master
    talk: teague
    after: defeat_naval_enemies
rewards:
  xp: 250
  gold: 120
  relationship: { cate: +10 }
  flags: [manifests_read]
  unlocks: [loc_tide_chapel]
```
````

### On an encounter note

````markdown
## Build

```yaml
encounter_id: cate_asks_favor
npc: cate
plays_when: quest harbor_masters_request is available
priority: 10
one_shot: true
morality_scale: normal     # subtle|normal|strong  (see 3.3)
```
````

### On a character note

````markdown
## Build

```yaml
npc_id: teague
home: loc_veritas_port
speaker_id: teague
busts: [base, wary, angry]     # art I still owe you
conversations:                  # the priority stack — highest first
  - teague_first_meeting   | one-shot | always
  - teague_quest_turnin    | quest harbor_masters_request ready
  - teague_idle            | always
```
````

### On a faction / creature note

````markdown
## Build

```yaml
faction_id: navy
tags: [naval, humanoid]
region: 1
enemies:
  - name: Tide Chaplain
    tier: elite
    role: support
    archetype: int
    signature: chills the party while healing allies
    elements: { weak: fire, resist: ice }
```
````

## 2.2 What I need per beat type, and what I'll infer

| You give me | I infer without asking |
|---|---|
| the scene, in `dialogue-creator` format | bust slot assignments, auto-advance timing, node layout |
| `[+Good]` / `[+Orderly]` tags | the numeric virtue/order delta (see 3.3) |
| `[APPROVAL: ±1]` | the numeric approval delta |
| `[REQUIRES: x]` + `**Default:**` | the `GameCondition`, and whether to hide or grey out the choice |
| "a fight with dock guards" | which existing encounter fits, or that a new one is needed — **I'll propose, not build silently** |
| "generous reward" | nothing — I'll ask, or take the Build Block number |

## 2.3 One format gap to be aware of

The vault writes player lines two different ways, and they compile differently:

```
**BONES:** (agreeable / questioning / dry)
- *e.g. "Always the forms." / "How'd you know?" / "Is it that obvious?"*
```

This is a **tone triple** — three flavours of the *same* beat, not a branch. The
engine shows one label per choice bubble, so this becomes **one** choice.
Default rule: I use the **first** listed line as the label and note the other
two as unused flavour. Mark your preferred line with a leading `*` to override:

```
- *e.g. "Always the forms." / *"How'd you know?" / "Is it that obvious?"*
```

Versus:

```
> [!info] **CHOICE POINT — Brief descriptor**
> - **Choice A** — ... → [[#Choice A — …]]
```

This is a **real branch** and becomes a `DialogueChoice` array.

Long term the cleaner fix is for the engine to support a small pool of
equivalent player lines and pick one — say the word and I'll build it.

---

# Part 3 — The compile mapping

Everything below is mechanical. No judgement calls hidden in it.

## 3.1 Vault dialogue syntax → engine

| Vault | Engine |
|---|---|
| `**NAME:** text` | `DialogueLine` with `speaker_id`, text |
| `*(stage direction)*` | dropped, or → `mood` change if it describes expression |
| `**BONES:** (tones)` + e.g. lines | one `DialogueChoice`, label = first (or `*`-marked) line |
| `> [!info] CHOICE POINT` block | `DialogueChoice[]` on the preceding line |
| `[[#Choice A — Name]]` | `choice.next_line` → that section's first line |
| `[+Good]` / `[+Evil]` | `counter_changes = {virtue: ±N}` |
| `[+Orderly]` / `[+Chaotic]` | `counter_changes = {order: ±N}` |
| `[APPROVAL: +1]` | `approval_changes = {npc: +N}` |
| `[REQUIRES: cond]` | `choice.condition` = the `GameCondition` |
| `**Default:**` line | the unconditional sibling choice / fallback branch |
| Flow-diagram `✅ outcome` | sanity check that every branch terminates — not compiled |
| `## Setup`, `## Characters`, `## Notes` | not compiled; `## Characters` becomes the art brief |
| encounter frontmatter `prerequisite:` | the `NPCDialogueEntry.condition` |

## 3.2 Vault entity → engine resource

| Vault note | Godot output |
|---|---|
| `Characters/<X>.md` | `resources/npcs/region_N/npc_<id>.tres` + `resources/dialogues/speakers/ds_<id>.tres` |
| encounter note | `resources/dialogues/<npc>/<encounter_id>.tres` + an `NPCDialogueEntry` in the NPC's table |
| `Quests/<X>.md` | `resources/definitions/quests/<quest_id>.tres` — **flat, no subfolders** |
| `Locations/<X>.md` | `resources/maps/<region>/loc_<id>.tres` + button defs, wired into the `MapDefinition` |
| `Factions/<X>.md` | `resources/enemies/region1/<faction>/<tier>/*.tres`, `resources/actions/<faction>/*.tres`, `resources/encounters/region1/<faction>/<tier>/*.tres` |
| `Creatures/<X>.md` | same as faction enemies, tagged by creature type |
| Random Encounter note (no NPC) | `resources/dungeon/events/<id>.tres` if it's a dungeon vignette, else a location-triggered encounter |

Naming: all ids `snake_case`; filename matches the id; locations prefixed `loc_`;
speakers prefixed `ds_`; enemy and encounter folders mirror each other.

## 3.3 Tag magnitude scale

The vault's morality and approval tags are unquantified. Fixed conversion, so
the same tag always means the same thing:

| Tag | `subtle` | `normal` (default) | `strong` |
|---|---|---|---|
| `[+Good]` / `[+Evil]` | virtue ±2 | virtue ±5 | virtue ±10 |
| `[+Orderly]` / `[+Chaotic]` | order ±2 | order ±5 | order ±10 |
| `[APPROVAL: ±1]` | ±3 | ±5 | ±10 |
| `[APPROVAL: ±2]` | ±6 | ±10 | ±20 |

Set `morality_scale:` per encounter in the Build Block. Default is `normal`.
Rationale: at `normal`, a full arc of ~20 tagged choices can move an axis by
about half its range — enough that consistent play reads as a stance, not
enough that one scene defines you.

Relationship deltas are **not** tag-driven — they're explicit in the quest or
encounter Build Block, because they're player-visible and shouldn't move by
accident.

## 3.4 Setting rules I enforce automatically

Pulled from `Characters/Bones.md` and the `dialogue-creator` skill. I check these
on anything I write or convert:

1. **Bones is amnesiac.** No dialogue where he references his real name, his age,
   how long he was dead, House Merrow, or his past — until the story has revealed
   it and a flag says so.
2. **Tone is Pratchett / Fable.** The absurd is treated as normal. Nobody winks
   at the audience. Humour comes from the gap between what the system demands
   and what reality is.
3. **Dialogue script, not prose.** No narrative paragraphs between lines, no
   internal monologue, no describing what the player can see on screen.
4. **The AI-tells checklist** in `.claude/skills/dialogue-creator/references/WRITING_RULES.md`
   is a hard pass before I hand anything back.
5. **Names follow the vault's per-race conventions**, checked against existing
   notes before proposing anything new.
6. **No inventing lore.** New facts get raised as a question, not written in.
7. **Quality bar**: *Foreign Goods* and *Smoked Mackerel*.

---

# Part 4 — The session loop

1. **You write** in the vault — a quest note, an encounter, a faction expansion.
   Add a Build Block when it's ready to ship.
2. **You say "build it"** and point me at the note.
3. **I read back an id sheet and file plan** — every id I'm about to create,
   every existing resource I'm about to touch, every number I inferred. Names
   are cheap to fix here and expensive to fix later.
4. **I build in dependency order**: flags → speakers/NPCs → enemies → encounters
   → dialogues → quest → map wiring.
5. **I stamp the vault**: `game_id` filled, `status: built`, `updated` bumped.
6. **I hand back a wiring report** — what to eyeball in the editor, and the
   fastest in-game route to reach the new content.
7. **You playtest and give notes** at whatever level the problem lives: a bad
   line is an encounter-note edit; a bad structure is a quest-note edit; bad
   numbers are a Build Block edit. Then "rebuild X".

Reverse direction — when the game has content the vault doesn't (the 85 built
Navy enemies, for instance) — say "backfill" and I'll write the vault notes from
the game files so canon catches up.

---

# Part 5 — Known gaps and drift

Real problems in the current code and data. Each is fixable; flag it if a story
needs one.

## Engine gaps

1. **Location dialogue is a stub.** `LocationNode.first_visit_dialogue` /
   `visit_dialogue` are stored but never played — `MapManager._trigger_dialogue()`
   only prints (`map_manager.gd:474`). Arrival cutscenes need this wired.
   Workaround: put the scene on an NPC gated by `location_visited`.
2. **`DELIVER`, `ESCORT`, `SURVIVE` objectives never report.** No code path
   increments them. Use `CUSTOM` + a dialogue tag, or ask for the hook.
3. **Quest definitions must be flat** in `resources/definitions/quests/` —
   `QuestManager._load_all_definitions()` doesn't recurse. Subfolders vanish
   silently.
4. **Dialogue editor dropdowns are misconfigured.** Enter Dungeon scans
   `res://resources/dungeons/` but dungeons live in `res://resources/dungeon/`
   (singular) → always empty. Start Combat only scans
   `resources/encounters/region1/`, so baseline encounters don't appear. Both are
   one-line fixes in `addons/dialogue_editor/nodes/action_node.gd`.
5. **Story flags need a code edit** — every new flag is an `@export var` in
   `resources/data/story_flags.gd`. Batch them per arc.
6. **`LocationNode.npc_ids` is unused.** NPC placement is driven entirely by
   `NPCDefinition.home_location_id`.
7. **Item conditions match on `item_name`**, not a stable id. Quest items need
   unique display names or they collide.
8. **Kill credit fires from `GameManager.pending_encounter`** after victory
   (`game_root.gd:389`). Scripted quest fights must start through the dialogue
   Action node or they won't count.
9. **No multi-line player-choice pool** — hence the tone-triple issue in 2.3.

## Vault ↔ game drift

10. **`game_id` is empty almost everywhere.** Only `Characters/Cate.md` has one.
    Until it's populated, "what's in the game" isn't queryable. First backfill
    job.
11. **The Sanctum Navy note's rank list doesn't match the built enemies.** The
    note lists ~20 ranks across five tiers; the game has **85** Navy enemies
    (17 per tier), with different names — the note says "Tide Priest" at trash,
    the game has `tide_priest` at trash *and* `tide_chaplain` at elite,
    `high_tide_priest` at mini-boss, `tide_oracle` at boss, `tidecaller_absolute`
    at world boss. Canon needs to catch up to the build.
12. **Embergate is non-canon.** `Locations/Embergate.md` flags it as a test town,
    but it's the live starting location in-game with Cate homed there
    (`resources/maps/test/loc_embergate.tres`). Either promote it to canon or
    plan the relocation — right now every quest we anchor there inherits that
    debt.
13. **The whole live map is `resources/maps/test/`** — Embergate, Crossroads,
    Harbor Watch, Dockside Camp, Patrol Grounds, Navy Sanctum. None of it
    corresponds to vault geography (Veritas Port, Sanctum City, Bastion Rock,
    Kestrel's Reach). The first real arc should probably start by building the
    canon map region rather than writing into the test one.
14. **Existing quest `.tres` files are test scaffolding** —
    `cates_curiosity`, `navy_bounty`, `harbor_masters_request`,
    `smugglers_cache`, `secret_stash`, `explorers_instinct` exist in the game
    with no matching vault notes. Backfill or delete.
15. **`CLAUDE.md`'s addon list is stale.** Actually enabled per `project.godot`:
    BurstParticles2D, companion_builder, dialogue_editor, e64_palette,
    npc_dialogue_manager, quest_manager.
