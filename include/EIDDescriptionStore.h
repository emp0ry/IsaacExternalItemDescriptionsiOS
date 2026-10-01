#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EIDCollectibleItemType) {
    EIDCollectibleItemTypeUnknown = 0,
    EIDCollectibleItemTypePassive = 1,
    EIDCollectibleItemTypeActive = 2,
    EIDCollectibleItemTypeFamiliar = 3,
};

typedef NS_ENUM(NSInteger, EIDActiveChargeType) {
    EIDActiveChargeTypeNormal = 0,
    EIDActiveChargeTypeTimed = 1,
    EIDActiveChargeTypeSpecial = 2,
};

@interface EIDDescription : NSObject
@property(nonatomic, readonly) NSInteger collectibleID;
@property(nonatomic, readonly) NSInteger pickupVariant;
@property(nonatomic, readonly) NSInteger pickupSubtype;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *detail;
@property(nonatomic, copy, readonly, nullable) NSString *iconPath;
@property(nonatomic, readonly) NSInteger quality;
@property(nonatomic, readonly) EIDCollectibleItemType itemType;
@property(nonatomic, readonly) NSInteger maxCharges;
@property(nonatomic, readonly) EIDActiveChargeType chargeType;
- (instancetype)initWithCollectibleID:(NSInteger)collectibleID
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath;
- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath;
- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath
                               quality:(NSInteger)quality;
- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath
                               quality:(NSInteger)quality
                              itemType:(EIDCollectibleItemType)itemType
                            maxCharges:(NSInteger)maxCharges
                            chargeType:(EIDActiveChargeType)chargeType;
@end

@interface EIDDescriptionStore : NSObject
@property(nonatomic, readonly) NSUInteger collectibleCount;
@property(nonatomic, readonly) NSUInteger trinketCount;
@property(nonatomic, readonly) NSUInteger cardCount;
@property(nonatomic, readonly) NSUInteger pillCount;
@property(nonatomic, readonly) NSUInteger horsePillCount;
@property(nonatomic, copy, readonly) NSString *languageCode;
@property(nonatomic, copy, readonly) NSArray<NSString *> *availableLanguageCodes;
@property(nonatomic, copy, readonly) NSString *descriptionDataSet;
- (void)reload;
- (void)setLanguageCode:(NSString *)languageCode;
- (NSString *)displayNameForLanguageCode:(NSString *)languageCode;
- (nullable EIDDescription *)descriptionForCollectibleID:(NSInteger)collectibleID;
- (nullable EIDDescription *)descriptionForPickupVariant:(NSInteger)variant
                                                  subtype:(NSInteger)subtype;
@end

NS_ASSUME_NONNULL_END
