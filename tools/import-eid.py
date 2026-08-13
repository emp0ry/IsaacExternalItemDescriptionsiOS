#!/usr/bin/env python3
"""Import user-supplied EID English data without vendoring the upstream project."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


ENTRY = re.compile(r"^\s*(?:\[(\d+)\]\s*=\s*)?\{")


def read_lua_string(text: str, start: int) -> tuple[str, int]:
    while start < len(text) and text[start].isspace():
        start += 1
    if start >= len(text) or text[start] not in {'"', "'"}:
        raise ValueError("expected Lua string")
    quote = text[start]
    start += 1
    chars: list[str] = []
    while start < len(text):
        char = text[start]
        start += 1
        if char == quote:
            return "".join(chars), start
        if char == "\\" and start < len(text):
            escaped = text[start]
            start += 1
            chars.append({"n": "\n", "r": "\r", "t": "\t"}.get(escaped, escaped))
        else:
            chars.append(char)
    raise ValueError("unterminated Lua string")


def parse_description_table(path: Path, table_names: set[str]) -> dict[int, dict[str, str]]:
    result: dict[int, dict[str, str]] = {}
    in_table = False
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        compact = line.replace(" ", "").replace("\t", "")
        if not in_table:
            compact_lower = compact.lower()
            if any(f"{name.lower()}={{" in compact_lower for name in table_names):
                in_table = True
            continue
        if line.lstrip().startswith("}"):
            break
        match = ENTRY.match(line)
        if not match:
            continue
        cursor = match.end()
        fields: list[str] = []
        try:
            for _ in range(3):
                value, cursor = read_lua_string(line, cursor)
                fields.append(value)
                comma = line.find(",", cursor)
                if comma < 0 and len(fields) < 3:
                    raise ValueError("missing field")
                cursor = comma + 1
        except ValueError:
            continue
        item_id = int(match.group(1) or fields[0])
        result[item_id] = {"name": fields[1], "description": fields[2]}
    return result


def git_commit(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} EID_SOURCE OUTPUT_JSON", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    language_files = {
        "en_us": [source / "descriptions/ab+/en_us.lua", source / "descriptions/rep/en_us.lua"],
        "ru": [source / "descriptions/ab+/ru.lua", source / "descriptions/rep/ru.lua"],
    }
    if not all(path.is_file() for files in language_files.values() for path in files):
        print("error: source is not an External-Item-Descriptions checkout", file=sys.stderr)
        return 2
    languages: dict[str, dict[str, object]] = {}
    counts: list[str] = []
    for code, files in language_files.items():
        categories: dict[str, dict[str, dict[str, str]]] = {}
        category_tables = {
            "collectibles": {"collectibles", "repcollectibles"},
            "trinkets": {"trinkets", "reptrinkets"},
            "cards": {"cards", "repcards"},
        }
        category_counts: list[str] = []
        for category, table_names in category_tables.items():
            entries: dict[int, dict[str, str]] = {}
            for path in files:
                entries.update(parse_description_table(path, table_names))
            categories[category] = {str(key): entries[key] for key in sorted(entries)}
            category_counts.append(f"{category}={len(entries)}")
        languages[code] = categories
        counts.append(f"{code}({', '.join(category_counts)})")
    payload = {
        "format": 1,
        "source": "user-supplied External Item Descriptions checkout",
        "source_commit": git_commit(source),
        "languages": languages,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"imported descriptions ({'; '.join(counts)}) into {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
