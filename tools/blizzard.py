"""Petit client pour l'API web de Blizzard (Game Data)."""
import base64
import json
import os
import time
import urllib.parse
import urllib.request


def load_env(path):
    """Ajoute les variables d'un fichier .env à l'environnement, sans écraser l'existant."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


class Client:
    def __init__(self, client_id, client_secret, region="eu", locale="fr_FR"):
        self.client_id = client_id
        self.client_secret = client_secret
        self.region = region
        self.locale = locale
        self._token = None

    @classmethod
    def from_env(cls, env_path):
        load_env(env_path)
        return cls(os.environ["BLIZZARD_CLIENT_ID"], os.environ["BLIZZARD_CLIENT_SECRET"])

    def token(self):
        if self._token is None:
            creds = f"{self.client_id}:{self.client_secret}".encode()
            req = urllib.request.Request(
                "https://oauth.battle.net/token",
                data=b"grant_type=client_credentials",
                headers={"Authorization": "Basic " + base64.b64encode(creds).decode()},
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                self._token = json.load(resp)["access_token"]
        return self._token

    def get(self, path, attempts=4):
        query = urllib.parse.urlencode({"namespace": f"static-{self.region}", "locale": self.locale})
        url = f"https://{self.region}.api.blizzard.com{path}?{query}"
        for attempt in range(attempts):
            try:
                req = urllib.request.Request(url, headers={"Authorization": f"Bearer {self.token()}"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    return json.load(resp)
            except Exception:
                if attempt == attempts - 1:
                    raise
                time.sleep(1 + attempt)
