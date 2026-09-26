# res://resources/data/map_decor_item.gd
# A single decorative element placed on a map (tree, rock, ruin, fog patch, etc.).
# Stored in MapDefinition.decor_items and rendered by the DecorLayer at runtime.
extends Resource
class_name MapDecorItem

## Texture to display for this decor element.
@export var texture: Texture2D = null

## Position in map-space coordinates (same coordinate system as LocationNode.map_position).
@export var position: Vector2 = Vector2.ZERO

## Rotation in degrees.
@export var rotation_deg: float = 0.0

## Scale applied to the texture. (1, 1) = original size.
@export var item_scale: Vector2 = Vector2.ONE

## Color tint / modulate applied to the texture.
@export var tint: Color = Color.WHITE

## Z-ordering offset within the decor layer. Higher = rendered on top.
@export var z_offset: int = 0

## Whether the texture is flipped horizontally.
@export var flip_h: bool = false
