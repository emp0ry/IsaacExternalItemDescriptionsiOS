#import "EIDOverlayController.h"
#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat EIDOverlayLeftMargin = 112.0;
static const CGFloat EIDOverlayRightMargin = 14.0;
static const CGFloat EIDItemIconSize = 28.0;
static const CGFloat EIDItemIconSpacing = 6.0;

@interface EIDPassthroughView : UIView
@end
@implementation EIDPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return [hit isKindOfClass:UIControl.class] ? hit : nil;
}
@end

@interface EIDOverlayController ()
@property(nonatomic, strong) EIDDescriptionStore *store;
@property(nonatomic, strong) EIDNativeProbe *probe;
@property(nonatomic, strong) EIDPassthroughView *rootView;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UIImageView *itemIconView;
@property(nonatomic, strong) UILabel *label;
@property(nonatomic, strong) UILabel *diagnosticsLabel;
@property(nonatomic, strong) UIButton *languageButton;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSArray<EIDPickupIdentity *> *lastPickups;
@property(nonatomic) BOOL diagnosticsEnabled;
@property(nonatomic) BOOL scanInProgress;
@property(nonatomic) BOOL startupBannerVisible;
@end

@implementation EIDOverlayController
- (instancetype)initWithStore:(EIDDescriptionStore *)store probe:(EIDNativeProbe *)probe {
    self = [super init];
    if (self) {
        _store = store;
        _probe = probe;
        _lastPickups = @[];
    }
    return self;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self attachOverlayIfNeeded];
        [self.probe start];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                     target:self
                                                   selector:@selector(tick:)
                                                   userInfo:nil
                                                    repeats:YES];
        [self showStartupBanner];
    });
}

- (UIWindow *)gameWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden && window.alpha > 0 && window.windowLevel == UIWindowLevelNormal) return window;
        }
    }
    return nil;
}

- (void)attachOverlayIfNeeded {
    UIWindow *window = [self gameWindow];
    if (!window) return;
    if (self.rootView.superview == window) return;
    [self.rootView removeFromSuperview];

    EIDPassthroughView *root = [[EIDPassthroughView alloc] initWithFrame:window.bounds];
    root.backgroundColor = UIColor.clearColor;
    root.userInteractionEnabled = YES;
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
    panel.frame = CGRectMake(EIDOverlayLeftMargin, 42,
                             MIN(340, window.bounds.size.width - EIDOverlayLeftMargin - EIDOverlayRightMargin),
                             80);
    panel.backgroundColor = UIColor.clearColor;
    panel.clipsToBounds = NO;
    panel.alpha = 0;
    panel.userInteractionEnabled = YES;
    panel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;

    UILabel *label = [[UILabel alloc] initWithFrame:panel.bounds];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    label.adjustsFontSizeToFitWidth = NO;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.shadowColor = [UIColor colorWithWhite:0 alpha:0.95];
    label.shadowOffset = CGSizeMake(1, 1);
    label.userInteractionEnabled = NO;
    [panel addSubview:label];

    UIImageView *itemIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    itemIcon.contentMode = UIViewContentModeScaleAspectFit;
    itemIcon.layer.magnificationFilter = kCAFilterNearest;
    itemIcon.layer.minificationFilter = kCAFilterNearest;
    itemIcon.userInteractionEnabled = NO;
    itemIcon.hidden = YES;
    [panel insertSubview:itemIcon belowSubview:label];

    UIButton *languageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    languageButton.frame = CGRectMake(panel.bounds.size.width - 48, 6, 42, 28);
    languageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    languageButton.backgroundColor = UIColor.clearColor;
    languageButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    languageButton.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.95];
    languageButton.titleLabel.shadowOffset = CGSizeMake(1, 1);
    [languageButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [languageButton addTarget:self action:@selector(toggleLanguage:) forControlEvents:UIControlEventTouchUpInside];
    languageButton.hidden = YES;
    [panel addSubview:languageButton];

    UILabel *diagnostics = [[UILabel alloc] initWithFrame:
        CGRectMake(EIDOverlayLeftMargin, window.bounds.size.height - 50,
                   window.bounds.size.width - EIDOverlayLeftMargin - EIDOverlayRightMargin, 36)];
    diagnostics.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    diagnostics.textColor = UIColor.systemGreenColor;
    diagnostics.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    diagnostics.numberOfLines = 2;
    diagnostics.layer.cornerRadius = 6;
    diagnostics.layer.masksToBounds = YES;
    diagnostics.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    diagnostics.hidden = !self.diagnosticsEnabled;

    [root addSubview:panel];
    [root addSubview:diagnostics];
    [window addSubview:root];
    self.rootView = root;
    self.panel = panel;
    self.itemIconView = itemIcon;
    self.label = label;
    self.diagnosticsLabel = diagnostics;
    self.languageButton = languageButton;
    [self updateLanguageButton];
    if (self.startupBannerVisible) {
        self.languageButton.hidden = NO;
        [self updateStartupBannerText];
        self.panel.alpha = 1;
    }
}

- (void)showStartupBanner {
    self.startupBannerVisible = YES;
    self.languageButton.hidden = NO;
    [self updateStartupBannerText];
    [UIView animateWithDuration:0.2 animations:^{ self.panel.alpha = 1; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.startupBannerVisible = NO;
        self.languageButton.hidden = YES;
        if (self.lastPickups.count) {
            [self renderPickups:self.lastPickups];
        } else {
            [UIView animateWithDuration:0.25 animations:^{ self.panel.alpha = 0; }];
        }
    });
}

- (void)updateStartupBannerText {
    self.itemIconView.image = nil;
    self.itemIconView.hidden = YES;
    BOOL russian = [self.store.languageCode isEqualToString:@"ru"];
    NSString *title = russian ? @"Описание предметов" : @"External Item Descriptions";
    NSString *status = self.probe.supportedBuild
        ? (russian ? @"Нативный сканер активен" : @"Native scanner active")
        : (russian ? @"Эта версия Isaac не поддерживается" : @"Unsupported Isaac version");
    self.label.text = [NSString stringWithFormat:@"%@\n%@", title, status];
    [self sizePanelForText];
}

- (void)tick:(NSTimer *)timer {
    (void)timer;
    [self attachOverlayIfNeeded];
    self.diagnosticsLabel.hidden = !self.diagnosticsEnabled;
    self.diagnosticsLabel.text = [NSString stringWithFormat:@" EID %@ | pickups %@\n %@",
                                  self.probe.executableUUID, self.lastPickups, self.probe.status];
    if (self.scanInProgress) return;
    self.scanInProgress = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<EIDPickupIdentity *> *pickups = [self.probe currentDescribablePickups];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.scanInProgress = NO;
            if (![pickups isEqualToArray:self.lastPickups]) {
                self.lastPickups = pickups;
                if (!self.startupBannerVisible) [self renderPickups:pickups];
                EIDLog(@"visible describable pickups: %@", pickups);
            }
        });
    });
}

- (NSString *)kindNameForVariant:(NSInteger)variant {
    BOOL russian = [self.store.languageCode isEqualToString:@"ru"];
    if (variant == EIDPickupVariantTrinket) return russian ? @"Брелок" : @"Trinket";
    if (variant == EIDPickupVariantCard) return russian ? @"Карта / руна" : @"Card / rune";
    if (variant == EIDPickupVariantPill) return russian ? @"Таблетка" : @"Pill";
    if (variant == EIDPickupVariantHorsePill) return russian ? @"Большая таблетка" : @"Horse pill";
    return russian ? @"Артефакт" : @"Collectible";
}

- (void)renderPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    if (!pickups.count) {
        self.itemIconView.image = nil;
        self.itemIconView.hidden = YES;
        [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 0; }];
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    EIDDescription *displayItem = nil;
    NSUInteger shown = MIN(pickups.count, 1);
    for (NSUInteger index = 0; index < shown; ++index) {
        EIDPickupIdentity *pickup = pickups[index];
        NSInteger displaySubtype = pickup.variant == EIDPickupVariantTrinket
            ? (pickup.subtype & 0x7fff) : pickup.subtype;
        EIDDescription *item = [self.store descriptionForPickupVariant:pickup.variant
                                                                subtype:pickup.subtype];
        if (index == 0) displayItem = item;
        NSString *kind = [self kindNameForVariant:pickup.variant];
        NSString *name = item.name.length ? item.name
            : [NSString stringWithFormat:@"%@ %ld", kind, (long)displaySubtype];
        NSString *detail = item.detail.length ? item.detail
            : ([self.store.languageCode isEqualToString:@"ru"]
               ? @"Описание недоступно" : @"No description available");
        detail = [detail stringByReplacingOccurrencesOfString:@"#" withString:@"\n"];
        detail = [self renderMarkup:detail];
        [lines addObject:[NSString stringWithFormat:@"%@ · %@  [%ld]\n%@",
                          kind, name, (long)displaySubtype, detail]];
    }
    if (pickups.count > shown) {
        NSString *more = [self.store.languageCode isEqualToString:@"ru"] ? @"ещё объектов" : @"more pickups";
        [lines addObject:[NSString stringWithFormat:@"+ %lu %@",
                          (unsigned long)(pickups.count - shown), more]];
    }
    UIImage *itemImage = displayItem.iconPath.length
        ? [UIImage imageWithContentsOfFile:displayItem.iconPath] : nil;
    self.itemIconView.image = itemImage;
    self.itemIconView.hidden = itemImage == nil;
    self.label.text = [lines componentsJoinedByString:@"\n\n"];
    [self sizePanelForText];
    [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 1; }];
}

- (void)sizePanelForText {
    CGRect bounds = self.rootView.bounds;
    CGFloat availableWidth = MAX(180, bounds.size.width - EIDOverlayLeftMargin - EIDOverlayRightMargin);
    CGFloat width = MIN(390, MAX(270, bounds.size.width * 0.42));
    width = MIN(width, availableWidth);
    CGFloat buttonSpace = self.languageButton.hidden ? 0 : 50;
    CGFloat iconSpace = self.itemIconView.hidden ? 0 : EIDItemIconSize + EIDItemIconSpacing;
    CGFloat textWidth = MAX(120, width - buttonSpace - iconSpace);
    CGFloat maximumHeight = MAX(100, bounds.size.height - 58);

    CGFloat fontSize = self.startupBannerVisible ? 11.0 : 10.5;
    CGSize textSize = CGSizeZero;
    do {
        self.label.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold];
        textSize = [self.label sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
        fontSize -= 0.5;
    } while (textSize.height > maximumHeight && fontSize >= 7.5);

    // Very long imported descriptions can use more horizontal room, but are never
    // clipped to an arbitrary character or line count.
    if (textSize.height > maximumHeight && width < availableWidth) {
        width = MIN(availableWidth, MAX(width, bounds.size.width * 0.58));
        textWidth = MAX(120, width - buttonSpace - iconSpace);
        textSize = [self.label sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    }
    CGFloat height = MAX(EIDItemIconSize, textSize.height);
    self.panel.frame = CGRectMake(EIDOverlayLeftMargin, 42, width, height);
    self.itemIconView.frame = CGRectMake(0, 1, EIDItemIconSize, EIDItemIconSize);
    self.label.frame = CGRectMake(iconSpace, 0, textWidth, height);
    self.languageButton.frame = CGRectMake(width - 44, 0, 42, 28);
}

- (NSString *)renderMarkup:(NSString *)input {
    static NSDictionary<NSString *, NSString *> *symbols;
    static NSRegularExpression *pattern;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        symbols = @{
            @"Tears": @"💧", @"Damage": @"⚔", @"Range": @"↔", @"Shotspeed": @"➤",
            @"Luck": @"🍀", @"Speed": @"👟", @"Heart": @"♥", @"HalfHeart": @"♥",
            @"SoulHeart": @"♡", @"BlackHeart": @"🖤", @"EternalHeart": @"♡",
            @"HealingRed": @"♥", @"Coin": @"¢", @"Bomb": @"💣", @"Key": @"🔑",
            @"Battery": @"⚡", @"Timer": @"◷", @"Warning": @"⚠", @"Poison": @"☠",
            @"Rune": @"◇", @"Card": @"▣", @"AngelRoom": @"♢", @"DevilRoom": @"♠",
            @"TreasureRoom": @"★", @"Shop": @"$", @"Chargeable": @"⚡"
        };
        pattern = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^}]+)\\}\\}"
                                                             options:0 error:nil];
    });
    NSMutableString *output = [input mutableCopy];
    NSArray<NSTextCheckingResult *> *matches = [pattern matchesInString:input options:0
                                                                  range:NSMakeRange(0, input.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSString *token = [input substringWithRange:[match rangeAtIndex:1]];
        NSString *replacement = symbols[token];
        if (!replacement && [token hasPrefix:@"Collectible"]) replacement = @"◆";
        if (!replacement && [token hasPrefix:@"Color"]) replacement = @"";
        if (!replacement) replacement = @"";
        [output replaceCharactersInRange:match.range withString:replacement];
    }
    return output;
}

- (void)updateLanguageButton {
    NSString *title = [self.store.languageCode isEqualToString:@"ru"] ? @"RU" : @"EN";
    [self.languageButton setTitle:title forState:UIControlStateNormal];
}

- (void)toggleLanguage:(UIButton *)sender {
    (void)sender;
    NSString *next = [self.store.languageCode isEqualToString:@"ru"] ? @"en_us" : @"ru";
    [self.store setLanguageCode:next];
    [self updateLanguageButton];
    if (self.startupBannerVisible) [self updateStartupBannerText];
    else [self renderPickups:self.lastPickups];
}

- (void)showCollectibleID:(NSInteger)collectibleID {
    EIDPickupIdentity *pickup = [[EIDPickupIdentity alloc]
        initWithVariant:EIDPickupVariantCollectible subtype:collectibleID];
    dispatch_async(dispatch_get_main_queue(), ^{ [self renderPickups:@[pickup]]; });
}

- (void)setDiagnosticsEnabled:(BOOL)enabled {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_diagnosticsEnabled = enabled;
        self.diagnosticsLabel.hidden = !enabled;
    });
}
@end
