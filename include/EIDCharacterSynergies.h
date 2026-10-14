#import <Foundation/Foundation.h>

FOUNDATION_EXPORT BOOL EIDUsesSalvageDescription(NSInteger variant, NSInteger subtype,
    NSInteger playerType, NSDictionary *context);
FOUNDATION_EXPORT NSString *EIDCharacterSynergyDescription(NSString *detail, NSInteger variant,
    NSInteger subtype, NSInteger playerType, NSSet<NSString *> *owned, NSDictionary *context);
