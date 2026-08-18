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
    data = source / "features/eid_data.lua"
    required = (inline_anm2, inline_png, transform_anm2, transform_png, data)
    if not all(path.is_file() for path in required):
        print("error: source is not a compatible External-Item-Descriptions checkout", file=sys.stderr)
        return 2

    output.mkdir(parents=True, exist_ok=True)
    for path in required[:4]:
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
    transform_payload = {
        "names": {str(key): value for key, value in TRANSFORM_NAMES.items()},
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
    print(f"imported {len(mapping)} inline icons and {len(assignments)} transformation assignments")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
