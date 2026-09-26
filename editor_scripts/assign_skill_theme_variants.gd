@tool
extends EditorScript

## Loads all SkillResource .tres files under res://resources/skills/classes/mage/,
## reads their skill_category in memory, then patches the .tres text file directly
## to ensure skill_category is explicitly serialized.
## Does NOT use ResourceSaver (avoids crashes from complex sub_resources).

const CATEGORY_NAMES := {
	0: "PASSIVE",
	1: "TRIGGER",
	2: "ACTION",
	3: "SIGNATURE",
	4: "WEAVE",
	5: "CAPSTONE",
}

func _run() -> void:
	var base_dir := "res://resources/skills/classes/mage/"
	var count := 0
	var updated := 0

	for subfolder in ["flame", "frost", "storm"]:
		var dir_path: String = base_dir + subfolder + "/"
		var dir := DirAccess.open(dir_path)
		if not dir:
			print("Could not open: %s" % dir_path)
			continue

		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = dir_path + file_name
				var skill := load(full_path) as SkillResource
				if skill:
					count += 1
					var cat: int = skill.skill_category
					var cat_name: String = CATEGORY_NAMES.get(cat, "UNKNOWN")
					print("  %s -> %s (%d)" % [skill.skill_id, cat_name, cat])
					if _patch_tres_file(full_path, cat):
						updated += 1
			file_name = dir.get_next()

	print("\nProcessed %d skills, patched %d files." % [count, updated])


func _patch_tres_file(path: String, category: int) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		print("    Could not read: %s" % abs_path)
		return false
	var text := file.get_as_text()
	file.close()

	var lines := text.split("\n")
	var result: Array[String] = []
	var found_main_resource := false
	var patched := false
	var category_line := "skill_category = %d" % category

	for i in range(lines.size()):
		var line: String = lines[i]

		# Find the LAST [resource] section (the main one, not sub_resources)
		if line.strip_edges() == "[resource]":
			found_main_resource = true

		# If we're in the main [resource] section and find existing skill_category, replace it
		if found_main_resource and not patched and line.strip_edges().begins_with("skill_category"):
			if category == 0:
				# Already default, but write it explicitly
				result.append(category_line)
			else:
				result.append(category_line)
			patched = true
			continue

		# Insert skill_category after skill_id line if we haven't patched yet
		if found_main_resource and not patched and line.strip_edges().begins_with("skill_name"):
			result.append(line)
			result.append(category_line)
			patched = true
			continue

		result.append(line)

	if not patched and found_main_resource:
		# Fallback: append at end
		result.append(category_line)
		patched = true

	if patched:
		var out := FileAccess.open(abs_path, FileAccess.WRITE)
		if not out:
			print("    Could not write: %s" % abs_path)
			return false
		out.store_string("\n".join(result))
		out.close()
		return true

	return false
