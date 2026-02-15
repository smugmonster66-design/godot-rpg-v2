# res://editor_scripts/repair_dice_grant_tables.gd
# Fixes the granted_dice array type hint in utility table files.
# Changes: Array[ExtResource("uid://d3l85pyscg85h")] → Array[ExtResource("LOCAL_ID")]
# where LOCAL_ID is the die_resource.gd ext_resource id in that file.
#
# Also ensures blank line before each [sub_resource] block.
# Run once, then delete this script.
@tool
extends EditorScript

const TABLE_DIR := "res://resources/affix_tables/base/"
const TABLE_FILES := ["utility_tier_1.tres", "utility_tier_2.tres", "utility_tier_3.tres"]

func _run() -> void:
	print("══════════════════════════════════════════════════════")
	print("🔧  REPAIR DICE GRANT TABLE FILES")
	print("══════════════════════════════════════════════════════")

	for fname in TABLE_FILES:
		var path: String = TABLE_DIR + fname
		_repair_file(path)

	print("══════════════════════════════════════════════════════")


func _repair_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		print("  ⏭️ Not found: %s" % path)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		print("  ❌ Can't open: %s" % path)
		return
	var text := f.get_as_text()
	f.close()

	# Find the die_resource.gd ext_resource LOCAL id (not uid)
	# Line looks like: [ext_resource type="Script" uid="uid://d3l85pyscg85h" path="...die_resource.gd" id="2_20ugn"]
	var die_script_local_id := ""
	for line in text.split("\n"):
		if "[ext_resource" in line and "die_resource.gd" in line:
			# Extract the LAST id="..." on the line (the local one, not the uid)
			var last_id_pos := line.rfind(' id="')
			if last_id_pos != -1:
				var start := last_id_pos + 5  # len(' id="')
				var end := line.find('"', start)
				if end != -1:
					die_script_local_id = line.substr(start, end - start)
			break

	if die_script_local_id.is_empty():
		print("  ❌ No die_resource.gd ext_resource in: %s" % path.get_file())
		return

	print("  🔍 %s: die_resource.gd local id = \"%s\"" % [path.get_file(), die_script_local_id])

	# Replace the bad UID reference with the correct local id
	var bad_pattern := 'Array[ExtResource("uid://d3l85pyscg85h")]'
	var good_pattern := 'Array[ExtResource("%s")]' % die_script_local_id

	var count := text.count(bad_pattern)
	if count == 0:
		print("  ⏭️ No repairs needed: %s" % path.get_file())
		return

	text = text.replace(bad_pattern, good_pattern)

	# Ensure blank line between granted_dice and next [sub_resource]
	# Fix: "granted_dice = ...\n[sub_resource" → "granted_dice = ...\n\n[sub_resource"
	var lines := text.split("\n")
	var fixed_lines: PackedStringArray = PackedStringArray()
	for i in range(lines.size()):
		fixed_lines.append(lines[i])
		# If this line starts with "granted_dice" and the next is a [sub_resource or [resource
		if i + 1 < lines.size():
			var this_stripped := lines[i].strip_edges()
			var next_stripped := lines[i + 1].strip_edges()
			if this_stripped.begins_with("granted_dice") and (next_stripped.begins_with("[sub_resource") or next_stripped.begins_with("[resource]")):
				fixed_lines.append("")  # blank separator line

	text = "\n".join(fixed_lines)

	# Write back
	var fw := FileAccess.open(path, FileAccess.WRITE)
	if not fw:
		print("  ❌ Can't write: %s" % path)
		return
	fw.store_string(text)
	fw.close()

	print("  ✅ Fixed %d references in %s" % [count, path.get_file()])
