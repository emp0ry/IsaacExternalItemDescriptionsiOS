#import "EIDDescriptionStore.h"
#import "EIDNativeProbe.h"
#import "EIDLogger.h"
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
-(UIImage*)imageForToken:(NSString*)t{if(!t.length)return nil;UIImage*c=self.cache[t];if(c)return c;NSDictionary*m=self.map[t];if(![m isKindOfClass:NSDictionary.class])return nil;NSArray*f=self.animations[m[@"animation"]];NSInteger i=[m[@"frame"]integerValue];if(i<0||i>=(NSInteger)f.count)return nil;id v=f[(NSUInteger)i];if(![v isKindOfClass:NSValue.class])return nil;UIImage*out=EIDCrop(self.image,[v CGRectValue]);if(out)self.cache[t]=out;return out;}
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
static UIImage*EIDTrimVisiblePixels(UIImage*image){CGImageRef cg=image.CGImage;if(!cg)return image;size_t w=CGImageGetWidth(cg),h=CGImageGetHeight(cg),row=w*4;if(!w||!h)return image;unsigned char*pixels=calloc(h,row);if(!pixels)return image;CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();CGContextRef c=CGBitmapContextCreate(pixels,w,h,8,row,cs,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(cs);if(!c){free(pixels);return image;}CGContextDrawImage(c,CGRectMake(0,0,w,h),cg);CGContextRelease(c);size_t minX=w,minY=h,maxX=0,maxY=0;BOOL found=NO;for(size_t y=0;y<h;y++)for(size_t x=0;x<w;x++)if(pixels[y*row+x*4+3]>8){found=YES;minX=MIN(minX,x);minY=MIN(minY,y);maxX=MAX(maxX,x);maxY=MAX(maxY,y);}free(pixels);if(!found)return image;CGRect r=CGRectMake(minX,minY,maxX-minX+1,maxY-minY+1);CGImageRef cropped=CGImageCreateWithImageInRect(cg,r);if(!cropped)return image;UIImage*out=[UIImage imageWithCGImage:cropped scale:1 orientation:UIImageOrientationUp];CGImageRelease(cropped);return out;}
static UIImage*EIDActiveChargeImage(EIDDescription*item){UIImage*battery=[[EIDTransformData shared]iconForAnimation:@"active" frame:0];if(!battery)return nil;UIImage*charge=nil;if(item.chargeType==EIDActiveChargeTypeTimed)charge=[[EIDInlineAtlas shared]imageForAnimation:@"Misc" frame:6];else if(item.chargeType==EIDActiveChargeTypeSpecial)charge=[[EIDInlineAtlas shared]imageForAnimation:@"numbers" frame:13];else if(item.maxCharges>=0&&item.maxCharges<=12)charge=[[EIDInlineAtlas shared]imageForAnimation:@"numbers" frame:item.maxCharges];CGSize canvas=CGSizeMake(MAX(16,9+charge.size.width),MAX(16,8+charge.size.height));UIGraphicsBeginImageContextWithOptions(canvas,NO,1);CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetInterpolationQuality(c,kCGInterpolationNone);[battery drawInRect:CGRectMake(0,0,16,16)];if(charge)[charge drawAtPoint:CGPointMake(9,8)];UIImage*out=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();return EIDTrimVisiblePixels(out);}
static void AppendActiveCharge(NSMutableAttributedString*out,EIDDescription*item,UIFont*font,CGFloat scale){if(item.itemType!=EIDCollectibleItemTypeActive)return;NSDictionary*attrs=Attrs(font,UIColor.whiteColor,scale);UIImage*composite=EIDActiveChargeImage(item);NSAttributedString*indicator=EIDAttachment(composite,12.0,scale,-1.8,YES);if(indicator)[out appendAttributedString:indicator];else [out appendAttributedString:[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"[A:%ld]",(long)item.maxCharges] attributes:attrs]];[out appendAttributedString:[[NSAttributedString alloc]initWithString:@" " attributes:attrs]];}
static NSDictionary*Colors(void){static id c;static dispatch_once_t once;dispatch_once(&once,^{c=@{@"ColorEIDText":UIColor.whiteColor,@"ColorText":UIColor.whiteColor,@"ColorEIDObjName":EIDObjNameColor(),@"ColorObjName":EIDObjNameColor(),@"ColorRed":UIColor.redColor,@"ColorBlue":UIColor.blueColor,@"ColorYellow":UIColor.yellowColor,@"ColorCyan":UIColor.cyanColor,@"ColorPink":UIColor.magentaColor,@"ColorOrange":[UIColor orangeColor]};});return c;}
static void AppendMarkup(NSMutableAttributedString*out,NSString*text,UIFont*f,CGFloat s){if(!text.length||[text isEqualToString:@"?"])return;text=[text stringByReplacingOccurrencesOfString:@"#" withString:@"\n• "];if(![text hasPrefix:@"• "]&&text.length)text=[@"• " stringByAppendingString:text];text=[text stringByReplacingOccurrencesOfString:@"↑" withString:@"{{ArrowUp}}"];text=[text stringByReplacingOccurrencesOfString:@"↓" withString:@"{{ArrowDown}}"];NSRegularExpression*r=[NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^}]+)\\}\\}" options:0 error:nil];NSArray*ms=[r matchesInString:text options:0 range:NSMakeRange(0,text.length)];NSUInteger cur=0;UIColor*color=UIColor.whiteColor;for(NSTextCheckingResult*m in ms){if(m.range.location>cur)[out appendAttributedString:[[NSAttributedString alloc]initWithString:[text substringWithRange:NSMakeRange(cur,m.range.location-cur)] attributes:Attrs(f,color,s)]];NSString*t=[text substringWithRange:[m rangeAtIndex:1]];if([t isEqualToString:@"ColorReset"]||[t isEqualToString:@"CR"])color=UIColor.whiteColor;else if(Colors()[t])color=Colors()[t];else if(![t hasPrefix:@"Color"]){NSAttributedString*a=Attachment([[EIDInlineAtlas shared]imageForToken:t],f.pointSize,s,-1.5);if(a)[out appendAttributedString:a];}cur=NSMaxRange(m.range);}if(cur<text.length)[out appendAttributedString:[[NSAttributedString alloc]initWithString:[text substringFromIndex:cur] attributes:Attrs(f,color,s)]];}

@interface NSObject(EIDParityMethods)
-(void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity*>*)pickups;-(void)eid_parity_attachOverlayIfNeeded;-(void)eid_parity_toggle:(UIButton*)sender;-(void)eid_parity_slider:(UISlider*)slider;-(void)eid_parity_refreshButtons;
@end
@interface EIDParityPresentation:NSObject@end
@implementation EIDParityPresentation
+(void)load{static dispatch_once_t once;dispatch_once(&once,^{Class cls=NSClassFromString(@"EIDOverlayController");if(!cls)return;NSArray*names=@[@"eid_parity_renderPickups:",@"eid_parity_attachOverlayIfNeeded",@"eid_parity_toggle:",@"eid_parity_slider:",@"eid_parity_refreshButtons"];for(NSString*n in names){SEL sel=NSSelectorFromString(n);Method m=class_getInstanceMethod(NSObject.class,sel);if(m)class_addMethod(cls,sel,method_getImplementation(m),method_getTypeEncoding(m));}Method o=class_getInstanceMethod(cls,NSSelectorFromString(@"renderPickups:")),r=class_getInstanceMethod(cls,@selector(eid_parity_renderPickups:));if(o&&r)method_exchangeImplementations(o,r);Method oa=class_getInstanceMethod(cls,NSSelectorFromString(@"attachOverlayIfNeeded")),ra=class_getInstanceMethod(cls,@selector(eid_parity_attachOverlayIfNeeded));if(oa&&ra)method_exchangeImplementations(oa,ra);});}
@end

@implementation NSObject(EIDParityMethods)
-(void)eid_parity_renderPickups:(NSArray<EIDPickupIdentity*>*)pickups{UILabel*l=[self valueForKey:@"label"];UIView*panel=[self valueForKey:@"panel"];UIImageView*iv=[self valueForKey:@"itemIconView"];EIDDescriptionStore*store=[self valueForKey:@"store"];if(!l||!panel||!store||!pickups.count){[self eid_parity_renderPickups:pickups];return;}EIDPickupIdentity*p=pickups.firstObject;EIDDescription*item=[store descriptionForPickupVariant:p.variant subtype:p.subtype];if(!item){[self eid_parity_renderPickups:pickups];return;}NSUserDefaults*d=NSUserDefaults.standardUserDefaults;CGFloat scale=[d objectForKey:EIDScaleKey]?[d doubleForKey:EIDScaleKey]:1;scale=MIN(1.8,MAX(.5,scale));CGFloat alpha=[d objectForKey:EIDTransparencyKey]?[d doubleForKey:EIDTransparencyKey]:.75;BOOL sn=[d objectForKey:EIDShowNameKey]?[d boolForKey:EIDShowNameKey]:YES,si=[d objectForKey:EIDShowIconKey]?[d boolForKey:EIDShowIconKey]:YES,sq=[d objectForKey:EIDShowQualityKey]?[d boolForKey:EIDShowQualityKey]:YES,sd=[d objectForKey:EIDShowDescriptionKey]?[d boolForKey:EIDShowDescriptionKey]:YES;UIFont*bodyFont=[UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];UIFont*titleFont=[UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];UIFont*transformFont=[UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];UIImage*image=si&&item.iconPath.length?[UIImage imageWithContentsOfFile:item.iconPath]:nil;if(!image&&si){SEL sel=NSSelectorFromString(@"pocketIconForVariant:subtype:");if([self respondsToSelector:sel])image=((UIImage*(*)(id,SEL,NSInteger,NSInteger))objc_msgSend)(self,sel,p.variant,p.subtype);}NSMutableAttributedString*out=[NSMutableAttributedString new];NSUInteger headerEnd=0;if(sn){if(si&&image){NSAttributedString*ii=Attachment(image,22.0,scale,-4.0);if(ii){[out appendAttributedString:ii];[out appendAttributedString:[[NSAttributedString alloc]initWithString:@"    " attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];}}AppendActiveCharge(out,item,titleFont,scale);[out appendAttributedString:[[NSAttributedString alloc]initWithString:item.name.length?item.name:[NSString stringWithFormat:@"%ld",(long)p.subtype] attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];if(sq&&p.variant==EIDPickupVariantCollectible&&item.quality>=0&&item.quality<=4){[out appendAttributedString:[[NSAttributedString alloc]initWithString:@"  -  " attributes:Attrs(titleFont,EIDObjNameColor(),scale)]];NSString*token=[NSString stringWithFormat:@"Quality%ld",(long)item.quality];NSAttributedString*q=Attachment([[EIDInlineAtlas shared]imageForToken:token],16.0,scale,-2.5);[out appendAttributedString:q?:QualityFallback(item.quality,titleFont,scale)];}headerEnd=out.length;NSArray*trans=[[EIDTransformData shared]transformationsForVariant:p.variant subtype:p.subtype];for(NSNumber*n in trans){NSInteger tid=n.integerValue;[out appendAttributedString:[[NSAttributedString alloc]initWithString:@"\n" attributes:Attrs(transformFont,UIColor.whiteColor,scale)]];NSAttributedString*ti=Attachment([[EIDTransformData shared]iconForID:tid],14.0,scale,-2.2);if(ti){[out appendAttributedString:ti];[out appendAttributedString:[[NSAttributedString alloc]initWithString:@"  " attributes:Attrs(transformFont,EIDTransformationColor(),scale)]];}[out appendAttributedString:[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"%@ (0/3)",[[EIDTransformData shared]nameForID:tid]] attributes:Attrs(transformFont,EIDTransformationColor(),scale)]];}if(sd)[out appendAttributedString:[[NSAttributedString alloc]initWithString:@"\n" attributes:Attrs(bodyFont,UIColor.whiteColor,scale)]];}if(sd)AppendMarkup(out,item.detail.length?item.detail:@"No description available",bodyFont,scale);NSMutableParagraphStyle*bodyPS=[NSMutableParagraphStyle new];bodyPS.minimumLineHeight=14*scale;bodyPS.maximumLineHeight=14*scale;[out addAttribute:NSParagraphStyleAttributeName value:bodyPS range:NSMakeRange(0,out.length)];if(headerEnd>0){NSMutableParagraphStyle*headerPS=[NSMutableParagraphStyle new];headerPS.minimumLineHeight=22*scale;headerPS.maximumLineHeight=22*scale;headerPS.paragraphSpacing=4.0*scale;NSUInteger headerRange=MIN(out.length,headerEnd+1);[out addAttribute:NSParagraphStyleAttributeName value:headerPS range:NSMakeRange(0,headerRange)];}iv.image=nil;iv.hidden=YES;l.attributedText=out;l.alpha=MIN(1,MAX(.15,alpha));iv.alpha=l.alpha;SEL size=NSSelectorFromString(@"sizePanelForText");if([self respondsToSelector:size])((void(*)(id,SEL))objc_msgSend)(self,size);[UIView animateWithDuration:.12 animations:^{panel.alpha=1;}];}
-(void)eid_parity_attachOverlayIfNeeded {
    [self eid_parity_attachOverlayIfNeeded];
    UIView *card = [self valueForKey:@"settingsCard"];
    UIView *root = [self valueForKey:@"rootView"];
    if (!card || !root || [card viewWithTag:0xE1D5]) return;

    CGFloat oldHeight = card.bounds.size.height;
    CGFloat height = MIN(430.0, MAX(oldHeight, root.bounds.size.height - 24.0));
    CGRect cardFrame = card.frame;
    cardFrame.origin.y -= (height - oldHeight) * 0.5;
    cardFrame.size.height = height;
    card.frame = cardFrame;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, 41, card.bounds.size.width, card.bounds.size.height - 49)];
    scroll.tag = 0xE1D4;
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = YES;

    UILabel *credits = nil;
    for (UIView *view in card.subviews.copy) {
        BOOL fixedTitle = [view isKindOfClass:UILabel.class] &&
            [((UILabel *)view).text isEqualToString:@"Isaac EID Settings"];
        BOOL fixedClose = [view isKindOfClass:UIButton.class] &&
            [[((UIButton *)view) titleForState:UIControlStateNormal] isEqualToString:@"×"];
        if (fixedTitle || fixedClose) continue;
        CGRect frame = view.frame;
        frame.origin.y -= 37.0;
        [view removeFromSuperview];
        view.frame = frame;
        [scroll addSubview:view];
        if ([view isKindOfClass:UILabel.class] &&
            [((UILabel *)view).text hasPrefix:@"Descriptions:"]) credits = (UILabel *)view;
    }
    [card addSubview:scroll];

    UIView *section = [[UIView alloc] initWithFrame:
        CGRectMake(18, 198, scroll.bounds.size.width - 36, 178)];
    section.tag = 0xE1D5;
    section.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [scroll addSubview:section];

    NSArray *titles = @[@"Name", @"Icon", @"Quality", @"Description"];
    NSArray *keys = @[EIDShowNameKey, EIDShowIconKey, EIDShowQualityKey, EIDShowDescriptionKey];
    CGFloat buttonWidth = floor((section.bounds.size.width - 12) / 4.0);
    for (NSUInteger index = 0; index < titles.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(index * (buttonWidth + 4), 0, buttonWidth, 28);
        button.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:.12];
        button.layer.cornerRadius = 6;
        [button setTitle:titles[index] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.accessibilityIdentifier = keys[index];
        [button addTarget:self action:@selector(eid_parity_toggle:)
         forControlEvents:UIControlEventTouchUpInside];
        [section addSubview:button];
    }

    NSArray *sliderKeys = @[EIDScaleKey, EIDTransparencyKey];
    for (NSUInteger index = 0; index < sliderKeys.count; index++) {
        NSString *key = sliderKeys[index];
        CGFloat labelY = index == 0 ? 36 : 94;
        UILabel *label = [[UILabel alloc] initWithFrame:
            CGRectMake(0, labelY, section.bounds.size.width, 20)];
        label.tag = index == 0 ? 0xE1D6 : 0xE1D7;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
        [section addSubview:label];

        UISlider *slider = [[UISlider alloc] initWithFrame:
            CGRectMake(0, labelY + 20, section.bounds.size.width, 32)];
        slider.minimumValue = index == 0 ? .5 : .15;
        slider.maximumValue = index == 0 ? 1.8 : 1.0;
        slider.value = [NSUserDefaults.standardUserDefaults objectForKey:key]
            ? [NSUserDefaults.standardUserDefaults doubleForKey:key] : (index == 0 ? 1.0 : .75);
        slider.accessibilityIdentifier = key;
        [slider addTarget:self action:@selector(eid_parity_slider:)
          forControlEvents:UIControlEventValueChanged];
        [section addSubview:slider];
    }

    UILabel *hint = [[UILabel alloc] initWithFrame:
        CGRectMake(0, 151, section.bounds.size.width, 20)];
    hint.text = @"EID layout · quality · transformations · inline icons";
    hint.textColor = [UIColor colorWithWhite:.72 alpha:1];
    hint.font = [UIFont systemFontOfSize:9.5];
    hint.textAlignment = NSTextAlignmentCenter;
    [section addSubview:hint];

    if (credits) {
        credits.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        credits.frame = CGRectMake(18, 389, scroll.bounds.size.width - 36, 54);
    }
    scroll.contentSize = CGSizeMake(scroll.bounds.size.width, 455);
    [self eid_parity_refreshButtons];
}
-(void)eid_parity_toggle:(UIButton*)b{NSString*k=b.accessibilityIdentifier;NSUserDefaults*d=NSUserDefaults.standardUserDefaults;BOOL on=[d objectForKey:k]?[d boolForKey:k]:YES;[d setBool:!on forKey:k];[self eid_parity_refreshButtons];NSArray*p=[self valueForKey:@"lastPickups"];if(p.count)[self eid_parity_renderPickups:p];}
-(void)eid_parity_slider:(UISlider*)s{[NSUserDefaults.standardUserDefaults setDouble:s.value forKey:s.accessibilityIdentifier];[self eid_parity_refreshButtons];NSArray*p=[self valueForKey:@"lastPickups"];if(p.count)[self eid_parity_renderPickups:p];}
-(void)eid_parity_refreshButtons{UIView*s=[[self valueForKey:@"settingsCard"]viewWithTag:0xE1D5];for(UIView*v in s.subviews)if([v isKindOfClass:UIButton.class]){UIButton*b=(UIButton*)v;NSString*k=b.accessibilityIdentifier;BOOL on=[NSUserDefaults.standardUserDefaults objectForKey:k]?[NSUserDefaults.standardUserDefaults boolForKey:k]:YES;NSString*base=[[b titleForState:UIControlStateNormal]stringByReplacingOccurrencesOfString:@"✓ " withString:@""];[b setTitle:on?[@"✓ " stringByAppendingString:base]:base forState:UIControlStateNormal];b.alpha=on?1:.5;}NSUserDefaults*d=NSUserDefaults.standardUserDefaults;CGFloat scale=[d objectForKey:EIDScaleKey]?[d doubleForKey:EIDScaleKey]:1.0,opacity=[d objectForKey:EIDTransparencyKey]?[d doubleForKey:EIDTransparencyKey]:.75;UILabel*scaleLabel=[s viewWithTag:0xE1D6],*opacityLabel=[s viewWithTag:0xE1D7];scaleLabel.text=[NSString stringWithFormat:@"Scale: %.0f%%",scale*100.0];opacityLabel.text=[NSString stringWithFormat:@"Opacity: %.0f%%",opacity*100.0];}
@end
