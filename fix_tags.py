#!/usr/bin/env python3
import os
import re
import glob

BASE = "D:/Games/dice-rpg-game-2026-new"

def fix_numbered_tags(content):
    """Fix tags like [status:burn|1 Burn] -> 1 [status:burn]
    and [status:chill|2 Chill] -> 2 [status:chill]
    and [status:static|1/2/3 Static] -> [status:static|1/2/3 Static] (keep fraction ranges as label)
    """
    # Fix [status:burn|N Burn] -> N [status:burn]
    content = re.sub(r'\[status:burn\|(\d+) Burn\]', r'\1 [status:burn]', content)
    # Fix [status:chill|N Chill] -> N [status:chill]
    content = re.sub(r'\[status:chill\|(\d+) Chill\]', r'\1 [status:chill]', content)
    # Fix [status:static|N Static] -> N [status:static]  (but keep range labels like 1/2/3)
    content = re.sub(r'\[status:static\|(\d+) Static\]', r'\1 [status:static]', content)
    # Fix [status:chill|N/M Chill] -> keep as is (it's a range display)
    # Actually for ranges like "2/3 Chill", the label is useful
    # Fix [status:burn|N/M Burn] -> N/M [status:burn]
    content = re.sub(r'\[status:burn\|(\d+/\d+) Burn\]', r'\1 [status:burn]', content)
    content = re.sub(r'\[status:chill\|(\d+/\d+) Chill\]', r'\1 [status:chill]', content)
    # [status:chill|N/M/P Chill] -> N/M/P [status:chill]
    content = re.sub(r'\[status:chill\|(\d+/\d+/\d+) Chill\]', r'\1 [status:chill]', content)
    # "1/2/3 Static" as a range label is actually useful as a display label, keep it
    # but fix simple ones: [status:static|2/3 Static] -> 2/3 [status:static]
    content = re.sub(r'\[status:static\|(\d+/\d+) Static\]', r'\1 [status:static]', content)
    # [status:static|2 Static] already fixed above, but handle [status:static|3 Static]
    # The 1/2/3 range label is fine to keep since it communicates scaling

    return content

changed = 0
dirs = [
    "resources/skills/**/*.tres",
    "resources/affixes/**/*.tres",
    "resources/dice_affixes/**/*.tres",
    "resources/actions/**/*.tres",
]
for pattern in dirs:
    for f in glob.glob(os.path.join(BASE, pattern), recursive=True):
        with open(f, 'r', encoding='utf-8') as fh:
            content = fh.read()
        new_content = fix_numbered_tags(content)
        if new_content != content:
            with open(f, 'w', encoding='utf-8') as fh:
                fh.write(new_content)
            print(f"Fixed: {os.path.relpath(f, BASE)}")
            changed += 1

print(f"\nFixed {changed} files")
