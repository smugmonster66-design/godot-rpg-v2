#!/usr/bin/env python3
import os
import re
import glob

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

def edit_action_file(rel_path, old_val, new_val):
    path = os.path.join(BASE, rel_path).replace("\\", "/")
    old_str = f'action_description = "{old_val}"'
    new_str = f'action_description = "{new_val}"'
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

# --- Affix files (simple string edits) ---
affix_edits = [
    # spark CA affixes
    ("resources/affixes/classes/mage/storm/spark/spark_ca_r1_affix.tres",
     "Chromatic Bolt applies 1 Static on hit (requires shock die).",
     "Chromatic Bolt applies 1 [status:static] on hit (requires [element:shock] die)."),
    ("resources/affixes/classes/mage/storm/spark/spark_ca_r2_affix.tres",
     "Chromatic Bolt applies 2 Static on hit (requires shock die).",
     "Chromatic Bolt applies 2 [status:static] on hit (requires [element:shock] die)."),
    ("resources/affixes/classes/mage/storm/spark/spark_ca_r3_affix.tres",
     "Chromatic Bolt applies 3 Static on hit (requires shock die).",
     "Chromatic Bolt applies 3 [status:static] on hit (requires [element:shock] die)."),
    # spark unlock affixes
    ("resources/affixes/classes/mage/storm/spark/spark_size_unlock.tres",
     "Unlocks D4 shock mana die.",
     "Unlocks D4 [element:shock] mana die."),
    ("resources/affixes/classes/mage/storm/spark/spark_element_unlock.tres",
     "Unlocks Shock mana element.",
     "Unlocks [element:shock] mana element."),
    # arc_pulse affixes
    ("resources/affixes/classes/mage/storm/arc_pulse/arc_pulse_r1_affix.tres",
     "Shock dice apply 1 Static on use.",
     "[element:shock] dice apply 1 [status:static] on use."),
    ("resources/affixes/classes/mage/storm/arc_pulse/arc_pulse_r2_affix.tres",
     "Shock dice apply 2 Static on use.",
     "[element:shock] dice apply 2 [status:static] on use."),
    ("resources/affixes/classes/mage/storm/arc_pulse/arc_pulse_r3_affix.tres",
     "Shock dice apply 3 Static on use.",
     "[element:shock] dice apply 3 [status:static] on use."),
    # eye_of_the_storm
    ("resources/affixes/classes/mage/storm/eye_of_the_storm/eots_double_stacks_affix.tres",
     "Double max Static stacks.",
     "Double max [status:static] stacks."),
    ("resources/affixes/classes/mage/storm/eye_of_the_storm/eye_chain_affix.tres",
     "All shock chain effects hit +1 additional target.",
     "All [element:shock] chain effects hit +1 additional target."),
    # entropic_cascade
    ("resources/affixes/classes/mage/frost/entropic_cascade/entropic_cascade_penalty_affix.tres",
     "Chill die-value penalty improved: -2 per 2 stacks (instead of -1).",
     "[status:chill] die-value penalty improved: -2 per 2 stacks (instead of -1)."),
]

for rel, old, new in affix_edits:
    edit_file(rel, old, new)

# --- Storm skill files (regex replacements for color-tagged patterns) ---
def fix_storm_skill_desc(content):
    # "Shock mana dice chain ... damage to 1 additional enemy on use."
    content = re.sub(
        r'description = "Shock mana dice chain (\[color=yellow\]\S+\[/color\]) damage to 1 additional enemy on use\."',
        r'description = "[element:shock] mana dice chain \1 damage to 1 additional enemy on use."',
        content
    )
    # "Shock die gains +X value if no adjacent die is Shock element."
    content = re.sub(
        r'description = "Shock die gains \+(\[color=yellow\]\S+\[/color\]) value if no adjacent die is Shock element\."',
        r'description = "[element:shock] die gains +\1 value if no adjacent die is [element:shock] element."',
        content
    )
    # "On shock kill: restore X mana."
    content = re.sub(
        r'description = "On shock kill: restore (\[color=yellow\]\S+\[/color\]) mana\."',
        r'description = "On [element:shock] kill: restore \1 mana."',
        content
    )
    # "On shock kill: gain X free shock die to hand."
    content = re.sub(
        r'description = "On shock kill: gain (\[color=yellow\]\S+\[/color\]) free shock die to hand\. Max 1 trigger/turn\."',
        r'description = "On [element:shock] kill: gain \1 free [element:shock] die to hand. Max 1 trigger/turn."',
        content
    )
    # ACTION line: "2 shock dice -> x1.2 damage + [color=yellow]3 per Static stack[/color]. Chain to 1 at 50%. Per turn."
    content = re.sub(
        r'description = "(\[color=yellow\]ACTION:\[/color\]) 2 shock dice -> x1\.2 damage \+ \[color=yellow\]3 per Static stack\[/color\]\. Chain to 1 at 50%\. Per turn\."',
        r'description = "\1 2 [element:shock] dice -> x1.2 damage + 3 per [status:static] stack. Chain to 1 at 50%. Per turn."',
        content
    )
    return content

storm_skill_files = glob.glob(
    os.path.join(BASE, "resources/skills/classes/mage/storm/**/*.tres"), recursive=True
)
changed = 0
for path in storm_skill_files:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = fix_storm_skill_desc(content)
    if new_content != content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"OK skill: {os.path.relpath(path, BASE)}")
        changed += 1

print(f"\nFixed {changed} storm skill files")

# --- Navy action descriptions ---
navy_action_edits = [
    ("resources/actions/navy/navy_focused_salvo.tres",
     "Concentrated fire that leaves a lasting burn.",
     "Concentrated fire that leaves a lasting [status:burn|burn]."),
    ("resources/actions/navy/navy_shield_charge.tres",
     "Rush forward, slamming and fortifying.",
     "Rush forward, slamming and fortifying."),  # no status/element tag needed
    ("resources/actions/navy/navy_subdue.tres",
     "Weaken the target with a stunning blow.",
     "Weaken the target with a stunning blow."),  # "stunning" is not a status tag
    ("resources/actions/navy/navy_smoke_pellet.tres",
     "Blind and enfeeble the target.",
     "Blind and [status:enfeeble|enfeeble] the target."),
    ("resources/actions/navy/navy_war_beat.tres",
     "Empower and fortify all allies.",
     "Empower and fortify all allies."),  # no status tag for fortify
    ("resources/actions/navy/navy_disruption_bolt.tres",
     "A shock bolt that corrodes defenses.",
     "A [element:shock] bolt that [status:corrode|corrodes] defenses."),
    ("resources/actions/navy/navy_tactical_strike.tres",
     "Attack that exposes the target.",
     "Attack that [status:expose|exposes] the target."),
    ("resources/actions/navy/navy_strafe.tres",
     "A quick pass that exposes weaknesses.",
     "A quick pass that [status:expose|exposes] weaknesses."),
    ("resources/actions/navy/navy_arcane_barrage.tres",
     "A barrage of arcane fire.",
     "A barrage of arcane [element:fire|fire]."),
]

for rel, old, new in navy_action_edits:
    if old != new:
        edit_action_file(rel, old, new)
    else:
        print(f"SKIP (no change needed): {rel}")

print("\nDone.")
