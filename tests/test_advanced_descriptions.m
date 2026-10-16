#import "EIDAdvancedDescriptions.h"

static NSMutableDictionary *AdvancedContext(NSDictionary *database, NSString *code) {
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"golden_trinket_effects",@"golden_trinket_overrides",@"tarot_cloth_blank_card",@"context_strings",@"stat_names",@"abyss_descriptions",@"purity_boosts"]) {
        NSMutableDictionary *entries = [database[@"languages"][@"en_us"][key] mutableCopy] ?: [NSMutableDictionary dictionary];
        [entries addEntriesFromDictionary:database[@"languages"][code][key] ?: @{}];
        context[key] = entries;
    }
    context[@"golden_full_replace_ids"] = [database[@"languages"][code][@"golden_trinket_effects"] allKeys] ?: @[];
    context[@"luck_formulas"] = database[@"luck_formulas"];
    context[@"golden_trinket_data"] = database[@"golden_trinket_data"];
    context[@"player_index"] = @0;
    NSMutableDictionary *names = [NSMutableDictionary dictionary], *details = [NSMutableDictionary dictionary];
    for (NSString *language in @[@"en_us",code]) {
        NSDictionary *prefixes = @{@"collectibles":@"5.100.",@"trinkets":@"5.350.",@"cards":@"5.300.",@"pills":@"5.70.",@"horsepills":@"5.1070."};
        for (NSString *category in prefixes) {
            for (NSString *identifier in database[@"languages"][language][category]) {
                NSDictionary *entry = database[@"languages"][language][category][identifier];
                NSString *key = [prefixes[category] stringByAppendingString:identifier];
                if ([entry[@"name"] length]) names[key] = entry[@"name"];
                if ([entry[@"description"] length]) details[key] = entry[@"description"];
            }
        }
    }
    context[@"item_names"] = names; context[@"item_details"] = details;
    context[@"native_metadata"] = @{@"collectible_ids":@[@1,@2,@3,@4,@5,@6,@7,@8,@9,@10,@668,@669,@670],
        @"hidden_ids":@[@8],@"no_greed_ids":@[@7],@"no_challenge_ids":@[@6],@"active_ids":@[@33,@34,@78,@477],
        @"mimic_charges":@{@"300:5":@{@"active":@286,@"cost":@6},
            @"300:32":@{@"active":@263,@"cost":@2},@"70:10":@{@"active":@348,@"cost":@4}}};
    context[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":@0,@"luck":@5}]};
    return context;
}

void TestAdvancedDescriptions(NSDictionary *database) {
    NSSet *none = [NSSet set];
    for (NSString *code in database[@"languages"]) {
        NSMutableDictionary *context = AdvancedContext(database,code);
        context[@"inside_item_reminder"] = @YES;
        for (NSNumber *boost in @[@0,@1,@2,@3]) {
            context[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":@0,@"owned":@[@"5.100.407"],
                @"purity":@{@"validated":@YES,@"active":@YES,@"boost":boost}}]};
            NSString *text=EIDAdvancedDescription(@"Base",100,407,0,none,context);
            NSCAssert([text containsString:context[@"purity_boosts"][boost.stringValue]], @"Purity uses the selected native boost (%@ %@)",code,boost);
        }
        context[@"live_state"] = @{@"players":@[@{@"index":@0,@"owned":@[@"5.100.407"],
            @"purity":@{@"validated":@YES,@"active":@NO,@"boost":@2}}]};
        NSCAssert([EIDAdvancedDescription(@"Base",100,407,0,none,context) containsString:context[@"context_strings"][@"CurrentEffectInactive"]],
            @"Inactive Purity never claims a cached stat is applied");
        context[@"inside_item_reminder"] = @NO;
        NSCAssert([EIDAdvancedDescription(@"Base",100,407,0,none,context) isEqual:@"Base"], @"An uncollected Purity pedestal does not predict a boost");
        context[@"inside_item_reminder"] = @YES;
        context[@"live_state"] = @{@"players":@[
            @{@"index":@0,@"type":@0,@"owned":@[]},
            @{@"index":@1,@"type":@0,@"owned":@[@"5.100.477"],@"void_actives":@[@78,@78,@33]}]};
        NSCAssert([EIDAdvancedDescription(@"Base",100,477,0,none,context) isEqual:@"Base"], @"Void absorption does not leak from a same-character partner");
        context[@"player_index"] = @1;
        NSString *voided=EIDAdvancedDescription(@"Base",100,477,0,none,context);
        NSCAssert([voided containsString:@"{{Collectible78}}"] && [voided containsString:@"×2"] &&
            [voided containsString:context[@"item_names"][@"5.100.33"]], @"Native Void list includes duplicates and localized active names");
        context[@"pickup_context"] = @{@"void_absorbed":@YES};
        NSCAssert([EIDAdvancedDescription(@"Active detail",100,78,0,none,context) hasPrefix:@"{{Collectible477}} →"], @"An absorbed active's full description is inspectable");
        context[@"player_index"] = @0;
        context[@"live_state"] = @{@"players":@[@{@"index":@0,@"owned":@[@"5.350.166"],
            @"modeling_clay":@{@"validated":@YES,@"result":@3}}]};
        context[@"pickup_context"] = @{@"current_effect":@{@"validated":@YES,@"source_variant":@350,@"source_id":@166,@"result":@3}};
        NSString *clay=EIDAdvancedDescription(@"Spoon detail",100,3,0,none,context);
        NSCAssert([clay containsString:@"{{Trinket166}}"] && [clay containsString:context[@"item_names"][@"5.100.3"]] &&
            [clay hasSuffix:@"Spoon detail"], @"Modeling Clay shows its current item and source without changing ownership");
        context[@"live_state"] = @{@"players":@[@{@"index":@0,@"owned":@[]}]};
        NSCAssert([EIDAdvancedDescription(@"Base",100,3,0,none,context) isEqual:@"Base"], @"Removed Modeling Clay clears the source effect annotation");
        context=AdvancedContext(database,code);
        context[@"inside_item_reminder"] = @YES;
        context[@"pickup_context"] = @{@"crooked_penny":@{@"validated":@YES,@"battery":@YES,@"heads":@[@YES,@NO]}};
        NSCAssert([EIDAdvancedDescription(@"Base",100,485,0,none,context) isEqual:@"Base"], @"Outcome previews are opt-in");
        context[@"rng_predictions_enabled"] = @YES;
        NSString *penny = EIDAdvancedDescription(@"Base",100,485,0,none,context);
        NSCAssert([penny containsString:context[@"context_strings"][@"CrookedPennyHeads"]] &&
            [penny containsString:context[@"context_strings"][@"CrookedPennyTails"]] &&
            [penny containsString:@"{{Collectible356}}"], @"Car Battery shows both localized Penny activations: %@",code);
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,none,context) isEqual:@"Base"], @"Penny prediction never attaches to other items");
        context[@"inside_item_reminder"] = @NO;
        NSCAssert([EIDAdvancedDescription(@"Base",100,485,0,none,context) isEqual:@"Base"], @"Penny is a personal inventory reminder");
        context[@"pickup_context"] = @{@"pedestal":@YES,@"eternal_d6":@{@"validated":@YES,@"vanishes":@NO,@"battery":@NO}};
        NSString *eternal = EIDAdvancedDescription(@"Base",100,25,0,none,context);
        NSCAssert([eternal containsString:context[@"context_strings"][@"EternalD6Survives"]] &&
            [eternal containsString:@"{{Collectible609}}"] && ![eternal containsString:@"{1}"], @"Eternal D6 localizes the next reroll without a fictitious future count: %@",code);
        context[@"pickup_context"] = @{@"pedestal":@YES,@"eternal_d6":@{@"validated":@YES,@"vanishes":@YES,@"battery":@YES}};
        eternal = EIDAdvancedDescription(@"Base",100,25,0,none,context);
        NSCAssert([eternal containsString:context[@"context_strings"][@"spindownError"]] &&
            [eternal containsString:context[@"context_strings"][@"EternalD6FirstOnly"]], @"Eternal D6 clearly scopes a battery prediction to the first reroll: %@",code);
        context[@"inside_item_reminder"] = @YES;
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,none,context) isEqual:@"Base"], @"No Eternal D6 prediction on already owned items");
        context[@"rng_predictions_enabled"] = @NO;
        context[@"inside_item_reminder"] = @NO;
        context[@"pickup_context"] = @{};
        for (NSDictionary *effect in @[
            @{@"index":@0,@"variant":@100,@"id":@34,@"color":@0},
            @{@"index":@0,@"variant":@300,@"id":@19,@"color":@0},
            @{@"index":@0,@"variant":@300,@"id":@48,@"color":@0},
            @{@"index":@0,@"variant":@70,@"id":@1,@"color":@1},
            @{@"index":@0,@"variant":@1070,@"id":@2,@"color":@(0x805)}]) {
            context[@"pickup_context"] = @{@"repeat_previews":@[effect]};
            NSString *preview = EIDAdvancedDescription(@"Base",300,80,0,none,context);
            NSString *key = [NSString stringWithFormat:@"5.%@.%@",effect[@"variant"],effect[@"id"]];
            NSCAssert([preview containsString:context[@"item_names"][key]], @"Wild Card localizes cards, actives and concrete pills: %@ %@",code,key);
            NSString *icon = [NSString stringWithFormat:@"{{%@%@}}",[effect[@"color"] integerValue] ? @"Pill" :
                [effect[@"variant"] integerValue] == 100 ? @"Collectible" : @"Card",
                [effect[@"color"] integerValue] ? effect[@"color"] : effect[@"id"]];
            NSCAssert([preview containsString:icon], @"Repeat preview keeps native card/pill artwork: %@",icon);
        }
        for (NSNumber *variant in @[@70,@1070]) {
            NSDictionary *effect = @{@"index":@0,@"variant":variant,@"id":@2,@"color":@([variant intValue] == 1070 ? 0x805 : 5)};
            context[@"pickup_context"] = @{@"repeat_previews":@[effect]};
            NSString *preview = EIDAdvancedDescription(@"Base",variant.integerValue,47,0,none,context);
            NSString *key = [NSString stringWithFormat:@"5.%@.2",variant];
            NSCAssert([preview containsString:context[@"item_names"][key]], @"Vurp uses the resulting normal/horse pill name: %@",code);
            NSCAssert([EIDAdvancedDescription(@"Base",2070,47,0,none,context) isEqual:@"Base"], @"Unidentified pills never leak Vurp history");
            NSCAssert([EIDAdvancedDescription(@"Base",70,2,0,none,context) isEqual:@"Base"], @"Other pills never inherit Vurp previews");
        }
        context[@"pickup_context"] = @{@"repeat_previews":@[@{@"index":@0,@"variant":@70,@"id":@47,@"color":@5}]};
        NSCAssert([EIDAdvancedDescription(@"Base",70,47,0,none,context) containsString:context[@"item_names"][@"5.70.47"]], @"First Vurp predicts itself without inventing a previous pill");
        for (NSDictionary *invalid in @[
            @{@"index":@0,@"variant":@300,@"id":@80},
            @{@"index":@0,@"variant":@100,@"id":@733},
            @{@"index":@0,@"variant":@2070,@"id":@1,@"color":@1},
            @{@"index":@0,@"variant":@70,@"id":@51,@"color":@1},
            @{@"index":@0,@"variant":@70,@"id":@1,@"color":@0x1001},
            @{@"index":@0,@"variant":@1070,@"id":@1,@"color":@1},
            @{@"index":@8,@"variant":@100,@"id":@34}]) {
            context[@"pickup_context"] = @{@"repeat_previews":@[invalid]};
            NSCAssert([EIDAdvancedDescription(@"Base",300,80,0,none,context) isEqual:@"Base"], @"Invalid/unavailable native history fails closed: %@",invalid);
        }
        context[@"pickup_context"] = @{@"repeat_previews":@[]};
        NSCAssert([EIDAdvancedDescription(@"Base",300,80,0,none,context) isEqual:@"Base"], @"No Wild Card history preserves its base description");
        context[@"live_state"] = @{@"players":@[@{@"index":@0},@{@"index":@1}]};
        context[@"pickup_context"] = @{@"repeat_previews":@[
            @{@"index":@0,@"variant":@100,@"id":@34,@"color":@0},
            @{@"index":@1,@"variant":@300,@"id":@19,@"color":@0}]};
        NSString *coopRepeat = EIDAdvancedDescription(@"Base",300,80,0,none,context);
        NSCAssert([coopRepeat containsString:@"#P1:"] && [coopRepeat containsString:@"#P2:"], @"Co-op history is separate for each native player");
        context = AdvancedContext(database,code);
        context[@"pickup_context"] = @{@"collectible_cycle":@{@"items":@[@1,@25,@2,@118,@689]},
            @"crown_overview":@YES,@"crown_selection":@0};
        NSSet *cycleOwned = [NSSet setWithArray:@[@"5.100.723",@"5.100.706"]];
        NSString *overview = EIDAdvancedDescription(@"Not a real Crown pedestal",100,689,0,cycleOwned,context);
        for (NSNumber *item in @[@1,@25,@2,@118,@689]) {
            NSString *icon = [NSString stringWithFormat:@"{{Collectible%@}}",item];
            NSString *key = [NSString stringWithFormat:@"5.100.%@",item];
            NSCAssert([overview containsString:icon] && [overview containsString:context[@"item_names"][key]], @"Crown overview has all five native items and localized icons/names: %@",code);
        }
        NSCAssert(![overview containsString:@"Not a real Crown pedestal"] && ![overview containsString:@"{{Collectible723}} →"] &&
            ![overview containsString:@"{{Collectible706}}"], @"Overview never describes or rerolls an invented Glitched Crown pickup");
        NSCAssert([overview containsString:@"›"] && ![overview containsString:@"CONFIG_BoC_Toggle"] && ![overview containsString:@"{1}"], @"Desktop Tab hint is adapted to the iOS next indicator: %@",code);
        context[@"pickup_context"] = @{@"collectible_cycle":@{@"items":@[@1,@25,@2,@118,@689]},
            @"crown_overview":@NO,@"crown_selection":@5};
        NSString *selectedCycle = EIDAdvancedDescription(@"Selected item details",100,689,0,none,context);
        NSCAssert([selectedCycle hasPrefix:@"Selected item details#"] && [selectedCycle containsString:@"{{Collectible689}}"], @"The final item links back to the Crown overview");
        context[@"pickup_context"] = @{@"collectible_cycle":@{@"items":@[@1,@2,@3,@4]},@"crown_overview":@YES,@"crown_selection":@0};
        NSCAssert([EIDAdvancedDescription(@"Base",100,689,0,none,context) isEqual:@"Base"], @"Too few native variants do not create a fake Crown summary");
        context[@"pickup_context"] = @{@"collectible_cycle":@{@"items":@[@1,@1,@2,@3,@4]},@"crown_overview":@YES,@"crown_selection":@0};
        NSCAssert([EIDAdvancedDescription(@"Base",100,689,0,none,context) isEqual:@"Base"], @"Repeated IDs do not count as five distinct items");
        context = AdvancedContext(database,code);
        context[@"pickup_context"] = @{@"stars_previews":@[@{@"index":@0,@"items":@[@25],@"tarot":@NO}]};
        NSString *stars = EIDAdvancedDescription(@"Base",300,73,0,none,context);
        NSCAssert([stars containsString:@"{{Collectible25}}"] && [stars containsString:context[@"item_names"][@"5.100.25"]], @"The Stars? shows the native oldest removable item: %@",code);
        NSCAssert([EIDAdvancedDescription(@"Base",300,17,0,none,context) isEqual:@"Base"], @"Ordinary Stars is not reversed Stars");
        context[@"pickup_context"] = @{@"stars_previews":@[@{@"index":@0,@"items":@[@25,@2],@"tarot":@YES}]};
        NSString *twoStars = EIDAdvancedDescription(@"Base",300,73,0,none,context);
        NSCAssert([twoStars containsString:@"{{Collectible25}}"] && [twoStars containsString:@"{{Collectible2}}"], @"Tarot Cloth shows two native removals");
        context[@"pickup_context"] = @{@"stars_previews":@[@{@"index":@0,@"items":@[],@"tarot":@NO}]};
        NSCAssert([EIDAdvancedDescription(@"Base",300,73,0,none,context) isEqual:@"Base"], @"No eligible item never invents a Stars target");
        for (NSNumber *box in @[@NO,@YES]) for (NSNumber *gold in @[@NO,@YES]) {
            context[@"pickup_context"] = @{@"black_feather":@[@{@"index":@0,@"count":@3,@"box":box}]};
            NSString *feather = EIDAdvancedDescription(@"Base",350,80+(gold.boolValue ? 0x8000 : 0),0,none,context);
            NSString *number = [NSString stringWithFormat:@"%.4g",1.5*(box.boolValue ? 2 : 1)*(gold.boolValue ? 2 : 1)];
            NSString *tint = box.boolValue || gold.boolValue ? @"ColorGold" : @"ColorSilver";
            NSString *expectedDamage = [NSString stringWithFormat:@"{{%@}}%@{{CR}}",tint,number];
            NSCAssert([feather containsString:expectedDamage], @"Black Feather uses upstream ordinary/golden/Box math: %@",code);
            NSCAssert(![feather containsString:@"{1}"] && ![feather containsString:@"{2}"], @"Black Feather text is localized and fully substituted");
        }
        context[@"pickup_context"] = @{@"black_feather":@[@{@"index":@0,@"count":@0,@"box":@NO}]};
        NSCAssert([EIDAdvancedDescription(@"Base",350,80,0,none,context) containsString:@"{{CR}}0{{CR}}"], @"Removing the last evil item updates to zero");
        NSCAssert([EIDAdvancedDescription(@"Base",350,17,0,none,context) isEqual:@"Base"], @"Other trinkets do not get Black Feather's computed line");
        context[@"pickup_context"] = @{@"black_feather":@[@{@"index":@0,@"count":@-1,@"box":@NO}]};
        NSCAssert([EIDAdvancedDescription(@"Base",350,80,0,none,context) isEqual:@"Base"], @"Invalid counters fail closed");
        context = AdvancedContext(database,code);
        NSCAssert([EIDAdvancedDescription(@"+2",350,35,0,none,context) isEqual:@"+2"], @"Ordinary trinkets remain unchanged");
        NSString *gold = EIDAdvancedDescription(@"+2 {{Collectible2}}",350,0x8000+35,0,none,context);
        NSCAssert([gold containsString:@"{{ColorGold}}4{{CR}}"] && [gold containsString:@"{{Collectible2}}"], @"Double whole values, not sprite IDs");
        NSSet *box = [NSSet setWithObject:@"5.100.439"];
        NSCAssert([EIDAdvancedDescription(@"+2",350,0x8000+35,0,box,context) containsString:@"6{{CR}}"], @"Golden + Mom's Box triples");
        NSCAssert([EIDAdvancedDescription(@"50%",350,0x8000+2,0,none,context) containsString:@"60{{CR}}"], @"Petrified Poop uses its actual custom multiplier");
        NSCAssert([EIDAdvancedDescription(@"17%",350,0x8000+80,0,none,context) length], @"Unsupported entries remain safe");
        NSString *luck = EIDAdvancedDescription(@"Base",100,617,0,none,context);
        NSCAssert([luck containsString:@"{{ColorGreen}}100{{CR}}"] && [luck containsString:@"5"], @"Lodestone is guaranteed at five luck");
        NSCAssert([EIDAdvancedDescription(@"Base",100,496,0,none,context) containsString:@"{{ColorGreen}}5{{CR}}"], @"Euthanasia: 5 luck yields 5%%, not the newer patch formula");
        NSSet *dice = [NSSet setWithObject:@"5.100.723"];
        NSSet *abyss = [NSSet setWithObject:@"5.100.706"];
        NSMutableDictionary *abyssContext = context.mutableCopy;
        abyssContext[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":@0,@"luck":@0}]};
        for (NSNumber *identifier in @[@2,@3,@4,@6,@7,@10,@13,@25,@103,@118,@149,@153,@257,@305,@374,@494,@559,@34]) {
            NSString *preview = context[@"abyss_descriptions"][identifier.stringValue] ?: context[@"abyss_descriptions"][@"default"];
            NSString *expected = [NSString stringWithFormat:@"Base#{{Collectible706}} {{ColorRed}}%@{{CR}}",
                [preview stringByReplacingOccurrencesOfString:@"#" withString:@"#{{ColorRed}}"]];
            NSCAssert([EIDAdvancedDescription(@"Base",100,identifier.integerValue,0,abyss,abyssContext) isEqual:expected], @"Abyss matches original locust preview: %@ %@",code,identifier);
        }
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,none,context) isEqual:@"Base"], @"No Abyss preview after ownership is removed");
        NSCAssert([EIDAdvancedDescription(@"Base",350,35,0,abyss,context) isEqual:@"Base"], @"Abyss does not absorb trinkets");
        NSCAssert([EIDAdvancedDescription(@"Base",300,41,0,abyss,context) isEqual:@"Base"], @"Abyss does not absorb pocket items");
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,abyss,@{}) isEqual:@"Base"], @"An older database never invents missing Abyss text");
        context[@"inside_item_reminder"] = @YES;
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,abyss,context) containsString:@"{{Collectible706}}"], @"The original hypothetical locust information remains available in inventory descriptions");
        context[@"inside_item_reminder"] = @NO;
        NSString *chain = EIDAdvancedDescription(@"Base",100,10,0,dice,context);
        NSCAssert([chain containsString:@"{{Collectible9}}"] && [chain containsString:@"{{Collectible7}}"] && ![chain containsString:@"{{Collectible8}}"], @"Spindown skips hidden IDs");
        NSString *doubleChain = EIDAdvancedDescription(@"Base",100,10,0,[NSSet setWithArray:@[@"5.100.723",@"5.100.356"]],context);
        NSCAssert(![doubleChain containsString:@"{{Collectible9}}"] && [doubleChain containsString:@"{{Collectible7}}"], @"Car Battery performs two valid steps per use");
        NSString *greed = EIDAdvancedDescription(@"Base",100,10,2,dice,context);
        NSCAssert(![greed containsString:@"{{Collectible7}}"], @"Mode-disallowed items are skipped");
        context[@"inside_item_reminder"] = @YES;
        NSCAssert([EIDAdvancedDescription(@"Base",100,10,0,dice,context) isEqual:@"Base"], @"No chain on inventory reminder entries");
        context[@"inside_item_reminder"] = @NO;
        NSString *stop = EIDAdvancedDescription(@"Base",100,669,0,[NSSet setWithArray:@[@"5.100.723",@"5.100.356"]],context);
        NSCAssert([stop containsString:@"{{Collectible668}}"] && ![stop containsString:@"{{Collectible10}}"], @"Dad's Note ends the chain before a second Car Battery step");
        context[@"pickup_context"] = @{@"spindown":@{@"owned":@YES,@"validated":@YES,@"steps":@[
            @{@"result":@7,@"excluded":@[@{@"id":@9,@"locked":@YES}]},
            @{@"result":@5,@"excluded":@[@{@"id":@6,@"locked":@NO}]},
            @{@"result":@0,@"excluded":@[]}]}};
        NSString *nativeChain = EIDAdvancedDescription(@"Base",100,10,0,dice,context);
        NSCAssert(![nativeChain containsString:@"{{Collectible9}}"] && ![nativeChain containsString:@"{{Collectible6}}"] &&
            ![nativeChain containsString:@"{{Strike}}"] && ![nativeChain containsString:@"{{Warning}}"], @"Locked and restricted intermediates are completely hidden, not crossed out");
        NSCAssert([nativeChain containsString:@"{{Collectible7}}"] && [nativeChain containsString:@"{{Collectible5}}"] &&
            [nativeChain containsString:context[@"context_strings"][@"spindownError"]], @"Only actual eligible results and disappearance remain visible");
        NSString *expectedNativeChain = [NSString stringWithFormat:@"Base#{{Collectible723}} → {{Collectible7}} %@ → {{Collectible5}} %@ → %@",
            context[@"item_names"][@"5.100.7"],context[@"item_names"][@"5.100.5"],context[@"context_strings"][@"spindownError"]];
        NSCAssert([nativeChain isEqual:expectedNativeChain], @"Native Spindown results form one arrow-connected paragraph, not separate forced lines: %@",code);
        NSMutableDictionary *nativeBattery = [context[@"pickup_context"][@"spindown"] mutableCopy];
        nativeBattery[@"battery"] = @YES;
        context[@"pickup_context"] = @{@"spindown":nativeBattery};
        NSString *expectedBatteryChain = [expectedNativeChain stringByReplacingOccurrencesOfString:@"#{{Collectible723}} → " withString:@"#{{Collectible723}} → {{Collectible356}} "];
        NSCAssert([EIDAdvancedDescription(@"Base",100,10,0,dice,context) isEqual:expectedBatteryChain], @"Car Battery retains the same inline arrow chain: %@",code);
        context[@"pickup_context"] = @{@"spindown":@{@"owned":@NO}};
        NSCAssert([EIDAdvancedDescription(@"Base",100,10,0,dice,context) isEqual:@"Base"], @"Fresh removal clears stale ownership immediately");
        context[@"pickup_context"] = @{@"spindown":@{@"validated":@NO}};
        NSCAssert([EIDAdvancedDescription(@"Base",100,10,0,dice,context) isEqual:@"Base"], @"An unavailable native eligibility query never claims everything is unlocked");
        context[@"inside_item_reminder"] = @YES;
        NSDictionary *fullBag = @{@"validated":@YES,@"count":@8,@"result":@25,
            @"ingredients":@[@1,@1,@1,@1,@1,@1,@1,@1]};
        context[@"pickup_context"] = @{@"crafting_bag":fullBag,@"crafting_result":@YES};
        NSString *crafted = EIDAdvancedDescription(@"Result description",100,25,0,none,context);
        NSCAssert([crafted containsString:@"{{Collectible710}} 8/8"] &&
            [crafted containsString:@"{{Crafting1}}"] && [crafted containsString:@"→ {{Collectible25}}"] &&
            [crafted containsString:context[@"item_names"][@"5.100.25"]] &&
            [crafted hasSuffix:@"#Result description"], @"The full bag preview preserves the result's localized description: %@",code);
        context[@"inside_item_reminder"] = @NO;
        NSCAssert(![EIDAdvancedDescription(@"Base",100,25,0,none,context) containsString:@"8/8"], @"Bag result never replaces a floor pickup");
        context[@"inside_item_reminder"] = @YES;
        context[@"pickup_context"] = @{@"crafting_bag":@{@"validated":@YES,@"count":@2,@"result":@0,@"ingredients":@[@1,@2]}};
        NSString *partialBag = EIDAdvancedDescription(@"Bag description",100,710,0,none,context);
        NSCAssert([partialBag hasPrefix:@"{{Collectible710}} 2/8"] && ![partialBag containsString:@"→"], @"Incomplete bags show progress, never a guessed recipe");
        context[@"pickup_context"] = @{@"crafting_bag":fullBag,@"crafting_result":@YES};
        NSCAssert([EIDAdvancedDescription(@"Base",100,26,0,none,context) isEqual:@"Base"], @"Mismatched result never becomes another item's recipe");
        context[@"pickup_context"] = @{@"crafting_bag":@{@"validated":@YES,@"count":@8,@"result":@25,@"ingredients":@[@1]}};
        NSCAssert([EIDAdvancedDescription(@"Base",100,710,0,none,context) isEqual:@"Base"], @"Malformed bag metadata fails closed");
        context[@"inside_item_reminder"] = @NO;
        context[@"pickup_context"] = @{};
        for (NSArray *test in @[@[@300,@5,@286,@6],@[@300,@32,@263,@2],@[@70,@10,@348,@4],@[@1070,@10,@348,@4]]) {
            NSString *key = [NSString stringWithFormat:@"5.100.%@",test[2]];
            NSString *result = EIDAdvancedDescription(@"Base",[test[0] integerValue],[test[1] integerValue],0,[NSSet setWithObject:key],context);
            NSString *expected = [NSString stringWithFormat:@" %@{{Battery}}",test[3]];
            NSCAssert([result containsString:expected], @"Mimic cost comes from installed native XML: %@ %@ -> %@",code,test,result);
        }
        NSCAssert([EIDAdvancedDescription(@"Base",2070,10,0,[NSSet setWithObject:@"5.100.348"],context) isEqual:@"Base"], @"Unknown pill never leaks an effect through mimic cost");
        context[@"pickup_context"] = @{@"pedestal":@YES,@"flip_id":@25};
        NSString *flip = EIDAdvancedDescription(@"Base",100,1,0,none,context);
        NSCAssert([flip containsString:@"{{Collectible711}}"] && [flip containsString:context[@"item_names"][@"5.100.25"]], @"Flip displays the native alternate identity");
        NSMutableDictionary *player = [@{@"index":@0,@"type":@0,@"pocket_cards":@[@41],
            @"void_prediction":@{@"room":@[@0,@1,@1,@0,@0,@0],@"single":@[@1,@0,@0,@0,@0,@1],@"purchased":@[@1,@1,@1,@0,@0,@1]},
            @"black_rune_prediction":@{@"room":@[@0,@0,@0,@1,@0,@1],@"single":@[@0,@0,@1,@0,@0,@1],@"purchased":@[@1,@0,@0,@1,@0,@2]}} mutableCopy];
        context[@"live_state"] = @{@"players":@[player],@"room_pedestals":@[@{@"id":@1,@"options":@0}]};
        context[@"pickup_context"] = @{@"pedestal":@YES};
        NSString *prediction = EIDAdvancedDescription(@"Base",100,1,0,[NSSet setWithObject:@"5.100.477"],context);
        NSCAssert([prediction containsString:@"{{Collectible477}}"] && [prediction containsString:@"{{Card41}}"] && [prediction containsString:@"+2.5"], @"Void and Black Rune use their distinct copied predictions");
        context[@"pickup_context"] = @{@"pedestal":@YES,@"shop":@YES};
        NSCAssert([EIDAdvancedDescription(@"Base",100,1,0,none,context) containsString:@"+2"], @"Purchased item uses the extra-absorption prediction");
        player[@"owned"] = @[]; context[@"live_state"] = @{@"players":@[player]};
        NSCAssert([EIDAdvancedDescription(@"Base",300,5,0,[NSSet setWithObject:@"5.100.286"],context) isEqual:@"Base"], @"Co-op cannot borrow another player's mimic active");
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,abyss,context) isEqual:@"Base"], @"Co-op cannot borrow another player's Abyss");
        player[@"owned"] = @[@"5.100.706"]; context[@"live_state"] = @{@"players":@[player]};
        NSCAssert([EIDAdvancedDescription(@"Base",100,25,0,none,context) containsString:@"{{Collectible706}}"], @"Abyss follows the fresh personal native inventory, not a stale aggregate");
        NSCAssert([EIDAdvancedDescription(@"Base",100,1,0,none,@{}) isEqual:@"Base"], @"Unavailable native state fails closed");
    }
    puts("Advanced descriptions: golden trinkets, Luck, Spindown, mimic charges, Flip, absorption, Abyss, Wild Card, Vurp!, The Stars?, Black Feather and Glitched Crown passed in 20 languages");
}
