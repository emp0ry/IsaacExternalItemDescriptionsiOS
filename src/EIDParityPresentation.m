#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const EIDScaleKey = @"IsaacEIDScale";
static NSString *const EIDTransparencyKey = @"IsaacEIDTransparency";
static NSString *const EIDShowNameKey = @"IsaacEIDShowItemName";
static NSString *const EIDShowIconKey = @"IsaacEIDShowItemIcon";
static NSString *const EIDShowQualityKey = @"IsaacEIDShowQuality";
static NSString *const EIDShowDescriptionKey = @"IsaacEIDShowItemDescription";
static NSString *const EIDTextWidthKey = @"IsaacEIDTextboxWidth";
static NSString *const EIDLineHeightKey = @"IsaacEIDLineHeight";

static UIColor *EIDObjNameColor(void) {
    // Upstream ColorEIDObjName = KColor(0.8, 0.3, 0.8, 1)
    return [UIColor colorWithRed:0.8 green:0.3 blue:0.8 alpha:1.0];
}

static NSDictionary<NSString *, UIColor *> *EIDInlineColors(void) {
    static NSDictionary *colors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = @{
            @"ColorEIDText": UIColor.whiteColor,
            @"ColorText": UIColor.whiteColor,
            @"ColorEIDObjName": EIDObjNameColor(),
            @"ColorObjName": EIDObjNameColor(),
            @"ColorEIDTransform": [UIColor colorWithRed:0.5 green:0.5 blue:1 alpha:1],
            @"ColorEIDError": [UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1],
            @"ColorBlack": UIColor.blackColor,
            @"ColorWhite": UIColor.whiteColor,
            @"ColorRed": UIColor.redColor,
            @"ColorLime": UIColor.greenColor,
            @"ColorBlue": UIColor.blueColor,
            @"ColorYellow": UIColor.yellowColor,
            @"ColorCyan": UIColor.cyanColor,
            @"ColorPink": UIColor.magentaColor,
            @"ColorSilver": [UIColor colorWithWhite:0.75 alpha:1],
            @"ColorGray": [UIColor colorWithWhite:0.5 alpha:1],
            @"ColorMaroon": [UIColor colorWithRed:0.5 green:0 blue:0 alpha:1],
            @"ColorOlive": [UIColor colorWithRed:0.5 green:0.5 blue:0 alpha:1],
            @"ColorGreen": [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1],
            @"ColorPurple": [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1],
            @"ColorTeal": [UIColor colorWithRed:0 green:0.5 blue:0.5 alpha:1],
            @"ColorNavy": [UIColor colorWithRed:0 green:0 blue:0.5 alpha:1],
            @"ColorOrange": [UIColor colorWithRed:1 green:0.54 blue:0 alpha:1],
            @"ColorPastelBlue": [UIColor colorWithRed:0.3882 green:0.5216 blue:1 alpha:1],
            @"ColorLavender": [UIColor colorWithRed:0.7451 green:0.3686 blue:1 alpha:1],
            @"ColorLightOrange": [UIColor colorWithRed:1 green:0.6353 blue:0.3686 alpha:1],
            @"ColorLightYellow": [UIColor colorWithRed:1 green:1 blue:0.5 alpha:1],
            @"ColorCard": [UIColor colorWithRed:0.815 green:0.651 blue:0.494 alpha:1],
            @"ColorPill": [UIColor colorWithRed:0.306 green:0.651 blue:0.851 alpha:1],
        };
    });
    return colors;
}

static NSString *EIDParityResourcePath(NSString *name) {
    NSArray<NSString *> *roots = @[
        [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],
        [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"IsaacEID.bundle"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions"],
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",
        @"/Library/Application Support/IsaacExternalItemDescriptions"
    ];
    for (NSString *root in roots) {
        NSString *path = [root stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

@interface EIDAtlasParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *animations;
@property(nonatomic, copy) NSString *animation;
@property(nonatomic) BOOL readingLayer;
@end

@implementation EIDAtlasParser
- (instancetype)init { if ((self = [super init])) _animations = [NSMutableDictionary dictionary]; return self; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"Animation"]) {
        self.animation = attributes[@"Name"];
        if (self.animation.length) self.animations[self.animation] = [NSMutableArray array];
        self.readingLayer = NO;
        return;
    }
    if ([elementName isEqualToString:@"LayerAnimation"] && self.animation.length) {
        self.readingLayer = [attributes[@"LayerId"] integerValue] == 0;
        return;
    }
    if (![elementName isEqualToString:@"Frame"] || !self.readingLayer || !self.animation.length) return;
    CGFloat x = [attributes[@"XCrop"] doubleValue];
    CGFloat y = [attributes[@"YCrop"] doubleValue];
    CGFloat width = [attributes[@"Width"] doubleValue];
    CGFloat height = [attributes[@"Height"] doubleValue];
    if (width <= 0 || height <= 0 || [attributes[@"Visible"] isEqualToString:@"false"]) {
        [self.animations[self.animation] addObject:NSNull.null];
    } else {
        [self.animations[self.animation] addObject:[NSValue valueWithCGRect:CGRectMake(x, y, width, height)]];
    }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"LayerAnimation"]) self.readingLayer = NO;
    if ([elementName isEqualToString:@"Animation"]) self.animation = nil;
}
@end

@interface EIDInlineAtlas : NSObject
@property(nonatomic, strong) UIImage *image;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray *> *animations;
@property(nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *iconMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *cache;
+ (instancetype)shared;
- (UIImage *)imageForToken:(NSString *)token;
@end

@implementation EIDInlineAtlas
+ (instancetype)shared { static EIDInlineAtlas *atlas; static dispatch_once_t once; dispatch_once(&once, ^{ atlas = [EIDInlineAtlas new]; }); return atlas; }
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _cache = [NSMutableDictionary dictionary];
    NSString *pngPath = EIDParityResourcePath(@"eid_inline_icons.png");
    NSString *anm2Path = EIDParityResourcePath(@"eid_inline_icons.anm2");
    NSString *mapPath = EIDParityResourcePath(@"eid_inline_icons.json");
    _image = pngPath.length ? [UIImage imageWithContentsOfFile:pngPath] : nil;
    NSData *anm2Data = anm2Path.length ? [NSData dataWithContentsOfFile:anm2Path] : nil;
    if (anm2Data.length) {
        EIDAtlasParser *delegate = [EIDAtlasParser new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:anm2Data];
        parser.delegate = delegate;
        if ([parser parse]) _animations = delegate.animations.copy;
    }
    NSData *mapData = mapPath.length ? [NSData dataWithContentsOfFile:mapPath] : nil;
    NSDictionary *map = mapData ? [NSJSONSerialization JSONObjectWithData:mapData options:0 error:nil] : nil;
    _iconMap = [map isKindOfClass:NSDictionary.class] ? map : @{};
    EIDLog(@"EID parity inline atlas %@ (%lu icon mappings)", _image ? @"loaded" : @"unavailable", (unsigned long)_iconMap.count);
    return self;
}
- (UIImage *)imageForToken:(NSString *)token {
    if (!token.length || !self.image.CGImage) return nil;
    UIImage *cached = self.cache[token];
    if (cached) return cached;
    NSDictionary *mapping = self.iconMap[token];
    if (![mapping isKindOfClass:NSDictionary.class]) return nil;
    NSString *animation = mapping[@"animation"];
    NSInteger frame = [mapping[@"frame"] integerValue];
    NSArray *frames = self.animations[animation];
    if (frame < 0 || frame >= (NSInteger)frames.count) return nil;
    id value = frames[(NSUInteger)frame];
    if (![value isKindOfClass:NSValue.class]) return nil;
    CGRect rect = [value CGRectValue];
    CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(self.image.CGImage), CGImageGetHeight(self.image.CGImage));
    if (!CGRectContainsRect(bounds, rect)) return nil;
    CGImageRef cropped = CGImageCreateWithImageInRect(self.image.CGImage, rect);
    if (!cropped) return nil;
    UIImage *result = [UIImage imageWithCGImage:cropped scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(cropped);
    self.cache[token] = result;
    return result;
}
@end

static NSDictionary *EIDTextAttributes(UIFont *font, UIColor *color, CGFloat scale) {
    return @{
        NSFontAttributeName: [font fontWithSize:font.pointSize * scale],
        NSForegroundColorAttributeName: color,
        NSStrokeColorAttributeName: [UIColor colorWithWhite:0 alpha:0.95],
        NSStrokeWidthAttributeName: @(-2.2),
    };
}

static NSAttributedString *EIDAttachment(UIImage *image, CGFloat fontSize, CGFloat scale) {
    if (!image) return nil;
    NSTextAttachment *attachment = [NSTextAttachment new];
    attachment.image = image;
    CGFloat target = MAX(8, fontSize * scale * 0.95);
    CGFloat ratio = image.size.height > 0 ? image.size.width / image.size.height : 1;
    attachment.bounds = CGRectMake(0, -2 * scale, target * ratio, target);
    return [NSAttributedString attributedStringWithAttachment:attachment];
}

static void EIDAppendMarkup(NSMutableAttributedString *output, NSString *text, UIFont *font, CGFloat scale,
                            UIColor *initialColor) {
    if (!text.length) return;
    text = [text stringByReplacingOccurrencesOfString:@"#" withString:@"\n"];
    text = [text stringByReplacingOccurrencesOfString:@"↑" withString:@"{{ArrowUp}}"];
    text = [text stringByReplacingOccurrencesOfString:@"↓" withString:@"{{ArrowDown}}"];
    text = [text stringByReplacingOccurrencesOfString:@"!!!" withString:@"{{Warning}}"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^}]+)\\}\\}" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    NSUInteger cursor = 0;
    UIColor *color = initialColor ?: UIColor.whiteColor;
    for (NSTextCheckingResult *match in matches) {
        if (match.range.location > cursor) {
            NSString *chunk = [text substringWithRange:NSMakeRange(cursor, match.range.location - cursor)];
            [output appendAttributedString:[[NSAttributedString alloc] initWithString:chunk attributes:EIDTextAttributes(font, color, scale)]];
        }
        NSString *token = [text substringWithRange:[match rangeAtIndex:1]];
        if ([token isEqualToString:@"ColorReset"] || [token isEqualToString:@"CR"]) {
            color = initialColor ?: UIColor.whiteColor;
        } else if (EIDInlineColors()[token]) {
            color = EIDInlineColors()[token];
        } else if ([token hasPrefix:@"Color"]) {
            // Unknown/dynamic upstream color token: keep the current color rather than printing markup.
        } else {
            UIImage *icon = [[EIDInlineAtlas shared] imageForToken:token];
            NSAttributedString *attachment = EIDAttachment(icon, font.pointSize, scale);
            if (attachment) [output appendAttributedString:attachment];
        }
        cursor = NSMaxRange(match.range);
    }
    if (cursor < text.length) {
        NSString *chunk = [text substringFromIndex:cursor];
        [output appendAttributedString:[[NSAttributedString alloc] initWithString:chunk attributes:EIDTextAttributes(font, color, scale)]];
    }
}

@interface EIDParityPresentation : NSObject
+ (void)install;
@end

@implementation EIDParityPresentation

+ (void)load { [self install]; }

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"EIDOverlayController");
        if (!cls) return;
        Method originalRender = class_getInstanceMethod(cls, NSSelectorFromString(@"renderPickups:"));
        Method replacementRender = class_getInstanceMethod(cls, @selector(eid_parity_renderPickups:));
        if (originalRender && replacementRender) method_exchangeImplementations(originalRender, replacementRender);
        Method originalAttach = class_getInstanceMethod(cls, NSSelectorFromString(@"attachOverlayIfNeeded"));
        Method replacementAttach = class_getInstanceMethod(cls, @selector(eid_parity_attachOverlayIfNeeded));
        if (originalAttach && replacementAttach) method_exchangeImplementations(originalAttach, replacementAttach);
    });
}

@end

@interface NSObject (EIDParityPrivate)
- (void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity *> *)pickups;
- (void)eid_parity_attachOverlayIfNeeded;
@end

@implementation NSObject (EIDParityPrivate)

- (void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    UILabel *label = [self valueForKey:@"label"];
    UIView *panel = [self valueForKey:@"panel"];
    UIImageView *itemIconView = [self valueForKey:@"itemIconView"];
    EIDDescriptionStore *store = [self valueForKey:@"store"];
    if (!label || !panel || !store || !pickups.count) {
        [self eid_parity_renderPickups:pickups];
        return;
    }

    EIDPickupIdentity *pickup = pickups.firstObject;
    EIDDescription *item = [store descriptionForPickupVariant:pickup.variant subtype:pickup.subtype];
    if (!item) {
        [self eid_parity_renderPickups:pickups];
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CGFloat scale = [defaults objectForKey:EIDScaleKey] ? [defaults doubleForKey:EIDScaleKey] : 1.0;
    scale = MIN(1.8, MAX(0.5, scale));
    CGFloat transparency = [defaults objectForKey:EIDTransparencyKey] ? [defaults doubleForKey:EIDTransparencyKey] : 0.75;
    transparency = MIN(1, MAX(0.15, transparency));
    BOOL showName = [defaults objectForKey:EIDShowNameKey] ? [defaults boolForKey:EIDShowNameKey] : YES;
    BOOL showIcon = [defaults objectForKey:EIDShowIconKey] ? [defaults boolForKey:EIDShowIconKey] : YES;
    BOOL showQuality = [defaults objectForKey:EIDShowQualityKey] ? [defaults boolForKey:EIDShowQualityKey] : YES;
    BOOL showDescription = [defaults objectForKey:EIDShowDescriptionKey] ? [defaults boolForKey:EIDShowDescriptionKey] : YES;
    CGFloat lineHeight = [defaults objectForKey:EIDLineHeightKey] ? [defaults doubleForKey:EIDLineHeightKey] : 11.0;

    UIFont *font = [UIFont fontWithName:@"Menlo-Bold" size:10.0] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    NSMutableAttributedString *rendered = [NSMutableAttributedString new];
    if (showName) {
        NSString *name = item.name.length ? item.name : [NSString stringWithFormat:@"%ld", (long)pickup.subtype];
        [rendered appendAttributedString:[[NSAttributedString alloc] initWithString:name attributes:EIDTextAttributes(font, EIDObjNameColor(), scale)]];
        if (showQuality && pickup.variant == EIDPickupVariantCollectible && item.quality >= 0 && item.quality <= 4) {
            NSString *token = [NSString stringWithFormat:@"Quality%ld", (long)item.quality];
            NSAttributedString *quality = EIDAttachment([[EIDInlineAtlas shared] imageForToken:token], font.pointSize, scale);
            if (quality) {
                [rendered appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:EIDTextAttributes(font, EIDObjNameColor(), scale)]];
                [rendered appendAttributedString:quality];
            }
        }
        if (showDescription) [rendered appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:EIDTextAttributes(font, UIColor.whiteColor, scale)]];
    }
    if (showDescription) {
        NSString *detail = item.detail.length ? item.detail : @"No description available";
        EIDAppendMarkup(rendered, detail, font, scale, UIColor.whiteColor);
    }

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.minimumLineHeight = lineHeight * scale;
    paragraph.maximumLineHeight = lineHeight * scale;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    [rendered addAttribute:NSParagraphStyleAttributeName value:paragraph range:NSMakeRange(0, rendered.length)];

    UIImage *itemImage = showIcon && item.iconPath.length ? [UIImage imageWithContentsOfFile:item.iconPath] : nil;
    if (!itemImage && showIcon) {
        SEL pocketSelector = NSSelectorFromString(@"pocketIconForVariant:subtype:");
        if ([self respondsToSelector:pocketSelector]) {
            itemImage = ((UIImage *(*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(self, pocketSelector, pickup.variant, pickup.subtype);
        }
    }
    itemIconView.image = itemImage;
    itemIconView.hidden = !showIcon || itemImage == nil;
    label.attributedText = rendered;
    label.alpha = transparency;
    itemIconView.alpha = transparency;

    SEL sizeSelector = NSSelectorFromString(@"sizePanelForText");
    if ([self respondsToSelector:sizeSelector]) ((void (*)(id, SEL))objc_msgSend)(self, sizeSelector);

    NSNumber *widthNumber = [defaults objectForKey:EIDTextWidthKey];
    if (widthNumber) {
        CGRect frame = panel.frame;
        CGFloat width = MIN(MAX(180, widthNumber.doubleValue * 2.5 * scale), MAX(180, ((UIView *)[self valueForKey:@"rootView"]).bounds.size.width - frame.origin.x - 14));
        frame.size.width = width;
        panel.frame = frame;
    }
    [UIView animateWithDuration:0.12 animations:^{ panel.alpha = 1; }];
}

- (void)eid_parity_attachOverlayIfNeeded {
    [self eid_parity_attachOverlayIfNeeded];
    UIView *card = [self valueForKey:@"settingsCard"];
    if (!card || [card viewWithTag:0xE1D5]) return;

    CGFloat oldHeight = card.bounds.size.height;
    CGFloat newHeight = MIN(430, MAX(oldHeight, ((UIView *)[self valueForKey:@"rootView"]).bounds.size.height - 24));
    CGRect cardFrame = card.frame;
    cardFrame.origin.y -= (newHeight - oldHeight) * 0.5;
    cardFrame.size.height = newHeight;
    card.frame = cardFrame;

    UIView *section = [[UIView alloc] initWithFrame:CGRectMake(16, 228, card.bounds.size.width - 32, 120)];
    section.tag = 0xE1D5;
    section.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:section];

    NSArray<NSString *> *titles = @[@"Name", @"Icon", @"Quality", @"Description"];
    NSArray<NSString *> *keys = @[EIDShowNameKey, EIDShowIconKey, EIDShowQualityKey, EIDShowDescriptionKey];
    CGFloat buttonWidth = floor((section.bounds.size.width - 12) / 4.0);
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(i * (buttonWidth + 4), 0, buttonWidth, 28);
        button.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        button.layer.cornerRadius = 6;
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.accessibilityIdentifier = keys[i];
        [button addTarget:self action:@selector(eid_parity_toggle:) forControlEvents:UIControlEventTouchUpInside];
        [section addSubview:button];
    }

    UILabel *scaleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 34, 70, 24)];
    scaleLabel.text = @"Scale"; scaleLabel.textColor = UIColor.whiteColor; scaleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [section addSubview:scaleLabel];
    UISlider *scale = [[UISlider alloc] initWithFrame:CGRectMake(64, 32, section.bounds.size.width - 64, 28)];
    scale.minimumValue = 0.5; scale.maximumValue = 1.8;
    scale.value = [NSUserDefaults.standardUserDefaults objectForKey:EIDScaleKey] ? [NSUserDefaults.standardUserDefaults doubleForKey:EIDScaleKey] : 1;
    scale.accessibilityIdentifier = EIDScaleKey;
    [scale addTarget:self action:@selector(eid_parity_slider:) forControlEvents:UIControlEventValueChanged];
    [section addSubview:scale];

    UILabel *alphaLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 64, 70, 24)];
    alphaLabel.text = @"Opacity"; alphaLabel.textColor = UIColor.whiteColor; alphaLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [section addSubview:alphaLabel];
    UISlider *alpha = [[UISlider alloc] initWithFrame:CGRectMake(64, 62, section.bounds.size.width - 64, 28)];
    alpha.minimumValue = 0.15; alpha.maximumValue = 1;
    alpha.value = [NSUserDefaults.standardUserDefaults objectForKey:EIDTransparencyKey] ? [NSUserDefaults.standardUserDefaults doubleForKey:EIDTransparencyKey] : 0.75;
    alpha.accessibilityIdentifier = EIDTransparencyKey;
    [alpha addTarget:self action:@selector(eid_parity_slider:) forControlEvents:UIControlEventValueChanged];
    [section addSubview:alpha];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, 91, section.bounds.size.width, 22)];
    hint.text = @"Original EID visual parity · Q0–Q4 · inline icons";
    hint.textColor = [UIColor colorWithWhite:0.72 alpha:1]; hint.font = [UIFont systemFontOfSize:9.5]; hint.textAlignment = NSTextAlignmentCenter;
    [section addSubview:hint];

    [self eid_parity_refreshButtons];
}

- (void)eid_parity_toggle:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!key.length) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL current = [defaults objectForKey:key] ? [defaults boolForKey:key] : YES;
    [defaults setBool:!current forKey:key];
    [self eid_parity_refreshButtons];
    NSArray *pickups = [self valueForKey:@"lastPickups"];
    if (pickups.count) [self eid_parity_renderPickups:pickups];
}

- (void)eid_parity_slider:(UISlider *)slider {
    NSString *key = slider.accessibilityIdentifier;
    if (!key.length) return;
    [NSUserDefaults.standardUserDefaults setDouble:slider.value forKey:key];
    NSArray *pickups = [self valueForKey:@"lastPickups"];
    if (pickups.count) [self eid_parity_renderPickups:pickups];
}

- (void)eid_parity_refreshButtons {
    UIView *card = [self valueForKey:@"settingsCard"];
    UIView *section = [card viewWithTag:0xE1D5];
    for (UIView *view in section.subviews) {
        if (![view isKindOfClass:UIButton.class]) continue;
        UIButton *button = (UIButton *)view;
        NSString *key = button.accessibilityIdentifier;
        BOOL enabled = [NSUserDefaults.standardUserDefaults objectForKey:key] ? [NSUserDefaults.standardUserDefaults boolForKey:key] : YES;
        NSString *title = enabled ? [NSString stringWithFormat:@"✓ %@", [button titleForState:UIControlStateNormal] ?: @""] : [button titleForState:UIControlStateNormal];
        NSString *base = [title stringByReplacingOccurrencesOfString:@"✓ " withString:@""];
        [button setTitle:enabled ? [@"✓ " stringByAppendingString:base] : base forState:UIControlStateNormal];
        button.alpha = enabled ? 1 : 0.5;
    }
}

@end
