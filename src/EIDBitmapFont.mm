#import "EIDBitmapFont.h"
#import <ImageIO/ImageIO.h>
#include <cmath>

@implementation EIDRaster { CGImageRef _image; }
- (instancetype)initWithImage:(CGImageRef)image {
    if (!(self=[super init]) || !image) return nil;
    _image=CGImageRetain(image); return self;
}
- (void)dealloc { CGImageRelease(_image); }
- (CGImageRef)image { return _image; }
+ (instancetype)load:(NSString *)path {
    if (!path.length) return nil;
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],nullptr);
    if (!source) return nil;
    CGImageRef image=CGImageSourceCreateImageAtIndex(source,0,nullptr); CFRelease(source);
    EIDRaster *result=image?[[self alloc] initWithImage:image]:nil;
    if (image) CGImageRelease(image); return result;
}
@end

void EIDDrawRaster(CGContextRef context, CGImageRef image, CGRect rect) {
    if (!context || !image || rect.size.width<=0 || rect.size.height<=0) return;
    CGContextSaveGState(context);
    CGContextSetInterpolationQuality(context,kCGInterpolationNone);
    CGContextSetShouldAntialias(context,false);
    CGContextTranslateCTM(context,rect.origin.x,rect.origin.y+rect.size.height);
    CGContextScaleCTM(context,1,-1);
    CGContextDrawImage(context,CGRectMake(0,0,rect.size.width,rect.size.height),image);
    CGContextRestoreGState(context);
}

@implementation EIDBitmapFont {
    EIDBitmap::Font _metrics;
    NSArray<EIDRaster *> *_pages;
    NSCache<NSString *,EIDRaster *> *_glyphs;
}
- (instancetype)initWithPath:(NSString *)path {
    if (!(self=[super init])) return nil;
    NSData *data=path.length?[NSData dataWithContentsOfFile:path]:nil;
    if (!_metrics.Load((const uint8_t *)data.bytes,data.length)) return nil;
    NSMutableArray *pages=[NSMutableArray array];
    for (const std::string &name:_metrics.pages) {
        NSString *file=[[NSString alloc] initWithBytes:name.data() length:name.size() encoding:NSUTF8StringEncoding];
        EIDRaster *page=[EIDRaster load:[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:file]];
        // EID's Chinese fonts deliberately use a 16x16 fix page for the
        // one-pixel spacer and bullet next to a full-sized text atlas.
        if (!page || CGImageGetWidth(page.image)>_metrics.width || CGImageGetHeight(page.image)>_metrics.height) return nil;
        [pages addObject:page];
    }
    for (const auto &entry:_metrics.glyphs) {
        const EIDBitmap::Glyph &g=entry.second; CGImageRef page=[pages[g.page] image];
        if (uint32_t(g.x)+g.w>CGImageGetWidth(page) || uint32_t(g.y)+g.h>CGImageGetHeight(page)) return nil;
    }
    _pages=pages.copy; _glyphs=[NSCache new]; _glyphs.countLimit=4096; _glyphs.totalCostLimit=8*1024*1024;
    return self;
}
- (const EIDBitmap::Font &)metrics { return _metrics; }
- (CGFloat)lineHeight { return _metrics.lineHeight; }
- (CGFloat)width:(NSString *)text { return _metrics.Measure(text.UTF8String ?: ""); }
- (void)draw:(NSString *)text at:(CGPoint)position color:(CGColorRef)color context:(CGContextRef)context {
    if (!context || !color) return;
    const CGFloat *components=CGColorGetComponents(color);
    bool rgb=CGColorGetNumberOfComponents(color)>=4;
    int red=lround(components[0]*255),green=lround(components[rgb?1:0]*255),blue=lround(components[rgb?2:0]*255);
    CGFloat alpha=CGColorGetAlpha(color);
    std::string utf8=text.UTF8String ?: ""; uint32_t previous=0;
    CGFloat x=position.x;
    CGContextSaveGState(context); CGContextSetAlpha(context,alpha);
    for (size_t i=0;i<utf8.size();) {
        uint32_t code=EIDBitmap::Font::Next(utf8,i); const EIDBitmap::Glyph *g=_metrics.Find(code);
        if (!g) continue;
        x+=_metrics.Kerning(previous,code); previous=code;
        if (g->w && g->h) {
            NSString *key=[NSString stringWithFormat:@"%u:%d:%d:%d",code,red,green,blue];
            EIDRaster *glyph=[_glyphs objectForKey:key];
            if (!glyph) {
                CGImageRef crop=CGImageCreateWithImageInRect(_pages[g->page].image,CGRectMake(g->x,g->y,g->w,g->h));
                size_t count=size_t(g->w)*g->h*4; std::vector<uint8_t> pixels(count);
                CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
                CGContextRef bitmap=CGBitmapContextCreate(pixels.data(),g->w,g->h,8,g->w*4,space,
                    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big); CGColorSpaceRelease(space);
                if (bitmap && crop) {
                    CGContextDrawImage(bitmap,CGRectMake(0,0,g->w,g->h),crop);
                    // Multiply RGB, not the alpha mask: black atlas outlines stay black.
                    for (size_t k=0;k<count;k+=4) {
                        pixels[k]=pixels[k]*red/255; pixels[k+1]=pixels[k+1]*green/255; pixels[k+2]=pixels[k+2]*blue/255;
                    }
                    CGImageRef tinted=CGBitmapContextCreateImage(bitmap);
                    glyph=[[EIDRaster alloc] initWithImage:tinted]; CGImageRelease(tinted);
                    [_glyphs setObject:glyph forKey:key cost:count];
                }
                if (bitmap) CGContextRelease(bitmap); if (crop) CGImageRelease(crop);
            }
            EIDDrawRaster(context,glyph.image,CGRectMake(x+g->dx,position.y+g->dy,g->w,g->h));
        }
        x+=g->advance;
    }
    CGContextRestoreGState(context);
}
@end
