#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *EIDTransformResourcePath(void) {
    NSString *main = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *roots = @[
        [main stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/Resources/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/IsaacEID.bundle"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions"],
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",
        @"/Library/Application Support/IsaacExternalItemDescriptions"
    ];
    for (NSString *root in roots) {
        NSString *path = [root stringByAppendingPathComponent:@"transformations.json"];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    NSBundle *framework = [NSBundle bundleForClass:NSClassFromString(@"EIDOverlayController") ?: NSObject.class];
    for (NSString *relative in @[@"Resources/IsaacEID.bundle/transformations.json", @"IsaacEID.bundle/transformations.json", @"transformations.json"]) {
        NSString *path = [framework.bundlePath stringByAppendingPathComponent:relative];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

@interface EIDTransformationProgress : NSObject
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<NSNumber *> *> *assignments;
@property(nonatomic) NSInteger required;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *takenCollectibles;
@property(nonatomic, strong) NSSet<NSNumber *> *previousVisibleCollectibles;
@property(nonatomic) NSUInteger nonGameplayScans;
+ (instancetype)shared;
- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible;
- (NSInteger)progressForTransformation:(NSInteger)transformation;
- (void)observePickups:(NSArray<EIDPickupIdentity *> *)pickups gameplayActive:(BOOL)gameplayActive;
- (void)observeGameplayActive:(BOOL)gameplayActive;
@end

@implementation EIDTransformationProgress
+ (instancetype)shared {
    static EIDTransformationProgress *tracker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ tracker = [EIDTransformationProgress new]; });
    return tracker;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _takenCollectibles = [NSMutableSet set];
    _previousVisibleCollectibles = [NSSet set];
    _required = 3;

    NSString *path = EIDTransformResourcePath();
    NSData *data = path.length ? [NSData dataWithContentsOfFile:path] : nil;
    NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *rawAssignments = [json[@"assignments"] isKindOfClass:NSDictionary.class] ? json[@"assignments"] : nil;
    if (rawAssignments) _assignments = rawAssignments;
    NSNumber *required = [json[@"required"] isKindOfClass:NSNumber.class] ? json[@"required"] : nil;
    if (required.integerValue > 0) _required = required.integerValue;
    EIDLog(@"temporary transformation tracker loaded %lu assignments; requirement %ld",
           (unsigned long)_assignments.count, (long)_required);
    return self;
}

- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible {
    if (collectible <= 0) return @[];
    NSArray *values = self.assignments[[NSString stringWithFormat:@"100:%ld", (long)collectible]];
    return [values isKindOfClass:NSArray.class] ? values : @[];
}

- (NSInteger)progressForTransformation:(NSInteger)transformation {
    if (transformation <= 0) return 0;
    NSInteger count = 0;
    for (NSNumber *collectible in self.takenCollectibles) {
        NSArray<NSNumber *> *transforms = [self transformationsForCollectible:collectible.integerValue];
        for (NSNumber *value in transforms) {
            if (value.integerValue == transformation) {
                count++;
                break;
            }
        }
        if (count >= self.required) return self.required;
    }
    return MIN(self.required, count);
}

- (void)resetForNewRun {
    if (self.takenCollectibles.count || self.previousVisibleCollectibles.count) {
        EIDLog(@"temporary transformation progress reset for new run");
    }
    [self.takenCollectibles removeAllObjects];
    self.previousVisibleCollectibles = [NSSet set];
}

- (void)observeGameplayActive:(BOOL)gameplayActive {
    if (!gameplayActive) {
        if (self.nonGameplayScans < 1000) self.nonGameplayScans++;
        return;
    }
    if (self.nonGameplayScans >= 12) [self resetForNewRun];
    self.nonGameplayScans = 0;
}

- (void)observePickups:(NSArray<EIDPickupIdentity *> *)pickups gameplayActive:(BOOL)gameplayActive {
    [self observeGameplayActive:gameplayActive];
    if (!gameplayActive) {
        self.previousVisibleCollectibles = [NSSet set];
        return;
    }

    NSMutableSet<NSNumber *> *current = [NSMutableSet set];
    for (EIDPickupIdentity *pickup in pickups) {
        if (pickup.variant == EIDPickupVariantCollectible && pickup.subtype > 0) {
            [current addObject:@(pickup.subtype)];
        }
    }

    NSMutableSet<NSNumber *> *removed = [self.previousVisibleCollectibles mutableCopy];
    [removed minusSet:current];
    for (NSNumber *collectible in removed) {
        if ([self.takenCollectibles containsObject:collectible]) continue;
        NSArray<NSNumber *> *transforms = [self transformationsForCollectible:collectible.integerValue];
        if (!transforms.count) continue;
        [self.takenCollectibles addObject:collectible];
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (NSNumber *transform in transforms) {
            NSInteger progress = [self progressForTransformation:transform.integerValue];
            [parts addObject:[NSString stringWithFormat:@"%ld=%ld/%ld", (long)transform.integerValue,
                              (long)progress, (long)self.required]];
        }
        EIDLog(@"remembered transformation collectible %@ (%@)", collectible,
               [parts componentsJoinedByString:@", "]);
    }
    self.previousVisibleCollectibles = current.copy;
}
@end

static NSAttributedString *EIDReplaceProgressInText(NSAttributedString *source,
                                                     NSArray<NSNumber *> *transforms) {
    if (!source.length || !transforms.count) return source;
    NSMutableAttributedString *result = [source mutableCopy];
    NSString *needle = @"(0/3)";
    NSUInteger searchStart = 0;
    for (NSNumber *transform in transforms) {
        if (searchStart >= result.length) break;
        NSRange searchRange = NSMakeRange(searchStart, result.length - searchStart);
        NSRange range = [result.string rangeOfString:needle options:0 range:searchRange];
        if (range.location == NSNotFound) break;
        NSInteger progress = [[EIDTransformationProgress shared] progressForTransformation:transform.integerValue];
        NSInteger required = [EIDTransformationProgress shared].required;
        NSString *replacement = [NSString stringWithFormat:@"(%ld/%ld)", (long)progress, (long)required];
        NSDictionary *attributes = range.location < result.length ? [result attributesAtIndex:range.location effectiveRange:nil] : @{};
        [result replaceCharactersInRange:range withAttributedString:
            [[NSAttributedString alloc] initWithString:replacement attributes:attributes]];
        searchStart = range.location + replacement.length;
    }
    return result;
}

@interface NSObject (EIDTransformationProgressHooks)
- (void)eid_progress_renderPickups:(NSArray<EIDPickupIdentity *> *)pickups;
- (void)eid_progress_updateMenuModeForGameplay:(BOOL)gameplayActive;
@end

@implementation NSObject (EIDTransformationProgressHooks)
- (void)eid_progress_renderPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    EIDNativeProbe *probe = nil;
    @try { probe = [self valueForKey:@"probe"]; } @catch (__unused NSException *exception) {}
    BOOL gameplayActive = probe ? probe.gameplayActive : YES;
    [[EIDTransformationProgress shared] observePickups:pickups gameplayActive:gameplayActive];

    [self eid_progress_renderPickups:pickups];

    EIDPickupIdentity *shown = pickups.firstObject;
    if (!shown || shown.variant != EIDPickupVariantCollectible) return;
    NSArray<NSNumber *> *transforms = [[EIDTransformationProgress shared] transformationsForCollectible:shown.subtype];
    if (!transforms.count) return;

    __weak id weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        id strongSelf = weakSelf;
        if (!strongSelf) return;
        UILabel *label = nil;
        @try { label = [strongSelf valueForKey:@"label"]; } @catch (__unused NSException *exception) {}
        if (![label isKindOfClass:UILabel.class] || !label.attributedText.length) return;
        label.attributedText = EIDReplaceProgressInText(label.attributedText, transforms);
    });
}

- (void)eid_progress_updateMenuModeForGameplay:(BOOL)gameplayActive {
    [[EIDTransformationProgress shared] observeGameplayActive:gameplayActive];
    [self eid_progress_updateMenuModeForGameplay:gameplayActive];
}
@end

static void EIDInstallProgressHook(void) {
    Class cls = NSClassFromString(@"EIDOverlayController");
    if (!cls) return;

    struct Hook { SEL original; SEL replacement; } hooks[] = {
        { NSSelectorFromString(@"renderPickups:"), @selector(eid_progress_renderPickups:) },
        { NSSelectorFromString(@"updateMenuModeForGameplay:"), @selector(eid_progress_updateMenuModeForGameplay:) },
    };
    for (const auto &hook : hooks) {
        Method source = class_getInstanceMethod(NSObject.class, hook.replacement);
        if (!source) continue;
        class_addMethod(cls, hook.replacement, method_getImplementation(source), method_getTypeEncoding(source));
        Method original = class_getInstanceMethod(cls, hook.original);
        Method replacement = class_getInstanceMethod(cls, hook.replacement);
        if (original && replacement) method_exchangeImplementations(original, replacement);
    }
}

__attribute__((constructor)) static void EIDInstallTransformationProgress(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ EIDInstallProgressHook(); });
}
