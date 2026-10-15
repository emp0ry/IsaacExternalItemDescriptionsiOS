#pragma once

// Shared by the main-thread native snapshot and pure description renderer.
// -1 means unavailable; zero is a verified absence, never a missing value.
enum {
    EIDPillModifierPHD = 1 << 0,
    EIDPillModifierFalsePHD = 1 << 1,
    EIDPillModifierVirgo = 1 << 2,
    EIDPillModifierLuckyFoot = 1 << 3,
    EIDPillModifierAll = 15
};

static inline int EIDPillModifiersIdentify(int modifiers) {
    return modifiers >= 0 && modifiers <= EIDPillModifierAll &&
        (modifiers & (EIDPillModifierPHD | EIDPillModifierFalsePHD)) != 0;
}
