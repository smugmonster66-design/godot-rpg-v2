# res://scripts/dice/die_visual_registry.gd
# Global registry of die visuals. Populate entries in the inspector —
# each entry defines fill/stroke textures for a die size + element pair.
#
# Lookup priority:
#   1. Exact match (die_type + element)
#   2. Base match (die_type + element == -1)
#   3. null (no visuals found)
#
# Usage:
#   var entry = DieVisualRegistry.instance.get_entry(DieResource.DieType.D4, 3)
#   if entry:
#       entry.apply_to(die)
extends Resource
class_name DieVisualRegistry

## All visual entries. Add one per die size for base textures,
## and additional entries per element for elemental overrides.
@export var entries: Array[DieVisualEntry] = []

# ============================================================================
# SINGLETON ACCESS
# ============================================================================

static var instance: DieVisualRegistry

func register():
	"""Call once at startup to set the global instance."""
	instance = self

# ============================================================================
# LOOKUP
# ============================================================================

func get_entry(die_type: DieResource.DieType, element: int = -1) -> DieVisualEntry:
	"""Find the best visual entry for this die type + element.
	Tries exact match first, falls back to base (element == -1)."""
	var base_match: DieVisualEntry = null

	for entry in entries:
		if entry.die_type != die_type:
			continue
		if entry.element == element:
			return entry  # Exact match — done
		if entry.element == -1:
			base_match = entry

	return base_match  # May be null if nothing matches

func apply_visuals(die: DieResource):
	"""Convenience — look up and apply visuals for a DieResource."""
	var entry = get_entry(die.die_type, die.element)
	if entry:
		entry.apply_to(die)
