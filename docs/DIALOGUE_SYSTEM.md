# Dialogue System — Implementation Guide

## Overview

A signal-based dialogue system with:
- **Speech bubbles** with BBCode text effects
- **Character busts** anchored above the bubble (3 slots: left/center/right)
- **Player choices** in a ring around the portrait
- **Condition system** integration with GameCondition (AND/OR logic)
- **Theme compliance** using ThemeManager.PALETTE

---

## Quick Start

1. Extract zip into project root
2. Register autoload: Project Settings → Autoload → Add:
   - Path: `res://scripts/autoload/dialogue_manager.gd`
   - Name: `DialogueManager`
3. Add theme types (see below)
4. Add to `game_root.tscn`:
   - Add CanvasLayer named `DialogueLayer`, set Layer = 110
   - Instance `res://scenes/ui/dialogue/dialogue_ui.tscn`
5. Add to `game_root.gd`:
   ```gdscript
   @onready var dialogue_layer: CanvasLayer = $DialogueLayer
   @onready var dialogue_ui: Control = $DialogueLayer/DialogueUI
   ```
6. Test: `TestDialogue.launch_test()`

---

## Theme Types Required

Add these to `base_theme.tres`:

### DialogueBubble (PanelContainer)
- bg_color: PALETTE.bg_panel
- border_color: PALETTE.border_accent
- border_width: 2, corner_radius: 16

### DialogueChoiceBubble (PanelContainer)
- bg_color: PALETTE.bg_panel
- border_color: PALETTE.border_default
- border_width: 2, corner_radius: 12

### DialogueSpeakerName (RichTextLabel)
- default_color: PALETTE.warning (golden)
- font_size: 28

### DialogueText (RichTextLabel)
- default_color: PALETTE.text_primary
- font_size: 36

### DialogueChoiceLabel (Label)
- font_color: PALETTE.text_primary
- font_size: 24

---

## Condition System Integration

Choices now use `GameCondition` from the progression system:

```gdscript
# In DialogueChoice resource:
@export var condition: Resource = null  # GameCondition

# Examples:
var choice = DialogueChoice.new()
choice.label = "The king sent me"
choice.condition = GameCondition.flag(&"met_king")  # Only shows if flag is true
choice.show_when_locked = true  # Show grayed out if condition fails
choice.locked_hint = "You haven't met the king"
```

Complex conditions:
```gdscript
# AND: Must have met king AND have 100+ gold
var cond = GameCondition.all_of([
    GameCondition.flag(&"met_king"),
    GameCondition.counter_at_least(&"gold", 100)
])

# OR: Either has key OR has lockpick skill
var cond = GameCondition.any_of([
    GameCondition.flag(&"has_key"),
    GameCondition.flag(&"lockpick_skill")
])
```

---

## Creating Dialogue

### Method 1: Inspector (.tres files)

1. Create `DialogueSpeaker` resources for each character
2. Create `DialogueLine` resources (work backwards from endings)
3. Create `DialogueChoice` resources, wire to next lines
4. Create `DialogueEncounter` with speakers array and first_line

### Method 2: Code (for testing or procedural)

```gdscript
var speaker = DialogueSpeaker.new()
speaker.speaker_id = &"merchant"
speaker.display_name = "Merchant"
speaker.name_color = Color.GOLD

var line = DialogueLine.new()
line.speaker_id = &"merchant"
line.text = "Welcome to my [wave]shop[/wave]!"
line.set_right_bust = &"merchant"

var encounter = DialogueEncounter.new()
encounter.speakers = [speaker]
encounter.first_line = line

DialogueManager.start_dialogue(encounter)
```

---

## Bust Positioning

Busts are anchored to the dialogue bubble via `DialogueContainer`:

```
┌─────────────────────────────────────────┐
│    [Left]     [Center]     [Right]      │  ← BustContainer (above bubble)
│                                         │
│   ┌─────────────────────────────────┐   │
│   │    ▲ (tail points at speaker)   │   │
│   │    Speaker Name                 │   │
│   │    "Dialogue text here..."      │   │
│   │                             ▼   │   │
│   └─────────────────────────────────┘   │
│                                         │
│                MainBubble               │
└─────────────────────────────────────────┘
         DialogueContainer (moves as unit)
```

The entire unit can be repositioned by moving DialogueContainer.

---

## BBCode Tags

Built-in:
- `[b]bold[/b]`, `[i]italic[/i]`
- `[color=red]colored[/color]`
- `[wave]wavy text[/wave]`
- `[shake]shaky text[/shake]`
- `[rainbow]rainbow text[/rainbow]`

Custom (register via DialogueTextEffects):
- `[pulse freq=2 amp=0.15]pulsing[/pulse]`
- `[appear speed=10]fade-in[/appear]`
- `[tremble rate=15 amp=2]trembling[/tremble]`
- `[ghost freq=1 min=0.3]ghostly[/ghost]`

---

## Events

Wire up event handling:

```gdscript
DialogueManager.event_triggered.connect(_on_dialogue_event)

func _on_dialogue_event(tag: StringName):
    match tag:
        &"give_quest": QuestManager.make_quest_available(&"main_quest")
        &"open_shop": show_shop_ui()
        &"shake_screen": camera.shake()
```

---

## Files

```
resources/data/
├── dialogue_speaker.gd
├── dialogue_choice.gd
├── dialogue_line.gd
└── dialogue_encounter.gd

scripts/
├── autoload/dialogue_manager.gd
├── ui/dialogue/
│   ├── dialogue_ui.gd
│   ├── choice_bubble.gd
│   └── dialogue_text_effects.gd
└── debug/test_dialogue.gd

scenes/ui/dialogue/
├── dialogue_ui.tscn
└── choice_bubble.tscn

assets/ui/dialogue/
├── tail_main.png
└── tail_choice.png
```
