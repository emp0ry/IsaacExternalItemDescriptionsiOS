#import "EIDSettings.h"
#import "EIDDescriptionStore.h"
#import "EIDFeatureConfig.h"
#import "EIDPresentationConfig.h"
#import "EIDUILocalization.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>

static UIStackView *Stack(void) {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    return stack;
}
static UILabel *Label(NSString *text, CGFloat size, BOOL secondary) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.numberOfLines = 0;
    label.textColor = [UIColor colorWithWhite:secondary ? .65 : .95 alpha:1];
    label.font = [UIFont systemFontOfSize:size weight:secondary ? UIFontWeightRegular : UIFontWeightSemibold];
    return label;
}
static BOOL Enabled(NSString *key) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([key isEqual:EIDStatChangeIconsKey]) return EIDStatChangeIconsEnabled(defaults);
    if (EIDFeatureDefaults()[key]) return EIDFeatureEnabled(defaults,key);
    return [defaults objectForKey:key] ? [defaults boolForKey:key] : ![key isEqual:@"IsaacEIDBackgroundEnabled"];
}
static void Repaint(id controller) {
    [controller setValue:@YES forKey:@"descriptionNeedsRefresh"];
    SEL background = NSSelectorFromString(@"applyDescriptionBackground");
    ((void(*)(id,SEL))objc_msgSend)(controller,background);
    id selected = [controller valueForKey:@"selectedInventoryItem"];
    NSArray *pickups = selected ? @[selected] : [controller valueForKey:@"lastPickups"];
    if (pickups.count) ((void(*)(id,SEL,id))objc_msgSend)(controller,NSSelectorFromString(@"renderPickups:"),pickups);
}
static UIView *Toggle(id controller, NSString *title, NSString *key, NSString *hint) {
    UIStackView *column = Stack(); column.spacing = 4;
    UIStackView *row = [UIStackView new]; row.axis = UILayoutConstraintAxisHorizontal; row.spacing = 12;
    UILabel *label = Label(title,13,NO);
    UISwitch *control = [UISwitch new]; control.on = Enabled(key);
    control.accessibilityIdentifier = key; control.accessibilityLabel = title;
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [control setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:label]; [row addArrangedSubview:control]; row.alignment = UIStackViewAlignmentCenter;
    __weak id weakController = controller;
    __weak UISwitch *weakControl = control;
    [control addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        [NSUserDefaults.standardUserDefaults setBool:weakControl.on forKey:key];
        id host = weakController; if (host) Repaint(host);
    }] forControlEvents:UIControlEventValueChanged];
    [column addArrangedSubview:row];
    if (hint.length) [column addArrangedSubview:Label(hint,11,YES)];
    return column;
}
static UIView *Slider(id controller, NSString *title, NSString *key, float minimum, float maximum, float fallback, NSString *language) {
    UIStackView *column = Stack(); column.spacing = 2;
    UILabel *label = Label(@"",13,NO);
    label.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    UISlider *slider = [UISlider new]; slider.minimumValue = minimum; slider.maximumValue = maximum;
    slider.accessibilityIdentifier = key; slider.accessibilityLabel = title;
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
    slider.value = stored && isfinite(stored.doubleValue) ? MIN(maximum,MAX(minimum,stored.doubleValue)) : fallback;
    __weak UISlider *weakSlider = slider;
    __weak UILabel *weakLabel = label;
    void (^refresh)(void) = ^{
        weakLabel.text = [NSString stringWithFormat:@"%@: %.0f%%",title,weakSlider.value*100];
        weakSlider.accessibilityValue = [NSString stringWithFormat:@"%.0f%%",weakSlider.value*100];
    };
    refresh();
    __weak id weakController = controller;
    [slider addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        [NSUserDefaults.standardUserDefaults setDouble:weakSlider.value forKey:key];
        refresh(); id host = weakController; if (host) Repaint(host);
    }] forControlEvents:UIControlEventValueChanged];
    UIStackView *row = [UIStackView new]; row.axis = UILayoutConstraintAxisHorizontal; row.spacing = 10;
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:EIDUIString(language,@"Reset") forState:UIControlStateNormal];
    reset.accessibilityIdentifier = [key stringByAppendingString:@"Reset"];
    [reset addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        weakSlider.value = fallback;
        [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
        refresh(); id host = weakController; if (host) Repaint(host);
    }] forControlEvents:UIControlEventTouchUpInside];
    [row addArrangedSubview:slider]; [row addArrangedSubview:reset];
    [reset.widthAnchor constraintGreaterThanOrEqualToConstant:56].active = YES;
    [slider.widthAnchor constraintGreaterThanOrEqualToConstant:90].active = YES;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
    [column addArrangedSubview:label]; [column addArrangedSubview:row];
    return column;
}
static UIView *Position(id controller, BOOL vertical, NSString *language) {
    UIStackView *column = Stack(); column.spacing = 2;
    UILabel *label = [controller valueForKey:vertical ? @"settingsVerticalPositionLabel" : @"settingsPositionLabel"];
    UISlider *slider = [controller valueForKey:vertical ? @"settingsVerticalPositionSlider" : @"settingsPositionSlider"];
    [label removeFromSuperview]; [slider removeFromSuperview];
    UIStackView *row = [UIStackView new]; row.axis = UILayoutConstraintAxisHorizontal; row.spacing = 10;
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:EIDUIString(language,@"Reset") forState:UIControlStateNormal];
    [reset addTarget:controller action:NSSelectorFromString(vertical ? @"resetVerticalPosition:" : @"resetPosition:") forControlEvents:UIControlEventTouchUpInside];
    [row addArrangedSubview:slider]; [row addArrangedSubview:reset];
    [reset.widthAnchor constraintGreaterThanOrEqualToConstant:56].active = YES;
    [slider.widthAnchor constraintGreaterThanOrEqualToConstant:90].active = YES;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
    [column addArrangedSubview:label]; [column addArrangedSubview:row];
    return column;
}

void EIDBuildSettings(id controller) {
    UIView *card = [controller valueForKey:@"settingsCard"], *root = [controller valueForKey:@"rootView"];
    if (!card || !root) return;
    EIDDescriptionStore *store = [controller valueForKey:@"store"];
    NSString *code = store.languageCode;
    UIView *oldPages = [card viewWithTag:0xE1D5];
    if ([oldPages.accessibilityIdentifier isEqual:code]) return;
    UISegmentedControl *oldTabs = (UISegmentedControl *)[card viewWithTag:0xE1D6];
    NSInteger selectedTab = oldTabs ? oldTabs.selectedSegmentIndex : 0;
    NSString *(^text)(NSString *) = ^(NSString *key) { return EIDUIString(code,key); };
    CGFloat width = MIN(440,root.bounds.size.width-28), height = MIN(550,root.bounds.size.height-24);
    card.frame = CGRectMake((root.bounds.size.width-width)/2,(root.bounds.size.height-height)/2,width,height);
    card.clipsToBounds = YES;
    UILabel *version = [controller valueForKey:@"settingsVersionLabel"];
    UIButton *language = [controller valueForKey:@"settingsLanguageButton"];
    for (UIView *view in card.subviews.copy) {
        BOOL title = view.tag == 0xE1D7 || ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqual:@"Isaac EID Settings"]);
        BOOL close = [view isKindOfClass:UIButton.class] && [[((UIButton *)view) titleForState:UIControlStateNormal] isEqual:@"×"];
        if (title) { view.tag = 0xE1D7; view.frame = CGRectMake(16,10,width-70,28); ((UILabel *)view).text = text(@"EID Settings"); }
        else if (close) view.frame = CGRectMake(width-48,7,38,36);
        else [view removeFromSuperview];
    }
    UISegmentedControl *tabs = [[UISegmentedControl alloc] initWithItems:
        @[text(@"Content"),text(@"Layout"),text(@"Appearance"),text(@"Advanced")]];
    tabs.tag = 0xE1D6;
    tabs.frame = CGRectMake(14,47,width-28,32); tabs.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    tabs.selectedSegmentIndex = MIN(3,MAX(0,selectedTab)); tabs.accessibilityIdentifier = @"IsaacEIDSettingsSections";
    [card addSubview:tabs];
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0,89,width,height-99)];
    scroll.tag = 0xE1D4; scroll.alwaysBounceVertical = YES;
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.showsVerticalScrollIndicator = YES;
    [card addSubview:scroll];
    UIStackView *pages = Stack(); pages.tag = 0xE1D5; pages.translatesAutoresizingMaskIntoConstraints = NO;
    pages.accessibilityIdentifier = code;
    [scroll addSubview:pages];
    [NSLayoutConstraint activateConstraints:@[
        [pages.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [pages.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [pages.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],
        [pages.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [pages.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    UIStackView *content = Stack(), *layout = Stack(), *appearance = Stack(), *advanced = Stack();
    NSArray<UIStackView *> *sections = @[content,layout,appearance,advanced];
    // Only attach the selected page: hiding a nested stack with required row
    // heights would produce UISV-hiding constraint conflicts on small screens.
    [pages addArrangedSubview:sections[(NSUInteger)tabs.selectedSegmentIndex]];
    [content addArrangedSubview:Label(text(@"Language"),13,NO)];
    language.translatesAutoresizingMaskIntoConstraints = NO;
    BOOL hasLanguageHeight = NO;
    for (NSLayoutConstraint *constraint in language.constraints)
        if ([constraint.identifier isEqual:@"EIDLanguageControlHeight"]) hasLanguageHeight = YES;
    if (!hasLanguageHeight) {
        NSLayoutConstraint *constraint = [language.heightAnchor constraintGreaterThanOrEqualToConstant:40];
        constraint.identifier = @"EIDLanguageControlHeight"; constraint.active = YES;
    }
    [content addArrangedSubview:language];
    NSArray *names = @[text(@"Item name"),text(@"Item icon"),text(@"Quality"),text(@"Description")];
    NSArray *keys = @[@"IsaacEIDShowItemName",@"IsaacEIDShowItemIcon",@"IsaacEIDShowQuality",@"IsaacEIDShowItemDescription"];
    for (NSUInteger i=0;i<keys.count;++i) [content addArrangedSubview:Toggle(controller,names[i],keys[i],nil)];
    [content addArrangedSubview:Toggle(controller,text(@"Stat icons after arrows"),EIDStatChangeIconsKey,nil)];
    version.numberOfLines = 0; version.font = [UIFont systemFontOfSize:10];
    [content addArrangedSubview:version];
    [layout addArrangedSubview:Position(controller,NO,code)];
    [layout addArrangedSubview:Position(controller,YES,code)];
    [layout addArrangedSubview:Slider(controller,text(@"Scale"),@"IsaacEIDScale",.5,EIDMaximumScalePercent/100.,1,code)];
    [layout addArrangedSubview:Slider(controller,text(@"Text width"),EIDTextWidthKey,1,3,1,code)];
    [layout addArrangedSubview:Label(text(@"Width hint"),11,YES)];
    [appearance addArrangedSubview:Slider(controller,text(@"Text opacity"),@"IsaacEIDTransparency",.15,1,.75,code)];
    [appearance addArrangedSubview:Toggle(controller,text(@"Description background"),@"IsaacEIDBackgroundEnabled",text(@"Pause background hint"))];
    [appearance addArrangedSubview:Slider(controller,text(@"Background opacity"),@"IsaacEIDBackgroundOpacity",0,1,.28,code)];
    [advanced addArrangedSubview:Toggle(controller,text(@"RNG predictions (spoilers)"),EIDOutcomesKey,text(@"RNG hint"))];
    [advanced addArrangedSubview:Toggle(controller,text(@"Void / Black Rune stat previews"),EIDVoidStatInfoKey,nil)];
    [advanced addArrangedSubview:Toggle(controller,text(@"Hidden current effects"),EIDHiddenInfoKey,nil)];
    __weak UIScrollView *weakScroll = scroll;
    __weak UISegmentedControl *weakTabs = tabs;
    __weak UIStackView *weakPages = pages;
    [tabs addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        UIStackView *host = weakPages;
        for (UIView *page in host.arrangedSubviews.copy) { [host removeArrangedSubview:page]; [page removeFromSuperview]; }
        NSInteger index = weakTabs.selectedSegmentIndex;
        if (index>=0 && (NSUInteger)index<sections.count) [host addArrangedSubview:sections[(NSUInteger)index]];
        [host layoutIfNeeded]; [weakScroll setContentOffset:CGPointZero animated:NO];
    }] forControlEvents:UIControlEventValueChanged];
}
