@tool
extends RefCounted
## Collects state from the CompanionDetailPanel and builds a CompanionData resource.

const CompanionDataScript = preload("res://resources/data/companion_data.gd")

static func serialize(detail_panel, base: Resource = null) -> Resource:
	# Start from the resource being edited so fields this builder has no UI
	# for (Reaction, Bond ability, Dice-shaper effects, bond die, temperament,
	# Trail perk) survive a save. Only the builder's own fields are overwritten.
	var data = base.duplicate(false) if base is CompanionData else CompanionDataScript.new()

	# ======================================================================
	# IDENTITY
	# ======================================================================
	if detail_panel.companion_name_edit:
		data.companion_name = detail_panel.companion_name_edit.text.strip_edges()
	if detail_panel.companion_id_edit:
		data.companion_id = StringName(detail_panel.companion_id_edit.text.strip_edges())
	if detail_panel.description_edit:
		data.description = detail_panel.description_edit.text
	if detail_panel.action_name_edit:
		data.action_name = detail_panel.action_name_edit.text.strip_edges()
	if detail_panel.action_description_edit:
		data.action_description = detail_panel.action_description_edit.text

	# Portrait
	if detail_panel.portrait_preview and detail_panel.portrait_preview.texture:
		data.portrait = detail_panel.portrait_preview.texture

	# Type
	if detail_panel.companion_type_dropdown:
		data.companion_type = detail_panel.get_selected_id(detail_panel.companion_type_dropdown)

	# Synergy Tags
	if detail_panel.synergy_tags_edit:
		var raw = detail_panel.synergy_tags_edit.text.strip_edges()
		var typed_tags: Array[StringName] = []
		if raw != "":
			for tag in raw.split(","):
				var clean = tag.strip_edges()
				if clean != "":
					typed_tags.append(StringName(clean))
		data.synergy_tags = typed_tags

	# ======================================================================
	# HEALTH
	# ======================================================================
	if detail_panel.base_max_hp_spin:
		data.base_max_hp = int(detail_panel.base_max_hp_spin.value)
	if detail_panel.hp_scaling_dropdown:
		data.hp_scaling = detail_panel.get_selected_id(detail_panel.hp_scaling_dropdown)
	if detail_panel.hp_scaling_value_spin:
		data.hp_scaling_value = detail_panel.hp_scaling_value_spin.value

	# ======================================================================
	# TRIGGER
	# ======================================================================
	if detail_panel.trigger_dropdown:
		data.trigger = detail_panel.get_selected_id(detail_panel.trigger_dropdown)

	# Trigger data (threshold); other keys (e.g. min_percent) are kept
	var td: Dictionary = data.trigger_data.duplicate() if data.trigger_data is Dictionary else {}
	td.erase("threshold_percent")
	if int(data.trigger) == 4 and detail_panel.threshold_spin:  # PLAYER_DAMAGED_THRESHOLD
		td["threshold_percent"] = detail_panel.threshold_spin.value
	data.trigger_data = td

	# ======================================================================
	# TARGETING
	# ======================================================================
	if detail_panel.target_rule_dropdown:
		data.target_rule = detail_panel.get_selected_id(detail_panel.target_rule_dropdown)

	# ======================================================================
	# CONDITION
	# ======================================================================
	data.condition = detail_panel._condition_resource

	# ======================================================================
	# LIMITS
	# ======================================================================
	if detail_panel.cooldown_spin:
		data.cooldown_turns = int(detail_panel.cooldown_spin.value)
	if detail_panel.uses_per_combat_spin:
		data.uses_per_combat = int(detail_panel.uses_per_combat_spin.value)
	if detail_panel.fires_on_first_turn_check:
		data.fires_on_first_turn = detail_panel.fires_on_first_turn_check.button_pressed

	# ======================================================================
	# TAUNT
	# ======================================================================
	if detail_panel.has_taunt_check:
		data.has_taunt = detail_panel.has_taunt_check.button_pressed
	if detail_panel.taunt_duration_spin:
		data.taunt_duration = int(detail_panel.taunt_duration_spin.value)

	# ======================================================================
	# ACTION EFFECTS
	# ======================================================================
	var effects = detail_panel.get_effect_resources()
	var typed_effects: Array[ActionEffect] = []
	for e in effects:
		if e is ActionEffect:
			typed_effects.append(e)
	data.action_effects = typed_effects

	# ======================================================================
	# VISUALS
	# ======================================================================
	data.animation_set = detail_panel._visual_resources.get("animation_set")
	data.idle_animation = detail_panel._visual_resources.get("idle_animation")
	data.summon_enter_preset = detail_panel._visual_resources.get("summon_enter_preset")
	data.entry_emanate_preset = detail_panel._visual_resources.get("entry_emanate_preset")
	data.bark_set = detail_panel._visual_resources.get("bark_set")

	# ======================================================================
	# SUMMON
	# ======================================================================
	if detail_panel.duration_turns_spin:
		data.duration_turns = int(detail_panel.duration_turns_spin.value)

	return data
