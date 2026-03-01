# Progression System — Design Document

## Overview

A unified game state and progression system for "Roll The Bones" that handles:
- **Story Flags** — Typed booleans for narrative progression
- **Counters** — Named integers for tracking quantities
- **Relationships** — NPC affinity scores (-100 to +100)
- **Quests** — Multi-objective quest tracking with rewards
- **Map** — Node-based world exploration with unlock conditions
- **Conditions** — AND/OR logic for gating content

All state is stored in a single `SaveData` resource with typed sub-classes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AUTOLOADS                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  GameState   │  │ QuestManager │  │  MapManager  │              │
│  │  (owns save) │  │ (quest logic)│  │ (travel/map) │              │
│  └──────┬───────┘  └──────────────┘  └──────────────┘              │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      SaveData.tres                           │   │
│  │  ┌────────────┐ ┌──────────┐ ┌───────────────┐              │   │
│  │  │ StoryFlags │ │ Counters │ │ Relationships │              │   │
│  │  │ (booleans) │ │  (ints)  │ │   (affinity)  │              │   │
│  │  └────────────┘ └──────────┘ └───────────────┘              │   │
│  │  ┌──────────────┐ ┌─────────────┐                           │   │
│  │  │ QuestJournal │ │ MapProgress │                           │   │
│  │  │  (progress)  │ │ (explored)  │                           │   │
│  │  └──────────────┘ └─────────────┘                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   DEFINITIONS (Static)                       │   │
│  │  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐   │   │
│  │  │ QuestDefinition │  │ LocationNode │  │ GameCondition │   │   │
│  │  │ (what quest IS) │  │ (map nodes)  │  │ (unlock logic)│   │   │
│  │  └─────────────────┘  └──────────────┘  └───────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Story Flags

```gdscript
# Direct property access (autocomplete!)
GameState.flags.met_king = true
GameState.flags.bridge_repaired = true

# Or by name
GameState.set_flag(&"met_king", true)
var met = GameState.get_flag(&"met_king")

# Listen for changes
GameState.flag_changed.connect(func(flag, value):
    print("%s is now %s" % [flag, value])
)
```

**Adding new flags:** Edit `story_flags.gd` and add `@export var your_flag: bool = false`

### Counters

```gdscript
# Increment
GameState.counters.increment(&"enemies_killed")
GameState.counters.enemies_killed += 1  # Property accessor

# Get value
var kills = GameState.get_counter(&"enemies_killed")

# Set specific value
GameState.counters.set_counter(&"gold_donated", 500)
```

### Relationships

```gdscript
# Modify affinity (-100 to +100)
GameState.modify_relationship(&"hilda", 10)  # +10 affinity
GameState.modify_relationship(&"guard", -20) # -20 affinity

# Check relationship state
var state = GameState.relationships.get_state(&"hilda")
if state >= Relationships.RelationshipState.FRIENDLY:
    # Show friendly dialogue options
```

### Quests

```gdscript
# Accept a quest
QuestManager.try_accept_quest(&"main_quest_1")

# Report progress (called by game systems)
QuestManager.report_kill(&"goblin", 1)
QuestManager.report_talk_to(&"merchant_hilda")
QuestManager.report_collect(&"ancient_coin", 3)
QuestManager.report_visit(&"haunted_ruins")

# Complete/turn-in
QuestManager.try_complete_quest(&"main_quest_1")

# Check state
if GameState.quests.is_active(&"main_quest_1"):
    # Show quest marker
```

### Map/Locations

```gdscript
# Travel to a location
if MapManager.can_travel_to(&"village_square"):
    MapManager.travel_to(&"village_square")

# Get current location
var location = MapManager.get_current_location()
print("You are at: %s" % location.display_name)

# Get available destinations
var destinations = MapManager.get_available_destinations()
for dest in destinations:
    print("%s - %s" % [dest.name, "Unlocked" if dest.unlocked else dest.locked_hint])

# Listen for travel
MapManager.location_entered.connect(func(id, location, first_visit):
    if first_visit:
        print("First time visiting %s!" % location.display_name)
)
```

### Conditions (for dialogue, locations, quests)

```gdscript
# Simple flag check
var cond = GameCondition.flag(&"met_king")

# Counter comparison
var cond2 = GameCondition.counter_at_least(&"enemies_killed", 50)

# AND logic
var cond3 = GameCondition.all_of([
    GameCondition.flag(&"met_king"),
    GameCondition.counter_at_least(&"gold_donated", 100)
])

# OR logic
var cond4 = GameCondition.any_of([
    GameCondition.flag(&"has_key"),
    GameCondition.flag(&"lockpick_skill")
])

# Evaluate
if GameState.evaluate_condition(cond3):
    # Condition met!
```

### Saving/Loading

```gdscript
# Save (call periodically or at checkpoints)
GameState.save()

# Load (usually at game start)
GameState.load_game()

# New game
GameState.new_game()

# Check for existing save
if GameState.has_save():
    # Show "Continue" button
```

---

## File Structure

```
resources/
├── data/                           # Resource class definitions
│   ├── save_data.gd               # Main save file resource
│   ├── story_flags.gd             # Typed boolean flags
│   ├── counters.gd                # Named integer counters
│   ├── relationships.gd           # NPC affinity tracking
│   ├── quest_journal.gd           # Quest progress collection
│   ├── quest_progress.gd          # Single quest runtime state
│   ├── quest_definition.gd        # Quest template (static)
│   ├── quest_objective.gd         # Single objective definition
│   ├── quest_rewards.gd           # Quest reward bundle
│   ├── map_progress.gd            # Map exploration state
│   ├── location_node.gd           # Location definition (static)
│   └── game_condition.gd          # Condition system with AND/OR
│
├── definitions/                    # Static game data
│   ├── quests/                    # Quest definitions (.tres)
│   │   ├── main_quest_1.tres
│   │   └── side_quest_blacksmith.tres
│   └── locations/                 # Location definitions (.tres)
│       ├── region1/
│       │   ├── starting_village.tres
│       │   └── forest_path.tres
│       └── region2/
│           └── port_city.tres
│
scripts/
└── autoload/
    ├── game_state.gd              # Central state access
    ├── quest_manager.gd           # Quest logic & tracking
    └── map_manager.gd             # Map & travel logic
```

---

## Autoload Registration

Add to Project Settings → Autoload (in this order):

| Name | Path |
|------|------|
| GameState | res://scripts/autoload/game_state.gd |
| QuestManager | res://scripts/autoload/quest_manager.gd |
| MapManager | res://scripts/autoload/map_manager.gd |

---

## Creating Content

### New Story Flag

1. Open `resources/data/story_flags.gd`
2. Add: `@export var your_flag_name: bool = false`
3. Use: `GameState.flags.your_flag_name = true`

### New Quest

1. Create `.tres` file in `resources/definitions/quests/`
2. Set resource type to `QuestDefinition`
3. Fill in:
   - `quest_id`: Unique StringName
   - `display_name`: Shown in UI
   - `quest_giver_id`: NPC who gives it
   - `objectives`: Array of QuestObjective
   - `rewards`: QuestRewards resource
   - `prerequisites`: GameCondition (optional)

### New Location

1. Create `.tres` file in `resources/definitions/locations/`
2. Set resource type to `LocationNode`
3. Fill in:
   - `location_id`: Unique StringName
   - `display_name`: Shown on map
   - `node_type`: Town, Dungeon, etc.
   - `connections`: Array of connected location IDs
   - `unlock_condition`: GameCondition (optional)

### Complex Condition

In the Inspector, create a `GameCondition` resource:

1. Set `condition_type` to `AND` or `OR`
2. Add `sub_conditions` array
3. Each sub-condition can be:
   - Another AND/OR for nesting
   - `SINGLE` with a `SingleCheck` for actual checks

Or in code:
```gdscript
var condition = GameCondition.all_of([
    GameCondition.flag(&"prologue_complete"),
    GameCondition.any_of([
        GameCondition.counter_at_least(&"reputation", 50),
        GameCondition.flag(&"special_pass")
    ])
])
```

---

## Integration with Dialogue System

Update `GameCondition.ConditionContext` in `game_state.gd` to work with your dialogue:

```gdscript
# In DialogueManager or wherever you check conditions:
func _check_choice_condition(choice: DialogueChoice) -> bool:
    if choice.condition == null:
        return true
    return GameState.evaluate_condition(choice.condition)
```

Update `DialogueChoice` to use `GameCondition`:
```gdscript
@export var condition: GameCondition = null
```

---

## Signals Reference

### GameState
- `state_loaded` — Save loaded/new game started
- `state_saved` — Save completed
- `flag_changed(flag_name, value)` — Story flag changed
- `counter_changed(name, old, new)` — Counter changed
- `relationship_changed(npc_id, old, new)` — Relationship changed

### QuestManager
- `quest_became_available(quest_id, definition)` — Quest unlocked
- `quest_objectives_updated(quest_id, definition)` — Progress made
- `quest_ready_for_turn_in(quest_id, definition)` — All objectives done

### MapManager
- `location_entered(id, location, first_visit)` — Player arrived
- `location_unlocked(id, location)` — Location became travelable
- `location_revealed(id, location)` — Location became visible
- `travel_blocked(from, to, reason)` — Travel attempt failed

---

## Tips

1. **Call `GameState.save()` at natural checkpoints** — after dialogue, after combat, at save points
2. **Use `QuestManager.check_all_quest_availability()`** after major state changes
3. **Use `MapManager.refresh_all_visibility()`** after unlocking content
4. **Typed flags give autocomplete** — prefer adding properties to `StoryFlags` over dynamic strings
5. **Conditions can nest arbitrarily deep** — AND containing OR containing AND, etc.
