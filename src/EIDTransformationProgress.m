#import "EIDNativeProbe.h"
#import "EIDTransformationProgress.h"
#import "EIDLogger.h"

static NSString *EIDTransformResourcePath(void) {
    NSString *main = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *roots = @[
        [main stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/Resources/IsaacEID.bundle"],
        [main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/IsaacEID.bundle"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions"],
        @"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",
        @"/Library/Application Support/IsaacExternalItemDescriptions"
    ];
    for (NSString *root in roots) {
        NSString *path = [root stringByAppendingPathComponent:@"transformations.json"];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    NSBundle *framework = [NSBundle bundleForClass:NSClassFromString(@"EIDOverlayController") ?: NSObject.class];
    for (NSString *relative in @[@"Resources/IsaacEID.bundle/transformations.json", @"IsaacEID.bundle/transformations.json", @"transformations.json"]) {
        NSString *path = [framework.bundlePath stringByAppendingPathComponent:relative];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) return path;
    }
    return nil;
}

static NSInteger EIDNativeFormIDForTransformation(NSInteger transformation) {
    // EID transformation IDs follow transformations.lua. Isaac's persisted
    // PlayerForm enum uses a different order; this table is verified against
    // the shipped iOS playerforms.xml and Entity_Player::_playerForms[15].
    switch (transformation) {
        case 1: return 0;   // Guppy
        case 2: return 2;   // Fun Guy
        case 3: return 1;   // Lord of the Flies / Beelzebub
        case 4: return 7;   // Conjoined
        case 5: return 5;   // Spun
        case 6: return 6;   // Yes Mother?
        case 7: return 9;   // Oh Crap
        case 8: return 4;   // Bob
        case 9: return 8;   // Leviathan
        case 10: return 3;  // Seraphim
        case 12: return 10; // Bookworm
        case 13: return 12; // Spider Baby
        case 14: return 11; // Adult
        case 15: return 13; // Stompy
        default: return NSNotFound; // Super Bum is not a PlayerForm.
    }
}

@interface EIDTransformationProgress ()
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<NSNumber *> *> *assignments;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *englishNames;
@property(nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *namesByLanguage;
@property(nonatomic, copy) NSDictionary<NSNumber *, NSArray<NSNumber *> *> *collectiblesByTransformation;
@property(nonatomic) NSInteger required;
+ (instancetype)shared;
- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible;
- (NSInteger)progressForTransformation:(NSInteger)transformation;
- (NSString *)localizedNameForTransformation:(NSInteger)transformation;
- (NSString *)englishNameForTransformation:(NSInteger)transformation;
- (void)observePickups:(NSArray<EIDPickupIdentity *> *)pickups gameplayActive:(BOOL)gameplayActive;
- (void)observeGameplayActive:(BOOL)gameplayActive;
@end

@implementation EIDTransformationProgress
+ (instancetype)shared {
    static EIDTransformationProgress *tracker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ tracker = [EIDTransformationProgress new]; });
    return tracker;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _required = 3;

    NSString *path = EIDTransformResourcePath();
    NSData *data = path.length ? [NSData dataWithContentsOfFile:path] : nil;
    NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *rawAssignments = [json[@"assignments"] isKindOfClass:NSDictionary.class] ? json[@"assignments"] : nil;
    if (rawAssignments) _assignments = rawAssignments;
    NSDictionary *rawNames = [json[@"names"] isKindOfClass:NSDictionary.class] ? json[@"names"] : nil;
    if (rawNames) _englishNames = rawNames;
    NSDictionary *rawLocalized = [json[@"names_by_language"] isKindOfClass:NSDictionary.class] ? json[@"names_by_language"] : nil;
    if (rawLocalized) _namesByLanguage = rawLocalized;
    NSNumber *required = [json[@"required"] isKindOfClass:NSNumber.class] ? json[@"required"] : nil;
    if (required.integerValue > 0) _required = required.integerValue;
    NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *members =
        [NSMutableDictionary dictionary];
    [_assignments enumerateKeysAndObjectsUsingBlock:
        ^(NSString *key, NSArray<NSNumber *> *transformations, __unused BOOL *stop) {
        NSArray<NSString *> *parts = [key componentsSeparatedByString:@":"];
        if (parts.count != 2 || parts[0].integerValue != EIDPickupVariantCollectible) return;
        NSInteger collectibleID = parts[1].integerValue;
        if (collectibleID <= 0 || collectibleID > 732 ||
            ![transformations isKindOfClass:NSArray.class]) return;
        for (NSNumber *transformation in transformations) {
            if (![transformation isKindOfClass:NSNumber.class] || transformation.integerValue <= 0) {
                continue;
            }
            NSMutableArray<NSNumber *> *values = members[transformation];
            if (!values) {
                values = [NSMutableArray array];
                members[transformation] = values;
            }
            [values addObject:@(collectibleID)];
        }
    }];
    NSMutableDictionary<NSNumber *, NSArray<NSNumber *> *> *immutableMembers =
        [NSMutableDictionary dictionary];
    [members enumerateKeysAndObjectsUsingBlock:
        ^(NSNumber *key, NSMutableArray<NSNumber *> *values, __unused BOOL *stop) {
        immutableMembers[key] = values.copy;
    }];
    _collectiblesByTransformation = immutableMembers.copy;
    EIDLog(@"native transformation tracker loaded %lu assignments, %lu groups, %lu languages; "
           "requirement %ld",
           (unsigned long)_assignments.count, (unsigned long)_collectiblesByTransformation.count,
           (unsigned long)_namesByLanguage.count, (long)_required);
    return self;
}

- (NSArray<NSNumber *> *)transformationsForCollectible:(NSInteger)collectible {
    return [self transformationsForVariant:EIDPickupVariantCollectible subtype:collectible];
}

- (NSArray<NSNumber *> *)transformationsForVariant:(NSInteger)variant subtype:(NSInteger)subtype {
    // EID uses effect+1 for both normal and horse-pill assignments. Unknown
    // pills retain color identity and must never reveal a transformation.
    if (variant == EIDPickupVariantUnidentifiedPill || subtype <= 0) return @[];
    if (variant == EIDPickupVariantHorsePill) variant = EIDPickupVariantPill;
    if (variant == EIDPickupVariantTrinket) subtype &= 0x7fff;
    NSArray *values = self.assignments[[NSString stringWithFormat:@"%ld:%ld", (long)variant, (long)subtype]];
    return [values isKindOfClass:NSArray.class] ? values : @[];
}

- (NSArray<NSNumber *> *)allTransformationIdentifiers {
    static NSArray<NSNumber *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = @[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10,
                        @11, @12, @13, @14, @15];
    });
    return identifiers;
}

- (NSString *)englishNameForTransformation:(NSInteger)transformation {
    NSString *key = [NSString stringWithFormat:@"%ld", (long)transformation];
    NSString *name = self.englishNames[key];
    return [name isKindOfClass:NSString.class] ? name : @"";
}

- (NSString *)localizedNameForTransformation:(NSInteger)transformation {
    NSString *key = [NSString stringWithFormat:@"%ld", (long)transformation];
    NSString *language = [[NSUserDefaults standardUserDefaults] stringForKey:@"IsaacEIDLanguage"] ?: @"en_us";
    NSDictionary *localized = self.namesByLanguage[language];
    NSString *name = [localized isKindOfClass:NSDictionary.class] ? localized[key] : nil;
    if ([name isKindOfClass:NSString.class] && name.length) return name;

    NSDictionary *english = self.namesByLanguage[@"en_us"];
    name = [english isKindOfClass:NSDictionary.class] ? english[key] : nil;
    if ([name isKindOfClass:NSString.class] && name.length) return name;
    return [self englishNameForTransformation:transformation];
}

- (NSInteger)progressForTransformation:(NSInteger)transformation {
    if (transformation <= 0) return 0;
    NSInteger nativeForm = EIDNativeFormIDForTransformation(transformation);
    if (nativeForm != NSNotFound) {
        NSInteger nativeCount = self.probe.transformationStateAvailable
            ? [self.probe nativeTransformationCounterForFormID:nativeForm] : 0;
        NSInteger liveCount = 0;
        if (self.probe.ownedCollectibleStateAvailable) {
            for (NSNumber *collectible in self.collectiblesByTransformation[@(transformation)]) {
                liveCount += [self.probe
                    transformationCollectibleCountForID:collectible.integerValue];
            }
        }
        // PlayerForm is authoritative across reloads and after an active item is
        // replaced, but Isaac can update it a few frames after the live inventory.
        // Taking the maximum gives an immediate in-room update without losing the
        // persisted history that the inventory alone cannot reconstruct.
        // Original EID displays the native count without capping it to the
        // requirement: four Puberty uses are useful information as 4/3.
        return MAX(0, MAX(nativeCount, liveCount));
    }

    // Super Bum (EID 11) is a familiar merge, not an entry in the native
    // PlayerForm array. Once its verified native familiar exists, the merge is
    // complete even though the three source collectibles may no longer be held.
    if (transformation != 11) return 0;
    NSInteger count = 0;
    if (self.probe.ownedCollectibleStateAvailable) {
        for (NSNumber *collectible in self.collectiblesByTransformation[@(transformation)]) {
            count += [self.probe ownedCollectibleCountForID:collectible.integerValue];
        }
    }
    return MAX(self.probe.superBumActive ? self.required : 0, count);
}

- (NSInteger)progressForTransformation:(NSInteger)transformation playerIndex:(NSInteger)playerIndex {
    if (playerIndex<0) return [self progressForTransformation:transformation];
    NSArray *players = self.probe.descriptionState[@"players"];
    NSDictionary *selected = nil;
    for (NSDictionary *player in players)
        if ([player[@"index"] integerValue]==playerIndex) { selected=player; break; }
    if (!selected) return -1;
    NSInteger nativeForm = EIDNativeFormIDForTransformation(transformation), live=0;
    NSDictionary *counts = selected[@"collectible_counts"];
    if (![counts isKindOfClass:NSDictionary.class]) return -1;
    NSCountedSet *actives = [[NSCountedSet alloc] initWithArray:selected[@"active_ids"] ?: @[]];
    for (NSNumber *item in self.collectiblesByTransformation[@(transformation)])
        live += MAX([counts[item.stringValue] integerValue],(NSInteger)[actives countForObject:item]);
    if (nativeForm!=NSNotFound) {
        NSArray *forms = selected[@"forms"];
        if (![forms isKindOfClass:NSArray.class] || nativeForm<0 || (NSUInteger)nativeForm>=forms.count) return -1;
        return MAX(live,[forms[(NSUInteger)nativeForm] integerValue]);
    }
    if (transformation!=11) return -1;
    if ([selected[@"super_bum_active"] isKindOfClass:NSNumber.class])
        return MAX(live,[selected[@"super_bum_active"] boolValue] ? self.required : 0);
    // Preserve the verified single-player fallback if the room list was
    // transiently unavailable. Never borrow a global merge flag in co-op.
    return players.count==1 ? MAX(live,self.probe.superBumActive ? self.required : 0) : -1;
}

- (NSString *)progressSignatureForPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    EIDPickupIdentity *pickup = pickups.firstObject;
    if (!pickup) return @"";
    NSArray<NSNumber *> *transformations = [self transformationsForVariant:pickup.variant subtype:pickup.subtype];
    if (!transformations.count) return @"";

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:transformations.count];
    for (NSNumber *transformation in transformations) {
        [parts addObject:[NSString stringWithFormat:@"%@=%ld", transformation,
                          (long)[self progressForTransformation:transformation.integerValue]]];
    }
    return [NSString stringWithFormat:@"%lu:%ld:%ld:%@", (unsigned long)self.probe.runCounter,
            (long)pickup.variant, (long)pickup.subtype, [parts componentsJoinedByString:@","]];
}

- (void)logProgressForCollectible:(NSInteger)collectible
                   transformations:(NSArray<NSNumber *> *)transformations {
    if (!transformations.count) return;
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:transformations.count];
    for (NSNumber *transformation in transformations) {
        NSInteger progress = [self progressForTransformation:transformation.integerValue];
        [parts addObject:[NSString stringWithFormat:@"%@=%ld/%ld", transformation,
                          (long)progress, (long)self.required]];
    }
    NSString *state = [NSString stringWithFormat:@"%lu:%ld:%@",
                       (unsigned long)self.probe.runCounter, (long)collectible,
                       [parts componentsJoinedByString:@","]];
    static NSString *lastLoggedState;
    if ([lastLoggedState isEqualToString:state]) return;
    lastLoggedState = state;
    EIDLog(@"transformation progress for collectible %ld: %@ (native/live counters %@)",
           (long)collectible, [parts componentsJoinedByString:@", "],
           self.probe.transformationStateAvailable ? @"ready" : @"unavailable");
}

- (void)resetForNewRun {
    // Progress is a live read of the current native player inventory. The
    // probe clears its snapshot on every authoritative run transition.
}

- (void)observeGameplayActive:(BOOL)gameplayActive {
    (void)gameplayActive;
}

- (void)observePickups:(NSArray<EIDPickupIdentity *> *)pickups gameplayActive:(BOOL)gameplayActive {
    (void)pickups;
    (void)gameplayActive;
}
@end
