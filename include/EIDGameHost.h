#import <UIKit/UIKit.h>

// Main-thread only. Never loads a controller's view or creates a window.
// Returns Isaac's own window only after its native display link has advanced.
FOUNDATION_EXPORT UIWindow * _Nullable EIDReadyGameWindow(void);
