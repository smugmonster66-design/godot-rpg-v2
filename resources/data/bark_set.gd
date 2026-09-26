# res://resources/data/bark_set.gd
# A companion's personality bark collection.
# Defines how this companion reacts to game events with speech bubble barks.
# Attach to CompanionData.bark_set.
extends Resource
class_name BarkSet

## Default speaker for all barks in this set.
## Individual BarkEntries can override with their own speaker_id.
@export var speaker_id: StringName = &""

## This companion's personality reactions.
## Evaluated in order — first matching reaction wins.
@export var reactions: Array[BarkReaction] = []
