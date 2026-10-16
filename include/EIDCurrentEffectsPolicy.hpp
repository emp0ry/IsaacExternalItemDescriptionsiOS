#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

namespace EIDCurrentEffectsPolicy {
inline bool ValidSpan(uintptr_t begin, uintptr_t end, uintptr_t capacity, size_t stride, size_t maximum) {
    if (!begin && !end && !capacity) return true;
    return stride && begin && begin % 4 == 0 && end >= begin && capacity >= end &&
        (end-begin) % stride == 0 && (capacity-begin) % stride == 0 &&
        (capacity-begin)/stride <= maximum;
}
inline bool ValidVoidIDs(const std::vector<int32_t>& ids) {
    if (ids.size() > 1024) return false;
    for (int32_t id : ids) if (id < 1 || id > 732) return false;
    return true;
}
inline bool ValidPurity(int32_t boost, uint8_t disabled) {
    return boost >= 0 && boost <= 3 && disabled <= 1;
}
inline bool ValidClay(int32_t item) { return item >= 0 && item <= 732; }
}
