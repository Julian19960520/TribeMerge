"""Maintain the single editable client text catalogue and its source references.

Run --sync after adding text or moving references, and --check before publishing.
Chinese UI copy belongs in localization/texts.json; comments, resource paths,
frozen migration fixtures and offline art authoring are not runtime copy.
"""
from __future__ import annotations
import argparse
import ast
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "localization/texts.json"
CJK = re.compile(r"[\u3400-\u9fff]")
REF = re.compile(r"^§([a-z0-9_.]+)§$")
CALL = re.compile(r'\bTextCatalog\.(?:source|text)\("([a-z0-9_.]+)"\)')
PRINTF = re.compile(r"%(?:[-+ #0]*\d*(?:\.\d+)?[sdifoxXc]|%)")
TEXT_FIELDS = {"name", "title", "description", "desc", "text", "say", "badge", "entry_title", "cards", "quotes", "names", "people", "subtitle", "label", "caption"}
TEXT_CALLS = {"lbl": 1, "title": 1, "btn": 2, "toast": 0, "section": 1, "draw_string": 2, "draw_string_outline": 2, "draw_multiline_string": 2, "draw_multiline_string_outline": 2, "get_string_size": 0, "get_multiline_string_size": 0, "resource_text": 0, "resource_rich": 0}
DISPLAY_CALLS = {key: value for key, value in TEXT_CALLS.items() if key.startswith(("draw_", "get_"))}
DISPLAY_CALLS.update({"add_item": 0, "add_tab": 0, "append_text": 0, "set_item_text": 1, "set_tab_title": 1})

@dataclass
class Token:
    start: int
    end: int
    kind: str
    value: str
    line: int
    call: str = ""
    arg: int = -1


def gd_tokens(source: str) -> list[Token]:
    """A string/comment aware lexer; quotes inside comments never become copy."""
    out: list[Token] = []
    stack: list[list] = []
    i = 0
    line = 1
    previous = ""
    while i < len(source):
        c = source[i]
        if c == "#":
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
            continue
        if c.isspace():
            line += c == "\n"
            i += 1
            continue
        start, at_line = i, line
        raw_prefix = c == "r" and i + 1 < len(source) and source[i + 1] in "\"'"
        if c in "\"'" or raw_prefix:
            if raw_prefix: i += 1; c = source[i]
            quote = c * (3 if source.startswith(c * 3, i) else 1)
            i += len(quote)
            body = []
            while i < len(source) and not source.startswith(quote, i):
                if source[i] == "\\" and i + 1 < len(source):
                    body.extend(source[i:i + 2]); i += 2
                else:
                    body.append(source[i]); i += 1
            i += len(quote)
            raw = "".join(body)
            # Godot's common escapes, without corrupting non-ASCII Unicode.
            def unescape(match):
                char = match.group(1)
                return {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'", "b": "\b", "f": "\f", "v": "\v"}.get(char, "\\" + char)
            value = raw if raw_prefix else re.sub(r"\\(.)", unescape, raw, flags=re.S)
            nearest = next((s for s in reversed(stack) if s[0] == "("), None)
            out.append(Token(start, i, "string", value, at_line, nearest[1] if nearest else "", nearest[2] if nearest else -1))
            line += source[start:i].count("\n")
            previous = "string"
            continue
        if c.isalpha() or c == "_":
            i += 1
            while i < len(source) and (source[i].isalnum() or source[i] == "_"): i += 1
            previous = source[start:i]
            out.append(Token(start, i, "identifier", previous, at_line))
            continue
        if c in "([{": stack.append([c, previous if c == "(" else "", 0])
        elif c in ")]}" and stack: stack.pop()
        elif c == "," and stack: stack[-1][2] += 1
        out.append(Token(i, i + 1, "symbol", c, line))
        previous = c
        i += 1
    return out


def resource_path(value: str) -> bool:
    return "://" in value or value.startswith(("/", "./", "../")) or bool(re.search(r"\.(?:gd|tscn|png|jpe?g|svg|json|xlsx|csv|zip|bat)$", value, re.I))


def script_paths() -> list[Path]:
    out = []
    for base in (ROOT / "scripts", ROOT / "addons/tribe_config", ROOT / "addons/item_export"):
        for path in base.rglob("*.gd"):
            rel = path.relative_to(ROOT).as_posix()
            if rel.startswith(("scripts/storage/", "scripts/preview/", "scripts/sprites/", "scripts/art/", "scripts/resources/", "scripts/localization/")): continue
            if path.name.startswith("Bake"): continue
            out.append(path)
    return sorted(out)


def json_paths() -> list[Path]:
    return sorted(list((ROOT / "data").glob("*.json")) + [ROOT / "assets/characters/hero_voice.json", ROOT / "assets/characters/portraits.json"] + list((ROOT / "assets/cards").glob("*/album.json")))


def category(path: Path) -> str:
    rel = path.relative_to(ROOT).as_posix()
    if rel.startswith("server/"): return "server_notice"
    if path.name == "story.json": return "legacy_story"
    if "hero_voice" in rel or path.name == "Meme.gd": return "dialogue"
    if "ui/config/" in rel or path.name in {"CfgEdit.gd", "config_schema.gd", "config_files.gd"} or rel.startswith("addons/"): return "developer"
    if rel.startswith("scripts/ui/") or path.name in {"Main.gd", "Paint.gd", "TribeArt.gd"}: return "ui"
    if path.name in {"chains.json", "dishes.json", "reward_resources.json", "lines.json", "builds.json"}: return "names"
    if rel.startswith("assets/cards/") or path.name == "albums.json": return "cards"
    if rel.startswith("data/") or "portraits.json" in rel: return "content"
    return "notice"


def translatable(token: Token, source: str) -> bool:
    if token.kind != "string" or not token.value or resource_path(token.value) or REF.fullmatch(token.value): return False
    if CJK.search(token.value): return True
    # A key nested inside a display expression is still an identifier.
    if re.search(r"\[\s*$", source[:token.start]) and re.match(r"\s*\]", source[token.end:]): return False
    display = token.call in TEXT_CALLS and token.arg == TEXT_CALLS[token.call]
    if not display:
        display = bool(re.search(r"\b(?:text|tooltip_text|placeholder_text|title)\s*=\s*$", source[max(0, token.start - 80):token.start]))
    return display and (bool(re.search(r"[a-zA-Z]{2,}", token.value)) or bool(re.search(r"[\u3000-\u303f\uff00-\uffef]", token.value)))


def json_strings(source: str):
    """Yield JSON value strings and pointers, preserving the original file layout."""
    decoder = json.JSONDecoder()
    def spaces(i):
        while i < len(source) and source[i].isspace(): i += 1
        return i
    def parse(i, pointer):
        i = spaces(i)
        if source[i] == '"':
            value, end = decoder.raw_decode(source, i)
            yield pointer, value, i, end
            return end
        if source[i] == "{":
            i = spaces(i + 1)
            while source[i] != "}":
                key, i = decoder.raw_decode(source, i)
                i = spaces(i); assert source[i] == ":"
                i = yield from parse(i + 1, pointer + [key])
                i = spaces(i)
                if source[i] == ",": i = spaces(i + 1)
                else: break
            return i + 1
        if source[i] == "[":
            i = spaces(i + 1); index = 0
            while source[i] != "]":
                i = yield from parse(i, pointer + [index]); index += 1
                i = spaces(i)
                if source[i] == ",": i = spaces(i + 1)
                else: break
            return i + 1
        _, end = decoder.raw_decode(source, i)
        return end
    yield from parse(0, [])


def json_copy(pointer, value) -> bool:
    if not value or resource_path(value) or REF.fullmatch(value): return False
    if any(str(part).startswith("_") or str(part) in {"reference", "prompt", "notes", "style_reference", "license"} for part in pointer): return False
    field = next((str(p) for p in reversed(pointer) if not isinstance(p, int)), "")
    return bool(CJK.search(value)) or field in TEXT_FIELDS and bool(re.search(r"[a-zA-Z]{2,}", value)) and not re.fullmatch(r"[a-z_]+_[0-9]+", value)


def apply(source: str, changes: list[tuple[int, int, str]]) -> str:
    for start, end, value in sorted(changes, reverse=True): source = source[:start] + value + source[end:]
    return source


def display_spans(source: str, path: Path):
    """Yield terminal display expressions, keeping editable input values canonical."""
    tokens = gd_tokens(source)
    for i, token in enumerate(tokens):
        if token.kind != "identifier": continue
        if token.value in DISPLAY_CALLS and i + 1 < len(tokens) and tokens[i + 1].value == "(":
            start = i + 2; depth = 0; arg = 0
            for j in range(start, len(tokens)):
                t = tokens[j]
                boundary = depth == 0 and t.value in {",", ")"} and t.kind == "symbol"
                if boundary:
                    if arg == DISPLAY_CALLS[token.value] and j > start:
                        yield tokens[start].start, tokens[j - 1].end
                        break
                    if t.value == ")": break
                    arg += 1; start = j + 1
                elif t.kind == "symbol":
                    if t.value in "([{": depth += 1
                    elif t.value in ")]}": depth -= 1
        if token.value not in {"text", "tooltip_text", "placeholder_text", "title"}: continue
        if i < 2 or tokens[i - 1].value != "." or i + 2 >= len(tokens) or tokens[i + 1].value != "=": continue
        if tokens[i + 2].value == "=": continue
        receiver = tokens[i - 2].value
        if token.value == "text" and receiver in {"edit", "e", "_search"}: continue
        start = i + 2; depth = 0; end = start
        for j in range(start, len(tokens)):
            t = tokens[j]
            if j > start and depth == 0 and t.line > tokens[j - 1].line and tokens[j - 1].value != "\\": break
            if t.kind == "symbol":
                if depth == 0 and t.value in {",", ";", ")", "]", "}"}: break
                if t.value in "([{": depth += 1
                elif t.value in ")]}": depth -= 1
            end = j + 1
        if end > start:
            expression = source[tokens[start].start:tokens[end - 1].end]
            if expression.startswith(("UI.resource_text(", "UI.resource_rich(", "resource_text(", "resource_rich(")): continue
            yield tokens[start].start, tokens[end - 1].end


def bind_displays(path: Path, source: str, sync: bool, errors: list[str]) -> str:
    rel = path.relative_to(ROOT).as_posix()
    if not (rel.startswith(("scripts/ui/", "addons/")) or path.name in {"Paint.gd", "Main.gd", "Meme.gd"}): return source
    changes = []
    for start, end in set(display_spans(source, path)):
        expression = source[start:end]
        # TButton translates once in its setter; drawing consumes the display value.
        if path.name == "TButton.gd" and expression == "text": continue
        if expression.startswith("TextCatalog.resolve("): continue
        # Empty literals, punctuation and numeric counters do not need translation.
        if re.fullmatch(r'"[^A-Za-z\u3400-\u9fff]*"', expression): continue
        if not sync: errors.append(f"{rel}:{source.count(chr(10), 0, start) + 1}: unbound display expression"); continue
        changes.extend([(start, start, "TextCatalog.resolve("), (end, end, ")")])
    return apply(source, changes)


def const_spans(source: str):
    tokens = gd_tokens(source)
    for i, token in enumerate(tokens):
        if token.kind != "identifier" or token.value != "const": continue
        depth = 0; end = len(source)
        for j in range(i + 1, len(tokens)):
            t = tokens[j]
            if depth == 0 and t.line > tokens[j - 1].line:
                end = t.start; break
            if t.kind == "symbol":
                if t.value in "([{": depth += 1
                elif t.value in ")]}": depth -= 1
        yield token, end


def format_signature(value: str) -> list[str]:
    return [m.group()[-1].lower().replace("i", "d") for m in PRINTF.finditer(value) if m.group() != "%%"]


def server_strings(source: str):
    offsets = [0]
    for line in source.splitlines(keepends=True): offsets.append(offsets[-1] + len(line))
    def position(line, column):
        raw = source[offsets[line - 1]:offsets[line]].encode()
        return offsets[line - 1] + len(raw[:column].decode())
    def literals(node):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "text_source": return
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            if CJK.search(node.value) or node.value == "Not Found":
                yield node.value, position(node.lineno, node.col_offset), position(node.end_lineno, node.end_col_offset)
        else:
            for child in ast.iter_child_nodes(node): yield from literals(child)
    for node in ast.walk(ast.parse(source)):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Name): continue
        argument = 2 if node.func.id == "ApiError" else 1 if node.func.id == "body" else -1
        if argument >= 0 and len(node.args) > argument: yield from literals(node.args[argument])


def reference_scope(ref: str) -> str:
    if ref.startswith("data/story.json#"): return "legacy_story"
    if ref.startswith(("addons/", "scripts/ui/config/", "scripts/ui/CfgEdit.gd:", "scripts/ui/OrderCurvePad.gd:", "scripts/config/")): return "developer"
    return "runtime"


def maintain(sync: bool) -> dict:
    document = json.loads(CATALOG.read_text()) if CATALOG.exists() else {"schema": 1, "default_locale": "zh_CN", "locales": ["zh_CN", "en_US"], "entries": {}}
    entries = document["entries"]
    by_source = {entry["source"]: key for key, entry in entries.items()}
    errors = []
    def register(value, path):
        if value in by_source: return by_source[value]
        group = category(path)
        stem = re.sub(r"[^a-z0-9]+", "_", path.stem.lower()).strip("_")
        key = group + "." + stem + "." + hashlib.sha256(value.encode()).hexdigest()[:12]
        entries[key] = {"category": group, "source": value, "zh_CN": value, "en_US": "", "refs": []}
        by_source[value] = key
        return key
    for path in script_paths():
        source = path.read_text(); changes = []; changed = []
        for token in gd_tokens(source):
            if not translatable(token, source): continue
            if not sync:
                errors.append(f"{path.relative_to(ROOT)}:{token.line}: unmanaged text {token.value[:60]!r}"); continue
            key = register(token.value, path)
            changes.append((token.start, token.end, f'TextCatalog.source("{key}")'))
            changed.append(token.start)
        for token, end in const_spans(source):
            if any(token.start < start < end for start in changed):
                prefix = source[source.rfind("\n", 0, token.start) + 1:token.start]
                changes.append((token.start, token.end, "var" if prefix.strip() == "" and prefix else "static var"))
        updated = bind_displays(path, apply(source, changes), sync, errors)
        if updated != source: path.write_text(updated)
    for path in json_paths():
        source = path.read_text(); changes = []
        for pointer, value, start, end in json_strings(source):
            if not json_copy(pointer, value): continue
            if not sync:
                errors.append(f"{path.relative_to(ROOT)}#/{'/'.join(map(str, pointer))}: unmanaged text {value[:50]!r}"); continue
            key = register(value, path)
            changes.append((start, end, json.dumps("§" + key + "§", ensure_ascii=False)))
        if changes: path.write_text(apply(source, changes))
    for path in sorted((ROOT / "server/app").glob("*.py")):
        source = path.read_text(); changes = []
        for value, start, end in server_strings(source):
            if not sync:
                errors.append(f"{path.relative_to(ROOT)}: unmanaged server copy {value!r}"); continue
            key = register(value, path)
            changes.append((start, end, f'text_source("{key}")'))
        if changes:
            source = apply(source, changes)
            if "from .texts import source as text_source" not in source:
                tree = ast.parse(source)
                imports = [node for node in tree.body if isinstance(node, (ast.Import, ast.ImportFrom))]
                at_line = imports[-1].end_lineno if imports else tree.body[0].end_lineno if ast.get_docstring(tree) else 0
                lines = source.splitlines(keepends=True)
                lines.insert(at_line, "from .texts import source as text_source\n")
                source = "".join(lines)
            path.write_text(source)
    actual = {key: [] for key in entries}
    for path in script_paths():
        source = path.read_text()
        for match in CALL.finditer(source):
            key = match.group(1)
            ref = f"{path.relative_to(ROOT).as_posix()}:{source.count(chr(10), 0, match.start()) + 1}"
            if key not in actual: errors.append(ref + ": missing catalogue key " + key)
            else: actual[key].append(ref)
    for path in json_paths():
        for pointer, value, _, _ in json_strings(path.read_text()):
            if not (match := REF.fullmatch(value)): continue
            key = match.group(1)
            ref = path.relative_to(ROOT).as_posix() + "#/" + "/".join(str(p).replace("~", "~0").replace("/", "~1") for p in pointer)
            if key not in actual: errors.append(ref + ": missing catalogue key " + key)
            else: actual[key].append(ref)
    web = ROOT / "tools/export_web.py"
    for match in re.finditer(r'web_text\("([a-z0-9_.]+)"\)', web.read_text()):
        key = match.group(1)
        if key not in actual: errors.append("tools/export_web.py: missing catalogue key " + key)
        else: actual[key].append("tools/export_web.py:" + str(web.read_text().count(chr(10), 0, match.start()) + 1))
    for path in sorted((ROOT / "server/app").glob("*.py")):
        source = path.read_text()
        for match in re.finditer(r'text_source\("([a-z0-9_.]+)"\)', source):
            key = match.group(1)
            ref = path.relative_to(ROOT).as_posix() + ":" + str(source.count(chr(10), 0, match.start()) + 1)
            if key not in actual: errors.append(ref + ": missing catalogue key " + key)
            else: actual[key].append(ref)
    counts = Counter(); scopes = Counter(); active = 0; references = 0
    for key, entry in entries.items():
        if key.rsplit(".", 1)[-1] != hashlib.sha256(entry["source"].encode()).hexdigest()[:12]: errors.append(key + ": source identity changed; edit locale fields instead of source")
        expected = format_signature(entry["source"])
        for locale in document["locales"]:
            value = entry.get(locale, "")
            if not isinstance(value, str): errors.append(key + ": invalid locale value " + locale)
            elif value and format_signature(value) != expected: errors.append(key + ": placeholder mismatch in " + locale)
        refs = sorted(set(actual[key]))
        used_scopes = {reference_scope(ref) for ref in refs}
        scope = "runtime" if "runtime" in used_scopes else ("developer" if "developer" in used_scopes else "legacy_story")
        if sync:
            entry["refs"] = refs
            entry["scope"] = scope
            entry["placeholders"] = expected
        elif entry.get("refs") != refs: errors.append(key + ": references changed; run --sync")
        elif entry.get("scope") != scope or entry.get("placeholders") != expected: errors.append(key + ": metadata changed; run --sync")
        if refs:
            active += 1; references += len(refs); counts[entry["category"]] += 1; scopes[scope] += 1
    stats = {"unique_texts": active, "references": references, "scopes": dict(sorted(scopes.items())), "categories": dict(sorted(counts.items())), "translated": {locale: sum(bool(entry.get(locale)) for entry in entries.values() if actual[by_source[entry['source']]]) for locale in document["locales"]}}
    if sync:
        document["stats"] = stats
        document["entries"] = dict(sorted(((key, entry) for key, entry in entries.items() if actual[key]), key=lambda pair: (pair[1]["category"], pair[0])))
        ordered = {key: document[key] for key in ("schema", "default_locale", "locales", "stats", "entries")}
        ordered.update({key: value for key, value in document.items() if key not in ordered})
        CATALOG.parent.mkdir(exist_ok=True)
        CATALOG.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n")
    elif document.get("stats") != stats: errors.append("Catalogue statistics changed; run --sync")
    if errors: raise SystemExit("\n".join(errors[:80]))
    return stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--sync", action="store_true"); mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    print(json.dumps(maintain(args.sync), ensure_ascii=False))
    print("PASS client text catalogue")


if __name__ == "__main__": main()
