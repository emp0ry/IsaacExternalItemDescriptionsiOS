#import "EIDDescriptionStore.h"
#import "EIDLogger.h"
#import "EIDNativeProbe.h"
#import <dlfcn.h>
#import <string.h>

static const unsigned char kEIDDescriptionStoreImageAnchor = 0;

static NSString *EIDOwnImageDirectory(void) {
    Dl_info imageInfo = {};
    if (!dladdr(&kEIDDescriptionStoreImageAnchor, &imageInfo) || !imageInfo.dli_fname) return nil;
    NSString *imagePath = [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:imageInfo.dli_fname
                                     length:strlen(imageInfo.dli_fname)];
    return imagePath.stringByDeletingLastPathComponent;
}

static NSString *EIDDescriptionKey(NSInteger variant, NSInteger subtype) {
    return [NSString stringWithFormat:@"%ld:%ld", (long)variant, (long)subtype];
}

@implementation EIDDescription
- (instancetype)initWithCollectibleID:(NSInteger)collectibleID
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath {
    return [self initWithPickupVariant:EIDPickupVariantCollectible subtype:collectibleID
                                  name:name detail:detail iconPath:iconPath quality:-1];
}

- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath {
    return [self initWithPickupVariant:pickupVariant subtype:subtype name:name detail:detail
                              iconPath:iconPath quality:-1];
}

- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath
                               quality:(NSInteger)quality {
    return [self initWithPickupVariant:pickupVariant subtype:subtype name:name detail:detail
                              iconPath:iconPath quality:quality
                              itemType:EIDCollectibleItemTypeUnknown maxCharges:0
                            chargeType:EIDActiveChargeTypeNormal];
}

- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath
                               quality:(NSInteger)quality
                              itemType:(EIDCollectibleItemType)itemType
                            maxCharges:(NSInteger)maxCharges
                            chargeType:(EIDActiveChargeType)chargeType {
    self = [super init];
    if (self) {
        _pickupVariant = pickupVariant;
        _pickupSubtype = subtype;
        _collectibleID = pickupVariant == EIDPickupVariantCollectible ? subtype : 0;
        _name = [name copy];
        _detail = [detail copy];
        _iconPath = [iconPath copy];
        _quality = quality;
        _itemType = itemType;
        _maxCharges = MAX(0, maxCharges);
        _chargeType = chargeType;
    }
    return self;
}
@end

@interface EIDItemsXMLParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, EIDDescription *> *items;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *hiddenIDs;
@end

@implementation EIDItemsXMLParser
- (instancetype)init {
    self = [super init];
    if (self) { _items = [NSMutableDictionary dictionary]; _hiddenIDs = [NSMutableSet set]; }
    return self;
}

- (void)parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    NSString *identifier = attributes[@"id"];
    if (!identifier.length || [identifier integerValue] <= 0) return;
    BOOL collectible = [@[@"active", @"passive", @"familiar"] containsObject:elementName];
    BOOL trinket = [elementName isEqualToString:@"trinket"];
    if (!collectible && !trinket) return;

    NSString *name = attributes[@"name"] ?: @"";
    NSString *detail = attributes[@"description"] ?: @"";
    if ([name hasPrefix:@"#"]) {
        name = [[name substringFromIndex:1] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        name = name.capitalizedString;
    }
    if ([detail hasPrefix:@"#"]) detail = @"Description available after importing EID data";
    NSInteger itemID = identifier.integerValue;
    if (collectible && [attributes[@"hidden"] boolValue]) [self.hiddenIDs addObject:@(itemID)];
    NSInteger variant = trinket ? EIDPickupVariantTrinket : EIDPickupVariantCollectible;
    NSInteger quality = -1;
    if (collectible && attributes[@"quality"].length) {
        NSInteger parsedQuality = attributes[@"quality"].integerValue;
        if (parsedQuality >= 0 && parsedQuality <= 4) quality = parsedQuality;
    }
    NSString *gfx = attributes[@"gfx"].lowercaseString;
    NSString *iconPath = nil;
    if (gfx.length) {
        NSArray<NSString *> *roots = @[@"repentance-resources", @"afterbirthplus-resources",
                                        @"afterbirth-resources", @"rebirth-resources"];
        NSString *directory = trinket ? @"trinkets" : @"collectibles";
        for (NSString *root in roots) {
            NSString *candidate = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"%@/data/gfx/items/%@/%@", root, directory, gfx]];
            if ([[NSFileManager defaultManager] isReadableFileAtPath:candidate]) {
                iconPath = candidate;
                break;
            }
        }
    }
    EIDCollectibleItemType itemType = EIDCollectibleItemTypeUnknown;
    if ([elementName isEqualToString:@"active"]) itemType = EIDCollectibleItemTypeActive;
    else if ([elementName isEqualToString:@"passive"]) itemType = EIDCollectibleItemTypePassive;
    else if ([elementName isEqualToString:@"familiar"]) itemType = EIDCollectibleItemTypeFamiliar;

    NSInteger maxCharges = itemType == EIDCollectibleItemTypeActive
        ? MAX(0, attributes[@"maxcharges"].integerValue) : 0;
    EIDActiveChargeType chargeType = EIDActiveChargeTypeNormal;
    NSString *chargeName = attributes[@"chargetype"].lowercaseString;
    if ([chargeName isEqualToString:@"timed"]) chargeType = EIDActiveChargeTypeTimed;
    else if ([chargeName isEqualToString:@"special"]) chargeType = EIDActiveChargeTypeSpecial;

    // Upstream EID marks these variable-charge actives as special even though
    // their XML entries expose the currently selected form's ordinary charge.
    if (itemType == EIDCollectibleItemTypeActive &&
        (itemID == 263 || itemID == 286 || itemID == 348 || itemID == 489)) {
        chargeType = EIDActiveChargeTypeSpecial;
    }

    self.items[EIDDescriptionKey(variant, itemID)] =
        [[EIDDescription alloc] initWithPickupVariant:variant subtype:itemID
                                                 name:name detail:detail iconPath:iconPath quality:quality
                                             itemType:itemType maxCharges:maxCharges chargeType:chargeType];
}
@end

@interface EIDQualityXMLParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *qualities;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *questIDs;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *noGreedIDs;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *noChallengeIDs;
@end

@implementation EIDQualityXMLParser
- (instancetype)init {
    self = [super init];
    if (self) { _qualities = [NSMutableDictionary dictionary]; _questIDs = [NSMutableSet set];
        _noGreedIDs = [NSMutableSet set]; _noChallengeIDs = [NSMutableSet set]; }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)namespaceURI; (void)qualifiedName;
    NSString *identifier = attributes[@"id"];
    NSString *quality = attributes[@"quality"];
    if (!identifier.length || !quality.length) return;
    NSInteger itemID = identifier.integerValue;
    NSInteger value = quality.integerValue;
    if (itemID > 0 && value >= 0 && value <= 4) self.qualities[@(itemID)] = @(value);
    if ([[attributes[@"tags"] componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        containsObject:@"quest"]) [self.questIDs addObject:@(itemID)];
    NSArray *tags = [attributes[@"tags"] componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([tags containsObject:@"nogreed"]) [self.noGreedIDs addObject:@(itemID)];
    if ([tags containsObject:@"nochallenge"]) [self.noChallengeIDs addObject:@(itemID)];
}
@end

// Read the installed version's mimic costs, not costs from a newer PC patch.
@interface EIDPocketMetadataParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary *entries;
@end
@implementation EIDPocketMetadataParser
- (instancetype)init { if ((self = [super init])) _entries = [NSMutableDictionary dictionary]; return self; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)element namespaceURI:(NSString *)uri
 qualifiedName:(NSString *)qualified attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)uri; (void)qualified;
    BOOL pill = [element isEqualToString:@"pilleffect"];
    if (!pill && ![element isEqualToString:@"card"] && ![element isEqualToString:@"rune"]) return;
    if (!attributes[@"id"].length || !attributes[@"mimiccharge"].length) return;
    NSInteger item = attributes[@"id"].integerValue, cost = attributes[@"mimiccharge"].integerValue;
    if (item < 0 || item > 100 || cost < 0 || cost > 12) return;
    NSString *type = attributes[@"type"] ?: @"";
    NSInteger active = pill ? 348 : [type isEqualToString:@"rune"] ? 263 :
        [@[@"tarot",@"suit",@"special",@"tarot_reverse"] containsObject:type] ? 286 : 0;
    if (active) self.entries[EIDDescriptionKey(pill ? 70 : 300,pill ? item+1 : item)] =
        @{@"active":@(active),@"cost":@(cost)};
}
@end

@interface EIDDescriptionStore ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, EIDDescription *> *items;
@property(nonatomic, copy) NSString *languageCode;
@property(nonatomic, copy) NSArray<NSString *> *availableLanguageCodes;
@property(nonatomic, copy) NSString *descriptionDataSet;
@property(nonatomic, copy) NSString *unidentifiedPillName;
@property(nonatomic, copy) NSDictionary *contextData;
@property(nonatomic, copy) NSDictionary *nativeMetadata;
@end

@implementation EIDDescriptionStore

static NSString *EIDUnidentifiedPillName(NSString *languageCode) {
    static NSDictionary<NSString *, NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Keep this tiny UI string in code as well as descriptions.json. Older
        // app-support databases take precedence so users can import their own EID
        // data; they must not force the title back to English after a language change.
        names = @{
            @"bul": @"Неидентифицирано хапче", @"cs_cz": @"Neznámá Pilulka",
            @"de": @"Unidentifizierte Pille", @"el_gr": @"Άγνωστο Χάπι",
            @"en_us": @"Unidentified Pill", @"spa": @"Píldora sin identificar",
            @"fr": @"Pilule non identifiée", @"it": @"Pillola non identificata",
            @"ja_jp": @"未識別のピル", @"ko_kr": @"확인하지 않은 알약",
            @"nl_nl": @"Unidentified Pill", @"pl": @"Nieznana Pigułka",
            @"pt": @"Comprimido não identificado", @"pt_br": @"Pílula não identificada",
            @"ro_ro": @"Unidentified Pill", @"ru": @"Неизвестная пилюля",
            @"tr_tr": @"Tanımlanmamış Hap", @"uk_ua": @"Невідома пігулка",
            @"vi": @"Viên thuốc không xác định", @"zh_cn": @"未识别的胶囊",
        };
    });
    return names[languageCode] ?: names[@"en_us"];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableDictionary dictionary];
        _contextData = @{};
        _languageCode = [self resolvedLanguageCode];
        _availableLanguageCodes = @[@"en_us"];
        _descriptionDataSet = @"Isaac metadata";
        _unidentifiedPillName = EIDUnidentifiedPillName(_languageCode);
        [self reload];
    }
    return self;
}

- (NSUInteger)countForVariant:(NSInteger)variant {
    __block NSUInteger count = 0;
    [self.items enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, EIDDescription *item,
                                                     __unused BOOL *stop) {
        if (item.pickupVariant == variant) count++;
    }];
    return count;
}

- (NSUInteger)collectibleCount { return [self countForVariant:EIDPickupVariantCollectible]; }
- (NSUInteger)trinketCount { return [self countForVariant:EIDPickupVariantTrinket]; }
- (NSUInteger)cardCount { return [self countForVariant:EIDPickupVariantCard]; }
- (NSUInteger)pillCount { return [self countForVariant:EIDPickupVariantPill]; }
- (NSUInteger)horsePillCount { return [self countForVariant:EIDPickupVariantHorsePill]; }

- (void)reload {
    [self.items removeAllObjects];
    [self loadGameItemMetadata];
    [self loadImportedDescriptions];
    EIDLog(@"descriptions loaded: %lu collectibles, %lu trinkets, %lu cards/runes, %lu pills, %lu horse pills",
           (unsigned long)self.collectibleCount, (unsigned long)self.trinketCount,
           (unsigned long)self.cardCount, (unsigned long)self.pillCount,
           (unsigned long)self.horsePillCount);
}

- (EIDDescription *)descriptionForCollectibleID:(NSInteger)collectibleID {
    return [self descriptionForPickupVariant:EIDPickupVariantCollectible subtype:collectibleID];
}

- (EIDDescription *)descriptionForPickupVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    if (variant == EIDPickupVariantTrinket) subtype &= 0x7fff;
    if (variant == EIDPickupVariantUnidentifiedPill) {
        return [[EIDDescription alloc] initWithPickupVariant:variant subtype:subtype
            name:self.unidentifiedPillName.length ? self.unidentifiedPillName : @"Unidentified Pill"
            detail:@"?" iconPath:nil quality:-1];
    }
    return self.items[EIDDescriptionKey(variant, subtype)];
}

- (NSString *)resolvedLanguageCode {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"IsaacEIDLanguage"];
    if (saved.length) return saved;
    NSString *preferred = [NSLocale.preferredLanguages.firstObject.lowercaseString stringByReplacingOccurrencesOfString:@"_" withString:@"-"] ?: @"en";
    if ([preferred hasPrefix:@"pt-br"]) return @"pt_br";
    NSDictionary<NSString *, NSString *> *languageMap = @{
        @"bg": @"bul", @"cs": @"cs_cz", @"de": @"de", @"el": @"el_gr", @"en": @"en_us",
        @"es": @"spa", @"fr": @"fr", @"it": @"it", @"ja": @"ja_jp", @"ko": @"ko_kr",
        @"nl": @"nl_nl", @"pl": @"pl", @"pt": @"pt", @"ro": @"ro_ro", @"ru": @"ru",
        @"tr": @"tr_tr", @"uk": @"uk_ua", @"vi": @"vi", @"zh": @"zh_cn"
    };
    NSString *base = [preferred componentsSeparatedByString:@"-"].firstObject;
    return languageMap[base] ?: @"en_us";
}

- (void)setLanguageCode:(NSString *)languageCode {
    if (![self.availableLanguageCodes containsObject:languageCode]) return;
    if ([_languageCode isEqualToString:languageCode]) return;
    _languageCode = [languageCode copy];
    [[NSUserDefaults standardUserDefaults] setObject:languageCode forKey:@"IsaacEIDLanguage"];
    [self reload];
    EIDLog(@"description language selected: %@", languageCode);
}

- (NSString *)displayNameForLanguageCode:(NSString *)languageCode {
    static NSDictionary<NSString *, NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{@"bul":@"Български",@"cs_cz":@"Čeština",@"de":@"Deutsch",@"el_gr":@"Ελληνικά",
                  @"en_us":@"English",@"spa":@"Español",@"fr":@"Français",@"it":@"Italiano",
                  @"ja_jp":@"日本語",@"ko_kr":@"한국어",@"nl_nl":@"Nederlands",@"pl":@"Polski",
                  @"pt":@"Português",@"pt_br":@"Português (Brasil)",@"ro_ro":@"Română",@"ru":@"Русский",
                  @"tr_tr":@"Türkçe",@"uk_ua":@"Українська",@"vi":@"Tiếng Việt",@"zh_cn":@"简体中文"};
    });
    return names[languageCode] ?: languageCode;
}

- (void)loadGameItemMetadata {
    NSMutableSet *quests = [NSMutableSet set];
    NSMutableSet *hidden = [NSMutableSet set];
    NSMutableSet *noGreed = [NSMutableSet set], *noChallenge = [NSMutableSet set];
    NSMutableDictionary *mimic = [NSMutableDictionary dictionary];
    BOOL questMetadataAvailable = NO;
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *relativePaths = @[@"rebirth-resources/data/items.xml", @"afterbirth-resources/data/items.xml",
        @"afterbirthplus-resources/data/items.xml", @"repentance-resources/data/items.xml"];
    for (NSString *relativePath in relativePaths) {
        NSString *path = [bundlePath stringByAppendingPathComponent:relativePath];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        EIDItemsXMLParser *delegate = [[EIDItemsXMLParser alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data]; parser.delegate = delegate;
        if ([parser parse]) {
            [self.items addEntriesFromDictionary:delegate.items];
            [hidden unionSet:delegate.hiddenIDs];
        }
    }
    NSArray<NSString *> *metadataPaths = @[@"repentance-resources/data/items_metadata.xml", @"repentance-resources/data/items_metadata2.xml"];
    for (NSString *relativePath in metadataPaths) {
        NSData *data = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:relativePath]];
        if (!data.length) continue;
        EIDQualityXMLParser *delegate = [[EIDQualityXMLParser alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data]; parser.delegate = delegate;
        if (![parser parse]) continue;
        [quests unionSet:delegate.questIDs];
        [noGreed unionSet:delegate.noGreedIDs];
        [noChallenge unionSet:delegate.noChallengeIDs];
        questMetadataAvailable = YES;
        [delegate.qualities enumerateKeysAndObjectsUsingBlock:^(NSNumber *itemID, NSNumber *quality, __unused BOOL *stop) {
            NSString *key = EIDDescriptionKey(EIDPickupVariantCollectible, itemID.integerValue);
            EIDDescription *existing = self.items[key];
            if (!existing) return;
            self.items[key] = [[EIDDescription alloc] initWithPickupVariant:existing.pickupVariant subtype:existing.pickupSubtype
                name:existing.name detail:existing.detail iconPath:existing.iconPath quality:quality.integerValue
                itemType:existing.itemType maxCharges:existing.maxCharges chargeType:existing.chargeType];
        }];
    }

    for (NSString *root in @[@"rebirth-resources",@"afterbirth-resources",@"afterbirthplus-resources",@"repentance-resources"]) {
        NSData *data = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:
            [root stringByAppendingPathComponent:@"data/pocketitems.xml"]]];
        if (!data.length) continue;
        EIDPocketMetadataParser *delegate = [EIDPocketMetadataParser new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data]; parser.delegate = delegate;
        if ([parser parse]) [mimic addEntriesFromDictionary:delegate.entries];
    }
    NSMutableArray *actives = [NSMutableArray array], *collectibles = [NSMutableArray array];
    for (EIDDescription *item in self.items.allValues)
        if (item.pickupVariant == EIDPickupVariantCollectible) {
            [collectibles addObject:@(item.collectibleID)];
            if (item.itemType == EIDCollectibleItemTypeActive) [actives addObject:@(item.collectibleID)];
        }
    NSMutableDictionary *activeDetails = [NSMutableDictionary dictionary];
    for (EIDDescription *item in self.items.allValues)
        if (item.pickupVariant == EIDPickupVariantCollectible && item.itemType == EIDCollectibleItemTypeActive)
            activeDetails[@(item.collectibleID).stringValue] = @{@"max":@(item.maxCharges),@"type":@(item.chargeType)};
    self.nativeMetadata = @{@"active_ids":[actives sortedArrayUsingSelector:@selector(compare:)], @"active_details":activeDetails.copy,
        @"collectible_ids":collectibles, @"mimic_charges":mimic.copy,
        @"no_greed_ids":noGreed.allObjects, @"no_challenge_ids":noChallenge.allObjects,
        @"hidden_ids":[hidden.allObjects sortedArrayUsingSelector:@selector(compare:)],
        @"quest_ids":[quests.allObjects sortedArrayUsingSelector:@selector(compare:)],
        @"quest_metadata_available":@(questMetadataAvailable)};
    __block NSUInteger activeCount = 0, timedCount = 0, specialCount = 0;
    [self.items enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, EIDDescription *item,
                                                     __unused BOOL *stop) {
        if (item.itemType != EIDCollectibleItemTypeActive) return;
        activeCount++;
        if (item.chargeType == EIDActiveChargeTypeTimed) timedCount++;
        else if (item.chargeType == EIDActiveChargeTypeSpecial) specialCount++;
    }];
    EIDLog(@"item metadata loaded: %lu active (%lu timed, %lu special)",
           (unsigned long)activeCount, (unsigned long)timedCount, (unsigned long)specialCount);
}

- (NSArray<NSString *> *)importedDescriptionPaths {
    NSString *appSupport = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions/descriptions.json"];
    NSString *embedded = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle/descriptions.json"];
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObjects:appSupport, embedded, nil];
    NSString *ownImageDirectory = EIDOwnImageDirectory();
    if (ownImageDirectory.length) {
        [paths addObject:[ownImageDirectory stringByAppendingPathComponent:@"IsaacEID.bundle/descriptions.json"]];
        [paths addObject:[ownImageDirectory stringByAppendingPathComponent:@"Resources/IsaacEID.bundle/descriptions.json"]];
    }
    [paths addObjectsFromArray:@[@"/var/jb/Library/Application Support/IsaacExternalItemDescriptions/descriptions.json",
                                  @"/Library/Application Support/IsaacExternalItemDescriptions/descriptions.json"]];
    return paths;
}

- (void)loadImportedDescriptions {
    self.contextData = @{};
    NSString *selectedPath = nil;
    for (NSString *path in [self importedDescriptionPaths]) if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) { selectedPath = path; break; }
    if (!selectedPath) { EIDLog(@"no imported EID description database; using game item metadata"); return; }
    NSData *data = [NSData dataWithContentsOfFile:selectedPath];
    NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *languages = [root[@"languages"] isKindOfClass:NSDictionary.class] ? root[@"languages"] : nil;
    NSArray<NSString *> *preferredOrder = @[@"en_us",@"fr",@"pt",@"pt_br",@"ru",@"spa",@"it",@"bul",@"pl",@"de",@"tr_tr",@"ko_kr",@"zh_cn",@"ja_jp",@"cs_cz",@"nl_nl",@"uk_ua",@"el_gr",@"ro_ro",@"vi"];
    NSMutableArray<NSString *> *available = [NSMutableArray array];
    for (NSString *code in preferredOrder) if ([languages[code] isKindOfClass:NSDictionary.class]) [available addObject:code];
    for (NSString *code in [[languages allKeys] sortedArrayUsingSelector:@selector(compare:)]) if (![available containsObject:code] && [languages[code] isKindOfClass:NSDictionary.class]) [available addObject:code];
    self.availableLanguageCodes = available.count ? available : @[@"en_us"];
    if (![self.availableLanguageCodes containsObject:self.languageCode]) {
        self.languageCode = [self.availableLanguageCodes containsObject:@"en_us"] ? @"en_us" : self.availableLanguageCodes.firstObject;
        [[NSUserDefaults standardUserDefaults] setObject:self.languageCode forKey:@"IsaacEIDLanguage"];
    }
    NSString *gameVersion = [root[@"game_version"] isKindOfClass:NSString.class] ? root[@"game_version"] : @"rep";
    NSString *compatibleVersion = [root[@"compatible_isaac_version"] isKindOfClass:NSString.class] ? root[@"compatible_isaac_version"] : @"1.7.9b";
    self.descriptionDataSet = [NSString stringWithFormat:@"Repentance %@ (%@)", compatibleVersion, gameVersion];
    NSDictionary *language = [languages[self.languageCode] isKindOfClass:NSDictionary.class] ? languages[self.languageCode] : nil;
    NSDictionary *english = [languages[@"en_us"] isKindOfClass:NSDictionary.class] ? languages[@"en_us"] : nil;
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"conditionals", @"heart_replacements", @"birthright", @"greed_no_effect_notes",
                            @"car_battery", @"tarot_cloth", @"stat_names", @"pickup_names",
                            @"pandora_floor_lines", @"context_strings", @"BFFSSynergies", @"binge_eater", @"purity_boosts", @"book_of_belial",
                            @"wisp_texts", @"wisp_extras", @"tear_flags", @"golden_trinket_effects",
                            @"golden_trinket_overrides", @"tarot_cloth_blank_card", @"abyss_descriptions"]) {
        NSMutableDictionary *entries = [NSMutableDictionary dictionary];
        if ([english[key] isKindOfClass:NSDictionary.class]) [entries addEntriesFromDictionary:english[key]];
        if ([language[key] isKindOfClass:NSDictionary.class]) [entries addEntriesFromDictionary:language[key]];
        context[key] = entries.copy;
    }
    if ([root[@"context_rules"] isKindOfClass:NSArray.class]) context[@"rules"] = root[@"context_rules"];
    if ([root[@"weapon_rules"] isKindOfClass:NSArray.class]) context[@"weapon_rules"] = root[@"weapon_rules"];
    if ([root[@"supplemental_rules"] isKindOfClass:NSArray.class]) context[@"supplemental_rules"] = root[@"supplemental_rules"];
    if ([root[@"pocket_active_players"] isKindOfClass:NSDictionary.class]) context[@"pocket_active_players"] = root[@"pocket_active_players"];
    if ([root[@"car_battery_metadata"] isKindOfClass:NSDictionary.class])
        context[@"car_battery_metadata"] = root[@"car_battery_metadata"];
    if ([root[@"pill_metadata"] isKindOfClass:NSDictionary.class])
        context[@"pill_metadata"] = root[@"pill_metadata"];
    for (NSString *key in @[@"luck_formulas",@"golden_trinket_data",@"black_feather_metadata",@"familiar_metadata"])
        if ([root[key] isKindOfClass:NSDictionary.class]) context[key] = root[key];
    context[@"golden_full_replace_ids"] = [language[@"golden_trinket_effects"] allKeys] ?: @[];
    NSMutableDictionary *itemNames = [NSMutableDictionary dictionary];
    NSMutableDictionary *itemDetails = [NSMutableDictionary dictionary];
    NSDictionary *namePrefixes = @{@"collectibles":@"5.100.",@"trinkets":@"5.350.",
        @"cards":@"5.300.",@"pills":@"5.70.",@"horsepills":@"5.1070."};
    for (NSString *category in namePrefixes) {
        NSString *prefix = namePrefixes[category];
        for (NSDictionary *localization in @[english ?: @{}, language ?: @{}]) {
            [localization[category] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *entry, __unused BOOL *stop) {
                NSString *name = [entry isKindOfClass:NSDictionary.class] ? entry[@"name"] : nil;
                if ([name isKindOfClass:NSString.class] && name.length) itemNames[[prefix stringByAppendingString:key]] = name;
                if ([entry[@"description"] isKindOfClass:NSString.class] && [entry[@"description"] length])
                    itemDetails[[prefix stringByAppendingString:key]] = entry[@"description"];
            }];
        }
    }
    context[@"item_names"] = itemNames.copy;
    context[@"item_details"] = itemDetails.copy;
    context[@"native_metadata"] = self.nativeMetadata ?: @{};
    if ([root[@"character_metadata"] isKindOfClass:NSDictionary.class])
        context[@"character_metadata"] = root[@"character_metadata"];
    if ([root[@"health_amounts"] isKindOfClass:NSDictionary.class]) context[@"health_amounts"] = root[@"health_amounts"];
    if ([root[@"healing_items"] isKindOfClass:NSArray.class]) context[@"healing_items"] = root[@"healing_items"];
    self.contextData = context.copy;
    EIDLog(@"imported context: %lu weapon rules, %lu supplemental rules, language %@; read-only native inventory; %lu Abyss previews",
        (unsigned long)[context[@"weapon_rules"] count], (unsigned long)[context[@"supplemental_rules"] count], self.languageCode,
        (unsigned long)[context[@"abyss_descriptions"] count]);
    NSDictionary *languageStrings = [language[@"strings"] isKindOfClass:NSDictionary.class]
        ? language[@"strings"] : nil;
    NSDictionary *englishStrings = [english[@"strings"] isKindOfClass:NSDictionary.class]
        ? english[@"strings"] : nil;
    NSString *unidentifiedPill = [languageStrings[@"unidentified_pill"] isKindOfClass:NSString.class]
        ? languageStrings[@"unidentified_pill"] : nil;
    if (!unidentifiedPill.length) unidentifiedPill = EIDUnidentifiedPillName(self.languageCode);
    if (!unidentifiedPill.length && [englishStrings[@"unidentified_pill"] isKindOfClass:NSString.class]) {
        unidentifiedPill = englishStrings[@"unidentified_pill"];
    }
    self.unidentifiedPillName = unidentifiedPill.length ? unidentifiedPill : @"Unidentified Pill";
    NSDictionary<NSString *, NSNumber *> *categories = @{
        @"collectibles": @(EIDPickupVariantCollectible),
        @"trinkets": @(EIDPickupVariantTrinket),
        @"cards": @(EIDPickupVariantCard),
        @"pills": @(EIDPickupVariantPill),
        @"horsepills": @(EIDPickupVariantHorsePill),
        @"dice": @(EIDPickupVariantDiceRoom),
        @"sacrifice": @(EIDPickupVariantSacrificeRoom),
        @"sanguine": @(EIDPickupVariantSanguineBond),
    };
    [categories enumerateKeysAndObjectsUsingBlock:^(NSString *category, NSNumber *variantNumber, __unused BOOL *categoryStop) {
        NSMutableDictionary *entries = [NSMutableDictionary dictionary];
        if ([english[category] isKindOfClass:NSDictionary.class]) [entries addEntriesFromDictionary:english[category]];
        if ([language[category] isKindOfClass:NSDictionary.class]) [entries addEntriesFromDictionary:language[category]];
        if (!entries.count && [category isEqualToString:@"collectibles"] && [root[@"collectibles"] isKindOfClass:NSDictionary.class]) [entries addEntriesFromDictionary:root[@"collectibles"]];
        NSInteger variant = variantNumber.integerValue;
        [entries enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *value, __unused BOOL *entryStop) {
            if (![value isKindOfClass:NSDictionary.class]) return;
            NSInteger subtype = key.integerValue;
            NSString *name = [value[@"name"] isKindOfClass:NSString.class] ? value[@"name"] : @"";
            NSString *detail = [value[@"description"] isKindOfClass:NSString.class] ? value[@"description"] : @"";
            if (subtype <= 0 || (!name.length && !detail.length)) return;
            NSString *descriptionKey = EIDDescriptionKey(variant, subtype);
            EIDDescription *existing = self.items[descriptionKey];
            EIDDescription *artwork = variant==EIDPickupVariantSanguineBond ? self.items[EIDDescriptionKey(100,692)] : existing;
            self.items[descriptionKey] = [[EIDDescription alloc] initWithPickupVariant:variant subtype:subtype
                name:name detail:detail iconPath:artwork.iconPath quality:existing ? existing.quality : -1
                itemType:existing ? existing.itemType : EIDCollectibleItemTypeUnknown
                maxCharges:existing ? existing.maxCharges : 0
                chargeType:existing ? existing.chargeType : EIDActiveChargeTypeNormal];
        }];
    }];
    EIDLog(@"imported EID descriptions from %@ (%lu languages; active %@; dataset %@)", selectedPath.lastPathComponent, (unsigned long)self.availableLanguageCodes.count, self.languageCode, self.descriptionDataSet);
}
@end
