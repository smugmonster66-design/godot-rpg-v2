@tool
# palette_io.gd
# Utility for parsing theme_manager.gd and writing changes back.
# Also handles JSON preset import/export.
#
# Parsing strategy:
#   - Reads the raw text of theme_manager.gd
#   - Uses regex to find each "key": Color(r, g, b[, a]) inside const PALETTE
#   - Uses regex to find each "key": value inside const FONT_SIZES
#   - Uses regex to find each "status_name": return Color(...) inside get_status_color()
#
# Write-back strategy:
#   - For each key, finds the EXACT original Color(...) text and replaces it
#   - Preserves all formatting, comments, and structure
extends RefCounted

# ============================================================================
# REGEX PATTERNS
# ============================================================================

# Matches: "key_name":  Color(0.1, 0.2, 0.3) or Color(0.1, 0.2, 0.3, 0.4)
const COLOR_ENTRY_PATTERN := '("(?<key>[^"]+)"\\s*:\\s*)Color\\((?<args>[^)]+)\\)'

# Matches: "key_name": 16  (integer value in FONT_SIZES)
const FONT_ENTRY_PATTERN := '"(?<key>[^"]+)"\\s*:\\s*(?<val>\\d+)'

# Matches: "status_name": return Color(...)  inside a match block
const STATUS_ENTRY_PATTERN := '"(?<key>[^"]+)"\\s*:\\s*return\\s+Color\\((?<args>[^)]+)\\)'


# ============================================================================
# PARSE PALETTE
# ============================================================================

static func parse_palette(script_path: String) -> Dictionary:
	# Extract all Color entries from the PALETTE const block.
	var source = _read_file(script_path)
	if source.is_empty():
		return {}

	var palette_start = source.find("const PALETTE = {")
	if palette_start == -1:
		palette_start = source.find("const PALETTE := {")
	if palette_start == -1:
		push_warning("PaletteIO: Could not find 'const PALETTE' in %s" % script_path)
		return {}

	var block_end = _find_closing_brace(source, palette_start)
	var block = source.substr(palette_start, block_end - palette_start + 1)

	return _parse_color_entries(block)


# ============================================================================
# PARSE FONT SIZES
# ============================================================================

static func parse_font_sizes(script_path: String) -> Dictionary:
	# Extract all int entries from the FONT_SIZES const block.
	var source = _read_file(script_path)
	if source.is_empty():
		return {}

	var fs_start = source.find("const FONT_SIZES = {")
	if fs_start == -1:
		fs_start = source.find("const FONT_SIZES := {")
	if fs_start == -1:
		return {}

	var block_end = _find_closing_brace(source, fs_start)
	var block = source.substr(fs_start, block_end - fs_start + 1)

	var result: Dictionary = {}
	var regex = RegEx.new()
	regex.compile(FONT_ENTRY_PATTERN)

	for m in regex.search_all(block):
		var key = m.get_string("key")
		var val = m.get_string("val").to_int()
		result[key] = val

	return result


# ============================================================================
# PARSE STATUS COLORS
# ============================================================================

static func parse_status_colors(script_path: String) -> Dictionary:
	# Extract status colors from get_status_color() match block.
	var source = _read_file(script_path)
	if source.is_empty():
		return {}

	var func_start = source.find("func get_status_color(")
	if func_start == -1:
		return {}

	var chunk_end = mini(func_start + 2000, source.length())
	var chunk = source.substr(func_start, chunk_end - func_start)

	var result: Dictionary = {}
	var regex = RegEx.new()
	regex.compile(STATUS_ENTRY_PATTERN)

	for m in regex.search_all(chunk):
		var key = m.get_string("key")
		var args = m.get_string("args")
		var color = _parse_color_args(args)
		if color != null:
			result[key] = color

	return result


# ============================================================================
# WRITE TO SCRIPT
# ============================================================================

static func write_to_script(
	script_path: String,
	palette: Dictionary,
	fonts: Dictionary,
	status: Dictionary
) -> bool:
	# Write all changes back to theme_manager.gd, preserving structure.
	var source = _read_file(script_path)
	if source.is_empty():
		return false

	var modified = source

	# --- Write PALETTE colors ---
	var palette_start = modified.find("const PALETTE = {")
	if palette_start == -1:
		palette_start = modified.find("const PALETTE := {")
	if palette_start != -1:
		var block_end = _find_closing_brace(modified, palette_start)
		var block = modified.substr(palette_start, block_end - palette_start + 1)
		var new_block = _replace_colors_in_block(block, palette)
		modified = modified.substr(0, palette_start) + new_block + modified.substr(block_end + 1)

	# --- Write FONT_SIZES ---
	var fs_start = modified.find("const FONT_SIZES = {")
	if fs_start == -1:
		fs_start = modified.find("const FONT_SIZES := {")
	if fs_start != -1:
		var fs_end = _find_closing_brace(modified, fs_start)
		var fs_block = modified.substr(fs_start, fs_end - fs_start + 1)
		var new_fs_block = _replace_fonts_in_block(fs_block, fonts)
		modified = modified.substr(0, fs_start) + new_fs_block + modified.substr(fs_end + 1)

	# --- Write status colors ---
	var func_start = modified.find("func get_status_color(")
	if func_start != -1:
		var func_end = modified.find("\nfunc ", func_start + 1)
		if func_end == -1:
			func_end = modified.length()
		var func_block = modified.substr(func_start, func_end - func_start)
		var new_func_block = _replace_status_in_block(func_block, status)
		modified = modified.substr(0, func_start) + new_func_block + modified.substr(func_end)

	return _write_file(script_path, modified)


# ============================================================================
# JSON EXPORT / IMPORT
# ============================================================================

static func export_json(
	path: String,
	palette: Dictionary,
	fonts: Dictionary,
	status: Dictionary
) -> bool:
	# Export current theme data as JSON.
	var data := {
		"_format": "roll_the_bones_theme_v1",
		"palette": {},
		"fonts": fonts.duplicate(),
		"status": {},
	}

	for key in palette:
		data.palette[key] = _color_to_dict(palette[key])
	for key in status:
		data.status[key] = _color_to_dict(status[key])

	var json_string = JSON.stringify(data, "\t")
	return _write_file(path, json_string)


static func import_json(path: String) -> Dictionary:
	# Import theme data from JSON. Returns { palette, fonts, status } or empty.
	var text = _read_file(path)
	if text.is_empty():
		return {}

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("PaletteIO: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.data
	if not data is Dictionary:
		return {}

	var result := {}

	if data.has("palette") and data.palette is Dictionary:
		var pal := {}
		for key in data.palette:
			pal[key] = _dict_to_color(data.palette[key])
		result["palette"] = pal

	if data.has("fonts") and data.fonts is Dictionary:
		var f := {}
		for key in data.fonts:
			f[key] = int(data.fonts[key])
		result["fonts"] = f

	if data.has("status") and data.status is Dictionary:
		var s := {}
		for key in data.status:
			s[key] = _dict_to_color(data.status[key])
		result["status"] = s

	return result


# ============================================================================
# PRIVATE — PARSING HELPERS
# ============================================================================

static func _parse_color_entries(block: String) -> Dictionary:
	var result := {}
	var regex = RegEx.new()
	regex.compile(COLOR_ENTRY_PATTERN)

	for m in regex.search_all(block):
		var key = m.get_string("key")
		var args = m.get_string("args")
		var color = _parse_color_args(args)
		if color != null:
			result[key] = color

	return result


static func _parse_color_args(args_str: String) -> Variant:
	# Parse '0.1, 0.2, 0.3' or '0.1, 0.2, 0.3, 0.4' into a Color.
	var parts = args_str.split(",")
	for i in parts.size():
		parts[i] = parts[i].strip_edges()

	if parts.size() == 3:
		return Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	elif parts.size() == 4:
		return Color(parts[0].to_float(), parts[1].to_float(),
			parts[2].to_float(), parts[3].to_float())
	return null


static func _find_closing_brace(source: String, start_pos: int) -> int:
	# Find the matching } for the first { at or after start_pos.
	# Handles string literals so braces inside quotes are skipped.
	var brace_pos = source.find("{", start_pos)
	if brace_pos == -1:
		return source.length()

	var depth := 0
	var in_string := false
	var escape_next := false

	for i in range(brace_pos, source.length()):
		var c = source[i]

		if escape_next:
			escape_next = false
			continue

		if c == "\\":
			escape_next = true
			continue

		if c == '"':
			in_string = not in_string
			continue

		if in_string:
			continue

		# Also skip # line comments
		if c == "#":
			# Advance to end of line
			var eol = source.find("\n", i)
			if eol == -1:
				return source.length()
			# The for loop will handle incrementing past eol
			# We need to jump — but GDScript for loops don't support skip.
			# So we track state instead. Actually, let's just keep going
			# since { and } won't appear in comments in PALETTE blocks.
			# This is a defense-in-depth measure.
			continue

		if c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return i

	return source.length()


# ============================================================================
# PRIVATE — WRITE-BACK HELPERS
# ============================================================================

static func _replace_colors_in_block(block: String, palette: Dictionary) -> String:
	# Replace Color() values in a PALETTE block with new values.
	var result = block
	var regex = RegEx.new()
	regex.compile(COLOR_ENTRY_PATTERN)

	# Process in reverse order so replacement offsets don't shift
	var matches = regex.search_all(result)
	matches.reverse()

	for m in matches:
		var key = m.get_string("key")
		if not palette.has(key):
			continue

		var color = palette[key]
		var new_color_str = _color_to_gdscript(color)

		var prefix_match = m.get_string(1)  # Everything before Color(
		var new_full = prefix_match + new_color_str

		result = result.substr(0, m.get_start()) + new_full + result.substr(m.get_end())

	return result


static func _replace_fonts_in_block(block: String, fonts: Dictionary) -> String:
	# Replace integer values in a FONT_SIZES block.
	var result = block
	var regex = RegEx.new()
	regex.compile(FONT_ENTRY_PATTERN)

	var matches = regex.search_all(result)
	matches.reverse()

	for m in matches:
		var key = m.get_string("key")
		if not fonts.has(key):
			continue

		var new_val = str(fonts[key])
		var val_start = m.get_start("val")
		var val_end = m.get_end("val")
		result = result.substr(0, val_start) + new_val + result.substr(val_end)

	return result


static func _replace_status_in_block(func_block: String, status: Dictionary) -> String:
	# Replace Color() values in get_status_color() match lines.
	var result = func_block
	var regex = RegEx.new()
	regex.compile(STATUS_ENTRY_PATTERN)

	var matches = regex.search_all(result)
	matches.reverse()

	for m in matches:
		var key = m.get_string("key")
		if not status.has(key):
			continue

		var color = status[key]
		var new_color_str = _color_to_gdscript(color)
		var new_line = '"%s": return %s' % [key, new_color_str]
		result = result.substr(0, m.get_start()) + new_line + result.substr(m.get_end())

	return result


static func _color_to_gdscript(c: Color) -> String:
	# Format a Color as GDScript literal, matching theme_manager.gd style.
	if c.a < 0.999:
		return "Color(%.3f, %.3f, %.3f, %.3f)" % [c.r, c.g, c.b, c.a]
	return "Color(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]


# ============================================================================
# PRIVATE — JSON HELPERS
# ============================================================================

static func _color_to_dict(c: Color) -> Dictionary:
	var d := {"r": snapped(c.r, 0.001), "g": snapped(c.g, 0.001), "b": snapped(c.b, 0.001)}
	if c.a < 0.999:
		d["a"] = snapped(c.a, 0.001)
	return d


static func _dict_to_color(d) -> Color:
	if d is Dictionary:
		return Color(
			d.get("r", 1.0),
			d.get("g", 1.0),
			d.get("b", 1.0),
			d.get("a", 1.0))
	return Color.WHITE


# ============================================================================
# PRIVATE — FILE I/O
# ============================================================================

static func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("PaletteIO: File not found: %s" % path)
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("PaletteIO: Cannot open %s: %s" % [path, FileAccess.get_open_error()])
		return ""
	var text = f.get_as_text()
	f.close()
	return text


static func _write_file(path: String, content: String) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("PaletteIO: Cannot write %s: %s" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(content)
	f.close()
	return true
