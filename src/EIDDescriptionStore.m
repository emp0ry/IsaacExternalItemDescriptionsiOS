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
    self = [super init];
    if (self) {
        _pickupVariant = pickupVariant;
        _pickupSubtype = subtype;
        _collectibleID = pickupVariant == EIDPickupVariantCollectible ? subtype : 0;
        _name = [name copy];
        _detail = [detail copy];
        _iconPath = [iconPath copy];
        _quality = quality;
    }
    return self;
}
@end

@interface EIDItemsXMLParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, EIDDescription *> *items;
@end

@implementation EIDItemsXMLParser
- (instancetype)init {
    self = [super init];
    if (self) _items = [NSMutableDictionary dictionary];
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
    self.items[EIDDescriptionKey(variant, itemID)] =
        [[EIDDescription alloc] initWithPickupVariant:variant subtype:itemID
                                                 name:name detail:detail iconPath:iconPath quality:quality];
}
@end

@interface EIDQualityXMLParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *qualities;
@end

@implementation EIDQualityXMLParser
- (instancetype)init {
    self = [super init];
    if (self) _qualities = [NSMutableDictionary dictionary];
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
}
@end

@interface EIDDescriptionStore ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, EIDDescription *> *items;
@property(nonatomic, copy) NSString *languageCode;
@property(nonatomic, copy) NSArray<NSString *> *availableLanguageCodes;
@property(nonatomic, copy) NSString *descriptionDataSet;
@end

@implementation EIDDescriptionStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableDictionary dictionary];
        _languageCode = [self resolvedLanguageCode];
        _availableLanguageCodes = @[@"en_us"];
        _descriptionDataSet = @"Isaac metadata";
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
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *relativePaths = @[@"rebirth-resources/data/items.xml", @"afterbirth-resources/data/items.xml",
        @"afterbirthplus-resources/data/items.xml", @"repentance-resources/data/items.xml"];
    for (NSString *relativePath in relativePaths) {
        NSString *path = [bundlePath stringByAppendingPathComponent:relativePath];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        EIDItemsXMLParser *delegate = [[EIDItemsXMLParser alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data]; parser.delegate = delegate;
        if ([parser parse]) [self.items addEntriesFromDictionary:delegate.items];
    }
    NSArray<NSString *> *metadataPaths = @[@"repentance-resources/data/items_metadata.xml", @"repentance-resources/data/items_metadata2.xml"];
    for (NSString *relativePath in metadataPaths) {
        NSData *data = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:relativePath]];
        if (!data.length) continue;
        EIDQualityXMLParser *delegate = [[EIDQualityXMLParser alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data]; parser.delegate = delegate;
        if (![parser parse]) continue;
        [delegate.qualities enumerateKeysAndObjectsUsingBlock:^(NSNumber *itemID, NSNumber *quality, __unused BOOL *stop) {
            NSString *key = EIDDescriptionKey(EIDPickupVariantCollectible, itemID.integerValue);
            EIDDescription *existing = self.items[key];
            if (!existing) return;
            self.items[key] = [[EIDDescription alloc] initWithPickupVariant:existing.pickupVariant subtype:existing.pickupSubtype
                name:existing.name detail:existing.detail iconPath:existing.iconPath quality:quality.integerValue];
        }];
    }
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
    NSDictionary<NSString *, NSNumber *> *categories = @{@"collectibles":@(EIDPickupVariantCollectible),@"trinkets":@(EIDPickupVariantTrinket),@"cards":@(EIDPickupVariantCard),@"pills":@(EIDPickupVariantPill),@"horsepills":@(EIDPickupVariantHorsePill)};
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
            self.items[descriptionKey] = [[EIDDescription alloc] initWithPickupVariant:variant subtype:subtype name:name detail:detail iconPath:existing.iconPath quality:existing ? existing.quality : -1];
        }];
    }];
    EIDLog(@"imported EID descriptions from %@ (%lu languages; active %@; dataset %@)", selectedPath.lastPathComponent, (unsigned long)self.availableLanguageCodes.count, self.languageCode, self.descriptionDataSet);
}
@end
