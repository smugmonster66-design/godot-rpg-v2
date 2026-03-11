# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A dice-based RPG built with **Godot 4.5** (GDScript), targeting mobile (1080x1920 portrait). The game features turn-based combat where players roll dice and place them into action fields, with deep affix/modifier systems for both equipment and dice. Roguelite dungeon runs use a Slay-the-Spire-style node map.

## Running the Project

Open in Godot 4.5 editor. Main scene is `scenes/game/game_root.tscn`. No external build tools or package managers are needed — all dependencies are in-repo addons.

## Architecture

### Data-Driven Design

All game content is defined as Godot Resources (`.tres` files) backed by GDScript class definitions in `resources/data/`. Zero hardcoded content — new items, enemies, affixes, and dungeons are created entirely through resource files. The `resources/data/` directory contains 70+ resource class definitions that form the data model.

### Autoloads (Singletons)

Defined in `project.godot` `[autoload]` section:

- **GameManager** — Holds persistent `Player` resource, bridges autoloads to GameRoot
- **GameState** — Central progression: story flags, counters, NPC relationships, quests, map progress
- **AffixPool** — Three-tier affix pools per equipment slot, lazy-loaded from `resources/affixes/`
- **AffixTableRegistry** / **DiceAffixTableRegistry** — Affix roll tables for equipment and dice
- **LootManager** — Generates items with random affixes at specified item_level
- **DieGenerator** — Creates DieResource instances with type/element/rarity
- **QuestManager** / **MapManager** / **DialogueManager** — Progression subsystems
- **ThemeManager** / **ResponsiveUI** — UI systems

### Combat System

The combat loop flows through these key files:

- `scripts/game/combat_manager.gd` — Orchestrates turn order, state machine (PLAYER_TURN, ENEMY_TURN, etc.)
- `scripts/combat/combat_event_bus.gd` — Central event hub; all combat signals flow through here
- `scripts/combat/combat_event.gd` — Lightweight RefCounted event payloads (not Resources), 20+ event types
- `scripts/resources/action_effect.gd` — Defines effect sequences (22 effect types, targeting, conditions)
- `scripts/combat/affix_proc_processor.gd` — Processes equipment affix procs on triggers
- `resources/data/dice_affix_processor.gd` — Processes dice affix triggers (ON_ROLL, ON_USE, PASSIVE, etc.)
- `scripts/effects/combat_animation_player.gd` — Listens to CombatEventBus and spawns visual effects

**Turn flow:** CombatManager starts turn → PlayerDiceCollection rolls hand → player places dice in ActionFields → ActionManager executes → effects fire events to CombatEventBus → CombatAnimationPlayer renders visuals → check victory/defeat → advance turn.

### Dice System

- `resources/data/die_resource.gd` — Die with type (D4-D20), element (10 types), and mutable dice_affixes array
- `resources/data/player_dice_collection.gd` — Pool (persistent templates) vs Hand (rolled copies for current turn)
- **Ghost Hand (v2.1):** Consumed dice marked `is_consumed=true` but remain in array so neighbor affixes can still resolve positions. Use `get_unconsumed_hand()` for available dice.
- **Position matters:** DiceAffix has `position_requirement` (FIRST, LAST, EVEN_SLOTS, etc.) and `neighbor_target` (LEFT, RIGHT, ALL_OTHERS, etc.)
- **50+ dice affix effect types** including value mods, tag operations, rerolls, status grants, chain/splash damage

### Affix System (Two Parallel Systems)

1. **Equipment Affixes** (`resources/data/affix.gd`) — On items, applied to `player.affix_manager` (AffixPoolManager). 50+ categories, proc triggers, conditions, sub-effects.
2. **Dice Affixes** (`resources/data/dice_affix.gd`) — On dice, processed by DiceAffixProcessor. Trigger-based (ON_ROLL, ON_USE, PASSIVE, ON_REORDER, ON_COMBAT_START/END).

Both support: ValueSource (20+ sources like STATIC, DICE_TOTAL, SOURCE_STAT), conditions, sub-effects, and dynamic scaling via AffixScalingConfig.

### Item/Equipment System

`resources/data/equippable_item.gd` — Items have three affix layers:
- `base_stat_affixes` — Always present, scale with item_level
- `inherent_affixes` — Identity affixes, don't scale
- `rolled_affixes` — Random from affix tables, scale with item_level

Equipment slots: Head, Torso, Gloves, Boots, MainHand, OffHand, Accessory. Slot definitions in `resources/items/` organized by region and slot type.

### Dungeon/Run System (Roguelite)

- `scripts/dungeon/dungeon_scene.gd` — Main dungeon controller
- `scripts/dungeon/dungeon_run.gd` — RefCounted run state tracker (gold, exp, items, chosen affixes)
- `resources/data/dungeon_definition.gd` — Defines everything for a run: encounters, events, loot pools, run affix pools
- `resources/data/run_affix_entry.gd` — Run affixes are either DICE (applied to all dice with "dungeon_temp" tag), STAT (added to affix_manager), or HYBRID. Supports stacking and mutual exclusion.
- Cleanup: `_cleanup_temp_effects()` removes all "dungeon_temp" affixes on run end.

### Progression System

See `docs/PROGRESSION_SYSTEM.md`. GameState holds StoryFlags (booleans), Counters (named ints), Relationships (-100 to +100), QuestJournal, and MapProgress. Condition system supports nested AND/OR logic for gating content.

### Dialogue System

See `docs/DIALOGUE_SYSTEM.md`. Signal-based with speech bubbles, character busts, player choices, and BBCode text effects. Conditions gate dialogue choices.

## Workflow Conventions

- **Find-replace delivery** — When proposing code changes, provide a FIND code block and a separate REPLACE code block so the user can copy-paste the replacement directly. Do not edit files directly.

## Key Conventions

- **Composition over inheritance** — Most features added via affixes/effects, not deep class hierarchies
- **Event-driven combat** — Visual system listens to CombatEventBus events, never called directly from game logic
- **CombatEvent is RefCounted**, not Resource — lightweight, created at runtime, short-lived
- **Resource paths** follow `resources/{type}/{region_or_category}/` pattern
- **Action definitions** in `resources/actions/` with effects defined as ActionEffect arrays in ActionEffectSlots
- **Enemies** defined in `resources/enemies/` with EnemyData resources containing actions, dice, AI strategy

## Custom Editor Addons

All in `addons/`, all enabled in project.godot:
- **affix_builder** — Inspector UI for Affix resources
- **action_effect_editor** — Visual builder for ActionEffect sequences
- **dungeon_editor** — Graph-based dungeon map designer
- **dialogue_editor** — Graph-based dialogue flow editor
- **theme_editor** — UI theme customization
- **auto_scene_documenter** — Generates SCENE_TREE.md from scene files
- **BurstParticles2D** — Third-party particle addon for combat effects
