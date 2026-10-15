#import "EIDContextDescriptions.h"
#import "EIDDynamicDescriptions.h"
#import "EIDCharacterSynergies.h"
#import "EIDInlineIconPolicy.h"
#import "EIDTransformationProgress.h"
#import "EIDNativeProbe.h"
#include "EIDPillPolicy.h"
void TestAdvancedDescriptions(NSDictionary *database);

// A read-only native snapshot, sufficient to exercise the production tracker.
@interface TestPlayerSnapshot : NSObject
@property(nonatomic, getter=isTransformationStateAvailable) BOOL transformationStateAvailable;
@property(nonatomic, getter=isOwnedCollectibleStateAvailable) BOOL ownedCollectibleStateAvailable;
@property(nonatomic, getter=isSuperBumActive) BOOL superBumActive;
@property(nonatomic) NSUInteger runCounter;
@property(nonatomic, copy) NSDictionary *forms;
@end
@implementation TestPlayerSnapshot
- (NSInteger)nativeTransformationCounterForFormID:(NSInteger)form { return [self.forms[@(form)] integerValue]; }
- (NSInteger)transformationCollectibleCountForID:(NSInteger)item { (void)item; return 0; }
- (NSInteger)ownedCollectibleCountForID:(NSInteger)item { (void)item; return 0; }
@end

static NSDictionary *Context(NSDictionary *database, NSString *language) {
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"conditionals", @"heart_replacements", @"birthright", @"greed_no_effect_notes",
                            @"car_battery", @"tarot_cloth", @"stat_names", @"pickup_names",
                            @"pandora_floor_lines", @"context_strings", @"BFFSSynergies", @"book_of_belial",
                            @"wisp_texts", @"wisp_extras", @"tear_flags"]) {
        NSMutableDictionary *entries = [database[@"languages"][@"en_us"][key] mutableCopy];
        [entries addEntriesFromDictionary:database[@"languages"][language][key]];
        context[key] = entries;
    }
    context[@"rules"] = database[@"context_rules"];
    context[@"weapon_rules"] = database[@"weapon_rules"];
    context[@"car_battery_metadata"] = database[@"car_battery_metadata"];
    context[@"pill_metadata"] = database[@"pill_metadata"];
    context[@"character_metadata"] = database[@"character_metadata"];
    context[@"native_metadata"] = @{@"active_ids":@[@33,@34,@35,@78,@133,@135,@164,@297,@584,@636,@653,@713],
        @"quest_ids":@[@238,@239,@327,@328,@626,@627,@633,@668],@"quest_metadata_available":@YES};
    context[@"live_state"] = @{@"active_ids":@[@33,@34,@78,@93,@386,@477]};
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    for (NSString *code in @[@"en_us", language]) {
        for (NSString *category in @[@"collectibles", @"trinkets"]) {
            NSString *prefix = [category isEqualToString:@"collectibles"] ? @"5.100." : @"5.350.";
            [database[@"languages"][code][category] enumerateKeysAndObjectsUsingBlock:
                ^(NSString *key, NSDictionary *entry, __unused BOOL *stop) {
                    if ([entry[@"name"] length]) names[[prefix stringByAppendingString:key]] = entry[@"name"];
                }];
        }
    }
    context[@"item_names"] = names;
    context[@"health_amounts"] = database[@"health_amounts"];
    context[@"healing_items"] = database[@"healing_items"];
    return context;
}

static NSString *PandoraLines(NSString *text) {
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [[text stringByReplacingOccurrencesOfString:@"{{NoLB}}" withString:@""]
            componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#;"]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length) [lines addObject:trimmed];
    }
    return [lines componentsJoinedByString:@"#"];
}

static void TestPillsAndCollection(NSDictionary *database) {
    for (NSString *language in database[@"languages"]) {
        NSMutableDictionary *context = [Context(database,language) mutableCopy];
        NSDictionary *strings = context[@"context_strings"];
        NSSet *falsePHD = [NSSet setWithObject:@"5.100.654"];
        NSString *damage = strings[@"FalsePHDDamage"], *horseDamage = strings[@"FalsePHDHorseDamage"];
        NSString *heart = strings[@"FalsePHDHeart"];
        NSCAssert(damage.length && horseDamage.length && heart.length, @"Pill translations fall back to English");
        for (NSNumber *effect in @[@7,@12,@14,@16,@18,@48]) {
            NSString *text = EIDContextDescriptionWithOwnedItems(@"Base",70,effect.integerValue,-1,0,falsePHD,context);
            NSCAssert([text containsString:damage] && ![text containsString:heart], @"False PHD stat down / shot-speed down grants damage");
            text = EIDContextDescriptionWithOwnedItems(@"Base",1070,effect.integerValue,-1,0,falsePHD,context);
            NSCAssert([text containsString:horseDamage], @"Horse damage doubles to 1.2");
        }
        for (NSNumber *effect in @[@2,@23,@26,@28,@30,@32,@38,@43]) {
            NSString *text = EIDContextDescriptionWithOwnedItems(@"Base",70,effect.integerValue,-1,0,falsePHD,context);
            NSCAssert([text containsString:heart], @"False PHD bad pill / I'm Excited grants a black heart");
        }
        for (NSNumber *effect in @[@8,@10,@15,@17,@33,@40])
            NSCAssert([EIDContextDescriptionWithOwnedItems(@"Base",70,effect.integerValue,-1,0,falsePHD,context)
                isEqualToString:@"Base"], @"Positive, neutral and class-0 pills have no invented reward");
        NSCAssert([EIDContextDescriptionWithOwnedItems(@"Unknown",2070,5,0,0,falsePHD,context)
            isEqualToString:@"Unknown"], @"Unknown pills expose neither effect nor synergy");
        NSCAssert([EIDContextDescriptionWithOwnedItems(@"Base",70,16,0,0,[NSSet set],context)
            isEqualToString:@"Base"], @"Without False PHD no bonus is shown");
        for (NSNumber *good in @[@75,@46,@303]) {
            NSSet *owned = [NSSet setWithObject:[NSString stringWithFormat:@"5.100.%@",good]];
            NSString *text = EIDContextDescriptionWithOwnedItems(@"Base",70,50,0,0,owned,context);
            NSCAssert([text containsString:strings[@"ExperimentalPillPHD"]], @"Good pill modifier prevents Experimental stat down");
        }
        NSString *experimental = EIDContextDescriptionWithOwnedItems(@"Base",70,50,0,0,falsePHD,context);
        NSCAssert([experimental containsString:strings[@"ExperimentalPillFalsePHD"]] &&
            [experimental containsString:damage], @"False PHD Experimental pill has no stat up and grants damage");
        NSSet *both = [NSSet setWithArray:@[@"5.100.75",@"5.100.654"]];
        experimental = EIDContextDescriptionWithOwnedItems(@"Base",1070,50,0,0,both,context);
        NSCAssert([experimental containsString:horseDamage] &&
            ![experimental containsString:strings[@"ExperimentalPillFalsePHD"]] &&
            ![experimental containsString:strings[@"ExperimentalPillPHD"]], @"PHD + False PHD cancel stat filtering, not the damage bonus");
        // One background scan deliberately retains both removed items. Fresh
        // main-thread modifiers must win even when the effect ID is unchanged.
        context[@"player_index"] = @0;
        context[@"live_state"] = @{@"players":@[@{@"index":@0,@"owned":both.allObjects}]};
        for (NSNumber *mask in @[@3,@2,@3,@1,@0,@(-1)]) {
            context[@"pill_modifiers"] = mask;
            NSInteger modifiers = mask.integerValue;
            BOOL bad = modifiers >= 0 && (modifiers & EIDPillModifierFalsePHD);
            BOOL good = modifiers >= 0 && (modifiers & EIDPillModifierPHD);
            for (NSNumber *variant in @[@70,@1070]) {
                NSString *expectedDamage = variant.integerValue == 1070 ? horseDamage : damage;
                NSString *down = EIDContextDescriptionWithOwnedItems(@"Base",variant.integerValue,16,0,0,both,context);
                NSCAssert([down containsString:expectedDamage] == bad, @"Removing False PHD clears damage despite stale inventory");
                NSString *paralysis = EIDContextDescriptionWithOwnedItems(@"Base",variant.integerValue,23,0,0,both,context);
                NSCAssert([paralysis containsString:heart] == bad, @"Removing False PHD clears black-heart reward");
                NSString *up = EIDContextDescriptionWithOwnedItems(@"Base",variant.integerValue,17,0,0,both,context);
                NSCAssert([up isEqualToString:@"Base"], @"Both items never grant a False PHD bonus to a positive pill");
                NSString *exp = EIDContextDescriptionWithOwnedItems(@"Base",variant.integerValue,50,0,0,both,context);
                NSCAssert([exp containsString:expectedDamage] == bad, @"Experimental damage follows current ownership");
                NSCAssert([exp containsString:strings[@"ExperimentalPillFalsePHD"]] == (bad && !good),
                    @"Both cancel bad filtering; removing PHD restores it");
                NSCAssert([exp containsString:strings[@"ExperimentalPillPHD"]] == (good && !bad),
                    @"Removing False PHD restores the PHD-only Experimental rule");
            }
            NSCAssert([EIDContextDescriptionWithOwnedItems(@"Unknown",2070,5,0,0,both,context)
                isEqualToString:@"Unknown"], @"No modifier combination reveals unknown pill bonuses");
        }
        [context removeObjectForKey:@"pill_modifiers"];
        context[@"player_index"] = @0;
        context[@"live_state"] = @{@"players":@[@{@"index":@0,@"owned":@[]},@{@"index":@1,@"owned":falsePHD.allObjects}]};
        NSCAssert([EIDContextDescriptionWithOwnedItems(@"Base",70,16,0,0,falsePHD,context)
            isEqualToString:@"Base"], @"Co-op partner's False PHD is not applied to this player");

        context[@"live_state"] = @{@"collection":@{@"slot":@2,@"progress_allowed":@YES,@"missing":@[@25,@626]}};
        context[@"native_metadata"] = @{@"hidden_ids":@[@626]};
        NSString *note = EIDCollectionDescription(@"Base",100,25,context);
        NSCAssert([note hasSuffix:strings[@"CollectionPageInfo"]] && [note containsString:@"{{Warning}}"], @"Active save's missing collectible has a final localized notice");
        NSCAssert([EIDCollectionDescription(@"Base",100,26,context) isEqualToString:@"Base"], @"Already collected item is not flagged");
        NSCAssert([EIDCollectionDescription(@"Base",100,626,context) isEqualToString:@"Base"], @"Hidden quest item is excluded");
        NSCAssert([EIDCollectionDescription(@"Base",300,25,context) isEqualToString:@"Base"], @"Cards are not collection-page collectibles");
        context[@"inside_item_reminder"] = @YES;
        NSCAssert([EIDCollectionDescription(@"Base",100,25,context) isEqualToString:@"Base"], @"Reminder never tells the player to collect an owned item");
        context[@"inside_item_reminder"] = @NO;
        context[@"live_state"] = @{@"collection":@{@"slot":@2,@"progress_allowed":@NO,@"missing":@[@25]}};
        NSCAssert([EIDCollectionDescription(@"Base",100,25,context) isEqualToString:@"Base"], @"Read-only/custom runs do not promise collection progress");
        context[@"live_state"] = @{};
        NSCAssert([EIDCollectionDescription(@"Base",100,25,context) isEqualToString:@"Base"], @"Unavailable collection state fails closed");
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Pass the bundled descriptions database");
        NSData *bytes = [NSData dataWithContentsOfFile:@(argv[1])];
        NSDictionary *database = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];
        NSCAssert(database[@"context_rules"], @"Context data is bundled");
        TestPillsAndCollection(database);
        TestAdvancedDescriptions(database);
        for (NSString *token in @[@"Damage",@"Speed",@"Tears",@"Range",@"Shotspeed",@"Luck",
                                   @"AngelChance",@"DevilChance",@"Tearsize"]) {
            NSCAssert([EIDRepentanceStatIconAlias(token) isEqualToString:[token stringByAppendingString:@"REP"]],
                @"Older atlases resolve the original Repentance stat frame");
        }
        NSCAssert(!EIDRepentanceStatIconAlias(@"Heart") && !EIDRepentanceStatIconAlias(@"Unknown"),
            @"Ordinary and unknown tokens are not incorrectly remapped");
        for (NSString *language in @[@"en_us", @"ru"]) {
            NSDictionary *context = Context(database, language);
            NSString *lostName = [language isEqualToString:@"ru"] ? @"Потерянный" : @"The Lost";
            NSCAssert([context[@"birthright"][@"10"][0] isEqualToString:lostName],
                @"Native Lost ID 10 must never resolve to Eden");
            NSString *breakfast = database[@"languages"][language][@"collectibles"][@"25"][@"description"];
            NSString *lostBreakfast = EIDContextDescription(breakfast,100,25,10,0,context);
            NSCAssert([lostBreakfast containsString:lostName] && ![lostBreakfast containsString:@"Eden"] &&
                ![lostBreakfast containsString:@"Эдем"], @"Real Breakfast description on Lost uses Lost's actual name");
            NSString *lostBirthright = EIDContextDescription(@"Original",100,619,10,0,context);
            NSCAssert([lostBirthright containsString:[language isEqualToString:@"ru"] ?
                @"Предметы, дающие здоровье" : @"Prevents items useless to The Lost"],
                @"Birthright grants the Lost effect, not Eden's three-item reward");
            NSString *name = context[@"birthright"][@"10"][0];
            NSString *noEffect = [context[@"conditionals"][@"No Effect Replace"][0]
                stringByReplacingOccurrencesOfString:@"{1}" withString:name];
            NSCAssert([EIDContextDescription(@"Grants flight",100,20,10,0,context) isEqualToString:noEffect], @"Lost flight item has no effect");
            NSCAssert([EIDContextDescription(@"Grants flight",100,20,0,0,context) isEqualToString:@"Grants flight"], @"Isaac keeps the original effect");
            NSCAssert([EIDContextDescription(@"Grants flight",100,20,-1,0,context) isEqualToString:@"Grants flight"], @"Unknown player context fails closed");
            NSString *warning = EIDContextDescription(@"Damage up",100,126,31,0,context);
            NSCAssert([warning containsString:@"{{Warning}}"] && ![warning containsString:@"{1}"], @"Tainted Lost gets a translated lethal-use warning");
            NSString *greed = EIDContextDescription(@"Original",100,416,0,2,context);
            NSString *greedier = EIDContextDescription(@"Original",100,416,0,3,context);
            NSCAssert(![greed isEqualToString:@"Original"] && [greed isEqualToString:greedier], @"Repentance Greed and Greedier override Deep Pockets");
            NSCAssert([EIDContextDescription(@"Original",100,416,0,1,context) isEqualToString:@"Original"], @"Hard mode is not Greed");
            NSCAssert([EIDContextDescription(@"Hidden",2070,8,10,2,context) isEqualToString:@"Hidden"], @"Context never identifies an unknown pill");
            NSCAssert([EIDContextDescription(@"Original",100,619,10,0,context) isEqualToString:context[@"birthright"][@"10"][2]], @"Birthright uses the actual character");
            NSString *bones = EIDContextDescription(@"Original bone-heart effects",100,549,14,0,context);
            NSCAssert([bones isEqualToString:context[@"conditionals"][@"5.100.549"][0]] &&
                [bones containsString:@"+0.4"] && ![bones containsString:@"Original"],
                @"Keeper Brittle Bones fully replaces the base text with +0.4 fire rate");
            NSString *blood = EIDContextDescription(@"↑ {{Heart}} +1 Health",100,15,36,0,context);
            NSCAssert([blood containsString:@"+12"] && ![blood containsString:@"{1}"],
                @"Tainted Bethany health pickups include the original item-specific blood-charge reward");
        }
        NSDictionary *english = Context(database,@"en_us");
        NSMutableDictionary *floorContext = [english mutableCopy];
        floorContext[@"live_state"] = @{@"floor":@{@"stage":@1,@"alternate":@NO}};
        NSString *floorRows = EIDDynamicDescription(@"{{NoLB}}Intro:#B1: 2; B2: 2#{{NoLB}}C1: Boss; C2: C1 + 2",100,297,
            0,[NSSet set],@{});
        NSCAssert([floorRows isEqualToString:@"Intro:#B1: 2#B2: 2#C1: Boss#C2: C1 + 2"],
            @"Pandora always separates semicolon floors even without live data and removes NoLB");
        floorRows = EIDDynamicDescription(database[@"languages"][@"en_us"][@"collectibles"][@"297"][@"description"],
            100,297,0,[NSSet set],floorContext);
        NSCAssert([floorRows containsString:@"{{ColorBagComplete}}B1: 2{{SoulHeart}}{{CR}}#B2:"] &&
            ![floorRows containsString:@";"] && ![floorRows containsString:@"{{NoLB}}"],
            @"Real English Pandora highlights only B1 and puts B2 on its own row");
        NSString *health = EIDContextDescription(@"↑ {{Heart}} +1 Health#Other bonus",100,15,10,0,english);
        NSCAssert([health isEqualToString:@"Other bonus"], @"Lost health lines are removed while other effects remain");
        NSCAssert([EIDContextDescription(@"↑ {{Heart}} +1 Health",100,15,4,0,english) containsString:@"SoulHeart"], @"Blue Baby health is converted to soul hearts");
        NSCAssert([EIDContextDescription(@"Each room",100,266,0,2,english) isEqualToString:@"Each wave"], @"Greed changes room triggers to wave triggers");
        NSCAssert([database[@"weapon_rules"] count] > 300, @"The full Repentance weapon block is bundled");
        NSCAssert(![database[@"car_battery_metadata"][@"no_synergy"] containsObject:@34] &&
            [database[@"car_battery_metadata"][@"no_synergy"] containsObject:@33],
            @"Repentance Book of Belial has a synergy, Bible does not");
        NSCAssert(![database[@"car_battery_metadata"][@"no_synergy"] containsObject:@285] &&
            [database[@"car_battery_metadata"][@"no_synergy"] containsObject:@728],
            @"Repentance patches are used, not AB+ or Repentance+ patches");
        NSString *decimal = EIDContextDescriptionWithOwnedItems(@"6.5 seconds, not 16.5",100,93,0,0,
            [NSSet setWithObject:@"5.100.356"],english);
        NSCAssert([decimal isEqualToString:@"{{BlinkYellowGreen}}13{{CR}} seconds, not 16.5"],
            @"Numeric replacement accepts decimals and changes one complete number");
        NSString *numbers = EIDContextDescriptionWithOwnedItems(@"10 first; 1 heart",100,78,0,0,
            [NSSet setWithObject:@"5.100.356"],english);
        NSCAssert([numbers isEqualToString:@"10 first; {{BlinkYellowGreen}}2{{CR}} heart"],
            @"Replacing 1 does not mutate 10");
        for (NSString *language in database[@"languages"]) {
            NSDictionary *context = Context(database,language);
            NSSet *batteryOwned = [NSSet setWithObject:@"5.100.356"];
            NSString *book = database[@"languages"][language][@"collectibles"][@"78"][@"description"]
                ?: database[@"languages"][@"en_us"][@"collectibles"][@"78"][@"description"];
            NSString *charged = EIDContextDescriptionWithOwnedItems(book,100,78,0,0,batteryOwned,context);
            NSCAssert([charged containsString:@"2"] && ![charged isEqualToString:book],
                @"Book of Revelations shows the doubled effect (%@): %@",language,charged);
            NSCAssert([EIDContextDescriptionWithOwnedItems(book,100,78,0,0,[NSSet set],context) isEqualToString:book],
                @"Without Car Battery the original active description remains unchanged");
            NSString *bible = EIDContextDescriptionWithOwnedItems(@"Flight",100,33,0,0,batteryOwned,context);
            NSCAssert([bible containsString:context[@"car_battery"][@"No Effect"]] &&
                [bible containsString:@"{{Item5.100.356}}"], @"No-synergy active gets the localized battery warning");
            NSString *card = database[@"languages"][language][@"cards"][@"6"][@"description"]
                ?: database[@"languages"][@"en_us"][@"cards"][@"6"][@"description"];
            NSString *cloth = EIDContextDescriptionWithOwnedItems(card,300,6,0,0,
                [NSSet setWithObject:@"5.100.451"],context);
            NSCAssert([cloth containsString:@"3"] && ![cloth isEqualToString:card],
                @"Repentance Hierophant uses the actual original three-heart Tarot Cloth effect");
            NSCAssert([EIDContextDescriptionWithOwnedItems(@"Rune",300,32,0,0,
                [NSSet setWithObject:@"5.100.451"],context) isEqualToString:@"Rune"], @"Tarot Cloth does not invent a rune buff");
            NSMutableDictionary *dynamic = [context mutableCopy];
            NSString *pandora = database[@"languages"][language][@"collectibles"][@"297"][@"description"];
            NSString *normalizedPandora = PandoraLines(pandora);
            for (NSNumber *stage in @[@1,@4,@10,@11,@12,@13]) {
                for (NSNumber *alternate in @[@NO,@YES]) {
                    dynamic[@"live_state"] = @{@"floor":@{@"stage":stage,@"alternate":alternate}};
                    NSString *result = EIDDynamicDescription(pandora,100,297,0,[NSSet set],dynamic);
                    static const NSInteger blocks[] = {0,1,2,3,4,5,6,7,8,9,10,12,9,14};
                    NSInteger index = blocks[stage.integerValue] +
                        ((stage.integerValue == 10 || stage.integerValue == 11) && alternate.boolValue ? 1 : 0);
                    NSString *line = dynamic[@"pandora_floor_lines"][[NSString stringWithFormat:@"normal.%ld",(long)index]];
                    BOOL exists = line.length && [pandora containsString:line];
                    if (line.length) line = PandoraLines(line);
                    NSCAssert((exists ? [result containsString:[NSString stringWithFormat:@"{{ColorBagComplete}}%@{{CR}}",line]] :
                        [result isEqualToString:normalizedPandora]), @"Only the available exact current-floor segment is highlighted");
                    NSCAssert(![result containsString:@";"] && ![result containsString:@"{{NoLB}}"],
                        @"Every language's floor rewards are rendered on separate rows");
                }
            }
            for (NSNumber *stage in @[@1,@2,@3,@4,@5,@6,@7]) {
                dynamic[@"live_state"] = @{@"floor":@{@"stage":stage,@"alternate":@NO}};
                NSString *base = EIDContextDescription(pandora,100,297,0,2,context);
                NSString *result = EIDDynamicDescription(base,100,297,2,[NSSet set],dynamic);
                NSString *line = dynamic[@"pandora_floor_lines"][[NSString stringWithFormat:@"greed.%ld",(long)MIN(stage.integerValue,6)]];
                line = PandoraLines(line);
                NSCAssert(([result containsString:[NSString stringWithFormat:@"{{ColorBagComplete}}%@{{CR}}",line]]),
                    @"Greed and Greedier highlight their own current payout");
            }
            dynamic[@"live_state"] = @{};
            NSCAssert([EIDDynamicDescription(pandora,100,297,0,[NSSet set],dynamic) isEqualToString:normalizedPandora],
                @"Unavailable floor data never guesses a highlighted payout");
            NSString *keyReward = EIDDynamicDescription(pandora,100,297,0,
                [NSSet setWithObject:@"5.350.175"],dynamic);
            NSCAssert([keyReward containsString:@"{{Item5.350.175}} {{ColorBagComplete}}"],
                @"Strange Key highlights its override rather than a false floor reward");
            NSDictionary *player = @{@"type":@0,@"speed":@1,@"fire_delay":@9,@"damage":@0.1,
                @"range":@260,@"coins":@10,@"bombs":@0,@"keys":@2};
            dynamic[@"live_state"] = @{@"players":@[player]};
            NSString *prediction = EIDDynamicDescription(@"Original",100,644,0,[NSSet set],dynamic);
            NSCAssert([prediction containsString:@"↑ {{Damage}}"] && ![prediction containsString:@"↑ {{Speed}}"] &&
                [prediction containsString:@"{{Bomb}}"], @"Consolation compares normalized stats and weighted consumables");
            NSCAssert([EIDDynamicDescription(@"Other item",100,1,0,[NSSet setWithObject:@"5.100.644"],dynamic)
                isEqualToString:@"Other item"], @"Prediction is scoped to Consolation Prize, not unrelated pedestals");
            for (NSNumber *type in @[@18,@36]) {
                NSMutableDictionary *bethany = player.mutableCopy;
                bethany[@"type"] = type;
                bethany[type.integerValue == 18 ? @"soul_charge" : @"blood_charge"] = @0;
                dynamic[@"live_state"] = @{@"players":@[bethany]};
                prediction = EIDDynamicDescription(@"Original",100,644,0,[NSSet set],dynamic);
                NSCAssert([prediction containsString:type.integerValue == 18 ? @"{{SoulHeart}}" : @"{{Heart}}"],
                    @"Bethany's special charge pool participates in consumable prediction");
            }
            NSString *fetus = context[@"item_names"][@"5.100.52"];
            NSString *trisagion = context[@"item_names"][@"5.100.533"];
            NSString *overridden = [context[@"conditionals"][@"Overridden"]
                stringByReplacingOccurrencesOfString:@"{1}" withString:fetus];
            NSString *overrides = [context[@"conditionals"][@"Overrides"]
                stringByReplacingOccurrencesOfString:@"{1}" withString:trisagion];
            NSString *result = EIDContextDescriptionWithOwnedItems(@"Beam effect",100,533,0,0,
                [NSSet setWithObject:@"5.100.52"],context);
            NSCAssert([result isEqualToString:[@"Beam effect#{{Item5.100.52}} " stringByAppendingString:overridden]],
                @"Owned Dr. Fetus overrides Trisagion with the localized item name and icon");
            result = EIDContextDescriptionWithOwnedItems(@"Bomb effect",100,52,0,0,
                [NSSet setWithObject:@"5.100.533"],context);
            NSCAssert([result isEqualToString:[@"Bomb effect#{{Item5.100.533}} " stringByAppendingString:overrides]],
                @"A Dr. Fetus pedestal warns in the reverse direction as well");
            NSCAssert([EIDContextDescriptionWithOwnedItems(@"Beam effect",100,533,0,0,
                [NSSet set],context) isEqualToString:@"Beam effect"], @"Unknown or empty inventory preserves the base");
            result = EIDContextDescriptionWithOwnedItems(@"Beam effect",100,533,0,0,
                [NSSet setWithObjects:@"5.100.52",@"5.100.118",nil],context);
            NSCAssert([result containsString:@"{{Item5.100.52}}"] &&
                ![result containsString:@"{{Item5.100.118}}"], @"Higher-priority Dr. Fetus suppresses lower Brimstone warnings");
            result = EIDContextDescriptionWithOwnedItems(@"Beam effect",100,533,0,0,
                [NSSet setWithObjects:@"5.100.52",@"5.100.168",nil],context);
            NSCAssert([result containsString:@"{{Item5.100.168}}"] &&
                ![result containsString:@"{{Item5.100.52}}"], @"Epic Fetus has priority over Dr. Fetus");
            for (NSNumber *player in @[@7,@28]) {
                result = EIDContextDescriptionWithOwnedItems(@"Bomb effect",100,52,player.integerValue,0,
                    [NSSet set],context);
                NSCAssert([result containsString:context[@"item_names"][@"5.100.118"]] &&
                    ![result containsString:@"NameOnly"], @"Azazel's native weapon is considered without an owned Brimstone item");
            }
            for (NSNumber *pedestal in @[@168,@118]) {
                NSSet *owned = [NSSet setWithObject:pedestal.integerValue == 168 ? @"5.100.118" : @"5.100.168"];
                result = EIDContextDescriptionWithOwnedItems(@"Original",100,pedestal.integerValue,0,0,owned,context);
                NSCAssert([result containsString:context[@"item_names"][@"5.100.168"]] &&
                    ![result containsString:@"{1}"] && ![result containsString:@"NameOnly"],
                    @"Special missile/Brimstone synergy retains the same priority name in either direction");
            }
            result = EIDContextDescriptionWithOwnedItems(@"Original",100,579,0,0,
                [NSSet setWithObject:@"5.100.68"],context);
            NSCAssert([result containsString:@"{{Item5.100.68}}"] &&
                ![result isEqualToString:@"Original"], @"Spirit Sword/Technology is a special synergy, not a no-effect claim");
            result = EIDContextDescriptionWithOwnedItems(@"Original",350,144,0,0,
                [NSSet setWithObject:@"5.100.52"],context);
            NSCAssert([result containsString:@"{{Item5.100.52}}"], @"Weapon override applies to affected trinkets too");
            NSCAssert([EIDContextDescriptionWithOwnedItems(@"Original",100,374,0,0,
                [NSSet setWithObject:@"5.100.52"],context) isEqualToString:@"Original"],
                @"AB+-only Holy Light/Dr. Fetus override must not leak into Repentance");
            NSString *base = database[@"languages"][language][@"collectibles"][@"241"][@"description"]
                ?: database[@"languages"][@"en_us"][@"collectibles"][@"241"][@"description"];
            NSString *notice = context[@"conditionals"][@"No Effect (Greed)"];
            for (NSNumber *difficulty in @[@0, @1, @2, @3]) {
                result = EIDContextDescription(base,100,241,14,difficulty.integerValue,context);
                for (NSString *legacy in context[@"greed_no_effect_notes"][@"5.100.241"]) {
                    NSCAssert(![result containsString:legacy], @"Legacy base Greed note is handled by the conditional");
                }
                NSUInteger count = [result componentsSeparatedByString:notice].count - 1;
                NSCAssert(count == (difficulty.integerValue >= 2 ? 1u : 0u),
                    @"Each language shows exactly one conditional Greed notice in Greed, none in normal/hard");
            }
            NSString *rib = database[@"languages"][language][@"trinkets"][@"84"][@"description"];
            if (rib) NSCAssert([EIDContextDescription(rib,350,84,0,0,context) isEqualToString:rib],
                @"Greed enemy names are not stripped from normal Rib of Greed descriptions");
        }
        for (NSString *language in database[@"languages"]) {
            NSMutableDictionary *context = [Context(database,language) mutableCopy];
            NSDictionary *texts = context[@"conditionals"];
            NSString *eyes = EIDContextDescription(@"Original",100,600,2,0,context);
            NSCAssert(![eyes isEqualToString:@"Original"], @"Cain gets the localized Eye Drops one-eye multiplier (%@): %@",language,eyes);
            if ([language isEqualToString:@"en_us"]) NSCAssert([eyes containsString:@"1.2"], @"English one-eye multiplier remains exactly 1.2");
            NSCAssert([EIDContextDescription(@"Original",100,600,0,0,context) isEqualToString:@"Original"], @"Isaac keeps the normal Eye Drops description");
            NSCAssert([EIDContextDescription(@"Original",100,596,27,0,context) containsString:texts[@"Ice Tears"]], @"Uranus warns Tainted Samson");
            if ([texts[@"Keeper 0-1"] isKindOfClass:NSString.class])
                NSCAssert(![EIDContextDescription(@"Original",100,135,14,0,context) isEqualToString:@"Original"], @"IV Bag has Keeper's specific payout");
            if ([texts[@"5.100.482"] isKindOfClass:NSString.class])
                NSCAssert([EIDContextDescription(@"Original",100,482,31,0,context) containsString:texts[@"5.100.482"]], @"Tainted Clicker explanation is imported");
            NSCAssert([EIDContextDescription(@"Original",100,482,0,0,context) isEqualToString:@"Original"], @"Normal Clicker has no tainted warning");
            NSCAssert([EIDContextDescription(@"Original",100,482,20,0,context) isEqualToString:@"Original"], @"Esau is not a tainted character despite the equivalence table");
            if ([texts[@"5.100.81"] isKindOfClass:NSString.class])
                NSCAssert([EIDContextDescription(@"Original",100,81,4,0,context) containsString:texts[@"5.100.81"]], @"Dead Cat explains non-red health");
            NSCAssert([EIDContextDescription(@"Original",100,81,0,0,context) isEqualToString:@"Original"], @"Red-health Dead Cat remains unchanged");
            for (NSNumber *type in @[@13,@32]) {
                NSString *buff = context[@"BFFSSynergies"][type.integerValue == 13 ? @"Lilith" : @"Tainted Lilith"];
                NSCAssert([EIDContextDescription(@"Original",100,247,type.integerValue,0,context) containsString:buff], @"BFFS explains the character's native familiar");
            }
            context[@"live_state"] = @{@"players":@[@{@"type":@0,@"owned":@[]},@{@"type":@10,@"owned":@[@"5.100.584"]}]};
            NSString *coop = EIDContextDescription(@"Original",100,20,0,0,context);
            NSCAssert([coop containsString:context[@"birthright"][@"10"][0]], @"Closest-player difference is reported for the Lost partner");
            NSCAssert([coop containsString:@"Original"], @"Partner's no-effect rule must not erase Isaac's flight description");
            context[@"inside_item_reminder"] = @YES;
            NSCAssert([EIDContextDescription(@"Original",100,20,0,0,context) isEqualToString:@"Original"], @"Pause description excludes partner warnings");
            NSString *isolated = EIDCharacterSynergyDescription(@"Original",100,35,0,
                [NSSet setWithObject:@"5.100.584"],context);
            NSCAssert([isolated isEqualToString:@"Original"], @"Partner's Book of Virtues is not applied to the player's reminder");
            context[@"inside_item_reminder"] = @NO;
            context[@"live_state"] = @{@"floor":@{@"stage":@1}};
            NSString *wisp = EIDCharacterSynergyDescription(@"Original",100,35,18,[NSSet setWithObject:@"5.100.584"],context);
            NSCAssert([wisp containsString:@"{{Wisp}}"] && [wisp containsString:@"4"] &&
                ![wisp containsString:@"{damage}"] && ![wisp containsString:@"{health}"], @"Wisp native-stage stats and named templates resolve");
            NSMutableDictionary *allWispContext = context.mutableCopy;
            NSMutableArray *wispActives = [NSMutableArray array];
            for (NSString *key in database[@"character_metadata"][@"wisps"]) [wispActives addObject:@(key.integerValue)];
            allWispContext[@"native_metadata"] = @{@"active_ids":wispActives};
            for (NSNumber *active in wispActives) {
                NSString *rendered = EIDCharacterSynergyDescription(@"Original",100,active.integerValue,18,
                    [NSSet setWithObject:@"5.100.584"],allWispContext);
                NSCAssert(![rendered containsString:@"{ringIcon}"] && ![rendered containsString:@"{amount}"] &&
                    ![rendered containsString:@"{health}"] && ![rendered containsString:@"{damage}"],
                    @"Every Repentance wisp renders in every language (%@, %@)",language,active);
            }
            NSString *roomWisp = EIDCharacterSynergyDescription(@"Original",100,164,18,[NSSet setWithObject:@"5.100.584"],context);
            NSCAssert([roomWisp containsString:context[@"wisp_texts"][@"SingleRoom"]], @"Single-room wisps are marked");
            NSCAssert([roomWisp containsString:@"{{Damage}} 2.5"], @"Candle wisp retains the damage icon token before its 2.5 DPS");
            NSString *none = EIDCharacterSynergyDescription(@"Original",100,636,18,[NSSet setWithObject:@"5.100.584"],context);
            NSCAssert([none containsString:context[@"wisp_texts"][@"NoWisps"]], @"R Key has no wisps");
            NSString *belial = EIDCharacterSynergyDescription(@"Original",100,133,3,[NSSet setWithObject:@"5.100.59"],context);
            NSCAssert([belial containsString:context[@"book_of_belial"][@"133"]], @"Passive Belial adds the actual active's extra effect");
            NSCAssert([EIDCharacterSynergyDescription(@"Original",100,133,3,[NSSet set],context) isEqualToString:@"Original"], @"Judas alone does not invent passive Belial");
            NSMutableDictionary *virtualBelial = context.mutableCopy;
            virtualBelial[@"player_index"] = @0;
            for (NSNumber *type in @[@3,@12]) {
                virtualBelial[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":type,
                    @"owned":@[@"5.100.619"],@"has_passive_belial":@YES}]};
                NSString *actual = EIDCharacterSynergyDescription(@"Original",100,133,type.integerValue,
                    [NSSet setWithObject:@"5.100.619"],virtualBelial);
                NSCAssert([actual containsString:context[@"book_of_belial"][@"133"]],
                    @"Judas/Black Judas Birthright applies without a raw count of hidden collectible 59");
            }
            virtualBelial[@"live_state"] = @{@"players":@[@{@"index":@0,@"type":@3,
                @"owned":@[@"5.100.619"],@"has_passive_belial":@NO}]};
            NSCAssert([EIDCharacterSynergyDescription(@"Original",100,133,3,[NSSet setWithObject:@"5.100.59"],
                virtualBelial) isEqualToString:@"Original"], @"Native disabled-effect state takes precedence over raw ownership");
            virtualBelial[@"live_state"] = @{@"players":@[
                @{@"index":@0,@"type":@3,@"owned":@[],@"has_passive_belial":@NO},
                @{@"index":@1,@"type":@3,@"owned":@[@"5.100.619"],@"has_passive_belial":@YES}]};
            virtualBelial[@"inside_item_reminder"] = @YES;
            NSCAssert([EIDCharacterSynergyDescription(@"Original",100,133,3,[NSSet set],virtualBelial)
                isEqualToString:@"Original"], @"Same-character partner's Birthright does not leak into pause reminder");
            virtualBelial[@"inside_item_reminder"] = @NO;
            NSCAssert(![EIDCharacterSynergyDescription(@"Original",100,133,3,[NSSet set],virtualBelial)
                isEqualToString:@"Original"], @"Floor synergy follows original EID's any-player ownership rule");
            context[@"live_state"] = @{@"salvage_allowed":@YES,@"room_type":@14,@"room_pool":@3,
                @"players":@[@{@"type":@23,@"owned":@[@"5.100.619",@"5.350.42",@"5.350.34",@"5.350.22"]}]};
            NSString *salvage = EIDCharacterSynergyDescription(@"Original",100,25,23,[NSSet set],context);
            NSCAssert([salvage containsString:context[@"context_strings"][@"TaintedCainPedestalBaseBirthright"]] && [salvage containsString:@"{{Trinket42}}"] &&
                [salvage containsString:@"{{Trinket34}}"] && [salvage containsString:@"{{Trinket22}}"] &&
                ![salvage containsString:@"Original"] && ![salvage containsString:@"{1}"], @"Tainted Cain salvage uses personal Birthright, trinkets and room pool");
            NSCAssert(!EIDUsesSalvageDescription(100,327,23,context), @"Quest items are never described as salvage");
            context[@"inside_item_reminder"] = @YES;
            NSCAssert(!EIDUsesSalvageDescription(100,25,23,context), @"Owned items in pause are not salvage pedestals");
            context[@"inside_item_reminder"] = @NO;
            context[@"live_state"] = @{@"salvage_allowed":@NO};
            NSCAssert(!EIDUsesSalvageDescription(100,25,23,context), @"Death Certificate, Cantripped and excluded room contexts preserve the item");
            context[@"live_state"] = @{};
            NSCAssert(!EIDUsesSalvageDescription(100,25,23,context), @"Unavailable native context fails closed");
        }
        NSMutableDictionary *twins = [Context(database,@"en_us") mutableCopy];
        twins[@"player_type"] = @23;
        twins[@"player_index"] = @1;
        twins[@"live_state"] = @{@"salvage_allowed":@YES,@"players":@[
            @{@"index":@0,@"type":@23,@"owned":@[@"5.100.619"]},
            @{@"index":@1,@"type":@23,@"owned":@[]}]};
        NSString *personal = EIDCharacterSynergyDescription(@"Original",100,25,23,
            [NSSet setWithObject:@"5.100.619"],twins);
        NSCAssert([personal containsString:@"3-8"] && ![personal containsString:@"6-16"], @"Same-character co-op does not borrow Birthright from the other player");
        twins[@"player_index"] = @0;
        NSCAssert([EIDCharacterSynergyDescription(@"Original",100,25,23,[NSSet set],twins) containsString:@"6-16"], @"The actual Birthright owner gets the doubled salvage");
        TestPlayerSnapshot *snapshot = [TestPlayerSnapshot new];
        snapshot.transformationStateAvailable = YES;
        snapshot.forms = @{@11:@2, @13:@1};
        EIDTransformationProgress *tracker = [EIDTransformationProgress new];
        tracker.probe = (EIDNativeProbe *)snapshot;
        [tracker setValue:@{@"70:10":@[@14], @"70:33":@[@15], @"350:169":@[@1]} forKey:@"assignments"];
        NSCAssert(tracker.required == 3, @"Default requirement never becomes zero");
        NSCAssert([[tracker transformationsForVariant:70 subtype:10] isEqualToArray:@[@14]], @"Puberty has Adult progress");
        NSCAssert([[tracker transformationsForVariant:1070 subtype:10] isEqualToArray:@[@14]], @"Horse Puberty uses the same transformation");
        NSCAssert(![tracker transformationsForVariant:2070 subtype:10].count, @"Unknown pills reveal no transformation");
        NSCAssert([tracker progressForTransformation:14] == 2 && [tracker progressForTransformation:15] == 1, @"Pill transformations read persisted counters");
        snapshot.forms = @{@11:@3};
        NSCAssert([tracker progressForTransformation:14] == 3, @"Adult counter updates and survives snapshot reload");
        snapshot.forms = @{@11:@4, @13:@5};
        NSCAssert([tracker progressForTransformation:14] == 4 && [tracker progressForTransformation:15] == 5 &&
            tracker.required == 3, @"Actual counters can display 4/3 and 5/3 without changing the requirement");
        puts("Context descriptions and pill transformation tests passed");
    }
    return 0;
}
