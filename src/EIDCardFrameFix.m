#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSArray<NSString *> *EIDCardBundleRoots(void) {
    NSString *main = NSBundle.mainBundle.bundlePath;
    NSMutableArray<NSString *> *roots = [NSMutableArray arrayWithArray:@[
        [main stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"IsaacEID.bundle"],
        [main stringByAppendingPathComponent:
            @"Frameworks/IsaacExternalItemDescriptions.framework/Resources/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:
            @"Frameworks/IsaacExternalItemDescriptions.framework/IsaacEID.bundle"],
        [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Application Support/IsaacExternalItemDescriptions"],
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",
        @"/Library/Application Support/IsaacExternalItemDescriptions"
    ]];
    NSBundle *framework = [NSBundle bundleForClass:NSClassFromString(@"EIDOverlayController")
                                                   ?: NSObject.class];
    if (framework.bundlePath.length) {
        [roots addObject:[framework.bundlePath stringByAppendingPathComponent:
                          @"Resources/IsaacEID.bundle"]];
        [roots addObject:[framework.bundlePath stringByAppendingPathComponent:@"IsaacEID.bundle"]];
        [roots addObject:framework.bundlePath];
    }
    return roots;
}

static NSString *EIDCardBundledResource(NSString *name) {
    for (NSString *root in EIDCardBundleRoots()) {
        NSString *path = [root stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

@interface EIDOriginalCardParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableArray *frames;
@property(nonatomic) BOOL readingCards;
@property(nonatomic) BOOL readingLayer;
@end

@implementation EIDOriginalCardParser
- (instancetype)init {
    if ((self = [super init])) _frames = [NSMutableArray array];
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
     attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"Animation"]) {
        self.readingCards = [attributes[@"Name"] isEqualToString:@"Cards"];
        self.readingLayer = NO;
    } else if ([elementName isEqualToString:@"LayerAnimation"] && self.readingCards) {
        self.readingLayer = [attributes[@"LayerId"] integerValue] == 0;
    } else if ([elementName isEqualToString:@"Frame"] && self.readingCards && self.readingLayer) {
        CGFloat x = [attributes[@"XCrop"] doubleValue];
        CGFloat y = [attributes[@"YCrop"] doubleValue];
        CGFloat width = [attributes[@"Width"] doubleValue];
        CGFloat height = [attributes[@"Height"] doubleValue];
        BOOL visible = ![attributes[@"Visible"] isEqualToString:@"false"];
        [self.frames addObject:(visible && width > 0 && height > 0)
            ? [NSValue valueWithCGRect:CGRectMake(x, y, width, height)] : NSNull.null];
    }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"LayerAnimation"]) self.readingLayer = NO;
    if ([elementName isEqualToString:@"Animation"]) self.readingCards = NO;
}
@end

@interface EIDOriginalRuneArtwork : NSObject
@property(nonatomic, strong) UIImage *atlas;
@property(nonatomic, copy) NSArray *frames;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, id> *cache;
+ (instancetype)shared;
- (UIImage *)imageForRuneSubtype:(NSInteger)subtype;
@end

@implementation EIDOriginalRuneArtwork
+ (instancetype)shared {
    static EIDOriginalRuneArtwork *resolver;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ resolver = [EIDOriginalRuneArtwork new]; });
    return resolver;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _cache = [NSMutableDictionary dictionary];
    NSString *png = EIDCardBundledResource(@"eid_cardspills.png");
    NSString *anm2 = EIDCardBundledResource(@"eid_cardspills.anm2");
    _atlas = png.length ? [UIImage imageWithContentsOfFile:png] : nil;
    NSData *data = anm2.length ? [NSData dataWithContentsOfFile:anm2] : nil;
    if (data.length) {
        EIDOriginalCardParser *delegate = [EIDOriginalCardParser new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = delegate;
        if ([parser parse]) _frames = delegate.frames.copy;
    }
    if (!_frames) _frames = @[];
    EIDLog(@"original EID rune artwork: atlas %@, card/rune frames %lu",
           _atlas ? @"yes" : @"no", (unsigned long)_frames.count);
    return self;
}
- (UIImage *)imageForRuneSubtype:(NSInteger)subtype {
    if (subtype < 32 || subtype > 41) return nil;
    NSNumber *key = @(subtype);
    id cached = self.cache[key];
    if (cached) return cached == NSNull.null ? nil : cached;

    // Original EID renders Card IDs with frame `cardID - 1`. The previous iOS
    // adapter applied the native CardFronts offset to runes as well, which sent
    // them into unrelated pickup-sheet cells.
    NSInteger frameIndex = subtype - 1;
    UIImage *image = nil;
    if (self.atlas.CGImage && frameIndex >= 0 && frameIndex < (NSInteger)self.frames.count) {
        id frameValue = self.frames[(NSUInteger)frameIndex];
        if ([frameValue isKindOfClass:NSValue.class]) {
            CGRect frame = [frameValue CGRectValue];
            CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(self.atlas.CGImage),
                                       CGImageGetHeight(self.atlas.CGImage));
            if (CGRectContainsRect(bounds, frame)) {
                CGImageRef cropped = CGImageCreateWithImageInRect(self.atlas.CGImage, frame);
                if (cropped) {
                    image = [UIImage imageWithCGImage:cropped scale:1
                                          orientation:UIImageOrientationUp];
                    CGImageRelease(cropped);
                }
            }
        }
    }
    self.cache[key] = image ?: NSNull.null;
    return image;
}
@end

@interface NSObject (EIDCardFrameFix)
- (UIImage *)eid_correct_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
@end

@implementation NSObject (EIDCardFrameFix)
- (UIImage *)eid_correct_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    if (variant == EIDPickupVariantCard && subtype >= 32 && subtype <= 41) {
        // Returning nil is safer than displaying a random card if an incomplete
        // raw-dylib installation omitted the attributed EID artwork bundle.
        return [[EIDOriginalRuneArtwork shared] imageForRuneSubtype:subtype];
    }
    if (variant == EIDPickupVariantCard && subtype > 0) {
        // Isaac's native CardFronts animation contains an invisible frame zero.
        return [self eid_correct_pocketIconForVariant:variant subtype:subtype + 1];
    }
    return [self eid_correct_pocketIconForVariant:variant subtype:subtype];
}
@end

__attribute__((constructor)) static void EIDInstallCardFrameFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;
        SEL replacementSEL = @selector(eid_correct_pocketIconForVariant:subtype:);
        Method source = class_getInstanceMethod(NSObject.class, replacementSEL);
        if (!source) return;
        class_addMethod(cls, replacementSEL, method_getImplementation(source),
                        method_getTypeEncoding(source));
        Method original = class_getInstanceMethod(
            cls, NSSelectorFromString(@"pocketIconForVariant:subtype:"));
        Method replacement = class_getInstanceMethod(cls, replacementSEL);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}
