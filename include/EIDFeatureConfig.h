#import <Foundation/Foundation.h>

// Separate upstream EID controls. Never infer one permission from another.
static NSString *const EIDOutcomesKey = @"IsaacEIDOutcomePredictions";
static NSString *const EIDVoidStatInfoKey = @"IsaacEIDVoidStatInfo";
static NSString *const EIDHiddenInfoKey = @"IsaacEIDHiddenInfo";

NS_INLINE NSDictionary<NSString *, NSNumber *> *EIDFeatureDefaults(void) {
    return @{EIDOutcomesKey:@NO, EIDVoidStatInfoKey:@NO, EIDHiddenInfoKey:@NO};
}

NS_INLINE BOOL EIDFeatureEnabled(NSUserDefaults *defaults, NSString *key) {
    return [defaults objectForKey:key] ? [defaults boolForKey:key] : [EIDFeatureDefaults()[key] boolValue];
}

NS_INLINE BOOL EIDTrinketEffectVisible(NSDictionary *player, NSInteger trinket, BOOL hiddenInfo) {
    if (![player[@"owned"] containsObject:[NSString stringWithFormat:@"5.350.%ld",(long)trinket]]) return NO;
    if (trinket==32 || trinket==132 || trinket==153) return hiddenInfo;
    if (trinket!=166) return NO;
    if (hiddenInfo) return YES;
    // Original EID exposes held Clay, but swallowed-only Clay is Hidden Info.
    for (NSNumber *slot in player[@"trinket_slots"])
        if ([slot isKindOfClass:NSNumber.class] && (slot.integerValue & 0x7fff)==166) return YES;
    return NO;
}
