#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EIDPickupVariant) {
    EIDPickupVariantPill = 70,
    EIDPickupVariantCollectible = 100,
    EIDPickupVariantCard = 300,
    EIDPickupVariantTrinket = 350,
    // Internal display variant. Native pickups still use variant 70 with bit 11 set.
    EIDPickupVariantHorsePill = 1070,
};

@interface EIDPickupIdentity : NSObject
@property(nonatomic, readonly) NSInteger variant;
@property(nonatomic, readonly) NSInteger subtype;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype;
@end

@interface EIDNativeProbe : NSObject
@property(nonatomic, copy, readonly) NSString *executableUUID;
@property(nonatomic, copy, readonly) NSString *status;
@property(nonatomic, readonly, getter=isSupportedBuild) BOOL supportedBuild;
- (void)start;
- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups;
// Compatibility API used by early integrations and exported diagnostic helpers.
- (NSArray<NSNumber *> *)currentCollectibleIDs;
@end

NS_ASSUME_NONNULL_END
