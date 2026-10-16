#pragma once
#include <stdbool.h>
#include <stdint.h>

// Short native cycles (Binge Eater / Soul of Isaac) follow the currently
// displayed item. Crown's five-item inspection browser remains separate.
static inline bool EIDLivePedestalShouldTrack(int32_t alternateCount) {
    return alternateCount >= 1 && alternateCount <= 3;
}

static inline int32_t EIDLivePedestalSubtype(int32_t current, int32_t visibleFlip) {
    if (current >= 1 && current <= 732) return current;
    // A zero-subtype Flip ghost can describe its validated visible alternate,
    // matching the ordinary scanner. Invalid nonzero IDs never fall back.
    if (current == 0 && visibleFlip >= 1 && visibleFlip <= 732) return visibleFlip;
    return 0;
}
