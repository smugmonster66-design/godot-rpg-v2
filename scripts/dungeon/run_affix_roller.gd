# res://scripts/dungeon/run_affix_roller.gd
## Selects run affix offers from a pool with weighted random,
## mutual exclusion, and stack limit filtering.
## No scene or node dependencies — instantiated by DungeonScene.
##
## GODOT 4.x SAFETY:
##   - NOT static. Static funcs silently fail on property access
##     of objects inside untyped arrays.
##   - All internals use untyped arrays.
##   - .assign() used ONLY at the final typed return.
extends RefCounted
class_name RunAffixRoller


func roll_offers(pool: Array, run: DungeonRun, count: int = 3) -> Array[RunAffixEntry]:
	if pool.size() == 0:
		return [] as Array[RunAffixEntry]

	var eligible := _filter_eligible(pool, run)

	if eligible.size() == 0:
		return [] as Array[RunAffixEntry]

	if eligible.size() <= count:
		eligible.shuffle()
		var typed: Array[RunAffixEntry] = []
		typed.assign(eligible)
		return typed

	return _weighted_pick(eligible, count)


func _filter_eligible(pool: Array, run: DungeonRun) -> Array:
	# Build active tags from what the run has already chosen
	var active_tags := []
	for i in run.run_affixes_chosen.size():
		var chosen = run.run_affixes_chosen[i]
		if chosen == null:
			continue
		for tag in chosen.tags:
			if tag not in active_tags:
				active_tags.append(tag)

	var result := []
	for i in pool.size():
		var entry = pool[i]
		if entry == null:
			continue
		# Stack limit check
		var stack_count: int = run.get_run_affix_stack_count(entry)
		if stack_count >= entry.max_stacks:
			continue
		# Mutual exclusion check
		if entry.has_any_exclusive_tag(active_tags):
			continue
		result.append(entry)
	return result


func _weighted_pick(eligible: Array, count: int) -> Array[RunAffixEntry]:
	var picks := []
	# Manual copy to avoid .duplicate() issues
	var remaining := []
	for i in eligible.size():
		remaining.append(eligible[i])

	for _i in count:
		if remaining.size() == 0:
			break

		var total_weight: int = 0
		for j in remaining.size():
			total_weight += remaining[j].get_effective_weight()

		if total_weight <= 0:
			# Fallback: equal chance
			var idx: int = randi() % remaining.size()
			picks.append(remaining[idx])
			remaining.remove_at(idx)
			continue

		var roll: int = absi(randi()) % total_weight
		var cumulative: int = 0
		var pick_idx: int = 0
		for j in remaining.size():
			cumulative += remaining[j].get_effective_weight()
			if roll < cumulative:
				pick_idx = j
				break

		picks.append(remaining[pick_idx])
		remaining.remove_at(pick_idx)

	var typed: Array[RunAffixEntry] = []
	typed.assign(picks)
	return typed
