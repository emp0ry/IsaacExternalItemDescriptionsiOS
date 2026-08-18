#import "EIDNativeProbe.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ui_cardspills.anm2 CardFronts contains an invisible frame 0.
// Isaac's Card enum/subtype is intentionally used as the ANM2 frame number:
// subtype 1 -> frame 1, subtype 2 -> frame 2, etc. This also covers runes
// because they are part of the same CardFronts animation.
@interface NSObject (EIDCardFrameFix)
- (UIImage *)eid_anm2_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
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
@end

__attribute__((constructor)) static void EIDInstallCardFrameFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;
        SEL replacementSEL = @selector(eid_anm2_pocketIconForVariant:subtype:);
        Method source = class_getInstanceMethod(NSObject.class, replacementSEL);
        if (!source) return;
        class_addMethod(cls, replacementSEL, method_getImplementation(source), method_getTypeEncoding(source));
        Method original = class_getInstanceMethod(cls, NSSelectorFromString(@"pocketIconForVariant:subtype:"));
        Method replacement = class_getInstanceMethod(cls, replacementSEL);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}
