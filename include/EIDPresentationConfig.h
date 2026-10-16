#import <Foundation/Foundation.h>
#include <math.h>

static NSString *const EIDTextWidthKey = @"IsaacEIDTextWidthMultiplier";
static NSString *const EIDStatChangeIconsKey = @"IsaacEIDStatChangeIcons";

// Width is relative to the original language's default (130 pixels for RU/EN).
// Existing installations keep exactly their current wrapping until changed.
static inline double EIDTextWidthMultiplier(NSUserDefaults *defaults) {
    double value = [defaults objectForKey:EIDTextWidthKey] ? [defaults doubleForKey:EIDTextWidthKey] : 1;
    return isfinite(value) ? fmin(3, fmax(1, value)) : 1;
}
static inline BOOL EIDStatChangeIconsEnabled(NSUserDefaults *defaults) {
    return [defaults objectForKey:EIDStatChangeIconsKey] ? [defaults boolForKey:EIDStatChangeIconsKey] : YES;
}

// Match original replaceShortMarkupStrings + replaceMarkupSize. Do not remove
// ordinary damage/heart icons elsewhere (e.g. Book of Virtues wisp statistics).
static inline NSString *EIDFormatStatChangeIcons(NSString *text, BOOL enabled) {
    if (enabled || !text.length) return text ?: @"";
    text = [text stringByReplacingOccurrencesOfString:@"↑" withString:@"{{ArrowUp}}"];
    text = [text stringByReplacingOccurrencesOfString:@"↓" withString:@"{{ArrowDown}}"];
    static NSRegularExpression *expression;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        expression = [NSRegularExpression regularExpressionWithPattern:
            @"(\\{\\{Arrow(?:Up|Down)\\}\\}) \\{\\{[^{}]+\\}\\}" options:0 error:nil];
    });
    text = [expression stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0,text.length) withTemplate:@"$1 "];
    text = [text stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    return [text stringByReplacingOccurrencesOfString:@"# " withString:@"#"];
}
