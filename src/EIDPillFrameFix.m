#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <objc/runtime.h>

static const char *kEIDPillSupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
static const uintptr_t kEIDPillGameGlobalOffset = 0xac3b90;
static const size_t kEIDPillGameItemPoolOffset = 0x242c0;
static const size_t kEIDPillEffectsOffset = 0xa2c;
static const NSInteger kEIDGoldenPillColor = 14;

static BOOL EIDPillReadMemory(vm_address_t address, void *destination, vm_size_t size) {
    if (!address || !destination || !size) return NO;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), address, size,
                             (vm_address_t)destination, &copied) == KERN_SUCCESS && copied == size;
}

static NSString *EIDPillUUIDForHeader(const struct mach_header_64 *header) {
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

static const struct mach_header_64 *EIDPillIsaacHeader(void) {
    NSString *wanted = [NSString stringWithUTF8String:kEIDPillSupportedUUID];
    for (uint32_t index = 0; index < _dyld_image_count(); ++index) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
        NSString *uuid = EIDPillUUIDForHeader(header);
        if (uuid && [uuid caseInsensitiveCompare:wanted] == NSOrderedSame) return header;
    }
    return NULL;
}

static NSArray<NSString *> *EIDPillBundleRoots(void) {
    NSMutableArray<NSString *> *roots = [NSMutableArray array];
    NSString *main = NSBundle.mainBundle.bundlePath;
    [roots addObjectsFromArray:@[
        [main stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/Resources/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/IsaacEID.bundle"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions"],
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",
        @"/Library/Application Support/IsaacExternalItemDescriptions"
    ]];
    NSBundle *framework = [NSBundle bundleForClass:NSClassFromString(@"EIDOverlayController") ?: NSObject.class];
    if (framework.bundlePath.length) {
        [roots addObject:[framework.bundlePath stringByAppendingPathComponent:@"Resources/IsaacEID.bundle"]];
        [roots addObject:[framework.bundlePath stringByAppendingPathComponent:@"IsaacEID.bundle"]];
        [roots addObject:framework.bundlePath];
    }
    return roots;
}

static NSString *EIDPillBundledResource(NSString *name) {
    for (NSString *root in EIDPillBundleRoots()) {
        NSString *path = [root stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

@interface EIDPillAnimationParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableArray *pillFrames;
@property(nonatomic) BOOL readingPills;
@property(nonatomic) BOOL readingLayer;
@end

@implementation EIDPillAnimationParser
- (instancetype)init {
    if ((self = [super init])) _pillFrames = [NSMutableArray array];
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
     attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"Animation"]) {
        self.readingPills = [attributes[@"Name"] isEqualToString:@"Pills"];
        self.readingLayer = NO;
    } else if ([elementName isEqualToString:@"LayerAnimation"] && self.readingPills) {
        self.readingLayer = [attributes[@"LayerId"] integerValue] == 0;
    } else if ([elementName isEqualToString:@"Frame"] && self.readingPills && self.readingLayer) {
        CGFloat x = [attributes[@"XCrop"] doubleValue];
        CGFloat y = [attributes[@"YCrop"] doubleValue];
        CGFloat w = [attributes[@"Width"] doubleValue];
        CGFloat h = [attributes[@"Height"] doubleValue];
        BOOL visible = ![attributes[@"Visible"] isEqualToString:@"false"];
        [self.pillFrames addObject:(visible && w > 0 && h > 0)
            ? [NSValue valueWithCGRect:CGRectMake(x, y, w, h)] : NSNull.null];
    }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"LayerAnimation"]) self.readingLayer = NO;
    if ([elementName isEqualToString:@"Animation"]) self.readingPills = NO;
}
@end

static UIImage *EIDPillCropImage(UIImage *atlas, id frameValue) {
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

@interface EIDOriginalPillArtwork : NSObject
@property(nonatomic, strong) UIImage *atlas;
@property(nonatomic, copy) NSArray *frames;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *cache;
+ (instancetype)shared;
- (UIImage *)imageForEffectSubtype:(NSInteger)subtype horse:(BOOL)horse;
@end

@implementation EIDOriginalPillArtwork
+ (instancetype)shared {
    static EIDOriginalPillArtwork *resolver;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ resolver = [EIDOriginalPillArtwork new]; });
    return resolver;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _cache = [NSMutableDictionary dictionary];
    NSString *png = EIDPillBundledResource(@"eid_cardspills.png");
    NSString *anm2 = EIDPillBundledResource(@"eid_cardspills.anm2");
    _atlas = png.length ? [UIImage imageWithContentsOfFile:png] : nil;
    NSData *data = anm2.length ? [NSData dataWithContentsOfFile:anm2] : nil;
    if (data.length) {
        EIDPillAnimationParser *delegate = [EIDPillAnimationParser new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = delegate;
        if ([parser parse]) _frames = delegate.pillFrames.copy;
    }
    if (!_frames) _frames = @[];
    EIDLog(@"original EID pill artwork: atlas %@, frames %lu",
           _atlas ? @"yes" : @"no", (unsigned long)_frames.count);
    return self;
}
- (NSInteger)colorForEffectSubtype:(NSInteger)subtype {
    if (subtype == 9999) return kEIDGoldenPillColor;
    NSInteger effect = subtype - 1;
    if (effect < 0 || effect > 63) return 0;
    const struct mach_header_64 *header = EIDPillIsaacHeader();
    if (!header) return 0;
    uintptr_t game = 0;
    if (!EIDPillReadMemory((vm_address_t)header + kEIDPillGameGlobalOffset,
                           &game, sizeof(game)) || !game) return 0;
    uintptr_t itemPool = game + kEIDPillGameItemPoolOffset;
    for (NSInteger color = 1; color < kEIDGoldenPillColor; ++color) {
        int32_t mappedEffect = -1;
        if (!EIDPillReadMemory(itemPool + kEIDPillEffectsOffset + color * sizeof(mappedEffect),
                               &mappedEffect, sizeof(mappedEffect))) continue;
        if (mappedEffect == effect) return color;
    }
    return 0;
}
- (UIImage *)imageForEffectSubtype:(NSInteger)subtype horse:(BOOL)horse {
    NSInteger color = [self colorForEffectSubtype:subtype];
    if (color <= 0) return nil;
    NSString *key = [NSString stringWithFormat:@"%ld:%d", (long)color, horse];
    id cached = self.cache[key];
    if (cached) return cached == NSNull.null ? nil : cached;

    // Original EID's Pills animation has exactly 14 visual frames corresponding
    // to Isaac PillColor values 1...14. This is animation-frame mapping, not a
    // guessed PNG grid index: color 1 -> animation frame 0, ... color 14 -> 13.
    NSInteger frameIndex = color - 1;
    UIImage *image = nil;
    if (frameIndex >= 0 && frameIndex < (NSInteger)self.frames.count) {
        image = EIDPillCropImage(self.atlas, self.frames[(NSUInteger)frameIndex]);
    }
    if (!image) EIDLog(@"no original EID pill frame for color %ld", (long)color);
    self.cache[key] = image ?: NSNull.null;
    return image;
}
@end

@interface NSObject (EIDPillFrameFix)
- (UIImage *)eid_original_pill_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype;
@end

@implementation NSObject (EIDPillFrameFix)
- (UIImage *)eid_original_pill_pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    if (variant == EIDPickupVariantPill || variant == EIDPickupVariantHorsePill) {
        UIImage *image = [[EIDOriginalPillArtwork shared] imageForEffectSubtype:subtype
                                                                         horse:(variant == EIDPickupVariantHorsePill)];
        if (image) return image;
    }
    return [self eid_original_pill_pocketIconForVariant:variant subtype:subtype];
}
@end

__attribute__((constructor)) static void EIDInstallOriginalPillArtwork(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;
        SEL replacementSEL = @selector(eid_original_pill_pocketIconForVariant:subtype:);
        Method source = class_getInstanceMethod(NSObject.class, replacementSEL);
        if (!source) return;
        class_addMethod(cls, replacementSEL, method_getImplementation(source), method_getTypeEncoding(source));
        Method original = class_getInstanceMethod(cls, NSSelectorFromString(@"pocketIconForVariant:subtype:"));
        Method replacement = class_getInstanceMethod(cls, replacementSEL);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}
