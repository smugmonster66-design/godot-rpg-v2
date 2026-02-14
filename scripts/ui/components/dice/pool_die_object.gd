# res://scripts/ui/components/dice/pool_die_object.gd
# Pool die object - displays MAX value for map pool and inventory views
# Inherits visual and animation logic from DieObjectBase
extends DieObjectBase
class_name PoolDieObject

# ============================================================================
# POOL-SPECIFIC SIGNALS
# ============================================================================
## Emitted when reorder drag completes
signal reorder_completed(die_object: PoolDieObject, new_index: int)

# ============================================================================
# POOL STATE
# ============================================================================
var pool_index: int = -1  # Position in the dice pool

# ============================================================================
# VALUE DISPLAY - Shows max value
# ============================================================================

func _update_value_display():
	"""Show the maximum possible roll value"""
	if not die_resource or not value_label:
		return
	
	value_label.text = str(die_resource.get_max_value())

# ============================================================================
# POOL-SPECIFIC ANIMATIONS
# ============================================================================

func show_reorder_mode():
	"""Visual indicator that pool is in reorder mode"""
	if animation_player and animation_player.has_animation("reorder_ready"):
		animation_player.play("reorder_ready")
	else:
		# Fallback - subtle wobble
		var tween = create_tween()
		tween.set_loops(0)  # Loop indefinitely until stopped
		tween.tween_property(self, "rotation", deg_to_rad(2), 0.15)
		tween.tween_property(self, "rotation", deg_to_rad(-2), 0.3)
		tween.tween_property(self, "rotation", 0.0, 0.15)

func hide_reorder_mode():
	"""Exit reorder mode visual state"""
	rotation = 0.0
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func play_reorder_complete():
	"""Play animation when reorder finishes"""
	if animation_player and animation_player.has_animation("reorder_complete"):
		animation_player.play("reorder_complete")
	else:
		# Fallback - quick settle
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ============================================================================
# AFFIX DISPLAY
# ============================================================================

func show_affix_count():
	"""Show indicator if die has affixes"""
	var affix_count = die_resource.get_all_affixes().size() if die_resource else 0
	
	if affix_count > 0:
		# Look for existing indicator or create one
		var indicator = find_child("AffixIndicator", false, false) as Label
		if not indicator:
			indicator = Label.new()
			indicator.name = "AffixIndicator"
			indicator.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
			indicator.add_theme_color_override("font_color", ThemeManager.PALETTE.maxed)
			indicator.position = Vector2(base_size.x - 20, 2)
			add_child(indicator)
		
		indicator.text = "◆" if affix_count == 1 else "◆%d" % affix_count
		indicator.show()
	else:
		var indicator = find_child("AffixIndicator", false, false)
		if indicator:
			indicator.hide()

# ============================================================================
# SOURCE DISPLAY
# ============================================================================

func show_source_badge():
	"""Show where this die came from (class, item, etc.)"""
	if not die_resource or die_resource.source.is_empty():
		return
	
	var badge = find_child("SourceBadge", false, false) as Label
	if not badge:
		badge = Label.new()
		badge.name = "SourceBadge"
		badge.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.tiny)
		badge.add_theme_color_override("font_color", ThemeManager.PALETTE.text_secondary)
		badge.position = Vector2(2, base_size.y - 14)
		add_child(badge)
	
	badge.text = die_resource.source
	badge.show()

# ============================================================================
# POOL-SPECIFIC UTILITY
# ============================================================================

func set_pool_index(index: int):
	"""Set the index in the pool (for affix position requirements)"""
	pool_index = index
	if die_resource:
		die_resource.slot_index = index
