"""Art manifest generator.

Scans the project's .tres / .tscn / .gd files and writes per-asset Markdown
tables into docs/art_spec/manifest/. Read-only with respect to game content —
re-run whenever content is added:

    python tools/art_manifest.py

Output files are fully regenerated; do not hand-edit them. Hand-written
category specs live in docs/art_spec/0*_*.md and link to these tables.
"""

from __future__ import annotations

import re
import struct
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "art_spec" / "manifest"
SKIP_DIRS = {".godot", ".claude", ".git", "addons"}

PLACEHOLDER_RE = re.compile(r"placeholder|test_|/test/|PLACEHOLDER UI|test_dummy|/debug/", re.I)
ELEMENT_WORDS = ["fire", "ice", "shock", "poison", "shadow", "slashing", "blunt", "piercing", "frost", "storm", "flame"]

# ---------------------------------------------------------------------------
# Enum labels (must match the GDScript enums)
# ---------------------------------------------------------------------------
EQUIP_SLOT = ["Head", "Torso", "Gloves", "Boots", "Main Hand", "Off Hand", "Heavy", "Accessory"]
RARITY = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
ENEMY_TIER = ["Trash", "Elite", "Mini Boss", "Boss", "World Boss"]
ARCHETYPE = ["-", "STR", "AGI", "INT"]
CONSUMABLE_TIER = ["Restorative", "Combat Prep", "Dice Elixir", "Inscription", "Curio"]
DAMAGE_TYPE = ["Slashing", "Blunt", "Piercing", "Fire", "Ice", "Shock", "Poison", "Shadow"]
ACTION_CATEGORY = ["Attack", "Buff", "Debuff", "Heal", "Summon", "Escape"]
SKILL_CATEGORY = ["Passive", "Trigger", "Action", "Signature", "Weave", "Capstone"]
LOCATION_TYPE = ["Town", "Camp", "Dungeon", "Boss", "Event", "Shrine", "Treasure", "Crossroads", "Hidden"]
QUEST_TYPE = ["Main", "Side", "Companion", "Bounty", "Collection", "Exploration", "Hidden"]
COMPANION_TYPE = ["NPC", "Summon"]
MOODS = ["base", "amused", "angry", "laughing", "frowning", "sad", "surprised", "worried", "smug",
         "embarrassed", "determined", "tired", "skeptical", "excited", "afraid", "disgusted",
         "thoughtful", "pleading", "stern", "sly"]


# ---------------------------------------------------------------------------
# .tres parsing
# ---------------------------------------------------------------------------
class Tres:
    def __init__(self, path: Path):
        self.path = path
        self.rel = path.relative_to(ROOT).as_posix()
        self.ext: dict[str, tuple[str, str]] = {}  # id -> (type, res path)
        self.props: dict[str, str] = {}
        self.script_path = ""
        self.subresources: list[dict[str, str]] = []
        self._parse()

    def _parse(self) -> None:
        text = self.path.read_text(encoding="utf-8", errors="replace")
        section = None
        current_sub: dict[str, str] | None = None
        for line in text.splitlines():
            if line.startswith("[ext_resource"):
                m_id = re.search(r'\bid="([^"]+)"', line)
                m_path = re.search(r'\bpath="([^"]+)"', line)
                m_type = re.search(r'\btype="([^"]+)"', line)
                if m_id and m_path:
                    self.ext[m_id.group(1)] = (m_type.group(1) if m_type else "", m_path.group(1))
                continue
            if line.startswith("[sub_resource"):
                section = "sub"
                current_sub = {"__header__": line}
                self.subresources.append(current_sub)
                continue
            if line.startswith("[resource]"):
                section = "resource"
                continue
            if line.startswith("["):
                section = None
                continue
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_/]*) = (.*)$", line)
            if not m:
                continue
            if section == "resource":
                self.props[m.group(1)] = m.group(2)
            elif section == "sub" and current_sub is not None:
                current_sub[m.group(1)] = m.group(2)
        script = self.props.get("script", "")
        m = re.match(r'ExtResource\("([^"]+)"\)', script)
        if m and m.group(1) in self.ext:
            self.script_path = self.ext[m.group(1)][1]

    @property
    def script_name(self) -> str:
        return Path(self.script_path).stem if self.script_path else ""

    def s(self, key: str, default: str = "") -> str:
        v = self.props.get(key)
        if v is None:
            return default
        m = re.match(r'^&?"(.*)"$', v)
        return m.group(1) if m else v

    def i(self, key: str, default: int = 0) -> int:
        try:
            return int(self.props.get(key, default))
        except ValueError:
            return default

    def tex(self, key: str) -> str:
        v = self.props.get(key)
        if not v or v == "null":
            return ""
        m = re.match(r'ExtResource\("([^"]+)"\)', v)
        if m and m.group(1) in self.ext:
            return self.ext[m.group(1)][1]
        if v.startswith("SubResource"):
            return "(embedded sub-resource)"
        return ""


def iter_files(ext: str):
    for p in ROOT.rglob(f"*{ext}"):
        if any(part in SKIP_DIRS for part in p.relative_to(ROOT).parts):
            continue
        yield p


def load_all_tres() -> dict[str, list[Tres]]:
    by_script: dict[str, list[Tres]] = defaultdict(list)
    for p in iter_files(".tres"):
        try:
            t = Tres(p)
        except Exception as exc:  # noqa: BLE001
            print(f"WARN: could not parse {p}: {exc}")
            continue
        if t.script_name:
            by_script[t.script_name].append(t)
    for lst in by_script.values():
        lst.sort(key=lambda t: t.rel)
    return by_script


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def png_size(res_path: str) -> str:
    if not res_path.startswith("res://"):
        return ""
    p = ROOT / res_path[len("res://"):]
    try:
        with p.open("rb") as fh:
            head = fh.read(24)
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return ""
        w, h = struct.unpack(">II", head[16:24])
        return f"{w}x{h}"
    except OSError:
        return "MISSING FILE"


def snake(name: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").lower()
    return re.sub(r"_+", "_", s)


def status_for(current: str, hookup: bool = False) -> str:
    if not current:
        st = "NEW"
    elif current == "(embedded sub-resource)":
        st = "REVIEW (embedded)"
    elif PLACEHOLDER_RE.search(current):
        st = "REDO (placeholder)"
    else:
        st = "REVIEW (keep/redo)"
    if hookup:
        st += " · NEEDS HOOKUP"
    return st


def current_cell(path: str) -> str:
    if not path:
        return "—"
    if not path.startswith("res://"):
        return path
    size = png_size(path)
    short = path.replace("res://", "")
    return f"`{short}`" + (f" ({size})" if size else "")


def element_of(stem: str) -> str:
    for w in ELEMENT_WORDS:
        if re.search(rf"(^|_){w}(_|$)", stem):
            return w
    return ""


def md_table(headers: list[str], rows: list[list[str]]) -> str:
    def esc(c: str) -> str:
        return str(c).replace("|", "\\|").replace("\n", " ")
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(esc(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def write(name: str, title: str, intro: str, sections: list[tuple[str, list[str], list[list[str]]]]) -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    total = sum(len(r) for _, _, r in sections)
    parts = [f"# {title}", "", "> Generated by `tools/art_manifest.py` — do not hand-edit. Re-run the script after adding content.", "",
             intro.strip(), "", f"**Total rows: {total}**", ""]
    for heading, headers, rows in sections:
        if heading:
            parts += [f"## {heading} ({len(rows)})", ""]
        parts += [md_table(headers, rows), ""]
    (OUT / name).write_text("\n".join(parts), encoding="utf-8")
    return total


def unique_ids(rows: list[list[str]], col: int = 0) -> None:
    seen = Counter(r[col] for r in rows)
    dup = {k for k, v in seen.items() if v > 1}
    if dup:
        print(f"WARN: duplicate asset ids: {sorted(dup)}")


# ---------------------------------------------------------------------------
# Category builders
# ---------------------------------------------------------------------------
HDR = ["Asset ID", "Deliver as", "Name", "Details", "Source resource", "Current art", "Status", "Priority"]


def build_enemies(db) -> int:
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for t in db.get("enemy_data", []):
        parts = Path(t.rel).parts
        faction = "navy" if "navy" in parts else ("baseline" if "baseline" in parts else "misc")
        stem = Path(t.rel).stem
        tier = ENEMY_TIER[t.i("enemy_tier")] if t.i("enemy_tier") < len(ENEMY_TIER) else "?"
        arch = ARCHETYPE[t.i("enemy_archetype")] if t.i("enemy_archetype") < len(ARCHETYPE) else "?"
        tier_slug = snake(tier)
        aid = f"ENM-{faction}-{tier_slug}-{stem}"
        deliver = f"assets/characters/enemies/{faction}/{tier_slug}/enemy_{stem}.png"
        if faction == "navy" and tier in ("Trash", "Elite"):
            prio = "P0"
        elif faction == "navy":
            prio = "P2"
        else:
            prio = "P3 (confirm: test/baseline content)"
        portrait = t.tex("portrait")
        groups[f"{faction.title()} — {tier}"].append(
            [aid, f"`{deliver}`", t.s("enemy_name", stem), f"{tier} · {arch}", f"`{t.rel}`",
             current_cell(portrait), status_for(portrait), prio])
    order = sorted(groups, key=lambda k: (not k.startswith("Navy"), k.split(" — ")[0],
                                         ENEMY_TIER.index(k.split(" — ")[1]) if k.split(" — ")[1] in ENEMY_TIER else 9))
    sections = [(k, HDR, groups[k]) for k in order]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("enemies.md", "Enemy Portraits",
                 "One portrait per enemy. Spec: see `04_characters.md` § Enemy portraits "
                 "(512×512 source, displayed 300×300 in the enemy slot). "
                 "`EnemyData.sprite_texture` (full body) is **not** requested — combatant sprites are hidden in-game.",
                 sections)


def build_items(db) -> int:
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for t in db.get("equippable_item", []):
        if "/items/" not in t.rel:
            continue
        stem = Path(t.rel).stem
        slot = EQUIP_SLOT[t.i("equip_slot", 4)] if t.i("equip_slot", 4) < len(EQUIP_SLOT) else "?"
        rarity = RARITY[t.i("rarity")] if t.i("rarity") < len(RARITY) else "?"
        region = "region_1" if "region_1" in t.rel else ("debug" if "debug" in t.rel else "legacy")
        slot_slug = snake(slot)
        icon = t.tex("icon")
        prio = "P1" if region == "region_1" else "P3 (legacy/test — confirm)"
        groups[f"{region} — {slot}"].append(
            [f"ITM-{slot_slug}-{stem}", f"`assets/items/{slot_slug}/item_{stem}.png`", t.s("item_name", stem),
             f"{slot} · base rarity {rarity}", f"`{t.rel}`", current_cell(icon), status_for(icon), prio])
    order = sorted(groups, key=lambda k: (not k.startswith("region_1"), k))
    sections = [(k, HDR, groups[k]) for k in order]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("items.md", "Equipment Item Icons",
                 "One icon per equipment item. Spec: see `05_items_consumables.md` § Equipment icons "
                 "(360×360 source; shown at 80–160 px with a shader rarity glow — do **not** paint rarity frames).",
                 sections)


def build_consumables(db) -> int:
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for t in db.get("consumable_item", []):
        stem = Path(t.rel).stem
        tier_i = t.i("tier")
        tier = CONSUMABLE_TIER[tier_i] if tier_i < len(CONSUMABLE_TIER) else "?"
        elem = element_of(stem)
        base = re.sub(rf"(^|_){elem}(_|$)", r"\1", stem).strip("_") if elem else ""
        details = tier + (f" · element variant of `{base}` ({elem})" if elem else "")
        icon = t.tex("icon")
        groups[tier].append(
            [f"CON-{stem}", f"`assets/items/consumables/{snake(tier)}/con_{stem}.png`", t.s("item_name", stem),
             details, f"`{t.rel}`", current_cell(icon), status_for(icon), "P2"])
    sections = [(k, HDR, groups[k]) for k in CONSUMABLE_TIER if k in groups]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("consumables.md", "Consumable Icons",
                 "One icon per consumable. Rows marked *element variant* can share one base drawing with an element "
                 "treatment (see `05_items_consumables.md` § Consumables — variant strategy).", sections)


def build_skills(db) -> int:
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for t in db.get("skill_resource", []):
        if "/skills/" not in t.rel:
            continue
        parts = Path(t.rel).parts
        tree = parts[-2]
        cls = parts[-3] if len(parts) >= 3 else ""
        stem = Path(t.rel).stem
        cat_i = t.i("skill_category")
        cat = SKILL_CATEGORY[cat_i] if cat_i < len(SKILL_CATEGORY) else "?"
        icon = t.tex("icon")
        groups[f"{cls} / {tree}"].append(
            [f"SKL-{tree}-{stem}", f"`assets/icons/skills/{cls}/{tree}/skill_{stem}.png`", t.s("skill_name", stem),
             f"Tier {t.i('tier', 1)} · col {t.i('column')} · {cat}", f"`{t.rel}`", current_cell(icon), status_for(icon), "P1"])
    for rows in groups.values():
        rows.sort(key=lambda r: (int(re.search(r"Tier (\d+)", r[3]).group(1)), r[2]))
    sections = [(k, HDR, groups[k]) for k in sorted(groups)]
    trees = []
    for t in db.get("skill_tree", []):
        icon = t.tex("icon")
        stem = Path(t.rel).stem
        trees.append([f"TREE-{stem}", f"`assets/icons/skills/trees/tree_{stem}.png`", t.s("tree_name", stem), "Skill tree tab icon",
                      f"`{t.rel}`", current_cell(icon), status_for(icon), "P1" if "mage" in t.rel or "flame" in stem or "frost" in stem or "storm" in stem else "P3 (future: Warrior)"])
    classes = []
    for t in db.get("player_class", []):
        stem = Path(t.rel).stem
        for field, what in (("icon", "Class icon"), ("portrait", "Class portrait")):
            cur = t.tex(field)
            classes.append([f"CLS-{stem}-{field}", f"`assets/icons/classes/class_{stem}_{field}.png`", t.s("player_class_name", stem),
                            what, f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P2"])
    sections += [("Skill trees", HDR, trees), ("Player classes", HDR, classes)]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("skills.md", "Skill, Tree and Class Icons",
                 "Spec: see `06_skills_actions.md` (skill icons 256×256 source, shown 48 px in the tree and 64 px in the popup).",
                 sections)


def build_actions(db) -> int:
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for t in db.get("action", []):
        if "/actions/" not in t.rel or "/effects/" in t.rel:
            continue
        rel_parts = Path(t.rel).parts
        idx = rel_parts.index("actions")
        group = rel_parts[idx + 1] if len(rel_parts) > idx + 2 else "root"
        owner = "Enemy" if group in ("enemy", "enemy_base", "navy") else "Player"
        stem = Path(t.rel).stem
        cat_i = t.i("action_category")
        cat = ACTION_CATEGORY[cat_i] if cat_i < len(ACTION_CATEGORY) else "?"
        el_i = t.i("damage_element")
        el = DAMAGE_TYPE[el_i] if el_i < len(DAMAGE_TYPE) else "?"
        icon = t.tex("icon")
        prio = "P2" if owner == "Player" and group != "root" else "P3"
        groups[f"{owner} — {group}"].append(
            [f"ACT-{group}-{stem}", f"`assets/icons/actions/{group}/act_{stem}.png`", t.s("action_name", stem),
             f"{cat} · {el}", f"`{t.rel}`", current_cell(icon), status_for(icon, hookup=True), prio])
    order = sorted(groups, key=lambda k: (not k.startswith("Player"), k))
    sections = [(k, HDR, groups[k]) for k in order]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("actions.md", "Action Icons",
                 "`Action.icon` is **not currently displayed** (no icon node on the action field card) — every row is "
                 "tagged NEEDS HOOKUP. Enemy action icons are lowest priority (P3) since enemy actions are shown briefly. "
                 "Spec: see `06_skills_actions.md` § Action icons.", sections)


def build_statuses(db) -> int:
    rows = []
    for t in db.get("status_affix", []):
        stem = Path(t.rel).stem
        icon = t.tex("icon")
        cur = current_cell(icon)
        st = status_for(icon)
        size = png_size(icon) if icon.startswith("res://") else ""
        if size and size not in ("MISSING FILE",) and int(size.split("x")[0]) < 128:
            st = f"REDO (too small: {size}, shown at 64)"
        rows.append([f"STS-{stem}", f"`assets/icons/status/status_{stem}.png`", t.s("affix_name", stem),
                     f"id `{t.s('status_id', stem)}`", f"`{t.rel}`", cur, st, "P1"])
    unique_ids(rows)
    return write("statuses.md", "Status Effect Icons",
                 "Spec: see `02_ui_icons.md` § Status icons (128×128 source; shown 64 px on combatants, 28 px on the player "
                 "portrait, 30 px inline in text). Deliver path matches the code fallback `res://assets/icons/status/`.",
                 [("", HDR, rows)])


def build_characters(db) -> int:
    comp = []
    for t in db.get("companion_data", []):
        stem = Path(t.rel).stem
        cur = t.tex("portrait")
        ctype = COMPANION_TYPE[t.i("companion_type")] if t.i("companion_type") < 2 else "?"
        comp.append([f"CMP-{stem}", f"`assets/characters/companions/cmp_{stem}.png`", t.s("companion_name", stem),
                     f"{ctype} · portrait", f"`{t.rel}`", current_cell(cur), status_for(cur), "P1"])
    npcs = []
    for t in db.get("npc_definition", []):
        stem = re.sub(r"^npc_", "", Path(t.rel).stem)
        cur = t.tex("portrait")
        npcs.append([f"NPC-{stem}-portrait", f"`assets/characters/npcs/npc_{stem}_portrait.png`", t.s("display_name", stem),
                     "Radial-menu portrait", f"`{t.rel}`", current_cell(cur), status_for(cur), "P1"])
        cur2 = t.tex("default_dialogue_icon")
        npcs.append([f"NPC-{stem}-dlgicon", f"`assets/characters/npcs/npc_{stem}_dialogue_icon.png`", t.s("display_name", stem),
                     "Default dialogue-topic icon", f"`{t.rel}`", current_cell(cur2), status_for(cur2), "P2"])
    speakers = []
    for t in db.get("dialogue_speaker", []):
        stem = re.sub(r"^ds_", "", Path(t.rel).stem)
        name = t.s("display_name", stem)
        cur = t.tex("bust_texture")
        moods_present = []
        for sub in t.subresources:
            if "mood_textures" in t.props and ("texture" in sub or "mood" in sub):
                try:
                    mood = MOODS[int(sub.get("mood", "0"))]
                except (ValueError, IndexError):
                    continue
                m_tex = re.match(r'ExtResource\("([^"]+)"\)', sub.get("texture", ""))
                moods_present.append((mood, t.ext[m_tex.group(1)][1] if m_tex and m_tex.group(1) in t.ext else ""))
        if not any(m == "base" for m, _ in moods_present):
            moods_present.insert(0, ("base", cur))
        for m, tex in moods_present:
            speakers.append([f"BUST-{stem}-{m}", f"`assets/busts/{snake(name)}/bust_{snake(name)}_{m}.png`", name, f"Bust — {m}",
                             f"`{t.rel}`", current_cell(tex), status_for(tex), "P1" if m == "base" else "P3"])
    sections = [("Companions", HDR, comp), ("NPCs", HDR, npcs), ("Dialogue speakers (busts)", HDR, speakers)]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("characters.md", "Companion, NPC and Speaker Art",
                 "Player bust and unreferenced busts (Hilda, Marcus, Gatekeeper, Bones moods) are specced by hand in "
                 "`04_characters.md`. Available moods: " + ", ".join(MOODS) + ".", sections)


def build_world(db) -> int:
    locs = []
    for t in db.get("location_node", []):
        stem = Path(t.rel).stem
        ltype_i = t.i("node_type")
        ltype = LOCATION_TYPE[ltype_i] if ltype_i < len(LOCATION_TYPE) else "?"
        cur = t.tex("map_icon")
        locs.append([f"LOC-{stem}", f"`assets/map_locations/icons/loc_{stem}.png`", t.s("display_name", stem), f"{ltype} · map icon",
                     f"`{t.rel}`", current_cell(cur), status_for(cur), "P1" if "new_dungeon" not in stem else "P3 (stray editor output)"])
    maps = []
    for t in db.get("map_definition", []):
        stem = Path(t.rel).stem
        cur = t.tex("background_texture")
        maps.append([f"MAP-{stem}", f"`assets/map_locations/backgrounds/map_{stem}.png`", t.s("display_name", stem), "Map background",
                     f"`{t.rel}`", current_cell(cur), status_for(cur), "P1"])
    btns = []
    for t in db.get("map_node_button_def", []):
        stem = Path(t.rel).stem
        for field in ("button_texture", "icon"):
            cur = t.tex(field)
            if cur:
                btns.append([f"MBTN-{stem}-{field}", "(override)", stem, field, f"`{t.rel}`", current_cell(cur), status_for(cur), "P2"])
    sections = [("Maps", HDR, maps), ("Locations", HDR, locs)]
    if btns:
        sections.append(("Radial button overrides (existing)", HDR, btns))
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("world.md", "World Map Art", "Spec: see `07_world_map.md`.", sections)


def build_dungeon(db) -> int:
    dung = []
    for t in db.get("dungeon_definition", []):
        stem = Path(t.rel).stem
        name = t.s("dungeon_name", stem)
        for field, what, hook in (("icon", "Dungeon icon (selection list 56 px)", True),
                                  ("map_background", "Dungeon map background 1080×(scrolling)", True),
                                  ("map_node_backing", "Node plate override (optional)", True)):
            cur = t.tex(field)
            dung.append([f"DGN-{stem}-{field}", f"`assets/dungeon/{stem}/dgn_{stem}_{field}.png`", name, what,
                         f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=hook), "P1" if field != "map_node_backing" else "P3"])
    for t in db.get("dungeon_chain", []):
        stem = Path(t.rel).stem
        cur = t.tex("icon")
        dung.append([f"DGN-chain-{stem}", f"`assets/dungeon/chains/chain_{stem}.png`", t.s("chain_name", stem), "Chain icon",
                     f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P2"])
    ev, sh, ra = [], [], []
    for t in db.get("dungeon_event", []):
        stem = Path(t.rel).stem
        cur = t.tex("icon")
        ev.append([f"DEV-{stem}", f"`assets/dungeon/events/evt_{stem}.png`", t.s("event_name", stem), "Event popup illustration/icon",
                   f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P2"])
    for t in db.get("dungeon_shrine", []):
        stem = Path(t.rel).stem
        cur = t.tex("icon")
        sh.append([f"DSH-{stem}", f"`assets/dungeon/shrines/shr_{stem}.png`", t.s("shrine_name", stem), "Shrine popup icon",
                   f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P2"])
    for t in db.get("run_affix_entry", []):
        stem = Path(t.rel).stem
        cur = t.tex("icon")
        ra.append([f"RAF-{stem}", f"`assets/dungeon/run_affixes/raf_{stem}.png`", t.s("display_name", stem),
                   f"Run-affix card icon (64 px) · {RARITY[t.i('rarity')] if t.i('rarity') < 5 else '?'}",
                   f"`{t.rel}`", current_cell(cur), status_for(cur), "P2"])
    sections = [("Dungeons & chains", HDR, dung), ("Events", HDR, ev), ("Shrines", HDR, sh), ("Run affixes", HDR, ra)]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("dungeon.md", "Dungeon Art",
                 "Node-type icons, node plate and player token are specced by hand in `08_dungeon.md`.", sections)


def build_misc(db) -> int:
    quests = []
    for t in db.get("quest_definition", []):
        stem = Path(t.rel).stem
        qt = QUEST_TYPE[t.i("quest_type", 1)] if t.i("quest_type", 1) < len(QUEST_TYPE) else "?"
        cur = t.tex("icon")
        quests.append([f"QST-{stem}", f"`assets/icons/quests/qst_{stem}.png`", t.s("display_name", stem), f"{qt} quest",
                       f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P3 (test quests)"])
    comps = []
    for t in db.get("crafting_component_definition", []):
        stem = Path(t.rel).stem
        cur = t.tex("icon")
        comps.append([f"CMPT-{stem}", f"`assets/icons/components/cmpt_{stem}.png`", t.s("display_name", stem),
                      "Crafting component (28 px in smithing, 32 px in character tab)", f"`{t.rel}`", current_cell(cur), status_for(cur), "P2"])
    sets = []
    for t in db.get("set_definition", []):
        stem = Path(t.rel).stem
        cur = t.tex("set_icon")
        sets.append([f"SET-{stem}", f"`assets/icons/sets/set_{stem}.png`", t.s("set_name", stem), "Equipment set icon",
                     f"`{t.rel}`", current_cell(cur), status_for(cur, hookup=True), "P3"])
    sections = [("Crafting components", HDR, comps), ("Equipment sets", HDR, sets), ("Quests", HDR, quests)]
    unique_ids([r for _, _, rows in sections for r in rows])
    return write("misc.md", "Components, Sets and Quest Icons", "Spec: see `02_ui_icons.md` and `05_items_consumables.md`.", sections)


# ---------------------------------------------------------------------------
# Coverage reports
# ---------------------------------------------------------------------------
def build_texture_fields() -> int:
    rx = re.compile(r"@export\s+var\s+(\w+)\s*:\s*(Texture2D|SpriteFrames|Texture|CompressedTexture2D|AtlasTexture)\b")
    rows = []
    for p in iter_files(".gd"):
        rel = p.relative_to(ROOT).as_posix()
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            m = rx.search(line)
            if m:
                rows.append([f"`{rel}:{n}`", p.stem, m.group(1), m.group(2)])
    rows.sort()
    return write("texture_fields.md", "Coverage: every exported texture field",
                 "Every `@export var x: Texture2D/SpriteFrames` in project scripts. Each must map to a spec section or be "
                 "listed as out of scope in `README.md`.", [("", ["Location", "Script", "Field", "Type"], rows)])


def build_texture_refs() -> int:
    refs: dict[str, set[str]] = defaultdict(set)
    rx = re.compile(r'path="(res://assets/[^"]+\.(?:png|jpg|jpeg|webp|svg))"', re.I)
    for ext in (".tscn", ".tres"):
        for p in iter_files(ext):
            rel = p.relative_to(ROOT).as_posix()
            for m in rx.finditer(p.read_text(encoding="utf-8", errors="replace")):
                refs[m.group(1)].add(rel)
    for p in iter_files(".gd"):
        rel = p.relative_to(ROOT).as_posix()
        for m in re.finditer(r'"(res://assets/[^"]+\.(?:png|jpg|webp|svg))"', p.read_text(encoding="utf-8", errors="replace")):
            refs[m.group(1)].add(rel)
    rows = []
    for path in sorted(refs):
        if "/particles/" in path:
            continue  # VFX particle kit is out of scope
        users = sorted(refs[path])
        flag = "placeholder" if PLACEHOLDER_RE.search(path) else ""
        shown = ", ".join(f"`{u}`" for u in users[:3]) + (f" +{len(users) - 3} more" if len(users) > 3 else "")
        rows.append([f"`{path.replace('res://', '')}`", png_size(path), str(len(users)), flag, shown])
    return write("texture_references.md", "Coverage: every referenced art file",
                 "Every `res://assets/...` image referenced by a scene, resource or script (particle kit excluded — VFX is "
                 "out of scope). Use this to confirm each in-use texture has a replacement row somewhere in the spec.",
                 [("", ["File", "Size", "Refs", "Flag", "Referenced by"], rows)])


def main() -> None:
    db = load_all_tres()
    counts = {
        "enemies.md": build_enemies(db),
        "items.md": build_items(db),
        "consumables.md": build_consumables(db),
        "skills.md": build_skills(db),
        "actions.md": build_actions(db),
        "statuses.md": build_statuses(db),
        "characters.md": build_characters(db),
        "world.md": build_world(db),
        "dungeon.md": build_dungeon(db),
        "misc.md": build_misc(db),
        "texture_fields.md": build_texture_fields(),
        "texture_references.md": build_texture_refs(),
    }
    index = ["# Art Manifest Index", "", "> Generated by `tools/art_manifest.py`.", "",
             "| File | Rows |", "|---|---|"]
    index += [f"| [{k}]({k}) | {v} |" for k, v in counts.items()]
    (OUT / "README.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    for k, v in counts.items():
        print(f"{k:28s} {v}")


if __name__ == "__main__":
    main()
