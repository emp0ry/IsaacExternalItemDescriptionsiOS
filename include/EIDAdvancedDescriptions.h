#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Pure presentation: consumes immutable native snapshots; never invokes game RNG.
FOUNDATION_EXPORT NSString *EIDAdvancedDescription(NSString *detail, NSInteger variant,
    NSInteger subtype, NSInteger difficulty, NSSet<NSString *> *owned, NSDictionary *context);
NS_ASSUME_NONNULL_END
