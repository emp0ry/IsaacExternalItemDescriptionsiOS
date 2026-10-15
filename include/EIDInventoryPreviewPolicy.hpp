#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace EIDInventoryPreviewPolicy {
// Native ItemHistory::Item. The Stars? walks this exact persisted order.
struct HistoryEntry {
    int32_t frame;
    uint8_t trinket;
    uint8_t padding[3];
    int32_t id;
    int32_t extra[4];
};
static_assert(sizeof(HistoryEntry) == 28, "Unexpected native ItemHistory stride");
constexpr size_t MaximumHistory = 4096;

inline bool HistorySpan(uintptr_t begin, uintptr_t end, uintptr_t capacity) {
    if (!begin && !end && !capacity) return true;
    return begin && begin % 4 == 0 && end >= begin && capacity >= end &&
        capacity-begin <= MaximumHistory*sizeof(HistoryEntry) &&
        (end-begin)%sizeof(HistoryEntry) == 0 && (capacity-begin)%sizeof(HistoryEntry) == 0;
}

inline uint64_t HistorySignature(const std::vector<HistoryEntry>& entries) {
    uint64_t signature = 14695981039346656037ull;
    for (const auto& entry : entries) {
        // Ignore padding, animation state, and unrelated record metadata.
        for (uint32_t value : {static_cast<uint32_t>(entry.frame),
                               static_cast<uint32_t>(entry.trinket),static_cast<uint32_t>(entry.id)}) {
            signature ^= value; signature *= 1099511628211ull;
        }
    }
    return signature;
}

enum class Eligibility { Unknown, Excluded, Eligible };

template <typename Query>
bool Stars(const std::vector<HistoryEntry>& history, std::array<int32_t,733> counts,
           bool tarotCloth, Query query, std::vector<int32_t>& result) {
    result.clear();
    if (history.size() > MaximumHistory) return false;
    for (const auto& entry : history) {
        if (entry.trinket > 1) { result.clear(); return false; }
        // Native branch excludes starting/frame-zero records and trinkets.
        if (entry.trinket || entry.frame < 1) continue;
        if (entry.id < 1 || entry.id > 732) { result.clear(); return false; }
        if (counts[static_cast<size_t>(entry.id)] <= 0) continue;
        auto eligible = query(entry.id);
        if (eligible == Eligibility::Unknown) { result.clear(); return false; }
        if (eligible == Eligibility::Excluded) continue;
        result.push_back(entry.id);
        --counts[static_cast<size_t>(entry.id)]; // Simulate only our private copy.
        if (result.size() == (tarotCloth ? 2u : 1u)) break;
    }
    return true;
}

inline double BlackFeatherDamage(int32_t count, bool momsBox, bool golden) {
    if (count < 0 || count > 100000) return -1;
    // Match upstream's BlackFeatherCallback, not generic trinket replacement.
    return 0.5*count*(momsBox ? 2 : 1)*(golden ? 2 : 1);
}
}
