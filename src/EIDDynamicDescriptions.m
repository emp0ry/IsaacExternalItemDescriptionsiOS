#import "EIDDynamicDescriptions.h"
#import "EIDCharacterSynergies.h"
#include <math.h>

static NSString *PandoraSegment(NSString *text) {
    return [[text stringByReplacingOccurrencesOfString:@"{{NoLB}}" withString:@""]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *HighlightPandora(NSString *detail, NSInteger difficulty, NSSet *owned, NSDictionary *context) {
    // Desktop translations compact some floors onto semicolon-separated
    // lines. Render each payout on its own line in the iOS overlay, regardless
    // of language or whether a reliable current-floor snapshot is available.
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"#;"];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *part in [detail componentsSeparatedByCharactersInSet:separators]) {
        NSString *line = PandoraSegment(part);
        if (line.length) [lines addObject:line];
    }
    detail = [lines componentsJoinedByString:@"#"];
    NSString *strange = context[@"context_strings"][@"pandora_strange_key"];
    if ([owned containsObject:@"5.350.175"] && [strange isKindOfClass:NSString.class] && strange.length) {
        // The key replaces the entire floor-dependent payout. Keep the floor
        // reference, but highlight only the actual override, never a false prize.
        return [detail stringByAppendingFormat:@"#{{Item5.350.175}} {{ColorBagComplete}}%@{{CR}}",strange];
    }
    NSDictionary *floor = context[@"live_state"][@"floor"];
    if (![floor[@"stage"] isKindOfClass:NSNumber.class] || difficulty < 0 || difficulty > 3) return detail;
    NSInteger stage = [floor[@"stage"] integerValue];
    BOOL greed = difficulty >= 2;
    NSInteger index = 0;
    if (greed && stage >= 1 && stage <= 7) index = MIN(stage,6);
    else if (!greed && stage >= 1 && stage <= 13) {
        static const NSInteger blocks[] = {0,1,2,3,4,5,6,7,8,9,10,12,9,14};
        index = blocks[stage];
        if ((stage == 10 || stage == 11) && [floor[@"alternate"] boolValue]) ++index;
    }
    if (!index) return detail;
    NSString *key = [NSString stringWithFormat:@"%@.%ld",greed ? @"greed" : @"normal",(long)index];
    NSString *text = context[@"pandora_floor_lines"][key];
    if (![text isKindOfClass:NSString.class] || !text.length) return detail;
    text = PandoraSegment(text);
    // Exact segment equality avoids highlighting C1 inside "C2: C1 + ...".
    NSRegularExpression *segments = [NSRegularExpression regularExpressionWithPattern:@"[^#;]+" options:0 error:nil];
    for (NSTextCheckingResult *match in [segments matchesInString:detail options:0 range:NSMakeRange(0,detail.length)]) {
        if ([[detail substringWithRange:match.range] isEqualToString:text]) {
            return [detail stringByReplacingCharactersInRange:match.range withString:
                [NSString stringWithFormat:@"{{ColorBagComplete}}%@{{CR}}",text]];
        }
    }
    return detail;
}

static double Rounded(double number) { return floor(number*100.0+0.5)/100.0; }

static NSString *ConsolationPrize(NSString *detail, NSDictionary *context) {
    static NSString *const icons[] = {@"Speed",@"Tears",@"Damage",@"Range"};
    static NSString *const increases[] = {@"+0.2",@"+0.5",@"+1",@"+2.5"};
    static NSString *const pickupKeys[] = {@"5.20",@"5.40",@"5.30",@"5.10.3",@"5.10"};
    static NSString *const quantities[] = {@"3",@"1",@"1",@"1",@"2"};
    NSDictionary *statNames = context[@"stat_names"], *pickupNames = context[@"pickup_names"];
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        if (![player isKindOfClass:NSDictionary.class]) continue;
        NSArray *required = @[@"type",@"speed",@"fire_delay",@"damage",@"range",@"coins",@"bombs",@"keys"];
        BOOL valid = [player isKindOfClass:NSDictionary.class];
        for (NSString *key in required) valid &= [player[key] isKindOfClass:NSNumber.class] && isfinite([player[key] doubleValue]);
        if (!valid) continue;
        double speed = [player[@"speed"] doubleValue], delay = [player[@"fire_delay"] doubleValue];
        double damage = [player[@"damage"] doubleValue], range = [player[@"range"] doubleValue];
        NSInteger type = [player[@"type"] integerValue];
        if (type < 0 || type > 40 || speed < 0 || delay <= -1 || damage < 0 || range < 0) continue;
        double stats[] = {Rounded(speed*4.5-2), Rounded(pow(30/(delay+1),0.75)*2.120391-2),
                          Rounded(pow(damage,0.56)*2.231179-2), Rounded((range-230)/60+2)};
        double pickups[] = {[player[@"coins"] doubleValue], [player[@"bombs"] doubleValue]*3,
                            [player[@"keys"] doubleValue]*3, 9999, 9999};
        if (type == 18 || type == 36) {
            NSString *charge = type == 18 ? @"soul_charge" : @"blood_charge";
            if (![player[charge] isKindOfClass:NSNumber.class] || [player[charge] integerValue] < 0) continue;
            pickups[type == 18 ? 3 : 4] = [player[charge] doubleValue]*2-1;
        }
        double lowestStat = stats[0], lowestPickup = pickups[0];
        for (NSUInteger index = 1; index < 4; ++index) lowestStat = fmin(lowestStat,stats[index]);
        for (NSUInteger index = 1; index < 5; ++index) lowestPickup = fmin(lowestPickup,pickups[index]);
        NSUInteger statMatches = 0, pickupMatches = 0;
        for (NSUInteger index = 0; index < 4; ++index) statMatches += stats[index] == lowestStat;
        for (NSUInteger index = 0; index < 5; ++index) pickupMatches += pickups[index] == lowestPickup;
        NSArray *character = context[@"birthright"][@(type).stringValue];
        NSString *name = [character isKindOfClass:NSArray.class] && character.count ? character[0] : @"";
        NSMutableArray *lines = [NSMutableArray array];
        if ([name isKindOfClass:NSString.class] && name.length) [lines addObject:[NSString stringWithFormat:@"{{ColorGray}}%@{{CR}}",name]];
        for (NSUInteger index = 0; index < 4; ++index) {
            if (stats[index] != lowestStat) continue;
            NSString *text = statNames[@(index+1).stringValue];
            if (![text isKindOfClass:NSString.class] || !text.length) continue;
            text = [text containsString:@"{1}"] ? [text stringByReplacingOccurrencesOfString:@"{1}" withString:increases[index]]
                                               : [NSString stringWithFormat:@"%@ %@",increases[index],text];
            [lines addObject:[NSString stringWithFormat:@"↑ {{%@}} %@%@",icons[index],text,statMatches > 1 ? @"?" : @""]];
        }
        for (NSUInteger index = 0; index < 5; ++index) {
            if (pickups[index] != lowestPickup) continue;
            NSString *text = pickupNames[pickupKeys[index]];
            if (![text isKindOfClass:NSString.class] || !text.length) continue;
            NSRange icon = [text rangeOfString:@"}} "];
            text = icon.location == NSNotFound ? [NSString stringWithFormat:@"%@ %@",quantities[index],text] :
                [text stringByReplacingCharactersInRange:icon withString:[NSString stringWithFormat:@"}} %@ ",quantities[index]]];
            [lines addObject:[text stringByAppendingString:pickupMatches > 1 ? @"?" : @""]];
        }
        if (lines.count > (name.length ? 1u : 0u)) detail = [detail stringByAppendingFormat:@"#%@",[lines componentsJoinedByString:@"#"]];
    }
    return detail;
}

NSString *EIDDynamicDescription(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger difficulty, NSSet<NSString *> *ownedItems, NSDictionary *context) {
    if (variant != 100) return detail;
    NSInteger playerType = [context[@"player_type"] isKindOfClass:NSNumber.class] ? [context[@"player_type"] integerValue] : -1;
    detail = EIDCharacterSynergyDescription(detail,variant,subtype,playerType,ownedItems,context);
    if (EIDUsesSalvageDescription(variant,subtype,playerType,context)) return detail;
    if (subtype == 297) return HighlightPandora(detail,difficulty,ownedItems,context);
    // Show the prediction on Consolation Prize itself, not every unrelated
    // pedestal after the player acquires it. Ties remain uncertain, as in EID.
    if (subtype == 644) return ConsolationPrize(detail,context);
    if (subtype == 464 && difficulty>=0 && difficulty<2 && [context[@"inside_item_reminder"] boolValue]) {
        NSDictionary *glyph = context[@"pickup_context"][@"glyph_balance"];
        if ([glyph[@"validated"] boolValue]) {
            NSInteger variant = [glyph[@"variant"] integerValue], sub = [glyph[@"subtype"] integerValue];
            NSString *key = variant ? [NSString stringWithFormat:@"5.%ld.%ld",(long)variant,(long)sub] : @"5.0";
            NSString *reward = context[@"pickup_names"][key] ?: context[@"pickup_names"][[NSString stringWithFormat:@"5.%ld",(long)variant]];
            if ([reward isKindOfClass:NSString.class] && reward.length)
                return [detail stringByAppendingFormat:@"#{{Collectible464}} → %@",reward];
        }
    }
    return detail;
}
