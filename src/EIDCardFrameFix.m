#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <objc/message.h>
#import <objc/runtime.h>

// ui_cardspills.anm2 CardFronts contains an invisible frame 0.
// Isaac's Card enum/subtype is intentionally used as the ANM2 frame number:
// subtype 1 -> frame 1, subtype 2 -> frame 2, etc. This also covers runes
// because they are part of the same CardFronts animation.

static const char *kEIDRunResetSupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
static const uintptr_t kEIDRunResetGameGlobalOffset = 0xac3b90;

struct EIDRemotePointerVector {
    uintptr_t begin;
    uintptr_t end;
    uintptr_t capacity;
};

static BOOL EIDRunResetRead(vm_address_t address, void *destination, vm_size_t size) {
    if (!address || !destination || !size) return NO;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), address, size,
                             (vm_address_t)destination, &copied) == KERN_SUCCESS && copied == size;
}

static NSString *EIDRunResetUUIDForHeader(const struct mach_header_64 *header) {
    if (!header || header->magic != MH_MAGIC_64) return nil;
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        if (cursor + sizeof(struct load_command) > end) break;
        const struct load_command *command = (const struct load_command *)cursor;
        if (!command->cmdsize || cursor + command->cmdsize > end) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)cursor;
            const unsigned char *u = uuidCommand->uuid;
            return [NSString stringWithFormat:
                @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                u[0],u[1],u[2],u[3],u[4],u[5],u[6],u[7],u[8],u[9],u[10],u[11],u[12],u[13],u[14],u[15]];
        }
        cursor += command->cmdsize;
    }
    return nil;
}

static const struct mach_header_64 *EIDRunResetIsaacHeader(void) {
    NSString *wanted = [NSString stringWithUTF8String:kEIDRunResetSupportedUUID];
    for (uint32_t index = 0; index < _dyld_image_count(); ++index) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
        NSString *uuid = EIDRunResetUUIDForHeader(header);
        if (uuid && [uuid caseInsensitiveCompare:wanted] == NSOrderedSame) return header;
    }
    return NULL;
}

static uintptr_t EIDCurrentRunIdentity(id probe) {
    if (!probe) return 0;
    NSNumber *offsetNumber = nil;
    @try { offsetNumber = [probe valueForKey:@"playerVectorOffset"]; }
    @catch (__unused NSException *exception) { return 0; }
    if (![offsetNumber isKindOfClass:NSNumber.class]) return 0;
    NSUInteger playerVectorOffset = offsetNumber.unsignedIntegerValue;
    if (playerVectorOffset == NSUIntegerMax) return 0;

    const struct mach_header_64 *header = EIDRunResetIsaacHeader();
    if (!header) return 0;
    uintptr_t game = 0;
    if (!EIDRunResetRead((vm_address_t)header + kEIDRunResetGameGlobalOffset,
                         &game, sizeof(game)) || !game) return 0;

    EIDRemotePointerVector vector = {};
    if (!EIDRunResetRead(game + playerVectorOffset, &vector, sizeof(vector))) return 0;
    if (!vector.begin || vector.end <= vector.begin || vector.capacity < vector.end) return 0;
    if ((vector.end - vector.begin) % sizeof(uintptr_t) != 0) return 0;

    uintptr_t firstPlayer = 0;
    if (!EIDRunResetRead(vector.begin, &firstPlayer, sizeof(firstPlayer))) return 0;
    return firstPlayer;
}

static void EIDResetTransformationTracker(NSString *reason) {
    Class trackerClass = NSClassFromString(@"EIDTransformationProgress");
    SEL sharedSEL = NSSelectorFromString(@"shared");
    SEL resetSEL = NSSelectorFromString(@"resetForNewRun");
    if (!trackerClass || ![trackerClass respondsToSelector:sharedSEL]) return;
    id (*sendShared)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id tracker = sendShared(trackerClass, sharedSEL);
    if (!tracker || ![tracker respondsToSelector:resetSEL]) return;
    void (*sendReset)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    sendReset(tracker, resetSEL);
    EIDLog(@"transformation progress reset: %@", reason);
}

@interface NSObject (EIDCardFrameFix)
- (UIImage *)eid_anm2_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
- (void)eid_runreset_updateMenuModeForGameplay:(BOOL)gameplayActive;
@end

@implementation NSObject (EIDCardFrameFix)
- (UIImage *)eid_anm2_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    if (variant == EIDPickupVariantCard && subtype > 0) {
        // EIDPocketArtworkFix currently converts its input with `subtype - 1`.
        // Passing subtype + 1 makes its array index equal the actual ANM2 frame.
        return [self eid_anm2_pocketIconForVariant:variant subtype:subtype + 1];
    }
    return [self eid_anm2_pocketIconForVariant:variant subtype:subtype];
}

- (void)eid_runreset_updateMenuModeForGameplay:(BOOL)gameplayActive {
    static uintptr_t lastRunIdentity = 0;
    static BOOL sawInactiveSinceRun = YES;

    if (!gameplayActive) {
        sawInactiveSinceRun = YES;
    } else {
        id probe = nil;
        @try { probe = [self valueForKey:@"probe"]; }
        @catch (__unused NSException *exception) {}
        uintptr_t identity = EIDCurrentRunIdentity(probe);
        if (identity) {
            BOOL changedIdentity = lastRunIdentity && identity != lastRunIdentity;
            BOOL restartedAfterInactive = sawInactiveSinceRun && lastRunIdentity != 0;
            if (changedIdentity || restartedAfterInactive) {
                EIDResetTransformationTracker(changedIdentity ? @"native run identity changed"
                                                              : @"gameplay restarted after menu/death");
            }
            lastRunIdentity = identity;
            sawInactiveSinceRun = NO;
        }
    }

    [self eid_runreset_updateMenuModeForGameplay:gameplayActive];
}
@end

__attribute__((constructor)) static void EIDInstallCardFrameFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;

        SEL cardReplacementSEL = @selector(eid_anm2_pocketIconForVariant:subtype:);
        Method cardSource = class_getInstanceMethod(NSObject.class, cardReplacementSEL);
        if (cardSource) {
            class_addMethod(cls, cardReplacementSEL, method_getImplementation(cardSource), method_getTypeEncoding(cardSource));
            Method cardOriginal = class_getInstanceMethod(cls, NSSelectorFromString(@"pocketIconForVariant:subtype:"));
            Method cardReplacement = class_getInstanceMethod(cls, cardReplacementSEL);
            if (cardOriginal && cardReplacement) method_exchangeImplementations(cardOriginal, cardReplacement);
        }

        SEL resetReplacementSEL = @selector(eid_runreset_updateMenuModeForGameplay:);
        Method resetSource = class_getInstanceMethod(NSObject.class, resetReplacementSEL);
        if (resetSource) {
            class_addMethod(cls, resetReplacementSEL, method_getImplementation(resetSource), method_getTypeEncoding(resetSource));
            Method resetOriginal = class_getInstanceMethod(cls, NSSelectorFromString(@"updateMenuModeForGameplay:"));
            Method resetReplacement = class_getInstanceMethod(cls, resetReplacementSEL);
            if (resetOriginal && resetReplacement) method_exchangeImplementations(resetOriginal, resetReplacement);
        }
    });
}
