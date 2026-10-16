#import "EIDCharacterSynergies.h"
#import "EIDContextPlayers.h"
#include <math.h>

static NSString *Template(NSString *text, NSDictionary *variables) {
    if (![text isKindOfClass:NSString.class]) return @"";
    for (NSString *key in variables) text = [text stringByReplacingOccurrencesOfString:
        [NSString stringWithFormat:@"{%@}",key] withString:variables[key]];
    return text;
}

static NSString *Append(NSString *detail, NSString *text, NSString *icon) {
    if (![text isKindOfClass:NSString.class] || !text.length) return detail;
    NSString *prefix = icon.length ? [NSString stringWithFormat:@"{{%@}} ",icon] : @"";
    text = [text stringByReplacingOccurrencesOfString:@"#" withString:[@"#" stringByAppendingString:prefix]];
    return [detail stringByAppendingFormat:@"#%@%@",prefix,text];
}

static NSSet *ClosestOwned(NSInteger type, NSSet *fallback, NSDictionary *context) {
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        BOOL selected = context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]]
            : [player[@"type"] integerValue] == type;
        if (selected && [player[@"owned"] isKindOfClass:NSArray.class])
            return [NSSet setWithArray:player[@"owned"]];
    }
    return [context[@"live_state"][@"players"] count] ? [NSSet set] : fallback;
}

static BOOL HasPassiveBelial(NSInteger type, NSSet *owned, NSDictionary *context) {
    NSArray *players = context[@"live_state"][@"players"];
    if (!players.count) return [owned containsObject:@"5.100.59"];
    BOOL reminder = [context[@"inside_item_reminder"] boolValue];
    for (NSDictionary *player in players) {
        BOOL selected = context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]]
            : [player[@"type"] integerValue] == type;
        if (reminder && !selected) continue;
        NSNumber *effective = player[@"has_passive_belial"];
        if ([effective isKindOfClass:NSNumber.class] && effective.boolValue) return YES;
    }
    return NO;
}

BOOL EIDUsesSalvageDescription(NSInteger variant, NSInteger subtype, NSInteger playerType, NSDictionary *context) {
    NSDictionary *state = context[@"live_state"], *metadata = context[@"native_metadata"];
    BOOL ownedKnown = NO;
    for (NSDictionary *player in state[@"players"]) {
        BOOL selected = [context[@"player_type"] integerValue] == 23 && context[@"player_index"]
            ? [player[@"index"] isEqual:context[@"player_index"]] : YES;
        if (selected && [player[@"type"] integerValue] == 23 && [player[@"owned"] isKindOfClass:NSArray.class]) ownedKnown = YES;
    }
    return variant == 100 && playerType == 23 && ![context[@"inside_item_reminder"] boolValue] &&
        ownedKnown &&
        [state[@"salvage_allowed"] boolValue] && [metadata[@"quest_metadata_available"] boolValue] &&
        [context[@"context_strings"][@"TaintedCainPedestalBase"] length] &&
        ![metadata[@"quest_ids"] containsObject:@(subtype)];
}

static NSString *PickupName(NSString *key, NSDictionary *context) {
    NSString *name = context[@"pickup_names"][key];
    if (![name isKindOfClass:NSString.class]) return @"";
    NSRegularExpression *markup = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{[^}]+\\}\\}\\s*" options:0 error:nil];
    return [markup stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0,name.length) withTemplate:@""];
}

static NSString *Salvage(NSInteger playerType, NSSet *owned, NSDictionary *context) {
    owned = ClosestOwned(playerType,owned,context);
    BOOL birthright = [owned containsObject:@"5.100.619"];
    NSDictionary *texts = context[@"context_strings"], *metadata = context[@"character_metadata"];
    NSString *detail = texts[birthright ? @"TaintedCainPedestalBaseBirthright" : @"TaintedCainPedestalBase"];
    if (![detail isKindOfClass:NSString.class]) return nil;
    detail = [@"{{Player23}} " stringByAppendingString:detail];
    NSNumber *pool = context[@"live_state"][@"room_pool"], *room = context[@"live_state"][@"room_type"];
    NSString *guaranteed = metadata[@"salvage_pools"][pool.stringValue];
    if (guaranteed && room.integerValue != 3) {
        NSString *name = PickupName(guaranteed,context);
        if (name.length) detail = Append(detail,Template(texts[@"TaintedCainPedestalGuaranteed"],
            @{@"1":name,@"n":[metadata[@"salvage_vowels"][guaranteed] boolValue] ? @"n" : @""}),nil);
    }
    NSDictionary *trinkets = metadata[@"salvage_trinkets"];
    for (NSString *key in [trinkets.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if (![owned containsObject:[@"5.350." stringByAppendingString:key]]) continue;
        NSString *name = PickupName(trinkets[key],context);
        if (name.length) detail = Append(detail,Template(texts[@"TaintedCainPedestalBonus"],@{@"1":name}),
            [@"Trinket" stringByAppendingString:key]);
    }
    if ([owned containsObject:@"5.350.42"]) detail = Append(detail,
        texts[birthright ? @"TaintedCainPedestalLuckyToeBirthright" : @"TaintedCainPedestalLuckyToe"],@"Trinket42");
    if ([owned containsObject:@"5.350.22"]) detail = Append(detail,texts[@"TaintedCainPedestalDaemonsTail"],@"Trinket22");
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        NSNumber *type = player[@"type"];
        NSArray *entry = context[@"birthright"][type.stringValue];
        if (type.integerValue != 23 && entry.count) detail = Append(detail,
            Template(context[@"conditionals"][@"Different Effect"],@{@"1":entry[0]}),nil);
    }
    return detail;
}

static NSString *Number(double value) {
    NSString *text = [NSString stringWithFormat:@"%.2f",value];
    while ([text hasSuffix:@"0"]) text = [text substringToIndex:text.length-1];
    return [text hasSuffix:@"."] ? [text substringToIndex:text.length-1] : text;
}

static NSString *Wisp(NSInteger item, NSDictionary *context) {
    NSDictionary *texts = context[@"wisp_texts"], *metadata = context[@"character_metadata"];
    NSString *extra = context[@"wisp_extras"][@(item).stringValue];
    NSArray *data = metadata[@"wisps"][@(item).stringValue];
    NSString *detail = @"";
    if ([data isKindOfClass:NSArray.class] && data.count == 12) {
        if ([metadata[@"wisp_flags"][@"NoWisp"][@(item).stringValue] boolValue]) detail = texts[@"NoWisps"] ?: @"";
        else {
            BOOL shooting = [data[8] boolValue] && [data[6] doubleValue] > 0;
            NSNumber *stage = context[@"live_state"][@"floor"][@"stage"];
            NSString *damage = !shooting ? @"-" : stage ? Number(([data[2] doubleValue] +
                [data[3] doubleValue]*(stage.integerValue-1))*30/[data[6] doubleValue]) : @"?";
            NSInteger ring = [data[1] integerValue];
            NSArray *rings = @[@"{{StationaryWisp}}",@"{{InnerWisp}}",@"{{MiddleWisp}}",@"{{OuterWisp}}"];
            NSString *amount = [data[9] integerValue] ? [data[9] stringValue] : @"";
            detail = Template(texts[@"StatDescription"],@{@"ringIcon":rings[(NSUInteger)MAX(0,MIN(3,ring+1))],
                @"amount":amount,@"health":Number([data[0] doubleValue]),@"damage":damage});
            if ([metadata[@"wisp_flags"][@"SingleRoom"][@(item).stringValue] boolValue])
                detail = Append(detail,texts[@"SingleRoom"],@"Warning");
            if (shooting) {
                if ([data[5] doubleValue] != 1) detail = Append(detail,
                    Template(texts[@"Shotspeed"],@{@"1":Number([data[5] doubleValue]*100)}),@"Shotspeed");
                double chance = [data[7] doubleValue];
                NSString *chanceText = chance == 1 ? @"" : Template(texts[@"Chance"],@{@"1":Number(chance*100)});
                if ([data[4] doubleValue] != 1) detail = Append(detail,[Template(texts[@"Damage"],
                    @{@"1":Number([data[4] doubleValue]*100)}) stringByAppendingString:chanceText],@"Damage");
                for (NSUInteger index = 10; index < 12; ++index) {
                    // Standard Repentance only triggers the first flag per bank.
                    NSArray *flags = data[index];
                    NSString *flag = flags.count ? context[@"tear_flags"][[flags[0] stringValue]] : nil;
                    if (flag.length) detail = Append(detail,[flag stringByAppendingString:chanceText],@"Shotspeed");
                }
            }
        }
    }
    if (extra.length) detail = detail.length ? [detail stringByAppendingFormat:@"#%@",extra] : extra;
    detail = Template(detail,@{@"pluralize":data.count > 9 && [data[9] integerValue] != 1 ? @"s" : @""});
    if (!detail.length) return @"";
    // Reuse the existing collectible icon and the original wisp/ring atlas.
    NSString *prefix = [NSString stringWithFormat:@"{{Collectible%ld}} {{ColorPastelBlue}}",(long)item];
    return [prefix stringByAppendingString:[detail stringByReplacingOccurrencesOfString:@"#"
        withString:@"#{{ColorPastelBlue}}"]];
}

NSString *EIDCharacterSynergyDescription(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger playerType, NSSet<NSString *> *owned, NSDictionary *context) {
    if (variant != 100) return detail;
    if (EIDUsesSalvageDescription(variant,subtype,playerType,context)) return Salvage(playerType,owned,context) ?: detail;
    if ([context[@"inside_item_reminder"] boolValue]) owned = ClosestOwned(playerType,owned,context);
    owned = EIDConditionalOwnedItems(owned,context);
    NSArray *activeIDs = context[@"native_metadata"][@"active_ids"];
    BOOL active = [activeIDs containsObject:@(subtype)];
    if (active && HasPassiveBelial(playerType,owned,context))
        detail = Append(detail,context[@"book_of_belial"][@(subtype).stringValue],@"Collectible59");
    if (subtype == 584 && ![context[@"inside_item_reminder"] boolValue]) {
        NSMutableArray *actives = [NSMutableArray array];
        for (NSDictionary *player in EIDRelevantPlayers(context)) {
            NSArray *slots = player[@"active_slots"];
            NSNumber *item = slots.count==4 ? slots[0] : nil;
            if (item && item.integerValue>0 && [activeIDs containsObject:item]) [actives addObject:item];
        }
        for (NSNumber *item in actives)
            detail = Append(detail,Wisp(item.integerValue,context),nil);
    } else if (active && [owned containsObject:@"5.100.584"]) detail = Append(detail,Wisp(subtype,context),nil);
    if (EIDUsesSalvageDescription(variant,subtype,23,context)) {
        for (NSDictionary *player in context[@"live_state"][@"players"]) {
            if ([player[@"type"] integerValue] != 23) continue;
            NSArray *entry = context[@"birthright"][@"23"];
            NSString *notice = entry.count ? Template(context[@"conditionals"][@"Different Effect"],@{@"1":entry[0]}) : @"";
            if (notice.length && ![detail containsString:notice]) detail = Append(detail,notice,nil);
            break;
        }
    }
    return detail;
}
