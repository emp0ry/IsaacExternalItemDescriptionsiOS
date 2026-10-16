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
// A negative result means the selected player's state is unavailable. Never
// substitute a partner's counter in the pause inventory or floor description.
- (NSInteger)progressForTransformation:(NSInteger)transformation playerIndex:(NSInteger)playerIndex;
- (NSString *)progressSignatureForPickups:(NSArray *)pickups;
- (NSString *)localizedNameForTransformation:(NSInteger)transformation;
- (NSString *)englishNameForTransformation:(NSInteger)transformation;
@end

NS_ASSUME_NONNULL_END
