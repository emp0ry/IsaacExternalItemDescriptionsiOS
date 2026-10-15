#import "EIDAdvancedDescriptions.h"

static NSMutableDictionary *AdvancedContext(NSDictionary *database, NSString *code) {
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"golden_trinket_effects",@"golden_trinket_overrides",@"tarot_cloth_blank_card",@"context_strings",@"stat_names"]) {
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
        for (NSString *identifier in database[@"languages"][language][@"collectibles"]) {
            NSDictionary *entry = database[@"languages"][language][@"collectibles"][identifier];
            NSString *key = [@"5.100." stringByAppendingString:identifier];
            if ([entry[@"name"] length]) names[key] = entry[@"name"];
            if ([entry[@"description"] length]) details[key] = entry[@"description"];
        }
    }
    context[@"item_names"] = names; context[@"item_details"] = details;
    context[@"native_metadata"] = @{@"collectible_ids":@[@1,@2,@3,@4,@5,@6,@7,@8,@9,@10,@668,@669,@670],
        @"hidden_ids":@[@8],@"no_greed_ids":@[@7],@"no_challenge_ids":@[@6],@"active_ids":@[@34,@477],
        @"mimic_charges":@{@"300:5":@{@"active":@286,@"cost":@6},
            @"300:32":@{@"active":@263,@"cost":@2},@"70:10":@{@"active":@348,@"cost":@4}}};
    context[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":@0,@"luck":@5}]};
    return context;
}

void TestAdvancedDescriptions(NSDictionary *database) {
    NSSet *none = [NSSet set];
    for (NSString *code in database[@"languages"]) {
        NSMutableDictionary *context = AdvancedContext(database,code);
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
        NSCAssert([EIDAdvancedDescription(@"Base",100,1,0,none,@{}) isEqual:@"Base"], @"Unavailable native state fails closed");
    }
    puts("Advanced descriptions: golden trinkets, Luck, Spindown, mimic charges, Flip and absorption passed in 20 languages");
}
