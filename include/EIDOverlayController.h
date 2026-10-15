#import <Foundation/Foundation.h>

@class EIDDescriptionStore;
@class EIDNativeProbe;
@class EIDPickupIdentity;

NS_ASSUME_NONNULL_BEGIN

@interface EIDOverlayController : NSObject
- (instancetype)initWithStore:(EIDDescriptionStore *)store probe:(EIDNativeProbe *)probe;
- (void)start;
- (void)showCollectibleID:(NSInteger)collectibleID;
- (void)setDiagnosticsEnabled:(BOOL)enabled;
// Shared with the parity renderer; these never change native gameplay state.
- (nullable EIDPickupIdentity *)prepareCollectibleCycleIdentity:(nullable EIDPickupIdentity *)identity;
- (void)updateCollectibleCycleControls;
- (CGFloat)collectibleCycleHeaderInset;
@end

NS_ASSUME_NONNULL_END
