# res://scripts/ui/combat/combat_ui_die_helpers.gd
# Helper functions for creating die visuals in combat UI
# Can be used as a static class or instantiated
class_name CombatUIDieHelpers

## Create a temporary die visual for animations (e.g., enemy attacks)
static func create_temp_die_visual(die: DieResource, parent: Node) -> CombatDieObject:
	var obj = die.instantiate_combat_visual()
	if obj:
		obj.draggable = false
		obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(obj)
	return obj

## Create a scaled die visual for display in panels
static func create_scaled_die_visual(die: DieResource, target_scale: float, parent: Node) -> CombatDieObject:
	var obj = die.instantiate_combat_visual()
	if obj:
		obj.draggable = false
		obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
		obj.set_display_scale(target_scale)
		parent.add_child(obj)
	return obj

## Animate die flying from source to target
static func animate_die_to_target(die_obj: CombatDieObject, target_pos: Vector2, duration: float = 0.3) -> Tween:
	var tween = die_obj.create_tween()
	tween.tween_property(die_obj, "global_position", target_pos, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	return tween

## Create and animate a die for attack display
static func create_attack_die_visual(die: DieResource, start_pos: Vector2, 
                                      target_pos: Vector2, parent: Node) -> CombatDieObject:
	var obj = create_temp_die_visual(die, parent)
	if obj:
		obj.global_position = start_pos
		animate_die_to_target(obj, target_pos)
	return obj
