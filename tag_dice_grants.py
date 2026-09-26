#!/usr/bin/env python3
import os
import re
import glob

BASE = "D:/Games/dice-rpg-game-2026-new"

# Grant dice affixes - "Add a X D4/D6/D8/D10/D12 to your dice pool"
# These reference element types
element_map = {
    "Fire": "fire",
    "Ice": "ice",
    "Shock": "shock",
    "Poison": "poison",
    "Shadow": "shadow",
    "Slashing": "slashing",
    "Blunt": "blunt",
    "Piercing": "piercing",
}

utility_dirs = glob.glob(os.path.join(BASE, "resources/affixes/base/utility/**/*.tres"), recursive=True)

changed = 0
for path in utility_dirs:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content

    def replace_grant_desc(m):
        line = m.group(0)
        # Match "Add a ELEMENT DX to your dice pool"
        for elem_name, elem_id in element_map.items():
            pattern = f'description = "Add a {elem_name} (D\\d+) to your dice pool"'
            repl = f'description = "Add a [element:{elem_id}] \\1 to your dice pool"'
            new_line = re.sub(pattern, repl, line)
            if new_line != line:
                return new_line
        return line

    # Process description lines
    new_content = re.sub(r'description = "Add a \w+ D\d+ to your dice pool"', replace_grant_desc, content)

    if new_content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"OK: {os.path.relpath(path, BASE)}")
        changed += 1

# Handle da_eye_chain_extension
path = os.path.join(BASE, "resources/dice_affixes/mage/storm/da_eye_chain_extension.tres")
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = content.replace(
    'description = "All shock chain effects hit +1 additional target."',
    'description = "All [element:shock] chain effects hit +1 additional target."'
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"OK: da_eye_chain_extension.tres")
    changed += 1

print(f"\nChanged {changed} files")
