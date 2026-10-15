#import "EIDDescriptionStore.h"
#import "EIDLogger.h"
#import "EIDNativeProbe.h"
#import "EIDOverlayController.h"
#import "EIDGameHost.h"
#import <UIKit/UIKit.h>

static EIDOverlayController *gEIDOverlay;
static dispatch_once_t gEIDStartOnce;
static NSTimer *gEIDStartTimer;

static void EIDStart(void) {
    dispatch_once(&gEIDStartOnce, ^{
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        EIDNativeProbe *probe = [[EIDNativeProbe alloc] init];
        BOOL isaacBundle = [bundleID isEqualToString:@"com.Nicalis.Isaac-iOS"];
        // LiveContainer can optionally retain its own bundle identifier while
        // hosting a private app. The exact executable UUID remains the stronger
        // identity check, and prevents a global tweak folder from activating EID
        // in unrelated applications.
        if (!isaacBundle && !probe.isSupportedBuild) return;
        EIDLog(@"bootstrap in %@%@", bundleID,
               isaacBundle ? @"" : @" (Isaac guest image detected)");
        EIDDescriptionStore *store = [[EIDDescriptionStore alloc] init];
        gEIDOverlay = [[EIDOverlayController alloc] initWithStore:store probe:probe];
        [gEIDOverlay start];
    });
}

static void EIDTryStartWhenReady(void) {
    if (gEIDOverlay) { [gEIDStartTimer invalidate]; gEIDStartTimer = nil; return; }
    if (!EIDReadyGameWindow()) return;
    EIDStart();
    [gEIDStartTimer invalidate];
    gEIDStartTimer = nil;
}

static void EIDScheduleStart(void) {
    if (gEIDOverlay || gEIDStartTimer) return;
    // Do not allocate the description database or attach views during the
    // host's active notification, which may precede LiveContainer guest launch.
    gEIDStartTimer = [NSTimer scheduledTimerWithTimeInterval:.1 repeats:YES block:^(__unused NSTimer *timer) {
        EIDTryStartWhenReady();
    }];
}
__attribute__((constructor)) static void EIDConstructor(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) { EIDScheduleStart(); }];
            // Scheduling only polls readiness; it never creates UIKit overlays.
            EIDScheduleStart();
        });
    }
}

__attribute__((visibility("default"))) void EIDShowCollectible(int collectibleID) {
    [gEIDOverlay showCollectibleID:collectibleID];
}

__attribute__((visibility("default"))) void EIDSetDiagnosticsEnabled(bool enabled) {
    [gEIDOverlay setDiagnosticsEnabled:enabled];
}
