#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdlib.h>

static const void *EIDHeaderLabelKey = &EIDHeaderLabelKey;
static const void *EIDHeaderLogoKey = &EIDHeaderLogoKey;

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

static UILabel *EIDHeaderLabelForController(id controller, UIView *panel) {
    UILabel *header = objc_getAssociatedObject(controller, EIDHeaderLabelKey);
    if (header) return header;
    header = [[UILabel alloc] initWithFrame:CGRectZero];
    header.numberOfLines = 1;
    header.backgroundColor = UIColor.clearColor;
    header.adjustsFontSizeToFitWidth = NO;
    header.lineBreakMode = NSLineBreakByClipping;
    header.userInteractionEnabled = NO;
    header.shadowColor = [UIColor colorWithWhite:0 alpha:0.95];
    header.shadowOffset = CGSizeMake(1, 1);
    [panel addSubview:header];
    objc_setAssociatedObject(controller, EIDHeaderLabelKey, header, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return header;
}

static UIImageView *EIDHeaderLogoForController(id controller, UIView *panel) {
    UIImageView *logo = objc_getAssociatedObject(controller, EIDHeaderLogoKey);
    if (logo) return logo;
    logo = [[UIImageView alloc] initWithFrame:CGRectZero];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.layer.magnificationFilter = kCAFilterNearest;
    logo.layer.minificationFilter = kCAFilterNearest;
    logo.userInteractionEnabled = NO;
    [panel addSubview:logo];
    objc_setAssociatedObject(controller, EIDHeaderLogoKey, logo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return logo;
}

@interface NSObject (EIDHeaderTuning)
- (void)eid_tuned_renderPickups:(NSArray *)pickups;
@end

@implementation NSObject (EIDHeaderTuning)
- (void)eid_tuned_renderPickups:(NSArray *)pickups {
    [self eid_tuned_renderPickups:pickups];

    UILabel *bodyLabel = [self valueForKey:@"label"];
    UIView *panel = [self valueForKey:@"panel"];
    if (![bodyLabel isKindOfClass:UILabel.class] || ![panel isKindOfClass:UIView.class] || !bodyLabel.attributedText.length) return;

    NSAttributedString *rendered = bodyLabel.attributedText;
    NSRange newline = [rendered.string rangeOfString:@"\n"];
    NSUInteger headerLength = newline.location == NSNotFound ? rendered.length : newline.location;
    if (!headerLength) return;

    CGFloat scale = [[NSUserDefaults standardUserDefaults] objectForKey:@"IsaacEIDScale"]
        ? [[NSUserDefaults standardUserDefaults] doubleForKey:@"IsaacEIDScale"] : 1.0;
    scale = MIN(1.8, MAX(0.5, scale));

    NSMutableAttributedString *headerText = [[rendered attributedSubstringFromRange:NSMakeRange(0, headerLength)] mutableCopy];

    __block NSTextAttachment *itemAttachment = nil;
    __block NSRange itemAttachmentRange = NSMakeRange(NSNotFound, 0);
    [headerText enumerateAttribute:NSAttachmentAttributeName
                          inRange:NSMakeRange(0, headerText.length)
                          options:0
                       usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
        if ([attachment isKindOfClass:NSTextAttachment.class]) {
            itemAttachment = attachment;
            itemAttachmentRange = range;
            *stop = YES;
        }
    }];

    UIImageView *logo = EIDHeaderLogoForController(self, panel);
    CGFloat logoSize = 22.0 * scale;
    CGFloat textInset = 27.0 * scale;
    if (itemAttachment && itemAttachment.image) {
        logo.image = EIDTrimTransparentPadding(itemAttachment.image);
        logo.hidden = NO;
        logo.frame = CGRectMake(0, 0, logoSize, logoSize);

        NSUInteger removeStart = itemAttachmentRange.location;
        NSUInteger removeEnd = NSMaxRange(itemAttachmentRange);
        while (removeEnd < headerText.length && [[headerText.string substringWithRange:NSMakeRange(removeEnd, 1)] isEqualToString:@" "]) removeEnd++;
        [headerText deleteCharactersInRange:NSMakeRange(removeStart, removeEnd - removeStart)];
    } else {
        logo.hidden = YES;
        textInset = 0;
    }

    UIFont *titleFont = [UIFont systemFontOfSize:16.0 * scale weight:UIFontWeightBold];
    [headerText addAttribute:NSFontAttributeName value:titleFont range:NSMakeRange(0, headerText.length)];

    [headerText enumerateAttribute:NSAttachmentAttributeName
                          inRange:NSMakeRange(0, headerText.length)
                          options:0
                       usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
        (void)range; (void)stop;
        if (![attachment isKindOfClass:NSTextAttachment.class]) return;
        UIImage *quality = attachment.image;
        CGFloat h = 16.0 * scale;
        CGFloat ratio = quality.size.height > 0 ? quality.size.width / quality.size.height : 1.0;
        attachment.bounds = CGRectMake(0, -3.0 * scale, h * ratio, h);
    }];

    UILabel *headerLabel = EIDHeaderLabelForController(self, panel);
    headerLabel.attributedText = headerText;

    CGFloat headerHeight = 23.0 * scale;
    CGFloat gap = 5.0 * scale;
    CGFloat textWidth = MAX(1, panel.bounds.size.width - textInset);
    headerLabel.frame = CGRectMake(textInset, 0, textWidth, headerHeight);

    if (newline.location != NSNotFound && NSMaxRange(newline) < rendered.length) {
        NSAttributedString *body = [rendered attributedSubstringFromRange:NSMakeRange(NSMaxRange(newline), rendered.length - NSMaxRange(newline))];
        bodyLabel.attributedText = body;
    } else {
        bodyLabel.attributedText = nil;
    }

    CGSize bodySize = [bodyLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    CGRect panelFrame = panel.frame;
    panelFrame.size.height = headerHeight + gap + MAX(1, ceil(bodySize.height));
    panel.frame = panelFrame;

    logo.frame = CGRectMake(0, 0, logoSize, logoSize);
    headerLabel.frame = CGRectMake(textInset, 0, textWidth, headerHeight);
    bodyLabel.frame = CGRectMake(textInset, headerHeight + gap, textWidth, MAX(1, ceil(bodySize.height)));
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
