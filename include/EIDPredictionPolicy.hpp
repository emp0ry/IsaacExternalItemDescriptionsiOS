#pragma once
#include <array>
#include <cstdint>

namespace EIDPredictionPolicy {
struct RNG { uint32_t seed, shift1, shift2, shift3; };
inline bool Valid(RNG rng) {
    // Both native absorption paths use shift-table index 35 (5,9,7).
    return rng.seed != 0 && rng.shift1 == 5 && rng.shift2 == 9 && rng.shift3 == 7;
}
inline uint32_t Next(uint32_t &seed) {
    seed ^= seed >> 5; seed ^= seed << 9; seed ^= seed >> 7;
    return seed;
}
inline std::array<unsigned,6> Absorption(uint32_t seed, unsigned count, bool rune) {
    std::array<unsigned,6> increases{};
    if (!seed || count > 4096) return increases;
    if (!rune) Next(seed);
    for (unsigned item = 0; item < count; ++item) {
        std::array<unsigned,6> stats = {0,1,2,3,4,5};
        for (unsigned size = 6; size > 1; --size) {
            unsigned index = Next(seed) % size;
            unsigned temporary = stats[size-1]; stats[size-1] = stats[index]; stats[index] = temporary;
        }
        ++increases[stats[0]]; ++increases[stats[1]];
    }
    return increases;
}
}
