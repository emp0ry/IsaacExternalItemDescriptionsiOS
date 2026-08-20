#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EIDPickupVariant) {
    EIDPickupVariantPill = 70,
    EIDPickupVariantCollectible = 100,
    EIDPickupVariantCard = 300,
    EIDPickupVariantTrinket = 350,
    // Internal display variant. Native pickups still use variant 70 with bit 11 set.
    EIDPickupVariantHorsePill = 1070,
    // Internal display variants for native room entities.
    EIDPickupVariantDiceRoom = 2001,
    EIDPickupVariantSacrificeRoom = 2002,
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
@property(atomic, readonly, getter=isGameplayActive) BOOL gameplayActive;
@property(atomic, readonly, getter=isPauseStateAvailable) BOOL pauseStateAvailable;
@property(atomic, readonly, getter=isPaused) BOOL paused;
@property(atomic, readonly) uint32_t runSeed;
@property(atomic, readonly) NSUInteger runCounter;
@property(atomic, readonly, getter=isOwnedCollectibleStateAvailable) BOOL ownedCollectibleStateAvailable;
@property(atomic, readonly, getter=isInventoryStateAvailable) BOOL inventoryStateAvailable;
@property(atomic, readonly, getter=isTransformationStateAvailable) BOOL transformationStateAvailable;
@property(atomic, readonly, getter=isSuperBumActive) BOOL superBumActive;
- (void)start;
- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups;
- (NSArray<EIDPickupIdentity *> *)currentInventoryItems;
- (NSInteger)ownedCollectibleCountForID:(NSInteger)collectibleID;
- (NSInteger)transformationCollectibleCountForID:(NSInteger)collectibleID;
- (NSInteger)nativeTransformationCounterForFormID:(NSInteger)formID;
// Compatibility API used by early integrations and exported diagnostic helpers.
- (NSArray<NSNumber *> *)currentCollectibleIDs;
@end

NS_ASSUME_NONNULL_END
