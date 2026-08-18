#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface EIDQualityOnlyParser : NSObject <NSXMLParserDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *qualities;
@end

@implementation EIDQualityOnlyParser
- (instancetype)init {
    if ((self = [super init])) _qualities = [NSMutableDictionary dictionary];
    return self;
}

- (void)parser:(NSXMLParser *)parser
 didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI
   qualifiedName:(NSString *)qualifiedName
      attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    (void)parser; (void)elementName; (void)namespaceURI; (void)qualifiedName;
    NSString *identifier = attributes[@"id"];
    NSString *qualityString = attributes[@"quality"];
    if (!identifier.length || !qualityString.length) return;

    NSInteger itemID = identifier.integerValue;
    NSInteger quality = qualityString.integerValue;
    if (itemID <= 0 || quality < 0 || quality > 4) return;

    NSNumber *key = @(itemID);
    NSNumber *existing = self.qualities[key];
    if (!existing || quality > existing.integerValue) self.qualities[key] = @(quality);
}
@end

static NSDictionary<NSNumber *, NSNumber *> *EIDResolvedQualities(void) {
    static NSDictionary<NSNumber *, NSNumber *> *result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSNumber *, NSNumber *> *qualities = [NSMutableDictionary dictionary];
        NSString *bundle = NSBundle.mainBundle.bundlePath;
        NSArray<NSString *> *roots = @[
            @"rebirth-resources/data",
            @"afterbirth-resources/data",
            @"afterbirthplus-resources/data",
            @"repentance-resources/data"
        ];
        NSArray<NSString *> *files = @[
            @"items_metadata.xml",
            @"items_metadata2.xml",
            @"items.xml"
        ];

        for (NSString *root in roots) {
            for (NSString *file in files) {
                NSString *path = [bundle stringByAppendingPathComponent:
                                  [root stringByAppendingPathComponent:file]];
                NSData *data = [NSData dataWithContentsOfFile:path];
                if (!data.length) continue;

                EIDQualityOnlyParser *delegate = [EIDQualityOnlyParser new];
                NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
                parser.delegate = delegate;
                if (![parser parse]) continue;

                [delegate.qualities enumerateKeysAndObjectsUsingBlock:^(NSNumber *itemID, NSNumber *quality, BOOL *stop) {
                    (void)stop;
                    NSNumber *existing = qualities[itemID];
                    if (!existing || quality.integerValue > existing.integerValue) {
                        qualities[itemID] = quality;
                    }
                }];
            }
        }
        result = qualities.copy;
    });
    return result;
}

@interface EIDDescriptionStore (EIDQualityFix)
- (EIDDescription *)eid_quality_descriptionForPickupVariant:(NSInteger)variant subtype:(NSInteger)subtype;
@end

@implementation EIDDescriptionStore (EIDQualityFix)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(descriptionForPickupVariant:subtype:));
        Method replacement = class_getInstanceMethod(self, @selector(eid_quality_descriptionForPickupVariant:subtype:));
        if (original && replacement) method_exchangeImplementations(original, replacement);
    });
}

- (EIDDescription *)eid_quality_descriptionForPickupVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    EIDDescription *description = [self eid_quality_descriptionForPickupVariant:variant subtype:subtype];
    if (!description || variant != EIDPickupVariantCollectible || subtype <= 0) return description;

    NSNumber *resolved = EIDResolvedQualities()[@(subtype)];
    if (!resolved || resolved.integerValue == description.quality) return description;

    return [[EIDDescription alloc] initWithPickupVariant:description.pickupVariant
                                                  subtype:description.pickupSubtype
                                                     name:description.name
                                                   detail:description.detail
                                                 iconPath:description.iconPath
                                                  quality:resolved.integerValue];
}
@end
