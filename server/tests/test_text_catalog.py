from app import catalog
from app.texts import catalogue, hydrate, source


def test_canonical_messages_and_config_names_are_hydrated():
    entries = catalogue()
    key = next(key for key, entry in entries.items() if entry["zh_CN"] == "小草篓")
    assert source(key) == "小草篓"
    assert hydrate({"items": ["§" + key + "§"], "count": 2}) == {"items": ["小草篓"], "count": 2}
    assert not any("§" in str(chain) for chain in catalog.data("chains.json"))


def test_api_messages_read_the_current_chinese_copy():
    entries = catalogue()
    key = next(key for key, entry in entries.items() if entry["zh_CN"] == "账号不存在")
    original = entries[key]["zh_CN"]
    try:
        entries[key]["zh_CN"] = "测试显示文案"
        assert source(key) == "测试显示文案"
    finally:
        entries[key]["zh_CN"] = original
