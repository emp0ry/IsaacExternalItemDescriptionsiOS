#import "EIDOriginalScene.h"
#import <ImageIO/ImageIO.h>
#import <Foundation/Foundation.h>
#include <cassert>
#include <cmath>

@interface EIDOriginalScene (PresentationTests)
- (NSString *)expand:(NSString *)text;
- (NSArray *)colorFor:(NSString *)token base:(NSArray *)base frame:(NSUInteger)frame;
@end

int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc!=3) return 2;
        NSString *root=@(argv[1]),*output=@(argv[2]);
        NSData *metadata=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"original-renderer.json"]];
        NSDictionary *configuration=[NSJSONSerialization JSONObjectWithData:metadata options:0 error:nil];
        for (NSString *language in configuration[@"languages"]) {
            EIDOriginalScene *check=[[EIDOriginalScene alloc] initWithRoot:root language:language iconResolver:nil nameResolver:nil];
            if (!check) fprintf(stderr,"Font/layout unavailable for %s\n",language.UTF8String);
            assert(check && check.font);
            for (NSString *token in configuration[@"icons"]) {
                EIDOriginalSprite *sprite = [check sprite:token];
                if (!sprite) fprintf(stderr,"Missing atlas icon: %s\n",token.UTF8String);
                assert(sprite);
            }
            for (NSArray *pair in configuration[@"shortcuts"]) {
                NSString *expanded = [check expand:pair[0]];
                assert(![expanded isEqual:pair[0]]);
                if ([expanded hasPrefix:@"{{"] && [expanded hasSuffix:@"}}"] &&
                    configuration[@"icons"][[expanded substringWithRange:NSMakeRange(2,expanded.length-4)]])
                    assert([check sprite:[expanded substringWithRange:NSMakeRange(2,expanded.length-4)]]);
            }
            EIDOriginalSprite *diceFace=[check sprite:@"DiceFace5"];
            assert(CGImageGetWidth(diceFace.raster.image)==14 && CGImageGetHeight(diceFace.raster.image)==14);
            assert([[check expand:@"{{GoldHeart}} {{BombChest}} {{EternalChest}} {{Verwirrung}}"]
                isEqual:@"{{GoldenHeart}} {{StoneChest}} {{HolyChest}} {{Confusion}}"]);
            [check layoutName:@"" detail:@"{{Blank}} text" icon:nil itemType:0 chargeType:0 charges:0 quality:-1
                transformations:@[] showName:NO showQuality:NO showDetail:YES];
            assert(check.operationCount==1); // No default dot or phantom blank sprite.
            [check layoutName:@"" detail:@"{{BlinkYellowGreen}}{{Heart}} text" icon:nil itemType:0 chargeType:0 charges:0 quality:-1
                transformations:@[] showName:NO showQuality:NO showDetail:YES];
            assert(check.operationCount==2); // Heart bullet and text, not an extra dot.
            NSArray *white=@[@1,@1,@1,@1], *red=configuration[@"colors"][@"ColorRed"];
            NSArray *color=[check colorFor:@"ColorRed|ColorBlink" base:white frame:0];
            assert([[color subarrayWithRange:NSMakeRange(0,3)] isEqual:[red subarrayWithRange:NSMakeRange(0,3)]]);
            assert([[check colorFor:@"ColorRed|ColorBlink" base:white frame:20][3] doubleValue]==0);
            assert([[check colorFor:@"ColorRed|ColorFade" base:white frame:15][3] doubleValue]==[red[3] doubleValue]);
            assert([[check colorFor:@"ColorRed|ColorFade" base:white frame:35][3] doubleValue]==0);
            NSArray *normal=[check wrappedLines:@"Longer descriptions should have fewer lines when width increases without changing font size or spacing."];
            check.widthMultiplier=.5;
            assert([[check wrappedLines:@"Longer descriptions should have fewer lines when width increases without changing font size or spacing."] isEqual:normal]);
            check.widthMultiplier=3;
            assert([[check wrappedLines:@"Longer descriptions should have fewer lines when width increases without changing font size or spacing."] count] <= normal.count);
            check.widthMultiplier=1;
            assert([[check wrappedLines:@"{{NoLB}}A → B → C"] count]==1);
            EIDOriginalSprite *heart=[check sprite:@"SoulHeart"]; assert(heart && heart.advance==10 && heart.offsetX==1 && heart.offsetY==1);
            EIDOriginalSprite *charge=[check animation:@"active" sheet:@"transform" frame:0];
            assert(charge && charge.rect.origin.x==-8 && charge.rect.origin.y==-8);
            EIDOriginalSprite *card=[check sprite:@"Card1"],*pill=[check sprite:@"Pill1"];
            assert(card && card.advance==8 && card.rect.size.width==8 && card.rect.size.height==10);
            assert(pill && pill.advance==9 && pill.rect.size.width==9 && pill.rect.size.height==9);
            assert(![check sprite:@"Card0"] && ![check sprite:@"Card98"] && ![check sprite:@"Pill0"]);
            check.unidentifiedPill=YES;
            [check layoutName:@"Unidentified Pill" detail:@"?" icon:pill itemType:0 chargeType:0 charges:0 quality:-1
                transformations:@[] showName:YES showQuality:YES showDetail:YES];
            assert(check.operationCount==3); // Pill, SecretRoom '?', red title; no body.
            NSArray *unknownOps=[check valueForKey:@"ops"];
            NSArray *errorColor=@[@1,@.4,@.4,@1];
            assert([[unknownOps.lastObject valueForKey:@"baseColor"] isEqual:errorColor]);
            check.unidentifiedPill=NO;
            [check layoutName:@"Collectible" detail:@"{{ArrowUp}} {{Damage}} +1 Damage#{{Indent}}{{SoulHeart}} +1 Soul Heart"
                icon:nil itemType:0 chargeType:0 charges:0 quality:4 transformations:@[] showName:YES showQuality:YES showDetail:YES];
            assert(std::isfinite(check.bounds.size.width) && check.bounds.size.width<4096);
            [check layoutName:@"Original EID" detail:[@"No character-count cutoff. " stringByPaddingToLength:300 withString:@"More text. " startingAtIndex:0]
                icon:nil itemType:0 chargeType:0 charges:0 quality:-1 transformations:@[] showName:YES showQuality:YES showDetail:YES];
            assert(check.operationCount>3 && check.bounds.size.height>30);
        }
        // Exercise every bundled pickup description, not just plain-text samples.
        // Icon-led bullets exposed unsigned-coordinate overflow on real pedestals.
        NSData *databaseBytes=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"descriptions.json"]];
        NSDictionary *database=[NSJSONSerialization JSONObjectWithData:databaseBytes options:0 error:nil];
        NSUInteger checked=0;
        for (NSString *language in database[@"languages"]) {
            @autoreleasepool {
                EIDOriginalScene *scene=[[EIDOriginalScene alloc] initWithRoot:root language:language iconResolver:nil nameResolver:nil];
                assert(scene);
                NSDictionary *pack=database[@"languages"][language];
                for (NSString *kind in @[@"collectibles",@"trinkets",@"cards",@"pills",@"horsepills",@"dice",@"sacrifice",@"sanguine"]) {
                    NSDictionary *entries=pack[kind];
                    for (NSString *identifier in entries) {
                        @autoreleasepool {
                            NSDictionary *entry=entries[identifier];
                            if (![entry isKindOfClass:NSDictionary.class]) continue;
                            BOOL collectible=[kind isEqual:@"collectibles"];
                            [scene layoutName:entry[@"name"] ?: @"EID" detail:entry[@"description"] ?: @"" icon:[scene sprite:@"Collectible"]
                                itemType:collectible?2:0 chargeType:0 charges:6 quality:collectible?4:-1 transformations:@[]
                                showName:YES showQuality:YES showDetail:YES];
                            CGRect bounds=scene.bounds;
                            if (!std::isfinite(bounds.size.width) || bounds.size.width>8192 || bounds.size.height>32768)
                                fprintf(stderr,"Invalid layout %s/%s/%s\n",language.UTF8String,kind.UTF8String,identifier.UTF8String);
                            assert(std::isfinite(bounds.size.width) && bounds.size.width>0 && bounds.size.width<=8192 && bounds.size.height>0 && bounds.size.height<=32768);
                            ++checked;
                        }
                    }
                }
            }
        }
        printf("Validated %lu bundled description layouts across all languages\n",(unsigned long)checked);
        NSUInteger modularCount=0;
        for (NSString *language in database[@"languages"]) {
            EIDOriginalScene *scene=[[EIDOriginalScene alloc] initWithRoot:root language:language iconResolver:nil nameResolver:nil];
            NSDictionary *entries=database[@"languages"][language][@"modular_descriptions"];
            for (NSString *key in entries) for (NSString *heart in entries[key]) {
                @autoreleasepool {
                    [scene layoutName:@"Modular EID" detail:entries[key][heart] icon:nil itemType:0 chargeType:0 charges:0 quality:-1
                        transformations:@[] showName:YES showQuality:NO showDetail:YES];
                    assert(std::isfinite(scene.bounds.size.width) && scene.bounds.size.width<=8192 && scene.bounds.size.height<=32768);
                    ++modularCount;
                }
            }
        }
        printf("Validated %lu modular character-health layouts across all languages\n",(unsigned long)modularCount);
        NSArray *examples=@[
            @{@"language":@"en_us",@"name":@"Brimstone",@"detail":@"↓ {{Tears}} x0.33 Fire rate multiplier#Isaac's tears are replaced by a chargeable blood beam#It deals 9x Isaac's damage over 0.63 seconds",@"transform":@"Leviathan (1/3)",@"id":@9},
            @{@"language":@"ru",@"name":@"Книга Откровений",@"detail":@"{{SoulHeart}} +1 синее сердце#{{ArrowUp}} {{Damage}} +2.5 к урону | {{Luck}} +1 к удаче#Русское описание использует исходные буквы и метрики EID.",@"type":@2,@"charges":@6},
            @{@"language":@"ru",@"name":@"Ящик Пандоры",@"detail":@"Создаёт награды в зависимости от этажа:#{{ColorLime}}П1: 2{{SoulHeart}}#П2: 2{{Bomb}} + 2{{Key}}#К1: Предмет из комнаты босса#М2: {{Collectible33}} Библия"},
            @{@"language":@"en_us",@"name":@"Spindown Dice",@"detail":@"Rerolls pedestal items by decreasing their item ID#{{NoLB}}{{Quality2}} Blood Bag → {{Quality4}} Brimstone → {{Quality1}} Dead Bird",@"type":@2,@"charges":@6}
        ];
        size_t width=1024,height=700; std::vector<uint8_t> pixels(width*height*4);
        CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
        CGContextRef context=CGBitmapContextCreate(pixels.data(),width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextSetRGBFillColor(context,.12,.10,.09,1); CGContextFillRect(context,CGRectMake(0,0,width,height));
        CGContextTranslateCTM(context,0,height); CGContextScaleCTM(context,1,-1);
        NSUInteger index=0;
        for (NSDictionary *example in examples) {
            EIDOriginalScene *scene=[[EIDOriginalScene alloc] initWithRoot:root language:example[@"language"] iconResolver:nil nameResolver:nil];
            assert(scene && scene.font);
            const auto &metrics=[scene.font metrics];
            assert(metrics.glyphs.count(65) && metrics.glyphs.count(1040) && metrics.glyphs.count(1072));
            assert(metrics.Measure("A")==5 && metrics.Measure("¤")==1);
            assert([scene.font width:@"Тест"]>0);
            NSArray *transform=example[@"transform"]?@[@{@"id":example[@"id"],@"text":example[@"transform"]}]:@[];
            [scene layoutName:example[@"name"] detail:example[@"detail"] icon:[scene sprite:@"Collectible"]
                itemType:[example[@"type"] integerValue] chargeType:0 charges:[example[@"charges"] integerValue]
                quality:4 transformations:transform showName:YES showQuality:YES showDetail:YES];
            assert(scene.operationCount && !CGRectIsEmpty(scene.bounds));
            CGContextSaveGState(context); CGContextTranslateCTM(context,32+(index%2)*500,40+(index/2)*330);
            CGContextScaleCTM(context,2,2); [scene drawInContext:context frame:0]; CGContextRestoreGState(context);
            ++index;
        }
        CGImageRef image=CGBitmapContextCreateImage(context);
        CGImageDestinationRef destination=CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:output],CFSTR("public.png"),1,nullptr);
        assert(destination); CGImageDestinationAddImage(destination,image,nullptr); assert(CGImageDestinationFinalize(destination));
        CFRelease(destination); CGImageRelease(image); CGContextRelease(context);
        puts("Original renderer: actual English/Russian atlas glyphs, colors, charge offsets and layout previews passed");
    }
}
