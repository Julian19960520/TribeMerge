from pathlib import Path

from app.gamedata import GameData


def test_configured_level_rewards_respect_card_unlock():
    gd = GameData(str(Path(__file__).parents[2] / "data"))
    gd.level_rewards[7] = [["pack_1", 2], ["chest_1", 1], ["fire_2", 50]]
    gd.level_rewards[8] = [["pack_1", 2], ["chest_1", 1]]
    assert gd.rewards_for_level(7) == [["chest_1", 1], ["fire_2", 50]]
    assert gd.rewards_for_level(8) == [["pack_1", 2], ["chest_1", 1]]
    assert gd.level_rewards[7][0] == ["pack_1", 2]
    for level in range(2, 8):
        assert all(gd.type_of(r[0]) != "pack" for r in gd.rewards_for_level(level))
