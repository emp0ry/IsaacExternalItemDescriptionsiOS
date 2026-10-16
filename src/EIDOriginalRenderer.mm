#import "EIDOriginalRenderer.h"
#import "EIDOriginalScene.h"
#import "EIDPresentationConfig.h"
#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDOverlayController.h"
#import "EIDCardArtwork.h"
#import "EIDPillArtwork.h"
#import "EIDLogger.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <cmath>

static const void *CanvasKey=&CanvasKey;
static const void *CounterKey=&CounterKey;
static const void *SceneKey=&SceneKey;
static EIDBitmapFont *CounterFont;
#ifndef EID_DEVELOPMENT_RENDER_CAPTURE
#define EID_DEVELOPMENT_RENDER_CAPTURE 0
#endif

@interface EIDOriginalCanvas : UIView
@property(nonatomic,strong) EIDOriginalScene *scene;
@property(nonatomic,weak) id controller;
@property(nonatomic) CGFloat pixelScale;
@property(nonatomic) NSUInteger gameFrame;
@property(nonatomic,strong) CADisplayLink *displayLink;
@property(nonatomic,copy) NSString *renderIdentity,*lastDrawIdentity;
- (void)animationTick:(CADisplayLink *)link;
@end
@interface EIDOriginalDisplayTarget : NSObject
@property(nonatomic,weak) EIDOriginalCanvas *canvas;
- (void)tick:(CADisplayLink *)link;
@end
@implementation EIDOriginalDisplayTarget
- (void)tick:(CADisplayLink *)link { [self.canvas animationTick:link]; }
@end
@implementation EIDOriginalCanvas
- (void)dealloc { [_displayLink invalidate]; }
- (void)setScene:(EIDOriginalScene *)scene {
    _scene=scene;
    [_displayLink invalidate]; _displayLink=nil;
    if (scene.animated) {
        EIDOriginalDisplayTarget *target=[EIDOriginalDisplayTarget new]; target.canvas=self;
        _displayLink=[CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
        _displayLink.preferredFramesPerSecond=30; [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    [self setNeedsDisplay];
}
- (void)animationTick:(CADisplayLink *)link {
    (void)link;
    if (self.hidden || !self.window || self.superview.alpha<=.01 || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    EIDNativeProbe *probe=[self.controller valueForKey:@"probe"];
    if (probe.pauseStateAvailable && probe.paused) return;
    ++self.gameFrame; [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    (void)rect; CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context,self.pixelScale,self.pixelScale);
    CGContextTranslateCTM(context,-self.scene.bounds.origin.x,-self.scene.bounds.origin.y);
    [self.scene drawInContext:context frame:self.gameFrame];
    if (![self.lastDrawIdentity isEqual:self.renderIdentity]) {
        self.lastDrawIdentity=self.renderIdentity;
        EIDLog(@"bitmap draw %@: %lu operations, canvas %@ alpha %.2f hidden %d, panel %@ alpha %.2f",
            self.renderIdentity,(unsigned long)self.scene.operationCount,NSStringFromCGRect(self.frame),self.alpha,self.hidden,
            NSStringFromCGRect(self.superview.frame),self.superview.alpha);
    }
}
@end

@interface EIDOriginalCounter : UIView
@property(nonatomic,strong) EIDBitmapFont *font;
@property(nonatomic,copy) NSString *text;
@property(nonatomic) CGFloat pixelScale;
@end
@implementation EIDOriginalCounter
- (void)drawRect:(CGRect)rect {
    (void)rect; CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context,self.pixelScale,self.pixelScale);
    CGFloat x=MAX(2,self.bounds.size.width/self.pixelScale-[self.font width:self.text]-2);
    [self.font draw:self.text at:CGPointMake(x,2) color:UIColor.whiteColor.CGColor context:context];
}
@end

static EIDOriginalSprite *DynamicSprite(UIImage *image,CGFloat advance,CGFloat height,CGFloat dx,CGFloat dy,BOOL item) {
    if (!image.CGImage) return nil;
    EIDOriginalSprite *sprite=[EIDOriginalSprite new]; sprite.raster=[[EIDRaster alloc] initWithImage:image.CGImage];
    CGFloat w=CGImageGetWidth(image.CGImage),h=CGImageGetHeight(image.CGImage);
    sprite.rect=CGRectMake(0,0,item?w*.5:w,item?h*.5:h);
    sprite.advance=advance; sprite.height=height; sprite.offsetX=dx; sprite.offsetY=dy; return sprite;
}

BOOL EIDRenderOriginalDescription(id controller,EIDDescription *item,EIDPickupIdentity *pickup,EIDDescriptionStore *store,
    NSString *detail,NSArray<NSDictionary *> *transformations,UIImage *image,NSArray<NSString *> *roots,
    CGFloat scale,CGFloat alpha,BOOL showName,BOOL showQuality,BOOL showDetail) {
    UIView *panel=[controller valueForKey:@"panel"],*rootView=[controller valueForKey:@"rootView"];
    if (!panel || !rootView) return NO;
    NSString *root=nil;
    for (NSString *candidate in roots) if ([[NSFileManager defaultManager] isReadableFileAtPath:
        [candidate stringByAppendingPathComponent:@"original-renderer.json"]]) { root=candidate; break; }
    if (!root) return NO;
    EIDOriginalCanvas *canvas=objc_getAssociatedObject(controller,CanvasKey);
    if (!canvas) {
        canvas=[[EIDOriginalCanvas alloc] initWithFrame:CGRectZero]; canvas.backgroundColor=UIColor.clearColor;
        canvas.opaque=NO; canvas.userInteractionEnabled=NO; canvas.controller=controller;
        objc_setAssociatedObject(controller,CanvasKey,canvas,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSString *cacheKey=[root stringByAppendingFormat:@"/%@",store.languageCode];
    NSString *previous=objc_getAssociatedObject(canvas,SceneKey);
    EIDOriginalScene *scene=canvas.scene;
    if (!scene || ![previous isEqual:cacheKey]) {
        __weak EIDDescriptionStore *weakStore=store;
        NSCache<NSString *,UIImage *> *art=[NSCache new]; art.countLimit=128;
        EIDOriginalIconResolver resolver=^EIDOriginalSprite *(NSString *token) {
            NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:
                @"^(?:Item5\\.(100|350)\\.([0-9]+)|Collectible([0-9]+)|Trinket([0-9]+)|Card([0-9]+)|Pill([0-9]+))$" options:0 error:nil];
            NSTextCheckingResult *m=[regex firstMatchInString:token options:0 range:NSMakeRange(0,token.length)]; if (!m) return nil;
            if ([m rangeAtIndex:5].location!=NSNotFound) return DynamicSprite(EIDCardImageForSubtype([[token substringWithRange:[m rangeAtIndex:5]] integerValue]),8,8,0,1,NO);
            if ([m rangeAtIndex:6].location!=NSNotFound) return DynamicSprite(EIDPillImageForColor([[token substringWithRange:[m rangeAtIndex:6]] integerValue]),9,8,0,1,NO);
            NSInteger variant=100,subtype=0;
            if ([m rangeAtIndex:1].location!=NSNotFound) { variant=[[token substringWithRange:[m rangeAtIndex:1]] integerValue]; subtype=[[token substringWithRange:[m rangeAtIndex:2]] integerValue]; }
            else { BOOL collectible=[m rangeAtIndex:3].location!=NSNotFound; variant=collectible?100:350; subtype=[[token substringWithRange:[m rangeAtIndex:collectible?3:4]] integerValue]; }
            EIDDescription *description=[weakStore descriptionForPickupVariant:variant subtype:subtype];
            if (!description.iconPath.length) return nil;
            UIImage *icon=[art objectForKey:description.iconPath];
            if (!icon) { icon=[UIImage imageWithContentsOfFile:description.iconPath]; if (icon) [art setObject:icon forKey:description.iconPath]; }
            return DynamicSprite(icon,11,8,-2,-2,YES);
        };
        EIDOriginalNameResolver names=^NSString *(NSString *token) {
            NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^Name(Only)?(?:([CTKP])([0-9]+)|5\\.(100|350|300|70)\\.([0-9]+))$" options:0 error:nil];
            NSTextCheckingResult *m=[regex firstMatchInString:token options:0 range:NSMakeRange(0,token.length)]; if (!m) return nil;
            BOOL generic=[m rangeAtIndex:4].location!=NSNotFound;
            NSString *kind=generic?@"":[token substringWithRange:[m rangeAtIndex:2]];
            NSInteger variant=generic?[[token substringWithRange:[m rangeAtIndex:4]] integerValue]:
                [kind isEqual:@"C"]?100:[kind isEqual:@"T"]?350:[kind isEqual:@"K"]?300:70;
            NSInteger subtype=[[token substringWithRange:[m rangeAtIndex:generic?5:3]] integerValue];
            NSString *name=[weakStore descriptionForPickupVariant:variant subtype:subtype].name ?: @"?";
            NSString *iconName=variant==100?@"Collectible":variant==350?@"Trinket":variant==300?@"Card":@"Pill";
            NSString *prefix=[m rangeAtIndex:1].location==NSNotFound?[NSString stringWithFormat:@"{{%@%ld}} ",iconName,(long)subtype]:@"";
            return [NSString stringWithFormat:@"%@{{%@}}%@{{CR}}",prefix,variant==300?@"ColorCard":variant==70?@"ColorPill":@"ColorYellow",name];
        };
        scene=[[EIDOriginalScene alloc] initWithRoot:root language:store.languageCode iconResolver:resolver nameResolver:names];
        if (!scene) return NO;
        objc_setAssociatedObject(canvas,SceneKey,cacheKey,OBJC_ASSOCIATION_COPY_NONATOMIC);
        EIDLog(@"original bitmap renderer loaded: %@, line height %.0f (no system description font)",store.languageCode,scene.font.lineHeight);
    }
    EIDOriginalSprite *headerIcon=image?DynamicSprite(image,11,8,-2,-2,pickup.variant==100 || pickup.variant==350):nil;
    if (image && pickup.variant==EIDPickupVariantCard) headerIcon=[scene sprite:[NSString stringWithFormat:@"Card%ld",(long)pickup.subtype]];
    else if (image && (pickup.variant==EIDPickupVariantPill || pickup.variant==EIDPickupVariantHorsePill || pickup.variant==EIDPickupVariantUnidentifiedPill)) {
        NSInteger color=pickup.rawPillSubtype ?: (pickup.variant==EIDPickupVariantUnidentifiedPill?pickup.subtype:0);
        headerIcon=[scene sprite:[NSString stringWithFormat:@"Pill%ld",(long)color]];
    } else if (pickup.variant==EIDPickupVariantDiceRoom) headerIcon=[scene sprite:[NSString stringWithFormat:@"DiceFace%ld",(long)pickup.subtype]];
    else if (pickup.variant==EIDPickupVariantSacrificeRoom) headerIcon=nil;
    scene.unidentifiedPill=pickup.variant==EIDPickupVariantUnidentifiedPill;
    scene.statChangeIcons=EIDStatChangeIconsEnabled(NSUserDefaults.standardUserDefaults);
    CGFloat left=((CGFloat(*)(id,SEL))objc_msgSend)(controller,NSSelectorFromString(@"overlayLeftMargin"));
    CGFloat available=MAX(scene.defaultTextWidth,(rootView.bounds.size.width-left-24)/scale-12);
    scene.widthMultiplier=MIN(EIDTextWidthMultiplier(NSUserDefaults.standardUserDefaults),available/scene.defaultTextWidth);
    // Pocket artwork returned by native iOS helpers is already a cropped icon.
    [scene layoutName:item.name detail:detail icon:headerIcon itemType:item.itemType chargeType:item.chargeType charges:item.maxCharges
        quality:pickup.variant==100?item.quality:-1 transformations:transformations showName:showName showQuality:showQuality showDetail:showDetail];
    CGRect measured=scene.bounds;
    if (!std::isfinite(measured.origin.x) || !std::isfinite(measured.origin.y) ||
        !std::isfinite(measured.size.width) || !std::isfinite(measured.size.height) ||
        measured.size.width<0 || measured.size.height<0 || measured.size.width>8192 || measured.size.height>32768) {
        EIDLog(@"bitmap invalid bounds for %ld:%ld: %@; using established renderer",(long)pickup.variant,(long)pickup.subtype,NSStringFromCGRect(measured));
        return NO;
    }
    [controller setValue:@(scene.operationCount>0) forKey:@"descriptionHasContent"];
    [panel.layer removeAllAnimations];
    CounterFont=scene.font; canvas.scene=scene; canvas.pixelScale=scale; canvas.alpha=MIN(1,MAX(.15,alpha)); canvas.hidden=NO;
    NSString *renderIdentity=[NSString stringWithFormat:@"%ld:%ld:%d",(long)pickup.variant,(long)pickup.subtype,[controller valueForKey:@"selectedInventoryItem"]!=nil];
    BOOL changed=![canvas.renderIdentity isEqual:renderIdentity]; canvas.renderIdentity=renderIdentity;
    if (canvas.superview!=panel) [panel addSubview:canvas];
    UILabel *label=[controller valueForKey:@"label"]; label.hidden=YES; label.alpha=canvas.alpha;
    label.attributedText=[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@",item.name ?: @"",detail ?: @""]];
    UIImageView *iconView=[controller valueForKey:@"itemIconView"]; iconView.hidden=YES; iconView.image=nil;
    CGFloat x=((CGFloat(*)(id,SEL))objc_msgSend)(controller,NSSelectorFromString(@"overlayLeftMargin"));
    CGFloat y=((CGFloat(*)(id,SEL))objc_msgSend)(controller,NSSelectorFromString(@"overlayTopMargin"));
    CGFloat inset=[(EIDOverlayController *)controller collectibleCycleHeaderInset];
    CGSize size=CGSizeMake(ceil(scene.bounds.size.width*scale)+inset,ceil(scene.bounds.size.height*scale));
    panel.frame=CGRectMake(x,y,MAX(1,size.width),MAX(1,size.height)); canvas.frame=(CGRect){CGPointZero,size};
    [canvas setNeedsDisplay]; [(EIDOverlayController *)controller updateCollectibleCycleControls];
    if (changed) EIDLog(@"bitmap layout %@: name %lu detail %lu, %lu operations, bounds %@, scene %@, flags %d/%d/%d",
        renderIdentity,(unsigned long)item.name.length,(unsigned long)detail.length,(unsigned long)scene.operationCount,
        NSStringFromCGRect(scene.bounds),NSStringFromCGRect(panel.frame),showName,showQuality,showDetail);
#if EID_DEVELOPMENT_RENDER_CAPTURE
    static NSUInteger captureCount=0;
    if (changed && captureCount++<12) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (canvas.hidden || ![canvas.renderIdentity isEqual:renderIdentity]) return;
            CGSize captureSize=panel.bounds.size;
            if (captureSize.width<1 || captureSize.height<1 || captureSize.width>2000 || captureSize.height>2000) return;
            UIGraphicsBeginImageContextWithOptions(captureSize,NO,1);
            [canvas.layer displayIfNeeded]; [panel.layer renderInContext:UIGraphicsGetCurrentContext()];
            UIImage *capture=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
            NSString *folder=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/IsaacExternalItemDescriptions/render-capture"];
            [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
            [UIImagePNGRepresentation(capture) writeToFile:[folder stringByAppendingPathComponent:[renderIdentity stringByAppendingString:@".png"]] atomically:YES];
        });
    }
#endif
    return YES;
}

void EIDHideOriginalDescription(id controller) {
    EIDOriginalCanvas *canvas=objc_getAssociatedObject(controller,CanvasKey);
    canvas.hidden=YES; [canvas.displayLink invalidate]; canvas.displayLink=nil;
    [controller setValue:@NO forKey:@"descriptionHasContent"];
}

BOOL EIDRenderOriginalCounter(UILabel *label,NSString *text,CGFloat scale) {
    if (!CounterFont) return NO;
    EIDOriginalCounter *counter=objc_getAssociatedObject(label,CounterKey);
    if (!counter) {
        counter=[[EIDOriginalCounter alloc] initWithFrame:label.bounds]; counter.userInteractionEnabled=NO;
        counter.opaque=NO; counter.backgroundColor=UIColor.clearColor; counter.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [label addSubview:counter]; objc_setAssociatedObject(label,CounterKey,counter,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    counter.frame=label.bounds; counter.font=CounterFont;
    counter.text=[text stringByReplacingOccurrencesOfString:@"›" withString:@">"];
    counter.pixelScale=scale; label.text=nil;
    [counter setNeedsDisplay]; return YES;
}
