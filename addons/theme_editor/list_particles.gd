@tool
extends EditorScript

func _run():
	var base_path = "res://assets/particles"
	var results: Array[String] = []
	_scan_dir(base_path, results)
	results.sort()
	for path in results:
		print(path)
	print("--- Total: %d files ---" % results.size())

func _scan_dir(path: String, results: Array[String]):
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("Could not open: %s" % path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path = path + "/" + entry
		if dir.current_is_dir():
			_scan_dir(full_path, results)
		else:
			if entry.ends_with(".png") or entry.ends_with(".jpg") or entry.ends_with(".webp"):
				results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
