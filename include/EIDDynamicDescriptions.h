#import <Foundation/Foundation.h>

// Read-only display modifiers for the verified native floor/stat snapshot.
FOUNDATION_EXPORT NSString *EIDDynamicDescription(NSString *detail, NSInteger variant,
    NSInteger subtype, NSInteger difficulty, NSSet<NSString *> *ownedItems, NSDictionary *context);
