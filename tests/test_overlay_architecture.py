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

# Paused console changes must either repaint or retain a pending repaint.
require("self.descriptionNeedsRefresh = YES;")
require("if (self.descriptionNeedsRefresh && !self.menuMode &&")
require("self.descriptionNeedsRefresh = NO;")
NATIVE = (ROOT / "src" / "EIDNativeProbe.mm").read_text(encoding="utf-8")
PRESENTATION = (ROOT / "src" / "EIDParityPresentation.m").read_text(encoding="utf-8")
BOOTSTRAP = (ROOT / "src" / "EIDBootstrap.m").read_text(encoding="utf-8")
HOST = (ROOT / "src" / "EIDGameHost.mm").read_text(encoding="utf-8")
assert "!NSThread.isMainThread" in NATIVE
assert "self.pillModifiers == other.pillModifiers" in NATIVE
assert 'context[@"pill_modifiers"] = @(pickup.pillModifiers)' in PRESENTATION
assert "resolvedSpindownIdentity:" in SOURCE
assert "resolvedRepeatIdentity:[probe resolvedPillIdentity:" in PRESENTATION
assert 'player[@"repeat_state"] = repeat' in NATIVE
assert "kPlayerWildCardOffset = 0x2834" in NATIVE
assert "kPlayerLastPillColorOffset = 0x1b40" in NATIVE
assert "EIDPillImageForColor(identifier.integerValue)" in PRESENTATION
assert "resolvedInventoryPreviewIdentity:pickup blackFeatherMetadata:" in PRESENTATION
assert "kPlayerPickupHistoryOffset = 0x24d0" in NATIVE
assert "prologue(kPlayerCanRemoveCollectibleOffset,0xa9be4ff4)" in NATIVE
assert "prologue(kPlayerGetTrinketMultiplierOffset,0xd10143ff)" in NATIVE
assert 'player[@"collectible_counts"] = numbers.copy' in NATIVE
assert 'player[@"pickup_history_signature"]' in NATIVE
assert "kPickupCollectibleCycleOffset = 0x5e4" in NATIVE
assert "kPickupCollectibleCycleCountOffset = 0x604" in NATIVE
assert "kPickupCycleSeedOffset = 0x3e8" in NATIVE
assert "PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible" in NATIVE
assert "prepareCollectibleCycleIdentity:pickup" in PRESENTATION
assert "prepareCollectibleCycleIdentity:nil" in PRESENTATION
assert "self.collectibleCycleIndicator.hidden = YES;" in SOURCE
assert "[self descriptionCycleAvailable] && self.panel.alpha > .01 && self.rootView.superview" in SOURCE
assert "EIDDescriptionCycleInventoryDice" in SOURCE
assert "EIDDInfinityPreviewID(self.inventoryDiceSelection)" in SOURCE
assert "EIDNextDescriptionSelection(self.inventoryDiceSelection,EIDDInfinityPreviewCount)" in SOURCE
assert "EIDDescriptionBackgroundVisible" in SOURCE
assert "EIDDescriptionBackgroundAlpha(opacity,inventoryPaused)" in SOURCE
assert "UIControl *panel = [[UIControl alloc] initWithFrame:CGRectZero]" in SOURCE
assert "[panel addTarget:self action:@selector(advanceCollectibleCycle:)" in SOURCE
assert "panel.userInteractionEnabled = NO;" in SOURCE
assert "self.panel.userInteractionEnabled = visible;" in SOURCE
assert "indicator.userInteractionEnabled = NO;" in SOURCE
assert "[self.panel addSubview:indicator]" in SOURCE
assert "self.panel.bounds.size.width-inset" in SOURCE
assert "collectibleCycleButton" not in SOURCE
HEADER_TUNING = (ROOT / "src" / "EIDHeaderTuning.m").read_text(encoding="utf-8")
assert "CGFloat headerWidth = MAX(1,textWidth-cycleInset);" in HEADER_TUNING
assert "updateCollectibleCycleControls];" in HEADER_TUNING
assert "usedRectForTextContainer:container" in HEADER_TUNING
assert "EIDDescriptionFittedWidth" in HEADER_TUNING
assert "applyDescriptionBackground];" in HEADER_TUNING
assert "available(config,3)" in NATIVE
assert "availablePrologue != 0xd10143ff" in NATIVE
assert "unlockedPrologue != 0x3100083f" in NATIVE
assert "UnavailableItemIcon" not in PRESENTATION
assert "NSStrikethroughStyleAttributeName" not in PRESENTATION
assert "image = EIDTrimVisiblePixels(image);" in PRESENTATION
assert "return EIDReadyGameWindow();" in SOURCE
assert "if (!EIDReadyGameWindow()) return;" in BOOTSTRAP
assert "viewIfLoaded" in HOST
assert "AAPLOpenGLView" in HOST and "_displayLink" in HOST
assert "link.timestamp" in HOST
assert "makeKeyAndVisible" not in HOST + BOOTSTRAP + SOURCE
assert "touchesBegan:" not in HOST + BOOTSTRAP + SOURCE
assert "isKeyWindow" not in HOST

print("Overlay architecture test passed")
