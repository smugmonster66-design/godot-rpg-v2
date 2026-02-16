@tool
extends EditorScript

func _run():
	print("=" .repeat(60))
	print("  DAMAGE SYSTEM OVERHAUL — VALIDATION")
	print("=" .repeat(60))
	
	# ── Test 1: Basic percentage reduction ──
	print("\n── Test 1: Percentage Reduction ──")
	var packet = DamagePacket.new()
	packet.add_damage(ActionEffect.DamageType.SLASHING, 100.0)
	
	var stats_0 = {"armor": 0, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	var stats_50 = {"armor": 50, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	var stats_100 = {"armor": 100, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	var stats_200 = {"armor": 200, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	
	print("  100 Slashing vs 0 armor   = %d (expect 100)" % packet.calculate_final_damage(stats_0))
	print("  100 Slashing vs 50 armor  = %d (expect ~67)" % packet.calculate_final_damage(stats_50))
	print("  100 Slashing vs 100 armor = %d (expect 50)" % packet.calculate_final_damage(stats_100))
	print("  100 Slashing vs 200 armor = %d (expect ~33)" % packet.calculate_final_damage(stats_200))
	
	# ── Test 2: Barrier vs magical ──
	print("\n── Test 2: Barrier vs Magic ──")
	var fire_packet = DamagePacket.new()
	fire_packet.add_damage(ActionEffect.DamageType.FIRE, 100.0)
	
	var barrier_0 = {"armor": 0, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	var barrier_50 = {"armor": 0, "barrier": 50, "element_modifiers": {}, "defense_mult": 1.0}
	var barrier_100 = {"armor": 0, "barrier": 100, "element_modifiers": {}, "defense_mult": 1.0}
	
	print("  100 Fire vs 0 barrier   = %d (expect 100)" % fire_packet.calculate_final_damage(barrier_0))
	print("  100 Fire vs 50 barrier  = %d (expect ~67)" % fire_packet.calculate_final_damage(barrier_50))
	print("  100 Fire vs 100 barrier = %d (expect 50)" % fire_packet.calculate_final_damage(barrier_100))
	
	# ── Test 3: Armor does NOT reduce magic ──
	print("\n── Test 3: Armor vs Magic (should be 0 reduction) ──")
	var armor_only = {"armor": 200, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}
	print("  100 Fire vs 200 armor, 0 barrier = %d (expect 100)" % fire_packet.calculate_final_damage(armor_only))
	
	# ── Test 4: Element modifiers ──
	print("\n── Test 4: Element Modifiers ──")
	var immune = {"armor": 0, "barrier": 0, "element_modifiers": {"FIRE": 0.0}, "defense_mult": 1.0}
	var resist = {"armor": 0, "barrier": 0, "element_modifiers": {"FIRE": 0.5}, "defense_mult": 1.0}
	var weak = {"armor": 0, "barrier": 0, "element_modifiers": {"FIRE": 2.0}, "defense_mult": 1.0}
	var wrong_elem = {"armor": 0, "barrier": 0, "element_modifiers": {"ICE": 0.0}, "defense_mult": 1.0}
	
	print("  100 Fire vs IMMUNE       = %d (expect 0)" % fire_packet.calculate_final_damage(immune))
	print("  100 Fire vs RESIST 0.5   = %d (expect 50)" % fire_packet.calculate_final_damage(resist))
	print("  100 Fire vs WEAK 2.0     = %d (expect 200)" % fire_packet.calculate_final_damage(weak))
	print("  100 Fire vs ICE immune   = %d (expect 100)" % fire_packet.calculate_final_damage(wrong_elem))
	
	# ── Test 5: Element modifier + barrier combined ──
	print("\n── Test 5: Modifier + Barrier Combined ──")
	var resist_barrier = {"armor": 0, "barrier": 100, "element_modifiers": {"FIRE": 0.5}, "defense_mult": 1.0}
	var weak_barrier = {"armor": 0, "barrier": 100, "element_modifiers": {"FIRE": 2.0}, "defense_mult": 1.0}
	
	print("  100 Fire vs 0.5 resist + 100 barrier = %d (expect ~25)" % fire_packet.calculate_final_damage(resist_barrier))
	print("  100 Fire vs 2.0 weak + 100 barrier   = %d (expect 100)" % fire_packet.calculate_final_damage(weak_barrier))
	
	# ── Test 6: Mixed physical + magical packet ──
	print("\n── Test 6: Split Damage Packet ──")
	var split = DamagePacket.new()
	split.add_damage(ActionEffect.DamageType.SLASHING, 60.0)
	split.add_damage(ActionEffect.DamageType.FIRE, 40.0)
	
	var mixed_def = {"armor": 100, "barrier": 50, "element_modifiers": {}, "defense_mult": 1.0}
	# Slashing: 60 × (100/200) = 30, Fire: 40 × (100/150) = 26.7 → total ~57
	print("  60 Slash + 40 Fire vs 100 armor + 50 barrier = %d (expect ~57)" % split.calculate_final_damage(mixed_def))
	
	# ── Test 7: Piercing armor penetration ──
	print("\n── Test 7: Piercing ──")
	var pierce = DamagePacket.new()
	pierce.add_damage(ActionEffect.DamageType.PIERCING, 100.0)
	# Piercing ignores 50% armor → effective armor = 50 → 100/(100+50) = 67%
	print("  100 Piercing vs 100 armor = %d (expect ~67, pen ignores half)" % pierce.calculate_final_damage(stats_100))
	
	print("\n" + "=" .repeat(60))
	print("  DONE — Check values above match expectations")
	print("=" .repeat(60))
