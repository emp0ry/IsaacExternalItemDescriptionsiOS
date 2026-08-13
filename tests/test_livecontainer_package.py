#!/usr/bin/env python3
"""Validate the LiveContainer framework without changing a guest application."""

import hashlib
import plistlib
import subprocess
import sys
import zipfile
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"LiveContainer package test failed: {message}")


def main() -> None:
    if len(sys.argv) != 3:
        fail("expected framework and archive paths")

    framework = Path(sys.argv[1])
    archive = Path(sys.argv[2])
    executable = framework / "IsaacExternalItemDescriptions"
    info_path = framework / "Info.plist"
    if not executable.is_file() or not info_path.is_file() or not archive.is_file():
        fail("framework, executable, Info.plist, or archive is missing")

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundlePackageType") != "FMWK":
        fail("CFBundlePackageType is not FMWK")
    if info.get("CFBundleExecutable") != executable.name:
        fail("CFBundleExecutable does not match the framework binary")

    file_output = subprocess.check_output(["file", str(executable)], text=True)
    if "arm64" not in file_output or "dynamically linked shared library" not in file_output:
        fail(f"unexpected executable format: {file_output.strip()}")

    with zipfile.ZipFile(archive) as zipped:
        names = set(zipped.namelist())
        prefix = f"{framework.name}/"
        if prefix + "Info.plist" not in names or prefix + executable.name not in names:
            fail("archive does not preserve the framework layout")

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    print(f"LiveContainer framework package passed ({digest[:16]})")


if __name__ == "__main__":
    main()
