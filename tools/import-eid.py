#!/usr/bin/env python3
"""Import user-supplied EID English data without vendoring the upstream project."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


ENTRY = re.compile(r"^\s*(?:\[(\d+)\]\s*=\s*)?\{")
LANGUAGE_CODE = re.compile(r'^\s*local\s+languageCode\s*=\s*["\']([^"\']+)["\']')
IGNORED_LANGUAGE_FILES = {"item_data.lua", "transformations.lua"}


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


def parse_description_table(
    path: Path, table_names: set[str], *, pill_effect_ids: bool = False
) -> dict[int, dict[str, str]]:
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
        if pill_effect_ids:
            # EID's pill lookup table is keyed by effect + 1. The Lua source's
            # unkeyed entries contain the zero-based effect in field zero, while
            # Repentance overrides already use their adjusted explicit key.
            item_id = int(match.group(1)) if match.group(1) else int(fields[0]) + 1
        else:
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


def language_code(path: Path) -> str | None:
    for line in path.read_text(encoding="utf-8-sig").splitlines()[:40]:
        match = LANGUAGE_CODE.match(line)
        if match:
            return match.group(1)
    return None


def discover_language_files(source: Path) -> dict[str, list[Path]]:
    """Return every language loaded by upstream AB+ plus Repentance.

    Some upstream languages do not have a Repentance override file. They are
    still valid EID languages and retain their complete AB+ base descriptions,
    exactly as the original mod's language manager does.
    """
    result: dict[str, list[Path]] = {}
    for game_version in ("ab+", "rep"):
        directory = source / "descriptions" / game_version
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.lua")):
            if path.name in IGNORED_LANGUAGE_FILES:
                continue
            code = language_code(path)
            if code:
                result.setdefault(code, []).append(path)
    return result


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} EID_SOURCE OUTPUT_JSON", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    language_files = discover_language_files(source)
    if "en_us" not in language_files or not (source / "descriptions/rep/en_us.lua").is_file():
        print("error: source is not an External-Item-Descriptions checkout", file=sys.stderr)
        return 2
    languages: dict[str, dict[str, object]] = {}
    counts: list[str] = []
    ordered_codes = ["en_us"] + sorted(code for code in language_files if code != "en_us")
    for code in ordered_codes:
        files = language_files[code]
        categories: dict[str, dict[str, dict[str, str]]] = {}
        category_tables = {
            "collectibles": {"collectibles", "repcollectibles"},
            "trinkets": {"trinkets", "reptrinkets"},
            "cards": {"cards", "repcards"},
            "pills": {"pills", "reppills"},
            "horsepills": {"horsepills"},
        }
        category_counts: list[str] = []
        for category, table_names in category_tables.items():
            entries: dict[int, dict[str, str]] = {}
            for path in files:
                entries.update(parse_description_table(
                    path, table_names, pill_effect_ids=category in {"pills", "horsepills"}
                ))
            categories[category] = {str(key): entries[key] for key in sorted(entries)}
            category_counts.append(f"{category}={len(entries)}")
        languages[code] = categories
        counts.append(f"{code}({', '.join(category_counts)})")
    payload = {
        "format": 1,
        "source": "https://github.com/wofsauge/External-Item-Descriptions",
        "source_commit": git_commit(source),
        "game_version": "rep",
        "game_version_name": "Repentance",
        "compatible_isaac_version": "1.7.9b",
        "languages": languages,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"imported descriptions ({'; '.join(counts)}) into {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
