# res://scripts/debug/test_dialogue.gd
# Quick test for the dialogue system.
# Call TestDialogue.launch_test() from anywhere.
extends RefCounted
class_name TestDialogue

static func launch_test() -> void:
	"""Launch a test dialogue encounter."""
	var encounter = _create_test_encounter()
	DialogueManager.start_dialogue(encounter)

static func _create_test_encounter() -> DialogueEncounter:
	# Create speakers
	var hilda = DialogueSpeaker.new()
	hilda.speaker_id = &"hilda"
	hilda.display_name = "Merchant Hilda"
	hilda.name_color = Color(0.9, 0.7, 0.3)
	
	var marcus = DialogueSpeaker.new()
	marcus.speaker_id = &"marcus"
	marcus.display_name = "Guard Marcus"
	marcus.name_color = Color(0.5, 0.6, 0.8)
	
	# Create ending lines first (work backwards)
	var end_weapons = DialogueLine.new()
	end_weapons.speaker_id = &"hilda"
	end_weapons.text = "Take a look around! I've got swords, daggers, and more."
	
	var end_rumors = DialogueLine.new()
	end_rumors.speaker_id = &"marcus"
	end_rumors.text = "I've heard strange [shake]noises[/shake] from the old ruins lately..."
	end_rumors.set_center_bust = &"marcus"
	
	var end_browse = DialogueLine.new()
	end_browse.speaker_id = &"hilda"
	end_browse.text = "Of course! Let me know if anything catches your eye."
	
	# Create choices
	var choice_weapons = DialogueChoice.new()
	choice_weapons.label = "Tell me about your weapons"
	choice_weapons.next_line = end_weapons
	
	var choice_rumors = DialogueChoice.new()
	choice_rumors.label = "Heard any rumors?"
	choice_rumors.next_line = end_rumors
	
	var choice_browse = DialogueChoice.new()
	choice_browse.label = "Just browsing"
	choice_browse.next_line = end_browse
	
	# First line with choices
	var first_line = DialogueLine.new()
	first_line.speaker_id = &"hilda"
	first_line.text = "Welcome to my shop, [wave]traveler[/wave]! What can I help you with today?"
	first_line.set_right_bust = &"hilda"
	first_line.choices = [choice_weapons, choice_rumors, choice_browse]
	
	# Create encounter
	var encounter = DialogueEncounter.new()
	encounter.encounter_id = &"test_dialogue"
	encounter.display_name = "Test Dialogue"
	encounter.speakers = [hilda, marcus]
	encounter.initial_right_bust = &"hilda"
	encounter.first_line = first_line
	encounter.show_dim_overlay = true
	encounter.dim_intensity = 0.4
	
	return encounter

static func launch_condition_test() -> void:
	"""Launch a test with conditions (requires progression system)."""
	var encounter = _create_condition_test_encounter()
	DialogueManager.start_dialogue(encounter)

static func _create_condition_test_encounter() -> DialogueEncounter:
	var npc = DialogueSpeaker.new()
	npc.speaker_id = &"gatekeeper"
	npc.display_name = "Gatekeeper"
	npc.name_color = Color(0.7, 0.5, 0.3)
	
	# Ending lines
	var end_pass = DialogueLine.new()
	end_pass.speaker_id = &"gatekeeper"
	end_pass.text = "Very well, you may pass. The king awaits."
	
	var end_bribe = DialogueLine.new()
	end_bribe.speaker_id = &"gatekeeper"
	end_bribe.text = "Hmm... your coin speaks louder than my duty. Go on through."
	
	var end_leave = DialogueLine.new()
	end_leave.speaker_id = &"gatekeeper"
	end_leave.text = "Come back when you have proper authorization."
	
	# Create condition for "has met the king" (requires GameCondition from progression system)
	var met_king_condition: Resource = null
	if ClassDB.class_exists("GameCondition"):
		met_king_condition = GameCondition.flag(&"met_king")
	
	var gold_condition: Resource = null
	if ClassDB.class_exists("GameCondition"):
		gold_condition = GameCondition.counter_at_least(&"gold", 100)
	
	# Choices
	var choice_king = DialogueChoice.new()
	choice_king.label = "The king sent for me"
	choice_king.next_line = end_pass
	choice_king.condition = met_king_condition  # Only shows if met_king flag is true
	choice_king.show_when_locked = true
	choice_king.locked_hint = "You haven't met the king yet"
	
	var choice_bribe = DialogueChoice.new()
	choice_bribe.label = "[100 Gold] Perhaps this will help..."
	choice_bribe.next_line = end_bribe
	choice_bribe.condition = gold_condition
	choice_bribe.show_when_locked = true
	choice_bribe.locked_hint = "Not enough gold"
	
	var choice_leave = DialogueChoice.new()
	choice_leave.label = "I'll come back later"
	choice_leave.next_line = end_leave
	
	var first_line = DialogueLine.new()
	first_line.speaker_id = &"gatekeeper"
	first_line.text = "Halt! None may pass without the king's permission."
	first_line.set_center_bust = &"gatekeeper"
	first_line.choices = [choice_king, choice_bribe, choice_leave]
	
	var encounter = DialogueEncounter.new()
	encounter.encounter_id = &"condition_test"
	encounter.display_name = "Condition Test"
	encounter.speakers = [npc]
	encounter.first_line = first_line
	encounter.show_dim_overlay = true
	
	return encounter
