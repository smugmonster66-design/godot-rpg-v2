@tool
extends EditorPlugin

func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Also inject into any ColorPickers already open
	_inject_into_existing(get_editor_interface().get_base_control())

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is ColorPicker:
		_inject_presets(node)

func _inject_into_existing(root: Node) -> void:
	for child in root.get_children():
		if child is ColorPicker:
			_inject_presets(child)
		if child.get_child_count() > 0:
			_inject_into_existing(child)

func _inject_presets(picker: ColorPicker) -> void:
	# Clear existing presets first to avoid duplicates on reload
	for c in picker.get_presets():
		picker.erase_preset(c)

	var colors := [
		Color(1.000, 0.000, 0.251),  # 01 #ff0040 hot red
		Color(0.075, 0.075, 0.075),  # 02 #131313 near black
		Color(0.106, 0.106, 0.106),  # 03 #1b1b1b dark grey 1
		Color(0.153, 0.153, 0.153),  # 04 #272727 dark grey 2
		Color(0.239, 0.239, 0.239),  # 05 #3d3d3d mid-dark grey
		Color(0.365, 0.365, 0.365),  # 06 #5d5d5d mid grey
		Color(0.522, 0.522, 0.522),  # 07 #858585 grey
		Color(0.706, 0.706, 0.706),  # 08 #b4b4b4 light grey
		Color(1.000, 1.000, 1.000),  # 09 #ffffff white
		Color(0.780, 0.812, 0.867),  # 10 #c7cfdd cool off-white
		Color(0.573, 0.631, 0.725),  # 11 #92a1b9 blue-grey
		Color(0.396, 0.451, 0.573),  # 12 #657392 steel blue
		Color(0.259, 0.298, 0.431),  # 13 #424c6e dark blue-grey
		Color(0.165, 0.184, 0.306),  # 14 #2a2f4e dark navy
		Color(0.102, 0.098, 0.196),  # 15 #1a1932 deep navy
		Color(0.055, 0.027, 0.106),  # 16 #0e071b near-black purple
		Color(0.110, 0.071, 0.110),  # 17 #1c121c dark plum
		Color(0.224, 0.122, 0.129),  # 18 #391f21 dark maroon
		Color(0.365, 0.173, 0.157),  # 19 #5d2c28 maroon
		Color(0.541, 0.282, 0.212),  # 20 #8a4836 sienna
		Color(0.749, 0.435, 0.290),  # 21 #bf6f4a warm brown
		Color(0.902, 0.612, 0.412),  # 22 #e69c69 tan
		Color(0.965, 0.792, 0.624),  # 23 #f6ca9f pale skin
		Color(0.976, 0.902, 0.816),  # 24 #f9e6cf lightest skin
		Color(0.929, 0.671, 0.314),  # 25 #edab50 amber
		Color(0.878, 0.455, 0.220),  # 26 #e07438 burnt orange
		Color(0.776, 0.271, 0.141),  # 27 #c64524 deep orange
		Color(0.557, 0.145, 0.114),  # 28 #8e251d dark red-brown
		Color(1.000, 0.314, 0.000),  # 29 #ff5000 fire orange
		Color(0.929, 0.463, 0.078),  # 30 #ed7614 orange
		Color(1.000, 0.635, 0.078),  # 31 #ffa214 amber-gold
		Color(1.000, 0.784, 0.145),  # 32 #ffc825 warm yellow
		Color(1.000, 0.922, 0.341),  # 33 #ffeb57 bright yellow
		Color(0.827, 0.988, 0.494),  # 34 #d3fc7e yellow-green
		Color(0.600, 0.902, 0.373),  # 35 #99e65f lime green
		Color(0.353, 0.773, 0.310),  # 36 #5ac54f mid green
		Color(0.200, 0.596, 0.294),  # 37 #33984b forest green
		Color(0.118, 0.435, 0.314),  # 38 #1e6f50 deep green
		Color(0.078, 0.298, 0.298),  # 39 #134c4c dark teal
		Color(0.047, 0.180, 0.267),  # 40 #0c2e44 dark blue-teal
		Color(0.000, 0.224, 0.427),  # 41 #00396d deep blue
		Color(0.000, 0.412, 0.667),  # 42 #0069aa ocean blue
		Color(0.000, 0.596, 0.863),  # 43 #0098dc sky blue
		Color(0.000, 0.804, 0.976),  # 44 #00cdf9 bright cyan
		Color(0.047, 0.945, 1.000),  # 45 #0cf1ff icy cyan
		Color(0.580, 0.992, 1.000),  # 46 #94fdff pale frost
		Color(0.992, 0.824, 0.929),  # 47 #fdd2ed pale pink
		Color(0.953, 0.537, 0.961),  # 48 #f389f5 hot pink
		Color(0.859, 0.247, 0.992),  # 49 #db3ffd electric violet
		Color(0.478, 0.035, 0.980),  # 50 #7a09fa deep violet
		Color(0.188, 0.012, 0.851),  # 51 #3003d9 indigo
		Color(0.047, 0.008, 0.576),  # 52 #0c0293 deep indigo
		Color(0.012, 0.098, 0.247),  # 53 #03193f midnight
		Color(0.231, 0.078, 0.263),  # 54 #3b1443 dark purple
		Color(0.384, 0.141, 0.380),  # 55 #622461 void purple
		Color(0.576, 0.220, 0.561),  # 56 #93388f drained purple
		Color(0.792, 0.322, 0.788),  # 57 #ca52c9 bright purple
		Color(0.784, 0.314, 0.525),  # 58 #c85086 rose purple
		Color(0.965, 0.506, 0.529),  # 59 #f68187 soft red-pink
		Color(0.961, 0.333, 0.365),  # 60 #f5555d coral red
		Color(0.918, 0.196, 0.235),  # 61 #ea323c danger red
		Color(0.769, 0.141, 0.188),  # 62 #c42430 blood red
		Color(0.537, 0.118, 0.169),  # 63 #891e2b dark crimson
		Color(0.341, 0.110, 0.153),  # 64 #571c27 deepest crimson
	]
	for c in colors:
		picker.add_preset(c)
