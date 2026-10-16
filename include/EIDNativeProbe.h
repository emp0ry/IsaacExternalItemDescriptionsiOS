#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EIDPickupVariant) {
    EIDPickupVariantPill = 70,
    EIDPickupVariantCollectible = 100,
    EIDPickupVariantCard = 300,
    EIDPickupVariantTrinket = 350,
    // Internal display variant. Native pickups still use variant 70 with bit 11 set.
    EIDPickupVariantHorsePill = 1070,
    // Internal display variant. Subtype preserves the native PillColor for artwork,
    // while the description store exposes no effect information.
    EIDPickupVariantUnidentifiedPill = 2070,
    // Internal display variants for native room entities.
    EIDPickupVariantDiceRoom = 2001,
    EIDPickupVariantSacrificeRoom = 2002,
};

@interface EIDPickupIdentity : NSObject
@property(nonatomic, readonly) NSInteger variant;
@property(nonatomic, readonly) NSInteger subtype;
// Native character closest to this pickup, or -1 when unavailable.
@property(nonatomic, readonly) NSInteger playerType;
@property(nonatomic, readonly) NSInteger playerIndex;
// Original native color/horse bit, independent of the player-adjusted effect.
@property(nonatomic, readonly) NSInteger rawPillSubtype;
// Fresh native HasCollectible flags used for this exact effect query. -1 when
// unavailable, zero when none are owned; see EIDPillPolicy.h.
@property(nonatomic, readonly) NSInteger pillModifiers;
@property(nonatomic, copy, readonly) NSDictionary *pickupContext;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype pillModifiers:(NSInteger)pillModifiers;
- (instancetype)initWithVariant:(NSInteger)variant subtype:(NSInteger)subtype
                      playerType:(NSInteger)playerType playerIndex:(NSInteger)playerIndex
                  rawPillSubtype:(NSInteger)rawPillSubtype pillModifiers:(NSInteger)pillModifiers
                   pickupContext:(NSDictionary *)pickupContext;
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
@property(atomic, readonly) NSInteger primaryPlayerType;
// 0 normal, 1 hard, 2 Greed, 3 Greedier; -1 when unavailable.
@property(atomic, readonly) NSInteger gameDifficulty;
@property(atomic, copy, readonly) NSDictionary *descriptionState;
@property(atomic, readonly, getter=isOwnedCollectibleStateAvailable) BOOL ownedCollectibleStateAvailable;
@property(atomic, readonly, getter=isInventoryStateAvailable) BOOL inventoryStateAvailable;
@property(atomic, readonly, getter=isTransformationStateAvailable) BOOL transformationStateAvailable;
@property(atomic, readonly, getter=isSuperBumActive) BOOL superBumActive;
- (void)start;
- (NSArray<EIDPickupIdentity *> *)currentDescribablePickups;
- (NSArray<EIDPickupIdentity *> *)currentInventoryItems;
- (NSArray<EIDPickupIdentity *> *)currentSmeltedTrinkets;
- (NSArray<EIDPickupIdentity *> *)currentVoidedItems;
// Main-thread-only, read-only native GetPillEffect adapter. Revalidates the live
// player vector; never invokes game code from the background memory scanner.
- (EIDPickupIdentity *)resolvedPillIdentity:(EIDPickupIdentity *)identity;
// Main-thread-only native Spindown availability query. It uses the same flags
// as the real iOS item effect; collection-page flags are not unlock state.
- (EIDPickupIdentity *)resolvedSpindownIdentity:(EIDPickupIdentity *)identity;
// Main-thread-only, read-only native Wild Card / Vurp history. Does not run
// either effect, consume RNG, or infer use from pocket inventory changes.
- (EIDPickupIdentity *)resolvedRepeatIdentity:(EIDPickupIdentity *)identity;
// Main-thread revalidation of the current pedestal, independent of Crown's
// cycle browser. Returns nil for removed, reused, stale-room or hidden objects.
- (nullable EIDPickupIdentity *)resolvedLivePedestalIdentity:(EIDPickupIdentity *)identity;
// Main-thread snapshot of a validated visible pedestal's native collectible
// cycle. No effect call, RNG advance or temporal sampling is involved.
- (EIDPickupIdentity *)resolvedCollectibleCycleIdentity:(EIDPickupIdentity *)identity;
// Read-only main-thread inventory/history adapters for The Stars? and Black
// Feather. Metadata contains only the bounded upstream Black Feather ID lists.
- (EIDPickupIdentity *)resolvedInventoryPreviewIdentity:(EIDPickupIdentity *)identity
                                blackFeatherMetadata:(NSDictionary *)metadata;
// Paused inventory only: read the game's already cached Bag of Crafting result.
// Never calls crafting, modifies ingredients, advances RNG or adds ownership.
- (EIDPickupIdentity *)resolvedCraftingIdentity:(EIDPickupIdentity *)identity;
// Current (already applied) Modeling Clay effect in the selected player's
// pause inventory. Never rolls or applies a temporary effect.
- (EIDPickupIdentity *)resolvedCurrentEffectIdentity:(EIDPickupIdentity *)identity;
// Optional, read-only next-outcome previews. Copies RNG state; never calls an
// item effect or native RNG. Eternal D6 is one reroll, not a future-use count.
- (EIDPickupIdentity *)resolvedOutcomeIdentity:(EIDPickupIdentity *)identity
                             insideInventory:(BOOL)insideInventory enabled:(BOOL)enabled;
// Normalized collectible/trinket identities for conditional descriptions.
- (NSSet<NSString *> *)currentOwnedItemKeys;
- (NSInteger)ownedCollectibleCountForID:(NSInteger)collectibleID;
- (NSInteger)transformationCollectibleCountForID:(NSInteger)collectibleID;
- (NSInteger)nativeTransformationCounterForFormID:(NSInteger)formID;
// Compatibility API used by early integrations and exported diagnostic helpers.
- (NSArray<NSNumber *> *)currentCollectibleIDs;
@end

NS_ASSUME_NONNULL_END
