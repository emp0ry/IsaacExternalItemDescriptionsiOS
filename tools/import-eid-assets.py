#!/usr/bin/env python3
"""Import the visual resources needed for close EID presentation parity.

The user supplies an upstream External-Item-Descriptions checkout. This keeps the
port repository source-only while allowing release builds to bundle the original
atlas under upstream's license/attribution.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

ICON = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*\{\s*"([^"]+)"\s*,\s*(\d+)')


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} EID_SOURCE OUTPUT_BUNDLE", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    anm2 = source / "resources/gfx/eid_inline_icons.anm2"
    png = source / "resources/gfx/eid_inline_icons.png"
    data = source / "features/eid_data.lua"
    if not all(path.is_file() for path in (anm2, png, data)):
        print("error: source is not a compatible External-Item-Descriptions checkout", file=sys.stderr)
        return 2

    output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(anm2, output / anm2.name)
    shutil.copy2(png, output / png.name)

    mapping: dict[str, dict[str, object]] = {}
    for line in data.read_text(encoding="utf-8-sig").splitlines():
        match = ICON.match(line)
        if match:
            token, animation, frame = match.groups()
            mapping[token] = {"animation": animation, "frame": int(frame)}

    # Quality icons are defined upstream as function-generated aliases for the
    # Quality animation, one frame per quality. Materialize those aliases here.
    for quality in range(5):
        mapping[f"Quality{quality}"] = {"animation": "Quality", "frame": quality}

    (output / "eid_inline_icons.json").write_text(
        json.dumps(mapping, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
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
    print(f"imported {len(mapping)} inline icon mappings and original EID atlas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
