#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#ifdef __cplusplus
#include "EIDBMFont.hpp"
#endif

@interface EIDRaster : NSObject
@property(nonatomic,readonly) CGImageRef image;
- (instancetype)initWithImage:(CGImageRef)image;
+ (instancetype)load:(NSString *)path;
@end

void EIDDrawRaster(CGContextRef context, CGImageRef image, CGRect rect);

@interface EIDBitmapFont : NSObject
@property(nonatomic,readonly) CGFloat lineHeight;
- (instancetype)initWithPath:(NSString *)path;
- (CGFloat)width:(NSString *)text;
- (void)draw:(NSString *)text at:(CGPoint)position color:(CGColorRef)color context:(CGContextRef)context;
#ifdef __cplusplus
- (const EIDBitmap::Font &)metrics;
#endif
@end
