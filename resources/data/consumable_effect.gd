# res://resources/data/consumable_effect.gd
# Base class for T5 Curio scripted effects.
# Subclass this and override execute().
extends Resource
class_name ConsumableEffect

func execute(player, params: Dictionary, context: Dictionary) -> Dictionary:
	"""Override in subclass. Return {"success": bool, "message": String, "effects": Array}"""
	return {"success": false, "message": "Not implemented.", "effects": []}
