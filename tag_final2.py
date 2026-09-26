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
            return True
        else:
            print(f"MISS: {old_val[:70]!r} in {rel_path}")
            return False
    except Exception as e:
        print(f"ERR {rel_path}: {e}")
        return False

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
            return True
        else:
            print(f"MISS: {old_val[:70]!r} in {rel_path}")
            return False
    except Exception as e:
        print(f"ERR {rel_path}: {e}")
        return False

# --- Flame skill files: "Fire die..." patterns without color tags ---
# These are descriptions that tag_skills.py missed because they had no [color=X] wrapper.
# We do regex replacement on the skill files.
def fix_flame_skill_desc(content):
    # "Fire die adjacent to another fire die: ..."
    content = re.sub(
        r'(description = ")Fire die adjacent to another fire die: ',
        r'\1[element:fire] die adjacent to another [element:fire] die: ',
        content
    )
    # "Fire die next to a non-fire die: ..."
    content = re.sub(
        r'(description = ")Fire die next to a non-fire die: ',
        r'\1[element:fire] die next to a non-[element:fire] die: ',
        content
    )
    # "Fire die copies X% of its higher neighbor..."
    content = re.sub(
        r'(description = ")Fire die copies ',
        r'\1[element:fire] die copies ',
        content
    )
    # "Fire die at or below half max value: ..."
    content = re.sub(
        r'(description = ")Fire die at or below half max value: ',
        r'\1[element:fire] die at or below half max value: ',
        content
    )
    # "Fire dice auto-reroll if value below ..."
    content = re.sub(
        r'(description = ")Fire dice auto-reroll if value below ',
        r'\1[element:fire] dice auto-reroll if value below ',
        content
    )
    # Detonate kill: refund charge + next 2 fire dice gain ...
    content = re.sub(
        r'next 2 fire dice gain ',
        r'next 2 [element:fire] dice gain ',
        content
    )
    return content

def fix_frost_skill_desc(content):
    # "Ice die adjacent to another ice die: ..."
    content = re.sub(
        r'(description = ")Ice die adjacent to another ice die: ',
        r'\1[element:ice] die adjacent to another [element:ice] die: ',
        content
    )
    # "Ice dice auto-reroll if value below ..."
    content = re.sub(
        r'(description = ")Ice dice auto-reroll if value below ',
        r'\1[element:ice] dice auto-reroll if value below ',
        content
    )
    return content

flame_skill_files = glob.glob(
    os.path.join(BASE, "resources/skills/classes/mage/flame/**/*.tres"), recursive=True
)
frost_skill_files = glob.glob(
    os.path.join(BASE, "resources/skills/classes/mage/frost/**/*.tres"), recursive=True
)

changed = 0
for path in flame_skill_files + frost_skill_files:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = fix_flame_skill_desc(content)
    new_content = fix_frost_skill_desc(new_content)
    if new_content != content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"OK skill: {os.path.relpath(path, BASE)}")
        changed += 1

print(f"Fixed {changed} flame/frost skill files")

# --- Crucibles gift affix (plain text, no color) ---
edit_file(
    "resources/affixes/classes/mage/flame/crucibles_gift/crucibles_gift_r1_affix.tres",
    "Detonate kill: refund Detonate charge + next 2 fire dice gain +3 value.",
    "Detonate kill: refund Detonate charge + next 2 [element:fire] dice gain +3 value."
)

# --- Navy action descriptions ---
navy_edits = [
    ("resources/actions/navy/navy_lightning_strike.tres",
     "A bolt of lightning with residual static.",
     "A bolt of lightning with residual [status:static|static]."),
    ("resources/actions/navy/navy_flash_signal.tres",
     "Blind and expose the target.",
     "Blind and [status:expose|expose] the target."),
    ("resources/actions/navy/navy_undertow.tres",
     "Corrode and enfeeble the target.",
     "[status:corrode|Corrode] and [status:enfeeble|enfeeble] the target."),
    ("resources/actions/navy/navy_coordinated_assault.tres",
     "Expose the target and empower all allies.",
     "[status:expose|Expose] the target and empower all allies."),
    ("resources/actions/navy/navy_ward_bolt.tres",
     "Shadow bolt that reinforces self.",
     "[element:shadow] bolt that reinforces self."),
]

for rel, old, new in navy_edits:
    edit_action_file(rel, old, new)

# --- Longbow volley: "Fire two arrows" - "Fire" here is a verb, not the element. Skip. ---
# "fire two arrows" = fire (verb) -> skip intentionally

# --- statuses: these are self-definitions, skip tagging the status files themselves ---
# ignition.tres "fire abilities" is incidental
# corrode.tres, freeze.tres, enfeeble.tres, expose.tres, shadow.tres are self-definitions

print("\nDone.")
