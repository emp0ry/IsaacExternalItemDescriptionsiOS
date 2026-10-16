#import "EIDOriginalScene.h"
#import "EIDPresentationConfig.h"
#include <cmath>
#include <vector>

static CGImageRef FrameImage(CGImageRef atlas, CGRect crop) {
    if (!atlas || crop.size.width<=0 || crop.size.height<=0 || crop.size.width>4096 || crop.size.height>4096) return nullptr;
    CGRect bounds=CGRectMake(0,0,CGImageGetWidth(atlas),CGImageGetHeight(atlas));
    if (CGRectContainsRect(bounds,crop)) return CGImageCreateWithImageInRect(atlas,crop);
    // Upstream's DiceFaces frames extend one pixel past its PNG. Isaac clips
    // that part; retain the ANM2 geometry and pad the missing edge transparently
    // rather than dropping the icon or stretching its remaining pixels.
    CGRect clipped=CGRectIntersection(bounds,crop);
    if (CGRectIsNull(clipped) || CGRectIsEmpty(clipped)) return nullptr;
    size_t width=(size_t)ceil(crop.size.width),height=(size_t)ceil(crop.size.height);
    std::vector<uint8_t> pixels(width*height*4);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.data(),width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return nullptr;
    CGImageRef part=CGImageCreateWithImageInRect(atlas,clipped);
    CGContextSetInterpolationQuality(context,kCGInterpolationNone);
    if (part) CGContextDrawImage(context,CGRectMake(clipped.origin.x-crop.origin.x,
        height-(clipped.origin.y-crop.origin.y+clipped.size.height),clipped.size.width,clipped.size.height),part);
    CGImageRef image=part?CGBitmapContextCreateImage(context):nullptr;
    if (part) CGImageRelease(part);
    CGContextRelease(context); return image;
}

@implementation EIDOriginalSprite
@end

@interface EIDOriginalOp : NSObject
@property(nonatomic,copy) NSString *text,*colorToken;
@property(nonatomic,strong) EIDOriginalSprite *sprite;
@property(nonatomic) CGPoint position;
@property(nonatomic,strong) NSArray<NSNumber *> *baseColor;
@end
@implementation EIDOriginalOp
@end

static NSString *Shortcut(NSString *text) {
    for (NSArray *pair in @[@[@"!!!",@"{{Warning}}"],@[@"↑",@"{{ArrowUp}}"],@[@"↓",@"{{ArrowDown}}"],
        @[@"\r\n",@"#"],@[@"\n",@"#"],@[@"\r",@"#"],@[@"\t",@""],@[@"{{CR}}",@"{{ColorReset}}"],
        @[@"{{IND}}",@"{{Indent}}"],@[@"{{Hashtag}}",@"ǂ"],@[@"{{EthernalHeart}}",@"{{EternalHeart}}"]])
        text=[text stringByReplacingOccurrencesOfString:pair[0] withString:pair[1]];
    return text;
}

@implementation EIDOriginalScene {
    EIDBitmapFont *_font;
    NSDictionary *_metadata;
    NSString *_language;
    CGFloat _lineHeight,_width;
    EIDOriginalIconResolver _icons;
    EIDOriginalNameResolver _names;
    NSMutableArray<EIDOriginalOp *> *_ops;
    NSMutableDictionary<NSString *,EIDRaster *> *_sheets;
    NSCache<NSString *,EIDOriginalSprite *> *_sprites;
    NSString *_root;
    CGRect _bounds;
    BOOL _animated;
    NSString *_resetToken;
}
- (instancetype)initWithRoot:(NSString *)root language:(NSString *)language iconResolver:(EIDOriginalIconResolver)icons nameResolver:(EIDOriginalNameResolver)names {
    if (!(self=[super init])) return nil;
    NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"original-renderer.json"]];
    _metadata=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    if (![_metadata isKindOfClass:NSDictionary.class]) return nil;
    _root=root; _language=language; _icons=[icons copy]; _names=[names copy];
    _widthMultiplier=1;
    _statChangeIcons=YES;
    NSDictionary *languageFont=_metadata[@"languages"][language] ?: _metadata[@"languages"][@"en_us"];
    _lineHeight=[languageFont[@"line_height"] doubleValue]; _width=[languageFont[@"width"] doubleValue];
    _font=[[EIDBitmapFont alloc] initWithPath:[root stringByAppendingPathComponent:
        [NSString stringWithFormat:@"fonts/eid_%@.fnt",languageFont[@"font"] ?: @"default"]]];
    if (!_font || _width<1 || _lineHeight<1) return nil;
    _ops=[NSMutableArray array]; _sheets=[NSMutableDictionary dictionary]; _sprites=[NSCache new]; _sprites.countLimit=512;
    return self;
}
- (EIDBitmapFont *)font { return _font; }
- (CGRect)bounds { return CGRectIsNull(_bounds)?CGRectZero:_bounds; }
- (NSUInteger)operationCount { return _ops.count; }
- (BOOL)animated { return _animated; }
- (CGFloat)defaultTextWidth { return _width; }
- (EIDOriginalSprite *)animation:(NSString *)animation sheet:(NSString *)sheet frame:(NSInteger)frame {
    if (frame<0) frame=0;
    NSString *key=[NSString stringWithFormat:@"%@:%@:%ld",sheet,animation,(long)frame];
    EIDOriginalSprite *cached=[_sprites objectForKey:key]; if (cached) return cached;
    NSDictionary *definition=_metadata[@"animations"][sheet];
    NSArray *frames=definition[@"definitions"][animation][@"layers"][@"0"];
    if ((NSUInteger)frame>=frames.count) return nil;
    NSDictionary *f=frames[frame];
    if ([f[@"Visible"] isEqual:@"false"]) return nil;
    EIDRaster *atlas=_sheets[sheet];
    if (!atlas) { atlas=[EIDRaster load:[_root stringByAppendingPathComponent:definition[@"file"]]]; if (atlas) _sheets[sheet]=atlas; }
    CGFloat w=[f[@"Width"] doubleValue],h=[f[@"Height"] doubleValue];
    CGRect crop=CGRectMake([f[@"XCrop"] doubleValue],[f[@"YCrop"] doubleValue],w,h);
    CGImageRef image=FrameImage(atlas.image,crop);
    if (!image) return nil;
    EIDOriginalSprite *sprite=[EIDOriginalSprite new]; sprite.raster=[[EIDRaster alloc] initWithImage:image]; CGImageRelease(image);
    CGFloat sx=[f[@"XScale"] doubleValue]/100.,sy=[f[@"YScale"] doubleValue]/100.;
    sprite.rect=CGRectMake([f[@"XPosition"] doubleValue]-[f[@"XPivot"] doubleValue]*sx,
        [f[@"YPosition"] doubleValue]-[f[@"YPivot"] doubleValue]*sy,w*sx,h*sy);
    sprite.advance=w*sx; sprite.height=h*sy; [_sprites setObject:sprite forKey:key]; return sprite;
}
- (EIDOriginalSprite *)sprite:(NSString *)token {
    NSDictionary *meta=_metadata[@"icons"][token];
    if (meta) {
        if ([meta[@"width"] doubleValue]==0 && [meta[@"height"] doubleValue]==0)
            return [EIDOriginalSprite new]; // Original Blank: no bullet, zero advance.
        EIDOriginalSprite *source=[self animation:meta[@"animation"] sheet:meta[@"sheet"] ?: @"inline" frame:[meta[@"frame"] integerValue]];
        if (!source) return nil;
        EIDOriginalSprite *sprite=[EIDOriginalSprite new]; sprite.raster=source.raster; sprite.rect=source.rect;
        sprite.advance=meta[@"width"]?[meta[@"width"] doubleValue]:source.advance;
        sprite.height=meta[@"height"]?[meta[@"height"] doubleValue]:source.height;
        sprite.offsetX=meta[@"x"]?[meta[@"x"] doubleValue]:-1; sprite.offsetY=[meta[@"y"] doubleValue]; return sprite;
    }
    NSRegularExpression *pocket=[NSRegularExpression regularExpressionWithPattern:@"^(Card|Pill)([0-9]+)$" options:0 error:nil];
    NSTextCheckingResult *match=[pocket firstMatchInString:token options:0 range:NSMakeRange(0,token.length)];
    if (match) {
        BOOL pill=[[token substringWithRange:[match rangeAtIndex:1]] isEqual:@"Pill"];
        NSInteger subtype=[[token substringWithRange:[match rangeAtIndex:2]] integerValue];
        if (pill) subtype%=2048;
        EIDOriginalSprite *source=[self animation:pill?@"Pills":@"Cards" sheet:@"pocket" frame:subtype-1];
        if (subtype<1 || subtype>(pill?14:97) || !source) return nil;
        EIDOriginalSprite *sprite=[EIDOriginalSprite new]; sprite.raster=source.raster; sprite.rect=source.rect;
        sprite.advance=pill?9:8; sprite.height=8; sprite.offsetX=0; sprite.offsetY=1; return sprite;
    }
    return _icons?_icons(token):nil;
}
- (BOOL)isColor:(NSString *)token {
    return _metadata[@"colors"][token] || [token hasPrefix:@"Color"] || [token hasPrefix:@"Blink"];
}
- (NSString *)expand:(NSString *)text {
    text=text ?: @"";
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"\\{\\{(Name[^}]+)\\}\\}" options:0 error:nil];
    NSMutableString *expanded=text.mutableCopy;
    for (NSTextCheckingResult *m in [[regex matchesInString:text options:0 range:NSMakeRange(0,text.length)] reverseObjectEnumerator]) {
        NSString *token=[text substringWithRange:[m rangeAtIndex:1]],*value=_names?_names(token):nil;
        if (value) [expanded replaceCharactersInRange:m.range withString:value];
    }
    NSArray *shortcuts=_metadata[@"shortcuts"];
    if ([shortcuts isKindOfClass:NSArray.class]) {
        for (NSArray *pair in shortcuts)
            if ([pair isKindOfClass:NSArray.class] && pair.count==2 && [pair[0] length])
                [expanded replaceOccurrencesOfString:pair[0] withString:pair[1] options:0 range:NSMakeRange(0,expanded.length)];
        return expanded;
    }
    return Shortcut(expanded); // Compatibility with an older resource bundle.
}
- (EIDBitmap::MeasuredWord)measureWord:(NSString *)word first:(BOOL)first {
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^}]+)\\}\\}" options:0 error:nil];
    NSArray *matches=[regex matchesInString:word options:0 range:NSMakeRange(0,word.length)];
    NSMutableString *plain=word.mutableCopy; NSInteger icons=0;
    for (NSTextCheckingResult *m in [matches reverseObjectEnumerator]) {
        EIDOriginalSprite *sprite=[self sprite:[word substringWithRange:[m rangeAtIndex:1]]];
        NSString *spacer=sprite?[@"¤" stringByPaddingToLength:(NSUInteger)sprite.advance withString:@"¤" startingAtIndex:0]:@"";
        if (sprite) ++icons;
        [plain replaceCharactersInRange:m.range withString:spacer];
    }
    NSMutableString *remainder=word.mutableCopy;
    for (NSTextCheckingResult *m in [matches reverseObjectEnumerator]) [remainder deleteCharactersInRange:m.range];
    BOOL iconOnly=icons && [remainder stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length==0;
    return {(int)((first && iconOnly)?0:[_font width:plain]),iconOnly && icons==1};
}
- (NSArray<NSString *> *)wrappedLines:(NSString *)text {
    std::string utf8=text.UTF8String ?: "";
    CGFloat multiplier=std::isfinite(self.widthMultiplier)?MIN(3,MAX(1,self.widthMultiplier)):1;
    auto lines=EIDBitmap::Wrap(utf8,(int)round(_width*multiplier),[_language isEqual:@"zh_cn"],[&](const std::string &word,bool first) {
        NSString *s=[[NSString alloc] initWithBytes:word.data() length:word.size() encoding:NSUTF8StringEncoding];
        return [self measureWord:s ?: @"" first:first];
    });
    NSMutableArray *result=[NSMutableArray array];
    for (const auto &line:lines) [result addObject:[[NSString alloc] initWithBytes:line.data() length:line.size() encoding:NSUTF8StringEncoding] ?: @""];
    return result;
}
- (void)addSprite:(EIDOriginalSprite *)sprite at:(CGPoint)at bullet:(BOOL)bullet {
    if (!sprite || !sprite.raster) return;
    EIDOriginalOp *op=[EIDOriginalOp new]; op.sprite=sprite;
    if (bullet && sprite.advance<11 && sprite.offsetX<=0) at.x+=floor((12-sprite.advance)/2);
    op.position=CGPointMake(at.x+sprite.offsetX,at.y+sprite.offsetY); [_ops addObject:op];
    CGRect rect=CGRectOffset(sprite.rect,op.position.x,op.position.y); _bounds=CGRectUnion(_bounds,rect);
}
- (NSString *)addString:(NSString *)text at:(CGPoint)at base:(NSArray *)base token:(NSString *)initial bullet:(BOOL)bullet {
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^}]+)\\}\\}" options:0 error:nil];
    NSArray *matches=[regex matchesInString:text options:0 range:NSMakeRange(0,text.length)];
    NSUInteger cursor=0; CGFloat x=at.x; NSString *colorToken=initial;
    for (NSUInteger n=0;n<=matches.count;++n) {
        NSTextCheckingResult *m=n<matches.count?matches[n]:nil;
        NSUInteger end=m?m.range.location:text.length;
        if (end>cursor) {
            NSString *part=[text substringWithRange:NSMakeRange(cursor,end-cursor)];
            EIDOriginalOp *op=[EIDOriginalOp new]; op.text=part; op.baseColor=base; op.colorToken=colorToken; op.position=CGPointMake(x,at.y);
            [_ops addObject:op]; CGFloat width=[_font width:part];
            _bounds=CGRectUnion(_bounds,CGRectMake(x-2,at.y-2,MAX(1,width+4),_font.lineHeight+4)); x+=width;
        }
        if (!m) break;
        NSString *token=[text substringWithRange:[m rangeAtIndex:1]];
        if ([self isColor:token]) {
            if ([token isEqual:@"ColorReset"]) colorToken=_resetToken;
            else if ([token isEqual:@"ColorText"]) colorToken=@"ColorEIDText";
            else if ([token isEqual:@"ColorObjName"]) colorToken=@"ColorEIDObjName";
            else if ([token isEqual:@"ColorTransform"]) colorToken=@"ColorEIDTransform";
            else if ([token isEqual:@"ColorError"]) colorToken=@"ColorEIDError";
            else if ([token isEqual:@"ColorBlink"] || [token isEqual:@"ColorFade"])
                colorToken=colorToken.length ? [colorToken stringByAppendingFormat:@"|%@",token] : token;
            else colorToken=token;
            if ([token hasPrefix:@"Blink"] || [@[@"ColorGold",@"ColorShinyPurple",@"ColorRainbow",@"ColorBlink",@"ColorFade"] containsObject:token]) _animated=YES;
        } else {
            EIDOriginalSprite *sprite=[self sprite:token]; [self addSprite:sprite at:CGPointMake(x,at.y) bullet:bullet]; x+=sprite.advance;
        }
        cursor=NSMaxRange(m.range);
    }
    return colorToken;
}
- (void)layoutName:(NSString *)name detail:(NSString *)detail icon:(EIDOriginalSprite *)icon itemType:(NSInteger)itemType chargeType:(NSInteger)chargeType charges:(NSInteger)charges quality:(NSInteger)quality transformations:(NSArray<NSDictionary *> *)transformations showName:(BOOL)showName showQuality:(BOOL)showQuality showDetail:(BOOL)showDetail {
    [_ops removeAllObjects]; _bounds=CGRectNull; _animated=NO; _resetToken=nil;
    NSArray *white=@[@1,@1,@1,@1],*purple=@[@.8,@.3,@.8,@1],*blue=@[@.5,@.5,@1,@1];
    CGFloat y=0,x=0;
    if (icon) { [self addSprite:icon at:CGPointMake(-3,-4) bullet:NO]; x+=14; }
    // main.lua:renderUnidentifiedPill is a separate path, not an ordinary
    // purple item name followed by a literal '?' description.
    if (self.unidentifiedPill) {
        if (icon) [self addSprite:[self sprite:@"SecretRoom"] at:CGPointMake(1,-4) bullet:NO];
        [self addString:name at:CGPointMake(x,-3) base:@[@1,@.4,@.4,@1] token:nil bullet:NO];
        if (!CGRectIsNull(_bounds)) _bounds=CGRectIntegral(_bounds);
        return;
    }
    if (itemType==2 || itemType==3) {
        EIDOriginalSprite *type=[self animation:itemType==2?@"active":@"familiar" sheet:@"transform" frame:0];
        [self addSprite:type at:CGPointMake(x,2) bullet:NO];
        if (itemType==2) {
            x+=1;
            EIDOriginalSprite *charge=[self animation:chargeType==1?@"Misc":@"numbers" sheet:@"inline" frame:chargeType==1?6:chargeType==2?13:charges];
            [self addSprite:charge at:CGPointMake(x,2) bullet:NO];
        }
        x+=8;
    }
    NSString *title=showName?[self expand:name]:@"";
    if (showQuality && quality>=0 && quality<=4) title=[title stringByAppendingFormat:@" - {{Quality%ld}}",(long)quality];
    [self addString:title at:CGPointMake(x,-3) base:purple token:nil bullet:NO]; y+=_lineHeight;
    for (NSDictionary *transform in transformations) {
        EIDOriginalSprite *sprite=[self animation:[NSString stringWithFormat:@"Transformation%@",transform[@"id"]] sheet:@"transform" frame:0];
        sprite.advance=16; sprite.height=16; sprite.offsetY=-1;
        [self addSprite:sprite at:CGPointMake(0,y) bullet:NO];
        [self addString:transform[@"text"] at:CGPointMake(sprite.advance+4,y+MIN(0,(sprite.height-9))/4) base:blue token:nil bullet:NO];
        y+=MAX(_lineHeight,sprite.height);
    }
    if (showDetail) for (NSString *paragraph in [EIDFormatStatChangeIcons([self expand:detail],self.statChangeIcons) componentsSeparatedByString:@"#"]) {
        if (!paragraph.length) continue;
        NSMutableString *line=paragraph.mutableCopy; NSUInteger indent=0;
        NSRange tag=[line rangeOfString:@"{{Indent}}"];
        while (tag.location!=NSNotFound) { [line deleteCharactersInRange:tag]; ++indent; tag=[line rangeOfString:@"{{Indent}}"]; }
        NSArray *lines=[self wrappedLines:line]; NSString *token=nil; _resetToken=nil;
        // indent is an unsigned count. Keep positions signed before subtracting
        // the original 3-pixel bullet offset (Lua numbers were signed).
        CGFloat indentX=12.0*(CGFloat)indent;
        for (NSUInteger i=0;i<lines.count;++i) {
            NSString *body=lines[i];
            if (i==0) {
                NSRegularExpression *start=[NSRegularExpression regularExpressionWithPattern:@"^(?:(\\{\\{(?:Color|Blink)[^}]+\\}\\}))*?(\\{\\{([^}]+)\\}\\}) " options:0 error:nil];
                NSTextCheckingResult *match=[start firstMatchInString:body options:0 range:NSMakeRange(0,body.length)];
                EIDOriginalSprite *bullet=match?[self sprite:[body substringWithRange:[match rangeAtIndex:3]]]:nil;
                if (bullet) {
                    NSRange iconRange=[match rangeAtIndex:2];
                    NSString *markup=[body substringToIndex:NSMaxRange(iconRange)];
                    token=[self addString:markup at:CGPointMake(-3.0+indentX,y) base:white token:nil bullet:YES];
                    _resetToken=token;
                    body=[body stringByReplacingCharactersInRange:NSMakeRange(0,NSMaxRange(iconRange)) withString:@""];
                } else [self addString:@"\007" at:CGPointMake(indentX,y) base:white token:nil bullet:NO];
            }
            body=[body stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            token=[self addString:body at:CGPointMake(12.0+indentX,y) base:white token:token bullet:NO]; y+=_lineHeight;
        }
    }
    if (!CGRectIsNull(_bounds)) _bounds=CGRectIntegral(_bounds);
}
- (NSArray *)colorFor:(NSString *)token base:(NSArray *)base frame:(NSUInteger)frame {
    if (!token.length) return base;
    if ([token containsString:@"|"]) {
        NSArray *color=base;
        for (NSString *part in [token componentsSeparatedByString:@"|"]) color=[self colorFor:part base:color frame:frame];
        return color;
    }
    if ([token isEqual:@"ColorBlink"]) return @[base[0],base[1],base[2],@([base[3] doubleValue]*(frame%40<20?1:0))];
    if ([token isEqual:@"ColorFade"]) {
        CGFloat time=frame%40,alpha=time<15?time/15:time<30?1-(time-15)/15:0;
        return @[base[0],base[1],base[2],@([base[3] doubleValue]*alpha)];
    }
    NSArray *fixed=_metadata[@"colors"][token]; if (fixed.count==4) return fixed;
    NSDictionary *palettes=@{@"ColorGold":@[@[@1,@1,@0,@1],@[@1,@.54,@0,@1]],
        @"BlinkYellowGreen":@[@[@1,@1,@0,@1],@[@0,@1,@0,@1]],@"BlinkYellowRed":@[@[@1,@1,@0,@1],@[@1,@0,@0,@1]],
        @"BlinkGray":@[@[@.5,@.5,@.5,@1],@[@.75,@.75,@.75,@1]],
        @"BlinkBirthright":@[@[@.831,@.725,@.604,@1],@[@.671,@.557,@.443,@1]],
        @"ColorShinyPurple":@[@[@.812,@.627,@1,@1],@[@.62,@.251,@1,@1]],
        @"BlinkBlue":@[@[@.341,@.529,@.906,@1],@[@.592,@.717,@.937,@1]],
        @"BlinkPink":@[@[@1,@.698,@.886,@1],@[@1,@.5,@1,@1]],
        @"BlinkGreen":@[@[@.404,@.663,@.306,@1],@[@.443,@.765,@.247,@1]],
        @"ColorRainbow":@[@[@1,@0,@0,@1],@[@1,@1,@0,@1],@[@0,@1,@0,@1],@[@0,@1,@1,@1],@[@0,@0,@1,@1],@[@1,@0,@1,@1]]};
    NSArray *palette=palettes[token]; if (!palette) return base;
    CGFloat duration=[token isEqual:@"ColorShinyPurple"]?40:80;
    CGFloat fractions=(duration-1)/palette.count,period=fractions+1,time=fmod(frame,duration);
    NSUInteger index=(NSUInteger)floor(time/period)%palette.count; CGFloat blend=fmod(time,period)/fractions;
    NSArray *a=palette[index],*b=palette[(index+1)%palette.count]; NSMutableArray *color=[NSMutableArray array];
    for (NSUInteger i=0;i<4;++i) [color addObject:@([a[i] doubleValue]+([b[i] doubleValue]-[a[i] doubleValue])*blend)];
    return color;
}
- (void)drawInContext:(CGContextRef)context frame:(NSUInteger)frame {
    for (EIDOriginalOp *op in _ops) {
        if (op.sprite) EIDDrawRaster(context,op.sprite.raster.image,CGRectOffset(op.sprite.rect,op.position.x,op.position.y));
        else {
            NSArray *color=[self colorFor:op.colorToken base:op.baseColor frame:frame];
            CGFloat values[]={[color[0] doubleValue],[color[1] doubleValue],[color[2] doubleValue],[color[3] doubleValue]};
            CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB(); CGColorRef cg=CGColorCreate(space,values); CGColorSpaceRelease(space);
            [_font draw:op.text at:op.position color:cg context:context]; CGColorRelease(cg);
        }
    }
}
@end
