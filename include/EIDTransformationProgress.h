#import <Foundation/Foundation.h>

@class EIDNativeProbe;

NS_ASSUME_NONNULL_BEGIN

@interface EIDTransformationProgress : NSObject
@property(nonatomic, weak, nullable) EIDNativeProbe *probe;
@property(nonatomic, readonly) NSInteger required;
+ (instancetype)shared;
- (NSArray<NSNumber *> *)allTransformationIdentifiers;
- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible;
- (NSArray<NSNumber *> *)transformationsForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
- (NSInteger)progressForTransformation:(NSInteger)transformation;
- (NSString *)progressSignatureForPickups:(NSArray *)pickups;
- (NSString *)localizedNameForTransformation:(NSInteger)transformation;
- (NSString *)englishNameForTransformation:(NSInteger)transformation;
@end

NS_ASSUME_NONNULL_END
