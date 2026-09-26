# res://resources/data/companion_dice_effect.gd
# A Dice-shaper effect: a companion works on the player's rolled hand.
# Used in CompanionData.dice_effects (Signature) and CompanionAbility.dice_effects.
extends Resource
class_name CompanionDiceEffect

enum Kind {
	RAISE,           ## +amount to `count` dice (capped at the die's max face)
	REROLL_MINIMUM,  ## reroll dice showing their minimum (the player's 1s)
	SET_MAX,         ## set `count` dice to their max face
	ADD_DIE,         ## add a temporary die to the hand (gone at the next roll)
}
enum Pick { LOWEST, HIGHEST, RANDOM }

@export var kind: Kind = Kind.RAISE
## RAISE: how much. 0 = the bond roll (bond die + stat bonus).
@export var amount: int = 0
## Which dice (RAISE, SET_MAX). Dice already at max are skipped.
@export var pick: Pick = Pick.LOWEST
## How many dice. REROLL_MINIMUM: 0 = every die showing its minimum.
@export var count: int = 1
## ADD_DIE: sides of the added die. 0 = the bond die's size.
@export var add_die_sides: int = 0
## ADD_DIE: the added die's element.
@export var add_die_element: DieResource.Element = DieResource.Element.NONE

const TEMP_DIE_TAG := "companion_temp"


static func die_max_face(die: DieResource) -> int:
	"""Highest value the die can show from its own roll (its top face plus its
	flat modifier, e.g. the stat bonus)."""
	return die.get_max_value() + die.modifier


func apply(pool: PlayerDiceCollection, bond_value: int, bond_sides: int, source_name: String = "") -> int:
	"""Apply to the pool's unconsumed hand. Returns how many dice changed."""
	if pool == null:
		return 0
	var hand: Array[DieResource] = pool.get_unconsumed_hand()
	var changed := 0
	match kind:
		Kind.RAISE:
			var add := amount if amount > 0 else maxi(1, bond_value)
			for die in _pick(hand, maxi(1, count), true):
				var cap := die_max_face(die)
				var new_val := mini(die.get_total_value() + add, cap)
				if new_val > die.get_total_value():
					die.modified_value = new_val
					changed += 1
		Kind.REROLL_MINIMUM:
			var n := 0
			for die in hand:
				if count > 0 and n >= count:
					break
				if die.current_value <= 1:
					die.roll()
					if pool.has_method("_finish_die_roll"):
						pool._finish_die_roll(die)
					n += 1
					changed += 1
		Kind.SET_MAX:
			for die in _pick(hand, maxi(1, count), true):
				die.set_value(die.get_max_value())
				changed += 1
		Kind.ADD_DIE:
			var sides := add_die_sides if add_die_sides > 0 else maxi(4, bond_sides)
			var die := DieResource.new(_die_type_for(sides), source_name if source_name != "" else "companion")
			die.element = add_die_element
			die.add_tag(TEMP_DIE_TAG)
			die.roll()
			pool.add_die_to_hand(die)
			changed += 1
	if changed > 0 and kind != Kind.ADD_DIE:
		pool.hand_changed.emit()
	return changed


func _pick(hand: Array[DieResource], n: int, skip_maxed: bool) -> Array[DieResource]:
	var candidates: Array[DieResource] = []
	for die in hand:
		if skip_maxed and die.get_total_value() >= die_max_face(die):
			continue
		candidates.append(die)
	match pick:
		Pick.LOWEST:
			candidates.sort_custom(func(a, b): return a.get_total_value() < b.get_total_value())
		Pick.HIGHEST:
			candidates.sort_custom(func(a, b): return a.get_total_value() > b.get_total_value())
		Pick.RANDOM:
			candidates.shuffle()
	return candidates.slice(0, n)


static func _die_type_for(sides: int) -> DieResource.DieType:
	for t in [4, 6, 8, 10, 12, 20]:
		if sides <= t:
			return t as DieResource.DieType
	return DieResource.DieType.D20
