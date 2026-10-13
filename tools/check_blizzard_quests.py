"""Vérifie ce que l'API Blizzard renvoie pour les quêtes des zones de Midnight.

Usage : BLIZZARD_CLIENT_ID=... BLIZZARD_CLIENT_SECRET=... python3 tools/check_blizzard_quests.py
"""
import base64
import json
import os
import sys
import urllib.parse
import urllib.request

REGION = "eu"
LOCALE = "fr_FR"
MIDNIGHT_ZONES = ("éclat", "eversong", "zul'aman", "harandar", "voidstorm", "lune-d'argent", "silvermoon", "vide")
QUESTS_PER_ZONE = 5


def get_token():
    creds = f"{os.environ['BLIZZARD_CLIENT_ID']}:{os.environ['BLIZZARD_CLIENT_SECRET']}"
    req = urllib.request.Request(
        "https://oauth.battle.net/token",
        data=b"grant_type=client_credentials",
        headers={"Authorization": "Basic " + base64.b64encode(creds.encode()).decode()},
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["access_token"]


def api(token, path):
    query = urllib.parse.urlencode({"namespace": f"static-{REGION}", "locale": LOCALE})
    req = urllib.request.Request(
        f"https://{REGION}.api.blizzard.com{path}?{query}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def main():
    token = get_token()
    areas = api(token, "/data/wow/quest/area/index")["areas"]
    matches = [a for a in areas if any(z in (a.get("name") or "").lower() for z in MIDNIGHT_ZONES)]
    print(f"{len(areas)} zones au total, {len(matches)} qui ressemblent à Midnight :")
    for area in matches:
        print(f"  {area['id']} {area['name']}")

    for area in matches:
        quests = api(token, f"/data/wow/quest/area/{area['id']}").get("quests", [])
        print(f"\n=== {area['name']} : {len(quests)} quêtes ===")
        for quest in quests[:QUESTS_PER_ZONE]:
            detail = api(token, f"/data/wow/quest/{quest['id']}")
            print(json.dumps(detail, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if not os.environ.get("BLIZZARD_CLIENT_ID"):
        sys.exit("Il manque BLIZZARD_CLIENT_ID et BLIZZARD_CLIENT_SECRET.")
    main()
