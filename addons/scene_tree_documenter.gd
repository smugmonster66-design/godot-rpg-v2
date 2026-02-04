@tool
extends EditorScript

const OUTPUT_PATH = "res://SCENE_TREE.md"

func _run() -> void:
	var output = "# Complete Scene Tree Documentation\n"
	output += "Generated: " + Time.get_datetime_string_from_system() + "\n\n"
	
	# Get all scene files in the project
	var scenes = get_all_scenes()
	
	for scene_path in scenes:
		output += document_scene(scene_path)
	
	# Write to file
	var file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()
		print("Scene tree documentation generated at: ", OUTPUT_PATH)
	else:
		printerr("Failed to write documentation file")

func get_all_scenes() -> Array[String]:
	var scenes: Array[String] = []
	scan_directory("res://", scenes)
	return scenes

func scan_directory(path: String, scenes: Array[String]) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = path + "/" + file_name if path != "res://" else path + file_name
			
			if dir.current_is_dir():
				if not file_name.begins_with(".") and file_name != "addons":
					scan_directory(full_path, scenes)
			elif file_name.ends_with(".tscn"):
				scenes.append(full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

func document_scene(scene_path: String) -> String:
	var output = "## " + scene_path + "\n\n"
	
	var scene = load(scene_path)
	if not scene:
		output += "*Failed to load scene*\n\n"
		return output
	
	var root = scene.instantiate()
	if not root:
		output += "*Failed to instantiate scene*\n\n"
		return output
	
	output += "```\n"
	output += document_node(root, 0)
	output += "```\n\n"
	
	root.queue_free()
	return output

func document_node(node: Node, indent_level: int) -> String:
	var output = ""
	var indent = "  ".repeat(indent_level)
	
	# Node name and type
	output += indent + "├─ " + node.name + " (" + node.get_class() + ")\n"
	
	# Check if this is a packed scene instance
	var scene_file_path = node.scene_file_path
	if scene_file_path != "":
		output += indent + "   [Packed Scene: " + scene_file_path + "]\n"
		# Still document its children to show the full hierarchy
	
	# Document children
	for child in node.get_children():
		output += document_node(child, indent_level + 1)
	
	return output
