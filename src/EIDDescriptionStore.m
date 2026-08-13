#import "EIDDescriptionStore.h"
#import "EIDLogger.h"
#import "EIDNativeProbe.h"

static NSString *EIDDescriptionKey(NSInteger variant, NSInteger subtype) {
    return [NSString stringWithFormat:@"%ld:%ld", (long)variant, (long)subtype];
}

@implementation EIDDescription
- (instancetype)initWithCollectibleID:(NSInteger)collectibleID
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath {
    return [self initWithPickupVariant:EIDPickupVariantCollectible subtype:collectibleID
                                  name:name detail:detail iconPath:iconPath];
}

- (instancetype)initWithPickupVariant:(NSInteger)pickupVariant
                               subtype:(NSInteger)subtype
                                  name:(NSString *)name
                                detail:(NSString *)detail
                              iconPath:(NSString *)iconPath {
    self = [super init];
    if (self) {
        _pickupVariant = pickupVariant;
        _pickupSubtype = subtype;
        _collectibleID = pickupVariant == EIDPickupVariantCollectible ? subtype : 0;
        _name = [name copy];
        _detail = [detail copy];
        _iconPath = [iconPath copy];
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
                                                 name:name detail:detail iconPath:iconPath];
}
@end

@interface EIDDescriptionStore ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, EIDDescription *> *items;
@property(nonatomic, copy) NSString *languageCode;
@end

@implementation EIDDescriptionStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableDictionary dictionary];
        _languageCode = [self resolvedLanguageCode];
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
    EIDLog(@"descriptions loaded: %lu collectibles, %lu trinkets, %lu cards/runes, "
           "%lu pills, %lu horse pills",
           (unsigned long)self.collectibleCount, (unsigned long)self.trinketCount,
           (unsigned long)self.cardCount, (unsigned long)self.pillCount,
           (unsigned long)self.horsePillCount);
}

- (EIDDescription *)descriptionForCollectibleID:(NSInteger)collectibleID {
    return [self descriptionForPickupVariant:EIDPickupVariantCollectible subtype:collectibleID];
}

- (EIDDescription *)descriptionForPickupVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    // Repentance encodes golden trinkets by setting the high trinket flag.
    if (variant == EIDPickupVariantTrinket) subtype &= 0x7fff;
    return self.items[EIDDescriptionKey(variant, subtype)];
}

- (NSString *)resolvedLanguageCode {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"IsaacEIDLanguage"];
    if ([saved isEqualToString:@"en_us"] || [saved isEqualToString:@"ru"]) return saved;
    NSString *preferred = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"en";
    return [preferred hasPrefix:@"ru"] ? @"ru" : @"en_us";
}

- (void)setLanguageCode:(NSString *)languageCode {
    if (![@[@"en_us", @"ru"] containsObject:languageCode]) return;
    if ([_languageCode isEqualToString:languageCode]) return;
    _languageCode = [languageCode copy];
    [[NSUserDefaults standardUserDefaults] setObject:languageCode forKey:@"IsaacEIDLanguage"];
    [self reload];
    EIDLog(@"description language selected: %@", languageCode);
}

- (void)loadGameItemMetadata {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *relativePaths = @[
        @"rebirth-resources/data/items.xml",
        @"afterbirth-resources/data/items.xml",
        @"afterbirthplus-resources/data/items.xml",
        @"repentance-resources/data/items.xml"
    ];
    for (NSString *relativePath in relativePaths) {
        NSString *path = [bundlePath stringByAppendingPathComponent:relativePath];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        EIDItemsXMLParser *delegate = [[EIDItemsXMLParser alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        parser.delegate = delegate;
        if ([parser parse]) [self.items addEntriesFromDictionary:delegate.items];
    }
}

- (NSArray<NSString *> *)importedDescriptionPaths {
    NSString *appSupport = [NSHomeDirectory() stringByAppendingPathComponent:
                            @"Library/Application Support/IsaacExternalItemDescriptions/descriptions.json"];
    NSString *embedded = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
                          @"Frameworks/IsaacEID.bundle/descriptions.json"];
    return @[
        appSupport,
        embedded,
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions/descriptions.json",
        @"/Library/Application Support/IsaacExternalItemDescriptions/descriptions.json"
    ];
}

- (void)loadImportedDescriptions {
    NSString *selectedPath = nil;
    for (NSString *path in [self importedDescriptionPaths]) {
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
            selectedPath = path;
            break;
        }
    }
    if (!selectedPath) {
        EIDLog(@"no imported EID description database; using game item metadata");
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:selectedPath];
    NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *languages = [root[@"languages"] isKindOfClass:NSDictionary.class] ? root[@"languages"] : nil;
    NSDictionary *language = [languages[self.languageCode] isKindOfClass:NSDictionary.class]
        ? languages[self.languageCode] : nil;
    NSDictionary<NSString *, NSNumber *> *categories = @{
        @"collectibles": @(EIDPickupVariantCollectible),
        @"trinkets": @(EIDPickupVariantTrinket),
        @"cards": @(EIDPickupVariantCard),
        @"pills": @(EIDPickupVariantPill),
        @"horsepills": @(EIDPickupVariantHorsePill),
    };
    [categories enumerateKeysAndObjectsUsingBlock:^(NSString *category, NSNumber *variantNumber,
                                                     __unused BOOL *categoryStop) {
        NSDictionary *entries = [language[category] isKindOfClass:NSDictionary.class]
            ? language[category] : nil;
        // Read the original one-category format for backward-compatible local databases.
        if (!entries && [category isEqualToString:@"collectibles"] &&
            [root[@"collectibles"] isKindOfClass:NSDictionary.class]) {
            entries = root[@"collectibles"];
        }
        NSInteger variant = variantNumber.integerValue;
        [entries enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *value,
                                                      __unused BOOL *entryStop) {
            if (![value isKindOfClass:NSDictionary.class]) return;
            NSInteger subtype = key.integerValue;
            NSString *name = [value[@"name"] isKindOfClass:NSString.class] ? value[@"name"] : @"";
            NSString *detail = [value[@"description"] isKindOfClass:NSString.class]
                ? value[@"description"] : @"";
            if (subtype <= 0 || (!name.length && !detail.length)) return;
            NSString *descriptionKey = EIDDescriptionKey(variant, subtype);
            EIDDescription *existing = self.items[descriptionKey];
            self.items[descriptionKey] =
                [[EIDDescription alloc] initWithPickupVariant:variant subtype:subtype
                                                         name:name detail:detail
                                                     iconPath:existing.iconPath];
        }];
    }];
    EIDLog(@"imported EID descriptions from %@", selectedPath.lastPathComponent);
}
@end
