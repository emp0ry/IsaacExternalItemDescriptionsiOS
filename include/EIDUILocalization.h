#import <Foundation/Foundation.h>

// UI language follows EID's selected description language, not iOS or Isaac.
FOUNDATION_EXPORT NSString *EIDUIString(NSString *language, NSString *key);
FOUNDATION_EXPORT NSArray<NSString *> *EIDUIKeys(void);
FOUNDATION_EXPORT NSArray<NSString *> *EIDUILanguages(void);
