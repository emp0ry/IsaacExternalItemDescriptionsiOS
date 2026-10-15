#pragma once
#include <cstdint>
#include <vector>

namespace EIDSpindownPolicy {
enum class Availability { Missing, Hidden, Available, Locked, Restricted, Unknown };
struct Excluded { int32_t id; Availability reason; };
struct Step { int32_t result; std::vector<Excluded> excluded; };

// Mirrors the supported native Spindown loop, not general item-pool rerolls.
// Query is read-only and must distinguish unavailable from unreadable data.
template <class Query>
bool Build(int32_t start, bool battery, Query query, std::vector<Step>& output) {
    output.clear();
    if (start <= 0 || start > 732) return false;
    if (start == 668) return true; // Native CanReroll excludes Dad's Note.
    for (unsigned use = 0; use < 3; ++use) {
        Step step{};
        for (unsigned trigger = 0; trigger < (battery ? 2u : 1u); ++trigger) {
            int32_t candidate = start-1;
            for (; candidate > 0; --candidate) {
                Availability state = query(candidate);
                if (state == Availability::Unknown) { output.clear(); return false; }
                if (state == Availability::Available) break;
                if (state == Availability::Locked || state == Availability::Restricted)
                    step.excluded.push_back({candidate,state});
            }
            step.result = start = candidate;
            if (start == 0 || start == 668) break;
        }
        output.push_back(step);
        if (start == 0 || start == 668) break;
    }
    return true;
}
}
