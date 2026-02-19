@tool
extends EditorScript

const PLACEHOLDER_PATH := "res://assets/characters/enemies/test_dummy_512.png"
const ENEMY_DIR := "res://resources/enemies/baseline"

func _run():
	print("── Stamping placeholder texture ──")

	var tex = load(PLACEHOLDER_PATH)
	if not tex:
		push_error("Texture not found: %s" % PLACEHOLDER_PATH)
		return
	print("  Texture loaded OK")

	var count := 0
	for tier in ["trash", "elite", "mini_boss", "boss", "world_boss"]:
		var dir_path = "%s/%s" % [ENEMY_DIR, tier]
		var dir = DirAccess.open(dir_path)
		if not dir:
			print("  Skipping %s (not found)" % tier)
			continue

		# Collect filenames first, then process (avoids iterator issues)
		var files: Array[String] = []
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.ends_with(".tres"):
				files.append(file)
			file = dir.get_next()
		dir.list_dir_end()

		print("  %s: %d files" % [tier, files.size()])
		for f in files:
			var path = "%s/%s" % [dir_path, f]
			var enemy = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if enemy and enemy is EnemyData:
				enemy.sprite_texture = tex
				enemy.portrait = tex
				ResourceSaver.save(enemy, path)
				count += 1
				print("    %s" % f)

	print("  Done: %d enemies stamped" % count)
