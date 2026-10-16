#import "EIDContextDescriptions.h"
#import "EIDContextPlayers.h"
#include "EIDPillPolicy.h"

static NSString *ReplaceVariables(NSString *text, NSString *name, NSInteger amount) {
    if ([text isKindOfClass:NSNumber.class]) text = [(NSNumber *)text stringValue];
    if (![text isKindOfClass:NSString.class]) return @"";
    NSString *result = [text stringByReplacingOccurrencesOfString:@"{1}" withString:name];
    // English plural templates are explicit in EID's fallback table. Other
    // languages generally supply their own find/replace pairs.
    return [result stringByReplacingOccurrencesOfString:@"{pluralize}"
                                            withString:amount > 1 ? @"s" : @""];
}

static NSString *ApplyStyled(NSString *detail, id entry, NSString *variable, NSInteger amount, NSString *color) {
    if ([entry isKindOfClass:NSString.class]) {
        NSString *addition = ReplaceVariables(entry, variable, amount);
        return addition.length ? (detail.length ? [detail stringByAppendingFormat:@"#%@", addition] : addition) : detail;
    }
    if (![entry isKindOfClass:NSArray.class]) return detail;
    NSArray *parts = entry;
    if (parts.count == 1) return ReplaceVariables(parts[0], variable, amount);
    for (NSUInteger index = 0; index + 1 < parts.count; index += 2) {
        id findValue = parts[index];
        NSString *find = ReplaceVariables(findValue, variable, amount);
        NSString *replace = ReplaceVariables(parts[index + 1], variable, amount);
        if (color.length) replace = [NSString stringWithFormat:@"{{%@}}%@{{CR}}",color,replace];
        if (find.length) {
            // EID:SimpleReplace(..., 1) changes one occurrence per pair. The
            // repeated Room to Wave pairs intentionally handle two mentions.
            NSRange range = NSMakeRange(NSNotFound,0);
            if ([findValue isKindOfClass:NSNumber.class]) {
                NSRegularExpression *numbers = [NSRegularExpression regularExpressionWithPattern:
                    @"[0-9]*\\.?[0-9]+" options:0 error:nil];
                for (NSTextCheckingResult *match in [numbers matchesInString:detail options:0 range:NSMakeRange(0,detail.length)]) {
                    if ([[detail substringWithRange:match.range] isEqualToString:find]) { range = match.range; break; }
                }
            } else {
                range = [detail rangeOfString:find];
                if (range.location == NSNotFound && color.length) {
                    // A few upstream localized charge pairs still expect old
                    // color tags which their updated base text no longer has.
                    // Ignore only those formatting tags, not icons or words.
                    NSRegularExpression *tags = [NSRegularExpression regularExpressionWithPattern:
                        @"\\{\\{(?:Color[A-Za-z0-9_]+|Blink[A-Za-z0-9_]+|CR)\\}\\}" options:0 error:nil];
                    NSString *plainFind = [tags stringByReplacingMatchesInString:find options:0
                        range:NSMakeRange(0,find.length) withTemplate:@""];
                    if (plainFind.length && ![plainFind isEqualToString:find]) range = [detail rangeOfString:plainFind];
                }
            }
            if (range.location != NSNotFound) detail = [detail stringByReplacingCharactersInRange:range withString:replace];
        }
    }
    if (parts.count % 2) detail = ApplyStyled(detail, parts.lastObject, variable, amount,color);
    return detail;
}

static NSString *Apply(NSString *detail, id entry, NSString *variable, NSInteger amount) {
    return ApplyStyled(detail,entry,variable,amount,nil);
}

static BOOL UnlockRuleMatches(NSDictionary *rule, NSDictionary *context) {
    if (![rule[@"achievement"] isKindOfClass:NSNumber.class]) return NO;
    NSDictionary *state = context[@"live_state"][@"unlocks"];
    NSNumber *value = state[[rule[@"achievement"] stringValue]];
    NSNumber *slot = state[@"slot"];
    if (![state[@"validated"] boolValue] || ![slot isKindOfClass:NSNumber.class] || slot.integerValue<1 || slot.integerValue>3 ||
        ![value isKindOfClass:NSNumber.class] ||
        (value.doubleValue!=0 && value.doubleValue!=1)) return NO;
    return [rule[@"predicate"] isEqual:@"achievement_locked"] ? !value.boolValue :
        [rule[@"predicate"] isEqual:@"achievement_unlocked"] && value.boolValue;
}

NSString *EIDUnlockDescription(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    NSString *target = [NSString stringWithFormat:@"5.%ld.%ld",(long)variant,(long)subtype];
    for (NSDictionary *rule in context[@"rules"])
        if ([rule[@"target"] isEqual:target] && [rule[@"predicate"] hasPrefix:@"achievement_"] && UnlockRuleMatches(rule,context))
            detail = Apply(detail,context[@"conditionals"][target],@"",1);
    return detail;
}

static NSString *HeartType(NSInteger player) {
    if (player == 10 || player == 31) return @"None";
    if (player == 14 || player == 33) return @"Coin";
    if (player == 16) return @"Bone";
    if (player == 12 || player == 24) return @"Black";
    if ([@[@4, @17, @25, @35, @36, @40] containsObject:@(player)]) return @"Soul";
    return @"Red";
}

NSString *EIDSingleUseDescription(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    if (variant != 100 || ![context[@"single_use_collectibles"] containsObject:@(subtype)] ||
        [context[@"pickup_context"][@"crown_overview"] boolValue]) return detail ?: @"";
    NSString *banner = context[@"context_strings"][@"SingleUseInfo"];
    if (![banner isKindOfClass:NSString.class] || !banner.length) return detail ?: @"";
    if ([[detail componentsSeparatedByString:@"#"] containsObject:banner]) return detail;
    return detail.length ? [banner stringByAppendingFormat:@"#%@",detail] : banner;
}

static NSArray<NSNumber *> *PlayerTypes(NSInteger closest, NSDictionary *context) {
    if ([context[@"inside_item_reminder"] boolValue]) return closest >= 0 ? @[@(closest)] : @[];
    NSMutableOrderedSet *types = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        NSNumber *type = player[@"type"];
        if ([type isKindOfClass:NSNumber.class] && type.integerValue >= 0 && type.integerValue <= 40)
            [types addObject:type];
    }
    if (!types.count && closest >= 0 && closest <= 40) [types addObject:@(closest)];
    return types.array;
}

static NSString *PlayerName(NSInteger type, NSDictionary *context) {
    NSArray *entry = context[@"birthright"][@(type).stringValue];
    return [entry isKindOfClass:NSArray.class] && entry.count && [entry[0] isKindOfClass:NSString.class] ? entry[0] : @"";
}

static NSString *ResolveItemVariables(NSString *text, NSDictionary *names) {
    if (![text isKindOfClass:NSString.class]) return @"";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:
        @"\\{\\{NameOnly(C[0-9]+|5\\.(?:100|350)\\.[0-9]+)\\}\\}" options:0 error:nil];
    NSMutableString *resolved = text.mutableCopy;
    NSArray *matches = [expression matchesInString:text options:0 range:NSMakeRange(0,text.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSString *key = [text substringWithRange:[match rangeAtIndex:1]];
        if ([key hasPrefix:@"C"]) key = [@"5.100." stringByAppendingString:[key substringFromIndex:1]];
        NSString *name = names[key];
        if (![name isKindOfClass:NSString.class] || !name.length) return @"";
        [resolved replaceCharactersInRange:match.range withString:name];
    }
    return resolved;
}

static id WithBulletpoint(id entry, NSString *bulletpoint) {
    if (!bulletpoint.length) return entry;
    NSString *(^decorate)(NSString *) = ^NSString *(NSString *text) {
        NSString *prefix = [NSString stringWithFormat:@"{{%@}} ", bulletpoint];
        return [prefix stringByAppendingString:[text stringByReplacingOccurrencesOfString:@"#"
            withString:[@"#" stringByAppendingString:prefix]]];
    };
    if ([entry isKindOfClass:NSString.class]) return decorate(entry);
    if (![entry isKindOfClass:NSArray.class]) return entry;
    NSMutableArray *parts = [entry mutableCopy];
    // Find/replace pairs are not prefixed; only whole replacements or the
    // trailing appended text get the owned-item bullet, like applyConditionals.
    if (parts.count % 2 && [parts.lastObject isKindOfClass:NSString.class])
        parts[parts.count - 1] = decorate(parts.lastObject);
    return parts;
}

static NSString *ChargeSynergies(NSString *detail, NSInteger variant, NSInteger subtype,
    NSSet<NSString *> *owned, NSDictionary *context) {
    NSDictionary *battery = context[@"car_battery"];
    NSDictionary *metadata = context[@"car_battery_metadata"];
    if (variant == 100 && [owned containsObject:@"5.100.356"] &&
        [context[@"live_state"][@"active_ids"] containsObject:@(subtype)]) {
        NSString *key = [metadata[@"no_synergy"] containsObject:@(subtype)] ? @"No Effect" : @(subtype).stringValue;
        detail = ApplyStyled(detail,WithBulletpoint(battery[key],@"Item5.100.356"),@"",1,@"BlinkYellowGreen");
    }
    if (variant == 100 && subtype == 356 && ![context[@"inside_item_reminder"] boolValue]) {
        for (NSNumber *item in metadata[@"pedestal_whitelist"]) {
            NSString *key = [@"5.100." stringByAppendingString:item.stringValue];
            if ([owned containsObject:key] && battery[item.stringValue]) {
                detail = ApplyStyled(detail,WithBulletpoint(battery[item.stringValue],[@"Item" stringByAppendingString:key]),
                    context[@"item_names"][key] ?: @"",1,@"BlinkYellowGreen");
                break;
            }
        }
        for (NSNumber *item in metadata[@"no_synergy"]) {
            NSString *key = [@"5.100." stringByAppendingString:item.stringValue];
            if ([owned containsObject:key]) {
                detail = Apply(detail,WithBulletpoint(battery[@"No Effect"],[@"Item" stringByAppendingString:key]),@"",1);
                break;
            }
        }
    }
    if (variant == 300 && [owned containsObject:@"5.100.451"]) {
        detail = ApplyStyled(detail,WithBulletpoint(context[@"tarot_cloth"][@(subtype).stringValue],@"Item5.100.451"),
            @"",1,@"ColorShinyPurple");
    }
    return detail;
}

static NSSet<NSString *> *CurrentSynergyOwned(NSSet<NSString *> *fallback, NSInteger type, NSDictionary *context) {
    NSArray *players = context[@"live_state"][@"players"];
    if (!players.count) return fallback;
    BOOL reminder = [context[@"inside_item_reminder"] boolValue];
    NSMutableSet *owned = [NSMutableSet set];
    for (NSDictionary *player in players) {
        BOOL selected = context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]]
            : [player[@"type"] integerValue] == type;
        if (reminder && !selected) continue;
        if ([player[@"owned"] isKindOfClass:NSArray.class]) [owned addObjectsFromArray:player[@"owned"]];
        if (reminder && selected) break;
    }
    // An unreadable/missing selected player must not reuse aggregated ownership
    // from a previous scan or borrow a co-op partner's effects in EID Items.
    return owned.copy;
}

static NSString *ItemCondition(NSString *detail, id entry, NSString *owner, NSString *color, NSDictionary *context) {
    if (!entry) return detail;
    NSString *name = context[@"item_names"][owner];
    if (![name isKindOfClass:NSString.class]) name = @"";
    if ([[entry description] containsString:@"{1}"] && !name.length) return detail;
    return ApplyStyled(detail,WithBulletpoint(entry,[@"Item" stringByAppendingString:owner]),name,1,color);
}

static BOOL ChargeMatches(NSInteger item, NSDictionary *params, NSDictionary *context) {
    NSDictionary *data = context[@"native_metadata"][@"active_details"][@(item).stringValue];
    if (![data[@"max"] isKindOfClass:NSNumber.class] || ![data[@"type"] isKindOfClass:NSNumber.class]) return NO;
    for (NSString *key in @[@"max",@"type"])
        if ([params[key] isKindOfClass:NSNumber.class] && ![params[key] isEqual:data[key]]) return NO;
    return item>0;
}

static id WithLineColor(id entry, NSString *color) {
    if (!color.length) return entry;
    NSString *(^decorate)(NSString *) = ^NSString *(NSString *line) {
        NSString *prefix = [NSString stringWithFormat:@"{{%@}}",color];
        return [NSString stringWithFormat:@"%@%@{{CR}}",prefix,
            [line stringByReplacingOccurrencesOfString:@"#" withString:[NSString stringWithFormat:@"{{CR}}#%@",prefix]]];
    };
    if ([entry isKindOfClass:NSString.class]) return decorate(entry);
    if (![entry isKindOfClass:NSArray.class]) return entry;
    NSMutableArray *parts = [entry mutableCopy];
    if (parts.count%2 && [parts.lastObject isKindOfClass:NSString.class]) parts[parts.count-1]=decorate(parts.lastObject);
    return parts;
}

static NSString *SupplementalDescriptions(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger difficulty, NSSet *fallback, NSDictionary *context) {
    NSSet *owned = EIDConditionalOwnedItems(fallback,context);
    BOOL reminder = [context[@"inside_item_reminder"] boolValue];
    NSString *target = [NSString stringWithFormat:@"5.%ld.%ld",(long)variant,(long)subtype];
    NSString *generic = [NSString stringWithFormat:@"5.%ld",(long)variant];
    NSMutableSet *printed = [NSMutableSet set], *unique = [NSMutableSet set];
    NSInteger highest = NSIntegerMin;
    for (NSDictionary *rule in context[@"supplemental_rules"]) {
        if (![rule[@"target"] isEqual:target] && ![rule[@"target"] isEqual:generic]) continue;
        if (reminder && ![rule[@"reminder"] boolValue]) continue;
        NSInteger layer = [rule[@"layer"] integerValue];
        if ([rule[@"check_layers"] boolValue] && highest>layer) continue;
        NSString *owner = rule[@"owned"], *predicate = rule[@"predicate"];
        NSDictionary *params = rule[@"params"];
        BOOL matches = owner.length && [owned containsObject:owner];
        if (predicate.length) {
            NSDictionary *floor = context[@"live_state"][@"floor"];
            NSNumber *stage = floor[@"stage"];
            if ([predicate isEqual:@"restock"]) matches = (difficulty==2 || difficulty==3) || [owned containsObject:@"5.100.376"];
            else if ([predicate isEqual:@"golden_bomb"]) {
                matches = NO;
                for (NSDictionary *player in EIDRelevantPlayers(context))
                    if ([player[@"golden_bomb"] isKindOfClass:NSNumber.class] && [player[@"golden_bomb"] doubleValue]==1) matches=YES;
            }
            else if ([predicate isEqual:@"stage_void"]) matches = stage && stage.integerValue==12;
            else if ([predicate isEqual:@"stage_shop"]) matches = stage && stage.integerValue==0 && (difficulty==2 || difficulty==3);
            else if ([predicate isEqual:@"stage_no_treasure"]) matches = stage && stage.integerValue>6;
            else if ([predicate isEqual:@"target_charge"]) {
                NSNumber *required = params[@"required"];
                matches = variant==100 && ChargeMatches(subtype,params,context) &&
                    (!required || [owned containsObject:[@"5.100." stringByAppendingString:required.stringValue]]);
                if (matches && required) owner=[@"5.100." stringByAppendingString:required.stringValue];
            } else {
                matches = NO;
                for (NSDictionary *player in EIDRelevantPlayers(context)) {
                    if ([predicate hasPrefix:@"multiple_"]) {
                        if ([player[@"owned"] containsObject:@"5.100.534"]) { owner=@"5.100.534"; matches=YES; break; }
                        NSNumber *kind = context[@"pocket_active_players"][[player[@"type"] stringValue]];
                        NSArray *slots = player[@"active_slots"];
                        if (kind && (![predicate isEqual:@"multiple_chargeable_actives"] || kind.integerValue==0) && slots.count==4 && [slots[2] integerValue]>0) {
                            owner=[@"5.100." stringByAppendingString:[slots[2] stringValue]]; matches=YES; break;
                        }
                    } else if ([predicate isEqual:@"player_charge"]) {
                        NSArray *slots = player[@"active_slots"];
                        NSUInteger limit = [params[@"check_pocket"] isEqual:@NO] ? 2 : 4;
                        if (slots.count!=4) continue;
                        for (NSUInteger slot=0; slot<limit; ++slot) if (ChargeMatches([slots[slot] integerValue],params,context)) {
                            owner=[@"5.100." stringByAppendingString:[slots[slot] stringValue]]; matches=YES; break;
                        }
                        if (matches) break;
                    }
                }
            }
        }
        if (!matches) continue;
        NSString *modifier = rule[@"modifier"];
        NSString *specific = modifier.length ? [target stringByAppendingFormat:@" (%@)",modifier] : target;
        NSString *uniqueID = rule[@"unique_id"];
        NSString *printKey = [specific stringByAppendingFormat:@":%@",owner ?: @""];
        if ([printed containsObject:printKey] || (uniqueID.length && [unique containsObject:uniqueID])) continue;
        id entry = [rule[@"no_table"] boolValue] ? context[@"context_strings"][modifier] :
            (context[@"conditionals"][specific] ?: context[@"conditionals"][modifier.length ? modifier : @(subtype).stringValue]);
        if (!entry) continue;
        NSString *variable = rule[@"variable"], *bullet = rule[@"bulletpoint"];
        if (predicate.length && owner.length && ![predicate isEqual:@"target_charge"]) {
            variable=[NSString stringWithFormat:@"{{NameOnly%@}}",owner]; bullet=[@"Item" stringByAppendingString:owner];
        }
        variable = ResolveItemVariables(variable,context[@"item_names"]);
        NSString *serialized = [entry description];
        if (([serialized containsString:@"{1}"] && !variable.length) || [serialized containsString:@"{2}"] || [serialized containsString:@"{3}"]) continue;
        entry=WithLineColor(entry,rule[@"line_color"]);
        if (bullet.length) entry=WithBulletpoint(entry,bullet);
        detail=ApplyStyled(detail,entry,variable,1,rule[@"replace_color"]);
        highest=MAX(highest,layer); [printed addObject:printKey];
        if (uniqueID.length) [unique addObject:uniqueID];
    }
    return detail;
}

static NSString *FoodSynergies(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger playerType, NSSet<NSString *> *owned, NSDictionary *context) {
    if (variant != 100 || ![owned containsObject:@"5.100.664"]) return detail;
    id buff = context[@"binge_eater"][@(subtype).stringValue];
    if (!buff) return detail;
    // Health adaptation can leave a food-only "No effect for The Lost" line.
    // Its health remains useless, but the Binge Eater stats are useful: do not
    // describe the entire item as ineffective once those bonuses are present.
    NSString *noEffect = Apply(@"",context[@"conditionals"][@"No Effect"],PlayerName(playerType,context),1);
    if (noEffect.length && [detail isEqualToString:noEffect]) detail = @"";
    detail = ItemCondition(detail,buff,@"5.100.664",nil,context);
    return ItemCondition(detail,context[@"conditionals"][@"Binge Eater Healing"],@"5.100.664",nil,context);
}

static NSString *FamiliarSynergies(NSString *detail, NSInteger variant, NSInteger subtype,
    NSSet<NSString *> *owned, NSDictionary *context) {
    NSDictionary *metadata = context[@"familiar_metadata"], *texts = context[@"BFFSSynergies"];
    NSDictionary *conditions = context[@"conditionals"];
    NSString *target = [NSString stringWithFormat:@"5.%ld.%ld",(long)variant,(long)subtype];
    BOOL bffs = [owned containsObject:@"5.100.247"], hive = [owned containsObject:@"5.100.248"];
    BOOL bffsTarget = variant == 100 || (variant == 300 && subtype == 96) ||
        (variant == 350 && [@[@54,@57,@142,@176,@182,@186] containsObject:@(subtype)]);
    BOOL applied = NO;
    if (bffs && bffsTarget && [metadata[@"bffs_ignore"] isKindOfClass:NSArray.class] &&
        ![metadata[@"bffs_ignore"] containsObject:@(subtype)]) {
        NSString *key = variant == 100 && [metadata[@"no_synergy"] containsObject:@(subtype)] ? @"No Effect" : target;
        if (texts[key]) {
            detail = ItemCondition(detail,texts[key],@"5.100.247",@"BlinkPink",context);
            applied = YES;
        }
    }
    // The original shared uniqueID prevents doubling the same familiar twice
    // when both upgrades are owned. Blue flies/spiders retain their base item
    // descriptions unless the upstream familiar table explicitly changes one.
    if (!applied && hive && variant == 100 && [metadata[@"hive_mind"] containsObject:@(subtype)]) {
        NSString *key = [metadata[@"no_synergy"] containsObject:@(subtype)] ? @"No Effect" : target;
        detail = ItemCondition(detail,texts[key],@"5.100.248",@"BlinkBlue",context);
    }
    if (variant == 100 && (subtype == 247 || subtype == 248)) {
        NSString *other = subtype == 247 ? @"5.100.248" : @"5.100.247";
        if ([owned containsObject:other])
            detail = ItemCondition(detail,conditions[@"No Effect (Familiars)"],other,nil,context);
        if (![context[@"inside_item_reminder"] boolValue]) {
            for (NSNumber *item in metadata[@"pedestal_whitelist"]) {
                if (subtype == 248 && ![metadata[@"hive_mind"] containsObject:item]) continue;
                NSString *key = [@"5.100." stringByAppendingString:item.stringValue];
                if ([owned containsObject:key] && texts[key]) {
                    detail = ItemCondition(detail,texts[key],key,nil,context);
                    break; // Match the original's single familiar pedestal hint.
                }
            }
            if (subtype == 247) for (NSNumber *item in metadata[@"no_synergy"]) {
                NSString *key = [@"5.100." stringByAppendingString:item.stringValue];
                if ([owned containsObject:key]) {
                    detail = ItemCondition(detail,conditions[@"No Effect"],key,nil,context);
                    break;
                }
            }
        }
    }
    if (variant == 100 && [@[@584,@685,@702,@728] containsObject:@(subtype)] &&
        [owned containsObject:@"5.350.141"])
        detail = ItemCondition(detail,conditions[@"No Effect From"],@"5.350.141",nil,context);
    if (variant == 350 && subtype == 141) {
        for (NSNumber *item in @[@584,@685,@702,@728]) {
            NSString *key = [@"5.100." stringByAppendingString:item.stringValue];
            if ([owned containsObject:key]) detail = ItemCondition(detail,conditions[@"No Effect From"],key,nil,context);
        }
        for (NSString *key in @[@"5.100.713",@"5.350.176"])
            if ([owned containsObject:key]) detail = ItemCondition(detail,conditions[@"Lullaby Clots"],key,nil,context);
    }
    return detail;
}

NSString *EIDContextDescription(NSString *detail, NSInteger variant, NSInteger subtype,
                               NSInteger playerType, NSInteger difficulty, NSDictionary *context) {
    return EIDContextDescriptionWithOwnedItems(detail, variant, subtype, playerType,
        difficulty, [NSSet set], context);
}

NSString *EIDCollectionDescription(NSString *detail, NSInteger variant, NSInteger subtype, NSDictionary *context) {
    NSDictionary *collection = context[@"live_state"][@"collection"];
    NSString *text = context[@"context_strings"][@"CollectionPageInfo"];
    NSInteger slot = [collection[@"slot"] integerValue];
    if (variant == 100 && subtype > 0 && subtype <= 732 &&
        slot >= 1 && slot <= 3 &&
        ![context[@"inside_item_reminder"] boolValue] && ![context[@"pickup_context"][@"crown_overview"] boolValue] &&
        [collection[@"progress_allowed"] boolValue] &&
        [collection[@"missing"] containsObject:@(subtype)] &&
        ![context[@"native_metadata"][@"hidden_ids"] containsObject:@(subtype)] && text.length)
        return [detail stringByAppendingFormat:@"#{{Warning}} %@",text];
    return detail;
}

static NSString *PillSynergies(NSString *detail, NSInteger variant, NSInteger subtype,
    NSSet<NSString *> *owned, NSDictionary *context) {
    if ((variant != 70 && variant != 1070) || subtype < 1 || subtype > 50) return detail;
    // Effects are resolved for the nearest/selected player. Do not attribute a
    // co-op partner's False PHD reward to this player's pill.
    for (NSDictionary *player in context[@"live_state"][@"players"]) {
        if ([player[@"index"] isEqual:context[@"player_index"]] && player[@"owned"]) {
            owned = [NSSet setWithArray:player[@"owned"]];
            break;
        }
    }
    if ([context[@"pill_modifiers"] isKindOfClass:NSNumber.class]) {
        // Explicit zero overrides every older ownership snapshot. Unavailable
        // native state also fails closed instead of reusing a previous reward.
        NSInteger modifiers = [context[@"pill_modifiers"] integerValue];
        NSMutableSet *current = [NSMutableSet set];
        if (modifiers >= 0 && modifiers <= EIDPillModifierAll) {
            if (modifiers & EIDPillModifierPHD) [current addObject:@"5.100.75"];
            if (modifiers & EIDPillModifierFalsePHD) [current addObject:@"5.100.654"];
            if (modifiers & EIDPillModifierVirgo) [current addObject:@"5.100.303"];
            if (modifiers & EIDPillModifierLuckyFoot) [current addObject:@"5.100.46"];
        }
        owned = current;
    }
    NSDictionary *strings = context[@"context_strings"];
    BOOL falsePHD = [owned containsObject:@"5.100.654"];
    NSString *damage = strings[variant == 1070 ? @"FalsePHDHorseDamage" : @"FalsePHDDamage"];
    if (subtype == 50) { // Experimental Pill, zero-based effect 49.
        NSInteger good = [owned containsObject:@"5.100.75"] ? 75 :
            [owned containsObject:@"5.100.46"] ? 46 : [owned containsObject:@"5.100.303"] ? 303 : 0;
        if (falsePHD) {
            NSString *text = strings[@"ExperimentalPillFalsePHD"];
            if (!good && text.length) detail = [detail stringByAppendingFormat:@"#{{Collectible654}} %@",text];
            if (damage.length) detail = [detail stringByAppendingFormat:@"#{{Collectible654}} %@",damage];
        } else if (good && [strings[@"ExperimentalPillPHD"] length]) {
            detail = [detail stringByAppendingFormat:@"#{{Collectible%ld}} %@",(long)good,strings[@"ExperimentalPillPHD"]];
        }
    } else if (falsePHD) {
        NSString *pillClass = context[@"pill_metadata"][@(subtype - 1).stringValue][@"class"];
        if (![pillClass isKindOfClass:NSString.class]) return detail;
        BOOL negative = [pillClass containsString:@"-"];
        BOOL damageUp = (negative && [pillClass containsString:@"3"]) || subtype == 48;
        BOOL blackHeart = ([pillClass containsString:@"1"] || [pillClass containsString:@"2"]) &&
            (negative || subtype == 43); // I'm Excited has no '-' in XML.
        NSString *text = damageUp ? damage : blackHeart ? strings[@"FalsePHDHeart"] : nil;
        if (text.length) detail = [detail stringByAppendingFormat:@"#{{Collectible654}} %@",text];
    }
    return detail;
}

NSString *EIDContextDescriptionWithOwnedItems(NSString *detail, NSInteger variant, NSInteger subtype,
    NSInteger playerType, NSInteger difficulty, NSSet<NSString *> *ownedItems, NSDictionary *context) {
    detail = detail ?: @"";
    if (variant == 2070) return detail; // Never identify an unknown pill.
    if (variant == 350) subtype &= 0x7fff;
    NSDictionary *conditions = context[@"conditionals"];
    NSDictionary *birthright = context[@"birthright"];
    NSArray *playerEntry = playerType >= 0 && playerType <= 40
        ? birthright[@(playerType).stringValue] : nil;
    NSString *playerName = [playerEntry isKindOfClass:NSArray.class] && playerEntry.count >= 1
        && [playerEntry[0] isKindOfClass:NSString.class] ? playerEntry[0] : @"";
    NSString *target = [NSString stringWithFormat:@"5.%ld.%ld", (long)variant, (long)subtype];
    NSArray *playerTypes = PlayerTypes(playerType,context);
    NSMutableOrderedSet *differentPlayers = [NSMutableOrderedSet orderedSet];
    if ([context[@"inside_item_reminder"] boolValue]) {
        for (NSDictionary *player in context[@"live_state"][@"players"]) {
            BOOL selected = context[@"player_index"] ? [player[@"index"] isEqual:context[@"player_index"]]
                : [player[@"type"] integerValue] == playerType;
            if (selected && [player[@"owned"] isKindOfClass:NSArray.class]) {
                ownedItems = [NSSet setWithArray:player[@"owned"]];
                break;
            }
        }
    }

    if (difficulty >= 0 && difficulty <= 3) {
        // Base translations can carry a legacy Greed caveat as plain text.
        // Remove only importer-classified no-effect notes for this exact item,
        // then apply the original conditional once in Greed/Greedier. Enemy
        // names (Greed/Super Greed) and unrelated gameplay lines are preserved.
        NSArray *notices = context[@"greed_no_effect_notes"][target];
        if ([notices isKindOfClass:NSArray.class] && notices.count) {
            NSMutableSet *trimmedNotices = [NSMutableSet set];
            for (NSString *notice in notices) {
                if ([notice isKindOfClass:NSString.class]) {
                    [trimmedNotices addObject:[notice stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
                }
            }
            NSMutableArray *lines = [NSMutableArray array];
            for (NSString *line in [detail componentsSeparatedByString:@"#"]) {
                NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (![trimmedNotices containsObject:trimmed]) [lines addObject:line];
            }
            detail = [lines componentsJoinedByString:@"#"];
        }
    }

    ownedItems = EIDConditionalOwnedItems(ownedItems,context);
    // Birthright is wholly character-specific in the original mod.
    if (variant == 100 && subtype == 619 && playerEntry.count >= 3 &&
        [playerEntry[2] isKindOfClass:NSString.class]) detail = playerEntry[2];

    NSInteger healthVariant = variant == 1070 ? 70 : variant;
    NSInteger healthSubtype = subtype + (variant == 1070 ? 2048 : 0);
    NSString *healthKey = [NSString stringWithFormat:@"5.%ld.%ld", (long)healthVariant, (long)healthSubtype];
    NSNumber *healthAmount = context[@"health_amounts"][healthKey];
    NSString *heartType = HeartType(playerType);
    NSDictionary *modular = context[@"modular_descriptions"][target];
    BOOL modularHealthHandled = NO;
    if ([modular isKindOfClass:NSDictionary.class] && [modular[@"Red"] isKindOfClass:NSString.class]) {
        NSString *generated = modular[heartType] ?: modular[@"Red"];
        if ([generated isKindOfClass:NSString.class]) {
            detail = generated;
            modularHealthHandled = ![heartType isEqual:@"Bone"] && playerType>=0;
            if (!detail.length && playerName.length) detail = Apply(@"",conditions[@"No Effect"],playerName,1);
        }
    }
    if (!modularHealthHandled && playerType >= 0 && ![heartType isEqualToString:@"Red"] &&
        (healthAmount || [context[@"healing_items"] containsObject:healthKey])) {
        NSInteger amount = healthAmount ? healthAmount.integerValue : 1;
        id replacements = context[@"heart_replacements"][[NSString stringWithFormat:@"Red to %@", heartType]];
        detail = Apply(detail, replacements, @(amount).stringValue, amount);
        if ([heartType isEqualToString:@"None"] || [heartType isEqualToString:@"Soul"] || [heartType isEqualToString:@"Black"]) {
            NSMutableArray *lines = [NSMutableArray array];
            for (NSString *line in [detail componentsSeparatedByString:@"#"]) {
                if ([line containsString:@"{{HealingRed}}"] || [line containsString:@"{{HealingHalfRed}}"] || !line.length) continue;
                [lines addObject:line];
            }
            detail = [lines componentsJoinedByString:@"#"];
        }
        if (!detail.length && playerName.length) detail = Apply(@"", conditions[@"No Effect"], playerName, 1);
    }
    if (healthAmount || [context[@"healing_items"] containsObject:healthKey]) {
        for (NSNumber *type in playerTypes)
            if (![HeartType(type.integerValue) isEqualToString:heartType]) [differentPlayers addObject:type];
    }

    NSMutableArray *rules = [NSMutableArray array];
    for (NSString *key in @[@"rules", @"weapon_rules"]) {
        for (NSDictionary *rule in context[key]) {
            if ([rule isKindOfClass:NSDictionary.class] && [rule[@"target"] isEqualToString:target])
                [rules addObject:rule];
        }
    }
    [rules sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"layer"] compare:left[@"layer"]];
    }];
    NSInteger highestLayer = NSIntegerMin;
    NSMutableSet *applied = [NSMutableSet set];
    NSMutableSet *uniqueIDs = [NSMutableSet set];
    for (NSDictionary *rule in rules) {
        if (![rule isKindOfClass:NSDictionary.class] || ![rule[@"target"] isEqualToString:target]) continue;
        BOOL weapon = [rule[@"weapon"] boolValue];
        NSInteger layer = [rule[@"layer"] integerValue];
        if ([rule[@"check_layers"] boolValue] && highestLayer > layer) continue;
        NSString *predicate = rule[@"predicate"] ?: ([rule[@"greed"] boolValue] ? @"greed" : @"");
        NSInteger rulePlayer = playerType;
        if (weapon && [rule[@"owned"] length]) {
            if (![ownedItems containsObject:rule[@"owned"]]) continue;
        } else if (predicate.length) {
            BOOL matched = NO;
            if ([predicate isEqualToString:@"greed"]) matched = difficulty == 2 || difficulty == 3;
            else if ([predicate isEqualToString:@"hard"]) matched = difficulty == 1 || difficulty == 3;
            else if ([predicate hasPrefix:@"achievement_"]) matched = UnlockRuleMatches(rule,context);
            else for (NSNumber *type in playerTypes) {
                if ([predicate isEqualToString:@"no_red_health"] && ![HeartType(type.integerValue) isEqualToString:@"Red"]) matched = YES;
                if ([predicate isEqualToString:@"tainted"] && [context[@"character_metadata"][@"tainted_ids"] containsObject:type]) matched = YES;
            }
            if (!matched) continue;
        } else {
            BOOL closestMatch = [rule[@"players"] containsObject:@(playerType)];
            if ([rule[@"closest"] boolValue]) {
                for (NSNumber *type in playerTypes)
                    if ([rule[@"players"] containsObject:type] != closestMatch) [differentPlayers addObject:type];
                if (!closestMatch) continue;
            } else if (!closestMatch) {
                rulePlayer = -1;
                for (NSNumber *type in playerTypes) if ([rule[@"players"] containsObject:type]) { rulePlayer = type.integerValue; break; }
                if (rulePlayer < 0) continue;
            }
        }
        NSString *modifier = [rule[@"modifier"] isKindOfClass:NSString.class] ? rule[@"modifier"] : @"";
        NSString *specific = modifier.length ? [target stringByAppendingFormat:@" (%@)", modifier] : target;
        NSDictionary *texts = rule[@"table"] ? context[rule[@"table"]] : conditions;
        id entry = texts[specific] ?: texts[modifier];
        if (!entry || (!weapon && [applied containsObject:specific])) continue;
        NSString *uniqueID = rule[@"unique_id"];
        if (uniqueID.length && [uniqueIDs containsObject:uniqueID]) continue;
        // Rules with unavailable dynamic variables must not display raw templates.
        NSString *serialized = [entry isKindOfClass:NSString.class] ? entry : [entry description];
        if ([serialized containsString:@"{2}"] || [serialized containsString:@"{3}"]) continue;
        NSString *variable = [rule[@"variable_literal"] isKindOfClass:NSString.class] ? rule[@"variable_literal"] :
            (weapon || rule[@"variable"] ? ResolveItemVariables(rule[@"variable"], context[@"item_names"]) : PlayerName(rulePlayer,context));
        if ([serialized containsString:@"{1}"] && !variable.length) continue;
        if (rule[@"bulletpoint"]) entry = WithBulletpoint(entry, rule[@"bulletpoint"]);
        detail = Apply(detail, entry, variable, 1);
        highestLayer = MAX(highestLayer, layer);
        if (uniqueID.length) [uniqueIDs addObject:uniqueID];
        if (!weapon) [applied addObject:specific];
    }
    NSSet *synergyOwned = CurrentSynergyOwned(ownedItems,playerType,context);
    detail = SupplementalDescriptions(detail,variant,subtype,difficulty,synergyOwned,context);
    detail = FoodSynergies(detail,variant,subtype,playerType,synergyOwned,context);
    detail = FamiliarSynergies(detail,variant,subtype,synergyOwned,context);
    detail = ChargeSynergies(detail,variant,subtype,ownedItems,context);
    detail = PillSynergies(detail,variant,subtype,ownedItems,context);
    if (![context[@"inside_item_reminder"] boolValue]) {
        for (NSNumber *type in differentPlayers) {
            NSString *name = PlayerName(type.integerValue,context);
            if (name.length) detail = Apply(detail,conditions[@"Different Effect"],name,1);
        }
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [detail componentsSeparatedByString:@"#"]) if (line.length) [lines addObject:line];
    return EIDSingleUseDescription([lines componentsJoinedByString:@"#"],variant,subtype,context);
}
