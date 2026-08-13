#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EIDDescription : NSObject
@property(nonatomic, readonly) NSInteger collectibleID;
@property(nonatomic, readonly) NSInteger pickupVariant;
@property(nonatomic, readonly) NSInteger pickupSubtype;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *detail;
@property(nonatomic, copy, readonly, nullable) NSString *iconPath;
- (instancetype)initWithCollectibleID:(NSInteger)collectibleID
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath;
- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(nullable NSString *)iconPath;
@end

@interface EIDDescriptionStore : NSObject
@property(nonatomic, readonly) NSUInteger collectibleCount;
@property(nonatomic, readonly) NSUInteger trinketCount;
@property(nonatomic, readonly) NSUInteger cardCount;
@property(nonatomic, copy, readonly) NSString *languageCode;
- (void)reload;
- (void)setLanguageCode:(NSString *)languageCode;
- (nullable EIDDescription *)descriptionForCollectibleID:(NSInteger)collectibleID;
- (nullable EIDDescription *)descriptionForPickupVariant:(NSInteger)variant
                                                  subtype:(NSInteger)subtype;
@end

NS_ASSUME_NONNULL_END
