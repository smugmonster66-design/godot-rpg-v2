# res://scripts/combat/counter_effect.gd
# Data class for registered counter-attacks that trigger when hit.
extends RefCounted
class_name CounterEffect

## Unique ID for this counter instance.
var counter_id: String = ""

## Display name (e.g., "Riposte", "Thorn Shield").
var counter_name: String = ""

## The ActionEffect to execute when triggered.
var counter_effect: ActionEffect = null

## Remaining times this counter can fire. 0 = unlimited.
var charges: int = 1

## Minimum damage to trigger (0 = any damage).
var damage_threshold: int = 0

## Owner who set up the counter.
var owner_name: String = ""
var owner = null

## Whether the counter is expired.
var is_expired: bool = false

static func create(p_name: String, p_effect: ActionEffect,
		p_charges: int, p_threshold: int, p_owner = null) -> CounterEffect:
	var c = CounterEffect.new()
	c.counter_id = "%s_%d" % [p_name.to_snake_case(), randi()]
	c.counter_name = p_name
	c.counter_effect = p_effect
	c.charges = p_charges
	c.damage_threshold = p_threshold
	c.owner = p_owner
	c.owner_name = p_owner.combatant_name if p_owner and "combatant_name" in p_owner else "Unknown"
	return c

func try_trigger(damage_taken: int) -> bool:
	"""Check if this counter should trigger from incoming damage.
	Returns true if triggered (caller should execute counter_effect)."""
	if is_expired:
		return false
	if damage_threshold > 0 and damage_taken < damage_threshold:
		return false
	# Consume a charge
	if charges > 0:
		charges -= 1
		if charges == 0:
			is_expired = true
	return true

func _to_string() -> String:
	return "CounterEffect<%s: %d charges, threshold=%d>" % [
		counter_name, charges, damage_threshold]
