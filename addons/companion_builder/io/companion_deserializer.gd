@tool
extends RefCounted
## Populates the CompanionDetailPanel controls from a loaded CompanionData resource.

static func deserialize(data: Resource, detail_panel) -> void:
	if not data or not detail_panel:
		return
	detail_panel.load_companion(data)
