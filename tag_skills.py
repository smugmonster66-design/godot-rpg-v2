#!/usr/bin/env python3
import os
import re
import glob

BASE = "D:/Games/dice-rpg-game-2026-new"

def process_description(desc):
    """Apply tag replacements to a description string value."""
    # Flame / Fire element and Burn status (orange colored)
    # Element: Fire
    desc = re.sub(r'\[color=orange\]Fire\[/color\]', '[element:fire]', desc)
    desc = re.sub(r'\[color=red\]Fire\[/color\]', '[element:fire]', desc)
    # Status: Burn and burning (adjective)
    desc = re.sub(r'\[color=orange\]burning\[/color\]', '[status:burn|burning]', desc)
    desc = re.sub(r'\[color=orange\](\d+\s+)?Burn\[/color\]', lambda m: f'[status:burn|{m.group(0).split("]")[1].split("[")[0]}]' if m.group(1) else '[status:burn]', desc)
    # Simpler approach - replace color-tagged Burn patterns
    desc = re.sub(r'\[color=orange\](\d+ Burn)\[/color\]', r'[status:burn|\1]', desc)
    desc = re.sub(r'\[color=orange\]Burn\[/color\]', '[status:burn]', desc)
    # Detonate (not a status/element - skip)

    # Storm / Shock element and Static status (yellow colored)
    desc = re.sub(r'\[color=yellow\]Shock\[/color\]', '[element:shock]', desc)
    # Static status - when [color=yellow]Static[/color] or just "Static" near shock context
    desc = re.sub(r'\[color=yellow\](\d+/?\d*\s+)?Static\[/color\]', lambda m: f'[status:static|{m.group(1).strip() + " Static" if m.group(1) else "Static"}]' if m.group(1) else '[status:static]', desc)
    # Simpler:
    desc = re.sub(r'\[color=yellow\](\d+/\d+ Static)\[/color\]', r'[status:static|\1]', desc)
    desc = re.sub(r'\[color=yellow\](\d+ Static)\[/color\]', r'[status:static|\1]', desc)
    desc = re.sub(r'\[color=yellow\]Static\[/color\]', '[status:static]', desc)
    desc = re.sub(r'\[color=yellow\]1/2/3 Static\[/color\]', '[status:static|1/2/3 Static]', desc)

    # Frost / Ice element and Chill/Freeze status (cyan colored)
    desc = re.sub(r'\[color=cyan\]Ice\[/color\]', '[element:ice]', desc)
    # Chill
    desc = re.sub(r'\[color=cyan\](\d+/\d+ Chill)\[/color\]', r'[status:chill|\1]', desc)
    desc = re.sub(r'\[color=cyan\](\d+ Chill)\[/color\]', r'[status:chill|\1]', desc)
    desc = re.sub(r'\[color=cyan\](\d+/\d+/\d+ Chill)\[/color\]', r'[status:chill|\1]', desc)
    desc = re.sub(r'\[color=cyan\]2 Chill\[/color\]', '[status:chill|2 Chill]', desc)
    desc = re.sub(r'\[color=cyan\]Chill\[/color\]', '[status:chill]', desc)
    # Freeze / Frozen
    desc = re.sub(r'\[color=cyan\]Frozen\[/color\]', '[status:freeze|Frozen]', desc)
    desc = re.sub(r'\[color=cyan\]Freeze\[/color\]', '[status:freeze]', desc)

    return desc

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Process each description line
    def replace_desc(m):
        field_name = m.group(1)
        desc = m.group(2)
        new_desc = process_description(desc)
        return f'{field_name} = "{new_desc}"'

    content = re.sub(r'(description) = "([^"]*)"', replace_desc, content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

# Process all skill files
skill_files = glob.glob(os.path.join(BASE, "resources/skills/**/*.tres"), recursive=True)
changed = 0
for f in skill_files:
    if process_file(f):
        print(f"OK: {os.path.relpath(f, BASE)}")
        changed += 1

print(f"\nChanged {changed} skill files")
