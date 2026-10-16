#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace EIDPocketInventoryPolicy {
struct Pocket { int32_t id; uint32_t type; };
static_assert(sizeof(Pocket) == 8, "Unexpected native pocket stride");
constexpr size_t Slots = 4;

// Type 2 stores ActiveSlot + 1, not a collectible ID. Native RemoveActiveItem
// compares this reference with slot+1 before reading Player[0x1964 + slot*28].
inline bool Resolve(const std::array<Pocket,Slots>& raw,
                    const std::array<int32_t,Slots>& actives,
                    std::array<Pocket,Slots>& resolved) {
    resolved = {};
    for (size_t i = 0; i < Slots; ++i) {
        const auto& pocket = raw[i];
        if (pocket.type > 2 || pocket.id < 0) return false;
        if (pocket.type == 0 && pocket.id > 0xffff) return false;
        if (pocket.type == 1 && pocket.id > 97) return false;
        resolved[i] = pocket;
        if (pocket.type != 2 || pocket.id == 0) continue;
        if (pocket.id > static_cast<int32_t>(Slots)) return false;
        int32_t item = actives[static_cast<size_t>(pocket.id-1)];
        if (item < 0 || item > 732) return false;
        resolved[i].id = item;
    }
    return true;
}

struct CraftingBag { std::array<uint8_t,8> ingredients; int32_t result; };
static_assert(sizeof(CraftingBag) == 12, "Unexpected native crafting snapshot");
inline bool ValidateBag(const CraftingBag& bag, size_t& count) {
    count = 0;
    bool empty = false;
    for (uint8_t ingredient : bag.ingredients) {
        if (ingredient > 29) return false;
        if (!ingredient) empty = true;
        else { if (empty) return false; ++count; }
    }
    // Zero also occurs while the native cache is not ready. Do not guess an ID.
    return bag.result >= 0 && bag.result <= 732 && (count == 8 || bag.result == 0);
}
inline int32_t CraftingResult(const CraftingBag& bag) {
    size_t count = 0;
    return ValidateBag(bag,count) && count == 8 ? bag.result : 0;
}
}
