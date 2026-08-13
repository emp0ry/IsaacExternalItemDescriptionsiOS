#import "EIDNativeProbe.h"
#import "EIDLogger.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <UIKit/UIKit.h>

#include <array>
#include <cmath>
#include <cstring>
#include <vector>

#ifndef EID_DEVELOPMENT_LAYOUT_CAPTURE
#define EID_DEVELOPMENT_LAYOUT_CAPTURE 0
#endif

namespace {
constexpr const char *kPickupRTTIName = "N15IsaacRepentance13Entity_PickupE";
constexpr const char *kPlayerRTTIName = "N15IsaacRepentance13Entity_PlayerE";
constexpr const char *kSlotRTTIName = "N15IsaacRepentance11Entity_SlotE";
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
};

static bool IsCandidateVTable(const std::array<uintptr_t, kMaxVTables>& vtables,
                              size_t count, uintptr_t value) {
    for (size_t i = 0; i < count; ++i) {
        if (vtables[i] == value) return true;
    }
    return false;
}


static const mach_header_64 *MainExecutableHeader(intptr_t *slideOut) {
    uint32_t count = _dyld_image_count();
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

static NSString *MainExecutableUUID(void) {
    const mach_header_64 *header = MainExecutableHeader(nullptr);
    if (!header || header->magic != MH_MAGIC_64) return @"UNKNOWN";
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header + 1);
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        const load_command *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmd == LC_UUID) {
            const uuid_command *uuidCommand = reinterpret_cast<const uuid_command *>(cursor);
            const unsigned char *u = uuidCommand->uuid;
            return [NSString stringWithFormat:
                    @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    u[0],u[1],u[2],u[3],u[4],u[5],u[6],u[7],u[8],u[9],u[10],u[11],u[12],u[13],u[14],u[15]];
        }
        if (!command->cmdsize) break;
        cursor += command->cmdsize;
    }
    return @"UNKNOWN";
}

static void ForEachMainImageSegment(void (^block)(const uint8_t *address, size_t size, vm_prot_t protection)) {
    intptr_t slide = 0;
    const mach_header_64 *header = MainExecutableHeader(&slide);
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
    return context;
}

constexpr size_t kEntityTypeOffset = 0x38;
constexpr size_t kEntityStateOffset = 0x1c0;
constexpr size_t kEntityPositionOffset = 0x310;
constexpr size_t kEntitySpriteLayerStatesOffset = 0xf8;
constexpr size_t kEntitySpriteLayerCountOffset = 0x100;
constexpr size_t kPickupForceBlindOffset = 0x562;
constexpr size_t kCranePrizeCollectibleOffset = 0x570;
constexpr size_t kLayerStateSize = 0x90;
constexpr size_t kLayerStateSpritePathOffset = 0x8;
constexpr vm_size_t kVMReadChunk = 2 * 1024 * 1024;
constexpr float kMaximumDescriptionDistance = 220.0f;
constexpr uintptr_t kGameGlobalOffset = 0xac3b90;
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

struct VMRegionResult {
    vm_address_t address = 0;
    vm_size_t size = 0;
    size_t pickupVTableReferences = 0;
    size_t playerVTableReferences = 0;
    size_t slotVTableReferences = 0;
    vm_address_t firstPickupVTableAddress = 0;
    vm_address_t lastPickupVTableAddress = 0;
    vm_address_t firstSlotVTableAddress = 0;
    vm_address_t lastSlotVTableAddress = 0;
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

static bool ResolveKnownPill(int32_t rawSubtype, int32_t& variant, int32_t& subtype) {
    uint32_t rawColor = static_cast<uint32_t>(rawSubtype);
    uint32_t color = rawColor & kPillColorMask;
    if (color == 0 || color > kGoldenPillColor) return false;

    const mach_header_64 *header = MainExecutableHeader(nullptr);
    uintptr_t game = 0;
    if (!header || !ReadOwnTaskMemory(reinterpret_cast<vm_address_t>(header) + kGameGlobalOffset,
                                      &game, sizeof(game)) || !game) return false;
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
    const mach_header_64 *header = MainExecutableHeader(nullptr);
    uintptr_t game = 0;
    if (!header || !ReadOwnTaskMemory(reinterpret_cast<vm_address_t>(header) + kGameGlobalOffset,
                                      &game, sizeof(game)) || !game) return false;
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

static bool RemoteLibCppStringEquals(const uint8_t *stringObject, const char *expected,
                                     bool& readable) {
    // This Isaac build uses libc++'s alternate string layout: long strings are
    // pointer/size/capacity and short strings store their size in byte 23.
    uintptr_t dataAddress = 0;
    uint64_t length = 0;
    uint64_t capacity = 0;
    memcpy(&dataAddress, stringObject, sizeof(dataAddress));
    memcpy(&length, stringObject + 8, sizeof(length));
    memcpy(&capacity, stringObject + 16, sizeof(capacity));
    char value[128]{};
    if (capacity & (1ull << 63)) {
        if (length >= sizeof(value) || (length && !dataAddress)) return false;
        if (length && !ReadOwnTaskMemory(dataAddress, value, static_cast<vm_size_t>(length))) return false;
        value[length] = '\0';
    } else {
        uint8_t shortLength = stringObject[23];
        if (shortLength >= 23 || shortLength >= sizeof(value)) return false;
        memcpy(value, stringObject, shortLength);
        value[shortLength] = '\0';
    }
    readable = true;
    return strcasecmp(value, expected) == 0;
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

    if (layerCount <= 1) return PickupVisibility::Unreadable;
    std::array<uint8_t, kLayerStateSize> layerState{};
    vm_address_t itemLayerAddress = layerStatesAddress + kLayerStateSize;
    if (!ReadOwnTaskMemory(itemLayerAddress, layerState.data(), layerState.size())) {
        return PickupVisibility::Unreadable;
    }
    constexpr const char *kQuestionMark = "gfx/Items/Collectibles/questionmark.png";
    bool readable = false;
    bool questionMark = RemoteLibCppStringEquals(
        layerState.data() + kLayerStateSpritePathOffset, kQuestionMark, readable);
    if (!readable) return PickupVisibility::Unreadable;
    return questionMark ? PickupVisibility::Blind : PickupVisibility::Visible;
}

static bool IsDescribableVariant(int32_t variant) {
    return variant == EIDPickupVariantPill || variant == EIDPickupVariantCollectible ||
        variant == EIDPickupVariantHorsePill || variant == EIDPickupVariantCard ||
        variant == EIDPickupVariantTrinket;
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
        bool slotVTable = IsCandidateVTable(context.slotVTables, context.slotVTableCount, vtable);
        if (!pickupVTable && !playerVTable && !slotVTable) continue;

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
                if (candidate.pickupVTableReferences > discovery.pickupRegion.pickupVTableReferences) {
                    discovery.pickupRegion = candidate;
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
@property(nonatomic, strong) NSArray<EIDPickupIdentity *> *lastPickups;
@property(nonatomic) ScanContext scanContext;
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL wroteDevelopmentProbe;
@property(nonatomic) vm_address_t pickupRegionAddress;
@property(nonatomic) vm_size_t pickupRegionSize;
@property(nonatomic) vm_address_t playerRegionAddress;
@property(nonatomic) vm_size_t playerRegionSize;
@property(nonatomic) vm_address_t slotRegionAddress;
@property(nonatomic) vm_size_t slotRegionSize;
@property(nonatomic) BOOL loggedVMDiscovery;
@property(nonatomic) BOOL loggedPositionValidation;
@property(nonatomic) BOOL loggedBlindPedestal;
@property(nonatomic) BOOL loggedUnreadableBlindState;
@property(nonatomic) NSUInteger developmentCaptureIndex;
@end

@implementation EIDNativeProbe
- (instancetype)init {
    self = [super init];
    if (self) {
        _executableUUID = MainExecutableUUID();
        NSString *supportedUUID = [NSString stringWithUTF8String:kSupportedUUID];
        _supportedBuild = [_executableUUID caseInsensitiveCompare:supportedUUID] == NSOrderedSame;
        _status = _supportedBuild ? @"Locating native pickup RTTI" : @"Unsupported Isaac executable";
        _lastPickups = @[];
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
    self.status = [NSString stringWithFormat:@"Native probe active (pickup:%lu player:%lu slot:%lu)",
                   (unsigned long)self.scanContext.pickupVTableCount,
                   (unsigned long)self.scanContext.playerVTableCount,
                   (unsigned long)self.scanContext.slotVTableCount];
    EIDLog(@"%@; executable UUID %@", self.status, self.executableUUID);
    NSUInteger identifiedPills = 0;
    if (ValidateNativePillPool(identifiedPills)) {
        EIDLog(@"native pill state active (%lu identified colors)",
               (unsigned long)identifiedPills);
    } else {
        EIDLog(@"native pill state is not ready; pill descriptions remain hidden");
    }
}

- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups {
    if (!self.started || !self.scanContext.pickupVTableCount) return @[];

    VMRegionResult pickupResult;
    VMRegionResult playerResult;
    VMRegionResult slotResult;
    bool pickupRegionValid = self.pickupRegionAddress &&
        ScanVMRegion(self.scanContext, self.pickupRegionAddress, self.pickupRegionSize, pickupResult) &&
        pickupResult.pickupVTableReferences;
    bool playerRegionValid = self.playerRegionAddress &&
        ScanVMRegion(self.scanContext, self.playerRegionAddress, self.playerRegionSize, playerResult) &&
        playerResult.playerVTableReferences;
    bool slotRegionValid = self.slotRegionAddress &&
        ScanVMRegion(self.scanContext, self.slotRegionAddress, self.slotRegionSize, slotResult) &&
        slotResult.slotVTableReferences;

    if (!pickupRegionValid || (pickupResult.pickupCount && !playerRegionValid) ||
        (self.slotRegionAddress && !slotRegionValid)) {
        VMDiscovery discovery = DiscoverEntityRegions(self.scanContext);
        if (discovery.pickupRegion.pickupVTableReferences) {
            pickupResult = discovery.pickupRegion;
            if (pickupResult.firstPickupVTableAddress && pickupResult.lastPickupVTableAddress >= pickupResult.firstPickupVTableAddress) {
                self.pickupRegionAddress = pickupResult.firstPickupVTableAddress;
                self.pickupRegionSize = pickupResult.lastPickupVTableAddress -
                    pickupResult.firstPickupVTableAddress + 0x1000;
            } else {
                self.pickupRegionAddress = pickupResult.address;
                self.pickupRegionSize = pickupResult.size;
            }
            pickupRegionValid = true;
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
            EIDLog(@"safe VM entity discovery: pickup refs %lu, player refs %lu, slot refs %lu, "
                   "cache %.1f MiB",
                   (unsigned long)pickupResult.pickupVTableReferences,
                   (unsigned long)playerResult.playerVTableReferences,
                   (unsigned long)slotResult.slotVTableReferences,
                   (double)self.pickupRegionSize / (1024.0 * 1024.0));
        }
    }
    if (!pickupRegionValid) return self.lastPickups;

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
    if (playerResult.playerCount && (pickupResult.pickupCount || slotResult.pickupCount)) {
        const VMPickup *closest = nullptr;
        float closestDistance = INFINITY;
        const VMRegionResult *sources[] = {&pickupResult, &slotResult};
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
@end
