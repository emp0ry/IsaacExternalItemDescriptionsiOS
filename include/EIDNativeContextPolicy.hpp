#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

namespace EIDNativeContextPolicy {
// HasCollectible(59) has a virtual-ownership branch in native Repentance:
// Judas/Black Judas + Birthright. It need not exist in the raw count table.
inline bool HasPassiveBelial(int32_t playerType, int32_t birthrightCount,
                            int32_t rawBelialCount, bool nonQuestItemsDisabled) {
    if (playerType < 0 || playerType > 40 || birthrightCount < 0 || rawBelialCount < 0 ||
        nonQuestItemsDisabled) return false;
    return rawBelialCount > 0 || ((playerType == 3 || playerType == 12) && birthrightCount > 0);
}

struct SmeltedCounts { int16_t regular; int16_t golden; };
static_assert(sizeof(SmeltedCounts) == 4, "Unexpected native smelted-count stride");

inline bool ValidSmeltedSpan(uintptr_t begin, uintptr_t end, uintptr_t capacity) {
    if (!begin && !end && !capacity) return true;
    return begin && begin % 4 == 0 && end >= begin && capacity >= end &&
        capacity - begin <= 4096 && (end - begin) % sizeof(SmeltedCounts) == 0;
}

inline bool DecodeSmeltedCounts(const std::vector<SmeltedCounts>& counts,
                               std::vector<int32_t>& identities) {
    identities.clear();
    if (counts.size() > 1024) return false;
    std::vector<int32_t> decoded;
    for (size_t index = 1; index < counts.size(); ++index) {
        if (counts[index].regular < 0 || counts[index].golden < 0) return false;
        if (index > 189) continue; // Supported Repentance trinket range.
        if (counts[index].regular > 0) decoded.push_back(static_cast<int32_t>(index));
        if (counts[index].golden > 0) decoded.push_back(static_cast<int32_t>(index | 0x8000));
    }
    identities.swap(decoded);
    return true;
}
}
