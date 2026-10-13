from import_collect import build_suggestions, format_line, known_quest_ids, parse_saved_variables

SAMPLE = '''
SentierDB = {
	["collect"] = {
		["enabled"] = true,
		["quests"] = {
			[91234] = {
				["title"] = "La \\"chasse\\" attend",
				["worldQuest"] = false,
				["rewards"] = {
					{
						["factionId"] = 2696,
						["amount"] = 250,
					}, -- [1]
				},
				["map"] = 2437,
				["x"] = 45.2,
				["y"] = 60.1,
				["seen"] = 1791900000,
			},
		},
	},
	["nav"] = "auto",
	["offset"] = -12.5,
}
'''


def test_parse_saved_variables_reads_wow_format():
    db = parse_saved_variables(SAMPLE)["SentierDB"]
    quest = db["collect"]["quests"][91234]
    assert quest["title"] == 'La "chasse" attend'
    assert quest["rewards"] == {1: {"factionId": 2696, "amount": 250}}
    assert quest["x"] == 45.2
    assert quest["worldQuest"] is False
    assert db["collect"]["enabled"] is True
    assert db["offset"] == -12.5
    assert db["nav"] == "auto"


def test_format_line_with_and_without_position():
    entry = {"title": "La chasse attend", "map": 2437, "x": 45.2, "y": 60.1}
    assert format_line(91234, entry, 250) == 'G:Quest(91234, { rep = 250, map = 2437, x = 45.2, y = 60.1 }) -- La chasse attend'
    assert format_line(5, {}, 75) == "G:Quest(5, { rep = 75 })"


def test_build_suggestions_skips_known_and_world_quests():
    rewards_amani = {1: {"factionId": 2696, "amount": 250}}
    collected = {
        1: {"title": "A", "rewards": rewards_amani},
        2: {"title": "B", "worldQuest": True, "rewards": rewards_amani},
        3: {"title": "C", "rewards": rewards_amani},
        4: {"title": "D", "rewards": {1: {"factionId": 2704, "amount": 50}, 2: {"factionId": 2696, "amount": 75}}},
    }
    assert build_suggestions(collected, known={3}) == {
        "Amani.lua": ["G:Quest(1, { rep = 250 }) -- A", "G:Quest(4, { rep = 75 }) -- D"],
        "Harati.lua": ["G:Quest(4, { rep = 50 }) -- D"],
    }


def test_known_quest_ids(tmp_path):
    (tmp_path / "Amani.lua").write_text("G:Quest(12, {})\nG:Quest(34, { rep = 1 })\n", encoding="utf-8")
    assert known_quest_ids(tmp_path) == {12, 34}
