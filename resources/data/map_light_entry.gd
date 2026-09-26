# res://resources/data/map_light_entry.gd
# A single point light source placed on a map for atmospheric lighting.
# Stored in MapLightingConfig.lights and rendered by the lighting overlay shader.
extends Resource
class_name MapLightEntry

## Position in map-space coordinates (same system as LocationNode.map_position).
@export var position: Vector2 = Vector2.ZERO

## Light color. Alpha is ignored — use energy for intensity.
@export var color: Color = Color(1.0, 0.9, 0.7, 1.0)

## Falloff radius in map-space pixels.
@export var radius: float = 200.0

## Intensity multiplier. 1.0 = full strength at center.
@export_range(0.0, 3.0, 0.05) var energy: float = 1.0
