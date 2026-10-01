#!/usr/bin/env python3
"""Guard the touch-safe overlay structure shared by native and LiveContainer."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src" / "EIDOverlayController.m").read_text(encoding="utf-8")


def require(fragment: str) -> None:
    if fragment not in SOURCE:
        raise SystemExit(f"Overlay architecture test failed: missing {fragment!r}")


def reject(fragment: str) -> None:
    if fragment in SOURCE:
        raise SystemExit(f"Overlay architecture test failed: forbidden {fragment!r}")


require("root.userInteractionEnabled = YES;")
require("[root addSubview:settingsButton];")
require("[root addSubview:inventoryButton];")
require("[root addSubview:settingsCard];")
require("[root addSubview:inventoryCard];")
require("[window addSubview:root];")
require("if (!hit || hit == self) return nil;")
require("if ([hit isKindOfClass:UIControl.class]) return hit;")

reject("EIDOverlayWindow")
reject("initWithWindowScene:")
reject("[hostView addSubview:")
reject("root.userInteractionEnabled = NO;")

print("Overlay architecture test passed")
