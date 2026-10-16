#import <Foundation/Foundation.h>

// Pure presentation function: applies imported static EID conditionals without
// writing game state or calling native gameplay functions.
FOUNDATION_EXPORT NSString *EIDContextDescription(NSString *detail,
    NSInteger variant, NSInteger subtype, NSInteger playerType,
    NSInteger difficulty, NSDictionary *context);

// Owned keys are read-only native inventory identities (e.g. "5.100.52").
// An empty/unavailable snapshot never invents an item synergy.
FOUNDATION_EXPORT NSString *EIDContextDescriptionWithOwnedItems(NSString *detail,
    NSInteger variant, NSInteger subtype, NSInteger playerType,
    NSInteger difficulty, NSSet<NSString *> *ownedItems, NSDictionary *context);

// Append a collection-page notice only from a validated active-slot snapshot.
FOUNDATION_EXPORT NSString *EIDCollectionDescription(NSString *detail,
    NSInteger variant, NSInteger subtype, NSDictionary *context);

// Shared by the ordinary description and Pandora's floor-highlight matcher.
FOUNDATION_EXPORT NSString *EIDUnlockDescription(NSString *detail,
    NSInteger variant, NSInteger subtype, NSDictionary *context);

// Original SingleUseCallback, independent of charges (many reusable actives
// also have zero charges). The imported exact ID allowlist is authoritative.
FOUNDATION_EXPORT NSString *EIDSingleUseDescription(NSString *detail,
    NSInteger variant, NSInteger subtype, NSDictionary *context);
