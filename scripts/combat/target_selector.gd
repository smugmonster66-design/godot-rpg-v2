# res://scripts/combat/target_selector.gd
# Intelligent target selection for enemy AI.
# Combines threat tracking, taunt mechanics, and role-based priorities.
#
# USAGE:
#   var target = TargetSelector.select_target(
#       enemy_combatant,
#       threat_tracker,
#       companion_manager,
#       player_combatant
#   )
extends RefCounted
class_name TargetSelector

# ============================================================================
# MAIN SELECTION
# ============================================================================

static func select_target(
	enemy: Combatant,
	threat_tracker: ThreatTracker,
	companion_manager,
	player_combatant: Combatant
) -> Combatant:
	
	# 1. CHECK IF THIS ENEMY IS TAUNTED
	var taunter = _get_taunting_companion_for(enemy)
	if taunter and taunter.is_alive():
		print("  [Target] %s is taunted by %s!" % [enemy.combatant_name, taunter.combatant_name])
		return taunter
	
	# 2. Normal targeting...
	var valid_targets = _get_alive_allies(companion_manager, player_combatant)
	# ... rest of role-based logic
	if valid_targets.is_empty():
		return null
	
	# 3. ROLE-BASED SELECTION
	var role = enemy.get("combat_role")
	if role == null:
		# Fallback for enemies without combat_role (legacy)
		return threat_tracker.get_highest_threat_target()
	
	var target: Combatant = null
	
	match role:
		0:  # BRUTE - Pure aggro, attack highest threat
			target = threat_tracker.get_highest_threat_target()
			print("  [Target] BRUTE → highest threat: %s" % target.combatant_name)
		
		1:  # SKIRMISHER - Opportunistic, weakest with minimum threat
			target = _lowest_hp_with_min_threat(valid_targets, threat_tracker, 10.0)
			print("  [Target] SKIRMISHER → weakest (min threat 10): %s" % target.combatant_name)
		
		2:  # CASTER - Weighted random by threat
			target = _weighted_random_by_threat(valid_targets, threat_tracker)
			print("  [Target] CASTER → weighted random: %s" % target.combatant_name)
		
		3:  # TANK - Protect allies by hitting biggest threat
			target = threat_tracker.get_highest_threat_target()
			print("  [Target] TANK → highest threat: %s" % target.combatant_name)
		
		4:  # SUPPORT - Execute low HP targets (ignore threat)
			target = _lowest_hp(valid_targets)
			print("  [Target] SUPPORT → lowest HP: %s" % target.combatant_name)
		
		_:
			target = threat_tracker.get_highest_threat_target()
			print("  [Target] UNKNOWN ROLE → highest threat: %s" % target.combatant_name)
	
	# 4. FALLBACK
	if not target or not target.is_alive():
		target = threat_tracker.get_highest_threat_target()
	
	return target

# ============================================================================
# TAUNT DETECTION
# ============================================================================

static func _get_taunting_companion_for(enemy: Combatant) -> Combatant:
	"""Check if this enemy has taunt status, return the taunting companion.
	Returns null if no taunt or taunter is dead."""
	var tracker: StatusTracker = null
	if enemy.has_node("StatusTracker"):
		tracker = enemy.get_node("StatusTracker")
	
	if not tracker:
		return null
	
	return tracker.get_taunting_combatant()





# ============================================================================
# ALLY QUERIES
# ============================================================================

static func _get_alive_allies(companion_manager, player_combatant: Combatant) -> Array[Combatant]:
	"""Get all alive allies (player + companions)."""
	var allies: Array[Combatant] = []
	
	# Add player if alive
	if player_combatant and player_combatant.is_alive():
		allies.append(player_combatant)
	
	# Add all alive companions
	if companion_manager:
		for companion in companion_manager.get_alive_companions():
			allies.append(companion)
	
	return allies

# ============================================================================
# ROLE-SPECIFIC TARGETING
# ============================================================================

static func _lowest_hp(targets: Array[Combatant]) -> Combatant:
	"""Get target with lowest current HP (execute role)."""
	if targets.is_empty():
		return null
	
	var lowest: Combatant = targets[0]
	var lowest_hp = lowest.current_health
	
	for i in range(1, targets.size()):
		if targets[i].current_health < lowest_hp:
			lowest_hp = targets[i].current_health
			lowest = targets[i]
	
	return lowest


static func _lowest_hp_with_min_threat(
	targets: Array[Combatant],
	threat_tracker: ThreatTracker,
	min_threat: float
) -> Combatant:
	"""Get lowest HP target that has at least min_threat.
	Prevents attacking allies that haven't acted yet.
	Falls back to highest threat if no one meets threshold."""
	
	var candidates: Array[Combatant] = []
	
	# Filter by minimum threat
	for target in targets:
		if threat_tracker.get_threat(target) >= min_threat:
			candidates.append(target)
	
	# No one meets threshold? Use highest threat instead
	if candidates.is_empty():
		return threat_tracker.get_highest_threat_target()
	
	# Pick lowest HP from candidates
	return _lowest_hp(candidates)


static func _weighted_random_by_threat(
	targets: Array[Combatant],
	threat_tracker: ThreatTracker
) -> Combatant:
	"""Pick a random target weighted by threat values.
	Higher threat = more likely to be picked, but still random."""
	
	if targets.is_empty():
		return null
	
	# Build weighted pool
	var total_threat: float = 0.0
	var threat_values: Array[float] = []
	
	for target in targets:
		var threat = maxf(threat_tracker.get_threat(target), 1.0)  # Min 1.0 so everyone has a chance
		threat_values.append(threat)
		total_threat += threat
	
	# Pick random value in [0, total_threat)
	var roll = randf() * total_threat
	var accumulated: float = 0.0
	
	for i in range(targets.size()):
		accumulated += threat_values[i]
		if roll < accumulated:
			return targets[i]
	
	# Fallback (shouldn't happen)
	return targets[-1]
