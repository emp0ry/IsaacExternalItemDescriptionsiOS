#import <UIKit/UIKit.h>
@class EIDDescription, EIDPickupIdentity, EIDDescriptionStore;

FOUNDATION_EXPORT BOOL EIDRenderOriginalDescription(id controller, EIDDescription *item, EIDPickupIdentity *pickup,
    EIDDescriptionStore *store, NSString *detail, NSArray<NSDictionary *> *transformations,
    UIImage *image, NSArray<NSString *> *roots, CGFloat scale, CGFloat alpha,
    BOOL showName, BOOL showQuality, BOOL showDetail);
FOUNDATION_EXPORT void EIDHideOriginalDescription(id controller);
FOUNDATION_EXPORT BOOL EIDRenderOriginalCounter(UILabel *label, NSString *text, CGFloat scale);
