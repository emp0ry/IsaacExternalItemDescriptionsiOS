#pragma once
#include <math.h>
#include <stdbool.h>
#include <stddef.h>

// Standard Repentance order from upstream EID's dinfinityList. Selection zero
// is D Infinity's own description; selections 1–10 inspect its individual dice.
static const int EIDDInfinityDice[] = {476,284,105,609,437,406,285,386,166,283};
enum { EIDDInfinityPreviewCount = sizeof(EIDDInfinityDice)/sizeof(EIDDInfinityDice[0]) };

static inline int EIDDInfinityPreviewID(size_t selection) {
    return selection > 0 && selection <= EIDDInfinityPreviewCount
        ? EIDDInfinityDice[selection-1] : 489;
}

static inline size_t EIDNextDescriptionSelection(size_t selection, size_t count) {
    return count > 0 && count <= 32 && selection < count ? selection+1 : 0;
}

static inline bool EIDDescriptionBackgroundVisible(bool configured, bool inventoryPaused) {
    return configured || inventoryPaused;
}

static inline double EIDDescriptionBackgroundAlpha(double configured, bool inventoryPaused) {
    double value = isfinite(configured) ? fmin(1, fmax(0,configured)) : .28;
    return inventoryPaused ? fmax(.72,value) : value;
}

// The body width is its widest laid-out line, not the wrapping container's
// default width. Reserve the cycle counter in the title row only.
static inline double EIDDescriptionFittedWidth(double available, double title, double body,
    double textInset, double cycleInset, double scale) {
    if (!isfinite(available) || available <= 0 || !isfinite(title) || !isfinite(body) ||
        !isfinite(textInset) || !isfinite(cycleInset) || !isfinite(scale)) return 0;
    double content = fmax(fmax(0,title)+fmax(0,cycleInset), fmax(0,body));
    double width = ceil(fmax(0,textInset)+content+2*fmin(1.8,fmax(.5,scale)));
    return fmin(available,fmax(1,width));
}
