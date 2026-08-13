#import "EIDOverlayController.h"
#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

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
@property(nonatomic, strong) UIVisualEffectView *panel;
@property(nonatomic, strong) UILabel *label;
@property(nonatomic, strong) UILabel *diagnosticsLabel;
@property(nonatomic, strong) UIImageView *itemIconView;
@property(nonatomic, strong) UIButton *languageButton;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSArray<EIDPickupIdentity *> *lastPickups;
@property(nonatomic) BOOL diagnosticsEnabled;
@property(nonatomic) BOOL scanInProgress;
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

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:blur];
    panel.frame = CGRectMake(14, 42, MIN(340, window.bounds.size.width - 28), 80);
    panel.layer.cornerRadius = 10;
    panel.layer.masksToBounds = YES;
    panel.alpha = 0;
    panel.userInteractionEnabled = YES;
    panel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(panel.bounds, 12, 9)];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.adjustsFontSizeToFitWidth = NO;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.userInteractionEnabled = NO;
    [panel.contentView addSubview:label];

    UIImageView *itemIcon = [[UIImageView alloc] initWithFrame:CGRectMake(10, 13, 38, 38)];
    itemIcon.contentMode = UIViewContentModeScaleAspectFit;
    itemIcon.layer.magnificationFilter = kCAFilterNearest;
    itemIcon.hidden = YES;
    [panel.contentView addSubview:itemIcon];

    UIButton *languageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    languageButton.frame = CGRectMake(panel.bounds.size.width - 48, 6, 42, 28);
    languageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    languageButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    languageButton.layer.cornerRadius = 7;
    languageButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [languageButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [languageButton addTarget:self action:@selector(toggleLanguage:) forControlEvents:UIControlEventTouchUpInside];
    [panel.contentView addSubview:languageButton];

    UILabel *diagnostics = [[UILabel alloc] initWithFrame:CGRectMake(14, window.bounds.size.height - 50,
                                                                     window.bounds.size.width - 28, 36)];
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
    self.label = label;
    self.diagnosticsLabel = diagnostics;
    self.itemIconView = itemIcon;
    self.languageButton = languageButton;
    [self updateLanguageButton];
}

- (void)showStartupBanner {
    BOOL russian = [self.store.languageCode isEqualToString:@"ru"];
    NSString *title = russian ? @"Описание предметов" : @"External Item Descriptions";
    NSString *status = self.probe.supportedBuild
        ? (russian ? @"Нативный сканер активен" : @"Native scanner active")
        : (russian ? @"Эта версия Isaac не поддерживается" : @"Unsupported Isaac version");
    self.label.text = [NSString stringWithFormat:@"%@\n%@", title, status];
    [self sizePanelForText];
    [UIView animateWithDuration:0.2 animations:^{ self.panel.alpha = 1; } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.25 delay:3 options:0 animations:^{ self.panel.alpha = 0; } completion:nil];
    }];
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
                [self renderPickups:pickups];
                EIDLog(@"visible describable pickups: %@", pickups);
            }
        });
    });
}

- (NSString *)kindNameForVariant:(NSInteger)variant {
    BOOL russian = [self.store.languageCode isEqualToString:@"ru"];
    if (variant == EIDPickupVariantTrinket) return russian ? @"Брелок" : @"Trinket";
    if (variant == EIDPickupVariantCard) return russian ? @"Карта / руна" : @"Card / rune";
    return russian ? @"Артефакт" : @"Collectible";
}

- (void)renderPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    if (!pickups.count) {
        [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 0; }];
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    EIDDescription *firstItem = nil;
    NSUInteger shown = MIN(pickups.count, 3);
    for (NSUInteger index = 0; index < shown; ++index) {
        EIDPickupIdentity *pickup = pickups[index];
        NSInteger displaySubtype = pickup.variant == EIDPickupVariantTrinket
            ? (pickup.subtype & 0x7fff) : pickup.subtype;
        EIDDescription *item = [self.store descriptionForPickupVariant:pickup.variant
                                                                subtype:pickup.subtype];
        if (!firstItem) firstItem = item;
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
    self.label.text = [lines componentsJoinedByString:@"\n\n"];
    UIImage *icon = firstItem.iconPath.length ? [UIImage imageWithContentsOfFile:firstItem.iconPath] : nil;
    self.itemIconView.image = icon;
    self.itemIconView.hidden = icon == nil;
    [self sizePanelForText];
    [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 1; }];
}

- (void)sizePanelForText {
    CGFloat width = MIN(360, MAX(260, self.rootView.bounds.size.width * 0.43));
    CGSize size = [self.label sizeThatFits:CGSizeMake(width - 24, 260)];
    CGFloat height = MIN(278, MAX(62, size.height + 18));
    self.panel.frame = CGRectMake(14, 42, width, height);
    CGRect labelFrame = CGRectInset(self.panel.bounds, 12, 9);
    if (!self.itemIconView.hidden) {
        labelFrame.origin.x += 44;
        labelFrame.size.width -= 44;
    }
    labelFrame.size.width -= 42;
    self.label.frame = labelFrame;
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
    [self renderPickups:self.lastPickups];
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
