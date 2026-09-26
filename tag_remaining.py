#!/usr/bin/env python3
import os

BASE = "D:/Games/dice-rpg-game-2026-new"

def edit_file(rel_path, old_val, new_val):
    path = os.path.join(BASE, rel_path).replace("\\", "/")
    old_str = f'description = "{old_val}"'
    new_str = f'description = "{new_val}"'
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        if old_str in content:
            new_content = content.replace(old_str, new_str, 1)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"OK: {rel_path}")
        else:
            print(f"MISS: {old_val[:60]!r} in {rel_path}")
    except Exception as e:
        print(f"ERR {rel_path}: {e}")

remaining = [
    # visual effect affixes
    ("resources/dice_affixes/visual effect affixes/fire_dice_visualeffect_affix.tres",
     "Turns the die into fire damage.",
     "Turns the die into [element:fire] damage."),

    # flame dice affixes - fire element die references
    ("resources/dice_affixes/mage/flame/da_kindling_r1.tres",
     "Fire die adjacent to fire: +1 value.",
     "[element:fire] die adjacent to [element:fire]: +1 value."),
    ("resources/dice_affixes/mage/flame/da_kindling_r2.tres",
     "Fire die adjacent to fire: +2 value.",
     "[element:fire] die adjacent to [element:fire]: +2 value."),
    ("resources/dice_affixes/mage/flame/da_heat_shimmer_r1.tres",
     "Auto-reroll fire die below 2.",
     "Auto-reroll [element:fire] die below 2."),
    ("resources/dice_affixes/mage/flame/da_heat_shimmer_r2.tres",
     "Auto-reroll fire die below 3.",
     "Auto-reroll [element:fire] die below 3."),
    ("resources/dice_affixes/mage/flame/da_heat_shimmer_r3.tres",
     "Auto-reroll fire die below 4.",
     "Auto-reroll [element:fire] die below 4."),
    ("resources/dice_affixes/mage/flame/da_hearthfire_r1.tres",
     "Fire die next to non-fire: +2 value.",
     "[element:fire] die next to non-fire: +2 value."),
    ("resources/dice_affixes/mage/flame/da_hearthfire_r2.tres",
     "Fire die next to non-fire: +3 value.",
     "[element:fire] die next to non-fire: +3 value."),
    ("resources/dice_affixes/mage/flame/da_mana_flare_r1.tres",
     "Fire die at/below half max: refund 1 mana.",
     "[element:fire] die at/below half max: refund 1 mana."),
    ("resources/dice_affixes/mage/flame/da_mana_flare_r2.tres",
     "Fire die at/below half max: refund 2 mana.",
     "[element:fire] die at/below half max: refund 2 mana."),
    ("resources/dice_affixes/mage/flame/da_forge_bond_first.tres",
     "FIRST fire die: +25% damage.",
     "FIRST [element:fire] die: +25% damage."),
    ("resources/dice_affixes/mage/flame/da_forge_bond_last.tres",
     "LAST fire die: +25% damage.",
     "LAST [element:fire] die: +25% damage."),

    # storm dice affixes - shock element die references
    ("resources/dice_affixes/mage/storm/da_polarity_r1.tres",
     "Shock die +2 value if no adjacent shock.",
     "[element:shock] die +2 value if no adjacent [element:shock]."),
    ("resources/dice_affixes/mage/storm/da_polarity_r2.tres",
     "Shock die +3 value if no adjacent shock.",
     "[element:shock] die +3 value if no adjacent [element:shock]."),
    ("resources/dice_affixes/mage/storm/da_polarity_r3.tres",
     "Shock die +4 value if no adjacent shock.",
     "[element:shock] die +4 value if no adjacent [element:shock]."),

    # frost dice affixes - ice element die references
    ("resources/dice_affixes/mage/frost/da_rime_first_r1.tres",
     "First-position ice die +2 value.",
     "First-position [element:ice] die +2 value."),
    ("resources/dice_affixes/mage/frost/da_rime_first_r2.tres",
     "First-position ice die +3 value.",
     "First-position [element:ice] die +3 value."),
    ("resources/dice_affixes/mage/frost/da_permafrost_rune_r1.tres",
     "Adjacent ice dice: +1 value each.",
     "Adjacent [element:ice] dice: +1 value each."),
    ("resources/dice_affixes/mage/frost/da_permafrost_rune_r2.tres",
     "Adjacent ice dice: +2 value each.",
     "Adjacent [element:ice] dice: +2 value each."),
    ("resources/dice_affixes/mage/frost/da_glacial_clarity_r1.tres",
     "Auto-reroll ice die below 2.",
     "Auto-reroll [element:ice] die below 2."),
    ("resources/dice_affixes/mage/frost/da_glacial_clarity_r2.tres",
     "Auto-reroll ice die below 3.",
     "Auto-reroll [element:ice] die below 3."),
    ("resources/dice_affixes/mage/frost/da_glacial_clarity_r3.tres",
     "Auto-reroll ice die below 4.",
     "Auto-reroll [element:ice] die below 4."),

    # class affixes - frost that missed (rime_first, permafrost positions)
    ("resources/affixes/classes/mage/frost/rime_dice/rime_dice_first_r1_affix.tres",
     "Ice die in first position: +2 value.",
     "[element:ice] die in first position: +2 value."),
    ("resources/affixes/classes/mage/frost/rime_dice/rime_dice_first_r2_affix.tres",
     "Ice die in first position: +3 value.",
     "[element:ice] die in first position: +3 value."),
    ("resources/affixes/classes/mage/frost/permafrost_rune/permafrost_rune_r1_affix.tres",
     "Ice die next to another ice die: both get +1 value.",
     "[element:ice] die next to another [element:ice] die: both get +1 value."),
    ("resources/affixes/classes/mage/frost/permafrost_rune/permafrost_rune_r2_affix.tres",
     "Ice die next to another ice die: both get +2 value.",
     "[element:ice] die next to another [element:ice] die: both get +2 value."),
    ("resources/affixes/classes/mage/frost/glacial_clarity/glacial_clarity_r1_affix.tres",
     "Ice dice auto-reroll below 2.",
     "[element:ice] dice auto-reroll below 2."),
    ("resources/affixes/classes/mage/frost/glacial_clarity/glacial_clarity_r2_affix.tres",
     "Ice dice auto-reroll below 3.",
     "[element:ice] dice auto-reroll below 3."),
    ("resources/affixes/classes/mage/frost/glacial_clarity/glacial_clarity_r3_affix.tres",
     "Ice dice auto-reroll below 4.",
     "[element:ice] dice auto-reroll below 4."),

    # class affixes - flame
    ("resources/affixes/classes/mage/flame/kindling/kindling_r1_affix.tres",
     "Fire die adjacent to another fire die: +1 value.",
     "[element:fire] die adjacent to another [element:fire] die: +1 value."),
    ("resources/affixes/classes/mage/flame/kindling/kindling_r2_affix.tres",
     "Fire die adjacent to another fire die: +2 value.",
     "[element:fire] die adjacent to another [element:fire] die: +2 value."),
    ("resources/affixes/classes/mage/flame/hearthfire/hearthfire_r1_affix.tres",
     "Fire die next to non-fire die: +2 value.",
     "[element:fire] die next to non-fire die: +2 value."),
    ("resources/affixes/classes/mage/flame/hearthfire/hearthfire_r2_affix.tres",
     "Fire die next to non-fire die: +3 value.",
     "[element:fire] die next to non-fire die: +3 value."),
    ("resources/affixes/classes/mage/flame/heat_shimmer/heat_shimmer_r1_affix.tres",
     "Fire dice auto-reroll below 2.",
     "[element:fire] dice auto-reroll below 2."),
    ("resources/affixes/classes/mage/flame/heat_shimmer/heat_shimmer_r2_affix.tres",
     "Fire dice auto-reroll below 3.",
     "[element:fire] dice auto-reroll below 3."),
    ("resources/affixes/classes/mage/flame/heat_shimmer/heat_shimmer_r3_affix.tres",
     "Fire dice auto-reroll below 4.",
     "[element:fire] dice auto-reroll below 4."),
    ("resources/affixes/classes/mage/flame/mana_flare/mana_flare_r1_affix.tres",
     "Fire die at/below half max value: refund 1 mana. Max 2/turn.",
     "[element:fire] die at/below half max value: refund 1 mana. Max 2/turn."),
    ("resources/affixes/classes/mage/flame/mana_flare/mana_flare_r2_affix.tres",
     "Fire die at/below half max value: refund 2 mana. Max 2/turn.",
     "[element:fire] die at/below half max value: refund 2 mana. Max 2/turn."),
    ("resources/affixes/classes/mage/flame/ember_link/ember_link_r1_affix.tres",
     "Fire die copies 15% of higher neighbor's value (round up).",
     "[element:fire] die copies 15% of higher neighbor's value (round up)."),
    ("resources/affixes/classes/mage/flame/ember_link/ember_link_r2_affix.tres",
     "Fire die copies 25% of higher neighbor's value (round up).",
     "[element:fire] die copies 25% of higher neighbor's value (round up)."),
    ("resources/affixes/classes/mage/flame/forge_bond/forge_bond_first_affix.tres",
     "Fire die in FIRST position: +25% damage.",
     "[element:fire] die in FIRST position: +25% damage."),
    ("resources/affixes/classes/mage/flame/forge_bond/forge_bond_last_affix.tres",
     "Fire die in LAST position: +25% damage.",
     "[element:fire] die in LAST position: +25% damage."),

    # class affixes - storm polarity
    ("resources/affixes/classes/mage/storm/polarity/polarity_r1_affix.tres",
     "Shock die +2 value if no adjacent die is Shock.",
     "[element:shock] die +2 value if no adjacent die is [element:shock]."),
    ("resources/affixes/classes/mage/storm/polarity/polarity_r2_affix.tres",
     "Shock die +3 value if no adjacent die is Shock.",
     "[element:shock] die +3 value if no adjacent die is [element:shock]."),
    ("resources/affixes/classes/mage/storm/polarity/polarity_r3_affix.tres",
     "Shock die +4 value if no adjacent die is Shock.",
     "[element:shock] die +4 value if no adjacent die is [element:shock]."),
    ("resources/affixes/classes/mage/storm/conductor/conductor_r1_affix.tres",
     "Shock dice chain 30% damage to 1 enemy on use.",
     "[element:shock] dice chain 30% damage to 1 enemy on use."),
    ("resources/affixes/classes/mage/storm/conductor/conductor_r2_affix.tres",
     "Shock dice chain 40% damage to 1 enemy on use.",
     "[element:shock] dice chain 40% damage to 1 enemy on use."),
    ("resources/affixes/classes/mage/storm/conductor/conductor_r3_affix.tres",
     "Shock dice chain 50% damage to 1 enemy on use.",
     "[element:shock] dice chain 50% damage to 1 enemy on use."),

    # remaining storm skill affix - galvanic_renewal's "shock damage" mention
    ("resources/affixes/classes/mage/storm/mana_siphon/mana_siphon_r1_affix.tres",
     "On shock kill: restore 4 mana.",
     "On [element:shock] kill: restore 4 mana."),
    ("resources/affixes/classes/mage/storm/mana_siphon/mana_siphon_r2_affix.tres",
     "On shock kill: restore 6 mana.",
     "On [element:shock] kill: restore 6 mana."),
    ("resources/affixes/classes/mage/storm/mana_siphon/mana_siphon_r3_affix.tres",
     "On shock kill, restore 7 mana.",
     "On [element:shock] kill, restore 7 mana."),
    ("resources/affixes/classes/mage/storm/galvanic_renewal/galvanic_renewal_r1_affix.tres",
     "On shock kill: gain 1 free shock die to hand. Max 1/turn.",
     "On [element:shock] kill: gain 1 free [element:shock] die to hand. Max 1/turn."),
    ("resources/affixes/classes/mage/storm/galvanic_renewal/galvanic_renewal_r2_affix.tres",
     "On shock kill: gain 2 free shock dice to hand. Max 1/turn.",
     "On [element:shock] kill: gain 2 free [element:shock] dice to hand. Max 1/turn."),

    # base affixes - apply_enfeeble_on_hit
    ("resources/affixes/base/offense/tier_3/apply_enfeeble_on_hit.tres",
     "{proc_chance}% chance to Enfeeble on hit",
     "{proc_chance}% chance to [status:enfeeble|Enfeeble] on hit"),
]

for rel, old, new in remaining:
    edit_file(rel, old, new)

print("Remaining edits done")
