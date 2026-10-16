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
assert "EIDPocketInventoryPolicy::Resolve(raw,actives,items)" in NATIVE
assert "kPlayerActiveItemsOffset = 0x1964" in NATIVE
assert "kPlayerActiveItemStride = 28" in NATIVE
assert "kPlayerVoidActivesOffset = 0x1b78" in NATIVE
assert "kPlayerPurityBoostOffset = 0x1da4" in NATIVE
assert "kPlayerModelingClayOffset = 0x2730" in NATIVE
assert "kPlayerTemporaryEffectsOffset = 0x18d8" in NATIVE
assert 'player[@"void_actives"] = voided' in NATIVE
assert 'player[@"forms"] = values.copy' in NATIVE
assert 'player[@"purity"] = purity' in NATIVE
assert "resolvedCurrentEffectIdentity:pickup" in PRESENTATION
assert 'owned = [NSSet setWithArray:player[@"owned"]]' in PRESENTATION
assert "currentVoidedItems" in SOURCE
assert "self.inventoryRows[row.accessibilityIdentifier] = identity" in SOURCE
assert "identity.playerIndex!=self.inventoryPlayerIndex" in SOURCE
assert "item.playerIndex!=self.inventoryPlayerIndex" in SOURCE
assert "@selector(chooseInventoryPlayer:)" in SOURCE
assert "playerIndex:self.inventoryPlayerIndex" in SOURCE
assert "EIDPickupIdentity *selected = nil, *old = self.selectedInventoryItem" in SOURCE
current_effect = NATIVE.split("- (EIDPickupIdentity *)resolvedCurrentEffectIdentity:")[1].split("- (EIDPickupIdentity *)resolvedCraftingIdentity:")[0]
assert "!NSThread.isMainThread" in current_effect and "!self.paused" in current_effect
assert "ReadDescriptionPlayer" in current_effect
assert "RNG" not in current_effect and "WriteOwnTaskMemory" not in current_effect and "UseActiveItem" not in current_effect
inventory = NATIVE.split("- (void)updateInventoryForPlayers:")[1].split("- (void)updateDescriptionStateForPlayers:")[0]
assert "playerType:type playerIndex:(NSInteger)playerIndex" in inventory
assert "self.ownedCollectibleCounts.allKeys" not in inventory
assert "EIDInventoryCountPolicy::PhysicalCopies(counts[id],activeSlots)" in inventory
assert 'context[@"inventory_copies"]' in inventory
inventory_signature = SOURCE.split("- (NSString *)inventorySignatureForItems:")[1].split("- (UIImage *)inventoryIconForIdentity:")[0]
assert 'item.pickupContext[@"inventory_copies"]' in inventory_signature
inventory_row = SOURCE.split("- (void)addInventoryIdentity:")[1].split("- (void)rebuildInventoryContentsIfNeeded:")[0]
assert 'identity.pickupContext[@"inventory_copies"]' in inventory_row
assert "copies>1" in inventory_row and '×%ld' in inventory_row
assert 'identity.pickupContext[@"void_copies"]' in inventory_row
assert "kPlayerCraftingBagOffset = 0x2690" in NATIVE
assert 'player[@"crafting_bag"] = bag' in NATIVE
assert "return [self.probe resolvedCraftingIdentity:self.selectedInventoryItem]" in SOURCE
crafting = NATIVE.split("- (EIDPickupIdentity *)resolvedCraftingIdentity:")[1].split("- (EIDPickupIdentity *)resolvedInventoryPreviewIdentity:")[0]
assert "!NSThread.isMainThread" in crafting and "!self.paused" in crafting
assert "ReadDescriptionPlayer" in crafting
assert "UseActiveItem" not in crafting and "WriteOwnTaskMemory" not in crafting
assert 'context[@"crafting_result"] = @YES;' in crafting
assert "displayID = result;" in crafting
assert "resolvedOutcomeIdentity:pickup insideInventory:inventory enabled:outcomesEnabled" in PRESENTATION
assert '@"rng_predictions_enabled"] = @(outcomesEnabled)' in PRESENTATION
assert "RNG predictions (spoilers)" in PRESENTATION
assert PRESENTATION.count('![key isEqualToString:EIDOutcomesKey]') == 2
assert "kPickupCurrentRNGOffset = 0x3d8" in NATIVE
assert '@"outcome_seed":@(closest->outcomeSeed)' in NATIVE
assert 'player[@"outcome_signature"]' in NATIVE
assert 'player[@"outcome_dice_modes"]' in NATIVE
outcomes = NATIVE.split("- (EIDPickupIdentity *)resolvedOutcomeIdentity:")[1].split("- (EIDPickupIdentity *)resolvedCraftingIdentity:")[0]
assert "!enabled" in outcomes and "!NSThread.isMainThread" in outcomes
assert "ReadCollectibleRNG(player,485,rng)" in outcomes
assert "ReadRoomDecorationSeed(decoration)" in outcomes
assert "mode == 3" in outcomes
assert "PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible" in outcomes
assert "EIDOutcomePredictionPolicy::EternalD6(current)" in outcomes
assert "WriteOwnTaskMemory" not in outcomes
assert "reinterpret_cast<CanReroll>(image+0x7180d8)(address)" in outcomes
assert 'context[@"eternal_d6"] = @{@"validated":@YES' in outcomes
assert "prologue(kPlayerCanRemoveCollectibleOffset,0xa9be4ff4)" in NATIVE
assert "prologue(kPlayerGetTrinketMultiplierOffset,0xd10143ff)" in NATIVE
assert 'player[@"collectible_counts"] = numbers.copy' in NATIVE
assert 'player[@"pickup_history_signature"]' in NATIVE
assert "kPickupCollectibleCycleOffset = 0x5e4" in NATIVE
assert "kPickupCollectibleCycleCountOffset = 0x604" in NATIVE
assert "kPickupCycleSeedOffset = 0x3e8" in NATIVE
assert "PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible" in NATIVE
assert "prepareCollectibleCycleIdentity:pickup" in PRESENTATION
assert "CADisplayLink *pedestalDisplayLink" in SOURCE
assert "@selector(tickLivePedestal:)" in SOURCE
assert "EIDLivePedestalShouldTrack" in SOURCE
assert "resolvedLivePedestalIdentity:identity" in SOURCE
assert "resolvedLivePedestalIdentity:source" in SOURCE
live_tick = SOURCE.split("- (void)tickLivePedestal:")[1].split("- (void)tick:")[0]
assert "self.selectedInventoryItem" in live_tick and "UIApplicationStateActive" in live_tick
assert "currentDescribablePickups" not in live_tick and "dispatch_async" not in live_tick
assert "if ([fresh isEqual:source]) return;" in live_tick
live_pedestal = NATIVE.split("- (EIDPickupIdentity *)resolvedLivePedestalIdentity:")[1].split("- (EIDPickupIdentity *)resolvedCollectibleCycleIdentity:")[0]
assert "!NSThread.isMainThread" in live_pedestal
assert 'room != [previous[@"native_room"] unsignedLongLongValue]' in live_pedestal
assert "currentSeed != seed" in live_pedestal and "kCurseOfTheBlind" in live_pedestal
assert "PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible" in live_pedestal
assert "EIDLivePedestalSubtype(native[2],flip)" in live_pedestal
assert "WriteOwnTaskMemory" not in live_pedestal and "Morph(" not in live_pedestal
assert "ScanVMRegion" not in live_pedestal and "DiscoverEntityRegions" not in live_pedestal
assert "EIDCollectibleCyclePolicy::Normalize" not in live_pedestal
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
