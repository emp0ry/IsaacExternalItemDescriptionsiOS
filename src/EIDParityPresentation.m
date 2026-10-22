#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
#import "EIDTransformationProgress.h"
#import "EIDContextDescriptions.h"
#import "EIDDynamicDescriptions.h"
#import "EIDAdvancedDescriptions.h"
#import "EIDCardArtwork.h"
#import "EIDPillArtwork.h"
#import "EIDOverlayController.h"
#import "EIDCharacterSynergies.h"
#import "EIDFeatureConfig.h"
#import "EIDOriginalRenderer.h"
#import "EIDSettings.h"
#import "EIDPresentationConfig.h"
#import "EIDInlineIconPolicy.h"
#include "EIDArtworkBounds.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>

static NSString *const EIDScaleKey=@"IsaacEIDScale",*const EIDTransparencyKey=@"IsaacEIDTransparency",*const EIDShowNameKey=@"IsaacEIDShowItemName",*const EIDShowIconKey=@"IsaacEIDShowItemIcon",*const EIDShowQualityKey=@"IsaacEIDShowQuality",*const EIDShowDescriptionKey=@"IsaacEIDShowItemDescription";
static UIColor *EIDObjNameColor(void){return [UIColor colorWithRed:.8 green:.3 blue:.8 alpha:1];}
static UIColor *EIDTransformationColor(void){return [UIColor colorWithRed:.42 green:.64 blue:1 alpha:1];}
static NSArray<NSString*> *EIDResourceRoots(void){NSMutableArray*roots=[NSMutableArray array];NSString*main=NSBundle.mainBundle.bundlePath;[roots addObjectsFromArray:@[[main stringByAppendingPathComponent:@"Frameworks/IsaacEID.bundle"],[main stringByAppendingPathComponent:@"IsaacEID.bundle"],[main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/Resources/IsaacEID.bundle"],[main stringByAppendingPathComponent:@"Frameworks/IsaacExternalItemDescriptions.framework/IsaacEID.bundle"],[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions"],@"/var/jb/Library/Application Support/IsaacExternalItemDescriptions",@"/Library/Application Support/IsaacExternalItemDescriptions"]];NSBundle*framework=[NSBundle bundleForClass:NSClassFromString(@"EIDOverlayController")?:NSObject.class];if(framework.bundlePath.length){[roots addObject:[framework.bundlePath stringByAppendingPathComponent:@"Resources/IsaacEID.bundle"]];[roots addObject:[framework.bundlePath stringByAppendingPathComponent:@"IsaacEID.bundle"]];[roots addObject:framework.bundlePath];}return roots;}
static NSString *EIDResource(NSString*name){for(NSString*root in EIDResourceRoots()){NSString*p=[root stringByAppendingPathComponent:name];if([[NSFileManager defaultManager]isReadableFileAtPath:p])return p;}return nil;}

@interface EIDAtlasParser:NSObject<NSXMLParserDelegate>@property(nonatomic,strong)NSMutableDictionary<NSString*,NSMutableArray*>*animations;@property(nonatomic,copy)NSString*animation;@property(nonatomic)BOOL layer;@end
@implementation EIDAtlasParser
-(instancetype)init{if((self=[super init]))_animations=[NSMutableDictionary dictionary];return self;}
-(void)parser:(NSXMLParser*)p didStartElement:(NSString*)e namespaceURI:(NSString*)u qualifiedName:(NSString*)q attributes:(NSDictionary<NSString*,NSString*>*)a{(void)p;(void)u;(void)q;if([e isEqualToString:@"Animation"]){self.animation=a[@"Name"];if(self.animation.length)self.animations[self.animation]=[NSMutableArray array];self.layer=NO;}else if([e isEqualToString:@"LayerAnimation"]&&self.animation.length)self.layer=[a[@"LayerId"]integerValue]==0;else if([e isEqualToString:@"Frame"]&&self.layer&&self.animation.length){CGFloat x=[a[@"XCrop"]doubleValue],y=[a[@"YCrop"]doubleValue],w=[a[@"Width"]doubleValue],h=[a[@"Height"]doubleValue];[self.animations[self.animation]addObject:(w>0&&h>0)?[NSValue valueWithCGRect:CGRectMake(x,y,w,h)]:NSNull.null];}}
-(void)parser:(NSXMLParser*)p didEndElement:(NSString*)e namespaceURI:(NSString*)u qualifiedName:(NSString*)q{(void)p;(void)u;(void)q;if([e isEqualToString:@"LayerAnimation"])self.layer=NO;if([e isEqualToString:@"Animation"])self.animation=nil;}
@end

static NSDictionary *EIDParseAnimations(NSString*resource){NSData*d=[NSData dataWithContentsOfFile:EIDResource(resource)];if(!d.length)return @{};EIDAtlasParser*x=[EIDAtlasParser new];NSXMLParser*p=[[NSXMLParser alloc]initWithData:d];p.delegate=x;return[p parse]?x.animations.copy:@{};}
static UIImage *EIDCrop(UIImage*image,CGRect r){if(!image.CGImage)return nil;CGRect b=CGRectMake(0,0,CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage));if(!CGRectContainsRect(b,r))return nil;CGImageRef g=CGImageCreateWithImageInRect(image.CGImage,r);if(!g)return nil;UIImage*out=[UIImage imageWithCGImage:g scale:1 orientation:UIImageOrientationUp];CGImageRelease(g);return out;}

@interface EIDInlineAtlas:NSObject@property(nonatomic,strong)UIImage*image;@property(nonatomic,copy)NSDictionary*animations;@property(nonatomic,copy)NSDictionary*map;@property(nonatomic,strong)NSMutableDictionary*cache;+(instancetype)shared;-(UIImage*)imageForToken:(NSString*)token;-(UIImage*)imageForAnimation:(NSString*)animation frame:(NSInteger)frame;@end
@implementation EIDInlineAtlas
+(instancetype)shared{static id x;static dispatch_once_t once;dispatch_once(&once,^{x=[self new];});return x;}
-(instancetype)init{if(!(self=[super init]))return nil;_cache=[NSMutableDictionary dictionary];_image=[UIImage imageWithContentsOfFile:EIDResource(@"eid_inline_icons.png")];_animations=EIDParseAnimations(@"eid_inline_icons.anm2");NSData*m=[NSData dataWithContentsOfFile:EIDResource(@"eid_inline_icons.json")];id map=m?[NSJSONSerialization JSONObjectWithData:m options:0 error:nil]:nil;_map=[map isKindOfClass:NSDictionary.class]?map:@{};return self;}
- (UIImage *)imageForToken:(NSString *)token {
    if (!token.length) return nil;
    UIImage *cached = self.cache[token];
    if (cached) return cached;
    NSDictionary *mapping = self.map[token];
    if (![mapping isKindOfClass:NSDictionary.class]) {
        NSString *alias = EIDRepentanceStatIconAlias(token);
        mapping = alias ? self.map[alias] : nil;
    }
    if (![mapping isKindOfClass:NSDictionary.class]) return nil;
    NSArray *frames = self.animations[mapping[@"animation"]];
    NSInteger index = [mapping[@"frame"] integerValue];
    if (index < 0 || index >= (NSInteger)frames.count) return nil;
    id frame = frames[(NSUInteger)index];
    if (![frame isKindOfClass:NSValue.class]) return nil;
    UIImage *image = EIDCrop(self.image,[frame CGRectValue]);
    if (image) self.cache[token] = image;
    return image;
}
-(UIImage*)imageForAnimation:(NSString*)animation frame:(NSInteger)frame{if(!animation.length||frame<0)return nil;NSString*k=[NSString stringWithFormat:@"%@:%ld",animation,(long)frame];UIImage*c=self.cache[k];if(c)return c;NSArray*f=self.animations[animation];if(frame>=(NSInteger)f.count)return nil;id v=f[(NSUInteger)frame];if(![v isKindOfClass:NSValue.class])return nil;UIImage*out=EIDCrop(self.image,[v CGRectValue]);if(out)self.cache[k]=out;return out;}
@end

@interface EIDTransformData:NSObject@property(nonatomic,strong)UIImage*image;@property(nonatomic,copy)NSDictionary*animations;@property(nonatomic,copy)NSDictionary*names;@property(nonatomic,copy)NSDictionary*assignments;+(instancetype)shared;-(NSArray*)transformationsForVariant:(NSInteger)v subtype:(NSInteger)s;-(UIImage*)iconForID:(NSInteger)i;-(UIImage*)iconForAnimation:(NSString*)animation frame:(NSInteger)frame;-(NSString*)nameForID:(NSInteger)i;@end
@implementation EIDTransformData
+(instancetype)shared{static id x;static dispatch_once_t once;dispatch_once(&once,^{x=[self new];});return x;}
-(instancetype)init{if(!(self=[super init]))return nil;_image=[UIImage imageWithContentsOfFile:EIDResource(@"eid_transform_icons.png")];_animations=EIDParseAnimations(@"eid_transform_icons.anm2");NSData*d=[NSData dataWithContentsOfFile:EIDResource(@"transformations.json")];NSDictionary*j=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;_names=[j[@"names"] isKindOfClass:NSDictionary.class]?j[@"names"]:@{};_assignments=[j[@"assignments"] isKindOfClass:NSDictionary.class]?j[@"assignments"]:@{};return self;}
-(NSArray*)transformationsForVariant:(NSInteger)v subtype:(NSInteger)s{return self.assignments[[NSString stringWithFormat:@"%ld:%ld",(long)v,(long)s]]?:@[];}
-(NSString*)nameForID:(NSInteger)i{return self.names[[NSString stringWithFormat:@"%ld",(long)i]]?:[NSString stringWithFormat:@"Transformation %ld",(long)i];}
-(UIImage*)iconForID:(NSInteger)i{NSArray*f=self.animations[[NSString stringWithFormat:@"Transformation%ld",(long)i]];if(!f.count||![f[0] isKindOfClass:NSValue.class])return nil;return EIDCrop(self.image,[f[0] CGRectValue]);}
-(UIImage*)iconForAnimation:(NSString*)animation frame:(NSInteger)frame{NSArray*f=self.animations[animation];if(frame<0||frame>=(NSInteger)f.count)return nil;id v=f[(NSUInteger)frame];if(![v isKindOfClass:NSValue.class])return nil;return EIDCrop(self.image,[v CGRectValue]);}
@end

static NSDictionary*Attrs(UIFont*f,UIColor*c,CGFloat s){return @{NSFontAttributeName:[f fontWithSize:f.pointSize*s],NSForegroundColorAttributeName:c};}
static UIImage*EIDCrispRaster(UIImage*image,CGSize pointSize){
    if(!image||pointSize.width<=0||pointSize.height<=0)return image;
    CGFloat screenScale=UIScreen.mainScreen.scale;
    if(screenScale<1)screenScale=1;
    UIGraphicsBeginImageContextWithOptions(pointSize,NO,screenScale);
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context,kCGInterpolationNone);
    CGContextSetShouldAntialias(context,false);
    [image drawInRect:(CGRect){CGPointZero,pointSize} blendMode:kCGBlendModeNormal alpha:1];
    UIImage*result=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result?:image;
}
static NSAttributedString*EIDAttachment(UIImage*i,CGFloat size,CGFloat s,CGFloat baseline,BOOL preserveOriginalSize){if(!i)return nil;CGFloat h=MAX(9,size*s),r=i.size.height?i.size.width/i.size.height:1;CGSize renderedSize=CGSizeMake(h*r,h);NSTextAttachment*a=[NSTextAttachment new];a.image=EIDCrispRaster(i,renderedSize);a.bounds=CGRectMake(0,baseline*s,renderedSize.width,renderedSize.height);if(preserveOriginalSize)objc_setAssociatedObject(a,NSSelectorFromString(@"eid_preserveOriginalAttachmentSize"),@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return[NSAttributedString attributedStringWithAttachment:a];}
static NSAttributedString*Attachment(UIImage*i,CGFloat size,CGFloat s,CGFloat baseline){return EIDAttachment(i,size,s,baseline,NO);}
static NSAttributedString*QualityFallback(NSInteger q,UIFont*f,CGFloat s){return[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"Q%ld",(long)q] attributes:Attrs(f,UIColor.whiteColor,s)];}
static UIImage *EIDTrimVisiblePixels(UIImage *image) {
    CGImageRef cg = image.CGImage;
    if (!cg) return image;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    if (!width || !height || width > 4096 || height > 4096) return image;
    size_t row = width*4;
    unsigned char *pixels = calloc(height,row);
    if (!pixels) return image;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(pixels,width,height,8,row,space,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!bitmap) { free(pixels); return image; }
    CGContextDrawImage(bitmap,CGRectMake(0,0,width,height),cg);
    CGContextRelease(bitmap);
    EIDArtworkBounds bounds = EIDVisibleArtworkBounds(pixels,height*row,width,height,row);
    free(pixels);
    if (!bounds.found) return image;
    CGImageRef cropped = CGImageCreateWithImageInRect(cg,
        CGRectMake(bounds.x,bounds.y,bounds.width,bounds.height));
    if (!cropped) return image;
    UIImage *result = [UIImage imageWithCGImage:cropped scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(cropped);
    return result;
}
static UIImage*EIDActiveChargeImage(EIDDescription*item){UIImage*battery=[[EIDTransformData shared]iconForAnimation:@"active" frame:0];if(!battery)return nil;UIImage*charge=nil;if(item.chargeType==EIDActiveChargeTypeTimed)charge=[[EIDInlineAtlas shared]imageForAnimation:@"Misc" frame:6];else if(item.chargeType==EIDActiveChargeTypeSpecial)charge=[[EIDInlineAtlas shared]imageForAnimation:@"numbers" frame:13];else if(item.maxCharges>=0&&item.maxCharges<=12)charge=[[EIDInlineAtlas shared]imageForAnimation:@"numbers" frame:item.maxCharges];CGSize canvas=CGSizeMake(MAX(16,9+charge.size.width),MAX(16,8+charge.size.height));UIGraphicsBeginImageContextWithOptions(canvas,NO,1);CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetInterpolationQuality(c,kCGInterpolationNone);[battery drawInRect:CGRectMake(0,0,16,16)];if(charge)[charge drawAtPoint:CGPointMake(9,8)];UIImage*out=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();return EIDTrimVisiblePixels(out);}
static void AppendActiveCharge(NSMutableAttributedString*out,EIDDescription*item,UIFont*font,CGFloat scale){if(item.itemType!=EIDCollectibleItemTypeActive)return;NSDictionary*attrs=Attrs(font,UIColor.whiteColor,scale);UIImage*composite=EIDActiveChargeImage(item);NSAttributedString*indicator=EIDAttachment(composite,12.0,scale,-1.8,YES);if(indicator)[out appendAttributedString:indicator];else [out appendAttributedString:[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"[A:%ld]",(long)item.maxCharges] attributes:attrs]];[out appendAttributedString:[[NSAttributedString alloc]initWithString:@" " attributes:attrs]];}
static NSDictionary*Colors(void){static id c;static dispatch_once_t once;dispatch_once(&once,^{c=@{@"ColorEIDText":UIColor.whiteColor,@"ColorText":UIColor.whiteColor,@"ColorEIDObjName":EIDObjNameColor(),@"ColorObjName":EIDObjNameColor(),@"ColorRed":UIColor.redColor,@"ColorBlue":UIColor.blueColor,@"ColorYellow":UIColor.yellowColor,@"ColorCyan":UIColor.cyanColor,@"ColorPink":UIColor.magentaColor,@"ColorOrange":[UIColor orangeColor],@"ColorBagComplete":UIColor.greenColor,@"ColorGreen":UIColor.greenColor,@"ColorGray":UIColor.grayColor,@"ColorShinyPurple":[UIColor colorWithRed:.8 green:.4 blue:1 alpha:1],@"BlinkYellowGreen":[UIColor colorWithRed:.7 green:1 blue:.2 alpha:1]};});return c;}
static UIImage *InlineItemImage(NSString *token, EIDDescriptionStore *store) {
    static NSRegularExpression *expression;
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        expression = [NSRegularExpression regularExpressionWithPattern:
            @"^(?:Item5\\.(100|350)\\.([0-9]+)|Collectible([0-9]+)|Trinket([0-9]+))$" options:0 error:nil];
        cache = [NSCache new];
        cache.countLimit = 128;
    });
    NSTextCheckingResult *match = [expression firstMatchInString:token options:0 range:NSMakeRange(0,token.length)];
    if (!match) return nil;
    NSInteger variant, subtype;
    if ([match rangeAtIndex:1].location != NSNotFound) {
        variant = [[token substringWithRange:[match rangeAtIndex:1]] integerValue];
        subtype = [[token substringWithRange:[match rangeAtIndex:2]] integerValue];
    } else {
        BOOL collectible = [match rangeAtIndex:3].location != NSNotFound;
        variant = collectible ? EIDPickupVariantCollectible : EIDPickupVariantTrinket;
        subtype = [[token substringWithRange:[match rangeAtIndex:collectible ? 3 : 4]] integerValue];
    }
    EIDDescription *item = [store descriptionForPickupVariant:variant subtype:subtype];
    if (!item.iconPath.length) return nil;
    UIImage *image = [cache objectForKey:item.iconPath];
    if (!image) {
        image = [UIImage imageWithContentsOfFile:item.iconPath];
        // Native item textures are padded 32x32 canvases. Match the visible
        // artwork to the inline glyph height, not the transparent canvas.
        image = EIDTrimVisiblePixels(image);
        if (image) [cache setObject:image forKey:item.iconPath];
    }
    return image;
}

static void AppendMarkup(NSMutableAttributedString *output, NSString *text, UIFont *font,
                         CGFloat scale, EIDDescriptionStore *store) {
    if (!text.length || [text isEqualToString:@"?"]) return;
    text = [text stringByReplacingOccurrencesOfString:@"#" withString:@"\n• "];
    if (![text hasPrefix:@"• "]) text = [@"• " stringByAppendingString:text];
    text = [text stringByReplacingOccurrencesOfString:@"↑" withString:@"{{ArrowUp}}"];
    text = [text stringByReplacingOccurrencesOfString:@"↓" withString:@"{{ArrowDown}}"];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:
        @"\\{\\{([^}]+)\\}\\}" options:0 error:nil];
    NSArray *matches = [expression matchesInString:text options:0 range:NSMakeRange(0,text.length)];
    NSUInteger cursor = 0;
    UIColor *color = UIColor.whiteColor;
    for (NSTextCheckingResult *match in matches) {
        if (match.range.location > cursor) {
            [output appendAttributedString:[[NSAttributedString alloc] initWithString:
                [text substringWithRange:NSMakeRange(cursor,match.range.location-cursor)]
                attributes:Attrs(font,color,scale)]];
        }
        NSString *token = [text substringWithRange:[match rangeAtIndex:1]];
        if ([token isEqualToString:@"ColorReset"] || [token isEqualToString:@"CR"]) color = UIColor.whiteColor;
        else if ([token isEqualToString:@"ColorPastelBlue"]) color = [UIColor colorWithRed:.65 green:.8 blue:1 alpha:1];
        else if ([token isEqualToString:@"ColorSilver"]) color = [UIColor colorWithWhite:.75 alpha:1];
        else if ([token isEqualToString:@"ColorGold"]) color = [UIColor colorWithRed:1 green:.78 blue:.2 alpha:1];
        else if ([token isEqualToString:@"ColorPill"]) color = [UIColor colorWithRed:.306 green:.651 blue:.851 alpha:1];
        else if ([token isEqualToString:@"ColorCard"]) color = [UIColor colorWithRed:.815 green:.651 blue:.494 alpha:1];
        else if ([token isEqualToString:@"ColorLime"]) color = UIColor.greenColor;
        else if (Colors()[token]) color = Colors()[token];
        else if (![token hasPrefix:@"Color"]) {
            UIImage *image = [[EIDInlineAtlas shared] imageForToken:token] ?: InlineItemImage(token,store);
            if (!image && [token hasPrefix:@"Card"]) {
                NSString *identifier = [token substringFromIndex:4];
                if (identifier.length && [identifier rangeOfCharacterFromSet:
                    NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound)
                    image = EIDCardImageForSubtype(identifier.integerValue);
            }
            if (!image && [token hasPrefix:@"Pill"]) {
                NSString *identifier = [token substringFromIndex:4];
                if (identifier.length && [identifier rangeOfCharacterFromSet:
                    NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound)
                    image = EIDPillImageForColor(identifier.integerValue);
            }
            NSAttributedString *attachment = Attachment(image,font.pointSize,scale,-1.5);
            if (attachment) [output appendAttributedString:attachment];
        }
        cursor = NSMaxRange(match.range);
    }
    if (cursor < text.length) [output appendAttributedString:[[NSAttributedString alloc]
        initWithString:[text substringFromIndex:cursor] attributes:Attrs(font,color,scale)]];
}

@interface NSObject(EIDParityMethods)
-(void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity*>*)pickups;-(void)eid_parity_attachOverlayIfNeeded;
@end
@interface NSObject(EIDBackgroundMethods)
- (void)applyDescriptionBackground;
@end
@interface EIDParityPresentation:NSObject@end
@implementation EIDParityPresentation
+(void)load{static dispatch_once_t once;dispatch_once(&once,^{Class cls=NSClassFromString(@"EIDOverlayController");if(!cls)return;NSArray*names=@[@"eid_parity_renderPickups:",@"eid_parity_attachOverlayIfNeeded"];for(NSString*n in names){SEL sel=NSSelectorFromString(n);Method m=class_getInstanceMethod(NSObject.class,sel);if(m)class_addMethod(cls,sel,method_getImplementation(m),method_getTypeEncoding(m));}Method o=class_getInstanceMethod(cls,NSSelectorFromString(@"renderPickups:")),r=class_getInstanceMethod(cls,@selector(eid_parity_renderPickups:));if(o&&r)method_exchangeImplementations(o,r);Method oa=class_getInstanceMethod(cls,NSSelectorFromString(@"attachOverlayIfNeeded")),ra=class_getInstanceMethod(cls,@selector(eid_parity_attachOverlayIfNeeded));if(oa&&ra)method_exchangeImplementations(oa,ra);});}
@end

@implementation NSObject(EIDParityMethods)
- (void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity *> *)pickups {
    UILabel *label = [self valueForKey:@"label"];
    UIView *panel = [self valueForKey:@"panel"];
    UIImageView *iconView = [self valueForKey:@"itemIconView"];
    EIDDescriptionStore *store = [self valueForKey:@"store"];
    EIDNativeProbe *probe = [self valueForKey:@"probe"];
    if (!label || !panel || !store || !pickups.count) {
        EIDHideOriginalDescription(self);
        [(EIDOverlayController *)self prepareCollectibleCycleIdentity:nil];
        [self eid_parity_renderPickups:pickups];
        return;
    }
    EIDPickupIdentity *pickup = [probe resolvedRepeatIdentity:[probe resolvedPillIdentity:pickups.firstObject]];
    pickup = [probe resolvedInventoryPreviewIdentity:pickup blackFeatherMetadata:store.contextData[@"black_feather_metadata"] ?: @{}];
    pickup = [(EIDOverlayController *)self prepareCollectibleCycleIdentity:pickup];
    if (!pickup) { EIDHideOriginalDescription(self); label.hidden=NO; [self eid_parity_renderPickups:@[]]; return; }
    BOOL inventory = [self valueForKey:@"selectedInventoryItem"] != nil;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL hiddenInfoEnabled = EIDFeatureEnabled(defaults,EIDHiddenInfoKey);
    if (inventory) pickup = [probe resolvedCurrentEffectIdentity:pickup hiddenInfo:hiddenInfoEnabled];
    BOOL outcomesEnabled = EIDFeatureEnabled(defaults,EIDOutcomesKey);
    pickup = [probe resolvedOutcomeIdentity:pickup insideInventory:inventory enabled:outcomesEnabled];
    EIDDescription *item = [store descriptionForPickupVariant:pickup.variant subtype:pickup.subtype];
    if (!item) {
        EIDLog(@"bitmap fallback: no descriptor for %ld:%ld",(long)pickup.variant,(long)pickup.subtype);
        EIDHideOriginalDescription(self); label.hidden=NO;
        [self eid_parity_renderPickups:pickups]; return;
    }
    NSInteger playerType = pickup.playerType >= 0 ? pickup.playerType : probe.primaryPlayerType;
    NSMutableDictionary *context = store.contextData.mutableCopy;
    context[@"live_state"] = probe.descriptionState;
    context[@"pickup_context"] = pickup.pickupContext;
    context[@"player_type"] = @(playerType);
    context[@"player_index"] = @(pickup.playerIndex >= 0 ? pickup.playerIndex : 0);
    if (pickup.rawPillSubtype) context[@"pill_modifiers"] = @(pickup.pillModifiers);
    context[@"inside_item_reminder"] = @([self valueForKey:@"selectedInventoryItem"] != nil);
    pickup = [probe resolvedGlyphIdentity:pickup insideInventory:[context[@"inside_item_reminder"] boolValue]];
    context[@"pickup_context"] = pickup.pickupContext;
    context[@"rng_predictions_enabled"] = @(outcomesEnabled);
    context[@"void_stat_info_enabled"] = @(EIDFeatureEnabled(defaults,EIDVoidStatInfoKey));
    context[@"hidden_info_enabled"] = @(hiddenInfoEnabled);
    CGFloat scale = [defaults objectForKey:EIDScaleKey] ? [defaults doubleForKey:EIDScaleKey] : 1;
    scale = EIDClampScale(scale);
    CGFloat alpha = [defaults objectForKey:EIDTransparencyKey] ? [defaults doubleForKey:EIDTransparencyKey] : .75;
    BOOL showName = [defaults objectForKey:EIDShowNameKey] ? [defaults boolForKey:EIDShowNameKey] : YES;
    BOOL showIcon = [defaults objectForKey:EIDShowIconKey] ? [defaults boolForKey:EIDShowIconKey] : YES;
    BOOL showQuality = [defaults objectForKey:EIDShowQualityKey] ? [defaults boolForKey:EIDShowQualityKey] : YES;
    BOOL showDetail = [defaults objectForKey:EIDShowDescriptionKey] ? [defaults boolForKey:EIDShowDescriptionKey] : YES;
    UIFont *bodyFont = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    UIFont *titleFont = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    UIFont *transformFont = [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
    UIImage *image = showIcon && item.iconPath.length ? [UIImage imageWithContentsOfFile:item.iconPath] : nil;
    if (!image && showIcon) {
        SEL selector = NSSelectorFromString(@"pocketIconForVariant:subtype:");
        if ([self respondsToSelector:selector])
            image = ((UIImage *(*)(id,SEL,NSInteger,NSInteger))objc_msgSend)(self,selector,
                pickup.rawPillSubtype ? EIDPickupVariantUnidentifiedPill : pickup.variant,
                pickup.rawPillSubtype ?: pickup.subtype);
    }
    NSMutableArray *originalTransformations=[NSMutableArray array];
    EIDTransformationProgress *originalTracker=[EIDTransformationProgress shared];
    originalTracker.probe=probe;
    NSArray *originalIDs=[pickup.pickupContext[@"crown_overview"] boolValue] ||
        EIDUsesSalvageDescription(pickup.variant,pickup.subtype,playerType,context)?@[]:
        [originalTracker transformationsForVariant:pickup.variant subtype:pickup.subtype];
    for (NSNumber *identifier in originalIDs) {
        NSInteger count=pickup.playerIndex>=0?[originalTracker progressForTransformation:identifier.integerValue playerIndex:pickup.playerIndex]:
            [originalTracker progressForTransformation:identifier.integerValue];
        if (count>=0) [originalTransformations addObject:@{@"id":identifier,@"text":[NSString stringWithFormat:@"%@ (%ld/%ld)",
            [originalTracker localizedNameForTransformation:identifier.integerValue],(long)count,(long)MAX(1,originalTracker.required)]}];
    }
    NSSet *originalOwned=[probe currentOwnedItemKeys];
    if (inventory) {
        originalOwned=[NSSet set];
        for (NSDictionary *player in context[@"live_state"][@"players"])
            if ([player[@"index"] isEqual:context[@"player_index"]] && [player[@"owned"] isKindOfClass:NSArray.class]) {
                originalOwned=[NSSet setWithArray:player[@"owned"]]; break;
            }
    }
    NSString *originalDetail=showDetail?EIDContextDescriptionWithOwnedItems(item.detail,pickup.variant,pickup.subtype,
        playerType,probe.gameDifficulty,originalOwned,context):@"";
    if (showDetail) {
        originalDetail=EIDDynamicDescription(originalDetail,pickup.variant,pickup.subtype,probe.gameDifficulty,originalOwned,context);
        originalDetail=EIDAdvancedDescription(originalDetail,pickup.variant,pickup.subtype,probe.gameDifficulty,originalOwned,context);
        originalDetail=EIDCollectionDescription(originalDetail,pickup.variant,pickup.subtype,context);
    }
    if (EIDRenderOriginalDescription(self,item,pickup,store,originalDetail,originalTransformations,image,
        EIDResourceRoots(),scale,alpha,showName,showQuality,showDetail)) {
        [self applyDescriptionBackground];
        [UIView animateWithDuration:.12 animations:^{panel.alpha=1;}];
        [(EIDOverlayController *)self updateCollectibleCycleControls];
        return;
    }
    // Missing or invalid fonts fall back to the established renderer, not a crash.
    EIDHideOriginalDescription(self); label.hidden=NO;
    NSMutableAttributedString *output = [NSMutableAttributedString new];
    NSUInteger headerEnd = 0;
    if (showName) {
        if (showIcon && image) {
            NSAttributedString *attachment = Attachment(image,22.0,scale,-4.0);
            if (attachment) {
                [output appendAttributedString:attachment];
                [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"    " attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];
            }
        }
        AppendActiveCharge(output,item,titleFont,scale);
        NSString *name = item.name.length ? item.name : [NSString stringWithFormat:@"%ld",(long)pickup.subtype];
        [output appendAttributedString:[[NSAttributedString alloc] initWithString:name attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];
        if (showQuality && pickup.variant == EIDPickupVariantCollectible && item.quality >= 0 && item.quality <= 4) {
            [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"  -  " attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];
            NSString *token = [NSString stringWithFormat:@"Quality%ld",(long)item.quality];
            NSAttributedString *quality = Attachment([[EIDInlineAtlas shared] imageForToken:token],16.0,scale,-2.5);
            [output appendAttributedString:quality ?: QualityFallback(item.quality,titleFont,scale)];
        }
        headerEnd = output.length;
        EIDTransformationProgress *tracker = [EIDTransformationProgress shared];
        tracker.probe = probe;
        NSArray *transformations = [pickup.pickupContext[@"crown_overview"] boolValue] || EIDUsesSalvageDescription(pickup.variant,pickup.subtype,playerType,context)
            ? @[] : [tracker transformationsForVariant:pickup.variant subtype:pickup.subtype];
        for (NSNumber *transformation in transformations) {
            NSInteger identifier = transformation.integerValue;
            NSInteger count = pickup.playerIndex>=0 ? [tracker progressForTransformation:identifier playerIndex:pickup.playerIndex]
                : [tracker progressForTransformation:identifier];
            if (count<0) continue;
            [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:Attrs(transformFont,UIColor.whiteColor,scale)]];
            NSAttributedString *icon = Attachment([[EIDTransformData shared] iconForID:identifier],14.0,scale,-2.2);
            if (icon) {
                [output appendAttributedString:icon];
                [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"  " attributes:Attrs(transformFont,EIDTransformationColor(),scale)]];
            }
            NSString *progress = [NSString stringWithFormat:@"%@ (%ld/%ld)",
                [tracker localizedNameForTransformation:identifier],
                (long)count,
                (long)(tracker.required > 0 ? tracker.required : 3)];
            [output appendAttributedString:[[NSAttributedString alloc] initWithString:progress attributes:Attrs(transformFont,EIDTransformationColor(),scale)]];
        }
        if (showDetail) [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:Attrs(bodyFont,UIColor.whiteColor,scale)]];
    }
    if (showDetail) {
        NSSet *owned = [probe currentOwnedItemKeys];
        if (inventory) {
            owned = [NSSet set];
            for (NSDictionary *player in context[@"live_state"][@"players"])
                if ([player[@"index"] isEqual:context[@"player_index"]] && [player[@"owned"] isKindOfClass:NSArray.class]) {
                    owned = [NSSet setWithArray:player[@"owned"]];
                    break;
                }
        }
        NSString *detail = EIDContextDescriptionWithOwnedItems(item.detail, pickup.variant, pickup.subtype,
            playerType, probe.gameDifficulty, owned, context);
        detail = EIDDynamicDescription(detail,pickup.variant,pickup.subtype,probe.gameDifficulty,owned,context);
        detail = EIDAdvancedDescription(detail,pickup.variant,pickup.subtype,probe.gameDifficulty,owned,context);
        detail = EIDCollectionDescription(detail,pickup.variant,pickup.subtype,context);
        detail = EIDFormatStatChangeIcons(detail,EIDStatChangeIconsEnabled(defaults));
        AppendMarkup(output, detail, bodyFont, scale, store);
    }
    NSMutableParagraphStyle *bodyStyle = [NSMutableParagraphStyle new];
    bodyStyle.minimumLineHeight = 14 * scale;
    bodyStyle.maximumLineHeight = 14 * scale;
    [output addAttribute:NSParagraphStyleAttributeName value:bodyStyle range:NSMakeRange(0,output.length)];
    if (headerEnd > 0) {
        NSMutableParagraphStyle *headerStyle = [NSMutableParagraphStyle new];
        headerStyle.minimumLineHeight = 22 * scale;
        headerStyle.maximumLineHeight = 22 * scale;
        headerStyle.paragraphSpacing = 4 * scale;
        [output addAttribute:NSParagraphStyleAttributeName value:headerStyle range:NSMakeRange(0,MIN(output.length,headerEnd+1))];
    }
    iconView.image = nil;
    iconView.hidden = YES;
    label.attributedText = output;
    label.alpha = MIN(1, MAX(.15, alpha));
    iconView.alpha = label.alpha;
    SEL size = NSSelectorFromString(@"sizePanelForText");
    if ([self respondsToSelector:size]) ((void(*)(id,SEL))objc_msgSend)(self,size);
    [self applyDescriptionBackground];
    [UIView animateWithDuration:.12 animations:^{ panel.alpha = 1; }];
    [(EIDOverlayController *)self updateCollectibleCycleControls];
}
-(void)eid_parity_attachOverlayIfNeeded {
    [self eid_parity_attachOverlayIfNeeded];
    EIDBuildSettings(self);
}
@end
