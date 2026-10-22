#import "EIDNativeProbe.h"
#include "EIDLivePedestalPolicy.h"
#include "IsaacPresentationState.hpp"
#include "EIDCurrentEffectsPolicy.hpp"
#include "EIDInventoryCountPolicy.hpp"
#import "EIDLogger.h"
#include "EIDPickupPolicy.hpp"
#include "EIDPickupMetadataPolicy.hpp"
#include "EIDCollectibleVisibilityPolicy.hpp"
#include "EIDNativeContextPolicy.hpp"
#include "EIDPillPolicy.h"
#include "EIDPredictionPolicy.hpp"
#include "EIDSpindownPolicy.hpp"
#include "EIDRepeatPolicy.hpp"
#include "EIDInventoryPreviewPolicy.hpp"
#include "EIDCollectibleCyclePolicy.hpp"
#include "EIDPocketInventoryPolicy.hpp"
#include "EIDOutcomePredictionPolicy.hpp"
#include "EIDTrinketEffectPolicy.hpp"
#import "EIDFeatureConfig.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

#ifndef EID_DEVELOPMENT_LAYOUT_CAPTURE
#define EID_DEVELOPMENT_LAYOUT_CAPTURE 0
#endif

namespace {
constexpr const char *kPickupRTTIName = "N15IsaacRepentance13Entity_PickupE";
constexpr const char *kPlayerRTTIName = "N15IsaacRepentance13Entity_PlayerE";
constexpr const char *kFamiliarRTTIName = "N15IsaacRepentance15Entity_FamiliarE";
constexpr const char *kSlotRTTIName = "N15IsaacRepentance11Entity_SlotE";
constexpr const char *kEffectRTTIName = "N15IsaacRepentance13Entity_EffectE";
constexpr const char *kGridSpikesRTTIName = "N15IsaacRepentance17GridEntity_SpikesE";
constexpr const char *kSupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
constexpr size_t kMaxVTables = 8;
constexpr size_t kMaxItems = 32;
constexpr size_t kMaxPlayers = 8;

struct ScanContext {
    std::array<uintptr_t, kMaxVTables> pickupVTables{};
    size_t pickupVTableCount = 0;
    std::array<uintptr_t, kMaxVTables> playerVTables{};
    size_t playerVTableCount = 0;
    std::array<uintptr_t, kMaxVTables> familiarVTables{};
    size_t familiarVTableCount = 0;
    std::array<uintptr_t, kMaxVTables> slotVTables{};
    size_t slotVTableCount = 0;
    std::array<uintptr_t, kMaxVTables> effectVTables{};
    size_t effectVTableCount = 0;
    std::array<uintptr_t, kMaxVTables> gridSpikesVTables{};
    size_t gridSpikesVTableCount = 0;
};

static bool IsCandidateVTable(const std::array<uintptr_t, kMaxVTables>& vtables,
                              size_t count, uintptr_t value) {
    for (size_t i = 0; i < count; ++i) {
        if (vtables[i] == value) return true;
    }
    return false;
}

static NSString *ExecutableUUIDForHeader(const mach_header_64 *header) {
    if (!header || header->magic != MH_MAGIC_64 || header->ncmds > 65536 ||
        header->sizeofcmds > 64 * 1024 * 1024) return @"UNKNOWN";

    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        if (cursor > end || static_cast<size_t>(end - cursor) < sizeof(load_command)) break;
        const load_command *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmdsize < sizeof(load_command) ||
            static_cast<size_t>(end - cursor) < command->cmdsize) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(uuid_command)) {
            const uuid_command *uuidCommand = reinterpret_cast<const uuid_command *>(cursor);
            const unsigned char *u = uuidCommand->uuid;
            return [NSString stringWithFormat:
                    @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    u[0],u[1],u[2],u[3],u[4],u[5],u[6],u[7],u[8],u[9],u[10],u[11],u[12],u[13],u[14],u[15]];
        }
        cursor += command->cmdsize;
    }
    return @"UNKNOWN";
}

static const mach_header_64 *IsaacExecutableHeader(intptr_t *slideOut) {
    uint32_t count = _dyld_image_count();

    // LiveContainer patches the guest executable's Mach-O type from MH_EXECUTE
    // to MH_DYLIB and loads it into the LiveContainer host. Select Isaac by its
    // exact verified UUID so native and LiveContainer loading resolve the same
    // image without trusting an arbitrary dylib in the process.
    for (uint32_t index = 0; index < count; ++index) {
        const mach_header_64 *header =
            reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(index));
        NSString *uuid = ExecutableUUIDForHeader(header);
        if ([uuid caseInsensitiveCompare:[NSString stringWithUTF8String:kSupportedUUID]] ==
            NSOrderedSame) {
            if (slideOut) *slideOut = _dyld_get_image_vmaddr_slide(index);
            return header;
        }
    }

    // Keep useful fail-closed diagnostics for a native game update. Fixed
    // offsets are never enabled unless the UUID above matches.
    for (uint32_t index = 0; index < count; ++index) {
        const mach_header_64 *header =
            reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(index));
        if (header && header->magic == MH_MAGIC_64 && header->filetype == MH_EXECUTE) {
            if (slideOut) *slideOut = _dyld_get_image_vmaddr_slide(index);
            return header;
        }
    }
    if (slideOut) *slideOut = 0;
    return nullptr;
}

static NSString *IsaacExecutableUUID(void) {
    return ExecutableUUIDForHeader(IsaacExecutableHeader(nullptr));
}

static void ForEachMainImageSegment(void (^block)(const uint8_t *address, size_t size, vm_prot_t protection)) {
    intptr_t slide = 0;
    const mach_header_64 *header = IsaacExecutableHeader(&slide);
    if (!header || header->magic != MH_MAGIC_64) return;
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header + 1);
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        const load_command *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmd == LC_SEGMENT_64) {
            const segment_command_64 *segment = reinterpret_cast<const segment_command_64 *>(cursor);
            if (segment->vmsize && strcmp(segment->segname, "__LINKEDIT") != 0) {
                block(reinterpret_cast<const uint8_t *>(segment->vmaddr + slide),
                      static_cast<size_t>(segment->vmsize), segment->initprot);
            }
        }
        if (!command->cmdsize) break;
        cursor += command->cmdsize;
    }
}

static void LocateVTables(const char *rttiName,
                          std::array<uintptr_t, kMaxVTables>& output,
                          size_t& outputCount) {
    __block uintptr_t typeNameAddress = 0;
    const size_t typeNameLength = strlen(rttiName) + 1;

    ForEachMainImageSegment(^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (typeNameAddress || !(protection & VM_PROT_READ) || (protection & VM_PROT_WRITE)) return;
        for (size_t offset = 0; offset + typeNameLength <= size; ++offset) {
            if (memcmp(address + offset, rttiName, typeNameLength) == 0) {
                typeNameAddress = reinterpret_cast<uintptr_t>(address + offset);
                return;
            }
        }
    });
    if (!typeNameAddress) return;

    __block std::array<uintptr_t, 8> typeInfos{};
    __block size_t typeInfoCount = 0;
    ForEachMainImageSegment(^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (!(protection & VM_PROT_READ)) return;
        for (size_t offset = sizeof(uintptr_t); offset + sizeof(uintptr_t) <= size; offset += sizeof(uintptr_t)) {
            uintptr_t value;
            memcpy(&value, address + offset, sizeof(value));
            if (value == typeNameAddress && typeInfoCount < typeInfos.size()) {
                typeInfos[typeInfoCount++] = reinterpret_cast<uintptr_t>(address + offset - sizeof(uintptr_t));
            }
        }
    });

    ForEachMainImageSegment(^(const uint8_t *address, size_t size, vm_prot_t protection) {
        if (!(protection & VM_PROT_READ)) return;
        for (size_t offset = sizeof(uintptr_t); offset + 2 * sizeof(uintptr_t) <= size; offset += sizeof(uintptr_t)) {
            uintptr_t value;
            memcpy(&value, address + offset, sizeof(value));
            for (size_t typeIndex = 0; typeIndex < typeInfoCount; ++typeIndex) {
                if (value != typeInfos[typeIndex] || outputCount >= output.size()) continue;
                intptr_t offsetToTop;
                uintptr_t firstMethod;
                memcpy(&offsetToTop, address + offset - sizeof(uintptr_t), sizeof(offsetToTop));
                memcpy(&firstMethod, address + offset + sizeof(uintptr_t), sizeof(firstMethod));
                if (offsetToTop == 0 && firstMethod != 0) {
                    output[outputCount++] = reinterpret_cast<uintptr_t>(address + offset + sizeof(uintptr_t));
                }
            }
        }
    });
}

static ScanContext LocateEntityVTables(void) {
    ScanContext context;
    LocateVTables(kPickupRTTIName, context.pickupVTables, context.pickupVTableCount);
    LocateVTables(kPlayerRTTIName, context.playerVTables, context.playerVTableCount);
    LocateVTables(kFamiliarRTTIName, context.familiarVTables, context.familiarVTableCount);
    LocateVTables(kSlotRTTIName, context.slotVTables, context.slotVTableCount);
    LocateVTables(kEffectRTTIName, context.effectVTables, context.effectVTableCount);
    LocateVTables(kGridSpikesRTTIName, context.gridSpikesVTables,
                  context.gridSpikesVTableCount);
    return context;
}

constexpr size_t kEntityTypeOffset = 0x38;
constexpr size_t kEntityStateOffset = 0x1c0;
constexpr size_t kEntityPositionOffset = 0x310;
constexpr size_t kGridEntityDescOffset = 0x8;
constexpr size_t kGridEntityVarDataOffset = kGridEntityDescOffset + 0x14;
// Native AddCollectibleCycle at 0x10071812c fills up to eight int32 IDs.
// Update at 0x10071a520 rotates the queue and current SubType together.
constexpr size_t kPickupCollectibleCycleOffset = 0x5e4;
constexpr size_t kPickupCollectibleCycleCountOffset = 0x604;
// Morph at 0x100718a3c preserves this seed during a cycle switch (keepSeed=1).
// +0x3d8 is the mutable pickup RNG record, not a stable identity key.
constexpr size_t kPickupCycleSeedOffset = 0x3e8;
constexpr size_t kPickupCurrentRNGOffset = 0x3d8;
constexpr size_t kCranePrizeCollectibleOffset = 0x570;
constexpr size_t kPlayerPocketItemsOffset = 0x1c10;
constexpr size_t kPlayerPocketItemCount = 4;
constexpr size_t kPlayerActiveItemsOffset = 0x1964;
constexpr size_t kPlayerActiveItemStride = 28;
// Void use iterates int32 IDs here (0x10058bf50); PlayerData copies the vector
// at 0x1005501cc. The native HasVoidedCollectible query uses the same span.
constexpr size_t kPlayerVoidActivesOffset = 0x1b78;
// Native stat evaluation reads the current Purity boost, not a future RNG roll.
constexpr size_t kPlayerPurityBoostOffset = 0x1da4;
constexpr size_t kPlayerTemporaryEffectsOffset = 0x18d8;
// New-room logic clears/replaces this cached Modeling Clay item at
// 0x10054c998 / 0x10054ce8c; GetCollectibleNum reads it at 0x1004ffa40.
constexpr size_t kPlayerModelingClayOffset = 0x2730;
// Add-to-bag caches the result at 0x100555140; both crafting paths consume
// that ID (0x100528cfc, 0x10058a3c0). The preceding eight bytes are ingredients.
constexpr size_t kPlayerCraftingBagOffset = 0x2690;
// Wild Card's UseCard(80) branch at 0x100543b40 reads this tagged union:
// byte type (0 pill, 1 card, 2 active, 0xff empty), int32 ID, int32 extra.
// PlayerData serialization at 0x100550044 preserves it at +0x6b8..+0x6c0.
constexpr size_t kPlayerWildCardOffset = 0x2834;
// Vurp (UsePill effect 46, 0x10053dec4) reads the last non-golden raw color.
// 0x10053e69c updates it; PlayerData +0x40 saves/restores it on Continue.
constexpr size_t kPlayerLastPillColorOffset = 0x1b40;
// The Stars? branch at 0x100547334 walks a vector of 28-byte ItemHistory
// records, rejecting trinkets/frame-zero entries before native removability.
constexpr size_t kPlayerPickupHistoryOffset = 0x24d0;
constexpr size_t kPlayerTrinketSlotsOffset = 0x1ab0;
constexpr size_t kPlayerTrinketSlotCount = 2;
// Native smelted-trinket operations use a vector of pairs of signed int16
// counts at +0x1b60: regular at id*4, golden at id*4+2 (0x100509680).
constexpr size_t kPlayerSmeltedTrinketsOffset = 0x1b60;
// Consolation Prize's native pickup branch (0x100502140, 0x1005035d8).
constexpr size_t kPlayerMoveSpeedOffset = 0x194c;
// Lodestone's native proc path at 0x100513fa4 reads this float.
constexpr size_t kPlayerLuckOffset = 0x1950;
constexpr size_t kPlayerMaxFireDelayOffset = 0x1834;
constexpr size_t kPlayerDamageOffset = 0x1844;
constexpr size_t kPlayerTearRangeOffset = 0x1854;
constexpr size_t kPlayerCoinsOffset = 0x16e0;
constexpr size_t kPlayerBombsOffset = 0x16dc;
// AddGoldenBomb 0x1005526f0; consumed by Mama Mega at 0x10058ad78.
constexpr size_t kPlayerGoldenBombOffset = 0x16d9;
// New-room temporary trinket effects at 0x10054c754 use this RNG vector.
constexpr size_t kPlayerTrinketRNGOffset = 0x1bc8;
constexpr size_t kPlayerKeysOffset = 0x16d4;
constexpr size_t kPlayerSoulChargeOffset = 0x2478;
constexpr size_t kPlayerBloodChargeOffset = 0x247c;
constexpr size_t kPlayerCollectibleCountsOffset = 0x1ab8;
constexpr size_t kPlayerTransformationCountersOffset = 0x1c54;
// Live-verified Entity_Player flight boolean. The supported ARM64 executable
// reads this exact byte with ldrb in its movement/collision paths. Reading a
// four-byte scalar here is incorrect because the adjacent bytes are unrelated.
constexpr size_t kPlayerCanFlyOffset = 0x1954;
// Repentance ChangePlayerType and character-specific item branches use this
// int32 field; Entity::SubType is not the authoritative character identifier.
constexpr size_t kPlayerTypeOffset = 0x1738;
// HasCollectible's non-quest suppression guard at 0x1004eebe0.
constexpr size_t kPlayerNonQuestItemsDisabledOffset = 0x284c;
// Game::IsGreedMode at 0x10088c994 reads (difficulty & ~1) == 2 here.
constexpr size_t kGameDifficultyOffset = 0x24f9d8;
constexpr size_t kNativeTransformationCount = 15;
constexpr size_t kMaximumCollectibleID = 732;
constexpr vm_size_t kVMReadChunk = 2 * 1024 * 1024;
constexpr vm_size_t kGamePlayerVectorScanLimit = 512 * 1024;
constexpr float kMaximumDescriptionDistance = 220.0f;
constexpr uintptr_t kGameGlobalOffset = 0xac3b90;
constexpr uintptr_t kManagerGlobalOffset = 0xac2428;
// Collection menu (0x10066b3c0) and persistent loader (0x1006ffd78)
// independently address the same currently selected save's collection flags.
constexpr size_t kManagerPersistentDataOffset = 0x204d0;
constexpr size_t kPersistentCollectionOffset = 0xa68;
constexpr uintptr_t kItemPoolGetPillEffectOffset = 0x879bf0;
constexpr uintptr_t kPlayerHasCollectibleOffset = 0x4eeb74;
constexpr uintptr_t kPlayerGetCollectibleNumOffset = 0x4ff70c;
constexpr uintptr_t kPlayerGetTrinketMultiplierOffset = 0x506238;
constexpr uintptr_t kPlayerCanRemoveCollectibleOffset = 0x505a54;
// Drop-reward selection at 0x10059f034 calls this read-only output adapter.
constexpr uintptr_t kPlayerGlyphOfBalanceOffset = 0x554364;
constexpr uintptr_t kItemConfigIsAvailableOffset = 0x73fab0;
constexpr uintptr_t kPersistentIsAchievementUnlockedOffset = 0x7027f8;
constexpr size_t kManagerCollectibleConfigsOffset = 0x55f30;
constexpr size_t kGameCursesOffset = 0xc;
constexpr size_t kGameCurrentRoomOffset = 0x21550;
// Entity_Pickup's Tainted Cain branch at 0x100720a64 reads these fields.
constexpr size_t kGameChallengeOffset = 0x1cf438;
constexpr size_t kGameRoomIndexOffset = 0x21558;
constexpr size_t kGameDimensionOffset = 0x21560;
// ItemPool::GetPoolForRoom (0x100877a3c) indexes these native tables.
constexpr size_t kItemPoolRoomPoolsOffset = 0x920;
constexpr size_t kItemPoolGreedRoomPoolsOffset = 0x998;
constexpr size_t kRoomDescriptorOffset = 0x8;
constexpr size_t kRoomDescriptorDataOffset = 0x10;
constexpr size_t kRoomConfigTypeOffset = 0x8;
constexpr size_t kRoomGridEntitiesOffset = 0x30;
constexpr size_t kRoomGridEntityCount = 0x1c0;
constexpr size_t kRoomGridWidthOffset = 0x14;
constexpr size_t kRoomGridHeightOffset = 0x18;
constexpr size_t kRoomGridPathsOffset = 0xe98;
constexpr int32_t kSacrificeRoomType = 13;
constexpr int32_t kGridSpikesType = 0x8;
constexpr int32_t kSuperBumFamiliarVariant = 102;
// Familiar::Init 0x1007fbf8c stores its owning player here. Update at
// 0x10080860c reads this player's position for Super Bum and related variants.
constexpr size_t kFamiliarOwnerOffset = 0x400;
constexpr uint32_t kCurseOfTheBlind = 1u << 6;
constexpr NSUInteger kRunEndConfirmationScans = 12;
constexpr size_t kGameRunSeedOffset = 0x25d44;
constexpr size_t kGameItemPoolOffset = 0x242c0;
constexpr size_t kItemPoolPillEffectsOffset = 0xa2c;
constexpr size_t kItemPoolIdentifiedPillsOffset = 0xa68;
constexpr uint32_t kPillColorMask = 0x7ff;
constexpr uint32_t kHorsePillFlag = 1u << 11;
constexpr uint32_t kGoldenPillColor = 14;
// Reverse-verified on executable UUID F4357753-A25F-30EE-BACF-63709F902895.
// PauseScreen starts at Game + 0x10DD20 and its state is the int32 at +0x2B8.
constexpr size_t kGamePauseMenuStateOffset = 0x10dfd8;

struct VMPickup {
    int32_t variant = 0;
    int32_t subtype = 0;
    float x = 0;
    float y = 0;
    bool hasPosition = false;
    bool isShopItem = false;
    int32_t optionsPickupIndex = 0;
    int32_t rawPillSubtype = 0;
    int32_t flipID = 0;
    vm_address_t address = 0;
    uint32_t cycleSeed = 0;
    uint32_t outcomeSeed = 0;
};

struct VMPlayer {
    vm_address_t address = 0;
    float x = 0;
    float y = 0;
};

using VMPlayerPocketItem = EIDPocketInventoryPolicy::Pocket;

static_assert(sizeof(VMPlayerPocketItem) == 8, "Unexpected native pocket-item layout");

struct VMRegionResult {
    vm_address_t address = 0;
    vm_size_t size = 0;
    size_t pickupVTableReferences = 0;
    size_t playerVTableReferences = 0;
    size_t familiarVTableReferences = 0;
    size_t slotVTableReferences = 0;
    size_t effectVTableReferences = 0;
    size_t gridSpikesVTableReferences = 0;
    vm_address_t firstPickupVTableAddress = 0;
    vm_address_t lastPickupVTableAddress = 0;
    vm_address_t firstSlotVTableAddress = 0;
    vm_address_t lastSlotVTableAddress = 0;
    vm_address_t firstEffectVTableAddress = 0;
    vm_address_t lastEffectVTableAddress = 0;
    vm_address_t firstFamiliarVTableAddress = 0;
    vm_address_t lastFamiliarVTableAddress = 0;
    bool superBumActive = false;
    std::array<VMPickup, kMaxItems> pickups{};
    size_t pickupCount = 0;
    size_t blindPickupCount = 0;
    size_t unreadableBlindStateCount = 0;
    std::array<VMPlayer, kMaxPlayers> players{};
    size_t playerCount = 0;
#if EID_DEVELOPMENT_LAYOUT_CAPTURE
    std::array<uint8_t, 4096> pickupSnapshot{};
    size_t pickupSnapshotSize = 0;
    std::array<uint8_t, 4096> playerSnapshot{};
    size_t playerSnapshotSize = 0;
#endif
};

static bool PlausiblePosition(float x, float y) {
    return std::isfinite(x) && std::isfinite(y) && x > -4096 && x < 4096 && y > -4096 && y < 4096;
}

static bool ReadOwnTaskMemory(vm_address_t address, void *destination, vm_size_t size) {
    if (!address || !destination || !size) return false;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), address, size,
                             reinterpret_cast<vm_address_t>(destination), &copied) == KERN_SUCCESS &&
        copied == size;
}

static bool ReadPickupMetadata(const uint8_t *object, size_t available,
                                EIDPickupMetadataPolicy::Metadata& metadata) {
    static const bool layoutValid = [] {
        const auto *header = IsaacExecutableHeader(nullptr);
        return header && EIDPickupMetadataPolicy::ValidateLayout(
            reinterpret_cast<uintptr_t>(header),ReadOwnTaskMemory);
    }();
    return layoutValid && EIDPickupMetadataPolicy::Read(object,available,metadata);
}

static bool ReadGameObjectAddress(vm_address_t& gameAddress) {
    gameAddress = 0;
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    uintptr_t game = 0;
    if (!header || !ReadOwnTaskMemory(
            reinterpret_cast<vm_address_t>(header) + kGameGlobalOffset,
            &game, sizeof(game)) || !game) return false;
    gameAddress = static_cast<vm_address_t>(game);
    return true;
}

struct RemotePointerVector {
    uintptr_t begin = 0;
    uintptr_t end = 0;
    uintptr_t capacity = 0;
};

static bool ReadPlayerObject(const ScanContext& context, vm_address_t address,
                             VMPlayer& player) {
    uintptr_t vtable = 0;
    if (!ReadOwnTaskMemory(address, &vtable, sizeof(vtable)) ||
        !IsCandidateVTable(context.playerVTables, context.playerVTableCount, vtable)) {
        return false;
    }

    std::array<uint8_t, kEntityPositionOffset + 2 * sizeof(float)> object{};
    if (!ReadOwnTaskMemory(address, object.data(), object.size())) return false;
    int32_t identity[3]{};
    float x = 0;
    float y = 0;
    memcpy(identity, object.data() + kEntityTypeOffset, sizeof(identity));
    memcpy(&x, object.data() + kEntityPositionOffset, sizeof(x));
    memcpy(&y, object.data() + kEntityPositionOffset + sizeof(float), sizeof(y));
    if (identity[0] != 1 || identity[1] != 0 || identity[2] < 0 ||
        identity[2] >= 100 || !PlausiblePosition(x, y)) return false;
    player = {address, x, y};
    return true;
}

static bool ReadPlayerVector(const ScanContext& context, vm_address_t vectorAddress,
                             bool allowEmpty, VMRegionResult& result) {
    RemotePointerVector remote;
    if (!ReadOwnTaskMemory(vectorAddress, &remote, sizeof(remote))) return false;
    if (!remote.begin && !remote.end && !remote.capacity) return allowEmpty;
    if (!remote.begin || remote.end < remote.begin || remote.capacity < remote.end ||
        (remote.end - remote.begin) % sizeof(uintptr_t) != 0 ||
        (remote.capacity - remote.begin) % sizeof(uintptr_t) != 0) return false;

    size_t count = (remote.end - remote.begin) / sizeof(uintptr_t);
    size_t capacity = (remote.capacity - remote.begin) / sizeof(uintptr_t);
    if (!count) return allowEmpty && capacity <= 64;
    if (count > kMaxPlayers || capacity < count || capacity > 64) return false;

    std::array<uintptr_t, kMaxPlayers> addresses{};
    if (!ReadOwnTaskMemory(remote.begin, addresses.data(),
                           static_cast<vm_size_t>(count * sizeof(uintptr_t)))) return false;
    VMRegionResult players;
    for (size_t index = 0; index < count; ++index) {
        VMPlayer player;
        if (!addresses[index] ||
            !ReadPlayerObject(context, static_cast<vm_address_t>(addresses[index]), player)) {
            return false;
        }
        players.players[players.playerCount++] = player;
    }
    if (players.playerCount != count) return false;
    result = players;
    return true;
}

static bool ResolvePlayersFromGame(const ScanContext& context, NSUInteger& vectorOffset,
                                   VMRegionResult& result) {
    vm_address_t game = 0;
    if (!ReadGameObjectAddress(game)) return false;

    if (vectorOffset != NSUIntegerMax) {
        if (ReadPlayerVector(context, game + vectorOffset, true, result)) return true;
        vectorOffset = NSUIntegerMax;
    }

    vm_address_t regionAddress = game;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    kern_return_t status = vm_region_64(
        mach_task_self(), &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info), &infoCount, &objectName);
    if (objectName != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), objectName);
    if (status != KERN_SUCCESS || regionAddress > game ||
        !(info.protection & VM_PROT_READ) || regionSize <= game - regionAddress) return false;

    vm_size_t available = regionSize - (game - regionAddress);
    vm_size_t scanSize = MIN(available, kGamePlayerVectorScanLimit);
    if (scanSize < sizeof(RemotePointerVector)) return false;
    std::vector<uint8_t> gameBytes(static_cast<size_t>(scanSize));
    if (!ReadOwnTaskMemory(game, gameBytes.data(), scanSize)) return false;

    for (size_t offset = 0; offset + sizeof(RemotePointerVector) <= gameBytes.size();
         offset += sizeof(uintptr_t)) {
        RemotePointerVector remote;
        memcpy(&remote, gameBytes.data() + offset, sizeof(remote));
        if (!remote.begin || remote.end <= remote.begin || remote.capacity < remote.end ||
            (remote.end - remote.begin) % sizeof(uintptr_t) != 0) continue;
        size_t count = (remote.end - remote.begin) / sizeof(uintptr_t);
        if (!count || count > kMaxPlayers) continue;
        VMRegionResult candidate;
        if (ReadPlayerVector(context, game + offset, false, candidate)) {
            vectorOffset = offset;
            result = candidate;
            return true;
        }
    }
    return false;
}

static bool ReadPlayerPocketItems(
    vm_address_t playerAddress,
    std::array<VMPlayerPocketItem, kPlayerPocketItemCount>& items) {
    std::array<VMPlayerPocketItem,kPlayerPocketItemCount> raw{}, confirmation{};
    std::array<int32_t,kPlayerPocketItemCount> actives{}, activeConfirmation{};
    if (!ReadOwnTaskMemory(playerAddress+kPlayerPocketItemsOffset,raw.data(),sizeof(raw))) return false;
    for (size_t slot = 0; slot < actives.size(); ++slot)
        if (!ReadOwnTaskMemory(playerAddress+kPlayerActiveItemsOffset+slot*kPlayerActiveItemStride,
                               &actives[slot],sizeof(int32_t))) return false;
    if (!ReadOwnTaskMemory(playerAddress+kPlayerPocketItemsOffset,confirmation.data(),sizeof(confirmation)) ||
        memcmp(raw.data(),confirmation.data(),sizeof(raw))) return false;
    for (size_t slot = 0; slot < actives.size(); ++slot)
        if (!ReadOwnTaskMemory(playerAddress+kPlayerActiveItemsOffset+slot*kPlayerActiveItemStride,
                               &activeConfirmation[slot],sizeof(int32_t))) return false;
    return actives == activeConfirmation && EIDPocketInventoryPolicy::Resolve(raw,actives,items);
}

static NSDictionary *ReadCraftingBag(vm_address_t player) {
    EIDPocketInventoryPolicy::CraftingBag bag{}, confirmation{};
    size_t count = 0;
    if (!ReadOwnTaskMemory(player+kPlayerCraftingBagOffset,&bag,sizeof(bag)) ||
        !EIDPocketInventoryPolicy::ValidateBag(bag,count) ||
        !ReadOwnTaskMemory(player+kPlayerCraftingBagOffset,&confirmation,sizeof(confirmation)) ||
        memcmp(&bag,&confirmation,sizeof(bag))) return nil;
    NSMutableArray *ingredients = [NSMutableArray array];
    for (size_t index = 0; index < count; ++index) [ingredients addObject:@(bag.ingredients[index])];
    return @{@"validated":@YES,@"count":@(count),@"result":@(EIDPocketInventoryPolicy::CraftingResult(bag)),
             @"ingredients":ingredients.copy};
}

static bool ReadPlayerCanFly(vm_address_t playerAddress, bool& canFly) {
    uint8_t nativeValue = UINT8_MAX;
    if (!ReadOwnTaskMemory(playerAddress + kPlayerCanFlyOffset,
                           &nativeValue, sizeof(nativeValue))) {
        canFly = false;
        return false;
    }
    // This build stores the evaluated flight state as a native C++ bool. Reject
    // values other than 0/1 so an incompatible layout fails closed.
    return EIDPickupPolicy::DecodeNativeCanFly(nativeValue, canFly);
}

static bool ReadPlayerCollectibleCounts(
    vm_address_t playerAddress,
    std::array<int32_t, kMaximumCollectibleID + 1>& counts) {
    uintptr_t countTable = 0;
    if (!ReadOwnTaskMemory(playerAddress + kPlayerCollectibleCountsOffset,
                           &countTable, sizeof(countTable)) || !countTable ||
        !ReadOwnTaskMemory(countTable, counts.data(), sizeof(counts))) return false;

    uint64_t total = 0;
    for (int32_t count : counts) {
        if (count < 0 || count > 999) return false;
        total += static_cast<uint32_t>(count);
        if (total > 4096) return false;
    }
    return true;
}

static bool ReadPlayerTrinkets(
    vm_address_t playerAddress,
    std::array<int32_t, kPlayerTrinketSlotCount>& trinkets) {
    if (!ReadOwnTaskMemory(playerAddress + kPlayerTrinketSlotsOffset,
                           trinkets.data(), sizeof(trinkets))) return false;
    for (int32_t trinket : trinkets) {
        // The high bit marks a golden trinket. Preserve it for icon/description
        // lookup, but validate the underlying identifier before publishing it.
        if (trinket < 0 || (trinket & 0x7fff) > 4096) return false;
    }
    return true;
}

static bool ReadSmeltedTrinkets(vm_address_t player, std::vector<int32_t>& identities,
                               uint64_t *signature = nullptr) {
    RemotePointerVector vector;
    if (!ReadOwnTaskMemory(player + kPlayerSmeltedTrinketsOffset,&vector,sizeof(vector))) return false;
    if (!EIDNativeContextPolicy::ValidSmeltedSpan(vector.begin,vector.end,vector.capacity)) return false;
    using EIDNativeContextPolicy::SmeltedCounts;
    std::vector<SmeltedCounts> counts((vector.end - vector.begin) / sizeof(SmeltedCounts));
    if (!counts.empty() && !ReadOwnTaskMemory(vector.begin,counts.data(),counts.size()*sizeof(SmeltedCounts))) return false;
    if (signature) {
        uint64_t hash = 14695981039346656037ull;
        for (const auto& count : counts) {
            hash ^= static_cast<uint16_t>(count.regular); hash *= 1099511628211ull;
            hash ^= static_cast<uint16_t>(count.golden); hash *= 1099511628211ull;
        }
        *signature = hash;
    }
    return EIDNativeContextPolicy::DecodeSmeltedCounts(counts,identities);
}

static bool ReadPickupHistory(vm_address_t player,
                             std::vector<EIDInventoryPreviewPolicy::HistoryEntry>& entries) {
    RemotePointerVector span{}, after{};
    if (!ReadOwnTaskMemory(player+kPlayerPickupHistoryOffset,&span,sizeof(span)) ||
        !EIDInventoryPreviewPolicy::HistorySpan(span.begin,span.end,span.capacity)) return false;
    entries.resize((span.end-span.begin)/sizeof(EIDInventoryPreviewPolicy::HistoryEntry));
    if (!entries.empty() && !ReadOwnTaskMemory(span.begin,entries.data(),entries.size()*sizeof(entries[0]))) return false;
    // The background reader must not publish a vector that changed allocation
    // during copying. Main-thread resolution re-reads it before any preview.
    return ReadOwnTaskMemory(player+kPlayerPickupHistoryOffset,&after,sizeof(after)) &&
        span.begin == after.begin && span.end == after.end && span.capacity == after.capacity;
}

static NSDictionary *ReadDescriptionStats(vm_address_t player) {
    int32_t type, coins, bombs, keys, soul = 0, blood = 0;
    float speed, delay, damage, range;
    if (!ReadOwnTaskMemory(player+kPlayerTypeOffset,&type,sizeof(type)) || type < 0 || type > 40 ||
        !ReadOwnTaskMemory(player+kPlayerMoveSpeedOffset,&speed,sizeof(speed)) ||
        !ReadOwnTaskMemory(player+kPlayerMaxFireDelayOffset,&delay,sizeof(delay)) ||
        !ReadOwnTaskMemory(player+kPlayerDamageOffset,&damage,sizeof(damage)) ||
        !ReadOwnTaskMemory(player+kPlayerTearRangeOffset,&range,sizeof(range)) ||
        !ReadOwnTaskMemory(player+kPlayerCoinsOffset,&coins,sizeof(coins)) ||
        !ReadOwnTaskMemory(player+kPlayerBombsOffset,&bombs,sizeof(bombs)) ||
        !ReadOwnTaskMemory(player+kPlayerKeysOffset,&keys,sizeof(keys))) return nil;
    if (!std::isfinite(speed) || !std::isfinite(delay) || !std::isfinite(damage) || !std::isfinite(range) ||
        speed < 0 || speed > 20 || delay <= -1 || delay > 10000 || damage < 0 || damage > 100000 ||
        range < 0 || range > 100000 || coins < 0 || coins > 9999 || bombs < 0 || bombs > 9999 ||
        keys < 0 || keys > 9999) return nil;
    if (type == 18 && (!ReadOwnTaskMemory(player+kPlayerSoulChargeOffset,&soul,sizeof(soul)) || soul < 0 || soul > 9999)) return nil;
    if (type == 36 && (!ReadOwnTaskMemory(player+kPlayerBloodChargeOffset,&blood,sizeof(blood)) || blood < 0 || blood > 9999)) return nil;
    NSMutableDictionary *stats = [@{@"type":@(type), @"speed":@(speed), @"fire_delay":@(delay), @"damage":@(damage),
             @"range":@(range), @"coins":@(coins), @"bombs":@(bombs), @"keys":@(keys),
             @"soul_charge":@(soul), @"blood_charge":@(blood)} mutableCopy];
    float luck = 0;
    if (ReadOwnTaskMemory(player+kPlayerLuckOffset,&luck,sizeof(luck)) && std::isfinite(luck) && fabsf(luck) < 100000)
        stats[@"luck"] = @(luck);
    return stats.copy;
}

static NSArray *ReadRoomPedestals(vm_address_t game, const ScanContext& context) {
    // Native Black Rune iterates Room[0x19c8], count Room[0x19d4]. This is
    // authoritative room order, not the heap scanner's limited visible list.
    uintptr_t room = 0, list = 0; uint32_t count = 0;
    if (!ReadOwnTaskMemory(game+kGameCurrentRoomOffset,&room,sizeof(room)) || !room ||
        !ReadOwnTaskMemory(room+0x19c8,&list,sizeof(list)) ||
        !ReadOwnTaskMemory(room+0x19d4,&count,sizeof(count)) || count > 4096 || (count && !list)) return nil;
    std::vector<uintptr_t> entities(count);
    if (count && !ReadOwnTaskMemory(list,entities.data(),count*sizeof(uintptr_t))) return nil;
    NSMutableArray *pedestals = [NSMutableArray array];
    for (uintptr_t address : entities) {
        if (!address) continue;
        uintptr_t vtable = 0;
        if (!ReadOwnTaskMemory(address,&vtable,sizeof(vtable))) return nil;
        if (!IsCandidateVTable(context.pickupVTables,context.pickupVTableCount,vtable)) continue;
        std::array<uint8_t,0x578> object{};
        if (!ReadOwnTaskMemory(address,object.data(),object.size())) return nil;
        int32_t identity[3], wait;
        EIDPickupMetadataPolicy::Metadata metadata;
        if (!ReadPickupMetadata(object.data(),object.size(),metadata)) return nil;
        memcpy(identity,object.data()+0x38,sizeof(identity));
        memcpy(&wait,object.data()+0x570,sizeof(wait));
        if (identity[0] != 5 || identity[1] != 100 || identity[2] <= 0 || identity[2] > 732 ||
            object[0x1c3] || !object[0x1c2] || metadata.IsShopItem() || wait > 0) continue;
        [pedestals addObject:@{@"id":@(identity[2]),@"options":@(metadata.optionsIndex)}];
    }
    uintptr_t latestList = 0; uint32_t latestCount = 0;
    if (!ReadOwnTaskMemory(room+0x19c8,&latestList,sizeof(latestList)) || latestList != list ||
        !ReadOwnTaskMemory(room+0x19d4,&latestCount,sizeof(latestCount)) || latestCount != count) return nil;
    return pedestals.copy;
}

static NSArray *ReadSuperBumOwners(vm_address_t game, const ScanContext& context, const VMRegionResult& players) {
    uintptr_t room=0, list=0; uint32_t count=0;
    if (!ReadOwnTaskMemory(game+kGameCurrentRoomOffset,&room,sizeof(room)) || !room ||
        !ReadOwnTaskMemory(room+0x19c8,&list,sizeof(list)) ||
        !ReadOwnTaskMemory(room+0x19d4,&count,sizeof(count)) || count>4096 || (count && !list)) return nil;
    std::vector<uintptr_t> entities(count);
    if (count && !ReadOwnTaskMemory(list,entities.data(),count*sizeof(uintptr_t))) return nil;
    NSMutableArray *owners = [NSMutableArray arrayWithCapacity:players.playerCount];
    for (size_t index=0; index<players.playerCount; ++index) [owners addObject:@NO];
    for (uintptr_t address : entities) {
        if (!address) continue;
        uintptr_t vtable=0;
        if (!ReadOwnTaskMemory(address,&vtable,sizeof(vtable))) return nil;
        if (!IsCandidateVTable(context.familiarVTables,context.familiarVTableCount,vtable)) continue;
        std::array<uint8_t,kFamiliarOwnerOffset+sizeof(uintptr_t)> bytes{};
        if (!ReadOwnTaskMemory(address,bytes.data(),bytes.size())) return nil;
        int32_t identity[3]{}; uintptr_t owner=0, again=0;
        memcpy(identity,bytes.data()+kEntityTypeOffset,sizeof(identity));
        if (identity[0]!=3 || identity[1]!=kSuperBumFamiliarVariant || bytes[0x1c3] || !bytes[0x1c2]) continue;
        memcpy(&owner,bytes.data()+kFamiliarOwnerOffset,sizeof(owner));
        if (!ReadOwnTaskMemory(address+kFamiliarOwnerOffset,&again,sizeof(again)) || owner!=again) return nil;
        for (size_t index=0; index<players.playerCount; ++index)
            if (owner && owner==players.players[index].address) owners[index]=@YES;
    }
    uintptr_t confirmation=0; uint32_t latestCount=0;
    if (!ReadOwnTaskMemory(room+0x19c8,&confirmation,sizeof(confirmation)) || confirmation!=list ||
        !ReadOwnTaskMemory(room+0x19d4,&latestCount,sizeof(latestCount)) || latestCount!=count) return nil;
    return owners.copy;
}

static NSDictionary *ReadAbsorptionPrediction(vm_address_t player, unsigned count, bool rune) {
    RemotePointerVector vector;
    size_t offset = rune ? 0x1bf8 : 0x1bb0, identifier = rune ? 41 : 477;
    if (!ReadOwnTaskMemory(player+offset,&vector,sizeof(vector)) || !vector.begin || vector.end < vector.begin ||
        vector.capacity < vector.end || (vector.end-vector.begin)%16 ||
        (vector.capacity-vector.begin)/16 > 4096 || (vector.end-vector.begin)/16 <= identifier) return nil;
    EIDPredictionPolicy::RNG rng{}, confirmation{};
    uintptr_t address = vector.begin+identifier*sizeof(rng);
    if (!ReadOwnTaskMemory(address,&rng,sizeof(rng)) || !EIDPredictionPolicy::Valid(rng) ||
        !ReadOwnTaskMemory(address,&confirmation,sizeof(confirmation)) || memcmp(&rng,&confirmation,sizeof(rng))) return nil;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *mode in @[@"room",@"single",@"purchased"]) {
        unsigned total = [mode isEqual:@"single"] ? 1 : [mode isEqual:@"purchased"] ? count+1 : count;
        auto increases = EIDPredictionPolicy::Absorption(rng.seed,total,rune);
        NSMutableArray *stats = [NSMutableArray arrayWithCapacity:6];
        for (unsigned increase : increases) [stats addObject:@(increase)];
        result[mode] = stats.copy;
    }
    return result.copy;
}

static NSDictionary *ReadRepeatState(vm_address_t address) {
    uint8_t type = 0xff;
    int32_t id = 0, extra = 0, lastPill = -1;
    if (!ReadOwnTaskMemory(address+kPlayerWildCardOffset,&type,sizeof(type)) ||
        !ReadOwnTaskMemory(address+kPlayerWildCardOffset+4,&id,sizeof(id)) ||
        !ReadOwnTaskMemory(address+kPlayerWildCardOffset+8,&extra,sizeof(extra)) ||
        !ReadOwnTaskMemory(address+kPlayerLastPillColorOffset,&lastPill,sizeof(lastPill))) return nil;
    // Also included in the background refresh signature, so using a new
    // effect repaints an unchanged Wild Card pickup or pause-inventory entry.
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    if (EIDRepeatPolicy::WildCard(type,id,extra))
        state[@"wild_card"] = @{@"type":@(type),@"id":@(id),@"extra":@(extra)};
    if (lastPill == 0 || EIDRepeatPolicy::PillColor(lastPill)) state[@"last_pill_color"] = @(lastPill);
    return state.copy;
}

static bool ReadCollectibleRNG(vm_address_t player, size_t item, EIDPredictionPolicy::RNG& rng) {
    RemotePointerVector span{}, after{};
    EIDPredictionPolicy::RNG confirmation{};
    if (item > kMaximumCollectibleID ||
        !ReadOwnTaskMemory(player+0x1bb0,&span,sizeof(span)) || !span.begin || span.begin%4 ||
        span.end < span.begin || span.capacity < span.end || (span.end-span.begin)%sizeof(rng) ||
        (span.capacity-span.begin)%sizeof(rng) || (span.capacity-span.begin)/sizeof(rng) > 4096 ||
        (span.end-span.begin)/sizeof(rng) <= item ||
        !ReadOwnTaskMemory(span.begin+item*sizeof(rng),&rng,sizeof(rng)) || !EIDPredictionPolicy::Valid(rng) ||
        !ReadOwnTaskMemory(span.begin+item*sizeof(rng),&confirmation,sizeof(confirmation)) ||
        memcmp(&rng,&confirmation,sizeof(rng)) ||
        !ReadOwnTaskMemory(player+0x1bb0,&after,sizeof(after))) return false;
    return span.begin == after.begin && span.end == after.end && span.capacity == after.capacity;
}

static bool ReadCurrentRoomAddress(vm_address_t& roomAddress);
static bool ReadRoomDecorationSeed(uint32_t& seed) {
    vm_address_t room = 0;
    uintptr_t descriptor = 0;
    // Crooked Penny's native branch reads Room[8]->DecorationSeed (+0x64).
    return ReadCurrentRoomAddress(room) &&
        ReadOwnTaskMemory(room+kRoomDescriptorOffset,&descriptor,sizeof(descriptor)) && descriptor &&
        ReadOwnTaskMemory(descriptor+0x64,&seed,sizeof(seed));
}

static bool ReadPlayerActiveIDs(vm_address_t player, std::array<int32_t,4>& ids) {
    std::array<int32_t,4> confirmation{};
    for (size_t i=0; i<ids.size(); ++i)
        if (!ReadOwnTaskMemory(player+kPlayerActiveItemsOffset+i*kPlayerActiveItemStride,&ids[i],sizeof(ids[i])) ||
            ids[i] < 0 || ids[i] > (int32_t)kMaximumCollectibleID) return false;
    for (size_t i=0; i<ids.size(); ++i)
        if (!ReadOwnTaskMemory(player+kPlayerActiveItemsOffset+i*kPlayerActiveItemStride,&confirmation[i],sizeof(confirmation[i]))) return false;
    return ids == confirmation;
}

static NSArray *ReadVoidedActives(vm_address_t player) {
    RemotePointerVector span{}, confirmation{};
    if (!ReadOwnTaskMemory(player+kPlayerVoidActivesOffset,&span,sizeof(span)) ||
        !EIDCurrentEffectsPolicy::ValidSpan(span.begin,span.end,span.capacity,4,1024)) return nil;
    std::vector<int32_t> ids((span.end-span.begin)/4), second(ids.size());
    if (!ids.empty() && (!ReadOwnTaskMemory(span.begin,ids.data(),ids.size()*4) ||
        !ReadOwnTaskMemory(span.begin,second.data(),second.size()*4) || ids != second)) return nil;
    if (!ReadOwnTaskMemory(player+kPlayerVoidActivesOffset,&confirmation,sizeof(confirmation)) ||
        memcmp(&span,&confirmation,sizeof(span)) || !EIDCurrentEffectsPolicy::ValidVoidIDs(ids)) return nil;
    NSMutableArray *result = [NSMutableArray array];
    for (int32_t id : ids) if (id != 477) [result addObject:@(id)]; // Void itself is skipped by the native effect.
    return result.copy;
}

static NSDictionary *ReadPurityState(vm_address_t player) {
    int32_t boost=-1, second=-1; uint8_t disabled=0xff, disabledAgain=0xff;
    RemotePointerVector effects{}, confirmation{};
    if (!ReadOwnTaskMemory(player+kPlayerPurityBoostOffset,&boost,sizeof(boost)) ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+0x21,&disabled,1) ||
        !EIDCurrentEffectsPolicy::ValidPurity(boost,disabled) ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+8,&effects,sizeof(effects)) ||
        !EIDCurrentEffectsPolicy::ValidSpan(effects.begin,effects.end,effects.capacity,16,1024)) return nil;
    BOOL active = NO;
    // Exact read-only HasCollectibleEffect predicate from 0x1006fdc90:
    // metadata type 1, 3 or 4, ID 407, with effects not disabled.
    for (uintptr_t at=effects.begin; at<effects.end; at+=16) {
        uintptr_t metadata=0; int32_t def[2]{};
        if (!ReadOwnTaskMemory(at,&metadata,sizeof(metadata)) ||
            !ReadOwnTaskMemory(metadata,def,sizeof(def)) || def[0]<0 || def[0]>4) return nil;
        if ((def[0]==1 || def[0]==3 || def[0]==4) && def[1]==407) active=YES;
    }
    if (!ReadOwnTaskMemory(player+kPlayerPurityBoostOffset,&second,sizeof(second)) || second!=boost ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+0x21,&disabledAgain,1) || disabledAgain!=disabled ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+8,&confirmation,sizeof(confirmation)) ||
        memcmp(&effects,&confirmation,sizeof(effects))) return nil;
    return @{@"validated":@YES,@"active":@(active && !disabled),@"boost":@(boost)};
}

static bool ReadPlayerTransformationCounters(vm_address_t address,
    std::array<int32_t,kNativeTransformationCount>& counters);

static bool ResolvePillPresentation(int32_t rawSubtype, int32_t& variant, int32_t& subtype);

static NSSet *ReadCurrentCollectibleEffects(vm_address_t player) {
    RemotePointerVector span{}, after{};
    uint8_t disabled=0xff, second=0xff;
    if (!ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+0x21,&disabled,1) || disabled>1 ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+8,&span,sizeof(span)) ||
        !EIDCurrentEffectsPolicy::ValidSpan(span.begin,span.end,span.capacity,16,1024)) return nil;
    std::vector<uint8_t> bytes(span.end-span.begin), confirmation(bytes.size());
    if (!bytes.empty() && !ReadOwnTaskMemory(span.begin,bytes.data(),bytes.size())) return nil;
    NSMutableSet *items = [NSMutableSet set];
    for (size_t at=0; at<bytes.size(); at+=16) {
        uintptr_t metadata=0; int32_t definition[2]{};
        memcpy(&metadata,bytes.data()+at,sizeof(metadata));
        if (!metadata || !ReadOwnTaskMemory(metadata,definition,sizeof(definition)) ||
            definition[0]<0 || definition[0]>4) return nil;
        // Same metadata-type predicate as native HasCollectibleEffect.
        if (!disabled && (definition[0]==1 || definition[0]==3 || definition[0]==4) &&
            definition[1]>0 && definition[1]<=(int32_t)kMaximumCollectibleID) [items addObject:@(definition[1])];
    }
    if ((!bytes.empty() && (!ReadOwnTaskMemory(span.begin,confirmation.data(),confirmation.size()) || bytes!=confirmation)) ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+8,&after,sizeof(after)) || memcmp(&span,&after,sizeof(span)) ||
        !ReadOwnTaskMemory(player+kPlayerTemporaryEffectsOffset+0x21,&second,1) || second!=disabled) return nil;
    return items.copy;
}

template<size_t N> static bool VerifyCurrentEffectTable(uintptr_t image, size_t offset, const std::array<int32_t,N>& expected) {
    std::array<int32_t,N> actual{};
    return ReadOwnTaskMemory(image+offset,actual.data(),sizeof(actual)) && actual==expected;
}

static NSDictionary *ReadCurrentTrinketEffects(vm_address_t player, NSSet *owned) {
    if (!EIDFeatureEnabled(NSUserDefaults.standardUserDefaults,EIDHiddenInfoKey)) return nil;
    if (![owned containsObject:@"5.350.32"] && ![owned containsObject:@"5.350.132"] && ![owned containsObject:@"5.350.153"]) return nil;
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    uintptr_t image = (uintptr_t)header;
    if (!header || !VerifyCurrentEffectTable(image,0x953360,EIDTrinketEffectPolicy::Liberty) ||
        !VerifyCurrentEffectTable(image,0x953378,EIDTrinketEffectPolicy::Syringe) ||
        !VerifyCurrentEffectTable(image,0x953398,EIDTrinketEffectPolicy::Lock)) return nil;
    NSSet *effects = ReadCurrentCollectibleEffects(player);
    RemotePointerVector span{}, after{};
    if (!effects || !ReadOwnTaskMemory(player+kPlayerTrinketRNGOffset,&span,sizeof(span)) ||
        !EIDCurrentEffectsPolicy::ValidSpan(span.begin,span.end,span.capacity,16,4096)) return nil;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (int32_t trinket : {32,132,153}) {
        if (![owned containsObject:[NSString stringWithFormat:@"5.350.%d",trinket]] ||
            (span.end-span.begin)/16 <= (size_t)trinket) continue;
        EIDPredictionPolicy::RNG rng{}, confirmation{};
        uintptr_t at = span.begin+(size_t)trinket*sizeof(rng);
        if (!ReadOwnTaskMemory(at,&rng,sizeof(rng)) || !rng.seed ||
            !rng.shift1 || rng.shift1>31 || !rng.shift2 || rng.shift2>31 || !rng.shift3 || rng.shift3>31 ||
            !ReadOwnTaskMemory(at,&confirmation,sizeof(confirmation)) || memcmp(&rng,&confirmation,sizeof(rng))) continue;
        // Use the CURRENT seed, with no RNG advance. Require the selected
        // effect to have actually been applied; a failed room proc stays hidden.
        int32_t item = EIDTrinketEffectPolicy::CurrentCandidate(trinket,rng.seed);
        result[@(trinket).stringValue] = @{@"validated":@YES,@"result":[effects containsObject:@(item)] ? @(item) : @0};
    }
    if (!ReadOwnTaskMemory(player+kPlayerTrinketRNGOffset,&after,sizeof(after)) || memcmp(&span,&after,sizeof(span))) return nil;
    return result.copy;
}

static NSDictionary *ReadDescriptionPlayer(vm_address_t address) {
    int32_t type = -1;
    if (!ReadOwnTaskMemory(address+kPlayerTypeOffset,&type,sizeof(type)) || type < 0 || type > 40) return nil;
    NSMutableDictionary *player = [ReadDescriptionStats(address) mutableCopy] ?: [NSMutableDictionary dictionary];
    player[@"type"] = @(type);
    uint8_t goldenBomb=0xff, goldenAgain=0xff;
    if (ReadOwnTaskMemory(address+kPlayerGoldenBombOffset,&goldenBomb,1) && goldenBomb<=1 &&
        ReadOwnTaskMemory(address+kPlayerGoldenBombOffset,&goldenAgain,1) && goldenBomb==goldenAgain)
        player[@"golden_bomb"] = @(goldenBomb!=0);
    NSDictionary *repeat = ReadRepeatState(address);
    if (repeat) player[@"repeat_state"] = repeat;
    std::vector<EIDInventoryPreviewPolicy::HistoryEntry> history;
    if (ReadPickupHistory(address,history))
        player[@"pickup_history_signature"] = @(EIDInventoryPreviewPolicy::HistorySignature(history));
    std::array<int32_t,kMaximumCollectibleID+1> counts{};
    std::array<int32_t,kPlayerTrinketSlotCount> trinkets{};
    std::array<VMPlayerPocketItem,kPlayerPocketItemCount> pockets{};
    std::vector<int32_t> swallowed;
    BOOL countsReadable = ReadPlayerCollectibleCounts(address,counts);
    if (countsReadable) {
        NSMutableDictionary *numbers = [NSMutableDictionary dictionary];
        for (size_t item = 1; item < counts.size(); ++item) if (counts[item]) numbers[@(item).stringValue] = @(counts[item]);
        player[@"collectible_counts"] = numbers.copy;
        if (counts[464]) {
            std::array<int32_t,7> health{};
            int32_t bone=0, poop=0;
            if (ReadOwnTaskMemory(address+0x16b8,health.data(),sizeof(health)) &&
                ReadOwnTaskMemory(address+0x2450,&bone,sizeof(bone)) &&
                ReadOwnTaskMemory(address+0x269c,&poop,sizeof(poop))) {
                NSMutableArray *signature = [NSMutableArray array];
                for (int32_t value : health) [signature addObject:@(value)];
                [signature addObject:@(bone)]; [signature addObject:@(poop)];
                player[@"glyph_health_signature"] = signature.copy;
            }
        }
    }
    uint8_t disabled = 0xff;
    if (countsReadable && ReadOwnTaskMemory(address+kPlayerNonQuestItemsDisabledOffset,&disabled,sizeof(disabled)) && disabled <= 1) {
        // Native HasCollectible(59), 0x1004eed80: virtual Belial ownership is
        // Judas/Black Judas + HasCollectible(619), not a stored count of 59.
        player[@"has_passive_belial"] = @(EIDNativeContextPolicy::HasPassiveBelial(type,counts[619],counts[59],disabled != 0));
    }
    uint64_t smeltedSignature = 0;
    std::array<int32_t,4> actives{};
    if (countsReadable && ReadPlayerActiveIDs(address,actives) && ReadPlayerTrinkets(address,trinkets) &&
        ReadPlayerPocketItems(address,pockets) && ReadSmeltedTrinkets(address,swallowed,&smeltedSignature)) {
        player[@"smelted_signature"] = @(smeltedSignature);
        player[@"trinket_slots"] = @[@(trinkets[0]),@(trinkets[1])];
        NSMutableSet *owned = [NSMutableSet set];
        for (size_t item = 1; item < counts.size(); ++item) if (counts[item])
            [owned addObject:[NSString stringWithFormat:@"5.100.%lu",(unsigned long)item]];
        for (int32_t item : trinkets) if ((item & 0x7fff) > 0)
            [owned addObject:[NSString stringWithFormat:@"5.350.%d",item & 0x7fff]];
        for (int32_t item : swallowed) if ((item & 0x7fff) > 0)
            [owned addObject:[NSString stringWithFormat:@"5.350.%d",item & 0x7fff]];
        for (const auto& pocket : pockets) if (pocket.type == 2 && pocket.id > 0)
            [owned addObject:[NSString stringWithFormat:@"5.100.%d",pocket.id]];
        for (const auto& pocket : pockets) if (pocket.type == 1 && pocket.id > 0)
            [owned addObject:[NSString stringWithFormat:@"5.300.%d",pocket.id]];
        for (const auto& pocket : pockets) if (pocket.type == 0 && pocket.id>0) {
            int32_t variant=0, effect=0;
            if (ResolvePillPresentation(pocket.id,variant,effect) && effect>0 && effect<=64 &&
                (variant==EIDPickupVariantPill || variant==EIDPickupVariantHorsePill))
                [owned addObject:[NSString stringWithFormat:@"5.70.%d",effect]];
        }
        player[@"active_slots"] = @[@(actives[0]),@(actives[1]),@(actives[2]),@(actives[3])];
        NSMutableArray *activeIDs = [NSMutableArray array];
        for (int32_t id : actives) if (id) {
            [activeIDs addObject:@(id)];
            [owned addObject:[NSString stringWithFormat:@"5.100.%d",id]];
        }
        player[@"active_ids"] = activeIDs.copy;
        NSMutableArray *cards = [NSMutableArray array];
        for (const auto& pocket : pockets) if (pocket.type == 1 && pocket.id > 0 && pocket.id <= 97)
            [cards addObject:@(pocket.id)];
        player[@"pocket_cards"] = cards.copy;
        player[@"owned"] = [owned.allObjects sortedArrayUsingSelector:@selector(compare:)];
        std::array<int32_t,kNativeTransformationCount> forms{};
        if (ReadPlayerTransformationCounters(address,forms)) {
            NSMutableArray *values = [NSMutableArray array];
            for (int32_t value : forms) [values addObject:@(value)];
            player[@"forms"] = values.copy;
        }
        if ([owned containsObject:@"5.100.477"]) {
            NSArray *voided = ReadVoidedActives(address);
            if (voided) player[@"void_actives"] = voided;
        }
        if ([owned containsObject:@"5.100.407"]) {
            NSDictionary *purity = ReadPurityState(address);
            if (purity) player[@"purity"] = purity;
        }
        if ([owned containsObject:@"5.350.166"]) {
            int32_t clay=-1, again=-1;
            if (ReadOwnTaskMemory(address+kPlayerModelingClayOffset,&clay,sizeof(clay)) &&
                EIDCurrentEffectsPolicy::ValidClay(clay) &&
                ReadOwnTaskMemory(address+kPlayerModelingClayOffset,&again,sizeof(again)) && clay==again)
                player[@"modeling_clay"] = @{@"validated":@YES,@"result":@(clay)};
        }
        NSDictionary *trinketEffects = ReadCurrentTrinketEffects(address,owned);
        if (trinketEffects) player[@"trinket_effects"] = trinketEffects;
        if ([NSUserDefaults.standardUserDefaults boolForKey:@"IsaacEIDOutcomePredictions"] &&
            [owned containsObject:@"5.100.485"]) {
            EIDPredictionPolicy::RNG rng{};
            uint32_t decoration = 0;
            if (ReadCollectibleRNG(address,485,rng) && ReadRoomDecorationSeed(decoration))
                player[@"outcome_signature"] = @[@(rng.seed),@(decoration)];
        }
        if ([NSUserDefaults.standardUserDefaults boolForKey:@"IsaacEIDOutcomePredictions"] &&
            [owned containsObject:@"5.100.489"]) {
            NSMutableArray *modes = [NSMutableArray array];
            for (size_t slot = 0; slot < kPlayerPocketItemCount; ++slot) {
                int32_t active = 0; int16_t mode = -1;
                uintptr_t record = address+kPlayerActiveItemsOffset+slot*kPlayerActiveItemStride;
                if (ReadOwnTaskMemory(record,&active,sizeof(active)) && active == 489 &&
                    ReadOwnTaskMemory(record+0x1a,&mode,sizeof(mode)) && mode >= 0 && mode < 10)
                    [modes addObject:@[@(slot),@(mode)]];
            }
            player[@"outcome_dice_modes"] = modes.copy;
        }
        if ([owned containsObject:@"5.100.710"]) {
            NSDictionary *bag = ReadCraftingBag(address);
            if (bag) player[@"crafting_bag"] = bag;
        }
    }
    return player.copy;
}

static bool ReadPlayerTransformationCounters(
    vm_address_t playerAddress,
    std::array<int32_t, kNativeTransformationCount>& counters) {
    if (!ReadOwnTaskMemory(playerAddress + kPlayerTransformationCountersOffset,
                           counters.data(), sizeof(counters))) return false;
    for (int32_t counter : counters) {
        // Native AddPlayerForm clamps the lower bound to zero. This generous
        // upper bound rejects a stale/wrong layout without constraining mods.
        if (counter < 0 || counter > 999) return false;
    }
    return true;
}

static bool ReadPauseMenuState(int32_t& state) {
    state = 0;
    vm_address_t game = 0;
    if (!ReadGameObjectAddress(game) ||
        !ReadOwnTaskMemory(game + kGamePauseMenuStateOffset, &state, sizeof(state))) {
        return false;
    }
    // PauseScreen::Update in this build switches over states 0..3.
    if (state < 0 || state > 3) {
        state = 0;
        return false;
    }
    return true;
}

static bool ReadRunSeed(uint32_t& seed) {
    seed = 0;
    vm_address_t game = 0;
    return ReadGameObjectAddress(game) &&
        ReadOwnTaskMemory(game + kGameRunSeedOffset, &seed, sizeof(seed)) && seed != 0;
}

static bool ReadCurrentCurseMask(uint32_t& curses) {
    curses = 0;
    vm_address_t game = 0;
    if (!ReadGameObjectAddress(game) ||
        !ReadOwnTaskMemory(game + kGameCursesOffset, &curses, sizeof(curses))) {
        return false;
    }
    // Native Repentance uses the low byte for LevelCurse flags. Reject an
    // unexpected layout instead of suppressing collectible identities based
    // on unrelated Game memory.
    if (curses & ~0xffu) {
        curses = 0;
        return false;
    }
    return true;
}

static bool ReadCurrentRoomAddress(vm_address_t& roomAddress) {
    roomAddress = 0;
    vm_address_t game = 0;
    uintptr_t room = 0;
    if (!ReadGameObjectAddress(game) ||
        !ReadOwnTaskMemory(game + kGameCurrentRoomOffset, &room, sizeof(room)) || !room) {
        return false;
    }
    roomAddress = static_cast<vm_address_t>(room);
    return true;
}

struct VMRoomPathMap {
    int32_t width = 0;
    int32_t height = 0;
    size_t pathCount = 0;
    std::array<int32_t, EIDPickupPolicy::kMaximumRoomGridCells> paths{};
};

static bool ReadCurrentRoomPathMap(VMRoomPathMap& map) {
    vm_address_t room = 0;
    if (!ReadCurrentRoomAddress(room) ||
        !ReadOwnTaskMemory(room + kRoomGridWidthOffset, &map.width, sizeof(map.width)) ||
        !ReadOwnTaskMemory(room + kRoomGridHeightOffset, &map.height, sizeof(map.height))) {
        return false;
    }
    if (map.width < 3 || map.height < 3 || map.width > 64 || map.height > 64) return false;
    const int64_t count = static_cast<int64_t>(map.width) * map.height;
    if (count <= 0 || count > static_cast<int64_t>(map.paths.size())) return false;
    map.pathCount = static_cast<size_t>(count);
    if (!ReadOwnTaskMemory(room + kRoomGridPathsOffset, map.paths.data(),
                           map.pathCount * sizeof(map.paths[0]))) return false;
    // Native Room::GetGridCollision treats values above 999 as blocked. EID's
    // own stricter policy uses <=900. Reject implausible data before applying it.
    for (size_t index = 0; index < map.pathCount; ++index) {
        if (map.paths[index] < 0 || map.paths[index] > 100000) return false;
    }
    return true;
}

static bool PickupHasReachablePath(const VMPickup& pickup,
                                   const VMRegionResult& players,
                                   const VMRoomPathMap *roomMap) {
    if (!pickup.hasPosition || !players.playerCount) return false;
    for (size_t playerIndex = 0; playerIndex < players.playerCount; ++playerIndex) {
        const VMPlayer& player = players.players[playerIndex];
        bool canFly = false;
        if (ReadPlayerCanFly(player.address, canFly) && canFly) return true;
        if (!roomMap) continue;
        EIDPickupPolicy::GridPoint start;
        EIDPickupPolicy::GridPoint finish;
        if (!EIDPickupPolicy::WorldToGrid(player.x, player.y, roomMap->width,
                                          roomMap->height, start) ||
            !EIDPickupPolicy::WorldToGrid(pickup.x, pickup.y, roomMap->width,
                                          roomMap->height, finish)) continue;
        if (EIDPickupPolicy::HasGridPath(roomMap->paths.data(), roomMap->pathCount,
                                         roomMap->width, roomMap->height,
                                         start, finish)) return true;
    }
    return false;
}

static size_t SuppressHiddenCardAndPillIdentities(VMRegionResult& pickups,
                                                   const VMRegionResult& players) {
    VMRoomPathMap roomMap;
    const bool roomPathAvailable = ReadCurrentRoomPathMap(roomMap);
    size_t output = 0;
    size_t suppressed = 0;
    for (size_t index = 0; index < pickups.pickupCount; ++index) {
        const VMPickup& pickup = pickups.pickups[index];
        bool reachable = true;
        if (pickup.variant == EIDPickupVariantCard ||
            EIDPickupPolicy::IsPill(pickup.variant)) {
            reachable = PickupHasReachablePath(
                pickup, players, roomPathAvailable ? &roomMap : nullptr);
        }
        if (!EIDPickupPolicy::ShouldRevealFloorIdentity(
                pickup.variant, pickup.subtype, pickup.isShopItem,
                pickup.optionsPickupIndex, reachable)) {
            suppressed++;
            continue;
        }
        if (output != index) pickups.pickups[output] = pickup;
        output++;
    }
    pickups.pickupCount = output;
    return suppressed;
}

static bool ReadCurrentRoomType(int32_t& roomType) {
    roomType = 0;
    vm_address_t room = 0;
    uintptr_t descriptor = 0;
    uintptr_t data = 0;
    if (!ReadCurrentRoomAddress(room) ||
        !ReadOwnTaskMemory(room + kRoomDescriptorOffset, &descriptor, sizeof(descriptor)) ||
        !descriptor ||
        !ReadOwnTaskMemory(descriptor + kRoomDescriptorDataOffset, &data, sizeof(data)) || !data ||
        !ReadOwnTaskMemory(data + kRoomConfigTypeOffset, &roomType, sizeof(roomType))) {
        roomType = 0;
        return false;
    }
    if (roomType < 1 || roomType > 29) {
        roomType = 0;
        return false;
    }
    return true;
}

static bool ResolvePillPresentation(int32_t rawSubtype, int32_t& variant, int32_t& subtype) {
    uint32_t rawColor = static_cast<uint32_t>(rawSubtype);
    uint32_t color = rawColor & kPillColorMask;
    if (color == 0 || color > kGoldenPillColor) return false;

    vm_address_t game = 0;
    if (!ReadGameObjectAddress(game)) return false;
    uintptr_t itemPool = game + kGameItemPoolOffset;
    uint8_t identified = 0;
    if (!ReadOwnTaskMemory(itemPool + kItemPoolIdentifiedPillsOffset + color,
                           &identified, sizeof(identified))) return false;
    if (identified > 1) return false;

    // Golden pills are visibly golden and intentionally have random effects.
    if (color == kGoldenPillColor) {
        variant = (rawColor & kHorsePillFlag) ? EIDPickupVariantHorsePill
                                              : EIDPickupVariantPill;
        subtype = 9999;
        return true;
    }
    if (identified != 1) {
        variant = EIDPickupVariantUnidentifiedPill;
        subtype = rawSubtype;
        return true;
    }

    int32_t effect = -1;
    if (!ReadOwnTaskMemory(itemPool + kItemPoolPillEffectsOffset + color * sizeof(effect),
                           &effect, sizeof(effect)) || effect < 0 || effect > 63) return false;
    variant = (rawColor & kHorsePillFlag) ? EIDPickupVariantHorsePill : EIDPickupVariantPill;
    subtype = effect + 1;
    return true;
}

static bool ValidateNativePillPool(NSUInteger& identifiedCount) {
    identifiedCount = 0;
    vm_address_t game = 0;
    if (!ReadGameObjectAddress(game)) return false;
    uintptr_t itemPool = game + kGameItemPoolOffset;
    for (uint32_t color = 1; color < kGoldenPillColor; ++color) {
        int32_t effect = -1;
        uint8_t identified = 0xff;
        if (!ReadOwnTaskMemory(itemPool + kItemPoolPillEffectsOffset + color * sizeof(effect),
                               &effect, sizeof(effect)) || effect < 0 || effect > 63 ||
            !ReadOwnTaskMemory(itemPool + kItemPoolIdentifiedPillsOffset + color,
                               &identified, sizeof(identified)) || identified > 1) return false;
        if (identified == 1) identifiedCount++;
    }
    return true;
}

static bool ReadRemoteLibCppString(const uint8_t *stringObject, std::string& value) {
    // This Isaac build uses libc++'s alternate string layout: long strings are
    // pointer/size/capacity and short strings store their size in byte 23.
    uintptr_t dataAddress = 0;
    uint64_t length = 0;
    uint64_t capacity = 0;
    memcpy(&dataAddress, stringObject, sizeof(dataAddress));
    memcpy(&length, stringObject + 8, sizeof(length));
    memcpy(&capacity, stringObject + 16, sizeof(capacity));
    char buffer[512]{};
    if (capacity & (1ull << 63)) {
        if (length >= sizeof(buffer) || (length && !dataAddress)) return false;
        if (length && !ReadOwnTaskMemory(dataAddress, buffer, static_cast<vm_size_t>(length))) return false;
        buffer[length] = '\0';
    } else {
        uint8_t shortLength = stringObject[23];
        if (shortLength >= 23) return false;
        memcpy(buffer, stringObject, shortLength);
        buffer[shortLength] = '\0';
    }
    value.assign(buffer);
    return true;
}

static NSDictionary *ReadCollectionSnapshot(void) {
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    uintptr_t manager = 0;
    if (!header || !ReadOwnTaskMemory(reinterpret_cast<vm_address_t>(header) +
        kManagerGlobalOffset, &manager, sizeof(manager)) || !manager) return nil;
    uintptr_t persistent = manager + kManagerPersistentDataOffset;
    std::array<uint8_t, 24> filenameBytes{};
    std::string filename;
    uint8_t readOnly = UINT8_MAX;
    std::array<uint8_t, kMaximumCollectibleID + 1> flags{};
    if (!ReadOwnTaskMemory(persistent + 0x10, filenameBytes.data(), filenameBytes.size()) ||
        !ReadRemoteLibCppString(filenameBytes.data(), filename) ||
        !ReadOwnTaskMemory(persistent + 1, &readOnly, sizeof(readOnly)) || readOnly > 1 ||
        !ReadOwnTaskMemory(persistent + kPersistentCollectionOffset, flags.data(), flags.size()) ||
        !EIDNativeContextPolicy::ValidCollectionFlags(flags.data(), flags.size())) return nil;
    NSString *basename = [[NSString stringWithUTF8String:filename.c_str()] lastPathComponent];
    NSInteger slot = 0;
    for (NSInteger candidate = 1; candidate <= 3; ++candidate)
        if ([basename isEqualToString:[NSString stringWithFormat:@"rep_persistentgamedata%ld.dat",(long)candidate]]) slot = candidate;
    if (!slot) return nil; // Never confuse another DLC or an unloaded slot.
    NSMutableArray *missing = [NSMutableArray array];
    for (size_t item = 1; item < flags.size(); ++item) if (!flags[item]) [missing addObject:@(item)];
    return @{@"slot":@(slot), @"progress_allowed":@(readOnly == 0), @"missing":missing.copy};
}

static NSDictionary *ReadUnlockHintState(void) {
    NSDictionary *before = ReadCollectionSnapshot();
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    uintptr_t manager=0; uint32_t prologue=0;
    if (!header || ![before[@"progress_allowed"] boolValue] ||
        !ReadOwnTaskMemory((uintptr_t)header+kManagerGlobalOffset,&manager,sizeof(manager)) || !manager ||
        !ReadOwnTaskMemory((uintptr_t)header+kPersistentIsAchievementUnlockedOffset,&prologue,4) || prologue!=0x3100083f) return nil;
    NSMutableDictionary *state = [@{@"validated":@YES,@"slot":before[@"slot"]} mutableCopy];
    // Persistent::Unlocked reads a byte at +0x28+ID (0x100702818). Read the
    // actual selected save, not its challenge-mode fallback or Game Center.
    for (int32_t achievement : {82,366}) {
        uint8_t flag=0xff, confirmation=0xff;
        uintptr_t at=manager+kManagerPersistentDataOffset+0x28+(size_t)achievement;
        if (!ReadOwnTaskMemory(at,&flag,1) || flag>1 ||
            !ReadOwnTaskMemory(at,&confirmation,1) || flag!=confirmation) return nil;
        state[@(achievement).stringValue] = @(flag!=0);
    }
    NSDictionary *after = ReadCollectionSnapshot();
    uintptr_t latest=0;
    if (!after || ![before[@"slot"] isEqual:after[@"slot"]] || ![after[@"progress_allowed"] boolValue] ||
        !ReadOwnTaskMemory((uintptr_t)header+kManagerGlobalOffset,&latest,sizeof(latest)) || latest!=manager) return nil;
    return state.copy;
}

using PickupVisibility = EIDCollectibleVisibilityPolicy::State;

static PickupVisibility PickupVisibilityState(const uint8_t *object, size_t available) {
    static const bool layoutValid = [] {
        const auto *header = IsaacExecutableHeader(nullptr);
        return header && EIDCollectibleVisibilityPolicy::ValidateLayout(
            reinterpret_cast<uintptr_t>(header),ReadOwnTaskMemory);
    }();
    if (!layoutValid) return PickupVisibility::Unreadable;
    return EIDCollectibleVisibilityPolicy::ReadNativeArtwork(object,available,
        ReadOwnTaskMemory,ReadRemoteLibCppString);
}

static bool IsDescribableVariant(int32_t variant) {
    return variant == EIDPickupVariantPill || variant == EIDPickupVariantCollectible ||
        variant == EIDPickupVariantHorsePill ||
        variant == EIDPickupVariantUnidentifiedPill || variant == EIDPickupVariantCard ||
        variant == EIDPickupVariantTrinket || variant == EIDPickupVariantDiceRoom ||
        variant == EIDPickupVariantSacrificeRoom || variant == EIDPickupVariantSanguineBond;
}

static void AddVMPickup(VMRegionResult& result, int32_t variant, int32_t subtype,
                        float x, float y, bool hasPosition,
                        bool isShopItem = false, int32_t optionsPickupIndex = 0,
                        int32_t rawPillSubtype = 0, int32_t flipID = 0,
                        vm_address_t address = 0, uint32_t cycleSeed = 0, uint32_t outcomeSeed = 0) {
    if (!IsDescribableVariant(variant) || subtype <= 0 || subtype > 65535) return;
    // Subtype zero and out-of-range tarot IDs are unknown/hidden card identities.
    if (variant == EIDPickupVariantCard && subtype > 97) return;
    // Keep duplicate identities: two equal cards/trinkets may exist at different positions,
    // and proximity must choose the actual nearest entity rather than the first copy.
    if (result.pickupCount < result.pickups.size()) {
        result.pickups[result.pickupCount++] = {
            variant, subtype, x, y, hasPosition, isShopItem, optionsPickupIndex, rawPillSubtype, flipID,address,cycleSeed,outcomeSeed
        };
    }
}

static bool ResolveSacrificeRoomSpikes(const ScanContext& context,
                                       VMRegionResult& result) {
    vm_address_t room = 0;
    int32_t roomType = 0;
    if (!ReadCurrentRoomAddress(room) || !ReadCurrentRoomType(roomType)) return false;

    std::array<uintptr_t, kRoomGridEntityCount> gridEntities{};
    if (!ReadOwnTaskMemory(room + kRoomGridEntitiesOffset, gridEntities.data(),
                           sizeof(gridEntities))) return false;

    int32_t roomGridWidth=0, roomGridHeight=0;
    if (!ReadOwnTaskMemory(room+kRoomGridWidthOffset,&roomGridWidth,4) ||
        !ReadOwnTaskMemory(room+kRoomGridHeightOffset,&roomGridHeight,4) ||
        roomGridWidth<1 || roomGridWidth>28 || roomGridHeight<1 || roomGridHeight>28 ||
        (size_t)(roomGridWidth*roomGridHeight)>gridEntities.size()) return false;
    for (size_t gridIndex = 0; gridIndex < (size_t)(roomGridWidth*roomGridHeight); ++gridIndex) {
        vm_address_t gridEntity = static_cast<vm_address_t>(gridEntities[gridIndex]);
        if (!gridEntity) continue;
        std::array<uint8_t, kGridEntityVarDataOffset + sizeof(int32_t)> object{};
        if (!ReadOwnTaskMemory(gridEntity, object.data(), object.size())) continue;
        uintptr_t vtable = 0;
        int32_t gridType = 0;
        int32_t gridVariant = 0;
        int32_t varData = 0;
        memcpy(&vtable, object.data(), sizeof(vtable));
        if (!IsCandidateVTable(context.gridSpikesVTables,
                               context.gridSpikesVTableCount, vtable)) continue;
        result.gridSpikesVTableReferences++;
        memcpy(&gridType, object.data() + kGridEntityDescOffset, sizeof(gridType));
        memcpy(&gridVariant, object.data() + kGridEntityDescOffset + 4, sizeof(gridVariant));
        memcpy(&varData, object.data() + kGridEntityVarDataOffset, sizeof(varData));
        if (gridType != kGridSpikesType || varData < 0 || varData > 1000) continue;
        BOOL sanguine = gridVariant>=100 && gridVariant<=255;
        if (!sanguine && roomType!=kSacrificeRoomType) continue;

        float gridX = 40.0f + 40.0f * static_cast<float>(gridIndex % roomGridWidth);
        float gridY = 80.0f + 40.0f * static_cast<float>(gridIndex / roomGridWidth);
        int32_t payout = varData >= 11 ? 12 : varData + 1;
        AddVMPickup(result, sanguine ? EIDPickupVariantSanguineBond : EIDPickupVariantSacrificeRoom, sanguine ? 692 : payout,
                    gridX, gridY, true);
    }
    return true;
}

static void AddVMPlayer(VMRegionResult& result, vm_address_t address, float x, float y) {
    for (size_t index = 0; index < result.playerCount; ++index) {
        if (result.players[index].address == address) return;
    }
    if (result.playerCount < result.players.size()) {
        result.players[result.playerCount++] = {address, x, y};
    }
}

static void ScanVMCopy(const ScanContext& context, const uint8_t *bytes, size_t size,
                       size_t scanLimit, vm_address_t sourceAddress, VMRegionResult& result) {
    if (size < kEntityTypeOffset + 12) return;
    scanLimit = MIN(scanLimit, size);
    for (size_t offset = 0; offset < scanLimit && offset + kEntityTypeOffset + 12 <= size;
         offset += sizeof(uintptr_t)) {
        uintptr_t vtable;
        memcpy(&vtable, bytes + offset, sizeof(vtable));
        bool pickupVTable = IsCandidateVTable(context.pickupVTables, context.pickupVTableCount, vtable);
        bool playerVTable = IsCandidateVTable(context.playerVTables, context.playerVTableCount, vtable);
        bool familiarVTable = IsCandidateVTable(context.familiarVTables,
                                                context.familiarVTableCount, vtable);
        bool slotVTable = IsCandidateVTable(context.slotVTables, context.slotVTableCount, vtable);
        bool effectVTable = IsCandidateVTable(context.effectVTables, context.effectVTableCount, vtable);
        if (!pickupVTable && !playerVTable && !familiarVTable &&
            !slotVTable && !effectVTable) continue;

        int32_t identity[3];
        memcpy(identity, bytes + offset + kEntityTypeOffset, sizeof(identity));
        bool activeObject = true;
        if (offset + kEntityStateOffset + 4 <= size) {
            const uint8_t *state = bytes + offset + kEntityStateOffset;
            activeObject = state[0] && state[2] && !state[3];
        }
        float x = 0;
        float y = 0;
        bool positionAvailable = offset + kEntityPositionOffset + 2 * sizeof(float) <= size;
        if (positionAvailable) {
            memcpy(&x, bytes + offset + kEntityPositionOffset, sizeof(x));
            memcpy(&y, bytes + offset + kEntityPositionOffset + sizeof(float), sizeof(y));
            positionAvailable = PlausiblePosition(x, y);
        }
        if (pickupVTable) {
            result.pickupVTableReferences++;
            vm_address_t referenceAddress = sourceAddress + offset;
            if (!result.firstPickupVTableAddress || referenceAddress < result.firstPickupVTableAddress) {
                result.firstPickupVTableAddress = referenceAddress;
            }
            if (referenceAddress > result.lastPickupVTableAddress) {
                result.lastPickupVTableAddress = referenceAddress;
            }
            if (activeObject && identity[0] == 5 && IsDescribableVariant(identity[1])) {
                int32_t displayVariant = identity[1];
                int32_t displaySubtype = identity[2];
                EIDPickupMetadataPolicy::Metadata metadata;
                const bool pickupMetadataAvailable = ReadPickupMetadata(bytes + offset,size - offset,metadata);
                // Fail closed for card identity if its shop/options metadata cannot
                // be read; showing it could reveal a purchase or Options? choice.
                if (displayVariant == EIDPickupVariantCard && !pickupMetadataAvailable) continue;
                if (displayVariant == EIDPickupVariantPill &&
                    !ResolvePillPresentation(displaySubtype, displayVariant, displaySubtype)) continue;
                PickupVisibility visibility = identity[1] == EIDPickupVariantCollectible
                    ? PickupVisibilityState(bytes + offset, size - offset)
                    : PickupVisibility::Visible;
                if (visibility == PickupVisibility::Visible) {
                    // Flip restores this native saved pickup record (0x1007188f8).
                    // Read it only after blind/protection checks have succeeded.
                    int32_t flipID = 0;
                    uintptr_t alternate = 0;
                    int32_t alternateIdentity[3]{};
                    if (identity[1] == 100 && ReadOwnTaskMemory(referenceAddress+0x610,&alternate,sizeof(alternate)) && alternate &&
                        ReadOwnTaskMemory(alternate,alternateIdentity,sizeof(alternateIdentity)) &&
                        alternateIdentity[0] == 5 && alternateIdentity[1] == 100 && alternateIdentity[2] > 0 && alternateIdentity[2] <= 732) {
                        uint8_t hidden = 1;
                        // Serialization at 0x10059d890 stores ForceBlind at +0x23.
                        if (ReadOwnTaskMemory(alternate+0x23,&hidden,sizeof(hidden)) && !hidden) flipID = alternateIdentity[2];
                    }
                    if (displayVariant == 100 && !displaySubtype && flipID) { displaySubtype = flipID; flipID = 0; }
                    uint32_t cycleSeed = 0, outcomeSeed = 0;
                    if (identity[1] == 100 && offset+kPickupCycleSeedOffset+sizeof(cycleSeed) <= size)
                        memcpy(&cycleSeed,bytes+offset+kPickupCycleSeedOffset,sizeof(cycleSeed));
                    if (identity[1] == 100 && offset+kPickupCurrentRNGOffset+sizeof(outcomeSeed) <= size)
                        memcpy(&outcomeSeed,bytes+offset+kPickupCurrentRNGOffset,sizeof(outcomeSeed));
                    AddVMPickup(result, displayVariant, displaySubtype, x, y,
                                positionAvailable, metadata.IsShopItem(), metadata.optionsIndex,
                                identity[1] == EIDPickupVariantPill ? identity[2] : 0,flipID,
                                identity[1] == 100 ? referenceAddress : 0,cycleSeed,outcomeSeed);
                } else if (visibility == PickupVisibility::Blind) {
                    result.blindPickupCount++;
                } else {
                    result.unreadableBlindStateCount++;
                }
#if EID_DEVELOPMENT_LAYOUT_CAPTURE
                if (visibility == PickupVisibility::Visible && !result.pickupSnapshotSize) {
                    result.pickupSnapshotSize = MIN(result.pickupSnapshot.size(), size - offset);
                    memcpy(result.pickupSnapshot.data(), bytes + offset, result.pickupSnapshotSize);
                }
#endif
            }
        }
        if (playerVTable) {
            result.playerVTableReferences++;
            if (identity[0] == 1 && identity[1] == 0 && identity[2] >= 0 &&
                identity[2] < 100 && positionAvailable) {
                AddVMPlayer(result, sourceAddress + offset, x, y);
#if EID_DEVELOPMENT_LAYOUT_CAPTURE
                if (!result.playerSnapshotSize) {
                    result.playerSnapshotSize = MIN(result.playerSnapshot.size(), size - offset);
                    memcpy(result.playerSnapshot.data(), bytes + offset, result.playerSnapshotSize);
                }
#endif
            }
        }
        if (familiarVTable) {
            result.familiarVTableReferences++;
            vm_address_t referenceAddress = sourceAddress + offset;
            if (!result.firstFamiliarVTableAddress ||
                referenceAddress < result.firstFamiliarVTableAddress) {
                result.firstFamiliarVTableAddress = referenceAddress;
            }
            if (referenceAddress > result.lastFamiliarVTableAddress) {
                result.lastFamiliarVTableAddress = referenceAddress;
            }
            if (activeObject && identity[0] == 3 &&
                identity[1] == kSuperBumFamiliarVariant) {
                result.superBumActive = true;
            }
        }
        if (slotVTable) {
            result.slotVTableReferences++;
            vm_address_t referenceAddress = sourceAddress + offset;
            if (!result.firstSlotVTableAddress || referenceAddress < result.firstSlotVTableAddress) {
                result.firstSlotVTableAddress = referenceAddress;
            }
            if (referenceAddress > result.lastSlotVTableAddress) {
                result.lastSlotVTableAddress = referenceAddress;
            }
            if (activeObject && identity[0] == 6 && identity[1] == 16 &&
                offset + kCranePrizeCollectibleOffset + sizeof(int32_t) <= size) {
                int32_t collectible = 0;
                memcpy(&collectible, bytes + offset + kCranePrizeCollectibleOffset,
                       sizeof(collectible));
                if (collectible > 0 && collectible <= 4096) {
                    AddVMPickup(result, EIDPickupVariantCollectible, collectible,
                                x, y, positionAvailable);
                }
            }
        }
        if (effectVTable) {
            result.effectVTableReferences++;
            vm_address_t referenceAddress = sourceAddress + offset;
            if (!result.firstEffectVTableAddress ||
                referenceAddress < result.firstEffectVTableAddress) {
                result.firstEffectVTableAddress = referenceAddress;
            }
            if (referenceAddress > result.lastEffectVTableAddress) {
                result.lastEffectVTableAddress = referenceAddress;
            }
            if (activeObject && identity[0] == 1000 && identity[1] == 76 &&
                identity[2] >= 0 && identity[2] < 6) {
                AddVMPickup(result, EIDPickupVariantDiceRoom, identity[2] + 1,
                            x, y, positionAvailable);
            }
        }
    }
}

static bool ScanVMRegion(const ScanContext& context, vm_address_t address,
                         vm_size_t size, VMRegionResult& result) {
    result.address = address;
    result.size = size;
    if (!address || !size || size > 512ull * 1024ull * 1024ull) return false;
    std::vector<uint8_t> buffer(static_cast<size_t>(MIN(size, kVMReadChunk)) + 4096);
    vm_size_t consumed = 0;
    while (consumed < size) {
        vm_size_t request = MIN(kVMReadChunk, size - consumed);
        vm_size_t overlap = consumed + request < size ? MIN(static_cast<vm_size_t>(4096), size - consumed - request) : 0;
        vm_size_t copied = 0;
        kern_return_t status = vm_read_overwrite(mach_task_self(), address + consumed,
                                                  request + overlap,
                                                  reinterpret_cast<vm_address_t>(buffer.data()),
                                                  &copied);
        if (status != KERN_SUCCESS || copied < sizeof(uintptr_t)) return false;
        ScanVMCopy(context, buffer.data(), static_cast<size_t>(copied),
                   static_cast<size_t>(request), address + consumed, result);
        consumed += request;
    }
    return true;
}

struct VMDiscovery {
    VMRegionResult pickupRegion;
    VMRegionResult effectRegion;
    VMRegionResult playerRegion;
    VMRegionResult familiarRegion;
    VMRegionResult slotRegion;
};

static VMDiscovery DiscoverEntityRegions(const ScanContext& context) {
    VMDiscovery discovery;
    vm_address_t address = 0;
    natural_t depth = 0;
    while (true) {
        vm_size_t size = 0;
        vm_region_submap_info_data_64_t info{};
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t status = vm_region_recurse_64(mach_task_self(), &address, &size, &depth,
                                                     reinterpret_cast<vm_region_recurse_info_t>(&info),
                                                     &count);
        if (status != KERN_SUCCESS) break;
        if (info.is_submap) {
            depth++;
            continue;
        }
        vm_address_t next = address + size;
        bool readableHeap = (info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) &&
                            size >= PAGE_SIZE && size <= 512ull * 1024ull * 1024ull;
        if (readableHeap) {
            VMRegionResult candidate;
            if (ScanVMRegion(context, address, size, candidate)) {
                if (candidate.pickupVTableReferences >
                    discovery.pickupRegion.pickupVTableReferences) {
                    discovery.pickupRegion = candidate;
                }
                if (candidate.effectVTableReferences >
                    discovery.effectRegion.effectVTableReferences) {
                    discovery.effectRegion = candidate;
                }
                if ((candidate.playerCount && !discovery.playerRegion.playerCount) ||
                    candidate.playerVTableReferences > discovery.playerRegion.playerVTableReferences) {
                    discovery.playerRegion = candidate;
                }
                if (candidate.familiarVTableReferences >
                    discovery.familiarRegion.familiarVTableReferences) {
                    discovery.familiarRegion = candidate;
                }
                if (candidate.slotVTableReferences > discovery.slotRegion.slotVTableReferences) {
                    discovery.slotRegion = candidate;
                }
            }
        }
        if (next <= address) break;
        address = next;
    }
    return discovery;
}
} // namespace

@interface EIDActiveCollectibleParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableSet<NSNumber *> *identifiers;
@end

@implementation EIDActiveCollectibleParser
- (instancetype)init {
    if ((self = [super init])) _identifiers = [NSMutableSet set];
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
     attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if (![elementName isEqualToString:@"active"]) return;
    NSInteger identifier = attributes[@"id"].integerValue;
    if (identifier > 0 && identifier <= (NSInteger)kMaximumCollectibleID) {
        [self.identifiers addObject:@(identifier)];
    }
}
@end

static NSSet<NSNumber *> *LoadActiveCollectibleIdentifiers(void) {
    NSString *bundle = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *resourceSets = @[
        @"repentance-resources", @"afterbirthplus-resources",
        @"afterbirth-resources", @"rebirth-resources"
    ];
    for (NSString *resourceSet in resourceSets) {
        NSString *path = [bundle stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/items.xml", resourceSet]];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        EIDActiveCollectibleParser *delegate = [EIDActiveCollectibleParser new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = delegate;
        if ([parser parse] && delegate.identifiers.count) return delegate.identifiers.copy;
    }
    return [NSSet set];
}

@implementation EIDPickupIdentity
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    return [self initWithVariant:variant subtype:subtype playerType:-1];
}

- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType {
    return [self initWithVariant:variant subtype:subtype playerType:playerType playerIndex:-1];
}

- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex {
    return [self initWithVariant:variant subtype:subtype playerType:playerType
                     playerIndex:playerIndex rawPillSubtype:0];
}

- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype {
    return [self initWithVariant:variant subtype:subtype playerType:playerType playerIndex:playerIndex
        rawPillSubtype:rawPillSubtype pillModifiers:-1];
}

- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype pillModifiers:(NSInteger)pillModifiers {
    return [self initWithVariant:variant subtype:subtype playerType:playerType playerIndex:playerIndex
        rawPillSubtype:rawPillSubtype pillModifiers:pillModifiers pickupContext:@{}];
}
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype pillModifiers:(NSInteger)pillModifiers
                   pickupContext:(NSDictionary *)pickupContext {
    self = [super init];
    if (self) {
        _variant = variant;
        _subtype = subtype;
        _playerType = playerType;
        _playerIndex = playerIndex;
        _rawPillSubtype = rawPillSubtype;
        _pillModifiers = pillModifiers;
        _pickupContext = [pickupContext copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (![object isKindOfClass:EIDPickupIdentity.class]) return NO;
    EIDPickupIdentity *other = object;
    return self.variant == other.variant && self.subtype == other.subtype &&
        self.playerType == other.playerType && self.playerIndex == other.playerIndex &&
        self.rawPillSubtype == other.rawPillSubtype && self.pillModifiers == other.pillModifiers &&
        [self.pickupContext isEqual:other.pickupContext];
}

- (NSUInteger)hash {
    return ((NSUInteger)self.variant << 16) ^ (NSUInteger)self.subtype;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%ld:%ld", (long)self.variant, (long)self.subtype];
}
@end

@interface EIDNativeProbe ()
@property(nonatomic, copy) NSString *executableUUID;
@property(nonatomic, copy) NSString *status;
@property(nonatomic, getter=isSupportedBuild) BOOL supportedBuild;
@property(atomic, getter=isGameplayActive) BOOL gameplayActive;
@property(atomic, getter=isPauseStateAvailable) BOOL pauseStateAvailable;
@property(atomic, getter=isPaused) BOOL paused;
@property(atomic) uint32_t runSeed;
@property(atomic) NSUInteger runCounter;
@property(atomic) NSInteger primaryPlayerType;
@property(atomic) NSInteger gameDifficulty;
@property(atomic, copy) NSDictionary *descriptionState;
@property(atomic, copy) NSArray<EIDPickupIdentity *> *smeltedTrinketItems;
@property(atomic, getter=isOwnedCollectibleStateAvailable) BOOL ownedCollectibleStateAvailable;
@property(atomic, getter=isInventoryStateAvailable) BOOL inventoryStateAvailable;
@property(atomic, getter=isTransformationStateAvailable) BOOL transformationStateAvailable;
@property(atomic, getter=isSuperBumActive) BOOL superBumActive;
@property(nonatomic, strong) NSArray<EIDPickupIdentity *> *lastPickups;
@property(atomic, copy) NSArray<EIDPickupIdentity *> *inventoryItems;
@property(nonatomic, strong) NSDictionary<NSNumber *, NSNumber *> *ownedCollectibleCounts;
@property(atomic, copy) NSArray<NSNumber *> *nativeTransformationCounters;
@property(nonatomic, copy) NSSet<NSNumber *> *activeCollectibleIDs;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *activeCollectibleHistory;
@property(nonatomic) ScanContext scanContext;
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL wroteDevelopmentProbe;
@property(nonatomic, copy) NSDictionary *lastSpindownLogSnapshot;
@property(nonatomic, copy) NSDictionary *lastRepeatLogSnapshot;
@property(nonatomic, copy) NSDictionary *lastInventoryPreviewLogSnapshot;
@property(nonatomic, copy) NSDictionary *lastOutcomeLogSnapshot;
@property(nonatomic, copy) NSDictionary *lastCollectibleCycleLogSnapshot;
@property(nonatomic) vm_address_t pickupRegionAddress;
@property(nonatomic) vm_size_t pickupRegionSize;
@property(nonatomic) vm_address_t playerRegionAddress;
@property(nonatomic) vm_size_t playerRegionSize;
@property(nonatomic) vm_address_t familiarRegionAddress;
@property(nonatomic) vm_size_t familiarRegionSize;
@property(nonatomic) vm_address_t effectRegionAddress;
@property(nonatomic) vm_size_t effectRegionSize;
@property(nonatomic) NSUInteger playerVectorOffset;
@property(nonatomic) vm_address_t slotRegionAddress;
@property(nonatomic) vm_size_t slotRegionSize;
@property(nonatomic) BOOL loggedVMDiscovery;
@property(nonatomic) BOOL loggedPositionValidation;
@property(nonatomic) BOOL loggedBlindPedestal;
@property(nonatomic) BOOL loggedUnreadableBlindState;
@property(nonatomic) BOOL loggedUnreadableCollectibleCounts;
@property(nonatomic) BOOL loggedUnreadableInventory;
@property(nonatomic) BOOL loggedUnreadableTransformations;
@property(nonatomic) NSInteger lastLoggedRoomType;
@property(nonatomic) uint32_t lastLoggedCurseMask;
@property(nonatomic) NSInteger lastSacrificePayout;
@property(nonatomic) NSInteger lastHiddenCardOrPillCount;
@property(nonatomic) BOOL nativeRunActive;
@property(nonatomic) NSUInteger consecutiveEmptyPlayerScans;
@property(nonatomic) BOOL pillPoolReady;
@property(nonatomic) NSUInteger developmentCaptureIndex;
@property(nonatomic) NSInteger lastPauseState;
// Diagnostics only; accessed exclusively by the main-thread pill resolver.
@property(nonatomic) NSUInteger loggedPillModifierRun;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *loggedPillModifiers;
@end

@implementation EIDNativeProbe
- (instancetype)init {
    self = [super init];
    if (self) {
        _executableUUID = IsaacExecutableUUID();
        NSString *supportedUUID = [NSString stringWithUTF8String:kSupportedUUID];
        _supportedBuild = [_executableUUID caseInsensitiveCompare:supportedUUID] == NSOrderedSame;
        _status = _supportedBuild ? @"Locating native pickup RTTI" : @"Unsupported Isaac executable";
        _lastPickups = @[];
        _inventoryItems = @[];
        _smeltedTrinketItems = @[];
        _descriptionState = @{};
        _ownedCollectibleCounts = @{};
        _nativeTransformationCounters = @[];
        _activeCollectibleIDs = [NSSet set];
        _activeCollectibleHistory = [NSMutableDictionary dictionary];
        _primaryPlayerType = -1;
        _gameDifficulty = -1;
        _playerVectorOffset = NSUIntegerMax;
        _lastLoggedRoomType = NSIntegerMin;
        _lastLoggedCurseMask = UINT32_MAX;
        _lastSacrificePayout = -1;
        _lastHiddenCardOrPillCount = NSIntegerMin;
        _lastPauseState = -1;
    }
    return self;
}

- (void)start {
    if (self.started) return;
    self.started = YES;
    if (!self.supportedBuild) {
        EIDLog(@"native probe disabled for executable UUID %@", self.executableUUID);
        return;
    }
    self.scanContext = LocateEntityVTables();
    if (!self.scanContext.pickupVTableCount) {
        self.status = @"Entity_Pickup RTTI found, but no primary vtable";
        EIDLog(@"%@", self.status);
        return;
    }
    self.status = [NSString stringWithFormat:@"Native probe active (pickup:%lu player:%lu familiar:%lu slot:%lu effect:%lu spikes:%lu)",
                   (unsigned long)self.scanContext.pickupVTableCount,
                   (unsigned long)self.scanContext.playerVTableCount,
                   (unsigned long)self.scanContext.familiarVTableCount,
                   (unsigned long)self.scanContext.slotVTableCount,
                   (unsigned long)self.scanContext.effectVTableCount,
                   (unsigned long)self.scanContext.gridSpikesVTableCount];
    const mach_header_64 *isaacHeader = IsaacExecutableHeader(nullptr);
    NSString *imageMode = isaacHeader && isaacHeader->filetype == MH_DYLIB
        ? @"LiveContainer guest dylib" : @"native executable";
    EIDLog(@"%@; executable UUID %@; image mode %@", self.status,
           self.executableUUID, imageMode);
    EIDLog(@"original EID floor visibility active (shop, Options?, path and pill knowledge)");
    self.activeCollectibleIDs = LoadActiveCollectibleIdentifiers();
    EIDLog(@"native active-item history ready (%lu collectible definitions)",
           (unsigned long)self.activeCollectibleIDs.count);
}

- (void)updateRunStateForAuthoritativePlayers:(const VMRegionResult&)players {
    BOOL active = players.playerCount > 0;
    if (!active) {
        if (self.consecutiveEmptyPlayerScans < kRunEndConfirmationScans) {
            self.consecutiveEmptyPlayerScans += 1;
        }
        if (self.consecutiveEmptyPlayerScans < kRunEndConfirmationScans) return;
        if (self.nativeRunActive) {
            EIDLog(@"native run ended: session %lu seed %08x; per-run knowledge cleared",
                   (unsigned long)self.runCounter, self.runSeed);
        }
        self.nativeRunActive = NO;
        self.runSeed = 0;
        self.lastPickups = @[];
        self.inventoryItems = @[];
        self.descriptionState = @{};
        self.smeltedTrinketItems = @[];
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
        self.inventoryStateAvailable = NO;
        self.nativeTransformationCounters = @[];
        self.transformationStateAvailable = NO;
        self.superBumActive = NO;
        self.pauseStateAvailable = NO;
        self.paused = NO;
        [self.activeCollectibleHistory removeAllObjects];
        self.pillPoolReady = NO;
        return;
    }
    self.consecutiveEmptyPlayerScans = 0;

    uint32_t seed = 0;
    BOOL hasSeed = ReadRunSeed(seed);
    BOOL newRun = !self.nativeRunActive ||
        (hasSeed && self.runSeed != 0 && self.runSeed != seed);
    if (newRun) {
        self.nativeRunActive = YES;
        self.runCounter += 1;
        self.runSeed = hasSeed ? seed : 0;
        self.lastPickups = @[];
        self.inventoryItems = @[];
        self.descriptionState = @{};
        self.smeltedTrinketItems = @[];
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
        self.inventoryStateAvailable = NO;
        self.nativeTransformationCounters = @[];
        self.transformationStateAvailable = NO;
        [self.activeCollectibleHistory removeAllObjects];
        self.loggedUnreadableCollectibleCounts = NO;
        self.loggedUnreadableInventory = NO;
        self.loggedUnreadableTransformations = NO;
        NSUInteger identifiedPills = 0;
        self.pillPoolReady = ValidateNativePillPool(identifiedPills);
        EIDLog(@"native run started: session %lu seed %@; knowledge reset; pill state %@ (%lu known)",
               (unsigned long)self.runCounter,
               hasSeed ? [NSString stringWithFormat:@"%08x", seed] : @"unavailable",
               self.pillPoolReady ? @"ready" : @"initializing",
               (unsigned long)identifiedPills);
    } else if (hasSeed && self.runSeed == 0) {
        self.runSeed = seed;
        EIDLog(@"native run seed resolved: session %lu seed %08x",
               (unsigned long)self.runCounter, seed);
    }

    if (!self.pillPoolReady) {
        NSUInteger identifiedPills = 0;
        if (ValidateNativePillPool(identifiedPills)) {
            self.pillPoolReady = YES;
            EIDLog(@"native pill knowledge ready: session %lu (%lu identified colors)",
                   (unsigned long)self.runCounter, (unsigned long)identifiedPills);
        }
    }
}

- (void)updateOwnedCollectibleCountsForPlayers:(const VMRegionResult&)players {
    std::array<int32_t, kMaximumCollectibleID + 1> totals{};
    for (size_t playerIndex = 0; playerIndex < players.playerCount; ++playerIndex) {
        std::array<int32_t, kMaximumCollectibleID + 1> counts{};
        if (!ReadPlayerCollectibleCounts(players.players[playerIndex].address, counts)) {
            self.ownedCollectibleCounts = @{};
            self.ownedCollectibleStateAvailable = NO;
            if (!self.loggedUnreadableCollectibleCounts) {
                self.loggedUnreadableCollectibleCounts = YES;
                EIDLog(@"native owned-collectible table unreadable; transformation progress suppressed");
            }
            return;
        }
        for (size_t identifier = 1; identifier < counts.size(); ++identifier) {
            totals[identifier] += counts[identifier];
            if (totals[identifier] > 4096) {
                self.ownedCollectibleCounts = @{};
                self.ownedCollectibleStateAvailable = NO;
                return;
            }
        }
    }

    NSMutableDictionary<NSNumber *, NSNumber *> *owned = [NSMutableDictionary dictionary];
    NSInteger total = 0;
    for (size_t identifier = 1; identifier < totals.size(); ++identifier) {
        if (!totals[identifier]) continue;
        owned[@(identifier)] = @(totals[identifier]);
        total += totals[identifier];
    }
    NSDictionary<NSNumber *, NSNumber *> *snapshot = owned.copy;
    BOOL inventoryChanged = ![self.ownedCollectibleCounts isEqualToDictionary:snapshot];
    self.ownedCollectibleCounts = snapshot;
    self.ownedCollectibleStateAvailable = players.playerCount > 0;
    for (NSNumber *identifier in snapshot) {
        if (![self.activeCollectibleIDs containsObject:identifier]) continue;
        NSInteger liveCount = snapshot[identifier].integerValue;
        NSInteger rememberedCount = self.activeCollectibleHistory[identifier].integerValue;
        if (liveCount > rememberedCount) self.activeCollectibleHistory[identifier] = @(liveCount);
    }
    self.loggedUnreadableCollectibleCounts = NO;
    if (self.ownedCollectibleStateAvailable && inventoryChanged) {
        NSArray<NSNumber *> *identifiers = [snapshot.allKeys
            sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray<NSString *> *entries = [NSMutableArray arrayWithCapacity:identifiers.count];
        for (NSNumber *identifier in identifiers) {
            [entries addObject:[NSString stringWithFormat:@"%@x%@",
                                identifier, snapshot[identifier]]];
        }
        EIDLog(@"native owned inventory changed: session %lu, %lu IDs, %ld total [%@]",
               (unsigned long)self.runCounter, (unsigned long)snapshot.count, (long)total,
               [entries componentsJoinedByString:@", "]);
    }
}

- (void)updateNativeTransformationCountersForPlayers:(const VMRegionResult&)players {
    std::array<int32_t, kNativeTransformationCount> maximums{};
    for (size_t playerIndex = 0; playerIndex < players.playerCount; ++playerIndex) {
        std::array<int32_t, kNativeTransformationCount> counters{};
        if (!ReadPlayerTransformationCounters(players.players[playerIndex].address, counters)) {
            self.nativeTransformationCounters = @[];
            self.transformationStateAvailable = NO;
            if (!self.loggedUnreadableTransformations) {
                self.loggedUnreadableTransformations = YES;
                EIDLog(@"native persisted transformation counters unreadable; progress suppressed");
            }
            return;
        }
        // Co-op players own independent form counters. Display the best valid
        // progress rather than summing players into a transformation neither has.
        for (size_t form = 0; form < counters.size(); ++form) {
            maximums[form] = std::max(maximums[form], counters[form]);
        }
    }

    NSMutableArray<NSNumber *> *snapshot =
        [NSMutableArray arrayWithCapacity:kNativeTransformationCount];
    for (int32_t counter : maximums) [snapshot addObject:@(counter)];
    NSArray<NSNumber *> *immutable = snapshot.copy;
    BOOL changed = ![self.nativeTransformationCounters isEqualToArray:immutable];
    self.nativeTransformationCounters = immutable;
    self.transformationStateAvailable = players.playerCount > 0;
    self.loggedUnreadableTransformations = NO;
    if (changed) {
        EIDLog(@"native persisted transformation counters: %@", immutable);
    }
}

- (void)updateInventoryForPlayers:(const VMRegionResult&)players {
    if (!self.ownedCollectibleStateAvailable || !players.playerCount) {
        self.smeltedTrinketItems = @[];
        self.inventoryItems = @[];
        self.inventoryStateAvailable = NO;
        return;
    }

    NSMutableArray<EIDPickupIdentity *> *items = [NSMutableArray array];
    NSMutableArray<EIDPickupIdentity *> *smelted = [NSMutableArray array];
    BOOL smeltedReadable = YES;
    BOOL readable = YES;
    for (size_t playerIndex = 0; playerIndex < players.playerCount; ++playerIndex) {
        vm_address_t playerAddress = players.players[playerIndex].address;
        int32_t type=-1;
        std::array<int32_t,kMaximumCollectibleID+1> counts{};
        std::array<int32_t,4> activeIDs{};
        std::array<int32_t, kPlayerTrinketSlotCount> trinkets{};
        if (!ReadOwnTaskMemory(playerAddress+kPlayerTypeOffset,&type,sizeof(type)) || type<0 || type>40 ||
            !ReadPlayerCollectibleCounts(playerAddress,counts) || !ReadPlayerActiveIDs(playerAddress,activeIDs) ||
            !ReadPlayerTrinkets(playerAddress, trinkets)) {
            readable = NO;
            break;
        }
        NSMutableSet<NSString *> *seen = [NSMutableSet set];
        std::array<int32_t,kMaximumCollectibleID+1> collectibleCopies{};
        for (size_t id=1; id<counts.size(); ++id) {
            const size_t activeSlots = std::count(activeIDs.begin(),activeIDs.end(),(int32_t)id);
            collectibleCopies[id] = EIDInventoryCountPolicy::PhysicalCopies(counts[id],activeSlots);
        }
        void (^addIdentity)(NSInteger,NSInteger) = ^(NSInteger variant,NSInteger subtype) {
            if (subtype<=0) return;
            NSString *key = [NSString stringWithFormat:@"%ld:%ld",(long)variant,(long)subtype];
            if ([seen containsObject:key]) return;
            [seen addObject:key];
            NSMutableDictionary *context = [@{@"inventory_run":@(self.runCounter)} mutableCopy];
            if (variant==EIDPickupVariantCollectible && (size_t)subtype<=kMaximumCollectibleID)
                context[@"inventory_copies"] = @(std::max(1,collectibleCopies[subtype]));
            [items addObject:[[EIDPickupIdentity alloc] initWithVariant:variant subtype:subtype
                playerType:type playerIndex:(NSInteger)playerIndex rawPillSubtype:0 pillModifiers:-1
                pickupContext:context]];
        };
        for (size_t id=1; id<counts.size(); ++id) if (counts[id]) addIdentity(100,(NSInteger)id);
        for (int32_t id : activeIDs) if (id) addIdentity(100,id);
        for (int32_t trinket : trinkets) {
            if ((trinket & 0x7fff) != 0) addIdentity(EIDPickupVariantTrinket, trinket);
        }
        std::vector<int32_t> swallowed;
        if (!ReadSmeltedTrinkets(playerAddress,swallowed)) smeltedReadable = NO;
        for (int32_t trinket : swallowed) {
            [smelted addObject:[[EIDPickupIdentity alloc] initWithVariant:350 subtype:trinket
                playerType:type playerIndex:(NSInteger)playerIndex rawPillSubtype:0 pillModifiers:-1
                pickupContext:@{@"inventory_run":@(self.runCounter)}]];
        }

        std::array<VMPlayerPocketItem, kPlayerPocketItemCount> pockets{};
        if (!ReadPlayerPocketItems(playerAddress, pockets)) {
            readable = NO;
            break;
        }
        for (const VMPlayerPocketItem& pocket : pockets) {
            if (pocket.id <= 0) continue;
            if (pocket.type == 2) {
                addIdentity(EIDPickupVariantCollectible, pocket.id);
            } else if (pocket.type == 1) {
                addIdentity(EIDPickupVariantCard, pocket.id);
            } else if (pocket.type == 0) {
                int32_t variant = EIDPickupVariantPill;
                int32_t subtype = 0;
                if (ResolvePillPresentation(pocket.id, variant, subtype)) {
                    [items addObject:[[EIDPickupIdentity alloc] initWithVariant:variant subtype:subtype
                        playerType:type playerIndex:(NSInteger)playerIndex rawPillSubtype:pocket.id pillModifiers:-1
                        pickupContext:@{@"inventory_run":@(self.runCounter)}]];
                }
            }
        }
    }

    if (!readable) {
        self.smeltedTrinketItems = @[];
        self.inventoryItems = @[];
        self.inventoryStateAvailable = NO;
        if (!self.loggedUnreadableInventory) {
            self.loggedUnreadableInventory = YES;
            EIDLog(@"native player inventory slots unreadable; pause inventory suppressed");
        }
        return;
    }
    NSArray<EIDPickupIdentity *> *snapshot = items.copy;
    BOOL changed = ![self.inventoryItems isEqualToArray:snapshot];
    BOOL swallowedChanged = ![self.smeltedTrinketItems isEqualToArray:smeltedReadable ? smelted : @[]];
    self.inventoryItems = snapshot;
    self.smeltedTrinketItems = smeltedReadable ? smelted.copy : @[];
    self.inventoryStateAvailable = YES;
    self.loggedUnreadableInventory = NO;
    if (changed || swallowedChanged) {
        EIDLog(@"native pause inventory changed: %lu entries %@, %lu smelted trinkets %@",
               (unsigned long)snapshot.count,snapshot,(unsigned long)self.smeltedTrinketItems.count,
               smeltedReadable ? self.smeltedTrinketItems : @"unavailable");
    }
}

- (void)updateDescriptionStateForPlayers:(const VMRegionResult&)players {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    NSDictionary *collection = ReadCollectionSnapshot();
    if (collection) state[@"collection"] = collection;
    NSDictionary *unlocks = ReadUnlockHintState();
    if (unlocks) state[@"unlocks"] = unlocks;
    if (collection && !self.descriptionState[@"collection"])
        EIDLog(@"native collection validated: slot %@, %lu missing entries, progress allowed %@",
            collection[@"slot"],(unsigned long)[collection[@"missing"] count],collection[@"progress_allowed"]);
    vm_address_t game = 0;
    int32_t floor[2] = {};
    // Pandora's native branch uses Game[0] for the reward stage and Game[1]
    // to select Sheol/Cathedral or Dark Room/Chest (0x10058b438/0x100590928).
    if (ReadGameObjectAddress(game) && ReadOwnTaskMemory(game,floor,sizeof(floor)) &&
        floor[0] >= 1 && floor[0] <= 13 && floor[1] >= 0 && floor[1] <= 5) {
        state[@"floor"] = @{@"stage":@(floor[0]), @"alternate":@(floor[1] != 0)};
    }
    int32_t challenge = -1, dimension = -1, roomIndex = -100, roomType = 0;
    if (game && ReadOwnTaskMemory(game+kGameChallengeOffset,&challenge,sizeof(challenge)) && challenge >= 0 && challenge <= 256 &&
        ReadOwnTaskMemory(game+kGameDimensionOffset,&dimension,sizeof(dimension)) && dimension >= 0 && dimension <= 2 &&
        ReadOwnTaskMemory(game+kGameRoomIndexOffset,&roomIndex,sizeof(roomIndex)) && roomIndex >= -15 && roomIndex < 169 &&
        ReadCurrentRoomType(roomType)) {
        state[@"room_type"] = @(roomType);
        state[@"dimension"] = @(dimension);
        state[@"challenge"] = @(challenge);
        state[@"salvage_allowed"] = @(challenge != 43 && dimension != 2 && roomIndex != -12);
        if (roomType != 3 && self.gameDifficulty >= 0 && self.gameDifficulty <= 3) {
            size_t table = self.gameDifficulty >= 2 ? kItemPoolGreedRoomPoolsOffset : kItemPoolRoomPoolsOffset;
            int32_t pool = -1;
            if (ReadOwnTaskMemory(game+kGameItemPoolOffset+table+roomType*sizeof(pool),&pool,sizeof(pool)) && pool >= 0 && pool <= 30)
                state[@"room_pool"] = @(pool);
        }
    }
    NSMutableArray *stats = [NSMutableArray array];
    BOOL needsAbsorption = [self ownedCollectibleCountForID:477] > 0;
    for (EIDPickupIdentity *identity in self.inventoryItems)
        if (identity.variant == 300 && identity.subtype == 41) needsAbsorption = YES;
    BOOL voidStatsEnabled = EIDFeatureEnabled(NSUserDefaults.standardUserDefaults,EIDVoidStatInfoKey);
    NSArray *pedestals = game && needsAbsorption && voidStatsEnabled ? ReadRoomPedestals(game,self.scanContext) : nil;
    unsigned voidCount = 0, runeCount = 0;
    NSMutableSet *options = [NSMutableSet set];
    for (NSDictionary *pedestal in pedestals) {
        NSNumber *option = pedestal[@"options"], *item = pedestal[@"id"];
        if (option.intValue && [options containsObject:option]) continue;
        if (option.intValue) [options addObject:option];
        ++runeCount;
        if (![self.activeCollectibleIDs containsObject:item] || item.intValue == 523) ++voidCount;
    }
    if (pedestals) state[@"room_pedestals"] = pedestals;
    NSArray *superBumOwners = game ? ReadSuperBumOwners(game,self.scanContext,players) : nil;
    for (size_t index = 0; index < players.playerCount; ++index) {
        NSMutableDictionary *player = [ReadDescriptionPlayer(players.players[index].address) mutableCopy];
        if (player) {
            player[@"index"] = @(index);
            if (index<superBumOwners.count) player[@"super_bum_active"] = superBumOwners[index];
            if (pedestals && self.activeCollectibleIDs.count) {
                NSDictionary *voidPrediction = ReadAbsorptionPrediction(players.players[index].address,voidCount,false);
                NSDictionary *runePrediction = ReadAbsorptionPrediction(players.players[index].address,runeCount,true);
                if (voidPrediction) player[@"void_prediction"] = voidPrediction;
                if (runePrediction) player[@"black_rune_prediction"] = runePrediction;
            }
            NSArray *previousPlayers = self.descriptionState[@"players"];
            NSDictionary *previous = index < previousPlayers.count ? previousPlayers[index] : nil;
            for (NSString *key in @[@"purity",@"modeling_clay",@"void_actives",@"trinket_effects",@"golden_bomb"])
                if (player[key] && ![player[key] isEqual:previous[key]])
                    EIDLog(@"native current effect: player %lu %@ %@ (read only)",(unsigned long)index,key,
                        [key isEqualToString:@"void_actives"] ? @([player[key] count]) : player[key]);
            if (player[@"has_passive_belial"] && ![player[@"has_passive_belial"] isEqual:previous[@"has_passive_belial"]])
                EIDLog(@"native passive Belial: player %lu type %@ enabled %@",(unsigned long)index,
                    player[@"type"],player[@"has_passive_belial"]);
            if (player[@"void_prediction"] && !previous[@"void_prediction"])
                EIDLog(@"copied Void RNG validated: player %lu, %u absorbable passives",(unsigned long)index,voidCount);
            if (player[@"black_rune_prediction"] && !previous[@"black_rune_prediction"])
                EIDLog(@"copied Black Rune RNG validated: player %lu, %u absorbable pedestals",(unsigned long)index,runeCount);
            [stats addObject:player.copy];
        }
    }
    state[@"players"] = stats.copy;
    if (![self.descriptionState[@"players"] count] && stats.count)
        EIDLog(@"native description context validated: %lu players; room %@ dimension %@ challenge %@",
            (unsigned long)stats.count,state[@"room_type"],state[@"dimension"],state[@"challenge"]);
    state[@"active_ids"] = self.activeCollectibleIDs.allObjects ?: @[];
    NSDictionary *previousFloor = self.descriptionState[@"floor"];
    if (previousFloor != state[@"floor"] && ![previousFloor isEqual:state[@"floor"]])
        EIDLog(@"native description floor: %@",state[@"floor"] ?: @"unavailable");
    self.descriptionState = state.copy;
}

- (BOOL)overlayPresentationVisible {
    if (!NSThread.isMainThread || !self.supportedBuild) return NO;
    const mach_header_64 *header=IsaacExecutableHeader(nullptr);
    if (!header) return NO;
    uintptr_t base=reinterpret_cast<uintptr_t>(header);
    static uintptr_t validatedBase=0;
    static bool validated=false;
    auto read=[](uintptr_t a,void *p,size_t n){ return ReadOwnTaskMemory(a,p,n); };
    if (validatedBase!=base) {
        validatedBase=base; validated=IsaacPresentation::Validate(base,read);
        EIDLog(@"native transition/cinematic presentation gate %@",validated?@"validated":@"rejected");
    }
    IsaacPresentation::State state;
    static IsaacPresentation::Visibility visibility;
    bool captured=validated && IsaacPresentation::Capture(base,read,state);
    return visibility.Observe(state,captured,true,true,CACurrentMediaTime());
}

- (void)updatePauseStateForGameplay:(BOOL)gameplayActive {
    int32_t state = 0;
    BOOL available = gameplayActive && ReadPauseMenuState(state);
    self.pauseStateAvailable = available;
    self.paused = available && state > 0;
    if (!available) state = -1;
    if (state != self.lastPauseState) {
        self.lastPauseState = state;
        EIDLog(@"native pause state: %@",
               state < 0 ? @"unavailable" : [NSString stringWithFormat:@"%d", state]);
    }
}

- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups {
    if (!self.started || !self.scanContext.pickupVTableCount) {
        self.gameplayActive = NO;
        return @[];
    }

    VMRegionResult pickupResult;
    VMRegionResult playerResult;
    VMRegionResult familiarResult;
    VMRegionResult slotResult;
    VMRegionResult effectResult;
    VMRegionResult gridSpikesResult;
    bool pickupRegionValid = self.pickupRegionAddress &&
        ScanVMRegion(self.scanContext, self.pickupRegionAddress, self.pickupRegionSize, pickupResult) &&
        pickupResult.pickupVTableReferences;
    bool playerRegionValid = self.playerRegionAddress &&
        ScanVMRegion(self.scanContext, self.playerRegionAddress, self.playerRegionSize, playerResult) &&
        playerResult.playerVTableReferences;
    bool familiarRegionValid = self.familiarRegionAddress &&
        ScanVMRegion(self.scanContext, self.familiarRegionAddress,
                     self.familiarRegionSize, familiarResult) &&
        familiarResult.familiarVTableReferences;
    bool slotRegionValid = self.slotRegionAddress &&
        ScanVMRegion(self.scanContext, self.slotRegionAddress, self.slotRegionSize, slotResult) &&
        slotResult.slotVTableReferences;
    bool effectRegionValid = self.effectRegionAddress &&
        ScanVMRegion(self.scanContext, self.effectRegionAddress, self.effectRegionSize, effectResult) &&
        effectResult.effectVTableReferences;
    bool gridSpikesResolved = ResolveSacrificeRoomSpikes(
        self.scanContext, gridSpikesResult);
    int32_t currentRoomType = 0;
    bool currentRoomTypeAvailable = ReadCurrentRoomType(currentRoomType);
    bool sacrificeRoomActive = currentRoomTypeAvailable &&
        currentRoomType == kSacrificeRoomType;
    if (currentRoomTypeAvailable && self.lastLoggedRoomType != currentRoomType) {
        self.lastLoggedRoomType = currentRoomType;
        EIDLog(@"native room type changed: %d%@", currentRoomType,
               sacrificeRoomActive ? @" (sacrifice)" : @"");
    }
    if (sacrificeRoomActive && gridSpikesResolved && gridSpikesResult.pickupCount &&
        self.lastSacrificePayout != gridSpikesResult.pickups[0].subtype) {
        const VMPickup& spike = gridSpikesResult.pickups[0];
        self.lastSacrificePayout = spike.subtype;
        EIDLog(@"native sacrifice payout %d/12 at (%.1f,%.1f)",
               spike.subtype, spike.x, spike.y);
    } else if (!sacrificeRoomActive) {
        self.lastSacrificePayout = -1;
    }

    // The main menu keeps an inactive Entity_Player allocation in a heap region.
    // A run may allocate the real player in a different region, so a region cache
    // alone can remain stuck in menu state. Resolve PlayerManager's pointer vector
    // from the verified Game object instead; once located, its empty/non-empty state
    // tracks menu/run transitions without repeated whole-process heap discovery.
    VMRegionResult managedPlayers;
    bool playerVectorResolved = ResolvePlayersFromGame(
        self.scanContext, _playerVectorOffset, managedPlayers);
    if (playerVectorResolved) {
        playerResult = managedPlayers;
        playerRegionValid = true;
        [self updateRunStateForAuthoritativePlayers:managedPlayers];
    }

    if (!pickupRegionValid || !effectRegionValid ||
        (pickupResult.pickupCount && !playerRegionValid) ||
        (self.slotRegionAddress && !slotRegionValid) ||
        (self.familiarRegionAddress && !familiarRegionValid)) {
        VMDiscovery discovery = DiscoverEntityRegions(self.scanContext);
        if (discovery.pickupRegion.pickupVTableReferences) {
            pickupResult = discovery.pickupRegion;
            if (pickupResult.firstPickupVTableAddress &&
                pickupResult.lastPickupVTableAddress >= pickupResult.firstPickupVTableAddress) {
                self.pickupRegionAddress = pickupResult.firstPickupVTableAddress;
                self.pickupRegionSize = pickupResult.lastPickupVTableAddress -
                    pickupResult.firstPickupVTableAddress + 0x1000;
            } else {
                self.pickupRegionAddress = pickupResult.address;
                self.pickupRegionSize = pickupResult.size;
            }
            pickupRegionValid = true;
        }
        if (discovery.effectRegion.effectVTableReferences) {
            effectResult = discovery.effectRegion;
            if (effectResult.firstEffectVTableAddress &&
                effectResult.lastEffectVTableAddress >= effectResult.firstEffectVTableAddress) {
                self.effectRegionAddress = effectResult.firstEffectVTableAddress;
                self.effectRegionSize = effectResult.lastEffectVTableAddress -
                    effectResult.firstEffectVTableAddress + 0x1000;
            } else {
                self.effectRegionAddress = effectResult.address;
                self.effectRegionSize = effectResult.size;
            }
            effectRegionValid = true;
        }
        if (discovery.playerRegion.playerVTableReferences) {
            playerResult = discovery.playerRegion;
            vm_address_t firstPlayerAddress = playerResult.playerCount
                ? playerResult.players[0].address : 0;
            self.playerRegionAddress = firstPlayerAddress ?: playerResult.address;
            self.playerRegionSize = firstPlayerAddress ? 0x3000 : playerResult.size;
            playerRegionValid = true;
        }
        if (discovery.familiarRegion.familiarVTableReferences) {
            familiarResult = discovery.familiarRegion;
            if (familiarResult.firstFamiliarVTableAddress &&
                familiarResult.lastFamiliarVTableAddress >=
                    familiarResult.firstFamiliarVTableAddress) {
                self.familiarRegionAddress = familiarResult.firstFamiliarVTableAddress;
                self.familiarRegionSize = familiarResult.lastFamiliarVTableAddress -
                    familiarResult.firstFamiliarVTableAddress + 0x1000;
            } else {
                self.familiarRegionAddress = familiarResult.address;
                self.familiarRegionSize = familiarResult.size;
            }
            familiarRegionValid = true;
        }
        if (discovery.slotRegion.slotVTableReferences) {
            slotResult = discovery.slotRegion;
            if (slotResult.firstSlotVTableAddress &&
                slotResult.lastSlotVTableAddress >= slotResult.firstSlotVTableAddress) {
                self.slotRegionAddress = slotResult.firstSlotVTableAddress;
                self.slotRegionSize = slotResult.lastSlotVTableAddress -
                    slotResult.firstSlotVTableAddress + 0x1000;
            } else {
                self.slotRegionAddress = slotResult.address;
                self.slotRegionSize = slotResult.size;
            }
            slotRegionValid = true;
        }
        if (!self.loggedVMDiscovery && pickupRegionValid) {
            self.loggedVMDiscovery = YES;
            EIDLog(@"safe VM entity discovery: pickup refs %lu, player refs %lu, familiar refs %lu, slot refs %lu, effect refs %lu, spikes refs %lu, "
                   "cache %.1f MiB",
                   (unsigned long)pickupResult.pickupVTableReferences,
                   (unsigned long)playerResult.playerVTableReferences,
                   (unsigned long)familiarResult.familiarVTableReferences,
                   (unsigned long)slotResult.slotVTableReferences,
                   (unsigned long)effectResult.effectVTableReferences,
                   (unsigned long)gridSpikesResult.gridSpikesVTableReferences,
                   (double)self.pickupRegionSize / (1024.0 * 1024.0));
        }
    }
    self.gameplayActive = playerVectorResolved
        ? managedPlayers.playerCount > 0
        : playerRegionValid && playerResult.playerCount > 0;
    NSInteger playerType = -1;
    NSInteger difficulty = -1;
    if (self.gameplayActive && playerResult.playerCount) {
        int32_t nativeType = -1;
        int32_t nativeDifficulty = -1;
        vm_address_t game = 0;
        if (ReadOwnTaskMemory(playerResult.players[0].address + kPlayerTypeOffset,
                              &nativeType, sizeof(nativeType)) &&
            nativeType >= 0 && nativeType <= 40) playerType = nativeType;
        if (ReadGameObjectAddress(game) &&
            ReadOwnTaskMemory(game + kGameDifficultyOffset, &nativeDifficulty,
                              sizeof(nativeDifficulty)) &&
            nativeDifficulty >= 0 && nativeDifficulty <= 3) difficulty = nativeDifficulty;
    }
    if (self.primaryPlayerType != playerType || self.gameDifficulty != difficulty) {
        EIDLog(@"description context: player %ld difficulty %ld", (long)playerType, (long)difficulty);
    }
    self.primaryPlayerType = playerType;
    self.gameDifficulty = difficulty;
    if (self.gameplayActive && playerResult.playerCount) {
        [self updateOwnedCollectibleCountsForPlayers:playerResult];
        [self updateNativeTransformationCountersForPlayers:playerResult];
        [self updateInventoryForPlayers:playerResult];
        [self updateDescriptionStateForPlayers:playerResult];
        self.superBumActive = familiarRegionValid && familiarResult.superBumActive;
    } else if (playerVectorResolved) {
        self.descriptionState = @{};
        self.smeltedTrinketItems = @[];
        self.inventoryItems = @[];
        self.inventoryStateAvailable = NO;
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
        self.nativeTransformationCounters = @[];
        self.transformationStateAvailable = NO;
        self.superBumActive = NO;
    }
    [self updatePauseStateForGameplay:self.gameplayActive];

    if (!pickupRegionValid) {
        if (!self.gameplayActive) self.lastPickups = @[];
        return self.gameplayActive ? self.lastPickups : @[];
    }

    uint32_t curseMask = 0;
    bool curseMaskAvailable = ReadCurrentCurseMask(curseMask);
    if (curseMaskAvailable && self.lastLoggedCurseMask != curseMask) {
        self.lastLoggedCurseMask = curseMask;
        EIDLog(@"native level curse mask changed: 0x%02x%@", curseMask,
               curseMask & kCurseOfTheBlind ? @" (Curse of the Blind)" : @"");
    }
    // ScanVMCopy already checks each pedestal's ForceBlind and actual artwork.
    // A level-wide curse must not hide a revealed/dropped active item again.

    // Original EID does not use Pickup.Touched as general card knowledge. Apply
    // its default shop, Options?, Soul Stone and reachability rules instead.
    const size_t hiddenCardOrPillCount =
        SuppressHiddenCardAndPillIdentities(pickupResult, playerResult);
    if (self.lastHiddenCardOrPillCount != (NSInteger)hiddenCardOrPillCount) {
        self.lastHiddenCardOrPillCount = (NSInteger)hiddenCardOrPillCount;
        EIDLog(@"original EID visibility suppressed %lu card/pill identit%@",
               (unsigned long)hiddenCardOrPillCount,
               hiddenCardOrPillCount == 1 ? @"y" : @"ies");
    }

    if (pickupResult.blindPickupCount && !self.loggedBlindPedestal) {
        self.loggedBlindPedestal = YES;
        EIDLog(@"hidden collectible pedestal detected; identity suppressed");
    }
    if (pickupResult.unreadableBlindStateCount && !self.loggedUnreadableBlindState) {
        self.loggedUnreadableBlindState = YES;
        EIDLog(@"collectible blind state unreadable; description suppressed for safety");
    }

#if EID_DEVELOPMENT_LAYOUT_CAPTURE
    if (pickupResult.pickupCount && self.developmentCaptureIndex < 12) {
        NSUInteger capture = self.developmentCaptureIndex++;
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:
                               @"Library/Application Support/IsaacExternalItemDescriptions/layout-capture"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        if (pickupResult.pickupSnapshotSize) {
            NSData *data = [NSData dataWithBytes:pickupResult.pickupSnapshot.data()
                                          length:pickupResult.pickupSnapshotSize];
            [data writeToFile:[directory stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"pickup-%02lu.bin", (unsigned long)capture]] atomically:YES];
        }
        if (playerResult.playerSnapshotSize) {
            NSData *data = [NSData dataWithBytes:playerResult.playerSnapshot.data()
                                          length:playerResult.playerSnapshotSize];
            [data writeToFile:[directory stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"player-%02lu.bin", (unsigned long)capture]] atomically:YES];
        }
    }
#endif

    if (!self.loggedPositionValidation && pickupResult.pickupCount) {
        self.loggedPositionValidation = YES;
        const VMPickup& first = pickupResult.pickups[0];
        EIDLog(@"entity offsets validated: pickup %d:%d at (%.1f,%.1f) player(%@%.1f,%.1f)",
               first.variant, first.subtype, first.x, first.y,
               playerResult.playerCount ? @"" : @"unavailable ",
               playerResult.playerCount ? playerResult.players[0].x : 0,
               playerResult.playerCount ? playerResult.players[0].y : 0);
    }

    NSMutableArray<EIDPickupIdentity *> *pickups = [NSMutableArray array];
    if (playerResult.playerCount &&
        (pickupResult.pickupCount || slotResult.pickupCount || effectResult.pickupCount ||
         gridSpikesResult.pickupCount)) {
        const VMPickup *closest = nullptr;
        vm_address_t closestPlayer = 0;
        NSInteger closestPlayerIndex = -1;
        float closestDistance = INFINITY;
        const VMRegionResult *sources[] = {
            &pickupResult, &slotResult, &effectResult, &gridSpikesResult
        };
        for (const VMRegionResult *source : sources) {
            for (size_t index = 0; index < source->pickupCount; ++index) {
                const VMPickup& pickup = source->pickups[index];
                if (!pickup.hasPosition) continue;
                for (size_t playerIndex = 0; playerIndex < playerResult.playerCount; ++playerIndex) {
                    const VMPlayer& player = playerResult.players[playerIndex];
                    float dx = pickup.x - player.x;
                    float dy = pickup.y - player.y;
                    float distance = dx * dx + dy * dy;
                    if (distance < closestDistance) {
                        closestDistance = distance;
                        closest = &pickup;
                        closestPlayer = player.address;
                        closestPlayerIndex = (NSInteger)playerIndex;
                    }
                }
            }
        }
        if (closest && closestDistance <= kMaximumDescriptionDistance * kMaximumDescriptionDistance) {
            int32_t contextType = -1;
            if (!ReadOwnTaskMemory(closestPlayer + kPlayerTypeOffset, &contextType,
                                   sizeof(contextType)) || contextType < 0 || contextType > 40) {
                contextType = -1;
            }
            vm_address_t nativeRoom = 0;
            ReadCurrentRoomAddress(nativeRoom);
            [pickups addObject:[[EIDPickupIdentity alloc] initWithVariant:closest->variant
                                                                  subtype:closest->subtype
                                                               playerType:contextType playerIndex:closestPlayerIndex
                                                           rawPillSubtype:closest->rawPillSubtype pillModifiers:-1
                                                            pickupContext:@{@"pedestal":@(closest->variant == 100),
                                                                @"shop":@(closest->isShopItem),@"options":@(closest->optionsPickupIndex),
                                                                @"flip_id":@(closest->flipID),
                                                                @"native_address":@(closest->address),
                                                                @"native_seed":@(closest->cycleSeed),@"native_run":@(self.runCounter),
                                                                @"native_room":@(nativeRoom),
                                                                @"outcome_seed":@(closest->outcomeSeed)}]];
        }
    }
    if (!pickups.count && !playerResult.playerCount) {
        for (size_t index = 0; index < pickupResult.pickupCount; ++index) {
            const VMPickup& pickup = pickupResult.pickups[index];
            [pickups addObject:[[EIDPickupIdentity alloc] initWithVariant:pickup.variant
                                                                  subtype:pickup.subtype]];
        }
        for (size_t index = 0; index < slotResult.pickupCount; ++index) {
            const VMPickup& pickup = slotResult.pickups[index];
            [pickups addObject:[[EIDPickupIdentity alloc] initWithVariant:pickup.variant
                                                                  subtype:pickup.subtype]];
        }
    }
    self.lastPickups = pickups;
    return pickups;
}

- (NSArray<NSNumber *> *)currentCollectibleIDs {
    NSMutableArray<NSNumber *> *identifiers = [NSMutableArray array];
    for (EIDPickupIdentity *pickup in [self currentDescribablePickups]) {
        if (pickup.variant == EIDPickupVariantCollectible) [identifiers addObject:@(pickup.subtype)];
    }
    return identifiers;
}

- (NSArray<EIDPickupIdentity *> *)currentInventoryItems {
    if (!self.inventoryStateAvailable) return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (EIDPickupIdentity *item in self.inventoryItems) [items addObject:[self resolvedPillIdentity:item]];
    return items.copy;
}

- (EIDPickupIdentity *)resolvedSpindownIdentity:(EIDPickupIdentity *)identity {
    if (identity.variant != EIDPickupVariantCollectible) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    context[@"spindown"] = @{@"validated":@NO};
    auto finish = [&]() -> EIDPickupIdentity * {
        return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
            playerType:identity.playerType playerIndex:identity.playerIndex
            rawPillSubtype:identity.rawPillSubtype pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!self.supportedBuild || !NSThread.isMainThread) return finish();
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    vm_address_t game = 0;
    VMRegionResult players;
    if (!header || !ReadGameObjectAddress(game) || !self.playerVectorOffset ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players) ||
        identity.playerIndex < 0 || (size_t)identity.playerIndex >= players.playerCount) return finish();
    uintptr_t image = reinterpret_cast<uintptr_t>(header);
    uintptr_t player = players.players[(size_t)identity.playerIndex].address;
    using HasCollectible = bool (*)(uintptr_t,uint32_t,bool);
    HasCollectible has = reinterpret_cast<HasCollectible>(image+kPlayerHasCollectibleOffset);
    BOOL absorbed = NO;
    if (!has(player,723,false) && has(player,477,false))
        absorbed = [ReadVoidedActives(player) containsObject:@723];
    if (!has(player,723,false) && !absorbed) { context[@"spindown"] = @{@"owned":@NO}; return finish(); }
    BOOL battery = has(player,356,false);
    uint32_t availablePrologue = 0, unlockedPrologue = 0;
    uintptr_t manager = 0;
    if (!ReadOwnTaskMemory(image+kItemConfigIsAvailableOffset,&availablePrologue,sizeof(availablePrologue)) ||
        availablePrologue != 0xd10143ff ||
        !ReadOwnTaskMemory(image+kPersistentIsAchievementUnlockedOffset,&unlockedPrologue,sizeof(unlockedPrologue)) ||
        unlockedPrologue != 0x3100083f ||
        !ReadOwnTaskMemory(image+kManagerGlobalOffset,&manager,sizeof(manager)) || !manager ||
        !ReadCollectionSnapshot()) return finish(); // Validate the selected Repentance slot, not its collection flags.
    RemotePointerVector vector;
    if (!ReadOwnTaskMemory(manager+kManagerCollectibleConfigsOffset,&vector,sizeof(vector)) ||
        !vector.begin || vector.end < vector.begin || vector.capacity < vector.end ||
        (vector.end-vector.begin)%sizeof(uintptr_t) || (vector.capacity-vector.begin)%sizeof(uintptr_t) ||
        (vector.capacity-vector.begin)/sizeof(uintptr_t) > 4096 ||
        (vector.end-vector.begin)/sizeof(uintptr_t) != kMaximumCollectibleID+1) return finish();
    std::array<uintptr_t,kMaximumCollectibleID+1> configs{};
    if (!ReadOwnTaskMemory(vector.begin,configs.data(),sizeof(configs))) return finish();
    using IsAvailable = bool (*)(uintptr_t,uint32_t);
    using IsUnlocked = bool (*)(uintptr_t,int32_t);
    IsAvailable available = reinterpret_cast<IsAvailable>(image+kItemConfigIsAvailableOffset);
    IsUnlocked unlocked = reinterpret_cast<IsUnlocked>(image+kPersistentIsAchievementUnlockedOffset);
    std::vector<EIDSpindownPolicy::Step> steps;
    using EIDSpindownPolicy::Availability;
    bool valid = EIDSpindownPolicy::Build((int32_t)identity.subtype,battery,[&](int32_t id) {
        uintptr_t config = configs[(size_t)id];
        if (!config) return Availability::Missing;
        int32_t nativeID = -1, achievement = -3;
        uint8_t hidden = 0xff;
        if (!ReadOwnTaskMemory(config+4,&nativeID,sizeof(nativeID)) || nativeID != id ||
            !ReadOwnTaskMemory(config+0xb7,&hidden,sizeof(hidden)) || hidden > 1 ||
            !ReadOwnTaskMemory(config+0x50,&achievement,sizeof(achievement)) || achievement < -2 || achievement > 637)
            return Availability::Unknown;
        if (hidden) return Availability::Hidden;
        // Native Spindown calls IsAvailable(config, 3) at 0x100585474.
        // Flags 1|2 apply run restrictions + achievement unlocks. Callback bit
        // 8 is deliberately absent; this does not reroll, consume RNG or write saves.
        if (available(config,3)) return Availability::Available;
        return unlocked(manager+kManagerPersistentDataOffset,achievement) ? Availability::Restricted : Availability::Locked;
    },steps);
    if (!valid) return finish();
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger lockedCount = 0, restrictedCount = 0;
    for (const auto& step : steps) {
        NSMutableArray *excluded = [NSMutableArray array];
        for (const auto& item : step.excluded) {
            BOOL locked = item.reason == Availability::Locked;
            lockedCount += locked; restrictedCount += !locked;
            [excluded addObject:@{@"id":@(item.id),@"locked":@(locked)}];
        }
        [rows addObject:@{@"result":@(step.result),@"excluded":excluded.copy}];
    }
    NSDictionary *snapshot = @{@"owned":@YES,@"validated":@YES,@"battery":@(battery),@"steps":rows.copy};
    context[@"spindown"] = snapshot;
    NSDictionary *logSnapshot = @{@"run":@(self.runCounter),@"item":@(identity.subtype),@"snapshot":snapshot};
    if (![logSnapshot isEqual:self.lastSpindownLogSnapshot]) {
        self.lastSpindownLogSnapshot = logSnapshot;
        EIDLog(@"native Spindown verified: item %ld, %lu locked and %lu run-restricted candidates skipped",
            (long)identity.subtype,(unsigned long)lockedCount,(unsigned long)restrictedCount);
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedGlyphIdentity:(EIDPickupIdentity *)identity insideInventory:(BOOL)insideInventory {
    if (identity.variant!=100 || identity.subtype!=464 || !insideInventory) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    context[@"glyph_balance"] = @{@"validated":@NO};
    if (self.supportedBuild && NSThread.isMainThread) {
        const mach_header_64 *header = IsaacExecutableHeader(nullptr);
        uintptr_t game=0; VMRegionResult players;
        uint32_t prologue=0;
        if (header && self.playerVectorOffset && ReadGameObjectAddress(game) &&
            ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players) &&
            identity.playerIndex>=0 && (size_t)identity.playerIndex<players.playerCount &&
            ReadOwnTaskMemory((uintptr_t)header+kPlayerGlyphOfBalanceOffset,&prologue,4) && prologue==0xd10183ff) {
            uintptr_t player=players.players[(size_t)identity.playerIndex].address;
            std::array<int32_t,kMaximumCollectibleID+1> counts{};
            if (ReadPlayerCollectibleCounts(player,counts) && counts[464]>0) {
                // The verified routine reads health/consumables and room entities.
                // Its only writes are to these two private stack output values;
                // no RNG, reward creation or native player mutation is called.
                int32_t variant=0, subtype=0;
                using GlyphPriority = void (*)(uintptr_t,int32_t *,int32_t *);
                reinterpret_cast<GlyphPriority>((uintptr_t)header+kPlayerGlyphOfBalanceOffset)(player,&variant,&subtype);
                if (variant==0 || variant==10 || variant==20 || variant==30 || variant==40 || variant==42 || variant==350)
                    if (subtype>=0 && subtype<=6) context[@"glyph_balance"] =
                        @{@"validated":@YES,@"variant":@(variant),@"subtype":@(subtype)};
            }
        }
    }
    return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
        playerType:identity.playerType playerIndex:identity.playerIndex rawPillSubtype:identity.rawPillSubtype
        pillModifiers:identity.pillModifiers pickupContext:context];
}

- (EIDPickupIdentity *)resolvedLivePedestalIdentity:(EIDPickupIdentity *)identity {
    if (identity.variant != 100 || ![identity.pickupContext[@"pedestal"] boolValue]) return identity;
    NSDictionary *previous = identity.pickupContext;
    if (!self.supportedBuild || !NSThread.isMainThread || !self.gameplayActive ||
        [previous[@"native_run"] unsignedIntegerValue] != self.runCounter) return nil;
    uintptr_t address = [previous[@"native_address"] unsignedLongLongValue];
    uint32_t seed = [previous[@"native_seed"] unsignedIntValue];
    vm_address_t room = 0;
    if (!address || !seed || !ReadCurrentRoomAddress(room) ||
        room != [previous[@"native_room"] unsignedLongLongValue]) return nil;
    // Read only the one selected object, not a heap region or player inventory.
    // Morph updates its ID, artwork and cycle queue on Isaac's main thread.
    std::array<uint8_t,0x618> bytes{};
    if (!ReadOwnTaskMemory(address,bytes.data(),bytes.size())) return nil;
    uintptr_t vtable = 0, alternate = 0;
    int32_t native[3]{}, count = 0;
    uint32_t currentSeed = 0, outcomeSeed = 0;
    memcpy(&vtable,bytes.data(),sizeof(vtable));
    memcpy(native,bytes.data()+kEntityTypeOffset,sizeof(native));
    memcpy(&currentSeed,bytes.data()+kPickupCycleSeedOffset,sizeof(currentSeed));
    const uint8_t *active = bytes.data()+kEntityStateOffset;
    if (!IsCandidateVTable(self.scanContext.pickupVTables,self.scanContext.pickupVTableCount,vtable) ||
        native[0] != 5 || native[1] != 100 || currentSeed != seed ||
        !active[0] || !active[2] || active[3] ||
        PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible) return nil;
    memcpy(&count,bytes.data()+kPickupCollectibleCycleCountOffset,sizeof(count));
    EIDPickupMetadataPolicy::Metadata metadata;
    if (!ReadPickupMetadata(bytes.data(),bytes.size(),metadata)) return nil;
    memcpy(&outcomeSeed,bytes.data()+kPickupCurrentRNGOffset,sizeof(outcomeSeed));
    memcpy(&alternate,bytes.data()+0x610,sizeof(alternate));
    int32_t flip = 0, saved[3]{}; uint8_t hidden = 1;
    if (alternate && ReadOwnTaskMemory(alternate,saved,sizeof(saved)) && saved[0] == 5 && saved[1] == 100 &&
        saved[2] >= 1 && saved[2] <= 732 && ReadOwnTaskMemory(alternate+0x23,&hidden,sizeof(hidden)) && !hidden)
        flip = saved[2];
    int32_t displayID = EIDLivePedestalSubtype(native[2],flip);
    if (!displayID) return nil;
    NSMutableDictionary *context = previous.mutableCopy;
    context[@"live_cycle_count"] = @(count >= 0 && count <= 8 ? count : 0);
    context[@"shop"] = @(metadata.IsShopItem());
    context[@"options"] = @(metadata.optionsIndex);
    context[@"flip_id"] = @(native[2] ? flip : 0);
    context[@"outcome_seed"] = @(outcomeSeed);
    if (displayID != identity.subtype) {
        // Derived predictions belong to the former ID, not the next food/item.
        for (NSString *key in @[@"spindown",@"collectible_cycle",@"crown_overview",@"crown_selection",@"eternal_d6"])
            [context removeObjectForKey:key];
    }
    return [[EIDPickupIdentity alloc] initWithVariant:100 subtype:displayID
        playerType:identity.playerType playerIndex:identity.playerIndex rawPillSubtype:0
        pillModifiers:identity.pillModifiers pickupContext:context];
}

- (EIDPickupIdentity *)resolvedCollectibleCycleIdentity:(EIDPickupIdentity *)identity {
    if (identity.variant != 100 || ![identity.pickupContext[@"pedestal"] boolValue]) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    [context removeObjectForKey:@"collectible_cycle"];
    [context removeObjectForKey:@"collectible_hidden"];
    auto finish = [&]() -> EIDPickupIdentity * {
        return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
            playerType:identity.playerType playerIndex:identity.playerIndex
            rawPillSubtype:identity.rawPillSubtype pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!self.supportedBuild || !NSThread.isMainThread || !self.gameplayActive ||
        [context[@"native_run"] unsignedIntegerValue] != self.runCounter) return finish();
    uintptr_t address = [context[@"native_address"] unsignedLongLongValue];
    uint32_t seed = [context[@"native_seed"] unsignedIntValue];
    if (!address || !seed) return finish();
    std::array<uint8_t,kPickupCollectibleCycleCountOffset+sizeof(int32_t)> bytes{};
    if (!ReadOwnTaskMemory(address,bytes.data(),bytes.size())) return finish();
    uintptr_t vtable = 0;
    int32_t native[3]{}, count = 0;
    uint32_t currentSeed = 0;
    memcpy(&vtable,bytes.data(),sizeof(vtable));
    memcpy(native,bytes.data()+kEntityTypeOffset,sizeof(native));
    memcpy(&currentSeed,bytes.data()+kPickupCycleSeedOffset,sizeof(currentSeed));
    const uint8_t *active = bytes.data()+kEntityStateOffset;
    if (!IsCandidateVTable(self.scanContext.pickupVTables,self.scanContext.pickupVTableCount,vtable) ||
        native[0] != 5 || native[1] != 100 || currentSeed != seed ||
        !active[0] || !active[2] || active[3]) return finish();
    if (PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible) {
        context[@"collectible_hidden"] = @YES;
        return finish();
    }
    std::array<int32_t,EIDCollectibleCyclePolicy::MaximumAlternates> queue{};
    memcpy(queue.data(),bytes.data()+kPickupCollectibleCycleOffset,sizeof(queue));
    memcpy(&count,bytes.data()+kPickupCollectibleCycleCountOffset,sizeof(count));
    std::vector<int32_t> items;
    if (!EIDCollectibleCyclePolicy::Normalize(native[2],queue,count,items)) return finish();
    vm_address_t game = 0;
    int32_t floor = -1, room = -999, dimension = -1;
    if (!ReadGameObjectAddress(game) || !ReadOwnTaskMemory(game,&floor,sizeof(floor)) || floor < 1 || floor > 13 ||
        !ReadOwnTaskMemory(game+kGameRoomIndexOffset,&room,sizeof(room)) || room < -15 || room >= 169 ||
        !ReadOwnTaskMemory(game+kGameDimensionOffset,&dimension,sizeof(dimension)) || dimension < 0 || dimension > 2) return finish();
    NSString *scope = [NSString stringWithFormat:@"%lu:%08x:%d:%d:%d",(unsigned long)self.runCounter,self.runSeed,floor,room,dimension];
    NSString *key = [scope stringByAppendingFormat:@":%llx:%08x",(unsigned long long)address,seed];
    NSMutableArray *identifiers = [NSMutableArray array];
    for (int32_t id : items) [identifiers addObject:@(id)];
    NSDictionary *cycle = @{@"key":key,@"scope":scope,@"items":identifiers.copy};
    context[@"collectible_cycle"] = cycle;
    if (![cycle isEqual:self.lastCollectibleCycleLogSnapshot]) {
        self.lastCollectibleCycleLogSnapshot = cycle;
        EIDLog(@"native collectible cycle: %lu unique items %@",(unsigned long)identifiers.count,identifiers);
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedOutcomeIdentity:(EIDPickupIdentity *)identity
                             insideInventory:(BOOL)insideInventory enabled:(BOOL)enabled {
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    [context removeObjectForKey:@"crooked_penny"];
    [context removeObjectForKey:@"eternal_d6"];
    auto finish = [&]() -> EIDPickupIdentity * {
        NSDictionary *outcome = context[@"crooked_penny"] ?: context[@"eternal_d6"];
        if (outcome) {
            NSDictionary *snapshot = @{@"run":@(self.runCounter),@"item":@(identity.subtype),
                @"player":@(identity.playerIndex),@"outcome":outcome};
            if (![snapshot isEqual:self.lastOutcomeLogSnapshot]) {
                self.lastOutcomeLogSnapshot = snapshot;
                EIDLog(@"native %@ prediction (copied state only): %@",
                    context[@"crooked_penny"] ? @"Crooked Penny" : @"Eternal D6",outcome);
            }
        }
        return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
            playerType:identity.playerType playerIndex:identity.playerIndex
            rawPillSubtype:identity.rawPillSubtype pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!enabled || identity.variant != 100 || !self.supportedBuild || !NSThread.isMainThread ||
        !self.gameplayActive || [context[@"crafting_result"] boolValue]) return finish();
    BOOL penny = insideInventory && identity.subtype == 485;
    BOOL pedestal = !insideInventory && [context[@"pedestal"] boolValue];
    if (!penny && !pedestal) return finish();
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    vm_address_t game = 0;
    VMRegionResult players;
    if (!header || !ReadGameObjectAddress(game) || self.playerVectorOffset == NSUIntegerMax ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players)) return finish();
    size_t index = identity.playerIndex >= 0 ? (size_t)identity.playerIndex : 0;
    if (index >= players.playerCount) return finish();
    uintptr_t image = reinterpret_cast<uintptr_t>(header), player = players.players[index].address;
    // Validate the exact read-only getter and native outcome branches. Never
    // call UseActiveItem, RandomInt/Float, RNG::Next, reroll or item-pool draws.
    for (const auto& check : std::array<std::array<uint32_t,2>,7>{{
        {{0x4eeb74,0xd10183ff}},{{0x582340,0xb943db41}},{{0x582348,0x52800582}},
        {{0x582368,0x54000329}},{{0x586290,0x5283ca09}},{{0x5862b4,0xb9406508}},
        {{0x5862c8,0x52800082}}}}) {
        uint32_t opcode = 0;
        if (!ReadOwnTaskMemory(image+check[0],&opcode,sizeof(opcode)) || opcode != check[1]) return finish();
    }
    using HasCollectible = bool (*)(uintptr_t,uint32_t,bool);
    HasCollectible has = reinterpret_cast<HasCollectible>(image+kPlayerHasCollectibleOffset);
    BOOL battery = has(player,356,false);
    if (penny) {
        EIDPredictionPolicy::RNG rng{};
        uint32_t decoration = 0;
        if (!has(player,485,false) || !ReadCollectibleRNG(player,485,rng) ||
            !ReadRoomDecorationSeed(decoration)) return finish();
        auto prediction = EIDOutcomePredictionPolicy::CrookedPenny(rng.seed,decoration,battery);
        NSMutableArray *outcomes = [NSMutableArray array];
        for (unsigned i = 0; i < prediction.count; ++i) [outcomes addObject:@(prediction.heads[i])];
        context[@"crooked_penny"] = @{@"validated":@YES,@"battery":@(battery),@"heads":outcomes.copy};
    } else {
        uintptr_t address = [context[@"native_address"] unsignedLongLongValue];
        uint32_t seed = [context[@"native_seed"] unsignedIntValue];
        if (!address || !seed || [context[@"native_run"] unsignedIntegerValue] != self.runCounter) return finish();
        BOOL eternal = has(player,609,false);
        if (!eternal && has(player,489,false)) {
            for (size_t slot = 0; slot < kPlayerPocketItemCount; ++slot) {
                int32_t active = 0; int16_t mode = -1;
                uintptr_t record = player+kPlayerActiveItemsOffset+slot*kPlayerActiveItemStride;
                if (ReadOwnTaskMemory(record,&active,sizeof(active)) && active == 489 &&
                    ReadOwnTaskMemory(record+0x1a,&mode,sizeof(mode)) && mode == 3) eternal = YES;
            }
        }
        if (!eternal) return finish();
        std::array<uint8_t,kPickupCollectibleCycleCountOffset+sizeof(int32_t)> bytes{};
        uintptr_t table = 0; int32_t native[3]{}, rerollState = 0, questState = 0; uint32_t init = 0, current = 0;
        if (!ReadOwnTaskMemory(address,bytes.data(),bytes.size())) return finish();
        memcpy(&table,bytes.data(),sizeof(table));
        memcpy(native,bytes.data()+kEntityTypeOffset,sizeof(native));
        memcpy(&init,bytes.data()+kPickupCycleSeedOffset,sizeof(init));
        memcpy(&current,bytes.data()+kPickupCurrentRNGOffset,sizeof(current));
        memcpy(&rerollState,bytes.data()+0x55c,sizeof(rerollState));
        memcpy(&questState,bytes.data()+0x570,sizeof(questState));
        const uint8_t *active = bytes.data()+kEntityStateOffset;
        if (!IsCandidateVTable(self.scanContext.pickupVTables,self.scanContext.pickupVTableCount,table) ||
            native[0] != 5 || native[1] != 100 || native[2] != identity.subtype || init != seed ||
            !active[0] || !active[2] || active[3] ||
            PickupVisibilityState(bytes.data(),bytes.size()) != PickupVisibility::Visible ||
            (rerollState != 0 && questState >= 0)) return finish();
        uint32_t queryOpcode = 0;
        if (!ReadOwnTaskMemory(image+0x7180d8,&queryOpcode,sizeof(queryOpcode)) || queryOpcode != 0xa9be4ff4) return finish();
        using CanReroll = bool (*)(uintptr_t);
        if (!reinterpret_cast<CanReroll>(image+0x7180d8)(address)) return finish();
        auto result = EIDOutcomePredictionPolicy::EternalD6(current);
        if (result == EIDOutcomePredictionPolicy::EternalResult::Unknown) return finish();
        context[@"eternal_d6"] = @{@"validated":@YES,@"battery":@(battery),
            @"vanishes":@(result == EIDOutcomePredictionPolicy::EternalResult::Vanish)};
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedCurrentEffectIdentity:(EIDPickupIdentity *)identity hiddenInfo:(BOOL)hiddenInfo {
    NSDictionary *oldEffect = identity.pickupContext[@"current_effect"];
    if ([oldEffect[@"validated"] boolValue] && [oldEffect[@"source_variant"] integerValue]==350) {
        NSInteger original = [oldEffect[@"source_subtype"] integerValue];
        if ((original & 0x7fff)==[oldEffect[@"source_id"] integerValue] && original>0 && original<=0xffff) {
            NSMutableDictionary *originalContext = identity.pickupContext.mutableCopy;
            [originalContext removeObjectForKey:@"current_effect"];
            identity = [[EIDPickupIdentity alloc] initWithVariant:350 subtype:original playerType:identity.playerType
                playerIndex:identity.playerIndex rawPillSubtype:0 pillModifiers:identity.pillModifiers pickupContext:originalContext];
        }
    }
    NSInteger trinket = identity.subtype & 0x7fff;
    if (identity.variant!=350 || (trinket!=166 && trinket!=32 && trinket!=132 && trinket!=153) || !self.supportedBuild ||
        !NSThread.isMainThread || !self.gameplayActive || !self.paused || identity.playerIndex<0) return identity;
    vm_address_t game=0; VMRegionResult players;
    if (!ReadGameObjectAddress(game) || self.playerVectorOffset==NSUIntegerMax ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players) ||
        (size_t)identity.playerIndex>=players.playerCount) return identity;
    NSDictionary *player = ReadDescriptionPlayer(players.players[(size_t)identity.playerIndex].address);
    if (!EIDTrinketEffectVisible(player,trinket,hiddenInfo)) return identity;
    NSDictionary *effect = trinket==166 ? player[@"modeling_clay"] : player[@"trinket_effects"][@(trinket).stringValue];
    NSInteger result = [effect[@"result"] integerValue];
    if (![effect[@"validated"] boolValue] || result<1 || result>732) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    context[@"current_effect"] = @{@"source_variant":@350,@"source_id":@(trinket),@"source_subtype":@(identity.subtype),
        @"result":@(result),@"validated":@YES};
    return [[EIDPickupIdentity alloc] initWithVariant:100 subtype:result playerType:[player[@"type"] integerValue]
        playerIndex:identity.playerIndex rawPillSubtype:0 pillModifiers:identity.pillModifiers pickupContext:context];
}

- (EIDPickupIdentity *)resolvedCraftingIdentity:(EIDPickupIdentity *)identity {
    if (identity.variant != EIDPickupVariantCollectible || identity.subtype != 710) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    // Do not carry floor-only or stale preview data into a hypothetical item.
    for (NSString *key in @[@"pedestal",@"collectible_cycle",@"crown_overview",@"crown_selection",
                            @"spindown",@"flip_id",@"crafting_bag",@"crafting_result"])
        [context removeObjectForKey:key];
    NSInteger displayID = 710, playerType = identity.playerType, playerIndex = identity.playerIndex;
    auto finish = [&]() -> EIDPickupIdentity * {
        return [[EIDPickupIdentity alloc] initWithVariant:EIDPickupVariantCollectible subtype:displayID
            playerType:playerType playerIndex:playerIndex rawPillSubtype:0
            pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!self.supportedBuild || !NSThread.isMainThread || !self.gameplayActive ||
        !self.pauseStateAvailable || !self.paused) return finish();
    vm_address_t game = 0;
    VMRegionResult players;
    if (!ReadGameObjectAddress(game) || self.playerVectorOffset == NSUIntegerMax ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players)) return finish();
    for (size_t index = 0; index < players.playerCount; ++index) {
        if (identity.playerIndex >= 0 && identity.playerIndex != (NSInteger)index) continue;
        NSDictionary *player = ReadDescriptionPlayer(players.players[index].address);
        if (![player[@"owned"] containsObject:@"5.100.710"]) continue;
        NSDictionary *bag = player[@"crafting_bag"];
        if (!bag) continue;
        context[@"crafting_bag"] = bag;
        playerType = [player[@"type"] integerValue];
        playerIndex = (NSInteger)index;
        NSInteger result = [bag[@"result"] integerValue];
        if ([bag[@"count"] integerValue] == 8 && result > 0 && result <= 732) {
            displayID = result;
            context[@"crafting_result"] = @YES;
        }
        NSDictionary *snapshot = @{@"run":@(self.runCounter),@"kind":@"crafting_bag",@"index":@(index),@"bag":bag};
        if (![snapshot isEqual:self.lastInventoryPreviewLogSnapshot]) {
            self.lastInventoryPreviewLogSnapshot = snapshot;
            EIDLog(@"native Bag of Crafting preview: player %lu, %@/8, result %@ (read only)",
                (unsigned long)index,bag[@"count"],bag[@"result"]);
        }
        break;
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedInventoryPreviewIdentity:(EIDPickupIdentity *)identity
                                blackFeatherMetadata:(NSDictionary *)metadata {
    BOOL stars = identity.variant == EIDPickupVariantCard && identity.subtype == 73;
    BOOL feather = identity.variant == EIDPickupVariantTrinket && (identity.subtype & 0x7fff) == 80;
    if (!stars && !feather) return identity;
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    NSString *key = stars ? @"stars_previews" : @"black_feather";
    context[key] = @[];
    auto finish = [&]() -> EIDPickupIdentity * {
        return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
            playerType:identity.playerType playerIndex:identity.playerIndex
            rawPillSubtype:identity.rawPillSubtype pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!self.supportedBuild || !NSThread.isMainThread) return finish();
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    vm_address_t game = 0, manager = 0;
    VMRegionResult players;
    if (!header || !ReadGameObjectAddress(game) || !self.playerVectorOffset ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players)) return finish();
    uintptr_t image = reinterpret_cast<uintptr_t>(header);
    std::array<uintptr_t,kMaximumCollectibleID+1> configs{};
    RemotePointerVector configSpan{};
    if (!ReadOwnTaskMemory(image+kManagerGlobalOffset,&manager,sizeof(manager)) || !manager ||
        !ReadOwnTaskMemory(manager+kManagerCollectibleConfigsOffset,&configSpan,sizeof(configSpan)) ||
        !configSpan.begin || configSpan.end < configSpan.begin || configSpan.capacity < configSpan.end ||
        configSpan.end-configSpan.begin != sizeof(configs) || configSpan.capacity-configSpan.begin > 4096*sizeof(uintptr_t) ||
        !ReadOwnTaskMemory(configSpan.begin,configs.data(),sizeof(configs))) return finish();
    uint32_t first = 0;
    auto prologue = [&](uintptr_t offset, uint32_t wanted) {
        return ReadOwnTaskMemory(image+offset,&first,sizeof(first)) && first == wanted;
    };
    if ((stars && !prologue(kPlayerCanRemoveCollectibleOffset,0xa9be4ff4)) ||
        (feather && (!prologue(kPlayerGetCollectibleNumOffset,0xa9bb67fa) ||
                     !prologue(kPlayerGetTrinketMultiplierOffset,0xd10143ff)))) return finish();
    NSArray *collectibles = metadata[@"collectibles"], *trinkets = metadata[@"trinkets"];
    if (feather) {
        if (![collectibles isKindOfClass:NSArray.class] || !collectibles.count || collectibles.count > 64 ||
            ![trinkets isKindOfClass:NSArray.class] || !trinkets.count || trinkets.count > 64) return finish();
        for (NSArray *list in @[collectibles,trinkets]) {
            NSInteger maximum = list == collectibles ? 732 : 189;
            if ([NSSet setWithArray:list].count != list.count) return finish();
            for (id identifier in list)
                if (![identifier isKindOfClass:NSNumber.class] || [identifier integerValue] < 1 ||
                    [identifier integerValue] > maximum) return finish();
        }
    }
    using HasCollectible = bool (*)(uintptr_t,uint32_t,bool);
    using GetNum = int32_t (*)(uintptr_t,uint32_t,bool);
    using GetTrinketMultiplier = int32_t (*)(uintptr_t,uint32_t);
    using CanRemove = bool (*)(uintptr_t,uint32_t);
    HasCollectible has = reinterpret_cast<HasCollectible>(image+kPlayerHasCollectibleOffset);
    GetNum getNum = reinterpret_cast<GetNum>(image+kPlayerGetCollectibleNumOffset);
    GetTrinketMultiplier multiplier = reinterpret_cast<GetTrinketMultiplier>(image+kPlayerGetTrinketMultiplierOffset);
    CanRemove canRemove = reinterpret_cast<CanRemove>(image+kPlayerCanRemoveCollectibleOffset);
    NSMutableArray *previews = [NSMutableArray array];
    for (size_t index = 0; index < players.playerCount; ++index) {
        uintptr_t player = players.players[index].address;
        std::array<int32_t,kMaximumCollectibleID+1> counts{};
        if (!ReadPlayerCollectibleCounts(player,counts)) continue;
        if (stars) {
            std::vector<EIDInventoryPreviewPolicy::HistoryEntry> history;
            std::vector<int32_t> items;
            if (!ReadPickupHistory(player,history)) continue;
            BOOL tarot = has(player,451,false);
            using EIDInventoryPreviewPolicy::Eligibility;
            bool valid = EIDInventoryPreviewPolicy::Stars(history,counts,tarot,[&](int32_t id) {
                uintptr_t config = configs[(size_t)id];
                int32_t nativeID = 0, type = -1;
                if (!config || !ReadOwnTaskMemory(config,&type,sizeof(type)) || type < 1 || type > 3 ||
                    !ReadOwnTaskMemory(config+4,&nativeID,sizeof(nativeID)) || nativeID != id) return Eligibility::Unknown;
                // Same native eligibility query and active-item exclusion used
                // by UseCard(73). It reads quest tags and challenge starters.
                if (type == 3 || !canRemove(player,(uint32_t)id)) return Eligibility::Excluded;
                return Eligibility::Eligible;
            },items);
            if (!valid) continue;
            NSMutableArray *identifiers = [NSMutableArray array];
            for (int32_t id : items) [identifiers addObject:@(id)];
            [previews addObject:@{@"index":@(index),@"items":identifiers.copy,@"tarot":@(tarot)}];
        } else {
            // The native getter reads the complete per-trinket count array,
            // including swallowed copies. Validate its span before calling it.
            RemotePointerVector smelted{};
            std::vector<int32_t> swallowed;
            std::array<int32_t,kPlayerTrinketSlotCount> slots{};
            if (!ReadOwnTaskMemory(player+kPlayerSmeltedTrinketsOffset,&smelted,sizeof(smelted)) ||
                !ReadSmeltedTrinkets(player,swallowed) || !ReadPlayerTrinkets(player,slots) ||
                smelted.end < smelted.begin || smelted.end-smelted.begin < 190*sizeof(EIDNativeContextPolicy::SmeltedCounts)) continue;
            int32_t count = 0;
            BOOL valid = YES;
            for (NSNumber *identifier in collectibles) {
                int32_t value = getNum(player,identifier.unsignedIntValue,false);
                if (value < 0 || value > 4096) { valid = NO; break; }
                count += value;
            }
            if (!valid) continue;
            for (NSNumber *identifier in trinkets) {
                int32_t value = multiplier(player,identifier.unsignedIntValue);
                if (value < 0 || value > 4096) { valid = NO; break; }
                count += value;
            }
            if (!valid || count > 100000) continue;
            [previews addObject:@{@"index":@(index),@"count":@(count),@"box":@(has(player,439,false))}];
        }
    }
    context[key] = previews.copy;
    NSDictionary *snapshot = @{@"run":@(self.runCounter),@"kind":key,@"previews":previews};
    if (![snapshot isEqual:self.lastInventoryPreviewLogSnapshot]) {
        self.lastInventoryPreviewLogSnapshot = snapshot;
        EIDLog(@"native %@ preview: %@",stars ? @"The Stars?" : @"Black Feather",previews);
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedRepeatIdentity:(EIDPickupIdentity *)identity {
    BOOL wild = identity.variant == EIDPickupVariantCard && identity.subtype == 80;
    BOOL vurp = (identity.variant == EIDPickupVariantPill || identity.variant == EIDPickupVariantHorsePill) && identity.subtype == 47;
    if (!wild && !vurp) return identity; // Includes unidentified/golden pills.
    NSMutableDictionary *context = identity.pickupContext.mutableCopy;
    context[@"repeat_previews"] = @[]; // Fail closed, never reuse an old result.
    auto finish = [&]() -> EIDPickupIdentity * {
        return [[EIDPickupIdentity alloc] initWithVariant:identity.variant subtype:identity.subtype
            playerType:identity.playerType playerIndex:identity.playerIndex
            rawPillSubtype:identity.rawPillSubtype pillModifiers:identity.pillModifiers pickupContext:context];
    };
    if (!self.supportedBuild || !NSThread.isMainThread) return finish();
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    vm_address_t game = 0;
    VMRegionResult players;
    if (!header || !ReadGameObjectAddress(game) || !self.playerVectorOffset ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players)) return finish();
    using GetEffect = int32_t (*)(uintptr_t,uint32_t,uintptr_t);
    GetEffect getEffect = reinterpret_cast<GetEffect>(reinterpret_cast<uintptr_t>(header)+kItemPoolGetPillEffectOffset);
    NSMutableArray *previews = [NSMutableArray array];
    for (size_t index = 0; index < players.playerCount; ++index) {
        vm_address_t player = players.players[index].address;
        NSDictionary *state = ReadRepeatState(player);
        NSInteger variant = 0, id = 0, color = 0;
        if (wild) {
            NSDictionary *effect = state[@"wild_card"];
            if (!effect) continue;
            switch ([effect[@"type"] intValue]) {
                case 0:
                    color = [effect[@"extra"] integerValue];
                    variant = (color & EIDRepeatPolicy::Horse) ? EIDPickupVariantHorsePill : EIDPickupVariantPill;
                    id = [effect[@"id"] integerValue]+1;
                    break;
                case 1: variant = EIDPickupVariantCard; id = [effect[@"id"] integerValue]; break;
                case 2: variant = EIDPickupVariantCollectible; id = [effect[@"id"] integerValue]; break;
                default: continue;
            }
        } else {
            NSNumber *previous = state[@"last_pill_color"];
            if (!previous) continue;
            color = EIDRepeatPolicy::VurpColor(previous.intValue,(int32_t)identity.rawPillSubtype);
            if (!color) continue;
            int32_t effect = previous.intValue == 0 ? EIDRepeatPolicy::VurpEffect :
                getEffect(game+kGameItemPoolOffset,(uint32_t)color & kPillColorMask,player);
            if (effect < 0 || effect > 49) continue;
            variant = (color & EIDRepeatPolicy::Horse) ? EIDPickupVariantHorsePill : EIDPickupVariantPill;
            id = effect+1;
        }
        [previews addObject:@{@"index":@(index),@"variant":@(variant),@"id":@(id),@"color":@(color)}];
    }
    context[@"repeat_previews"] = previews.copy;
    NSDictionary *snapshot = @{@"run":@(self.runCounter),@"wild_card":@(wild),@"previews":previews};
    if (![snapshot isEqual:self.lastRepeatLogSnapshot]) {
        self.lastRepeatLogSnapshot = snapshot;
        EIDLog(@"native %@ preview: %@",wild ? @"Wild Card" : @"Vurp!",previews);
    }
    return finish();
}

- (EIDPickupIdentity *)resolvedPillIdentity:(EIDPickupIdentity *)identity {
    if (!identity.rawPillSubtype || !self.supportedBuild || !NSThread.isMainThread ||
        !EIDPickupPolicy::IsPill((int32_t)identity.variant)) return identity;
    uint32_t color = (uint32_t)identity.rawPillSubtype & kPillColorMask;
    if (!color || color >= kGoldenPillColor) return identity;
    int32_t variant = EIDPickupVariantUnidentifiedPill;
    int32_t subtype = (int32_t)identity.rawPillSubtype;
    EIDPickupIdentity *unavailable = [[EIDPickupIdentity alloc] initWithVariant:variant subtype:subtype
        playerType:identity.playerType playerIndex:identity.playerIndex rawPillSubtype:identity.rawPillSubtype];
    vm_address_t game = 0;
    VMRegionResult players;
    const mach_header_64 *header = IsaacExecutableHeader(nullptr);
    if (!header || !ReadGameObjectAddress(game) || !self.playerVectorOffset ||
        !ReadPlayerVector(self.scanContext,game+self.playerVectorOffset,false,players) ||
        identity.playerIndex < 0 || (size_t)identity.playerIndex >= players.playerCount) return unavailable;
    vm_address_t player = players.players[(size_t)identity.playerIndex].address;
    uint8_t identified = UINT8_MAX, disabled = UINT8_MAX;
    std::array<int32_t, kMaximumCollectibleID + 1> counts{};
    if (!ReadOwnTaskMemory(game+kGameItemPoolOffset+kItemPoolIdentifiedPillsOffset+color,
        &identified,sizeof(identified)) || identified > 1 ||
        !ReadOwnTaskMemory(player+kPlayerNonQuestItemsDisabledOffset,&disabled,sizeof(disabled)) || disabled > 1 ||
        !ReadPlayerCollectibleCounts(player,counts)) return unavailable;
    // Read exactly the ownership used by native GetPillEffect, at the same
    // main-thread boundary. A background inventory snapshot may be one scan
    // behind a console removal and must not keep its reward text alive.
    using HasCollectible = bool (*)(uintptr_t, uint32_t, bool);
    HasCollectible has = reinterpret_cast<HasCollectible>(reinterpret_cast<uintptr_t>(header)+kPlayerHasCollectibleOffset);
    int modifiers = (has(player,75,false) ? EIDPillModifierPHD : 0) |
        (has(player,654,false) ? EIDPillModifierFalsePHD : 0) |
        (has(player,303,false) ? EIDPillModifierVirgo : 0) |
        (has(player,46,false) ? EIDPillModifierLuckyFoot : 0);
    if (!self.loggedPillModifiers || self.loggedPillModifierRun != self.runCounter) {
        self.loggedPillModifiers = [NSMutableDictionary dictionary];
        self.loggedPillModifierRun = self.runCounter;
    }
    NSNumber *previous = self.loggedPillModifiers[@(identity.playerIndex)];
    if (!previous || previous.integerValue != modifiers) {
        self.loggedPillModifiers[@(identity.playerIndex)] = @(modifiers);
        EIDLog(@"native pill modifiers: player %ld PHD %d FalsePHD %d Virgo %d LuckyFoot %d",
            (long)identity.playerIndex,!!(modifiers & EIDPillModifierPHD),
            !!(modifiers & EIDPillModifierFalsePHD),!!(modifiers & EIDPillModifierVirgo),
            !!(modifiers & EIDPillModifierLuckyFoot));
    }
    // PHD and False PHD identify pills; Virgo and Lucky Foot only improve them.
    if (identified || EIDPillModifiersIdentify(modifiers)) {
        // Reverse-verified ItemPool::GetPillEffect(color, player), not the mutating
        // pill randomizer. It handles good/bad conversions, health safety and
        // temporary Virgo effects exactly as the game's own pocket tooltip.
        using GetEffect = int32_t (*)(uintptr_t, uint32_t, uintptr_t);
        GetEffect getEffect = reinterpret_cast<GetEffect>(reinterpret_cast<uintptr_t>(header)+kItemPoolGetPillEffectOffset);
        int32_t effect = getEffect(game+kGameItemPoolOffset,color,player);
        if (effect < 0 || effect > 49) return unavailable;
        variant = ((uint32_t)identity.rawPillSubtype & kHorsePillFlag) ? EIDPickupVariantHorsePill : EIDPickupVariantPill;
        subtype = effect + 1;
    }
    return [[EIDPickupIdentity alloc] initWithVariant:variant subtype:subtype
        playerType:identity.playerType playerIndex:identity.playerIndex rawPillSubtype:identity.rawPillSubtype
        pillModifiers:modifiers];
}

- (NSArray<EIDPickupIdentity *> *)currentSmeltedTrinkets {
    return self.inventoryStateAvailable ? self.smeltedTrinketItems : @[];
}

- (NSArray<EIDPickupIdentity *> *)currentVoidedItems {
    if (!self.inventoryStateAvailable) return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *player in self.descriptionState[@"players"]) {
        if (![player[@"owned"] containsObject:@"5.100.477"]) continue;
        NSCountedSet *voided = [[NSCountedSet alloc] initWithArray:player[@"void_actives"] ?: @[]];
        for (NSNumber *item in [[voided allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
            if (![self.activeCollectibleIDs containsObject:item]) continue;
            [items addObject:[[EIDPickupIdentity alloc] initWithVariant:100 subtype:item.integerValue
                playerType:[player[@"type"] integerValue] playerIndex:[player[@"index"] integerValue]
                rawPillSubtype:0 pillModifiers:-1 pickupContext:@{@"inventory_run":@(self.runCounter),
                    @"void_absorbed":@YES,@"void_copies":@([voided countForObject:item])}]];
        }
    }
    return items.copy;
}

- (NSSet<NSString *> *)currentOwnedItemKeys {
    NSMutableSet<NSString *> *keys = [NSMutableSet set];
    NSArray *items = [[self currentInventoryItems] arrayByAddingObjectsFromArray:[self currentSmeltedTrinkets]];
    for (EIDPickupIdentity *item in items) {
        if (item.variant != EIDPickupVariantCollectible && item.variant != EIDPickupVariantTrinket) continue;
        NSInteger subtype = item.variant == EIDPickupVariantTrinket ? item.subtype & 0x7fff : item.subtype;
        if (subtype > 0) [keys addObject:[NSString stringWithFormat:@"5.%ld.%ld", (long)item.variant, (long)subtype]];
    }
    return keys.copy;
}

- (NSInteger)ownedCollectibleCountForID:(NSInteger)collectibleID {
    if (collectibleID <= 0 || collectibleID > (NSInteger)kMaximumCollectibleID ||
        !self.ownedCollectibleStateAvailable) return 0;
    return self.ownedCollectibleCounts[@(collectibleID)].integerValue;
}

- (NSInteger)transformationCollectibleCountForID:(NSInteger)collectibleID {
    NSInteger liveCount = [self ownedCollectibleCountForID:collectibleID];
    if (![self.activeCollectibleIDs containsObject:@(collectibleID)]) return liveCount;
    return MAX(liveCount, self.activeCollectibleHistory[@(collectibleID)].integerValue);
}

- (NSInteger)nativeTransformationCounterForFormID:(NSInteger)formID {
    if (!self.transformationStateAvailable || formID < 0 ||
        formID >= (NSInteger)self.nativeTransformationCounters.count) return 0;
    return self.nativeTransformationCounters[(NSUInteger)formID].integerValue;
}
@end
