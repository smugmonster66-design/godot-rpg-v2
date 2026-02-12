# ============================================================================
# CHUNK 4 — PREREQUISITES + SKILL TREE ASSEMBLY
# ============================================================================
#
# INSTRUCTIONS: Replace the two remaining `pass` stubs in the generator:
#   func _wire_prerequisites():  pass  # CHUNK 3
#   func _build_skill_tree():    pass  # CHUNK 3
#
# with the full implementations below.
# ============================================================================


# ============================================================================
# PREREQUISITE WIRING
# ============================================================================
#
# Design doc prerequisite map:
#
# TIER 2 (all require Ignite):
#   Ember Dice       ← Ignite
#   Searing Force    ← Ignite
#   Kindling         ← Ignite
#
# TIER 3:
#   Fuel the Fire    ← Ember Dice
#   Pyroclasm        ← Searing Force
#   Heat Shimmer     ← Searing Force
#   Flame Ward       ← Kindling
#
# TIER 4:
#   Accelerant       ← Fuel the Fire
#   Immolate         ← Ember Dice
#   Conflagrant Surge← Pyroclasm
#   Mana Flare       ← Kindling
#   Hearthfire       ← Kindling
#
# TIER 5:
#   Inferno          ← Accelerant, Immolate
#   Eruption         ← Conflagrant Surge
#   Tempered Steel   ← Mana Flare
#
# TIER 6:
#   Burning Vengeance← Inferno r1
#   ★ Flashpoint     ← Inferno r1, Pyroclasm      (crossover)
#   Firestorm        ← Eruption
#   ★ Forge Bond     ← Conflagrant Surge r2, Kindling (crossover)
#   Cauterize        ← Tempered Steel
#
# TIER 7:
#   Detonate         ← Burning Vengeance
#   Cinder Storm     ← Flashpoint OR Firestorm     (either path)
#   Radiance         ← Forge Bond
#   Ember Link       ← Tempered Steel
#
# TIER 8:
#   ★ Pyroclastic Flow ← Inferno r1, Firestorm r1  (crossover)
#   Volcanic Core      ← Cinder Storm
#   ★ Crucible's Gift  ← Eruption, Tempered Steel r1 (crossover)
#
# TIER 9:
#   Eternal Flame    ← Detonate, Pyroclastic Flow
#   Ironfire Stance  ← Radiance, Crucible's Gift
#
# TIER 10:
#   Conflagration    ← Eternal Flame, Ironfire Stance  (both deep paths converge)
#
# ============================================================================

func _wire_prerequisites():
	print("\n🔗 Wiring prerequisites...")

	# Helper to add a prereq to a skill
	# required_rank defaults to 1; pass higher for "requires rank N" prereqs
	var _add_prereq = func(skill_id: String, prereq_id: String, req_rank: int = 1):
		var skill: SkillResource = _skill_lookup.get(skill_id)
		var prereq_skill: SkillResource = _skill_lookup.get(prereq_id)
		if not skill:
			push_error("Prereq wiring: skill '%s' not found" % skill_id)
			return
		if not prereq_skill:
			push_error("Prereq wiring: prereq '%s' not found for '%s'" % [prereq_id, skill_id])
			return

		var sp := SkillPrerequisite.new()
		sp.required_skill = prereq_skill
		sp.required_rank = req_rank
		skill.prerequisites.append(sp)
		print("  🔗 %s ← %s (r%d)" % [skill.skill_name, prereq_skill.skill_name, req_rank])

	# ── TIER 2 ──
	_add_prereq.call("flame_ember_dice", "flame_ignite")
	_add_prereq.call("flame_searing_force", "flame_ignite")
	_add_prereq.call("flame_kindling", "flame_ignite")

	# ── TIER 3 ──
	_add_prereq.call("flame_fuel_the_fire", "flame_ember_dice")
	_add_prereq.call("flame_pyroclasm", "flame_searing_force")
	_add_prereq.call("flame_heat_shimmer", "flame_searing_force")
	_add_prereq.call("flame_flame_ward", "flame_kindling")

	# ── TIER 4 ──
	_add_prereq.call("flame_accelerant", "flame_fuel_the_fire")
	_add_prereq.call("flame_immolate", "flame_ember_dice")
	_add_prereq.call("flame_conflagrant_surge", "flame_pyroclasm")
	_add_prereq.call("flame_mana_flare", "flame_kindling")
	_add_prereq.call("flame_hearthfire", "flame_kindling")

	# ── TIER 5 ──
	_add_prereq.call("flame_inferno", "flame_accelerant")
	_add_prereq.call("flame_inferno", "flame_immolate")
	_add_prereq.call("flame_eruption", "flame_conflagrant_surge")
	_add_prereq.call("flame_tempered_steel", "flame_mana_flare")

	# ── TIER 6 ──
	_add_prereq.call("flame_burning_vengeance", "flame_inferno")
	_add_prereq.call("flame_flashpoint", "flame_inferno")           # ★ crossover
	_add_prereq.call("flame_flashpoint", "flame_pyroclasm")         # ★ crossover
	_add_prereq.call("flame_firestorm", "flame_eruption")
	_add_prereq.call("flame_forge_bond", "flame_conflagrant_surge", 2)  # ★ crossover, r2
	_add_prereq.call("flame_forge_bond", "flame_kindling")              # ★ crossover
	_add_prereq.call("flame_cauterize", "flame_tempered_steel")

	# ── TIER 7 ──
	_add_prereq.call("flame_detonate", "flame_burning_vengeance")
	_add_prereq.call("flame_cinder_storm", "flame_firestorm")
	_add_prereq.call("flame_radiance", "flame_forge_bond")
	_add_prereq.call("flame_ember_link", "flame_tempered_steel")

	# ── TIER 8 ──
	_add_prereq.call("flame_pyroclastic_flow", "flame_inferno")        # ★ crossover
	_add_prereq.call("flame_pyroclastic_flow", "flame_firestorm")      # ★ crossover
	_add_prereq.call("flame_volcanic_core", "flame_cinder_storm")
	_add_prereq.call("flame_crucibles_gift", "flame_eruption")         # ★ crossover
	_add_prereq.call("flame_crucibles_gift", "flame_tempered_steel")   # ★ crossover

	# ── TIER 9 ──
	_add_prereq.call("flame_eternal_flame", "flame_detonate")
	_add_prereq.call("flame_eternal_flame", "flame_pyroclastic_flow")
	_add_prereq.call("flame_ironfire_stance", "flame_radiance")
	_add_prereq.call("flame_ironfire_stance", "flame_crucibles_gift")

	# ── TIER 10 ──
	_add_prereq.call("flame_conflagration", "flame_eternal_flame")
	_add_prereq.call("flame_conflagration", "flame_ironfire_stance")

	# Re-save all skills with their prerequisites now attached
	print("\n💾 Re-saving skills with prerequisites...")
	for skill_id in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		var filename := skill_id.replace("flame_", "flame_")
		_save(skill, BASE_SKILL_DIR + filename + ".tres")


# ============================================================================
# SKILL TREE ASSEMBLY
# ============================================================================

func _build_skill_tree():
	print("\n🌳 Building SkillTree resource...")

	var tree := SkillTree.new()
	tree.tree_id = "mage_flame"
	tree.tree_name = "Flame"
	tree.description = "Master fire magic. Three paths: Pyre (burn & detonate), Crucible (raw power & AoE), Forge (efficiency & resilience)."

	# Populate tier arrays
	tree.tier_1_skills = _get_tier_skills(1)
	tree.tier_2_skills = _get_tier_skills(2)
	tree.tier_3_skills = _get_tier_skills(3)
	tree.tier_4_skills = _get_tier_skills(4)
	tree.tier_5_skills = _get_tier_skills(5)
	tree.tier_6_skills = _get_tier_skills(6)
	tree.tier_7_skills = _get_tier_skills(7)
	tree.tier_8_skills = _get_tier_skills(8)
	tree.tier_9_skills = _get_tier_skills(9)
	tree.tier_10_skills = _get_tier_skills(10)

	# Set tier unlock point requirements (from design doc)
	tree.tier_2_points_required = 1
	tree.tier_3_points_required = 3
	tree.tier_4_points_required = 5
	tree.tier_5_points_required = 8
	tree.tier_6_points_required = 11
	tree.tier_7_points_required = 15
	tree.tier_8_points_required = 20
	tree.tier_9_points_required = 25
	tree.tier_10_points_required = 28

	_save(tree, TREE_DIR + "mage_flame.tres")
	print("  🌳 SkillTree saved: %s (%d skills)" % [tree.tree_name, tree.get_all_skills().size()])

	# Validation
	var warnings := tree.validate()
	if warnings.size() > 0:
		print("\n⚠️  Validation warnings:")
		for w in warnings:
			print("    %s" % w)
	else:
		print("  ✅ Validation passed — no warnings!")


func _get_tier_skills(tier: int) -> Array[SkillResource]:
	"""Gather all skills for a tier from the lookup, sorted by column."""
	var result: Array[SkillResource] = []
	for skill_id in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		if skill.tier == tier:
			result.append(skill)
	# Sort by column for consistent ordering
	result.sort_custom(func(a, b): return a.column < b.column)
	return result
