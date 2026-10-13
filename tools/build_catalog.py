"""Génère Sentier/Guides/Reputation/Midnight/Catalog.lua depuis l'API Blizzard.

Usage : python3 tools/build_catalog.py   (identifiants lus dans .env)
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from blizzard import Client

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Sentier" / "Guides" / "Reputation" / "Midnight" / "Catalog.lua"

# Zones de quêtes de Midnight dans l'API (relevées le 2026-10-13, build 12.1.0_68914).
MIDNIGHT_AREAS = {
    15355: "Harandar",
    15947: "Zul’Aman",
    15968: "Bois des Chants éternels",
    15969: "Lune-d’Argent",
    16340: "La flèche du Vide",
    16648: "Tempête du Vide",
}


def fetch_catalog(client, areas=MIDNIGHT_AREAS, workers=3):
    catalog = {}
    for area_id in sorted(areas):
        quests = client.get(f"/data/wow/quest/area/{area_id}").get("quests", [])
        ids = [qid for qid in dict.fromkeys(q["id"] for q in quests) if qid not in catalog]
        with ThreadPoolExecutor(workers) as pool:
            details = list(pool.map(lambda qid: client.get(f"/data/wow/quest/{qid}"), ids))
        for detail in details:
            catalog[detail["id"]] = {
                "title": detail.get("title") or "",
                "zone": areas[area_id],
                "area": area_id,
                "min_level": (detail.get("requirements") or {}).get("min_character_level"),
            }
    return catalog


def lua_string(value):
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\r", "").replace("\n", "\\n")
    return f'"{escaped}"'


def render_lua(catalog):
    lines = [
        "-- Généré par tools/build_catalog.py. Ne pas modifier à la main.",
        "local _, ns = ...",
        "ns.MidnightCatalog = {",
    ]
    for qid in sorted(catalog):
        q = catalog[qid]
        level = q["min_level"] if q["min_level"] is not None else "nil"
        lines.append(
            f'  [{qid}] = {{ title = {lua_string(q["title"])}, zone = {lua_string(q["zone"])}, '
            f'area = {q["area"]}, minLevel = {level} }},'
        )
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    catalog = fetch_catalog(Client.from_env(ROOT / ".env"))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(render_lua(catalog), encoding="utf-8")
    print(f"{len(catalog)} quêtes écrites dans {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
