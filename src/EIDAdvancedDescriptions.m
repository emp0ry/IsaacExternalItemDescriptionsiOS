#import "EIDAdvancedDescriptions.h"
#import "EIDContextDescriptions.h"
#import "EIDDynamicDescriptions.h"
#include <math.h>

static NSString *Text(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }
static NSString *Append(NSString *detail, NSString *line) {
    return line.length ? [detail stringByAppendingFormat:@"#%@",line] : detail;
}
static NSString *Key(NSInteger variant, NSInteger item) {
    return [NSString stringWithFormat:@"5.%ld.%ld",(long)variant,(long)item];
}
static NSDictionary *SelectedPlayer(NSDictionary *context) {
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        if (context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]] :
            [player[@"type"] isEqual:context[@"player_type"]]) return player;
    }
    return nil;
}

// Evaluate a small whitelisted arithmetic tree imported from upstream Lua.
// No eval, scripting runtime or executable data is involved.
static double Formula(id node, double luck, unsigned depth) {
    if (depth > 24) return NAN;
    if ([node isKindOfClass:NSNumber.class]) return [node doubleValue];
    if (![node isKindOfClass:NSDictionary.class]) return NAN;
    NSString *op = node[@"op"];
    if ([op isEqual:@"luck"]) return luck;
    NSArray *args = node[@"args"];
    if (![args isKindOfClass:NSArray.class] || !args.count || args.count > 2) return NAN;
    double a = Formula(args[0],luck,depth+1);
    if (!isfinite(a)) return NAN;
    if ([op isEqual:@"floor"]) return floor(a);
    if ([op isEqual:@"ceil"]) return ceil(a);
    if ([op isEqual:@"neg"]) return -a;
    if (args.count != 2) return NAN;
    double b = Formula(args[1],luck,depth+1);
    if (!isfinite(b)) return NAN;
    if ([op isEqual:@"add"]) return a+b;
    if ([op isEqual:@"sub"]) return a-b;
    if ([op isEqual:@"mul"]) return a*b;
    if ([op isEqual:@"div"]) return b ? a/b : NAN;
    if ([op isEqual:@"min"]) return fmin(a,b);
    if ([op isEqual:@"max"]) return fmax(a,b);
    return NAN;
}

static NSString *Golden(NSString *detail, NSInteger subtype, NSSet *owned, NSDictionary *context) {
    BOOL golden = (subtype & 0x8000) != 0, box = [owned containsObject:@"5.100.439"];
    if (!golden && !box) return detail;
    NSString *identifier = @(subtype & 0x7fff).stringValue;
    id raw = context[@"golden_trinket_overrides"][identifier] ?: context[@"golden_trinket_data"][identifier];
    NSDictionary *data = [raw isKindOfClass:NSNumber.class] ? @{@"t":@[raw]} : raw;
    if (![data isKindOfClass:NSDictionary.class] || ([data[@"goldenOnly"] boolValue] && !golden)) return detail;
    double multiplier = golden && box ? 3 : 2;
    NSUInteger choice = golden && box ? 2 : box ? 1 : 0;
    NSArray *mults = data[@"mults"];
    if ([mults isKindOfClass:NSArray.class] && mults.count >= 2) multiplier = [mults[golden && box ? 1 : 0] doubleValue];
    else if (data[@"mult"] && ((golden && box) || [data[@"mult"] doubleValue] < 2)) multiplier = [data[@"mult"] doubleValue];
    NSArray *additions = data[@"additions"];
    NSInteger additionIndex = box ? (NSInteger)choice-1 : (NSInteger)choice;
    double addition = [additions isKindOfClass:NSArray.class] && additionIndex >= 0 && additionIndex < (NSInteger)additions.count
        ? [additions[(NSUInteger)additionIndex] doubleValue] : 0;
    __block NSUInteger replacements = 0;
    NSArray *numbers = data[@"t"];
    if ([numbers isKindOfClass:NSArray.class]) {
        // Protect sprite IDs and other markup while matching whole numeric tokens.
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{[^}]*\\}\\}|[0-9]*\\.?[0-9]+" options:0 error:nil];
        NSMutableString *result = detail.mutableCopy;
        for (NSTextCheckingResult *match in [[regex matchesInString:detail options:0 range:NSMakeRange(0,detail.length)] reverseObjectEnumerator]) {
            NSString *number = [detail substringWithRange:match.range];
            if ([number hasPrefix:@"{{"]) continue;
            for (NSNumber *target in numbers) {
                if (![number isEqualToString:target.stringValue]) continue;
                double value = target.doubleValue;
                if (value == 17) value = multiplier == 2 ? 16.5 : multiplier == 3 ? 100.0/6 : value;
                if (value == 33 && (multiplier == 1.5 || multiplier == 3)) value = 100.0/3;
                [result replaceCharactersInRange:match.range withString:
                    [NSString stringWithFormat:@"{{ColorGold}}%.4g{{CR}}",value*multiplier+addition]];
                ++replacements; break;
            }
        }
        detail = result;
    }
    NSArray *effects = context[@"golden_trinket_effects"][identifier];
    if ([effects isKindOfClass:NSArray.class] && effects.count) {
        if ([data[@"findReplace"] boolValue]) {
            for (NSUInteger index = 0; index < effects.count; index += 3) {
                NSString *find = Text(effects[index]);
                NSRange range = find.length ? [detail rangeOfString:find] : NSMakeRange(NSNotFound,0);
                if (range.location == NSNotFound) continue;
                NSUInteger target = MIN(effects.count-1,index+(NSUInteger)MAX(0,multiplier-1));
                detail = [detail stringByReplacingCharactersInRange:range withString:
                    [NSString stringWithFormat:@"{{ColorGold}}%@{{CR}}",Text(effects[target])]];
                ++replacements;
            }
        }
        NSUInteger index = effects.count == 2 && choice == 1 ? 0 : MIN(choice,effects.count-1);
        if ([data[@"append"] boolValue] && Text(effects[index]).length) {
            detail = Append(detail,[@"{{ColorGold}}" stringByAppendingString:Text(effects[index])]); ++replacements;
        }
        if ([data[@"fullReplace"] boolValue] && [context[@"golden_full_replace_ids"] containsObject:identifier]) {
            detail = Text(effects[index]); ++replacements;
        }
    }
    if (!replacements && multiplier > 1) {
        NSString *key = multiplier == 4 ? @"quadrupledTrinket" : multiplier == 3 ? @"tripledTrinket" : @"goldenTrinket";
        NSString *note = Text(context[@"context_strings"][key]);
        if (note.length) detail = Append(detail,[@"{{ColorGold}}" stringByAppendingString:note]);
    }
    return detail;
}

static NSString *Luck(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    id expression = context[@"luck_formulas"][Key(variant,subtype)];
    NSString *format = Text(context[@"context_strings"][@"LuckModifier"]);
    if (!expression || !format.length) return detail;
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        if (![player[@"luck"] isKindOfClass:NSNumber.class]) continue;
        double luck = [player[@"luck"] doubleValue];
        if (!isfinite(luck) || luck == 0) continue; // Upstream keeps the base chance at zero luck.
        double chance = Formula(expression,luck,0);
        if (!isfinite(chance)) continue;
        NSString *line = [format stringByReplacingOccurrencesOfString:@"{1}" withString:
            [NSString stringWithFormat:@"{{ColorGreen}}%.3g{{CR}}",fmin(100,fmax(0,chance))]];
        line = [line stringByReplacingOccurrencesOfString:@"{2}" withString:[NSString stringWithFormat:@"%.3g",luck]];
        NSString *icon = [context[@"live_state"][@"players"] count] > 1
            ? [NSString stringWithFormat:@"{{Player%@}}",player[@"index"]] : @"{{Luck}}";
        detail = Append(detail,[icon stringByAppendingFormat:@" %@",line]);
    }
    return detail;
}

static NSInteger SpindownResult(NSInteger identifier, NSInteger difficulty, NSDictionary *context) {
    NSDictionary *metadata = context[@"native_metadata"];
    NSArray *valid = metadata[@"collectible_ids"];
    if (![valid isKindOfClass:NSArray.class] || !valid.count) return 0;
    for (--identifier; identifier > 0; --identifier) {
        NSNumber *item = @(identifier);
        if (![valid containsObject:item] || [metadata[@"hidden_ids"] containsObject:item]) continue;
        if (difficulty >= 2 && [metadata[@"no_greed_ids"] containsObject:item]) continue;
        if ([context[@"live_state"][@"challenge"] integerValue] > 0 && [metadata[@"no_challenge_ids"] containsObject:item]) continue;
        return identifier;
    }
    return 0;
}

static NSString *Spindown(NSString *detail, NSInteger item, NSInteger difficulty, NSSet *owned, NSDictionary *context) {
    NSDictionary *native = context[@"pickup_context"][@"spindown"];
    if ([native isKindOfClass:NSDictionary.class]) {
        if (![native[@"owned"] boolValue] || ![native[@"validated"] boolValue] ||
            [context[@"inside_item_reminder"] boolValue] || item == 668) return detail;
        NSMutableArray *lines = [NSMutableArray array];
        for (NSDictionary *step in native[@"steps"]) {
            NSMutableArray *candidates = [NSMutableArray array];
            // Keep excluded IDs for native diagnostics only. The overlay shows
            // actual eligible results, never locked/restricted intermediates.
            NSInteger result = [step[@"result"] integerValue];
            if (result > 0 && result <= 732) [candidates addObject:[NSString stringWithFormat:@"{{Collectible%ld}} %@",
                (long)result,Text(context[@"item_names"][Key(100,result)])]];
            else {
                NSString *error = Text(context[@"context_strings"][@"spindownError"]);
                if (error.length) [candidates addObject:error];
            }
            if (candidates.count) [lines addObject:[candidates componentsJoinedByString:@" → "]];
        }
        NSString *line = [lines componentsJoinedByString:@" → "];
        if ([native[@"battery"] boolValue]) line = [@"{{Collectible356}} " stringByAppendingString:line];
        return line.length ? Append(detail,[@"{{Collectible723}} → " stringByAppendingString:line]) : detail;
    }
    if (![owned containsObject:@"5.100.723"] || [context[@"inside_item_reminder"] boolValue] || item == 668) return detail;
    BOOL battery = [owned containsObject:@"5.100.356"];
    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger use = 0; use < 3; ++use) {
        item = SpindownResult(item,difficulty,context);
        if (battery && item != 668 && item > 0) item = SpindownResult(item,difficulty,context);
        if (!item) break;
        NSString *name = Text(context[@"item_names"][Key(100,item)]);
        [results addObject:[NSString stringWithFormat:@"{{Collectible%ld}} %@",(long)item,name]];
        if (item == 668) break;
    }
    NSString *line = [results componentsJoinedByString:@" → "];
    if (!line.length) line = Text(context[@"context_strings"][@"spindownError"]);
    if (battery && line.length) line = [@"{{Collectible356}} " stringByAppendingString:line];
    return line.length ? Append(detail,[@"{{Collectible723}} → " stringByAppendingString:line]) : detail;
}

static NSString *Mimic(NSString *detail, NSInteger variant, NSInteger subtype, NSSet *owned, NSDictionary *context) {
    if (variant == 1070) variant = 70;
    if ((variant != 70 && variant != 300) || subtype <= 0 || subtype == 9999 || (variant == 300 && subtype == 48)) return detail;
    NSDictionary *data = context[@"native_metadata"][@"mimic_charges"][[NSString stringWithFormat:@"%ld:%ld",(long)variant,(long)subtype]];
    if (![data isKindOfClass:NSDictionary.class] || ![data[@"cost"] isKindOfClass:NSNumber.class]) return detail;
    NSInteger active = [data[@"active"] integerValue];
    if (![owned containsObject:Key(100,active)]) return detail;
    NSString *format = Text(context[@"context_strings"][@"VariableCharge"]);
    NSString *name = Text(context[@"item_names"][Key(100,active)]);
    if (format.length && name.length) detail = Append(detail,[NSString stringWithFormat:@"{{Collectible%ld}} %@ %@{{Battery}}",
        (long)active,[format stringByReplacingOccurrencesOfString:@"{1}" withString:name],data[@"cost"]]);
    if (active == 286 && [owned containsObject:@"5.100.451"]) {
        NSString *extra = Text(context[@"tarot_cloth_blank_card"][@(subtype).stringValue]);
        if (extra.length) detail = Append(detail,[NSString stringWithFormat:@"{{Collectible286}} %@ %@",
            Text(context[@"context_strings"][@"BlankCardEffect"]),extra]);
    }
    return detail;
}

static NSString *Abyss(NSString *detail, NSInteger item, NSSet *owned, NSDictionary *context) {
    if (item < 1 || item > 732 || ![owned containsObject:@"5.100.706"]) return detail;
    NSDictionary *descriptions = context[@"abyss_descriptions"];
    if (![descriptions isKindOfClass:NSDictionary.class]) return detail;
    NSString *preview = Text(descriptions[@(item).stringValue] ?: descriptions[@"default"]);
    if (!preview.length) return detail;
    // Like the upstream callback this is hypothetical locust information, not
    // an absorption action or a forecast of damage after unrelated synergies.
    preview = [preview stringByReplacingOccurrencesOfString:@"#" withString:@"#{{ColorRed}}"];
    return Append(detail,[NSString stringWithFormat:@"{{Collectible706}} {{ColorRed}}%@{{CR}}",preview]);
}

static NSString *PredictionFor(NSString *detail, BOOL rune, NSDictionary *prediction, NSString *mode, NSDictionary *context) {
    NSArray *counts = prediction[mode];
    if (![counts isKindOfClass:NSArray.class] || counts.count != 6) return detail;
    static NSString *const icons[] = {@"Speed",@"Tears",@"Damage",@"Range",@"Shotspeed",@"Luck"};
    static const double amounts[] = {.2,.5,1,2.5,.2,1};
    NSMutableArray *stats = [NSMutableArray array];
    for (NSUInteger index = 0; index < 6; ++index) {
        NSUInteger count = [counts[index] unsignedIntegerValue];
        if (!count || count > 4096) continue;
        NSString *name = Text(context[@"stat_names"][@(index+1).stringValue]);
        NSString *value = [NSString stringWithFormat:@"+%.3g",amounts[index]*count];
        if (name.length) [stats addObject:[NSString stringWithFormat:@"{{%@}} %@",icons[index],
            [name containsString:@"{1}"] ? [name stringByReplacingOccurrencesOfString:@"{1}" withString:value]
                : [value stringByAppendingFormat:@" %@",name]]];
    }
    if (!stats.count) return detail;
    NSString *text = Text(context[@"context_strings"][[mode isEqual:@"room"] ? @"VoidText" : @"VoidShopText"]);
    return Append(detail,[NSString stringWithFormat:@"{{%@}} %@ %@",rune ? @"Card41" : @"Collectible477",text,
        [stats componentsJoinedByString:@" | "]]);
}

static NSString *RepeatPreview(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    BOOL wild = variant == 300 && subtype == 80;
    BOOL vurp = (variant == 70 || variant == 1070) && subtype == 47;
    if (!wild && !vurp) return detail;
    NSArray *previews = context[@"pickup_context"][@"repeat_previews"];
    if (![previews isKindOfClass:NSArray.class] || previews.count > 8) return detail;
    for (NSDictionary *effect in previews) {
        if (![effect isKindOfClass:NSDictionary.class] || ![effect[@"variant"] isKindOfClass:NSNumber.class] ||
            ![effect[@"id"] isKindOfClass:NSNumber.class] || ![effect[@"index"] isKindOfClass:NSNumber.class]) continue;
        NSInteger target = [effect[@"variant"] integerValue], id = [effect[@"id"] integerValue];
        NSInteger index = [effect[@"index"] integerValue], color = [effect[@"color"] integerValue];
        BOOL pill = target == 70 || target == 1070;
        if (index < 0 || index >= 8 || id < 1 || (vurp && !pill)) continue;
        NSString *icon = nil, *tint = nil;
        if (pill) {
            if (id > 50 || color <= 0 || (color & ~0xfff) || !(color & 0x7ff) ||
                (color & 0x7ff) > 14 || ((color & 0x800) != 0) != (target == 1070)) continue;
            icon = [NSString stringWithFormat:@"Pill%ld",(long)color]; tint = @"ColorPill";
        } else if (target == 300 && id <= 97 && id != 80) {
            icon = [NSString stringWithFormat:@"Card%ld",(long)id]; tint = @"ColorCard";
        } else if (target == 100 && id <= 732) {
            icon = [NSString stringWithFormat:@"Collectible%ld",(long)id]; tint = @"ColorYellow";
        }
        NSString *name = Text(context[@"item_names"][Key(target,id)]);
        if (pill && !name.length) name = Text(context[@"item_names"][Key(70,id)]);
        if (!icon || !name.length) continue;
        NSString *prefix = [context[@"live_state"][@"players"] count] > 1
            ? [NSString stringWithFormat:@"P%ld: ",(long)index+1] : @"";
        detail = Append(detail,[NSString stringWithFormat:@"%@{{%@}} {{%@}}%@{{CR}}",prefix,icon,tint,name]);
    }
    return detail;
}

static NSString *InventoryPreview(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    BOOL stars = variant == 300 && subtype == 73;
    BOOL feather = variant == 350 && (subtype & 0x7fff) == 80;
    if (!stars && !feather) return detail;
    NSArray *previews = context[@"pickup_context"][stars ? @"stars_previews" : @"black_feather"];
    if (![previews isKindOfClass:NSArray.class] || previews.count > 8) return detail;
    BOOL coop = [context[@"live_state"][@"players"] count] > 1;
    for (NSDictionary *preview in previews) {
        if (![preview isKindOfClass:NSDictionary.class] || ![preview[@"index"] isKindOfClass:NSNumber.class]) continue;
        NSInteger index = [preview[@"index"] integerValue];
        if (index < 0 || index >= 8) continue;
        NSString *prefix = coop ? [NSString stringWithFormat:@"P%ld: ",(long)index+1] : @"";
        if (stars) {
            NSArray *items = preview[@"items"];
            if (![items isKindOfClass:NSArray.class] || items.count > ([preview[@"tarot"] boolValue] ? 2u : 1u)) continue;
            for (NSNumber *item in items) {
                if (![item isKindOfClass:NSNumber.class] || item.integerValue < 1 || item.integerValue > 732) continue;
                NSString *name = Text(context[@"item_names"][Key(100,item.integerValue)]);
                if (name.length) detail = Append(detail,[NSString stringWithFormat:@"%@{{Collectible%@}} {{ColorYellow}}%@{{CR}}",prefix,item,name]);
            }
        } else {
            if (![preview[@"count"] isKindOfClass:NSNumber.class] || ![preview[@"box"] isKindOfClass:NSNumber.class]) continue;
            NSInteger count = [preview[@"count"] integerValue];
            if (count < 0 || count > 100000) continue;
            BOOL box = [preview[@"box"] boolValue], golden = (subtype & 0x8000) != 0;
            double damage = .5*count*(box ? 2 : 1)*(golden ? 2 : 1);
            NSString *color = !count ? @"CR" : box || golden ? @"ColorGold" : @"ColorSilver";
            NSString *value = [NSString stringWithFormat:@"{{%@}}%.4g{{CR}}",color,damage];
            NSString *text = Text(context[@"context_strings"][@"BlackFeatherInformation"]);
            text = [text stringByReplacingOccurrencesOfString:@"{1}" withString:@(count).stringValue];
            text = [text stringByReplacingOccurrencesOfString:@"{2}" withString:value];
            if (text.length) detail = Append(detail,[prefix stringByAppendingString:text]);
        }
    }
    return detail;
}

static NSString *Prediction(NSString *detail, NSInteger variant, NSInteger item, NSSet *owned, NSDictionary *context) {
    if ([context[@"inside_item_reminder"] boolValue] || context[@"pickup_context"][@"collectible_cycle"]) return detail;
    NSDictionary *player = SelectedPlayer(context);
    BOOL rune = variant == 300 && item == 41;
    BOOL voidItem = variant == 100 && item == 477;
    BOOL pedestal = variant == 100 && [context[@"pickup_context"][@"pedestal"] boolValue];
    NSArray *room = context[@"live_state"][@"room_pedestals"];
    if (![room isKindOfClass:NSArray.class]) return detail;
    NSString *mode = (rune || voidItem) ? @"single" : @"room";
    if (pedestal && [context[@"pickup_context"][@"shop"] boolValue]) mode = @"purchased";
    NSInteger option = [context[@"pickup_context"][@"options"] integerValue];
    if (pedestal && option) {
        for (NSDictionary *pickup in room) {
            if ([pickup[@"options"] integerValue] != option) continue;
            NSInteger first = [pickup[@"id"] integerValue];
            if (first != item) {
                NSString *name = Text(context[@"item_names"][Key(100,first)]);
                detail = Append(detail,[NSString stringWithFormat:@"{{Collectible477}} %@%@",name,
                    Text(context[@"context_strings"][@"VoidOptionText"])]);
                mode = @"single";
            }
            break;
        }
    }
    BOOL active = [context[@"native_metadata"][@"active_ids"] containsObject:@(item)] && item != 523;
    if (voidItem || (pedestal && !active && [owned containsObject:@"5.100.477"]))
        detail = PredictionFor(detail,NO,player[@"void_prediction"],mode,context);
    if (rune || (pedestal && [player[@"pocket_cards"] containsObject:@41]))
        detail = PredictionFor(detail,YES,player[@"black_rune_prediction"],mode,context);
    return detail;
}

static NSArray *CollectibleCycleItems(NSDictionary *context) {
    NSArray *items = context[@"pickup_context"][@"collectible_cycle"][@"items"];
    if (![items isKindOfClass:NSArray.class] || items.count < 5 || items.count > 9 ||
        [NSSet setWithArray:items].count != items.count) return nil;
    for (NSNumber *item in items)
        if (![item isKindOfClass:NSNumber.class] || item.integerValue < 1 || item.integerValue > 732 ||
            !Text(context[@"item_names"][Key(100,item.integerValue)]).length) return nil;
    return items;
}

static NSString *CollectibleCycleToggle(NSString *detail, NSDictionary *context) {
    NSArray *items = CollectibleCycleItems(context);
    NSNumber *selection = context[@"pickup_context"][@"crown_selection"];
    if (!items || ![selection isKindOfClass:NSNumber.class] || selection.integerValue < 0 ||
        selection.unsignedIntegerValue > items.count) return detail;
    NSNumber *next = selection.unsignedIntegerValue < items.count ? items[selection.unsignedIntegerValue] : @689;
    NSString *text = Text(context[@"context_strings"][@"GlitchedCrownToggleInfo"]);
    if (!text.length) return detail;
    text = [text stringByReplacingOccurrencesOfString:@"{{CONFIG_BoC_Toggle}}" withString:@"›"];
    // This upstream translation spells out the map button instead of using
    // the configurable-input token. Adapt its label to the same iOS control.
    text = [text stringByReplacingOccurrencesOfString:@"マップボタン" withString:@"›"];
    text = [text stringByReplacingOccurrencesOfString:@"{1}" withString:[NSString stringWithFormat:@"{{Collectible%@}}",next]];
    return Append(detail,[@"{{Blank}} " stringByAppendingString:text]);
}

NSString *EIDAdvancedDescription(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger difficulty, NSSet<NSString *> *owned, NSDictionary *context) {
    NSDictionary *player = SelectedPlayer(context);
    if ([player[@"owned"] isKindOfClass:NSArray.class]) owned = [NSSet setWithArray:player[@"owned"]];
    BOOL overview = variant == 100 && subtype == 689 && [context[@"pickup_context"][@"crown_overview"] boolValue] &&
        CollectibleCycleItems(context) != nil;
    if (overview) {
        NSMutableArray *lines = [NSMutableArray array];
        for (NSNumber *item in CollectibleCycleItems(context))
            [lines addObject:[NSString stringWithFormat:@"{{Collectible%@}} {{ColorYellow}}%@{{CR}}",item,
                Text(context[@"item_names"][Key(100,item.integerValue)])]];
        detail = [lines componentsJoinedByString:@"#"];
    } else {
        if (variant == 350) detail = Golden(detail,subtype,owned,context);
        detail = Luck(detail,variant,variant == 350 ? subtype & 0x7fff : subtype,context);
        detail = Mimic(detail,variant,subtype,owned,context);
        detail = RepeatPreview(detail,variant,subtype,context);
        detail = InventoryPreview(detail,variant,subtype,context);
    }
    if (variant == 100) {
        if (!overview) {
            detail = Abyss(detail,subtype,owned,context);
            detail = Spindown(detail,subtype,difficulty,owned,context);
        }
        NSInteger flip = [context[@"pickup_context"][@"flip_id"] integerValue];
        if (flip > 0 && flip <= 732 && ![context[@"inside_item_reminder"] boolValue]) {
            NSString *name = Text(context[@"item_names"][Key(100,flip)]);
            NSString *other = Text(context[@"item_details"][Key(100,flip)]);
            NSMutableDictionary *alternate = context.mutableCopy;
            alternate[@"pickup_context"] = @{};
            // Apply the same character/mode rules without recursively following Flip.
            other = EIDContextDescriptionWithOwnedItems(other,100,flip,[context[@"player_type"] integerValue],difficulty,owned,alternate);
            other = EIDDynamicDescription(other,100,flip,difficulty,owned,alternate);
            if (name.length) detail = Append(detail,[NSString stringWithFormat:@"{{Collectible711}} → {{Collectible%ld}} %@%@%@",
                (long)flip,name,other.length ? @"#" : @"",other]);
        }
    }
    detail = Prediction(detail,variant,subtype,owned,context);
    return variant == 100 ? CollectibleCycleToggle(detail,context) : detail;
}
