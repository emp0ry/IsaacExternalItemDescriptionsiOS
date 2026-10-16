#pragma once
#include <array>
#include <cstdint>

namespace EIDTrinketEffectPolicy {
// Native new-room tables at 0x100953360/378/398. The iOS Liberty Cap table
// swaps the two mushroom entries relative to upstream PC EID; use native order.
constexpr std::array<int32_t,6> Liberty = {12,71,121,120,342,398};
constexpr std::array<int32_t,8> Syringe = {13,14,240,70,143,345,493,496};
constexpr std::array<int32_t,13> Lock = {29,30,31,55,110,114,199,200,217,228,355,508,732};

inline int32_t CurrentCandidate(int32_t trinket, uint32_t currentSeed) {
    if (!currentSeed) return 0;
    switch (trinket) {
        case 32: return Liberty[currentSeed % Liberty.size()];
        case 132: return Syringe[currentSeed % Syringe.size()];
        case 153: return Lock[currentSeed % Lock.size()];
        default: return 0;
    }
}
}
