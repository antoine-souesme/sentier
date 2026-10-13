from build_catalog import fetch_catalog, lua_string, render_lua


class FakeClient:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def get(self, path):
        self.calls.append(path)
        return self.responses[path]


def test_lua_string_escapes_quotes_backslashes_and_newlines():
    assert lua_string('a "b" \\ c\r\nd') == '"a \\"b\\" \\\\ c\\nd"'


def test_fetch_catalog_dedupes_quests_and_reads_levels():
    client = FakeClient({
        "/data/wow/quest/area/1": {"quests": [{"id": 10}, {"id": 11}]},
        "/data/wow/quest/area/2": {"quests": [{"id": 11}, {"id": 12}]},
        "/data/wow/quest/10": {"id": 10, "title": "Dix", "requirements": {"min_character_level": 83}},
        "/data/wow/quest/11": {"id": 11, "title": "Onze"},
        "/data/wow/quest/12": {"id": 12, "title": "Douze"},
    })
    catalog = fetch_catalog(client, {1: "Zone A", 2: "Zone B"}, workers=1)
    assert catalog == {
        10: {"title": "Dix", "zone": "Zone A", "area": 1, "min_level": 83},
        11: {"title": "Onze", "zone": "Zone A", "area": 1, "min_level": None},
        12: {"title": "Douze", "zone": "Zone B", "area": 2, "min_level": None},
    }
    assert client.calls.count("/data/wow/quest/11") == 1


def test_render_lua_is_sorted_and_valid():
    text = render_lua({
        12: {"title": "Douze", "zone": "Zone B", "area": 2, "min_level": None},
        10: {"title": "Dix", "zone": "Zone A", "area": 1, "min_level": 83},
    })
    lines = text.splitlines()
    assert lines[1] == "local _, ns = ..."
    assert lines[2] == "ns.MidnightCatalog = {"
    assert lines[3] == '  [10] = { title = "Dix", zone = "Zone A", area = 1, minLevel = 83 },'
    assert lines[4] == '  [12] = { title = "Douze", zone = "Zone B", area = 2, minLevel = nil },'
    assert lines[5] == "}"


def test_untitled_quest_is_stored_as_none_and_rendered_as_nil():
    client = FakeClient({
        "/data/wow/quest/area/1": {"quests": [{"id": 20}, {"id": 21}]},
        "/data/wow/quest/20": {"id": 20, "title": ""},
        "/data/wow/quest/21": {"id": 21},
    })
    catalog = fetch_catalog(client, {1: "Zone A"}, workers=1)
    assert catalog[20]["title"] is None
    assert catalog[21]["title"] is None
    text = render_lua(catalog)
    lines = text.splitlines()
    assert lines[0] == "-- Généré par tools/build_catalog.py. Ne pas modifier à la main."
    assert lines[3] == '  [20] = { title = nil, zone = "Zone A", area = 1, minLevel = nil },'
