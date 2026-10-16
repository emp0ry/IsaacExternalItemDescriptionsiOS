#pragma once
#include <cstddef>
#include <cstdint>

namespace EIDInventoryCountPolicy {
// Native active slots can represent copies already present in the raw table.
// Merge overlapping sources, never sum them or include temporary/Void effects.
inline int32_t PhysicalCopies(int32_t rawCount, size_t activeSlots) {
    if (rawCount < 0 || rawCount > 999 || activeSlots > 4) return 0;
    const int32_t activeCount = static_cast<int32_t>(activeSlots);
    return rawCount > activeCount ? rawCount : activeCount;
}
}
