#import "EIDDescriptionStore.h"
#import "EIDLogger.h"
#import "EIDNativeProbe.h"
#import "EIDOverlayController.h"
#import <UIKit/UIKit.h>

static EIDOverlayController *gEIDOverlay;
static dispatch_once_t gEIDStartOnce;

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
__attribute__((constructor)) static void EIDConstructor(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                                object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) { EIDStart(); }];
            [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) { EIDStart(); }];
            if (UIApplication.sharedApplication.applicationState != UIApplicationStateInactive) EIDStart();
        });
    }
}

__attribute__((visibility("default"))) void EIDShowCollectible(int collectibleID) {
    [gEIDOverlay showCollectibleID:collectibleID];
}

__attribute__((visibility("default"))) void EIDSetDiagnosticsEnabled(bool enabled) {
    [gEIDOverlay setDiagnosticsEnabled:enabled];
}
