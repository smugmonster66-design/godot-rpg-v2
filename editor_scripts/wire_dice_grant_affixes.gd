# res://editor_scripts/wire_dice_grant_affixes.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# PURE TEXT MANIPULATION — no ResourceLoader.load() calls.
# Reads .tres files as text, injects ext_resource + granted_dice lines.
#
# REQUIRES: Run generate_base_dice.gd FIRST.
# SAFE TO RE-RUN: Skips files that already have granted_dice.
@tool
extends EditorScript

const BASE_DICE_DIR := "res://resources/dice/base/"
const STANDALONE_DIR := "res://resources/affixes/base/utility/"
const TABLE_DIR := "res://resources/affix_tables/base/"
const DIE_SCRIPT_UID := "uid://d3l85pyscg85h"  # die_resource.gd UID

# ============================================================================
# ENTRY POINT
# ============================================================================

var _wired_standalone := 0
var _wired_table := 0
var _skipped := 0
var _errors := 0
var _die_uid_cache := {}  # path → uid string (or "" if no uid)

func _run() -> void:
	print("══════════════════════════════════════════════════════")
	print("🔗  DICE GRANT WIRING — TEXT MODE (v5)")
	print("══════════════════════════════════════════════════════")

	# Phase 0: Cache base die UIDs
	_cache_base_die_uids()
	print("  📦 Cached %d base die UIDs" % _die_uid_cache.size())
	print("")

	# Phase 1: Standalone affix files
	print("── Phase 1: Standalone Affix Files ──")
	for tier_folder in ["tier_1", "tier_2", "tier_3"]:
		var dir_path: String = STANDALONE_DIR + tier_folder + "/"
		_process_standalone_dir(dir_path)

	# Phase 2: AffixTable files
	print("")
	print("── Phase 2: AffixTable Files (text edit) ──")
	for table_name in ["utility_tier_1", "utility_tier_2", "utility_tier_3"]:
		var table_path: String = TABLE_DIR + table_name + ".tres"
		_process_table_file(table_path)

	print("")
	print("══════════════════════════════════════════════════════")
	print("✅  Wired standalone: %d" % _wired_standalone)
	print("✅  Wired in tables:  %d" % _wired_table)
	print("⏭️  Skipped:          %d" % _skipped)
	if _errors > 0:
		print("❌  Errors:           %d" % _errors)
	print("══════════════════════════════════════════════════════")


# ============================================================================
# PHASE 0 — Read UIDs from base dice .tres files
# ============================================================================

func _cache_base_die_uids() -> void:
	var dir := DirAccess.open(BASE_DICE_DIR)
	if not dir:
		push_error("Cannot open %s" % BASE_DICE_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var path := BASE_DICE_DIR + fname
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				var header := f.get_line()
				f.close()
				var uid := _extract_uid(header)
				_die_uid_cache[path] = uid
		fname = dir.get_next()
	dir.list_dir_end()


func _extract_uid(header_line: String) -> String:
	var idx := header_line.find('uid="')
	if idx == -1:
		return ""
	var start := idx + 5
	var end := header_line.find('"', start)
	if end == -1:
		return ""
	return header_line.substr(start, end - start)


# ============================================================================
# PHASE 1 — Standalone affix .tres files
# ============================================================================

func _process_standalone_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		print("  ⚠️ Dir not found: %s" % dir_path)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and fname.begins_with("grant_"):
			_process_standalone_file(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _process_standalone_file(path: String) -> void:
	var text := _read_file(path)
	if text.is_empty():
		return

	if "granted_dice" in text:
		_skipped += 1
		return

	var affix_name := _extract_property(text, "affix_name")
	if affix_name.is_empty():
		_skipped += 1
		return

	var die_info := _parse_die_from_name(affix_name)
	if die_info.is_empty():
		print("  ⚠️ Can't parse die from: '%s'" % affix_name)
		_errors += 1
		return

	var die_path: String = die_info.path
	if not _die_uid_cache.has(die_path):
		print("  ⚠️ Base die not found: %s (for %s)" % [die_path, affix_name])
		_errors += 1
		return

	var die_script_id := _find_ext_resource_local_id(text, "die_resource.gd")
	if die_script_id.is_empty():
		print("  ⚠️ No die_resource.gd ext_resource in: %s" % path.get_file())
		_errors += 1
		return

	var new_ext_id := "die_ref"
	var die_uid: String = _die_uid_cache[die_path]
	var uid_part := ' uid="%s"' % die_uid if not die_uid.is_empty() else ""
	var new_ext_line := '[ext_resource type="Resource"%s path="%s" id="%s"]' % [uid_part, die_path, new_ext_id]

	var granted_line := 'granted_dice = Array[ExtResource("%s")]([ExtResource("%s")])' % [die_script_id, new_ext_id]

	text = _increment_load_steps(text)
	text = _insert_ext_resource(text, new_ext_line)
	text = _append_to_resource_section(text, granted_line)

	if _write_file(path, text):
		print("  🔗 %s → %s" % [path.get_file(), die_path.get_file()])
		_wired_standalone += 1
	else:
		_errors += 1


# ============================================================================
# PHASE 2 — AffixTable .tres files (text manipulation)
# ============================================================================

func _process_table_file(path: String) -> void:
	var text := _read_file(path)
	if text.is_empty():
		print("  ⚠️ Table not found: %s" % path)
		return

	var die_script_id := _find_ext_resource_local_id(text, "die_resource.gd")
	if die_script_id.is_empty():
		print("  ⚠️ No die_resource.gd in: %s" % path.get_file())
		return

	var lines := text.split("\n")
	var dice_grants := []

	var in_sub_resource := false
	var current_sub_end := -1
	var current_category := -1
	var current_has_dice_grant := false
	var current_affix_name := ""
	var current_has_granted_dice := false

	for i in range(lines.size()):
		var line := lines[i].strip_edges()

		if line.begins_with("[sub_resource"):
			if in_sub_resource and current_category == 32 and current_has_dice_grant and not current_has_granted_dice:
				var die_info := _parse_die_from_name(current_affix_name)
				if not die_info.is_empty() and _die_uid_cache.has(die_info.path):
					dice_grants.append({
						"affix_name": current_affix_name,
						"die_path": die_info.path,
						"insert_after_line": current_sub_end,
					})
			in_sub_resource = true
			current_sub_end = i
			current_category = -1
			current_has_dice_grant = false
			current_affix_name = ""
			current_has_granted_dice = false

		elif line.begins_with("[resource]"):
			if in_sub_resource and current_category == 32 and current_has_dice_grant and not current_has_granted_dice:
				var die_info := _parse_die_from_name(current_affix_name)
				if not die_info.is_empty() and _die_uid_cache.has(die_info.path):
					dice_grants.append({
						"affix_name": current_affix_name,
						"die_path": die_info.path,
						"insert_after_line": current_sub_end,
					})
			in_sub_resource = false

		elif in_sub_resource:
			current_sub_end = i
			if line.begins_with("category = "):
				current_category = int(line.get_slice("= ", 1))
			elif line.begins_with("affix_name = "):
				current_affix_name = line.get_slice('= "', 1).trim_suffix('"')
			elif "dice_grant" in line and "tags" in line:
				current_has_dice_grant = true
			elif line.begins_with("granted_dice"):
				current_has_granted_dice = true

	if dice_grants.is_empty():
		print("  ⏭️ No unwired dice grants in: %s" % path.get_file())
		return

	# Collect unique die paths needed
	var unique_dies := {}
	var ext_counter := 0
	for grant in dice_grants:
		if not unique_dies.has(grant.die_path):
			unique_dies[grant.die_path] = "die_%d" % ext_counter
			ext_counter += 1

	# Build new ext_resource lines
	var new_ext_lines := []
	for die_path in unique_dies:
		var ext_id: String = unique_dies[die_path]
		var die_uid: String = _die_uid_cache.get(die_path, "")
		var uid_part := ' uid="%s"' % die_uid if not die_uid.is_empty() else ""
		new_ext_lines.append('[ext_resource type="Resource"%s path="%s" id="%s"]' % [uid_part, die_path, ext_id])

	# Insert granted_dice lines (work backwards to preserve indices)
	dice_grants.sort_custom(func(a, b): return a.insert_after_line > b.insert_after_line)
	for grant in dice_grants:
		var ext_id: String = unique_dies[grant.die_path]
		var granted_line := 'granted_dice = Array[ExtResource("%s")]([ExtResource("%s")])' % [die_script_id, ext_id]
		lines.insert(grant.insert_after_line + 1, granted_line)
		print("  🔗 [table] %s → %s" % [grant.affix_name, grant.die_path.get_file()])
		_wired_table += 1

	# Insert new ext_resource lines after existing ones
	var insert_pos := _find_last_ext_resource_line(lines) + 1
	for j in range(new_ext_lines.size()):
		lines.insert(insert_pos + j, new_ext_lines[j])

	# Rebuild text and increment load_steps
	var new_text := "\n".join(lines)
	new_text = _increment_load_steps_by(new_text, new_ext_lines.size())

	if _write_file(path, new_text):
		print("  💾 Saved: %s (%d dice wired)" % [path.get_file(), dice_grants.size()])
	else:
		_errors += 1


# ============================================================================
# DIE NAME PARSING
# ============================================================================

func _parse_die_from_name(affix_name: String) -> Dictionary:
	var lower := affix_name.to_lower()

	var size_token := ""
	for s in ["d20", "d12", "d10", "d8", "d6", "d4"]:
		if s in lower:
			size_token = s
			break
	if size_token.is_empty():
		return {}

	var element_token := "none"
	if "neutral" in lower:
		element_token = "none"
	else:
		for elem in ["fire", "ice", "shock", "poison", "shadow", "slashing", "blunt", "piercing", "faith"]:
			if elem in lower:
				element_token = elem
				break

	var path := BASE_DICE_DIR + "%s_%s.tres" % [size_token, element_token]
	return {"size": size_token, "element": element_token, "path": path}


# ============================================================================
# TEXT MANIPULATION HELPERS
# ============================================================================

func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _write_file(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Cannot write: %s" % path)
		return false
	f.store_string(text)
	f.close()
	return true


func _extract_property(text: String, prop_name: String) -> String:
	var key := prop_name + ' = "'
	var idx := text.find(key)
	if idx == -1:
		return ""
	var start := idx + key.length()
	var end := text.find('"', start)
	if end == -1:
		return ""
	return text.substr(start, end - start)


func _find_ext_resource_local_id(text: String, script_filename: String) -> String:
	## Find the LOCAL ext_resource id for a script file.
	## Uses rfind(' id="') to skip past uid="..." and match only the trailing id attribute.
	for line in text.split("\n"):
		if "[ext_resource" in line and script_filename in line:
			var id_idx := line.rfind(' id="')
			if id_idx == -1:
				continue
			var start := id_idx + 5  # len(' id="')
			var end := line.find('"', start)
			if end == -1:
				continue
			return line.substr(start, end - start)
	return ""


func _increment_load_steps(text: String) -> String:
	return _increment_load_steps_by(text, 1)


func _increment_load_steps_by(text: String, amount: int) -> String:
	var re_start := text.find("load_steps=")
	if re_start == -1:
		return text
	var num_start := re_start + 11
	var num_end := num_start
	while num_end < text.length() and text[num_end].is_valid_int():
		num_end += 1
	var old_val := int(text.substr(num_start, num_end - num_start))
	var new_val := old_val + amount
	return text.substr(0, num_start) + str(new_val) + text.substr(num_end)


func _insert_ext_resource(text: String, new_line: String) -> String:
	var lines := text.split("\n")
	var insert_pos := _find_last_ext_resource_line(lines) + 1
	lines.insert(insert_pos, new_line)
	return "\n".join(lines)


func _find_last_ext_resource_line(lines) -> int:
	var last := -1
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("[ext_resource"):
			last = i
	return last


func _append_to_resource_section(text: String, new_line: String) -> String:
	var lines := text.split("\n")
	var resource_line := -1
	for i in range(lines.size()):
		if lines[i].strip_edges() == "[resource]":
			resource_line = i
			break
	if resource_line == -1:
		push_error("No [resource] section found")
		return text
	var insert_pos := lines.size() - 1
	while insert_pos > resource_line and lines[insert_pos].strip_edges().is_empty():
		insert_pos -= 1
	lines.insert(insert_pos + 1, new_line)
	return "\n".join(lines)
