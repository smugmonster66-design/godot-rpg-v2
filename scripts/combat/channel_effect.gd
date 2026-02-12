# res://scripts/combat/channel_effect.gd
# Data class for multi-turn channeled effects that grow stronger over time.
# Each turn the channel is maintained, it grows. Releases on completion or break.
extends RefCounted
class_name ChannelEffect

## Unique ID for this channel instance.
var channel_id: String = ""

## Display name (e.g., "Gathering Storm", "Focused Beam").
var channel_name: String = ""

## Maximum turns the channel can be maintained.
var max_turns: int = 3

## Current turn of channeling (starts at 1).
var current_turn: int = 1

## Growth multiplier per turn maintained. 0.5 = +50% per turn.
## Turn 1: 1.0x, Turn 2: 1.5x, Turn 3: 2.0x (additive growth).
var growth_per_turn: float = 0.5

## The ActionEffect to execute on release/break.
var release_effect: ActionEffect = null

## Owner who started the channel.
var owner_name: String = ""
var owner = null

## Whether the channel was broken (vs released naturally).
var was_broken: bool = false

## Whether the channel is complete (expired or released).
var is_complete: bool = false

static func create(p_name: String, p_release_effect: ActionEffect,
		p_max_turns: int, p_growth: float, p_owner = null) -> ChannelEffect:
	var c = ChannelEffect.new()
	c.channel_id = "%s_%d" % [p_name.to_snake_case(), randi()]
	c.channel_name = p_name
	c.release_effect = p_release_effect
	c.max_turns = p_max_turns
	c.growth_per_turn = p_growth
	c.owner = p_owner
	c.owner_name = p_owner.combatant_name if p_owner and "combatant_name" in p_owner else "Unknown"
	return c

func get_current_multiplier() -> float:
	"""Get the accumulated damage/effect multiplier for the current turn."""
	return 1.0 + (growth_per_turn * (current_turn - 1))

func advance_turn() -> bool:
	"""Advance the channel by one turn. Returns true if still active.
	If max turns reached, marks complete (caller should release)."""
	current_turn += 1
	if current_turn > max_turns:
		is_complete = true
	return not is_complete

func break_channel() -> void:
	"""Force-break the channel (e.g., by taking damage or not feeding dice)."""
	was_broken = true
	is_complete = true

func _to_string() -> String:
	return "ChannelEffect<%s: turn %d/%d, x%.1f>" % [
		channel_name, current_turn, max_turns, get_current_multiplier()]
