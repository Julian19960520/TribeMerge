"""Maintain the client text catalogue.

Editable copy is split by feature under localization/texts/<group>/<feature>.json.
Each entry is a key plus its languages. localization/texts.json lists those files.
Run --sync after adding text, and --check before publishing.
Comments, resource paths, frozen migration fixtures and offline art authoring
are not runtime copy.
"""
from __future__ import annotations
import argparse
import ast
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "localization/texts.json"
PARTS = CATALOG.parent / "texts"
CJK = re.compile(r"[\u3400-\u9fff]")
REF = re.compile(r"^§([a-z0-9_.]+)§$")
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


def join_key(path: Path, part: dict, local: str) -> str:
    feature = str(part.get("feature") or path.stem)
    prefix = f"{path.parent.name}.{feature}."
    return local if local.startswith(prefix) else prefix + local


def own_key(category_name: str, feature: str, key: str) -> str:
    prefix = f"{category_name}.{feature}."
    if not key.startswith(prefix) or key == prefix:
        raise SystemExit("text key is outside its feature file: " + key)
    return key[len(prefix):]


def feature_of(key: str) -> tuple[str, str]:
    category_name, feature, _identity = key.split(".", 2)
    if not re.fullmatch(r"[a-z0-9_]+", category_name) or not re.fullmatch(r"[a-z0-9_]+", feature):
        raise SystemExit("text key is not a feature file name: " + key)
    return category_name, feature


def part_paths(document: dict) -> list[Path]:
    paths: list[Path] = []
    seen: set[Path] = set()
    for relative in document.get("files", []):
        path = (CATALOG.parent / relative).resolve()
        if path not in seen:
            paths.append(path)
            seen.add(path)
    if PARTS.exists():
        for path in sorted(PARTS.rglob("*.json")):
            resolved = path.resolve()
            if resolved not in seen:
                paths.append(resolved)
                seen.add(resolved)
    return paths


def load_document() -> dict:
    document = json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {"schema": 1, "default_locale": "zh_CN", "locales": ["zh_CN"], "entries": {}}
    paths = part_paths(document)
    if not paths:
        document.setdefault("entries", {})
        return document
    entries: dict = {}
    for path in paths:
        part = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in part.get("entries", {}).items():
            full = join_key(path, part, key)
            if full in entries:
                raise SystemExit("duplicate text key " + full)
            category_name, feature = feature_of(full)
            expected = PARTS / category_name / f"{feature}.json"
            if path.resolve() != expected.resolve():
                raise SystemExit(f"{full} belongs in {expected.relative_to(ROOT).as_posix()}, not {path.relative_to(ROOT).as_posix()}")
            entries[full] = entry
    document["entries"] = entries
    return document


def copy_of(entry: dict) -> str:
    value = entry.get("zh_CN", "")
    return value if isinstance(value, str) else ""


def stored_entry(entry: dict) -> dict:
    stored = {"zh_CN": entry.get("zh_CN", "")}
    for locale, value in entry.items():
        if locale != "zh_CN" and isinstance(value, str) and value:
            stored[locale] = value
    return stored


def onboarding_stage(key: str) -> int:
    if not hasattr(onboarding_stage, "order"):
        order = {}
        document = json.loads((ROOT / "data/onboarding.json").read_text(encoding="utf-8"))
        for index, stage in enumerate(document.get("stages", [])):
            match = REF.fullmatch(str(stage.get("text", "")))
            if match:
                order.setdefault(match.group(1), index)
        onboarding_stage.order = order
    return onboarding_stage.order.get(key, 10**9)


def ordered_entries(category_name: str, feature: str, entries: dict) -> dict:
    if (category_name, feature) != ("content", "onboarding"):
        ordered = sorted(entries.items())
    else:
        ordered = sorted(entries.items(), key=lambda item: (onboarding_stage(item[0]), item[0]))
    return {own_key(category_name, feature, key): stored_entry(entry) for key, entry in ordered}


def save_document(document: dict) -> None:
    grouped: dict[tuple[str, str], dict] = {}
    for key, entry in document["entries"].items():
        grouped.setdefault(feature_of(key), {})[key] = entry
    files: list[str] = []
    used: set[Path] = set()
    for (category_name, feature), entries in sorted(grouped.items()):
        relative = f"texts/{category_name}/{feature}.json"
        path = CATALOG.parent / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        body = {"feature": feature, "entries": ordered_entries(category_name, feature, entries)}
        path.write_text(json.dumps(body, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        files.append(relative)
        used.add(path.resolve())
    if PARTS.exists():
        for path in PARTS.rglob("*.json"):
            if path.resolve() not in used:
                path.unlink()
        for path in sorted((item for item in PARTS.rglob("*") if item.is_dir()), reverse=True):
            if not any(path.iterdir()):
                path.rmdir()
    locales = ["zh_CN"]
    for grouped_entries in grouped.values():
        for entry in grouped_entries.values():
            for locale, value in stored_entry(entry).items():
                if locale not in locales and value:
                    locales.append(locale)
    document["locales"] = locales
    document["stats"] = {"unique_texts": len(document["entries"]), "translated": {locale: sum(bool(stored_entry(entry).get(locale)) for entry in document["entries"].values()) for locale in locales}}
    manifest = {key: document[key] for key in ("schema", "default_locale", "locales", "stats") if key in document}
    manifest["files"] = files
    CATALOG.parent.mkdir(exist_ok=True)
    CATALOG.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def maintain(sync: bool) -> dict:
    document = load_document()
    entries = document["entries"]
    by_copy = {}
    for key, entry in entries.items():
        text = copy_of(entry)
        if text and text not in by_copy:
            by_copy[text] = key
    errors = []
    def register(value, path):
        if value in by_copy: return by_copy[value]
        group = category(path)
        stem = re.sub(r"[^a-z0-9]+", "_", path.stem.lower()).strip("_")
        key = group + "." + stem + "." + hashlib.sha256(value.encode()).hexdigest()[:12]
        entries[key] = {"zh_CN": value}
        by_copy[value] = key
        return key
    for path in script_paths():
        source = path.read_text(encoding="utf-8"); changes = []; changed = []
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
        if updated != source: path.write_text(updated, encoding="utf-8")
    for path in json_paths():
        source = path.read_text(encoding="utf-8"); changes = []
        for pointer, value, start, end in json_strings(source):
            if not json_copy(pointer, value): continue
            if not sync:
                errors.append(f"{path.relative_to(ROOT)}#/{'/'.join(map(str, pointer))}: unmanaged text {value[:50]!r}"); continue
            key = register(value, path)
            changes.append((start, end, json.dumps("§" + key + "§", ensure_ascii=False)))
        if changes: path.write_text(apply(source, changes), encoding="utf-8")
    for path in sorted((ROOT / "server/app").glob("*.py")):
        source = path.read_text(encoding="utf-8"); changes = []
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
            path.write_text(source, encoding="utf-8")
    for key, entry in entries.items():
        if copy_of(entry) == "": errors.append(key + ": missing zh_CN")
        for locale in document["locales"]:
            if not isinstance(entry.get(locale, ""), str): errors.append(key + ": invalid locale value " + locale)
    stats = {"unique_texts": len(entries), "translated": {locale: sum(bool(entry.get(locale)) for entry in entries.values()) for locale in document["locales"]}}
    if sync:
        document["stats"] = stats
        document["entries"] = dict(sorted(entries.items()))
        save_document(document)
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
