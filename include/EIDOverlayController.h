#import <Foundation/Foundation.h>

@class EIDDescriptionStore;
@class EIDNativeProbe;

NS_ASSUME_NONNULL_BEGIN

@interface EIDOverlayController : NSObject
- (instancetype)initWithStore:(EIDDescriptionStore *)store probe:(EIDNativeProbe *)probe;
- (void)start;
- (void)showCollectibleID:(NSInteger)collectibleID;
- (void)setDiagnosticsEnabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END
