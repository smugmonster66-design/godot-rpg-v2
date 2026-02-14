class_name DungeonEnums

enum NodeType {
	START,
	COMBAT,
	ELITE,
	BOSS,
	SHOP,
	REST,
	EVENT,
	TREASURE,
	SHRINE,
}

## Icon texture path per node type — loaded by DungeonDoor scene
static func get_node_icon_path(type: NodeType) -> String:
	match type:
		NodeType.START: return "res://assets/dungeon/icons/start.png"
		NodeType.COMBAT: return "res://assets/dungeon/icons/combat.png"
		NodeType.ELITE: return "res://assets/dungeon/icons/elite.png"
		NodeType.BOSS: return "res://assets/dungeon/icons/boss.png"
		NodeType.SHOP: return "res://assets/dungeon/icons/shop.png"
		NodeType.REST: return "res://assets/dungeon/icons/rest.png"
		NodeType.EVENT: return "res://assets/dungeon/icons/event.png"
		NodeType.TREASURE: return "res://assets/dungeon/icons/treasure.png"
		NodeType.SHRINE: return "res://assets/dungeon/icons/shrine.png"
		_: return ""

## Display color per node type (door tint, label color, debug)
static func get_node_color(type: NodeType) -> Color:
	match type:
		NodeType.START: return Color(0.3, 0.8, 0.3)
		NodeType.COMBAT: return Color(0.8, 0.3, 0.3)
		NodeType.ELITE: return Color(0.9, 0.5, 0.1)
		NodeType.BOSS: return Color(0.8, 0.1, 0.1)
		NodeType.SHOP: return Color(0.9, 0.8, 0.2)
		NodeType.REST: return Color(0.2, 0.6, 0.9)
		NodeType.EVENT: return Color(0.6, 0.4, 0.8)
		NodeType.TREASURE: return Color(1.0, 0.85, 0.0)
		NodeType.SHRINE: return Color(0.4, 0.8, 0.8)
		_: return Color.WHITE

static func get_node_type_name(type: NodeType) -> String:
	match type:
		NodeType.START: return "Entrance"
		NodeType.COMBAT: return "Combat"
		NodeType.ELITE: return "Elite"
		NodeType.BOSS: return "Boss"
		NodeType.SHOP: return "Shop"
		NodeType.REST: return "Rest"
		NodeType.EVENT: return "Event"
		NodeType.TREASURE: return "Treasure"
		NodeType.SHRINE: return "Shrine"
		_: return "Unknown"
