#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

namespace EIDCollectibleCyclePolicy {
constexpr size_t MaximumAlternates = 8;
constexpr size_t MinimumSummaryItems = 5; // Same threshold as original EID.

inline bool Normalize(int32_t current, const std::array<int32_t,MaximumAlternates>& alternatives,
                      int32_t count, std::vector<int32_t>& output) {
    output.clear();
    if (current < 1 || current > 732 || count < 4 || count > 8) return false;
    std::vector<int32_t> ring{current};
    for (int32_t index = 0; index < count; ++index) {
        int32_t id = alternatives[static_cast<size_t>(index)];
        if (id < 1 || id > 732) return false;
        ring.push_back(id);
    }
    // The game rotates [current, queue...] on each switch. Canonicalize the
    // complete ring before deduplicating, retaining cyclic order without UI
    // selection resets. Sorting the IDs would lose that order.
    std::vector<int32_t> canonical = ring;
    for (size_t shift = 1; shift < ring.size(); ++shift) {
        std::rotate(ring.begin(),ring.begin()+1,ring.end());
        if (ring < canonical) canonical = ring;
    }
    for (int32_t id : canonical)
        if (std::find(output.begin(),output.end(),id) == output.end()) output.push_back(id);
    if (output.size() < MinimumSummaryItems) { output.clear(); return false; }
    return true;
}
}
