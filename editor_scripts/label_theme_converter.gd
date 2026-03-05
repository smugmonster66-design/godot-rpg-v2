@tool
extends EditorScript

# ============================================================================
# LABEL THEME CONVERTER - EditorScript
# ============================================================================
# Converts manual font_size overrides to theme_type_variation for Labels.
#
# MODES:
#   - AUDIT: Print what would change (dry run)
#   - APPLY: Actually modify and save scenes
#
# USAGE:
#   1. Set MODE below
#   2. File > Run (Ctrl+Shift+X)
#   3. Check Output tab for results
# ============================================================================

enum Mode { AUDIT, APPLY }
const MODE: Mode = Mode.APPLY  # Change to Mode.APPLY to save changes

# ============================================================================
# CONFIGURATION
# ============================================================================

# Path patterns to EXCLUDE (labels in these paths are manually sized)
const EXCLUDE_PATHS: Array[String] = [
	"scenes/ui/components/dice/combat/",  # Combat dice - manually sized for textures
	"scenes/ui/components/dice/die_face_",  # Die face variants - texture-specific
]

# Scenes to process (relative to res://)
const SCENES: Array[String] = [
	"scenes/ui/combat/action_field.tscn",
	"scenes/ui/components/die_visual.tscn",
	"scenes/ui/components/skill_button.tscn",
	"scenes/ui/components/icon_button.tscn",
	"scenes/ui/components/stat_display.tscn",
	"scenes/ui/bottom_ui_panel.tscn",
	"scenes/ui/combat/enemy_slot.tscn",
	"scenes/game/game_root.tscn",
	"scenes/dungeon/dungeon_scene.tscn",
	"scenes/dungeon/popups/dungeon_rest_popup.tscn",
	"scenes/dungeon/popups/dungeon_shrine_popup.tscn",
]

# Theme variation mapping rules (priority order matters)
# Format: { "pattern": "theme_variation", "description": "when to use" }
const MAPPING_RULES: Array[Dictionary] = [
	# Exact name matches (highest priority)
	{"pattern": "ItemName", "theme": "title", "desc": "Item/equipment name display"},
	{"pattern": "TitleLabel", "theme": "title", "desc": "Popup/section titles"},
	{"pattern": "DungeonNameLabel", "theme": "caption", "desc": "Dungeon identifier"},
	{"pattern": "FloorLabel", "theme": "normal", "desc": "Floor progress"},
	{"pattern": "FlavorLabel", "theme": "FlavorLabel", "desc": "Narrative text"},
	
	# Numeric displays - should be prominent (large/header tier)
	{"pattern": "DmgPreview", "theme": "large", "desc": "Damage preview numbers"},
	{"pattern": "GoldValue", "theme": "large", "desc": "Gold value displays"},
	{"pattern": "XPValue", "theme": "large", "desc": "XP value displays"},
	{"pattern": "GoldLabel", "theme": "large", "desc": "Gold amounts"},
	{"pattern": "HealLabel", "theme": "large", "desc": "Heal amounts"},
	{"pattern": "ExpLabel", "theme": "large", "desc": "Experience points"},
	
	# Section headers
	{"pattern": "DiceTitle", "theme": "header", "desc": "Dice section titles"},
	{"pattern": "Header", "theme": "header", "desc": "Section headers"},
	{"pattern": "Title", "theme": "title", "desc": "Titles"},
	
	# Secondary info (small tier)
	{"pattern": "CountLabel", "theme": "small", "desc": "Count displays"},
	{"pattern": "CostLabel", "theme": "small", "desc": "Cost displays"},
	{"pattern": "ChargeLabel", "theme": "small", "desc": "Charge indicators"},
	{"pattern": "LevelLabel", "theme": "small", "desc": "Level displays"},
	{"pattern": "Prerequisites", "theme": "small", "desc": "Prerequisite text"},
	
	# Tertiary info (tiny tier)
	{"pattern": "ModifierLabel", "theme": "tiny", "desc": "Stat modifiers (+X)"},
	
	# Substring matches
	{"pattern": "Caption", "theme": "caption", "desc": "Captions"},
	{"pattern": "Subtitle", "theme": "normal", "desc": "Subtitles"},
	{"pattern": "Description", "theme": "large", "desc": "Item descriptions"},
	{"pattern": "Flavor", "theme": "FlavorLabel", "desc": "Flavor text"},
	
	# Functional patterns
	{"pattern": "ValueLabel", "theme": "large", "desc": "Numeric values (die faces, stats)"},
	{"pattern": "NameLabel", "theme": "normal", "desc": "Entity names"},
	{"pattern": "SkillName", "theme": "normal", "desc": "Skill names"},
	{"pattern": "RankLabel", "theme": "small", "desc": "Skill ranks"},
	{"pattern": "DescLabel", "theme": "small", "desc": "Short descriptions"},
	{"pattern": "MultLabel", "theme": "small", "desc": "Multipliers"},
	{"pattern": "TypeLabel", "theme": "tiny", "desc": "Type indicators"},
	{"pattern": "TagsLabel", "theme": "tiny", "desc": "Tag lists"},
	{"pattern": "EmptyLabel", "theme": "small", "desc": "Empty state text"},
	
	# Health/resource displays
	{"pattern": "health", "theme": "small", "desc": "Health displays", "case_insensitive": true},
	{"pattern": "mana", "theme": "small", "desc": "Mana displays", "case_insensitive": true},
	
	# Fallback for unlabeled generics
	{"pattern": "Label", "theme": "normal", "desc": "Generic labels (fallback)"},
]

# ============================================================================
# STATE
# ============================================================================

var changes_made: int = 0
var scenes_modified: int = 0
var audit_report: Array[Dictionary] = []

# ============================================================================
# MAIN EXECUTION
# ============================================================================

func _run():
	print("\n" + "=".repeat(80))
	print("🎨 LABEL THEME CONVERTER - %s MODE" % Mode.keys()[MODE])
	print("=".repeat(80) + "\n")
	
	for scene_path in SCENES:
		var full_path = "res://%s" % scene_path
		if not ResourceLoader.exists(full_path):
			print("⚠️  Scene not found: %s" % scene_path)
			continue
		
		process_scene(full_path)
	
	print_summary()

# ============================================================================
# SCENE PROCESSING
# ============================================================================

func process_scene(scene_path: String):
	print("📄 Processing: %s" % scene_path.get_file())
	
	# Check exclusion patterns
	for exclude_path in EXCLUDE_PATHS:
		if exclude_path in scene_path:
			print("   ⏭️  Skipped (excluded path: %s)" % exclude_path)
			return
	
	var scene = load(scene_path)
	if not scene:
		print("   ❌ Failed to load scene")
		return
	
	var root = scene.instantiate()
	if not root:
		print("   ❌ Failed to instantiate scene")
		return
	
	var scene_changes: int = 0
	var labels_found: Array[Label] = []
	
	# Recursively find all Label nodes
	_find_labels_recursive(root, labels_found)
	
	print("   Found %d labels" % labels_found.size())
	
	for label in labels_found:
		if process_label(label, scene_path):
			scene_changes += 1
	
	if scene_changes > 0:
		if MODE == Mode.APPLY:
			# Save modified scene
			var packed = PackedScene.new()
			var result = packed.pack(root)
			if result == OK:
				ResourceSaver.save(packed, scene_path)
				print("   ✅ Saved %d changes" % scene_changes)
				scenes_modified += 1
			else:
				print("   ❌ Failed to pack scene")
		else:
			print("   📋 Would modify %d labels" % scene_changes)
	
	root.queue_free()
	changes_made += scene_changes

func _find_labels_recursive(node: Node, results: Array[Label]):
	if node is Label:
		results.append(node)
	
	for child in node.get_children():
		_find_labels_recursive(child, results)

# ============================================================================
# LABEL PROCESSING
# ============================================================================

func process_label(label: Label, scene_path: String) -> bool:
	"""Process a single label. Returns true if changes were made."""
	
	# Skip labels that already use theme variations
	if label.theme_type_variation != &"":
		return false
	
	# Check if it has manual font_size override
	var has_override = false
	var current_size = 0
	
	# Check theme overrides
	if label.has_theme_font_size_override("font_size"):
		has_override = true
		current_size = label.get_theme_font_size("font_size")
	
	# Determine appropriate theme variation
	var suggested_theme = suggest_theme_variation(label)
	
	if not suggested_theme:
		# No clear mapping - skip
		return false
	
	var change_info = {
		"scene": scene_path.get_file(),
		"node_path": _get_node_path(label),
		"node_name": label.name,
		"current_override": current_size if has_override else "none",
		"suggested_theme": suggested_theme,
		"reason": _get_mapping_reason(label),
	}
	
	audit_report.append(change_info)
	
	if MODE == Mode.AUDIT:
		print("      • %s → [%s]  (%s)" % [
			label.name,
			suggested_theme,
			change_info.reason
		])
	else:
		# Apply changes
		label.theme_type_variation = suggested_theme
		
		# Remove manual overrides (theme handles it now)
		if has_override:
			label.remove_theme_font_size_override("font_size")
		
		print("      ✓ %s → [%s]" % [label.name, suggested_theme])
	
	return true

# ============================================================================
# THEME SUGGESTION LOGIC
# ============================================================================

func suggest_theme_variation(label: Label) -> String:
	"""Determine appropriate theme variation based on label name and context."""
	
	var label_name = label.name
	
	# Try each mapping rule in order
	for rule in MAPPING_RULES:
		var pattern = rule.pattern
		var case_insensitive = rule.get("case_insensitive", false)
		
		var name_to_check = label_name.to_lower() if case_insensitive else label_name
		var pattern_to_check = pattern.to_lower() if case_insensitive else pattern
		
		if name_to_check == pattern_to_check or pattern_to_check in name_to_check:
			return rule.theme
	
	return ""  # No match found

func _get_mapping_reason(label: Label) -> String:
	"""Get human-readable reason for the theme choice."""
	var label_name = label.name
	
	for rule in MAPPING_RULES:
		var pattern = rule.pattern
		var case_insensitive = rule.get("case_insensitive", false)
		
		var name_to_check = label_name.to_lower() if case_insensitive else label_name
		var pattern_to_check = pattern.to_lower() if case_insensitive else pattern
		
		if name_to_check == pattern_to_check or pattern_to_check in name_to_check:
			return rule.desc
	
	return "no match"

# ============================================================================
# HELPERS
# ============================================================================

func _get_node_path(node: Node) -> String:
	"""Get scene-relative path for a node."""
	var path_parts: Array[String] = []
	var current = node
	
	while current and not current is Window:
		path_parts.insert(0, current.name)
		current = current.get_parent()
	
	return "/".join(path_parts)

# ============================================================================
# REPORTING
# ============================================================================

func print_summary():
	print("\n" + "=".repeat(80))
	print("📊 SUMMARY")
	print("=".repeat(80))
	
	if MODE == Mode.AUDIT:
		print("Mode: AUDIT (dry run - no changes saved)")
		print("Total labels to convert: %d" % changes_made)
		print("Scenes affected: %d" % SCENES.size())
		print("\nTo apply changes: Set MODE = Mode.APPLY and run again")
	else:
		print("Mode: APPLY")
		print("Labels converted: %d" % changes_made)
		print("Scenes modified: %d" % scenes_modified)
		print("\n✅ Changes saved to disk")
	
	print("\n" + "=".repeat(80))
	print("BREAKDOWN BY THEME VARIATION:")
	print("=".repeat(80))
	
	var theme_counts: Dictionary = {}
	for change in audit_report:
		var theme = change.suggested_theme
		theme_counts[theme] = theme_counts.get(theme, 0) + 1
	
	var sorted_themes = theme_counts.keys()
	sorted_themes.sort()
	
	for theme in sorted_themes:
		print("  %s: %d labels" % [theme, theme_counts[theme]])
	
	print("\n")
