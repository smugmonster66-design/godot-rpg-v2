# res://editor_scripts/migrate_to_theme_variations.gd
# =============================================================================
# ONE-SHOT THEME MIGRATION — replaces hard-coded font sizes with
# theme_type_variation across scenes, presets, and scripts.
#
# Run: Editor → Script → Run (Ctrl+Shift+X)
#
# WHAT IT DOES (4 phases):
#   Phase 1: Patches .tscn scene files
#     - Inserts theme_type_variation on labels that lack one
#     - Replaces theme_override_font_sizes/font_size → theme_type_variation
#     - Removes LabelSettings sub-resources, converts to theme_type_variation
#       + per-node overrides preserving color, outline, shadow exactly
#     - Removes inline Theme sub-resource on player_menu AffixesContainer
#
#   Phase 2: Patches micro_animation_preset.gd
#     - Adds @export var label_theme_type: StringName = &""
#
#   Phase 3: Patches reactive_animator.gd
#     - Assigns ThemeManager.theme to _effects_container
#     - Updates _spawn_floating_label() to prefer label_theme_type
#
#   Phase 4: Patches micro preset .tres files
#     - Adds label_theme_type = &"xxx" to each preset with label_enabled
#
# SAFE TO RE-RUN: Checks for already-applied patches before writing.
# =============================================================================
@tool
extends EditorScript

var _patched: int = 0
var _skipped: int = 0
var _errors: int = 0


func _run() -> void:
	print("")
	print("=".repeat(60))
	print("  THEME MIGRATION — font sizes → theme_type_variation")
	print("=".repeat(60))

	# Phase 1: Scene files
	print("\n--- Phase 1: Scene Files (.tscn) ---")
	_patch_post_combat_summary()
	_patch_player_menu()
	_patch_dungeon_event_popup()
	_patch_dungeon_treasure_popup()
	_patch_dungeon_complete_popup()
	_patch_dungeon_rest_popup()
	_patch_dungeon_shop_popup()
	_patch_dungeon_shrine_popup()
	_patch_dungeon_scene()

	# Phase 2: MicroAnimationPreset script
	print("\n--- Phase 2: micro_animation_preset.gd ---")
	_patch_micro_animation_preset_script()

	# Phase 3: ReactiveAnimator script
	print("\n--- Phase 3: reactive_animator.gd ---")
	_patch_reactive_animator_script()

	# Phase 4: Preset .tres files
	print("\n--- Phase 4: Micro Preset .tres Files ---")
	_patch_micro_presets()

	# Summary
	print("\n" + "=".repeat(60))
	print("  DONE: %d patched, %d skipped, %d errors" % [_patched, _skipped, _errors])
	print("=".repeat(60))
	print("")
	print("MANUAL STEPS REMAINING:")
	print("  1. Open base_theme.tres in Theme Editor")
	print("  2. For EACH named size (normal, tiny, small, caption,")
	print("     large, title, header, display):")
	print("     - Select the type in the left panel")
	print("     - Set Base Type = Label")
	print("  3. Re-run generate_post_combat_summary_scene.gd")
	print("     (updated generator already uses theme_type_variation)")
	print("")


# =============================================================================
# PHASE 1: SCENE FILE PATCHES
# =============================================================================

# -----------------------------------------------------------------------------
# Post Combat Summary — live file has NO font_size overrides, so we INSERT
# theme_type_variation on each label that needs one.
# -----------------------------------------------------------------------------
func _patch_post_combat_summary() -> void:
	var path := "res://scenes/ui/popups/post_combat_summary.tscn"
	var text := _read(path)
	if text.is_empty():
		return

	# Map: node name → theme_type_variation to apply
	var node_map := {
		"TitleLabel": '&"header"',
		"XPIconLabel": '&"large"',
		"XPValueLabel": '&"large"',
		"LevelLabel": '&"caption"',
		"NextLevelLabel": '&"caption"',
		"LevelUpLabel": '&"large"',
		"GoldIconLabel": '&"large"',
		"GoldValueLabel": '&"large"',
		"LootHeader": '&"large"',
		"DetailNameLabel": '&"large"',
		"DetailSlotLabel": '&"caption"',
	}

	var changed := false
	for node_name in node_map:
		var variation: String = node_map[node_name]
		var result := _ensure_variation_on_label(text, node_name, variation)
		if result.changed:
			text = result.text
			changed = true

	if changed:
		_write(path, text)
	else:
		_skip(path, "all labels already have theme_type_variation")


# -----------------------------------------------------------------------------
# Player Menu — replace font_size overrides + remove inline Theme sub-resource
# -----------------------------------------------------------------------------
func _patch_player_menu() -> void:
	var path := "res://scenes/ui/menus/player_menu.tscn"
	var text := _read(path)
	if text.is_empty():
		return

	var changed := false

	# ItemName: font_size = 44 → title
	# This label appears in Inventory tab with the override, Equipment tab without.
	var result := _ensure_variation_on_label(text, "ItemName", '&"title"')
	if result.changed:
		text = result.text
		changed = true

	# SubtitleLabel: font_size = 24 → normal (Inventory tab only)
	result = _ensure_variation_on_label(text, "SubtitleLabel", '&"normal"')
	if result.changed:
		text = result.text
		changed = true

	# ItemDescription: font_size = 30 → large (Inventory tab only)
	result = _ensure_variation_on_label(text, "ItemDescription", '&"large"')
	if result.changed:
		text = result.text
		changed = true

	# Remove inline Theme sub-resource on AffixesContainer (default_font_size = 30)
	var theme_sub_regex := RegEx.new()
	theme_sub_regex.compile('\\[sub_resource type="Theme" id="([^"]+)"\\]\\ndefault_font_size = 30\\n')
	var theme_match := theme_sub_regex.search(text)
	if theme_match:
		var sub_id: String = theme_match.get_string(1)
		# Remove the sub_resource block
		text = text.replace(theme_match.get_string(), "")
		# Remove the theme = SubResource("...") reference on the node
		text = text.replace('theme = SubResource("%s")\n' % sub_id, "")
		# Decrement load_steps
		text = _decrement_load_steps(text, 1)
		changed = true

	if changed:
		_write(path, text)
	else:
		_skip(path, "no matching patterns found or already migrated")


# -----------------------------------------------------------------------------
# Dungeon Popups — remove LabelSettings, preserve ALL visual properties
# -----------------------------------------------------------------------------
func _patch_dungeon_event_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_event_popup.tscn",
		"LabelSettings_title", '&"title"',
		{
			"font_color": "Color(1, 0.95, 0.8, 1)",
			"outline_size": 4,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 3),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)

func _patch_dungeon_treasure_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_treasure_popup.tscn",
		"LabelSettings_title", '&"title"',
		{
			"font_color": "Color(1, 0.85, 0.3, 1)",
			"outline_size": 4,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 3),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)

func _patch_dungeon_complete_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_complete_popup.tscn",
		"LabelSettings_title", '&"header"',
		{
			"font_color": "Color(1, 0.95, 0.6, 1)",
			"outline_size": 5,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 4),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)

func _patch_dungeon_rest_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_rest_popup.tscn",
		"LabelSettings_title", '&"title"',
		{
			"font_color": "Color(0.4, 0.85, 1, 1)",
			"outline_size": 4,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 3),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)

func _patch_dungeon_shop_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_shop_popup.tscn",
		"LabelSettings_title", '&"title"',
		{
			"font_color": "Color(0.95, 0.85, 0.4, 1)",
			"outline_size": 4,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 3),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)

func _patch_dungeon_shrine_popup() -> void:
	_patch_label_settings_popup(
		"res://scenes/dungeon/popups/dungeon_shrine_popup.tscn",
		"LabelSettings_title", '&"title"',
		{
			"font_color": "Color(0.8, 0.5, 1, 1)",
			"outline_size": 4,
			"outline_color": "Color(0, 0, 0, 0.9)",
			"shadow_offset": Vector2(2, 3),
			"shadow_color": "Color(0, 0, 0, 0.6)",
		}
	)


# -----------------------------------------------------------------------------
# Dungeon Scene — FloorLabel + DungeonNameLabel LabelSettings removal
# -----------------------------------------------------------------------------
func _patch_dungeon_scene() -> void:
	var path := "res://scenes/dungeon/dungeon_scene.tscn"
	var text := _read(path)
	if text.is_empty():
		return
	if "LabelSettings" not in text:
		_skip(path, "no LabelSettings found (already migrated)")
		return

	var subs_removed := 0

	# --- FloorLabel: LabelSettings_floor ---
	# Original: font_size=18, outline_size=3, outline_color=(0,0,0,0.9),
	#           shadow_size=2, shadow_color=(0,0,0,0.6), shadow_offset=(1,2)
	var floor_result := _remove_label_settings_block(text, "LabelSettings_floor")
	if floor_result.changed:
		text = floor_result.text
		subs_removed += 1
		var old_ref := 'label_settings = SubResource("LabelSettings_floor")'
		var new_ref := 'theme_type_variation = &"normal"\n' + \
			'theme_override_constants/outline_size = 3\n' + \
			'theme_override_colors/font_outline_color = Color(0, 0, 0, 0.9)\n' + \
			'theme_override_constants/shadow_offset_x = 1\n' + \
			'theme_override_constants/shadow_offset_y = 2\n' + \
			'theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.6)'
		text = text.replace(old_ref, new_ref)

	# --- DungeonNameLabel: LabelSettings_name ---
	# Original: font_size=14, outline_size=2, outline_color=(0,0,0,0.8),
	#           shadow_color=(0,0,0,0.4) (no shadow_offset, no shadow_size)
	var name_result := _remove_label_settings_block(text, "LabelSettings_name")
	if name_result.changed:
		text = name_result.text
		subs_removed += 1
		var old_ref := 'label_settings = SubResource("LabelSettings_name")'
		var new_ref := 'theme_type_variation = &"caption"\n' + \
			'theme_override_constants/outline_size = 2\n' + \
			'theme_override_colors/font_outline_color = Color(0, 0, 0, 0.8)\n' + \
			'theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.4)'
		text = text.replace(old_ref, new_ref)

	if subs_removed > 0:
		text = _decrement_load_steps(text, subs_removed)
		_write(path, text)
	else:
		_skip(path, "LabelSettings blocks not found by ID")


# =============================================================================
# PHASE 2: MICRO ANIMATION PRESET SCRIPT
# =============================================================================

func _patch_micro_animation_preset_script() -> void:
	var path := "res://resources/data/micro_animation_preset.gd"
	var text := _read(path)
	if text.is_empty():
		return
	if "label_theme_type" in text:
		_skip(path, "label_theme_type already exists")
		return

	# Insert new export AFTER label_font_size line
	var anchor := "@export var label_font_size: int = 24"
	if anchor not in text:
		anchor = "@export var label_font_size"
		if anchor not in text:
			_error(path, "cannot find label_font_size export to insert after")
			return

	var idx := text.find(anchor)
	var line_end := text.find("\n", idx)

	var new_export := '\n\n## Theme type variation for the floating label (e.g. &"normal", &"display").\n' + \
		'## When set (non-empty), overrides label_font_size with the theme\'s value.\n' + \
		'@export var label_theme_type: StringName = &""'

	text = text.insert(line_end, new_export)
	_write(path, text)


# =============================================================================
# PHASE 3: REACTIVE ANIMATOR SCRIPT
# =============================================================================

func _patch_reactive_animator_script() -> void:
	var path := "res://resources/data/reactive_animator.gd"
	var text := _read(path)
	if text.is_empty():
		return

	var changed := false

	# --- 3a: Assign theme to _effects_container ---
	var container_anchor := '_effects_layer.add_child(_effects_container)'
	if container_anchor in text and "ThemeManager" not in text:
		text = text.replace(
			container_anchor,
			"# Assign theme so floating labels can resolve theme_type_variation\n" +
			"\tif ThemeManager and ThemeManager.theme:\n" +
			"\t\t_effects_container.theme = ThemeManager.theme\n" +
			"\t" + container_anchor
		)
		changed = true

	# --- 3b: Update _spawn_floating_label to prefer label_theme_type ---
	var old_font_block := '\tlabel.add_theme_font_size_override("font_size", preset.label_font_size)\n' + \
		'\tif preset.label_bold:\n' + \
		'\t\t# Use default bold font if available, otherwise just size up\n' + \
		'\t\tlabel.add_theme_font_size_override("font_size", preset.label_font_size + 2)'

	var new_font_block := '\t# Prefer theme_type_variation when set, fall back to raw font_size\n' + \
		'\tif preset.label_theme_type != &"":\n' + \
		'\t\tlabel.theme_type_variation = preset.label_theme_type\n' + \
		'\telse:\n' + \
		'\t\tlabel.add_theme_font_size_override("font_size", preset.label_font_size)\n' + \
		'\tif preset.label_bold and preset.label_theme_type == &"":\n' + \
		'\t\tlabel.add_theme_font_size_override("font_size", preset.label_font_size + 2)'

	if old_font_block in text:
		text = text.replace(old_font_block, new_font_block)
		changed = true
	elif "preset.label_theme_type" in text:
		_skip(path, "_spawn_floating_label already uses label_theme_type")
	else:
		_error(path, "could not find expected font block in _spawn_floating_label")

	if changed:
		_write(path, text)


# =============================================================================
# PHASE 4: MICRO PRESET .tres FILES
# =============================================================================

func _patch_micro_presets() -> void:
	# Map: filename → label_theme_type to add
	# Only presets with label_enabled = true need this
	var preset_map := {
		"die_value_grew.tres": '&"large"',
		"die_value_shrunk.tres": '&"normal"',
		"damage_dealt.tres": '&"large"',
		"crit_hit.tres": '&"display"',
		"heal_applied.tres": '&"normal"',
		"status_applied.tres": '&"normal"',
		"status_ticked.tres": '&"normal"',
		"shield_gained.tres": '&"normal"',
		"shield_broken.tres": '&"normal"',
		"mana_gained.tres": '&"normal"',
	}

	var base_dir := "res://resources/effects/micro_presets/"

	for filename in preset_map:
		var path: String = base_dir + filename
		var text := _read(path)
		if text.is_empty():
			continue
		if "label_theme_type" in text:
			_skip(path, "label_theme_type already set")
			continue
		if "label_enabled = true" not in text:
			_skip(path, "label_enabled not true, skipping")
			continue

		# Insert label_theme_type after label_font_size line (or label_color if
		# font_size uses default and isn't explicitly in the .tres)
		var variation: String = preset_map[filename]
		var anchor_idx := text.find("label_font_size = ")
		if anchor_idx == -1:
			# font_size might be at default (24) and omitted — try label_color
			anchor_idx = text.find("label_color = ")
			if anchor_idx == -1:
				# Last resort: after label_enabled
				anchor_idx = text.find("label_enabled = true")
				if anchor_idx == -1:
					_error(path, "no label anchor line found")
					continue

		var line_end := text.find("\n", anchor_idx)
		var insert_line := "\nlabel_theme_type = %s" % variation
		text = text.insert(line_end, insert_line)
		_write(path, text)


# =============================================================================
# HELPERS — Label Settings Removal (with full visual property preservation)
# =============================================================================

func _patch_label_settings_popup(path: String, settings_id: String,
		variation: String, visuals: Dictionary) -> void:
	"""Remove a LabelSettings sub-resource and replace with theme_type_variation
	plus per-node overrides that preserve color, outline, and shadow exactly."""
	var text := _read(path)
	if text.is_empty():
		return
	if settings_id not in text:
		_skip(path, "LabelSettings '%s' not found (already migrated)" % settings_id)
		return

	# 1. Remove the [sub_resource] block
	var result := _remove_label_settings_block(text, settings_id)
	if not result.changed:
		_error(path, "could not remove LabelSettings block '%s'" % settings_id)
		return
	text = result.text

	# 2. Build replacement: theme_type_variation + all visual overrides
	var old_ref := 'label_settings = SubResource("%s")' % settings_id
	if old_ref not in text:
		_error(path, "label_settings reference not found for '%s'" % settings_id)
		return

	var lines: PackedStringArray = []
	lines.append("theme_type_variation = %s" % variation)

	# Font color
	if visuals.has("font_color"):
		lines.append("theme_override_colors/font_color = %s" % visuals["font_color"])

	# Outline
	if visuals.has("outline_size"):
		lines.append("theme_override_constants/outline_size = %d" % visuals["outline_size"])
	if visuals.has("outline_color"):
		lines.append("theme_override_colors/font_outline_color = %s" % visuals["outline_color"])

	# Shadow
	if visuals.has("shadow_offset"):
		var offset: Vector2 = visuals["shadow_offset"]
		lines.append("theme_override_constants/shadow_offset_x = %d" % int(offset.x))
		lines.append("theme_override_constants/shadow_offset_y = %d" % int(offset.y))
	if visuals.has("shadow_color"):
		lines.append("theme_override_colors/font_shadow_color = %s" % visuals["shadow_color"])

	text = text.replace(old_ref, "\n".join(lines))

	# 3. Decrement load_steps
	text = _decrement_load_steps(text, 1)

	_write(path, text)


func _remove_label_settings_block(text: String, block_id: String) -> Dictionary:
	"""Remove a [sub_resource type="LabelSettings" id="..."] block.
	Returns {text: String, changed: bool}."""
	var header := '[sub_resource type="LabelSettings" id="%s"]' % block_id
	var start := text.find(header)
	if start == -1:
		return {"text": text, "changed": false}

	# Find end of block — next [sub_resource], [node], [resource], or [ext_resource]
	var search_from := start + header.length()
	var end := text.length()
	for marker in ["[sub_resource", "[node", "[resource]", "[ext_resource"]:
		var pos := text.find(marker, search_from)
		if pos != -1 and pos < end:
			end = pos

	# Include any leading blank line
	if start > 0 and text[start - 1] == "\n":
		start -= 1

	text = text.substr(0, start) + text.substr(end)
	return {"text": text, "changed": true}


# =============================================================================
# HELPERS — Insert / Replace theme_type_variation on Label nodes
# =============================================================================

func _ensure_variation_on_label(text: String, node_name: String,
		variation: String) -> Dictionary:
	"""For ALL Label nodes with node_name, ensure they have theme_type_variation.
	- If it has theme_override_font_sizes/font_size: replace that line.
	- If it already has theme_type_variation: skip.
	- Otherwise: insert after layout_mode line.
	Processes every match (handles duplicate node names across tabs).
	Returns {text: String, changed: bool}."""

	var header_pattern := '[node name="%s"' % node_name
	var changed := false
	var search_from := 0

	while true:
		var header_idx := text.find(header_pattern, search_from)
		if header_idx == -1:
			break

		# Find the end of this node's property block (next [node or EOF)
		var next_node := text.find("\n[node ", header_idx + 1)
		if next_node == -1:
			next_node = text.length()
		var block := text.substr(header_idx, next_node - header_idx)

		# Already has theme_type_variation? Skip this instance.
		if "theme_type_variation" in block:
			search_from = next_node
			continue

		# Has font_size override? Replace it.
		var override_key := "theme_override_font_sizes/font_size"
		var override_idx := block.find(override_key)
		if override_idx != -1:
			var abs_idx := header_idx + override_idx
			var line_end := text.find("\n", abs_idx)
			if line_end == -1:
				line_end = text.length()
			text = text.substr(0, abs_idx) + \
				"theme_type_variation = %s" % variation + \
				text.substr(line_end)
			changed = true
			# After replacement, text shifted — advance past this node
			search_from = abs_idx + 40
			continue

		# No font_size override — insert after layout_mode line
		var layout_idx := block.find("layout_mode = ")
		if layout_idx != -1:
			var abs_layout := header_idx + layout_idx
			var layout_line_end := text.find("\n", abs_layout)
			if layout_line_end != -1:
				var insert_text := "theme_type_variation = %s\n" % variation
				text = text.insert(layout_line_end + 1, insert_text)
				changed = true
				search_from = layout_line_end + insert_text.length() + 1
				continue

		# Fallback: couldn't process this node, skip it
		search_from = next_node

	return {"text": text, "changed": changed}


# =============================================================================
# HELPERS — Generic Text Operations
# =============================================================================

func _decrement_load_steps(text: String, by: int) -> String:
	"""Reduce load_steps in a .tscn header by N."""
	var regex := RegEx.new()
	regex.compile("load_steps=(\\d+)")
	var m := regex.search(text)
	if m:
		var old_val := int(m.get_string(1))
		var new_val := old_val - by
		text = text.replace(
			"load_steps=%d" % old_val,
			"load_steps=%d" % new_val
		)
	return text


# =============================================================================
# FILE I/O + LOGGING
# =============================================================================

func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		_error(path, "file not found")
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		_error(path, "cannot open for reading")
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		_error(path, "cannot open for writing")
		return
	f.store_string(text)
	f.close()
	_patched += 1
	print("  [OK] %s" % path.get_file())


func _skip(path: String, reason: String) -> void:
	_skipped += 1
	print("  [SKIP] %s — %s" % [path.get_file(), reason])


func _error(path: String, msg: String) -> void:
	_errors += 1
	push_error("  [ERR] %s — %s" % [path.get_file(), msg])
