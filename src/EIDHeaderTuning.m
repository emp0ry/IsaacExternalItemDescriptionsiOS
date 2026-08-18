#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdlib.h>

static UIImage *EIDTrimTransparentPadding(UIImage *image) {
    CGImageRef cg = image.CGImage;
    if (!cg) return image;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    if (!width || !height) return image;

    size_t bytesPerRow = width * 4;
    unsigned char *pixels = calloc(height, bytesPerRow);
    if (!pixels) return image;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) { free(pixels); return image; }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cg);
    CGContextRelease(context);

    size_t minX = width, minY = height, maxX = 0, maxY = 0;
    BOOL found = NO;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            unsigned char alpha = pixels[y * bytesPerRow + x * 4 + 3];
            if (alpha > 8) {
                found = YES;
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
            }
        }
    }
    free(pixels);
    if (!found) return image;

    minX = minX > 1 ? minX - 1 : 0;
    minY = minY > 1 ? minY - 1 : 0;
    maxX = MIN(width - 1, maxX + 1);
    maxY = MIN(height - 1, maxY + 1);
    CGRect rect = CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1);
    CGImageRef cropped = CGImageCreateWithImageInRect(cg, rect);
    if (!cropped) return image;
    UIImage *result = [UIImage imageWithCGImage:cropped scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cropped);
    return result;
}

@interface NSObject (EIDHeaderTuning)
- (void)eid_tuned_renderPickups:(NSArray *)pickups;
@end

@implementation NSObject (EIDHeaderTuning)
- (void)eid_tuned_renderPickups:(NSArray *)pickups {
    [self eid_tuned_renderPickups:pickups];

    UILabel *label = [self valueForKey:@"label"];
    if (![label isKindOfClass:UILabel.class] || !label.attributedText.length) return;

    NSMutableAttributedString *text = [label.attributedText mutableCopy];
    NSRange firstNewline = [text.string rangeOfString:@"\n"];
    NSUInteger headerLength = firstNewline.location == NSNotFound ? text.length : firstNewline.location;
    if (!headerLength) return;

    CGFloat scale = [[NSUserDefaults standardUserDefaults] objectForKey:@"IsaacEIDScale"]
        ? [[NSUserDefaults standardUserDefaults] doubleForKey:@"IsaacEIDScale"] : 1.0;
    scale = MIN(1.8, MAX(0.5, scale));

    UIFont *headerFont = [UIFont systemFontOfSize:22.0 * scale weight:UIFontWeightHeavy];
    [text addAttribute:NSFontAttributeName value:headerFont range:NSMakeRange(0, headerLength)];

    __block NSUInteger attachmentIndex = 0;
    [text enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, text.length)
                     options:0
                  usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
        (void)stop;
        if (![attachment isKindOfClass:NSTextAttachment.class]) return;
        attachmentIndex++;

        if (attachmentIndex == 1) {
            UIImage *trimmed = EIDTrimTransparentPadding(attachment.image);
            attachment.image = trimmed;
            CGFloat visibleHeight = 32.0 * scale;
            CGFloat ratio = trimmed.size.height > 0 ? trimmed.size.width / trimmed.size.height : 1.0;
            attachment.bounds = CGRectMake(0, -7.0 * scale, visibleHeight * ratio, visibleHeight);
        } else if (attachmentIndex == 2 && range.location < headerLength) {
            UIImage *quality = attachment.image;
            CGFloat h = 11.5 * scale;
            CGFloat ratio = quality.size.height > 0 ? quality.size.width / quality.size.height : 1.0;
            attachment.bounds = CGRectMake(0, -1.0 * scale, h * ratio, h);
        } else {
            UIImage *icon = attachment.image;
            CGFloat h = 15.5 * scale;
            CGFloat ratio = icon.size.height > 0 ? icon.size.width / icon.size.height : 1.0;
            attachment.bounds = CGRectMake(0, -2.5 * scale, h * ratio, h);
        }
    }];

    NSMutableParagraphStyle *headerParagraph = [[NSMutableParagraphStyle alloc] init];
    headerParagraph.minimumLineHeight = 32.0 * scale;
    headerParagraph.maximumLineHeight = 32.0 * scale;
    headerParagraph.paragraphSpacing = 8.0 * scale;
    NSUInteger headerRangeLength = MIN(text.length, headerLength + (firstNewline.location == NSNotFound ? 0 : 1));
    [text addAttribute:NSParagraphStyleAttributeName value:headerParagraph range:NSMakeRange(0, headerRangeLength)];

    label.attributedText = text;
    SEL sizeSelector = NSSelectorFromString(@"sizePanelForText");
    if ([self respondsToSelector:sizeSelector]) {
        ((void (*)(id, SEL))objc_msgSend)(self, sizeSelector);
    }
}
@end

static void EIDApplyHeaderTuningSwizzle(void) {
    Class cls = NSClassFromString(@"EIDOverlayController");
    if (!cls) return;
    SEL tunedSelector = @selector(eid_tuned_renderPickups:);
    Method source = class_getInstanceMethod(NSObject.class, tunedSelector);
    if (!source) return;
    class_addMethod(cls, tunedSelector, method_getImplementation(source), method_getTypeEncoding(source));
    Method original = class_getInstanceMethod(cls, NSSelectorFromString(@"renderPickups:"));
    Method tuned = class_getInstanceMethod(cls, tunedSelector);
    if (original && tuned) method_exchangeImplementations(original, tuned);
}

__attribute__((constructor)) static void EIDInstallHeaderTuning(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        EIDApplyHeaderTuningSwizzle();
    });
}
