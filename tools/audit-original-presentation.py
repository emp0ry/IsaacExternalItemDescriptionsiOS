#!/usr/bin/env python3
"""Report unsupported markup in the bundled presentation data, without game files."""
import collections
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
database = json.loads((root / "data/descriptions.json").read_text())
metadata = json.loads((root / "build/IsaacEID.bundle/original-renderer.json").read_text())
aliases = {"CR", "IND", "Hashtag", "EthernalHeart", "NoLB", "NoLineBreak", "Indent", "ColorReset", "ColorText", "ColorObjName", "ColorTransform", "ColorError"}
dynamic_colors = {"ColorGold", "ColorShinyPurple", "ColorRainbow", "ColorBlink", "ColorFade", "BlinkYellowGreen", "BlinkYellowRed", "BlinkGray", "BlinkBirthright", "BlinkBlue", "BlinkPink", "BlinkGreen"}
supported = set(metadata["icons"]) | set(metadata["colors"]) | aliases | dynamic_colors
for before, after in metadata.get("shortcuts", []):
    match = re.fullmatch(r"\{\{([^}]+)\}\}", before)
    if match:
        supported.add(match[1])
counts = collections.Counter()
locations = {}

def visit(value, path):
    if isinstance(value, dict):
        for key, entry in value.items():
            visit(entry, path + "/" + key)
    elif isinstance(value, list):
        for index, entry in enumerate(value):
            visit(entry, path + "/" + str(index))
    elif isinstance(value, str):
        for token in re.findall(r"\{\{([^}]+)\}\}", value):
            if token in supported or re.fullmatch(r"(?:Collectible|Trinket|Card|Pill)\d+|Item5\.(?:100|350)\.\d+|Name(?:Only)?(?:[CTKP]\d+|5\.(?:100|350|300|70)\.\d+)", token):
                continue
            counts[token] += 1
            locations.setdefault(token, path)

visit(database["languages"], "languages")
result = {"static_icons": len(metadata["icons"]), "unsupported_tokens": [
    {"token": token, "count": count, "example": locations[token]} for token, count in counts.most_common()]}
print(json.dumps(result, ensure_ascii=False, indent=2))
if "--strict" in sys.argv and counts:
    raise SystemExit(1)
