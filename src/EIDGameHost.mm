#import "EIDGameHost.h"
#import "EIDLogger.h"
#include "EIDHostReadinessPolicy.hpp"
#import <objc/runtime.h>

static UIView *IsaacRenderView(UIView *root, Class renderClass, NSUInteger *budget) {
    if (!root || !*budget || root.hidden || root.alpha <= .01) return nil;
    --*budget;
    if ([root isKindOfClass:renderClass]) return root;
    for (UIView *child in root.subviews) {
        UIView *found = IsaacRenderView(child,renderClass,budget);
        if (found) return found;
    }
    return nil;
}

UIWindow *EIDReadyGameWindow(void) {
    static EIDHostReadinessPolicy::Frames frames;
    static __weak UIWindow *loggedWindow;
    if (!NSThread.isMainThread) return nil;
    UIApplication *application = UIApplication.sharedApplication;
    if (application.applicationState != UIApplicationStateActive) {
        frames.Observe(false,0,0,0,0,0,0);
        return nil;
    }
    // LiveContainer's host may already be active while the guest is still
    // launching. ApplicationStateActive alone is not guest readiness.
    Class renderClass = NSClassFromString(@"AAPLOpenGLView");
    Class controllerClass = NSClassFromString(@"AAPLOpenGLViewController");
    // Do not require a particular application-delegate class: LiveContainer
    // versions may proxy it. The actual guest render view/controller are the
    // identity boundary, not the host's delegate or key-window status.
    if (!renderClass || !controllerClass) return nil;
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    if ([application.delegate respondsToSelector:@selector(window)]) {
        UIWindow *window = application.delegate.window;
        if (window) [windows addObject:window];
    }
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows)
            if (![windows containsObject:window]) [windows addObject:window];
    }
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= .01 || window.windowLevel != UIWindowLevelNormal || CGRectIsEmpty(window.bounds)) continue;
        // viewIfLoaded avoids forcing guest controller/virtual-control setup.
        UIView *root = window.rootViewController.viewIfLoaded;
        NSUInteger budget = 256;
        UIView *render = IsaacRenderView(root,renderClass,&budget);
        if (!render || render.window != window) continue;
        UIResponder *responder = render.nextResponder;
        for (NSUInteger depth = 0; responder && depth < 32; ++depth) {
            if ([responder isKindOfClass:controllerClass]) break;
            responder = responder.nextResponder;
        }
        if (![responder isKindOfClass:controllerClass]) continue;
        // The supported native controller owns _displayLink. Merely finding a
        // loaded view is insufficient: wait for two observed native frame times.
        Ivar ivar = class_getInstanceVariable(controllerClass,"_displayLink");
        const char *encoding = ivar ? ivar_getTypeEncoding(ivar) : nullptr;
        if (!encoding || encoding[0] != '@') continue;
        id value = object_getIvar(responder,ivar);
        if (![value isKindOfClass:CADisplayLink.class]) continue;
        CADisplayLink *link = value;
        if (!frames.Observe(true,(uintptr_t)(__bridge void *)window,(uintptr_t)(__bridge void *)render,
            (uintptr_t)(__bridge void *)link,link.timestamp,render.bounds.size.width,render.bounds.size.height)) return nil;
        if (loggedWindow != window) {
            loggedWindow = window;
            EIDLog(@"Isaac render host ready after native frames: %.0fx%.0f; single-window overlay",
                render.bounds.size.width,render.bounds.size.height);
        }
        return window;
    }
    frames.Observe(false,0,0,0,0,0,0);
    return nil;
}
