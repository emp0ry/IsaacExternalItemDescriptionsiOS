#import <Foundation/Foundation.h>

// Conditional ownership is deliberately separate from physical inventory.
static inline NSArray<NSDictionary *> *EIDRelevantPlayers(NSDictionary *context) {
    NSArray *players = context[@"live_state"][@"players"];
    if (![players isKindOfClass:NSArray.class]) return @[];
    if (![context[@"inside_item_reminder"] boolValue]) return players;
    NSMutableArray *selected = [NSMutableArray array];
    for (NSDictionary *player in players) {
        if (context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]]
            : [player[@"type"] isEqual:context[@"player_type"]]) [selected addObject:player];
    }
    return selected.copy;
}

static inline NSSet<NSString *> *EIDConditionalOwnedItems(NSSet<NSString *> *fallback, NSDictionary *context) {
    if (![context[@"live_state"][@"players"] isKindOfClass:NSArray.class]) return fallback;
    // The caller already resolved physical ownership (including fail-closed
    // empty snapshots). Add only validated Void abilities, never another
    // player's physical items or a cached fallback inventory.
    NSMutableSet *owned = fallback.mutableCopy ?: [NSMutableSet set];
    NSArray *activeIDs = context[@"native_metadata"][@"active_ids"];
    for (NSDictionary *player in EIDRelevantPlayers(context)) {
        if (![player[@"owned"] isKindOfClass:NSArray.class]) continue;
        if (![player[@"owned"] containsObject:@"5.100.477"]) continue;
        for (NSNumber *item in player[@"void_actives"])
            if ([item isKindOfClass:NSNumber.class] && item.integerValue!=477 && [activeIDs containsObject:item])
                [owned addObject:[NSString stringWithFormat:@"5.100.%@",item]];
    }
    return owned.copy;
}
