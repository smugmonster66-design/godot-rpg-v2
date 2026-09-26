# res://resources/data/map_lighting_config.gd
# Atmospheric lighting configuration for a map.
# Stored on MapDefinition.lighting_config and applied by the LightingOverlay shader.
extends Resource
class_name MapLightingConfig

## The darkness/tint color applied to the entire map.
## RGB = tint hue, Alpha = darkness intensity (0 = no effect, 1 = fully opaque tint).
@export var ambient_color: Color = Color(0.15, 0.1, 0.2, 0.6)

## Strength of the screen-edge vignette darkening. 0 = none.
@export_range(0.0, 1.0, 0.05) var vignette_strength: float = 0.3

## How gradually the vignette fades in from center to edge. Higher = softer.
@export_range(0.1, 1.0, 0.05) var vignette_softness: float = 0.4

## Point light sources on this map.
@export var lights: Array[MapLightEntry] = []

## --- Global directional lighting ---

## Normalized direction the light comes FROM. Default: top-left (light shines toward bottom-right).
## Controls both drop shadow direction and light ray direction.
@export var light_direction: Vector2 = Vector2(-0.707, -0.707)

## --- Drop shadows ---

## Opacity of drop shadows on decor, location icons, and player marker. 0 = no shadows.
@export_range(0.0, 1.0, 0.05) var shadow_opacity: float = 0.4

## Shadow offset distance in texture pixels.
@export_range(0.0, 30.0, 0.5) var shadow_offset: float = 6.0

## Shadow blur softness in texture pixels. 0 = hard edge.
@export_range(0.0, 8.0, 0.5) var shadow_softness: float = 2.0

## --- Light rays ---

## Whether the god rays layer is visible.
@export var light_rays_enabled: bool = false

## God rays tint color. Alpha controls base transparency of the ray bands.
@export var light_rays_color: Color = Color(1.0, 0.95, 0.8, 0.3)

## God rays intensity multiplier.
@export_range(0.0, 2.0, 0.05) var light_rays_energy: float = 0.5
