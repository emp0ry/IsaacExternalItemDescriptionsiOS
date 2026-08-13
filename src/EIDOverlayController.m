#import "EIDOverlayController.h"
#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat EIDDefaultOverlayLeftMargin = 140.0;
static const CGFloat EIDDefaultOverlayTopMargin = 50.0;
static const CGFloat EIDMinimumOverlayLeftMargin = 20.0;
static const CGFloat EIDMinimumOverlayTopMargin = 20.0;
static const CGFloat EIDOverlayRightMargin = 14.0;
static const CGFloat EIDItemIconSize = 28.0;
static const CGFloat EIDItemIconSpacing = 6.0;
static NSString *const EIDHorizontalPositionKey = @"IsaacEIDHorizontalPosition";
static NSString *const EIDVerticalPositionKey = @"IsaacEIDVerticalPosition";

static NSString *EIDGameResourcePath(NSString *relativePath) {
    NSArray<NSString *> *roots = @[@"repentance-resources", @"afterbirthplus-resources",
                                    @"afterbirth-resources", @"rebirth-resources"];
    for (NSString *root in roots) {
        NSString *candidate = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/%@", root, relativePath]];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:candidate]) return candidate;
    }
    return nil;
}

@interface EIDCardAtlasParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableArray *frames;
@property(nonatomic) BOOL readingCardAnimation;
@property(nonatomic) BOOL readingCardLayer;
@end

@implementation EIDCardAtlasParser
- (instancetype)init {
    self = [super init];
    if (self) _frames = [NSMutableArray array];
    return self;
}

- (void)parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"Animation"]) {
        self.readingCardAnimation = [attributes[@"Name"] isEqualToString:@"CardFronts"];
        self.readingCardLayer = NO;
        return;
    }
    if (self.readingCardAnimation && [elementName isEqualToString:@"LayerAnimation"]) {
        self.readingCardLayer = [attributes[@"LayerId"] integerValue] == 0;
        return;
    }
    if (!self.readingCardLayer || ![elementName isEqualToString:@"Frame"]) return;
    CGFloat x = [attributes[@"XCrop"] doubleValue];
    CGFloat y = [attributes[@"YCrop"] doubleValue];
    CGFloat width = [attributes[@"Width"] doubleValue];
    CGFloat height = [attributes[@"Height"] doubleValue];
    BOOL visible = ![attributes[@"Visible"] isEqualToString:@"false"];
    if (visible && width > 0 && height > 0) {
        [self.frames addObject:[NSValue valueWithCGRect:CGRectMake(x, y, width, height)]];
    } else {
        [self.frames addObject:NSNull.null];
    }
}

- (void)parser:(NSXMLParser *)parser
   didEndElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    if ([elementName isEqualToString:@"LayerAnimation"]) self.readingCardLayer = NO;
    if ([elementName isEqualToString:@"Animation"] && self.readingCardAnimation) {
        self.readingCardAnimation = NO;
    }
}
@end

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
@property(nonatomic, strong) UIButton *settingsButton;
@property(nonatomic, strong) UIView *settingsCard;
@property(nonatomic, strong) UIButton *settingsLanguageButton;
@property(nonatomic, strong) UILabel *settingsPositionLabel;
@property(nonatomic, strong) UILabel *settingsVersionLabel;
@property(nonatomic, strong) UISlider *settingsPositionSlider;
@property(nonatomic, strong) UILabel *settingsVerticalPositionLabel;
@property(nonatomic, strong) UISlider *settingsVerticalPositionSlider;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSArray<EIDPickupIdentity *> *lastPickups;
@property(nonatomic, strong) UIImage *cardAtlas;
@property(nonatomic, copy) NSArray *cardAtlasFrames;
@property(nonatomic, strong) UIImage *genericCardIcon;
@property(nonatomic, strong) UIImage *genericPillIcon;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *pocketIconCache;
@property(nonatomic) BOOL diagnosticsEnabled;
@property(nonatomic) BOOL scanInProgress;
@property(nonatomic) BOOL loggedOverlayLayout;
@property(nonatomic) BOOL menuMode;
@property(nonatomic) NSUInteger consecutiveMenuScans;
@end

@implementation EIDOverlayController
- (instancetype)initWithStore:(EIDDescriptionStore *)store probe:(EIDNativeProbe *)probe {
    self = [super init];
    if (self) {
        _store = store;
        _probe = probe;
        _lastPickups = @[];
        _pocketIconCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (CGFloat)overlayLeftMargin {
    NSNumber *saved = [[NSUserDefaults standardUserDefaults] objectForKey:EIDHorizontalPositionKey];
    CGFloat value = saved ? saved.doubleValue : EIDDefaultOverlayLeftMargin;
    CGFloat maximum = self.rootView.bounds.size.width > 0
        ? MAX(EIDDefaultOverlayLeftMargin, self.rootView.bounds.size.width - 220.0) : 360.0;
    return MIN(maximum, MAX(EIDMinimumOverlayLeftMargin, round(value)));
}

- (CGFloat)overlayTopMargin {
    NSNumber *saved = [[NSUserDefaults standardUserDefaults] objectForKey:EIDVerticalPositionKey];
    CGFloat value = saved ? saved.doubleValue : EIDDefaultOverlayTopMargin;
    CGFloat maximum = self.rootView.bounds.size.height > 0
        ? MAX(EIDDefaultOverlayTopMargin, self.rootView.bounds.size.height - 120.0) : 300.0;
    return MIN(maximum, MAX(EIDMinimumOverlayTopMargin, round(value)));
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

    CGFloat leftMargin = [self overlayLeftMargin];
    UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
    panel.frame = CGRectMake(leftMargin, [self overlayTopMargin],
                             MIN(340, window.bounds.size.width - leftMargin - EIDOverlayRightMargin),
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

    UILabel *diagnostics = [[UILabel alloc] initWithFrame:
        CGRectMake(leftMargin, window.bounds.size.height - 50,
                   window.bounds.size.width - leftMargin - EIDOverlayRightMargin, 36)];
    diagnostics.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    diagnostics.textColor = UIColor.systemGreenColor;
    diagnostics.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    diagnostics.numberOfLines = 2;
    diagnostics.layer.cornerRadius = 6;
    diagnostics.layer.masksToBounds = YES;
    diagnostics.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    diagnostics.hidden = !self.diagnosticsEnabled;

    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(window.bounds.size.width - 78,
                                      window.bounds.size.height - 46, 64, 32);
    settingsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    settingsButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    settingsButton.layer.cornerRadius = 8;
    settingsButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [settingsButton setTitle:@"EID ⚙" forState:UIControlStateNormal];
    [settingsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [settingsButton addTarget:self action:@selector(toggleSettings:) forControlEvents:UIControlEventTouchUpInside];
    settingsButton.hidden = !self.menuMode;

    CGFloat cardWidth = MIN(410, window.bounds.size.width - 40);
    CGFloat cardHeight = MIN(310, window.bounds.size.height - 30);
    UIView *settingsCard = [[UIView alloc] initWithFrame:
        CGRectMake((window.bounds.size.width - cardWidth) * 0.5,
                   (window.bounds.size.height - cardHeight) * 0.5, cardWidth, cardHeight)];
    settingsCard.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    settingsCard.backgroundColor = [UIColor colorWithWhite:0.035 alpha:0.94];
    settingsCard.layer.cornerRadius = 14;
    settingsCard.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    settingsCard.layer.borderWidth = 1;
    settingsCard.hidden = YES;

    UILabel *settingsTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 10, cardWidth - 72, 27)];
    settingsTitle.text = @"Isaac EID Settings";
    settingsTitle.textColor = UIColor.whiteColor;
    settingsTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [settingsCard addSubview:settingsTitle];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(cardWidth - 48, 7, 38, 32);
    closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    [closeButton setTitle:@"×" forState:UIControlStateNormal];
    [closeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
    [settingsCard addSubview:closeButton];

    UILabel *versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 37, cardWidth - 36, 20)];
    versionLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1];
    versionLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightRegular];
    [settingsCard addSubview:versionLabel];

    UILabel *languageLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 66, 90, 32)];
    languageLabel.text = @"Language";
    languageLabel.textColor = UIColor.whiteColor;
    languageLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [settingsCard addSubview:languageLabel];

    UIButton *languageSelector = [UIButton buttonWithType:UIButtonTypeSystem];
    languageSelector.frame = CGRectMake(110, 66, cardWidth - 128, 32);
    languageSelector.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    languageSelector.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    languageSelector.layer.cornerRadius = 7;
    languageSelector.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [languageSelector setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [languageSelector addTarget:self action:@selector(showLanguagePicker:)
               forControlEvents:UIControlEventTouchUpInside];
    [settingsCard addSubview:languageSelector];

    UILabel *positionLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 108, cardWidth - 36, 22)];
    positionLabel.textColor = UIColor.whiteColor;
    positionLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    [settingsCard addSubview:positionLabel];

    UISlider *positionSlider = [[UISlider alloc] initWithFrame:CGRectMake(18, 132, cardWidth - 104, 32)];
    positionSlider.minimumValue = EIDMinimumOverlayLeftMargin;
    positionSlider.maximumValue = MAX(EIDDefaultOverlayLeftMargin, window.bounds.size.width - 220.0);
    positionSlider.value = [self overlayLeftMargin];
    [positionSlider addTarget:self action:@selector(positionChanged:) forControlEvents:UIControlEventValueChanged];
    [settingsCard addSubview:positionSlider];

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.frame = CGRectMake(cardWidth - 78, 132, 60, 32);
    resetButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    resetButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [resetButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [resetButton addTarget:self action:@selector(resetPosition:) forControlEvents:UIControlEventTouchUpInside];
    [settingsCard addSubview:resetButton];

    UILabel *verticalPositionLabel = [[UILabel alloc] initWithFrame:
        CGRectMake(18, 168, cardWidth - 36, 22)];
    verticalPositionLabel.textColor = UIColor.whiteColor;
    verticalPositionLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    [settingsCard addSubview:verticalPositionLabel];

    UISlider *verticalPositionSlider = [[UISlider alloc] initWithFrame:
        CGRectMake(18, 192, cardWidth - 104, 32)];
    verticalPositionSlider.minimumValue = EIDMinimumOverlayTopMargin;
    verticalPositionSlider.maximumValue = MAX(EIDDefaultOverlayTopMargin,
                                               window.bounds.size.height - 120.0);
    verticalPositionSlider.value = [self overlayTopMargin];
    [verticalPositionSlider addTarget:self action:@selector(verticalPositionChanged:)
                      forControlEvents:UIControlEventValueChanged];
    [settingsCard addSubview:verticalPositionSlider];

    UIButton *verticalResetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    verticalResetButton.frame = CGRectMake(cardWidth - 78, 192, 60, 32);
    verticalResetButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    verticalResetButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [verticalResetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [verticalResetButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [verticalResetButton addTarget:self action:@selector(resetVerticalPosition:)
                  forControlEvents:UIControlEventTouchUpInside];
    [settingsCard addSubview:verticalResetButton];

    UILabel *creditsLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, cardHeight - 68,
                                                                      cardWidth - 36, 54)];
    creditsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    creditsLabel.text = @"Descriptions: External Item Descriptions\nby wofsauge and contributors · github.com/wofsauge/External-Item-Descriptions";
    creditsLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    creditsLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
    creditsLabel.numberOfLines = 3;
    creditsLabel.textAlignment = NSTextAlignmentCenter;
    [settingsCard addSubview:creditsLabel];

    [root addSubview:panel];
    [root addSubview:diagnostics];
    [root addSubview:settingsButton];
    [root addSubview:settingsCard];
    [window addSubview:root];
    self.rootView = root;
    self.panel = panel;
    self.itemIconView = itemIcon;
    self.label = label;
    self.diagnosticsLabel = diagnostics;
    self.settingsButton = settingsButton;
    self.settingsCard = settingsCard;
    self.settingsLanguageButton = languageSelector;
    self.settingsPositionLabel = positionLabel;
    self.settingsVersionLabel = versionLabel;
    self.settingsPositionSlider = positionSlider;
    self.settingsVerticalPositionLabel = verticalPositionLabel;
    self.settingsVerticalPositionSlider = verticalPositionSlider;
    [self updateSettingsControls];
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
            [self updateMenuModeForGameplay:self.probe.gameplayActive];
            if (![pickups isEqualToArray:self.lastPickups]) {
                self.lastPickups = pickups;
                if (!self.menuMode) [self renderPickups:pickups];
                EIDLog(@"visible describable pickups: %@", pickups);
            }
        });
    });
}

- (void)updateMenuModeForGameplay:(BOOL)gameplayActive {
    if (gameplayActive) {
        self.consecutiveMenuScans = 0;
        self.settingsButton.hidden = YES;
        self.settingsCard.hidden = YES;
        if (!self.menuMode) return;
        self.menuMode = NO;
        [self updateSettingsControls];
        EIDLog(@"game state: gameplay active; settings hidden");
        return;
    }
    if (self.consecutiveMenuScans < 12) self.consecutiveMenuScans++;
    if (self.consecutiveMenuScans < 12) return;
    self.settingsButton.hidden = NO;
    if (self.menuMode) return;
    self.menuMode = YES;
    self.lastPickups = @[];
    self.panel.alpha = 0;
    EIDLog(@"game state: menu detected; settings available");
}

- (void)updateSettingsControls {
    NSString *languageName = [self.store displayNameForLanguageCode:self.store.languageCode];
    [self.settingsLanguageButton setTitle:
        [NSString stringWithFormat:@"%@ · %@  ▾", languageName, self.store.languageCode]
                                  forState:UIControlStateNormal];
    CGFloat position = [self overlayLeftMargin];
    self.settingsPositionSlider.value = position;
    self.settingsPositionLabel.text = [NSString stringWithFormat:@"Horizontal position: %.0f px", position];
    CGFloat verticalPosition = [self overlayTopMargin];
    self.settingsVerticalPositionSlider.value = verticalPosition;
    self.settingsVerticalPositionLabel.text = [NSString stringWithFormat:
        @"Vertical position: %.0f px", verticalPosition];
    NSString *appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    self.settingsVersionLabel.text = [NSString stringWithFormat:
        @"%@ · iOS %@ · dataset: %@ · not Repentance+",
        self.probe.gameplayActive ? @"In game" : @"Menu", appVersion,
        self.store.descriptionDataSet];
}

- (UIViewController *)topViewControllerFrom:(UIViewController *)viewController {
    UIViewController *current = viewController;
    while (current.presentedViewController) current = current.presentedViewController;
    if ([current isKindOfClass:UINavigationController.class]) {
        return [self topViewControllerFrom:((UINavigationController *)current).visibleViewController];
    }
    if ([current isKindOfClass:UITabBarController.class]) {
        return [self topViewControllerFrom:((UITabBarController *)current).selectedViewController];
    }
    return current;
}

- (void)showLanguagePicker:(UIButton *)sender {
    UIWindow *window = [self gameWindow];
    UIViewController *presenter = [self topViewControllerFrom:window.rootViewController];
    if (!presenter) {
        EIDLog(@"language picker unavailable: no game view controller");
        return;
    }

    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Description Language"
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSString *code in self.store.availableLanguageCodes) {
        NSString *name = [self.store displayNameForLanguageCode:code];
        NSString *checkmark = [code isEqualToString:self.store.languageCode] ? @"✓ " : @"";
        NSString *title = [NSString stringWithFormat:@"%@%@ · %@", checkmark, name, code];
        [picker addAction:[UIAlertAction actionWithTitle:title
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.store setLanguageCode:code];
            [self updateSettingsControls];
            EIDLog(@"description language changed to %@", code);
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = sender;
    popover.sourceRect = sender.bounds;
    popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)toggleSettings:(UIButton *)sender {
    (void)sender;
    self.settingsCard.hidden = !self.settingsCard.hidden;
    if (!self.settingsCard.hidden) {
        [self updateSettingsControls];
        [self.rootView bringSubviewToFront:self.settingsCard];
        self.panel.alpha = 0;
    }
}

- (void)closeSettings:(UIButton *)sender {
    (void)sender;
    self.settingsCard.hidden = YES;
}

- (void)positionChanged:(UISlider *)slider {
    CGFloat position = round(slider.value);
    slider.value = position;
    [[NSUserDefaults standardUserDefaults] setDouble:position forKey:EIDHorizontalPositionKey];
    self.settingsPositionLabel.text = [NSString stringWithFormat:@"Horizontal position: %.0f px", position];
    [self sizePanelForText];
    CGRect diagnosticsFrame = self.diagnosticsLabel.frame;
    diagnosticsFrame.origin.x = position;
    diagnosticsFrame.size.width = MAX(100, self.rootView.bounds.size.width - position - EIDOverlayRightMargin);
    self.diagnosticsLabel.frame = diagnosticsFrame;
}

- (void)verticalPositionChanged:(UISlider *)slider {
    CGFloat position = round(slider.value);
    slider.value = position;
    [[NSUserDefaults standardUserDefaults] setDouble:position forKey:EIDVerticalPositionKey];
    self.settingsVerticalPositionLabel.text = [NSString stringWithFormat:
        @"Vertical position: %.0f px", position];
    [self sizePanelForText];
}

- (void)resetPosition:(UIButton *)sender {
    (void)sender;
    self.settingsPositionSlider.value = EIDDefaultOverlayLeftMargin;
    [self positionChanged:self.settingsPositionSlider];
    EIDLog(@"overlay horizontal position reset to %.0f px", EIDDefaultOverlayLeftMargin);
}

- (void)resetVerticalPosition:(UIButton *)sender {
    (void)sender;
    self.settingsVerticalPositionSlider.value = EIDDefaultOverlayTopMargin;
    [self verticalPositionChanged:self.settingsVerticalPositionSlider];
    EIDLog(@"overlay vertical position reset to %.0f px", EIDDefaultOverlayTopMargin);
}

- (NSString *)kindNameForVariant:(NSInteger)variant {
    BOOL russian = [self.store.languageCode isEqualToString:@"ru"];
    if (variant == EIDPickupVariantTrinket) return russian ? @"Брелок" : @"Trinket";
    if (variant == EIDPickupVariantCard) return russian ? @"Карта / руна" : @"Card / rune";
    if (variant == EIDPickupVariantPill) return russian ? @"Таблетка" : @"Pill";
    if (variant == EIDPickupVariantHorsePill) return russian ? @"Большая таблетка" : @"Horse pill";
    return russian ? @"Артефакт" : @"Collectible";
}

- (void)loadPocketArtworkIfNeeded {
    if (self.cardAtlasFrames) return;
    NSString *animationPath = EIDGameResourcePath(@"gfx/ui/ui_cardspills.anm2");
    NSString *atlasPath = EIDGameResourcePath(@"gfx/ui/ui_cardfronts.png");
    NSData *animationData = animationPath.length
        ? [NSData dataWithContentsOfFile:animationPath] : nil;
    EIDCardAtlasParser *delegate = [[EIDCardAtlasParser alloc] init];
    if (animationData.length) {
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:animationData];
        parser.delegate = delegate;
        if (![parser parse]) [delegate.frames removeAllObjects];
    }
    self.cardAtlasFrames = delegate.frames.copy ?: @[];
    self.cardAtlas = atlasPath.length ? [UIImage imageWithContentsOfFile:atlasPath] : nil;

    NSString *cardPath = EIDGameResourcePath(@"gfx/items/pick ups/pickup_017_card.png");
    NSString *pillPath = EIDGameResourcePath(@"gfx/items/pick ups/pickup_007_pill.png");
    self.genericCardIcon = cardPath.length ? [UIImage imageWithContentsOfFile:cardPath] : nil;
    UIImage *pillAtlas = pillPath.length ? [UIImage imageWithContentsOfFile:pillPath] : nil;
    if (pillAtlas.CGImage) {
        // Isaac's white-white pill is the 32x32 frame at (0, 32). Use one
        // stable icon for every identified normal and horse pill.
        CGRect whitePillFrame = CGRectMake(0, 32, 32, 32);
        CGImageRef cropped = CGImageCreateWithImageInRect(pillAtlas.CGImage, whitePillFrame);
        if (cropped) {
            self.genericPillIcon = [UIImage imageWithCGImage:cropped
                                                       scale:1
                                                 orientation:UIImageOrientationUp];
            CGImageRelease(cropped);
        }
    }
    EIDLog(@"pocket artwork loaded: %lu card frames, atlas %@, card fallback %@, pill fallback %@",
           (unsigned long)self.cardAtlasFrames.count,
           self.cardAtlas ? @"yes" : @"no", self.genericCardIcon ? @"yes" : @"no",
           self.genericPillIcon ? @"yes" : @"no");
}

- (UIImage *)pocketIconForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    if (variant != EIDPickupVariantCard && variant != EIDPickupVariantPill &&
        variant != EIDPickupVariantHorsePill) return nil;
    NSString *key = [NSString stringWithFormat:@"%ld:%ld", (long)variant, (long)subtype];
    id cached = self.pocketIconCache[key];
    if (cached) return cached == NSNull.null ? nil : cached;
    [self loadPocketArtworkIfNeeded];

    UIImage *image = nil;
    if (variant == EIDPickupVariantCard) {
        if (subtype > 0 && subtype < (NSInteger)self.cardAtlasFrames.count && self.cardAtlas.CGImage) {
            id frameValue = self.cardAtlasFrames[(NSUInteger)subtype];
            if ([frameValue isKindOfClass:NSValue.class]) {
                CGRect frame = [frameValue CGRectValue];
                CGRect imageBounds = CGRectMake(0, 0, CGImageGetWidth(self.cardAtlas.CGImage),
                                                 CGImageGetHeight(self.cardAtlas.CGImage));
                if (CGRectContainsRect(imageBounds, frame)) {
                    CGImageRef cropped = CGImageCreateWithImageInRect(self.cardAtlas.CGImage, frame);
                    if (cropped) {
                        image = [UIImage imageWithCGImage:cropped scale:1 orientation:UIImageOrientationUp];
                        CGImageRelease(cropped);
                    }
                }
            }
        }
        if (!image) image = self.genericCardIcon;
    } else {
        image = self.genericPillIcon;
    }
    self.pocketIconCache[key] = image ?: NSNull.null;
    return image;
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
    if (!itemImage) {
        EIDPickupIdentity *pickup = pickups.firstObject;
        itemImage = [self pocketIconForVariant:pickup.variant subtype:pickup.subtype];
    }
    self.itemIconView.image = itemImage;
    self.itemIconView.hidden = itemImage == nil;
    self.label.text = [lines componentsJoinedByString:@"\n\n"];
    [self sizePanelForText];
    [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 1; }];
}

- (void)sizePanelForText {
    CGRect bounds = self.rootView.bounds;
    CGFloat leftMargin = [self overlayLeftMargin];
    CGFloat availableWidth = MAX(180, bounds.size.width - leftMargin - EIDOverlayRightMargin);
    CGFloat width = MIN(390, MAX(270, bounds.size.width * 0.42));
    width = MIN(width, availableWidth);
    CGFloat iconSpace = self.itemIconView.hidden ? 0 : EIDItemIconSize + EIDItemIconSpacing;
    CGFloat textWidth = MAX(120, width - iconSpace);
    CGFloat topMargin = [self overlayTopMargin];
    CGFloat maximumHeight = MAX(100, bounds.size.height - topMargin - 16);

    CGFloat fontSize = 10.5;
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
        textWidth = MAX(120, width - iconSpace);
        textSize = [self.label sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    }
    CGFloat height = MAX(EIDItemIconSize, textSize.height);
    self.panel.frame = CGRectMake(leftMargin, topMargin, width, height);
    self.itemIconView.frame = CGRectMake(0, 1, EIDItemIconSize, EIDItemIconSize);
    self.label.frame = CGRectMake(iconSpace, 0, textWidth, height);
    if (!self.loggedOverlayLayout) {
        self.loggedOverlayLayout = YES;
        EIDLog(@"overlay layout fixed at x %.0f y %.0f, icon origin x %.0f",
               self.panel.frame.origin.x,
               self.panel.frame.origin.y,
               self.panel.frame.origin.x + self.itemIconView.frame.origin.x);
    }
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
