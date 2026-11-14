"""Copy extraction must keep comments, lookup keys and player input out of copy."""
import importlib.util
from pathlib import Path
import sys
import unittest

SPEC = importlib.util.spec_from_file_location("text_catalog", Path(__file__).resolve().parents[1] / "text_catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = catalog
SPEC.loader.exec_module(catalog)


class TextCatalogueTests(unittest.TestCase):
    def test_comments_escaped_quotes_and_raw_literals(self):
        source = '# "不要提取"\nvar a = "兄弟，\\\"发现\\\"\\n了" # "也不要"\nvar b = r"野莓\\n"\n'
        strings = [token for token in catalog.gd_tokens(source) if token.kind == "string"]
        self.assertEqual([token.value for token in strings], ['兄弟，"发现"\n了', r'野莓\n'])
        self.assertEqual(source[strings[1].start:strings[1].end], 'r"野莓\\n"')

    def test_lookup_key_inside_label_is_not_copy(self):
        source = 'UI.btn(parent, rect, a["price"], "orange", Callable())\nUI.lbl(parent, "GM", rect)'
        actual = [token.value for token in catalog.gd_tokens(source) if catalog.translatable(token, source)]
        self.assertEqual(actual, ["GM"])

    def test_json_value_positions_preserve_keys_and_format(self):
        source = '{"名字": ["野莓", {"name": "核桃"}], "count": 1}'
        values = list(catalog.json_strings(source))
        self.assertEqual([(path, value) for path, value, *_ in values], [(["名字", 0], "野莓"), (["名字", 1, "name"], "核桃")])
        for _, value, start, end in values:
            self.assertEqual(source[start:end], '"' + value + '"')

    def test_json_tags_and_resource_paths_stay_identifiers(self):
        self.assertFalse(catalog.json_copy(["orders", 0, "tag"], "level2_first"))
        self.assertFalse(catalog.json_copy(["art", 0], "res://assets/参考图.png"))
        self.assertTrue(catalog.json_copy(["title"], "HOT"))
        self.assertTrue(catalog.json_copy(["tag"], "赠送"))

    def test_display_bindings_preserve_editable_values_and_lambda_closure(self):
        source = 'e.text = text\nlabel.text = "%d级" % level\nupdate.connect(func(): label.text = message)\n'
        expressions = [source[start:end] for start, end in catalog.display_spans(source, Path("Test.gd"))]
        self.assertEqual(expressions, ['"%d级" % level', "message"])

    def test_server_messages_exclude_comments_and_existing_getters(self):
        source = '# ApiError(400, "id", "注释")\nraise ApiError(400, "id", "%s 登录" % provider)\nraise ApiError(400, "id", text_source("notice.key"))'
        self.assertEqual([value for value, *_ in catalog.server_strings(source)], ["%s 登录"])

    def test_placeholder_types_order_and_percent_escape(self):
        self.assertEqual(catalog.format_signature("%s / %02d / %.1f%%"), ["s", "d", "f"])
        self.assertNotEqual(catalog.format_signature("%s %d"), catalog.format_signature("%d %s"))


if __name__ == "__main__": unittest.main()
