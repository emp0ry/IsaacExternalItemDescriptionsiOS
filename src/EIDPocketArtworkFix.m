#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <objc/runtime.h>

static const char *kEIDSupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
static const uintptr_t kEIDGameGlobalOffset = 0xac3b90;
static const size_t kEIDGameItemPoolOffset = 0x242c0;
static const size_t kEIDItemPoolPillEffectsOffset = 0xa2c;
static const uint32_t kEIDPillColorMask = 0x7ff;
static const uint32_t kEIDGoldenPillColor = 14;

static BOOL EIDReadMemory(vm_address_t address, void *destination, vm_size_t size) {
    if (!address || !destination || !size) return NO;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), address, size,
                             (vm_address_t)destination, &copied) == KERN_SUCCESS && copied == size;
}

static NSString *EIDUUIDForHeader(const struct mach_header_64 *header) {
    if (!header || header->magic != MH_MAGIC_64) return nil;
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        if (cursor + sizeof(struct load_command) > end) break;
        const struct load_command *command = (const struct load_command *)cursor;
        if (!command->cmdsize || cursor + command->cmdsize > end) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)cursor;
            const unsigned char *u = uuidCommand->uuid;
            return [NSString stringWithFormat:
                    @"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    u[0],u[1],u[2],u[3],u[4],u[5],u[6],u[7],u[8],u[9],u[10],u[11],u[12],u[13],u[14],u[15]];
        }
        cursor += command->cmdsize;
    }
    return nil;
}

static const struct mach_header_64 *EIDIsaacHeader(void) {
    NSString *wanted = [NSString stringWithUTF8String:kEIDSupportedUUID];
    for (uint32_t index = 0; index < _dyld_image_count(); ++index) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
        NSString *uuid = EIDUUIDForHeader(header);
        if (uuid && [uuid caseInsensitiveCompare:wanted] == NSOrderedSame) return header;
    }
    return NULL;
}

static NSString *EIDGameResource(NSString *relativePath) {
    for (NSString *root in @[@"repentance-resources", @"afterbirthplus-resources",
                              @"afterbirth-resources", @"rebirth-resources"]) {
        NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@/data/%@", root, relativePath]];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

@interface EIDArtworkAnimationParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *animations;
@property(nonatomic, copy) NSString *currentAnimation;
@property(nonatomic) BOOL readingLayer;
@end

@implementation EIDArtworkAnimationParser
- (instancetype)init {
    if ((self = [super init])) _animations = [NSMutableDictionary dictionary];
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
     attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"Animation"]) {
        self.currentAnimation = attributes[@"Name"] ?: @"";
        if (self.currentAnimation.length) self.animations[self.currentAnimation] = [NSMutableArray array];
        self.readingLayer = NO;
    } else if ([elementName isEqualToString:@"LayerAnimation"] && self.currentAnimation.length) {
        self.readingLayer = [attributes[@"LayerId"] integerValue] == 0;
    } else if ([elementName isEqualToString:@"Frame"] && self.readingLayer && self.currentAnimation.length) {
        CGFloat x = [attributes[@"XCrop"] doubleValue];
        CGFloat y = [attributes[@"YCrop"] doubleValue];
        CGFloat w = [attributes[@"Width"] doubleValue];
        CGFloat h = [attributes[@"Height"] doubleValue];
        BOOL visible = ![attributes[@"Visible"] isEqualToString:@"false"];
        [self.animations[self.currentAnimation] addObject:(visible && w > 0 && h > 0)
            ? [NSValue valueWithCGRect:CGRectMake(x, y, w, h)] : NSNull.null];
    }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"LayerAnimation"]) self.readingLayer = NO;
    if ([elementName isEqualToString:@"Animation"]) self.currentAnimation = nil;
}
@end

static NSDictionary<NSString *, NSArray *> *EIDParseAnimations(NSString *path) {
    NSData *data = path.length ? [NSData dataWithContentsOfFile:path] : nil;
    if (!data.length) return @{};
    EIDArtworkAnimationParser *delegate = [EIDArtworkAnimationParser new];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = delegate;
    if (![parser parse]) return @{};
    return delegate.animations.copy;
}

static UIImage *EIDCropImage(UIImage *atlas, id frameValue) {
    if (!atlas.CGImage || ![frameValue isKindOfClass:NSValue.class]) return nil;
    CGRect frame = [frameValue CGRectValue];
    CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(atlas.CGImage), CGImageGetHeight(atlas.CGImage));
    if (!CGRectContainsRect(bounds, frame)) return nil;
    CGImageRef cropped = CGImageCreateWithImageInRect(atlas.CGImage, frame);
    if (!cropped) return nil;
    UIImage *image = [UIImage imageWithCGImage:cropped scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(cropped);
    return image;
}

@interface EIDPocketArtworkResolver : NSObject
@property(nonatomic, strong) UIImage *cardAtlas;
@property(nonatomic, copy) NSArray *cardFrames;
@property(nonatomic, strong) UIImage *pillAtlas;
@property(nonatomic, copy) NSArray *pillFrames;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *cache;
+ (instancetype)shared;
- (UIImage *)cardImageForSubtype:(NSInteger)subtype;
- (UIImage *)pillImageForEffectSubtype:(NSInteger)subtype horse:(BOOL)horse;
@end

@implementation EIDPocketArtworkResolver
+ (instancetype)shared {
    static EIDPocketArtworkResolver *resolver;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ resolver = [EIDPocketArtworkResolver new]; });
    return resolver;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _cache = [NSMutableDictionary dictionary];

    NSString *cardPNG = EIDGameResource(@"gfx/ui/ui_cardfronts.png");
    NSString *cardANM2 = EIDGameResource(@"gfx/ui/ui_cardspills.anm2");
    _cardAtlas = cardPNG.length ? [UIImage imageWithContentsOfFile:cardPNG] : nil;
    NSDictionary *cardAnimations = EIDParseAnimations(cardANM2);
    _cardFrames = [cardAnimations[@"CardFronts"] isKindOfClass:NSArray.class] ? cardAnimations[@"CardFronts"] : @[];

    NSString *pillPNG = EIDGameResource(@"gfx/items/pick ups/pickup_007_pill.png");
    NSString *pillANM2 = EIDGameResource(@"gfx/items/pick ups/pickup_007_pill.anm2");
    _pillAtlas = pillPNG.length ? [UIImage imageWithContentsOfFile:pillPNG] : nil;
    NSDictionary *pillAnimations = EIDParseAnimations(pillANM2);
    NSArray *best = nil;
    for (NSArray *frames in pillAnimations.allValues) {
        if (![frames isKindOfClass:NSArray.class] || frames.count < kEIDGoldenPillColor) continue;
        if (!best || frames.count > best.count) best = frames;
    }
    _pillFrames = best ?: @[];
    EIDLog(@"pocket artwork fix loaded: card frames %lu, pill frames %lu",
           (unsigned long)_cardFrames.count, (unsigned long)_pillFrames.count);
    return self;
}
- (UIImage *)cardImageForSubtype:(NSInteger)subtype {
    if (subtype <= 0) return nil;
    NSString *key = [NSString stringWithFormat:@"card:%ld", (long)subtype];
    id cached = self.cache[key];
    if (cached) return cached == NSNull.null ? nil : cached;

    // Isaac card/rune SubType IDs are 1-based; ANM2 frames are zero-based.
    NSInteger index = subtype - 1;
    UIImage *image = nil;
    if (index >= 0 && index < (NSInteger)self.cardFrames.count) {
        image = EIDCropImage(self.cardAtlas, self.cardFrames[(NSUInteger)index]);
    }
    self.cache[key] = image ?: NSNull.null;
    return image;
}
- (NSInteger)pillColorForEffectSubtype:(NSInteger)subtype {
    if (subtype == 9999) return kEIDGoldenPillColor;
    NSInteger effect = subtype - 1;
    if (effect < 0 || effect > 63) return 0;
    const struct mach_header_64 *header = EIDIsaacHeader();
    if (!header) return 0;
    uintptr_t game = 0;
    if (!EIDReadMemory((vm_address_t)header + kEIDGameGlobalOffset, &game, sizeof(game)) || !game) return 0;
    uintptr_t itemPool = game + kEIDGameItemPoolOffset;
    for (uint32_t color = 1; color < kEIDGoldenPillColor; ++color) {
        int32_t mappedEffect = -1;
        if (!EIDReadMemory(itemPool + kEIDItemPoolPillEffectsOffset + color * sizeof(mappedEffect),
                           &mappedEffect, sizeof(mappedEffect))) continue;
        if (mappedEffect == effect) return color;
    }
    return 0;
}
- (UIImage *)pillImageForEffectSubtype:(NSInteger)subtype horse:(BOOL)horse {
    NSInteger color = [self pillColorForEffectSubtype:subtype];
    if (color <= 0) return nil;
    NSString *key = [NSString stringWithFormat:@"pill:%ld:%d", (long)color, horse];
    id cached = self.cache[key];
    if (cached) return cached == NSNull.null ? nil : cached;

    UIImage *image = nil;
    NSInteger index = color - 1;
    if (index >= 0 && index < (NSInteger)self.pillFrames.count) {
        image = EIDCropImage(self.pillAtlas, self.pillFrames[(NSUInteger)index]);
    }

    // Some Isaac resource packs do not expose the pickup animation frames in ANM2.
    // The pill sheet is still a 32x32 frame grid; use the native color ID as the
    // frame index rather than falling back to one hard-coded white pill.
    if (!image && self.pillAtlas.CGImage) {
        size_t width = CGImageGetWidth(self.pillAtlas.CGImage);
        size_t height = CGImageGetHeight(self.pillAtlas.CGImage);
        const NSInteger cell = 32;
        NSInteger columns = (NSInteger)(width / cell);
        NSInteger rows = (NSInteger)(height / cell);
        NSInteger frameCount = columns * rows;
        if (columns > 0 && index >= 0 && index < frameCount) {
            CGRect frame = CGRectMake((index % columns) * cell, (index / columns) * cell, cell, cell);
            image = EIDCropImage(self.pillAtlas, [NSValue valueWithCGRect:frame]);
        }
    }
    self.cache[key] = image ?: NSNull.null;
    return image;
}
@end

@interface NSObject (EIDPocketArtworkFix)
- (UIImage *)eid_fixed_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
@end

@implementation NSObject (EIDPocketArtworkFix)
- (UIImage *)eid_fixed_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    UIImage *fixed = nil;
    if (variant == EIDPickupVariantCard) {
        fixed = [[EIDPocketArtworkResolver shared] cardImageForSubtype:subtype];
    } else if (variant == EIDPickupVariantPill || variant == EIDPickupVariantHorsePill) {
        fixed = [[EIDPocketArtworkResolver shared] pillImageForEffectSubtype:subtype
                                                                      horse:(variant == EIDPickupVariantHorsePill)];
    }
    return fixed ?: [self eid_fixed_pocketIconForVariant:variant subtype:subtype];
}
@end

__attribute__((constructor)) static void EIDInstallPocketArtworkFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;
        SEL replacementSEL = @selector(eid_fixed_pocketIconForVariant:subtype:);
        Method source = class_getInstanceMethod(NSObject.class, replacementSEL);
        if (!source) return;
        class_addMethod(cls, replacementSEL, method_getImplementation(source), method_getTypeEncoding(source));
        Method original = class_getInstanceMethod(cls, NSSelectorFromString(@"pocketIconForVariant:subtype:"));
        Method replacement = class_getInstanceMethod(cls, replacementSEL);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}
