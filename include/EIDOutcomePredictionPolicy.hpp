#pragma once
#include <array>
#include <cstdint>

namespace EIDOutcomePredictionPolicy {
inline uint32_t Shift(uint32_t seed, unsigned a, unsigned b, unsigned c) {
    seed ^= seed >> a; seed ^= seed << b; seed ^= seed >> c;
    return seed;
}

struct PennyResult {
    std::array<bool,2> heads{};
    unsigned count = 0;
    uint32_t nextSeed = 0;
};

inline PennyResult CrookedPenny(uint32_t seed, uint32_t roomDecorationSeed, bool battery) {
    PennyResult result;
    if (!seed) return result;
    result.count = battery ? 2 : 1;
    for (unsigned i = 0; i < result.count; ++i) {
        // UseActiveItem advances the stored collectible stream once. The room
        // mixing and shift #4 happen on a separate stack RNG, not that stream.
        seed = Shift(seed,5,9,7);
        uint32_t mixed = seed ^ roomDecorationSeed;
        if (!mixed) mixed = 1;
        result.heads[i] = (Shift(mixed,1,11,6) & 1) == 0;
        // Failure advances the original stream for the consolation penny.
        if (!result.heads[i]) seed = Shift(seed,5,9,7);
    }
    result.nextSeed = seed;
    return result;
}

enum class EternalResult { Unknown, Reroll, Vanish };
inline bool EternalVanishRoll(uint32_t roll) {
    float value = static_cast<float>(roll) * 0x1.fffffep-33f;
    return value <= .25f;
}
inline EternalResult EternalD6(uint32_t currentPickupSeed) {
    if (!currentPickupSeed) return EternalResult::Unknown;
    // iOS 1.7.9b uses shift #44 and a single-precision <= .25 comparison.
    // Current upstream PC EID uses another seed/shift path; do not copy it.
    uint32_t roll = Shift(currentPickupSeed,5,27,25);
    return EternalVanishRoll(roll) ? EternalResult::Vanish : EternalResult::Reroll;
}
}
