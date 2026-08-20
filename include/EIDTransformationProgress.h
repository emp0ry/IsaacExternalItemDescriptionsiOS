#import <Foundation/Foundation.h>

@class EIDNativeProbe;

NS_ASSUME_NONNULL_BEGIN

@interface EIDTransformationProgress : NSObject
@property(nonatomic, weak, nullable) EIDNativeProbe *probe;
@property(nonatomic, readonly) NSInteger required;
+ (instancetype)shared;
- (NSArray<NSNumber *> *)allTransformationIdentifiers;
- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible;
- (NSInteger)progressForTransformation:(NSInteger)transformation;
- (NSString *)localizedNameForTransformation:(NSInteger)transformation;
- (NSString *)englishNameForTransformation:(NSInteger)transformation;
@end

NS_ASSUME_NONNULL_END
