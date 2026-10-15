#pragma once
#include <cstdint>

// The supported native Repentance build stores these values in PlayerData.
// Reading them avoids inferring use from dropping, buying or swapping pockets.
namespace EIDRepeatPolicy {
constexpr int32_t Horse = 0x800;
constexpr int32_t ColorMask = 0x7ff;
constexpr int32_t VurpEffect = 46;

inline bool PillColor(int32_t color, bool allowGold = false) {
    return color > 0 && !(color & ~(Horse | ColorMask)) &&
        (color & ColorMask) >= 1 && (color & ColorMask) <= (allowGold ? 14 : 13);
}

inline bool WildCard(uint8_t type, int32_t id, int32_t extra) {
    switch (type) {
        case 0: return id >= 0 && id <= 49 && PillColor(extra,true);
        case 1: return id >= 1 && id <= 97 && id != 80;
        case 2: return id >= 1 && id <= 732;
        default: return false; // 0xff is the native empty sentinel.
    }
}

inline int32_t VurpColor(int32_t previous, int32_t current) {
    // Native Vurp uses the last non-golden color, falling back to itself.
    // Its horse bit is ORed with the stored color, not substituted for it.
    if (!PillColor(current) || (previous != 0 && !PillColor(previous))) return 0;
    return (previous ? previous : current) | (current & Horse);
}
}
