#!/usr/bin/env python3
"""Import visual resources and transformation metadata used by original EID."""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

ICON = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*\{\s*"([^"]+)"\s*,\s*(\d+)')
TRANSFORM = re.compile(r'^\s*\["5\.(\d+)\.(\d+)"\]\s*=\s*"([0-9,]+)"')
LANGUAGE_CODE = re.compile(r'^\s*local\s+languageCode\s*=\s*"([^"]+)"')
TRANSFORM_BLOCK = re.compile(r'EID\.descriptions\[languageCode\]\.transformations\s*=\s*\{')
QUOTED_VALUE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*,?')

TRANSFORM_NAMES = {
    1: "Guppy", 2: "Fun Guy", 3: "Lord of the Flies", 4: "Conjoined",
    5: "Spun", 6: "Mom", 7: "Oh Crap", 8: "Bob", 9: "Leviathan",
    10: "Seraphim", 11: "Super Bum", 12: "Bookworm", 13: "Spider Baby",
    14: "Adult", 15: "Stompy",
}


def parse_transformations(path: Path, result: dict[str, list[int]]) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        match = TRANSFORM.match(line)
        if not match:
            continue
        variant, subtype, ids = match.groups()
        result[f"{variant}:{subtype}"] = [int(value) for value in ids.split(",")]


def lua_unescape(value: str) -> str:
    return value.replace(r'\"', '"').replace(r'\\', '\\')


def parse_transformation_names(path: Path) -> tuple[str, dict[str, str]] | None:
    if not path.is_file():
        return None
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    language = None
    for line in lines:
        match = LANGUAGE_CODE.match(line)
        if match:
            language = match.group(1)
            break
    if not language:
        return None

    start = None
    for index, line in enumerate(lines):
        if TRANSFORM_BLOCK.search(line):
            start = index + 1
            break
    if start is None:
        return None

    values: list[str] = []
    for line in lines[start:]:
        if line.strip().startswith("}"):
            break
        match = QUOTED_VALUE.match(line)
        if match:
            values.append(lua_unescape(match.group(1)))

    # EID arrays include index 0 (empty/none) first; transformations 1..15 follow.
    names: dict[str, str] = {}
    for transform_id in range(1, 16):
        value_index = transform_id
        if value_index < len(values) and values[value_index]:
            names[str(transform_id)] = values[value_index]
    return language, names


def collect_localized_names(source: Path) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {
        "en_us": {str(key): value for key, value in TRANSFORM_NAMES.items()}
    }
    # Base AB+ language packs contain the complete classic transformation table.
    # Later packs may override/add localized names, so process them afterwards.
    for directory in ("ab+", "rep", "rep+"):
        root = source / "descriptions" / directory
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.lua")):
            parsed = parse_transformation_names(path)
            if not parsed:
                continue
            language, names = parsed
            if not names:
                continue
            merged = dict(result.get(language, {}))
            merged.update(names)
            result[language] = merged
    return result


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} EID_SOURCE OUTPUT_BUNDLE", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    gfx = source / "resources/gfx"
    inline_anm2 = gfx / "eid_inline_icons.anm2"
    inline_png = gfx / "eid_inline_icons.png"
    transform_anm2 = gfx / "eid_transform_icons.anm2"
    transform_png = gfx / "eid_transform_icons.png"
    cardspill_anm2 = gfx / "eid_cardspills.anm2"
    cardspill_png = gfx / "eid_cardspills.png"
    data = source / "features/eid_data.lua"
    visual_resources = (
        inline_anm2, inline_png, transform_anm2, transform_png,
        cardspill_anm2, cardspill_png,
    )
    required = visual_resources + (data,)
    if not all(path.is_file() for path in required):
        print("error: source is not a compatible External-Item-Descriptions checkout", file=sys.stderr)
        return 2

    output.mkdir(parents=True, exist_ok=True)
    for path in visual_resources:
        shutil.copy2(path, output / path.name)

    mapping: dict[str, dict[str, object]] = {}
    for line in data.read_text(encoding="utf-8-sig").splitlines():
        match = ICON.match(line)
        if match:
            token, animation, frame = match.groups()
            mapping[token] = {"animation": animation, "frame": int(frame)}
    for quality in range(5):
        mapping[f"Quality{quality}"] = {"animation": "Quality", "frame": quality}
    (output / "eid_inline_icons.json").write_text(
        json.dumps(mapping, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )

    assignments: dict[str, list[int]] = {}
    parse_transformations(source / "descriptions/ab+/transformations.lua", assignments)
    parse_transformations(source / "descriptions/rep/transformations.lua", assignments)
    localized_names = collect_localized_names(source)
    transform_payload = {
        "names": {str(key): value for key, value in TRANSFORM_NAMES.items()},
        "names_by_language": localized_names,
        "assignments": assignments,
        "required": 3,
    }
    (output / "transformations.json").write_text(
        json.dumps(transform_payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )

    license_candidates = [source / "LICENSE", source / "LICENSE.md", source / "COPYING"]
    for candidate in license_candidates:
        if candidate.is_file():
            shutil.copy2(candidate, output / "EID-UPSTREAM-LICENSE.txt")
            break
    (output / "EID-UPSTREAM-SOURCE.txt").write_text(
        "External Item Descriptions\nhttps://github.com/wofsauge/External-Item-Descriptions\n",
        encoding="utf-8",
    )
    print(
        f"imported {len(mapping)} inline icons, {len(assignments)} transformation assignments, "
        f"{len(localized_names)} transformation languages, and original card/pill artwork"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
