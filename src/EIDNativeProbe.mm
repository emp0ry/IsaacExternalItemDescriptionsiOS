#import "EIDNativeProbe.h"
#import "EIDLogger.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>

#include <array>
#include <cctype>
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
    LocateVTables(kSlotRTTIName, context.slotVTables, context.slotVTableCount);
    LocateVTables(kEffectRTTIName, context.effectVTables, context.effectVTableCount);
    LocateVTables(kGridSpikesRTTIName, context.gridSpikesVTables,
                  context.gridSpikesVTableCount);
    return context;
}

constexpr size_t kEntityTypeOffset = 0x38;
constexpr size_t kEntityStateOffset = 0x1c0;
constexpr size_t kEntityPositionOffset = 0x310;
constexpr size_t kEntitySpriteLayerStatesOffset = 0xf8;
constexpr size_t kEntitySpriteLayerCountOffset = 0x100;
constexpr size_t kGridEntityDescOffset = 0x8;
constexpr size_t kGridEntityVarDataOffset = kGridEntityDescOffset + 0x14;
constexpr size_t kPickupTouchedOffset = 0x560;
constexpr size_t kPickupForceBlindOffset = 0x562;
constexpr size_t kCranePrizeCollectibleOffset = 0x570;
constexpr size_t kPlayerPocketItemsOffset = 0x1c10;
constexpr size_t kPlayerPocketItemCount = 4;
constexpr size_t kPlayerCollectibleCountsOffset = 0x1ab8;
constexpr size_t kMaximumCollectibleID = 732;
constexpr size_t kLayerStateSize = 0x90;
constexpr size_t kLayerStateSpritePathOffset = 0x8;
constexpr vm_size_t kVMReadChunk = 2 * 1024 * 1024;
constexpr vm_size_t kGamePlayerVectorScanLimit = 512 * 1024;
constexpr float kMaximumDescriptionDistance = 220.0f;
constexpr uintptr_t kGameGlobalOffset = 0xac3b90;
constexpr size_t kGameCursesOffset = 0xc;
constexpr size_t kGameCurrentRoomOffset = 0x21550;
constexpr size_t kRoomDescriptorOffset = 0x8;
constexpr size_t kRoomDescriptorDataOffset = 0x10;
constexpr size_t kRoomConfigTypeOffset = 0x8;
constexpr size_t kRoomGridEntitiesOffset = 0x30;
constexpr size_t kRoomGridEntityCount = 0x1c0;
constexpr int32_t kSacrificeRoomType = 13;
constexpr int32_t kGridSpikesType = 0x8;
constexpr uint32_t kCurseOfTheBlind = 1u << 6;
constexpr NSUInteger kRunEndConfirmationScans = 12;
constexpr size_t kGameRunSeedOffset = 0x25d44;
constexpr size_t kGameItemPoolOffset = 0x242c0;
constexpr size_t kItemPoolPillEffectsOffset = 0xa2c;
constexpr size_t kItemPoolIdentifiedPillsOffset = 0xa68;
constexpr uint32_t kPillColorMask = 0x7ff;
constexpr uint32_t kHorsePillFlag = 1u << 11;
constexpr uint32_t kGoldenPillColor = 14;

struct VMPickup {
    int32_t variant = 0;
    int32_t subtype = 0;
    float x = 0;
    float y = 0;
    bool hasPosition = false;
};

struct VMPlayer {
    vm_address_t address = 0;
    float x = 0;
    float y = 0;
};

struct VMCardObservation {
    vm_address_t address = 0;
    int32_t subtype = 0;
    float x = 0;
    float y = 0;
    bool hasPosition = false;
    bool touched = false;
};

struct VMPlayerPocketItem {
    int32_t id = 0;
    uint32_t type = 0;
};

static_assert(sizeof(VMPlayerPocketItem) == 8, "Unexpected native pocket-item layout");

struct VMRegionResult {
    vm_address_t address = 0;
    vm_size_t size = 0;
    size_t pickupVTableReferences = 0;
    size_t playerVTableReferences = 0;
    size_t slotVTableReferences = 0;
    size_t effectVTableReferences = 0;
    size_t gridSpikesVTableReferences = 0;
    vm_address_t firstPickupVTableAddress = 0;
    vm_address_t lastPickupVTableAddress = 0;
    vm_address_t firstSlotVTableAddress = 0;
    vm_address_t lastSlotVTableAddress = 0;
    vm_address_t firstEffectVTableAddress = 0;
    vm_address_t lastEffectVTableAddress = 0;
    std::array<VMPickup, kMaxItems> pickups{};
    size_t pickupCount = 0;
    std::array<VMCardObservation, kMaxItems> cardObservations{};
    size_t cardObservationCount = 0;
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
    if (!ReadOwnTaskMemory(playerAddress + kPlayerPocketItemsOffset,
                           items.data(), sizeof(items))) return false;

    // Entity_Player::GetCard/GetPill in the supported ARM64 executable read four
    // consecutive { int32 id, uint32 type } entries here. Reject the whole read if
    // any entry is inconsistent, rather than treating unrelated memory as inventory.
    for (const VMPlayerPocketItem& item : items) {
        if (item.type > 2 || item.id < 0) return false;
        if (item.type == 0 && item.id > 0xffff) return false;
        if (item.type == 1 && item.id > 97) return false;
        if (item.type == 2 && item.id > 4096) return false;
    }
    return true;
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

static bool ResolveKnownPill(int32_t rawSubtype, int32_t& variant, int32_t& subtype) {
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
    if (identified != 1) return false;

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

static bool IsQuestionMarkSpritePath(std::string path) {
    for (char& character : path) {
        if (character == '\\') character = '/';
        else character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    }
    size_t slash = path.find_last_of('/');
    std::string basename = slash == std::string::npos ? path : path.substr(slash + 1);
    return basename == "questionmark.png";
}

enum class PickupVisibility { Visible, Blind, Unreadable };

static PickupVisibility PickupVisibilityState(const uint8_t *object, size_t available) {
    if (available <= kPickupForceBlindOffset) return PickupVisibility::Unreadable;
    if (object[kPickupForceBlindOffset]) return PickupVisibility::Blind;
    if (available < kEntitySpriteLayerCountOffset + sizeof(uint32_t)) {
        return PickupVisibility::Unreadable;
    }
    uintptr_t layerStatesAddress = 0;
    uint32_t layerCount = 0;
    memcpy(&layerStatesAddress, object + kEntitySpriteLayerStatesOffset, sizeof(layerStatesAddress));
    memcpy(&layerCount, object + kEntitySpriteLayerCountOffset, sizeof(layerCount));
    if (!layerStatesAddress || !layerCount || layerCount > 32) return PickupVisibility::Unreadable;

    bool unreadableLayer = false;
    for (uint32_t layer = 0; layer < layerCount; ++layer) {
        std::array<uint8_t, kLayerStateSize> layerState{};
        vm_address_t layerAddress = layerStatesAddress + layer * kLayerStateSize;
        if (!ReadOwnTaskMemory(layerAddress, layerState.data(), layerState.size())) {
            unreadableLayer = true;
            continue;
        }
        std::string path;
        if (!ReadRemoteLibCppString(layerState.data() + kLayerStateSpritePathOffset, path)) {
            unreadableLayer = true;
            continue;
        }
        if (IsQuestionMarkSpritePath(path)) return PickupVisibility::Blind;
    }
    return unreadableLayer ? PickupVisibility::Unreadable : PickupVisibility::Visible;
}

static bool IsDescribableVariant(int32_t variant) {
    return variant == EIDPickupVariantPill || variant == EIDPickupVariantCollectible ||
        variant == EIDPickupVariantHorsePill || variant == EIDPickupVariantCard ||
        variant == EIDPickupVariantTrinket || variant == EIDPickupVariantDiceRoom ||
        variant == EIDPickupVariantSacrificeRoom;
}

static void AddVMPickup(VMRegionResult& result, int32_t variant, int32_t subtype,
                        float x, float y, bool hasPosition) {
    if (!IsDescribableVariant(variant) || subtype <= 0 || subtype > 65535) return;
    // Subtype zero and out-of-range tarot IDs are unknown/hidden card identities.
    if (variant == EIDPickupVariantCard && subtype > 97) return;
    // Keep duplicate identities: two equal cards/trinkets may exist at different positions,
    // and proximity must choose the actual nearest entity rather than the first copy.
    if (result.pickupCount < result.pickups.size()) {
        result.pickups[result.pickupCount++] = {variant, subtype, x, y, hasPosition};
    }
}

static size_t SuppressCollectiblePickups(VMRegionResult& result) {
    size_t output = 0;
    size_t suppressed = 0;
    for (size_t index = 0; index < result.pickupCount; ++index) {
        const VMPickup& pickup = result.pickups[index];
        if (pickup.variant == EIDPickupVariantCollectible) {
            suppressed++;
            continue;
        }
        if (output != index) result.pickups[output] = pickup;
        output++;
    }
    result.pickupCount = output;
    result.blindPickupCount += suppressed;
    return suppressed;
}

static bool ResolveSacrificeRoomSpikes(const ScanContext& context,
                                       VMRegionResult& result) {
    vm_address_t room = 0;
    int32_t roomType = 0;
    if (!ReadCurrentRoomAddress(room) || !ReadCurrentRoomType(roomType)) return false;
    if (roomType != kSacrificeRoomType) return true;

    std::array<uintptr_t, kRoomGridEntityCount> gridEntities{};
    if (!ReadOwnTaskMemory(room + kRoomGridEntitiesOffset, gridEntities.data(),
                           sizeof(gridEntities))) return false;

    constexpr int32_t roomGridWidth = 15;
    for (size_t gridIndex = 0; gridIndex < gridEntities.size(); ++gridIndex) {
        vm_address_t gridEntity = static_cast<vm_address_t>(gridEntities[gridIndex]);
        if (!gridEntity) continue;
        std::array<uint8_t, kGridEntityVarDataOffset + sizeof(int32_t)> object{};
        if (!ReadOwnTaskMemory(gridEntity, object.data(), object.size())) continue;
        uintptr_t vtable = 0;
        int32_t gridType = 0;
        int32_t varData = 0;
        memcpy(&vtable, object.data(), sizeof(vtable));
        if (!IsCandidateVTable(context.gridSpikesVTables,
                               context.gridSpikesVTableCount, vtable)) continue;
        result.gridSpikesVTableReferences++;
        memcpy(&gridType, object.data() + kGridEntityDescOffset, sizeof(gridType));
        memcpy(&varData, object.data() + kGridEntityVarDataOffset, sizeof(varData));
        if (gridType != kGridSpikesType || varData < 0 || varData > 1000) continue;

        float gridX = 40.0f + 40.0f * static_cast<float>(gridIndex % roomGridWidth);
        float gridY = 80.0f + 40.0f * static_cast<float>(gridIndex / roomGridWidth);
        int32_t payout = varData >= 11 ? 12 : varData + 1;
        AddVMPickup(result, EIDPickupVariantSacrificeRoom, payout,
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

static void AddVMCardObservation(VMRegionResult& result, vm_address_t address, int32_t subtype,
                                 float x, float y, bool hasPosition, bool touched) {
    if (subtype <= 0 || subtype > 97 || result.cardObservationCount >= result.cardObservations.size()) {
        return;
    }
    result.cardObservations[result.cardObservationCount++] = {
        address, subtype, x, y, hasPosition, touched
    };
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
        bool slotVTable = IsCandidateVTable(context.slotVTables, context.slotVTableCount, vtable);
        bool effectVTable = IsCandidateVTable(context.effectVTables, context.effectVTableCount, vtable);
        if (!pickupVTable && !playerVTable && !slotVTable && !effectVTable) continue;

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
                if (displayVariant == EIDPickupVariantCard) {
                    bool touched = offset + kPickupTouchedOffset < size &&
                        bytes[offset + kPickupTouchedOffset] != 0;
                    AddVMCardObservation(result, sourceAddress + offset, displaySubtype,
                                         x, y, positionAvailable, touched);
                    // Card visibility is decided after the player and pickup snapshots are
                    // combined, allowing EID to remember a real pickup/drop transition even
                    // when this iOS build clears the native Touched flag on the new entity.
                    continue;
                }
                if (displayVariant == EIDPickupVariantPill &&
                    !ResolveKnownPill(displaySubtype, displayVariant, displaySubtype)) continue;
                PickupVisibility visibility = identity[1] == EIDPickupVariantCollectible
                    ? PickupVisibilityState(bytes + offset, size - offset)
                    : PickupVisibility::Visible;
                if (visibility == PickupVisibility::Visible) {
                    AddVMPickup(result, displayVariant, displaySubtype, x, y, positionAvailable);
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
    self = [super init];
    if (self) {
        _variant = variant;
        _subtype = subtype;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (![object isKindOfClass:EIDPickupIdentity.class]) return NO;
    EIDPickupIdentity *other = object;
    return self.variant == other.variant && self.subtype == other.subtype;
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
@property(atomic) uint32_t runSeed;
@property(atomic) NSUInteger runCounter;
@property(atomic, getter=isOwnedCollectibleStateAvailable) BOOL ownedCollectibleStateAvailable;
@property(nonatomic, strong) NSArray<EIDPickupIdentity *> *lastPickups;
@property(nonatomic, strong) NSDictionary<NSNumber *, NSNumber *> *ownedCollectibleCounts;
@property(nonatomic, copy) NSSet<NSNumber *> *activeCollectibleIDs;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *activeCollectibleHistory;
@property(nonatomic) ScanContext scanContext;
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL wroteDevelopmentProbe;
@property(nonatomic) vm_address_t pickupRegionAddress;
@property(nonatomic) vm_size_t pickupRegionSize;
@property(nonatomic) vm_address_t playerRegionAddress;
@property(nonatomic) vm_size_t playerRegionSize;
@property(nonatomic) vm_address_t effectRegionAddress;
@property(nonatomic) vm_size_t effectRegionSize;
@property(nonatomic) NSUInteger playerVectorOffset;
@property(nonatomic) vm_address_t slotRegionAddress;
@property(nonatomic) vm_size_t slotRegionSize;
@property(nonatomic) BOOL loggedVMDiscovery;
@property(nonatomic) BOOL loggedPositionValidation;
@property(nonatomic) BOOL loggedBlindPedestal;
@property(nonatomic) BOOL loggedUnreadableBlindState;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *knownCardSubtypes;
@property(nonatomic) BOOL loggedUnreadablePocketItems;
@property(nonatomic) BOOL loggedUnreadableCollectibleCounts;
@property(nonatomic) NSInteger lastLoggedRoomType;
@property(nonatomic) uint32_t lastLoggedCurseMask;
@property(nonatomic) NSInteger lastSacrificePayout;
@property(nonatomic) BOOL nativeRunActive;
@property(nonatomic) NSUInteger consecutiveEmptyPlayerScans;
@property(nonatomic) BOOL pillPoolReady;
@property(nonatomic) NSUInteger developmentCaptureIndex;
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
        _ownedCollectibleCounts = @{};
        _activeCollectibleIDs = [NSSet set];
        _activeCollectibleHistory = [NSMutableDictionary dictionary];
        _knownCardSubtypes = [NSMutableSet set];
        _playerVectorOffset = NSUIntegerMax;
        _lastLoggedRoomType = NSIntegerMin;
        _lastLoggedCurseMask = UINT32_MAX;
        _lastSacrificePayout = -1;
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
    self.status = [NSString stringWithFormat:@"Native probe active (pickup:%lu player:%lu slot:%lu effect:%lu spikes:%lu)",
                   (unsigned long)self.scanContext.pickupVTableCount,
                   (unsigned long)self.scanContext.playerVTableCount,
                   (unsigned long)self.scanContext.slotVTableCount,
                   (unsigned long)self.scanContext.effectVTableCount,
                   (unsigned long)self.scanContext.gridSpikesVTableCount];
    const mach_header_64 *isaacHeader = IsaacExecutableHeader(nullptr);
    NSString *imageMode = isaacHeader && isaacHeader->filetype == MH_DYLIB
        ? @"LiveContainer guest dylib" : @"native executable";
    EIDLog(@"%@; executable UUID %@; image mode %@", self.status,
           self.executableUUID, imageMode);
    EIDLog(@"native card/rune and pill knowledge will activate from current run state");
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
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
        [self.activeCollectibleHistory removeAllObjects];
        [self.knownCardSubtypes removeAllObjects];
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
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
        [self.activeCollectibleHistory removeAllObjects];
        [self.knownCardSubtypes removeAllObjects];
        self.loggedUnreadablePocketItems = NO;
        self.loggedUnreadableCollectibleCounts = NO;
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

- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups {
    if (!self.started || !self.scanContext.pickupVTableCount) {
        self.gameplayActive = NO;
        return @[];
    }

    VMRegionResult pickupResult;
    VMRegionResult playerResult;
    VMRegionResult slotResult;
    VMRegionResult effectResult;
    VMRegionResult gridSpikesResult;
    bool pickupRegionValid = self.pickupRegionAddress &&
        ScanVMRegion(self.scanContext, self.pickupRegionAddress, self.pickupRegionSize, pickupResult) &&
        pickupResult.pickupVTableReferences;
    bool playerRegionValid = self.playerRegionAddress &&
        ScanVMRegion(self.scanContext, self.playerRegionAddress, self.playerRegionSize, playerResult) &&
        playerResult.playerVTableReferences;
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
        (self.slotRegionAddress && !slotRegionValid)) {
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
            EIDLog(@"safe VM entity discovery: pickup refs %lu, player refs %lu, slot refs %lu, effect refs %lu, spikes refs %lu, "
                   "cache %.1f MiB",
                   (unsigned long)pickupResult.pickupVTableReferences,
                   (unsigned long)playerResult.playerVTableReferences,
                   (unsigned long)slotResult.slotVTableReferences,
                   (unsigned long)effectResult.effectVTableReferences,
                   (unsigned long)gridSpikesResult.gridSpikesVTableReferences,
                   (double)self.pickupRegionSize / (1024.0 * 1024.0));
        }
    }
    if (!pickupRegionValid) {
        self.gameplayActive = playerVectorResolved && managedPlayers.playerCount > 0;
        if (!self.gameplayActive) self.lastPickups = @[];
        return self.gameplayActive ? self.lastPickups : @[];
    }
    self.gameplayActive = playerVectorResolved
        ? managedPlayers.playerCount > 0
        : playerRegionValid && playerResult.playerCount > 0;
    if (self.gameplayActive && playerResult.playerCount) {
        [self updateOwnedCollectibleCountsForPlayers:playerResult];
    } else if (playerVectorResolved) {
        self.ownedCollectibleCounts = @{};
        self.ownedCollectibleStateAvailable = NO;
    }

    uint32_t curseMask = 0;
    bool curseMaskAvailable = ReadCurrentCurseMask(curseMask);
    if (curseMaskAvailable && self.lastLoggedCurseMask != curseMask) {
        self.lastLoggedCurseMask = curseMask;
        EIDLog(@"native level curse mask changed: 0x%02x%@", curseMask,
               curseMask & kCurseOfTheBlind ? @" (Curse of the Blind)" : @"");
    }
    if (curseMaskAvailable && (curseMask & kCurseOfTheBlind)) {
        SuppressCollectiblePickups(pickupResult);
    }

    // Some iOS card drops are created with Touched cleared. Read the game's four native
    // pocket slots first, so a concrete card is learned while the player actually holds
    // it. The learned identity then remains visible if that card is dropped later, while
    // a never-held floor card remains hidden.
    if (playerResult.playerCount) {
        for (size_t playerIndex = 0; playerIndex < playerResult.playerCount; ++playerIndex) {
            std::array<VMPlayerPocketItem, kPlayerPocketItemCount> pocketItems{};
            if (!ReadPlayerPocketItems(playerResult.players[playerIndex].address, pocketItems)) {
                if (!self.loggedUnreadablePocketItems) {
                    self.loggedUnreadablePocketItems = YES;
                    EIDLog(@"native player pocket slots unreadable; card learning suppressed");
                }
                continue;
            }
            for (size_t slot = 0; slot < pocketItems.size(); ++slot) {
                const VMPlayerPocketItem& item = pocketItems[slot];
                if (item.type != 1 || item.id <= 0 || item.id > 97) continue;
                NSNumber *subtype = @(item.id);
                if (![self.knownCardSubtypes containsObject:subtype]) {
                    [self.knownCardSubtypes addObject:subtype];
                    EIDLog(@"card/rune %@ learned from native player pocket slot %lu",
                           subtype, (unsigned long)slot);
                }
            }
        }
    }

    for (size_t index = 0; index < pickupResult.cardObservationCount; ++index) {
        const VMCardObservation& card = pickupResult.cardObservations[index];
        if (card.touched) [self.knownCardSubtypes addObject:@(card.subtype)];
        if (card.touched || [self.knownCardSubtypes containsObject:@(card.subtype)]) {
            AddVMPickup(pickupResult, EIDPickupVariantCard, card.subtype,
                        card.x, card.y, card.hasPosition);
        }
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
                    }
                }
            }
        }
        if (closest && closestDistance <= kMaximumDescriptionDistance * kMaximumDescriptionDistance) {
            [pickups addObject:[[EIDPickupIdentity alloc] initWithVariant:closest->variant
                                                                  subtype:closest->subtype]];
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
@end
