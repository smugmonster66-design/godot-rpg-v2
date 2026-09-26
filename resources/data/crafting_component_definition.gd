# res://resources/data/crafting_component_definition.gd
# Defines a single crafting component type (Common Component, Threads of Fate, etc.)
extends Resource
class_name CraftingComponentDefinition

## Unique identifier used as dictionary key in player.crafting_components
@export var component_id: StringName = &""

## Display name shown in UI
@export var display_name: String = ""

## Icon shown in smithing popup and inventory
@export var icon: Texture2D = null

## Short abbreviation shown when no icon is set (e.g. "Cmn", "Fate")
@export var abbreviation: String = ""

## Rarity tier (0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary)
@export_range(0, 4) var rarity_tier: int = 0

## Short description for tooltips
@export_multiline var description: String = ""
