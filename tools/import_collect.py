"""Transforme les données du mode collecte en lignes prêtes à coller dans les guides.

Usage : python3 tools/import_collect.py "<WoW>/_retail_/WTF/Account/<COMPTE>/SavedVariables/Sentier.lua"
"""
import re
import sys
from pathlib import Path

GUIDES_DIR = Path(__file__).resolve().parent.parent / "Sentier" / "Guides" / "Reputation" / "Midnight"

FACTION_FILES = {
    2696: "Amani.lua",
    2699: "Singularity.lua",
    2704: "Harati.lua",
    2710: "SilvermoonCourt.lua",
    2772: "ZuljarraForces.lua",
}

NUMBER = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
FIELD = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "\n": "\n"}


class LuaParser:
    """Lit les tables Lua littérales écrites par WoW dans les SavedVariables."""

    def __init__(self, text):
        self.s = text
        self.i = 0

    def skip(self):
        while self.i < len(self.s):
            if self.s[self.i] in " \t\r\n":
                self.i += 1
            elif self.s.startswith("--", self.i):
                end = self.s.find("\n", self.i)
                self.i = len(self.s) if end < 0 else end + 1
            else:
                break

    def expect(self, token):
        self.skip()
        if not self.s.startswith(token, self.i):
            raise ValueError(f"'{token}' attendu à la position {self.i}")
        self.i += len(token)

    def parse_file(self):
        out = {}
        while True:
            self.skip()
            if self.i >= len(self.s):
                return out
            m = IDENT.match(self.s, self.i)
            if not m:
                raise ValueError(f"nom attendu à la position {self.i}")
            self.i = m.end()
            self.expect("=")
            out[m.group()] = self.value()

    def value(self):
        self.skip()
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c == '"':
            return self.string()
        for word, val in (("true", True), ("false", False), ("nil", None)):
            if self.s.startswith(word, self.i):
                self.i += len(word)
                return val
        m = NUMBER.match(self.s, self.i)
        if not m:
            raise ValueError(f"valeur inattendue à la position {self.i}")
        self.i = m.end()
        text = m.group()
        return float(text) if any(ch in text for ch in ".eE") else int(text)

    def string(self):
        self.i += 1
        out = []
        while True:
            c = self.s[self.i]
            if c == '"':
                self.i += 1
                return "".join(out)
            if c == "\\":
                nxt = self.s[self.i + 1]
                if nxt.isdigit():
                    digits = re.match(r"\d{1,3}", self.s[self.i + 1:]).group()
                    out.append(chr(int(digits)))
                    self.i += 1 + len(digits)
                    continue
                out.append(ESCAPES.get(nxt, nxt))
                self.i += 2
                continue
            out.append(c)
            self.i += 1

    def table(self):
        self.i += 1
        out = {}
        n = 1
        while True:
            self.skip()
            if self.s[self.i] == "}":
                self.i += 1
                return out
            if self.s[self.i] == "[":
                self.i += 1
                key = self.value()
                self.expect("]")
                self.expect("=")
                out[key] = self.value()
            else:
                m = FIELD.match(self.s, self.i)
                if m and m.group(1) not in ("true", "false", "nil"):
                    self.i = m.end()
                    out[m.group(1)] = self.value()
                else:
                    out[n] = self.value()
                    n += 1
            self.skip()
            if self.i < len(self.s) and self.s[self.i] in ",;":
                self.i += 1


def parse_saved_variables(text):
    return LuaParser(text).parse_file()


def as_list(value):
    if isinstance(value, dict):
        return [value[k] for k in sorted(value)]
    return value or []


def known_quest_ids(guides_dir):
    ids = set()
    for path in Path(guides_dir).glob("*.lua"):
        ids.update(int(m) for m in re.findall(r"G:Quest\((\d+)", path.read_text(encoding="utf-8")))
    return ids


def format_line(quest_id, entry, amount):
    parts = [f"rep = {amount}"]
    if entry.get("map") is not None and entry.get("x") is not None and entry.get("y") is not None:
        parts.append(f"map = {int(entry['map'])}, x = {entry['x']:.1f}, y = {entry['y']:.1f}")
    line = f"G:Quest({quest_id}, {{ {', '.join(parts)} }})"
    title = entry.get("title")
    return f"{line} -- {title}" if title else line


def build_suggestions(collected, known):
    result = {}
    for quest_id in sorted(collected):
        entry = collected[quest_id]
        if entry.get("worldQuest") or quest_id in known:
            continue
        for reward in as_list(entry.get("rewards")):
            file = FACTION_FILES.get(int(reward.get("factionId", 0)))
            if file:
                result.setdefault(file, []).append(format_line(quest_id, entry, int(reward["amount"])))
    return result


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 1
    data = parse_saved_variables(Path(argv[1]).read_text(encoding="utf-8"))
    collected = ((data.get("SentierDB") or {}).get("collect") or {}).get("quests") or {}
    suggestions = build_suggestions({int(k): v for k, v in collected.items()}, known_quest_ids(GUIDES_DIR))
    if not suggestions:
        print("Rien de nouveau à ajouter.")
        return 0
    for file in sorted(suggestions):
        print(f"\n-- {file}")
        for line in suggestions[file]:
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
