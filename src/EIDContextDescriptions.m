#import "EIDContextDescriptions.h"

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

static NSString *HeartType(NSInteger player) {
    if (player == 10 || player == 31) return @"None";
    if (player == 14 || player == 33) return @"Coin";
    if (player == 16) return @"Bone";
    if (player == 12 || player == 24) return @"Black";
    if ([@[@4, @17, @25, @35, @36, @40] containsObject:@(player)]) return @"Soul";
    return @"Red";
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

NSString *EIDContextDescription(NSString *detail, NSInteger variant, NSInteger subtype,
                               NSInteger playerType, NSInteger difficulty, NSDictionary *context) {
    return EIDContextDescriptionWithOwnedItems(detail, variant, subtype, playerType,
        difficulty, [NSSet set], context);
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

    // Birthright is wholly character-specific in the original mod.
    if (variant == 100 && subtype == 619 && playerEntry.count >= 3 &&
        [playerEntry[2] isKindOfClass:NSString.class]) detail = playerEntry[2];

    NSInteger healthVariant = variant == 1070 ? 70 : variant;
    NSInteger healthSubtype = subtype + (variant == 1070 ? 2048 : 0);
    NSString *healthKey = [NSString stringWithFormat:@"5.%ld.%ld", (long)healthVariant, (long)healthSubtype];
    NSNumber *healthAmount = context[@"health_amounts"][healthKey];
    NSString *heartType = HeartType(playerType);
    if (playerType >= 0 && ![heartType isEqualToString:@"Red"] &&
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
    detail = ChargeSynergies(detail,variant,subtype,ownedItems,context);
    if (![context[@"inside_item_reminder"] boolValue]) {
        for (NSNumber *type in differentPlayers) {
            NSString *name = PlayerName(type.integerValue,context);
            if (name.length) detail = Apply(detail,conditions[@"Different Effect"],name,1);
        }
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [detail componentsSeparatedByString:@"#"]) if (line.length) [lines addObject:line];
    return [lines componentsJoinedByString:@"#"];
}
