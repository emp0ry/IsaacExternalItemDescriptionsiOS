#!/usr/bin/env python3
"""Print one CHANGELOG entry as a release body, without repeating its title."""

import argparse
import re
import sys
from pathlib import Path


VERSION = re.compile(r"\d+\.\d+\.\d+")
HEADING = re.compile(r"## v(\d+\.\d+\.\d+)\s*")


def release_body(source, version):
    if not VERSION.fullmatch(version):
        raise ValueError("Expected a version such as 0.12.0 (without v).")
    entries = {}
    current = None
    fence = None
    for line in source.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if marker:
            token = marker.group(1)
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence):
                fence = None
            if current is not None:
                entries[current].append(line)
            continue
        match = HEADING.fullmatch(line) if fence is None else None
        if match:
            current = match.group(1)
            if current in entries:
                raise ValueError(f"Duplicate changelog entry: v{current}")
            entries[current] = []
        elif current is not None:
            entries[current].append(line)
    if version not in entries:
        raise ValueError(f"Missing changelog entry: v{version}")
    body = "\n".join(entries[version]).strip()
    body = re.sub(r"^\d{4}-\d{2}-\d{2}(?:\n+|$)", "", body).strip()
    if not body:
        raise ValueError(f"Empty changelog entry: v{version}")
    if re.search(r"^#\s", body, re.MULTILINE):
        raise ValueError("Release bodies must not contain a repeated top-level title.")
    if re.match(r"^(?:#{1,6}\s*)?(?:Isaac External Item Descriptions[^\n]*|v?" +
                re.escape(version) + r")\s*$", body.splitlines()[0]):
        raise ValueError("The release title belongs in GitHub's title field, not its body.")
    return body + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--changelog", type=Path,
                        default=Path(__file__).resolve().parents[1] / "CHANGELOG.md")
    args = parser.parse_args()
    try:
        body = release_body(args.changelog.read_text(encoding="utf-8"), args.version)
    except (OSError, ValueError) as error:
        parser.exit(1, f"release-notes: {error}\n")
    sys.stdout.write(body)


if __name__ == "__main__":
    main()
