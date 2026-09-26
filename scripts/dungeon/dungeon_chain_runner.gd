# res://scripts/dungeon/dungeon_chain_runner.gd
# Runtime state tracker for an active dungeon chain session.
# Parallel to DungeonRun (which tracks a single dungeon), this tracks
# progression across multiple chained dungeons within one session.
extends RefCounted
class_name DungeonChainRunner

var chain: DungeonChain = null
var current_index: int = 0
var completed_runs: Array[DungeonRun] = []
var is_chain_complete: bool = false
var is_chain_failed: bool = false

## Cumulative cemented totals (for UI display / logging)
var total_gold_cemented: int = 0
var total_exp_cemented: int = 0
var total_items_cemented: int = 0

func _init(p_chain: DungeonChain = null):
	chain = p_chain

func get_current_definition() -> DungeonDefinition:
	if not chain:
		return null
	return chain.get_dungeon(current_index)

func has_next_dungeon() -> bool:
	if not chain:
		return false
	return current_index + 1 < chain.get_dungeon_count()

func advance() -> DungeonDefinition:
	"""Increment index and return the next definition, or null if chain is done."""
	current_index += 1
	if not chain or current_index >= chain.get_dungeon_count():
		is_chain_complete = true
		return null
	return chain.get_dungeon(current_index)

func record_completed_run(run: DungeonRun):
	completed_runs.append(run)
	total_gold_cemented += run.gold_earned
	total_exp_cemented += run.exp_earned
	total_items_cemented += run.items_earned.size()

func get_progress_text() -> String:
	if not chain:
		return "0 / 0"
	return "%d / %d" % [completed_runs.size(), chain.get_dungeon_count()]

func get_progress_fraction() -> float:
	if not chain or chain.get_dungeon_count() == 0:
		return 0.0
	return float(completed_runs.size()) / float(chain.get_dungeon_count())
