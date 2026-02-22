# res://scripts/ui/menus/skills_tab.gd
# Skills tab with sub-tabs for each skill tree - uses SkillTreeCanvas
extends Control
class_name SkillsTab

# ============================================================================
# SIGNALS
# ============================================================================
signal skill_learned(skill: SkillResource, new_rank: int)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@export_group("Header")
@export var skill_points_label: Label
@export var class_name_label: Label
@export var tree_points_label: Label  ## Shows points spent in current tree

@export_group("Tree Tabs")
@export var tree_tab_container: HBoxContainer
@export var tree_tab_1: Button
@export var tree_tab_2: Button
@export var tree_tab_3: Button

@export_group("Skill Canvas")
@export var skill_canvas: SkillTreeCanvas

@export_group("Skill Popup")
@export var skill_popup: SkillPopup

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var current_tree_index: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_connect_tab_buttons()
	if skill_canvas:
		skill_canvas.skill_clicked.connect(_on_skill_clicked)
	if skill_popup:
		skill_popup.learn_pressed.connect(_on_popup_learn_pressed)
	# Don't call _show_tree(0) here — wait for set_player()
	print("🌳 SkillsTab: Ready")



func _connect_tab_buttons():
	"""Connect tree tab buttons"""
	if tree_tab_1:
		tree_tab_1.pressed.connect(_on_tree_tab_pressed.bind(0))
	if tree_tab_2:
		tree_tab_2.pressed.connect(_on_tree_tab_pressed.bind(1))
	if tree_tab_3:
		tree_tab_3.pressed.connect(_on_tree_tab_pressed.bind(2))

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player reference and refresh display"""
	player = p_player
	refresh()

func refresh():
	"""Refresh entire tab display"""
	_update_header()
	_update_tree_tabs()
	_build_skill_grid()

func on_external_data_change():
	"""Called when other tabs modify player data - OPTIMIZED.
	Uses efficient state update if canvas is built, otherwise full refresh."""
	if not skill_canvas or skill_canvas.skill_buttons.is_empty():
		# Canvas not built yet - do full refresh
		refresh()
		return
	
	# Canvas exists - just update states without rebuild
	_update_header()
	_update_all_skill_buttons()


func has_active_popup() -> bool:
	"""Returns true if the skill detail popup is currently open."""
	return skill_popup != null and skill_popup.visible


# ============================================================================
# SKILL RANK HELPERS
# ============================================================================

func _get_skill_rank(skill_id: String) -> int:
	"""Get skill rank from player's active class"""
	if player and player.active_class:
		return player.active_class.get_skill_rank(skill_id)
	return 0

func _set_skill_rank(skill_id: String, rank: int):
	"""Set skill rank on player's active class"""
	if player and player.active_class:
		player.active_class.set_skill_rank(skill_id, rank)

func _get_current_skill_tree() -> SkillTree:
	"""Get the currently selected skill tree"""
	if not player or not player.active_class:
		return null
	return player.active_class.get_skill_tree_by_index(current_tree_index)

func _get_skill_rank_callable() -> Callable:
	"""Get a callable for checking skill ranks (for prerequisite checking)"""
	return func(skill_id: String) -> int:
		return _get_skill_rank(skill_id)

# ============================================================================
# TREE POINTS TRACKING
# ============================================================================

func _get_points_spent_in_tree(tree: SkillTree) -> int:
	"""Calculate total points spent in a specific skill tree"""
	if not tree or not player or not player.active_class:
		return 0
	
	var total = 0
	for skill in tree.get_all_skills():
		if skill:
			var rank = _get_skill_rank(skill.skill_id)
			total += rank * skill.skill_point_cost
	
	return total

func _get_points_spent_in_current_tree() -> int:
	"""Calculate total points spent in current skill tree"""
	return _get_points_spent_in_tree(_get_current_skill_tree())

# ============================================================================
# HEADER
# ============================================================================

func _update_header():
	if not player:
		if skill_points_label:
			skill_points_label.text = "No player"
		return
	
	if not player.active_class:
		if skill_points_label:
			skill_points_label.text = "No class selected"
		if class_name_label:
			class_name_label.text = ""
		return
	
	var active_class = player.active_class
	
	if class_name_label:
		class_name_label.text = active_class.player_class_name
	
	if skill_points_label:
		var available = active_class.get_available_skill_points()
		var total = active_class.total_skill_points
		skill_points_label.text = "Skill Points: %d / %d" % [available, total]
	
	# Update tree points display
	if tree_points_label:
		var tree = _get_current_skill_tree()
		if tree:
			var spent = _get_points_spent_in_current_tree()
			tree_points_label.text = "%s: %d points" % [tree.tree_name, spent]
		else:
			tree_points_label.text = ""

# ============================================================================
# TREE TABS
# ============================================================================

func _update_tree_tabs():
	"""Update tree tab names and visibility"""
	if not player or not player.active_class:
		_hide_all_tabs()
		return
	
	var trees = player.active_class.get_skill_trees()
	
	if tree_tab_1:
		if trees.size() > 0 and trees[0]:
			tree_tab_1.text = trees[0].tree_name
			tree_tab_1.show()
		else:
			tree_tab_1.hide()
	
	if tree_tab_2:
		if trees.size() > 1 and trees[1]:
			tree_tab_2.text = trees[1].tree_name
			tree_tab_2.show()
		else:
			tree_tab_2.hide()
	
	if tree_tab_3:
		if trees.size() > 2 and trees[2]:
			tree_tab_3.text = trees[2].tree_name
			tree_tab_3.show()
		else:
			tree_tab_3.hide()
	
	_update_tab_highlight()

func _hide_all_tabs():
	"""Hide all tree tabs when no class is active"""
	if tree_tab_1: tree_tab_1.hide()
	if tree_tab_2: tree_tab_2.hide()
	if tree_tab_3: tree_tab_3.hide()

func _update_tab_highlight():
	"""Highlight the active tab, dim inactive ones"""
	var tabs = [tree_tab_1, tree_tab_2, tree_tab_3]
	for i in range(tabs.size()):
		if tabs[i]:
			tabs[i].button_pressed = (i == current_tree_index)
			if i == current_tree_index:
				tabs[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				tabs[i].modulate = Color(0.5, 0.5, 0.5, 1.0)
	if tree_tab_container:
		print("🔍 TabContainer pos: %s | size: %s | center: %s" % [
			tree_tab_container.global_position,
			tree_tab_container.size,
			tree_tab_container.global_position.x + tree_tab_container.size.x / 2.0
		])


func _on_tree_tab_pressed(index: int):
	"""Switch to a different skill tree"""
	_show_tree(index)

func _show_tree(index: int):
	"""Show the specified tree"""
	current_tree_index = index
	_update_tab_highlight()
	_build_skill_grid()
	_update_header()

# ============================================================================
# SKILL GRID BUILDING
# ============================================================================

func _build_skill_grid():
	"""Build the skill canvas for the current tree"""
	if not skill_canvas:
		return
	var tree = _get_current_skill_tree()
	if not tree:
		return
	var points_spent = _get_points_spent_in_current_tree()
	skill_canvas.build(tree, _get_skill_rank_callable(), points_spent, player.active_class if player else null)

# ============================================================================
# SKILL BUTTON UPDATES
# ============================================================================

func _update_all_skill_buttons():
	"""Refresh all button states and prerequisite lines"""
	if not skill_canvas:
		return
	var points_spent = _get_points_spent_in_current_tree()
	skill_canvas.update_all_states(_get_skill_rank_callable(), points_spent)

# ============================================================================
# SKILL POPUP
# ============================================================================

func _on_skill_clicked(skill: SkillResource):
	"""Handle skill button click — show popup with skill details."""
	if not skill or not skill_popup:
		return
	
	if not player or not player.active_class:
		return
	
	var current_rank = _get_skill_rank(skill.skill_id)
	var effective_rank = _get_effective_skill_rank(skill)
	var tree_points = _get_points_spent_in_current_tree()
	var can_learn = skill.can_learn(_get_skill_rank_callable(), tree_points)
	var available_points = player.active_class.get_available_skill_points()
	
	skill_popup.show_skill(skill, current_rank, can_learn, available_points, [], effective_rank)

func _on_popup_learn_pressed(skill: SkillResource):
	"""Handle Learn button press from popup."""
	if not skill or not player or not player.active_class:
		return
	
	var skill_id = skill.skill_id
	var current_rank = _get_skill_rank(skill_id)
	var max_rank = skill.get_max_rank()
	
	# Check if already maxed
	if current_rank >= max_rank:
		print("🌳 %s is already maxed (%d/%d)" % [skill.skill_name, current_rank, max_rank])
		return
	
	# Check requirements
	var tree_points = _get_points_spent_in_current_tree()
	if not skill.can_learn(_get_skill_rank_callable(), tree_points):
		print("🌳 Requirements not met for %s" % skill.skill_name)
		_log_missing_requirements(skill, tree_points)
		return
	
	# Check skill points
	var available_points = player.active_class.get_available_skill_points()
	if available_points < skill.skill_point_cost:
		print("🌳 Not enough skill points for %s (need %d, have %d)" % [
			skill.skill_name, skill.skill_point_cost, available_points
		])
		return
	
	_learn_skill(skill)

# ============================================================================
# SKILL LEARNING
# ============================================================================

func _log_missing_requirements(skill: SkillResource, tree_points: int):
	"""Log detailed info about missing requirements"""
	# Check tree points
	if tree_points < skill.tree_points_required:
		print("  ❌ Need %d tree points (have %d)" % [skill.tree_points_required, tree_points])
	
	# Check prerequisites
	var missing = skill.get_missing_prerequisites(_get_skill_rank_callable())
	for prereq_data in missing:
		print("  ❌ Need %s Rank %d (have Rank %d)" % [
			prereq_data.skill.skill_name,
			prereq_data.required,
			prereq_data.current
		])


func _learn_skill(skill: SkillResource):
	"""Actually learn/rank up a skill"""
	var skill_id = skill.skill_id
	var current_rank = _get_skill_rank(skill_id)
	var new_rank = current_rank + 1
	
	# Spend skill point(s)
	for i in range(skill.skill_point_cost):
		if not player.active_class.spend_skill_point():
			print("🌳 Failed to spend skill point!")
			return
	
	# Update rank on the class
	_set_skill_rank(skill_id, new_rank)
	
	# Apply affixes from the new rank
	var new_affixes = skill.get_affixes_for_rank(new_rank)
	for affix in new_affixes:
		if affix:
			var affix_copy = affix.duplicate_with_source(skill.skill_name, "skill")
			player.affix_manager.add_affix(affix_copy)
			print("  ✨ Applied affix: %s" % affix.affix_name)
			
			# Register granted actions in the skill→action registry
			if affix.category == Affix.Category.NEW_ACTION and affix.granted_action:
				player.active_class.register_skill_action(
					skill.skill_id, affix.granted_action.action_id
				)
				print("  📋 Registered action: %s → %s" % [
					skill.skill_id, affix.granted_action.action_id
				])
	
	# Track applied effective rank for bonus rank diffing
	player.active_class.applied_effective_ranks[skill.skill_id] = new_rank
	
	# Notify mana pool that available elements/sizes may have changed
	if player.mana_pool:
		player.mana_pool.notify_options_changed()
	
	print("🌳 Learned %s rank %d!" % [skill.skill_name, new_rank])
	
	# Gear bonuses may now apply to the newly learned skill
	if player.active_class:
		player.active_class.recalculate_effective_ranks()
	
	# Refresh THIS tab directly (not via signal)
	refresh()
	
	# THEN emit signal for OTHER tabs (after our refresh is complete)
	skill_learned.emit(skill, new_rank)
	
	# Update popup if still visible
	if skill_popup and skill_popup.visible:
		var updated_rank = _get_skill_rank(skill_id)
		var updated_effective = _get_effective_skill_rank(skill)
		var tree_points = _get_points_spent_in_current_tree()
		var can_learn = skill.can_learn(_get_skill_rank_callable(), tree_points)
		var available_points = player.active_class.get_available_skill_points()
		skill_popup.show_skill(skill, updated_rank, can_learn, available_points, [], updated_effective)

# ============================================================================
# RESET
# ============================================================================

func reset_current_tree():
	"""Reset all skills in the current tree"""
	var tree = _get_current_skill_tree()
	if not tree or not player or not player.active_class:
		return
	
	for skill in tree.get_all_skills():
		if not skill:
			continue
		
		var rank = _get_skill_rank(skill.skill_id)
		if rank <= 0:
			continue
		
		# Unregister any granted actions
		var action_id = player.active_class.get_action_for_skill(skill.skill_id)
		if action_id != "":
			player.active_class.unregister_skill_action(skill.skill_id)
			print("  📋 Unregistered action: %s → %s" % [skill.skill_id, action_id])
		
		# Remove affixes
		player.affix_manager.remove_affixes_by_source(skill.skill_name)
		
		# Clear applied effective rank tracking
		player.active_class.applied_effective_ranks.erase(skill.skill_id)
		
		# Refund points
		for i in range(rank * skill.skill_point_cost):
			player.active_class.refund_skill_point()
		
		# Clear rank
		_set_skill_rank(skill.skill_id, 0)
	
	print("🌳 Reset %s tree" % tree.tree_name)
	refresh()



func reset_all_trees():
	"""Reset all skills across all trees"""
	if not player or not player.active_class:
		return
	
	for skill in player.active_class.get_all_skills():
		if skill:
			player.affix_manager.remove_affixes_by_source(skill.skill_name)
	
	# Clear registries
	player.active_class.skill_action_registry.clear()
	player.active_class.applied_effective_ranks.clear()
	
	player.active_class.reset_all_skills()
	
	print("🌳 All skills reset!")

# ============================================================================
# DEBUG
# ============================================================================

func print_learned_skills():
	"""Debug: Print all learned skills for active class"""
	if not player or not player.active_class:
		print("No active class")
		return
	
	print("=== Learned Skills for %s ===" % player.active_class.player_class_name)
	for skill_id in player.active_class.skill_ranks:
		print("  %s: Rank %d" % [skill_id, player.active_class.skill_ranks[skill_id]])

func _get_effective_skill_rank(skill: SkillResource) -> int:
	"""Get effective rank including gear bonuses."""
	if not player or not player.active_class or not skill:
		return 0
	var tree = _get_current_skill_tree()
	var tree_id = tree.tree_id if tree else ""
	var class_id = player.active_class.player_class_name if player.active_class else ""
	return player.active_class.get_effective_skill_rank(
		skill.skill_id, tree_id, class_id, skill.get_max_rank()
	)


func print_tree_status():
	"""Debug: Print current tree status"""
	var tree = _get_current_skill_tree()
	if not tree:
		print("No current tree")
		return
	
	print("=== %s Tree Status ===" % tree.tree_name)
	print("  Points spent: %d" % _get_points_spent_in_current_tree())
	
	for skill in tree.get_all_skills():
		if not skill:
			continue
		var rank = _get_skill_rank(skill.skill_id)
		var tree_points = _get_points_spent_in_current_tree()
		var can_learn = skill.can_learn(_get_skill_rank_callable(), tree_points)
		print("  [%d,%d] %s: Rank %d/%d %s" % [
			skill.tier, skill.column,
			skill.skill_name,
			rank, skill.get_max_rank(),
			"✓" if can_learn else "✗"
		])
