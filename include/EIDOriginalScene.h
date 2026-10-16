#import "EIDBitmapFont.h"

@interface EIDOriginalSprite : NSObject
@property(nonatomic,strong) EIDRaster *raster;
@property(nonatomic) CGRect rect;
@property(nonatomic) CGFloat advance,height,offsetX,offsetY;
@end

typedef EIDOriginalSprite *(^EIDOriginalIconResolver)(NSString *token);
typedef NSString *(^EIDOriginalNameResolver)(NSString *token);

// Immutable layout and original font drawing shared by iOS and host previews.
@interface EIDOriginalScene : NSObject
@property(nonatomic,readonly) EIDBitmapFont *font;
@property(nonatomic,readonly) CGRect bounds;
@property(nonatomic,readonly) NSUInteger operationCount;
@property(nonatomic,readonly) BOOL animated;
@property(nonatomic) BOOL unidentifiedPill;
@property(nonatomic) BOOL statChangeIcons;
@property(nonatomic) CGFloat widthMultiplier;
@property(nonatomic,readonly) CGFloat defaultTextWidth;
- (instancetype)initWithRoot:(NSString *)root language:(NSString *)language
                 iconResolver:(EIDOriginalIconResolver)icons nameResolver:(EIDOriginalNameResolver)names;
- (EIDOriginalSprite *)sprite:(NSString *)token;
- (EIDOriginalSprite *)animation:(NSString *)animation sheet:(NSString *)sheet frame:(NSInteger)frame;
- (void)layoutName:(NSString *)name detail:(NSString *)detail icon:(EIDOriginalSprite *)icon
         itemType:(NSInteger)itemType chargeType:(NSInteger)chargeType charges:(NSInteger)charges
          quality:(NSInteger)quality transformations:(NSArray<NSDictionary *> *)transformations
         showName:(BOOL)showName showQuality:(BOOL)showQuality showDetail:(BOOL)showDetail;
- (void)drawInContext:(CGContextRef)context frame:(NSUInteger)frame;
- (NSArray<NSString *> *)wrappedLines:(NSString *)text;
@end
