#import <Foundation/Foundation.h>

// Older resource bundles contain the literal REP/AB frames but omit Lua's
// dynamically assigned stat aliases. Resolve only the supported Repentance set.
static inline NSString *EIDRepentanceStatIconAlias(NSString *token) {
    if ([@[@"Damage", @"Speed", @"Tears", @"Range", @"Shotspeed", @"Luck",
           @"AngelChance", @"DevilChance", @"Tearsize"] containsObject:token]) {
        return [token stringByAppendingString:@"REP"];
    }
    return nil;
}
