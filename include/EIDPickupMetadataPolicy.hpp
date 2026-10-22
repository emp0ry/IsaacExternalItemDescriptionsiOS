#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>

namespace EIDPickupMetadataPolicy {

constexpr size_t OptionsIndexOffset = 0x55c;
constexpr size_t PriceOffset = 0x564;
constexpr size_t ShopItemIDOffset = 0x56c;

struct Metadata {
    int32_t price = 0;
    int32_t optionsIndex = 0;
    int32_t shopItemID = 0;
    bool IsShopItem() const { return price != 0; }
};

// Native pickup serialization stores these as independent fields. In
// particular, a negative shop slot is valid and is NOT a hidden Options? group.
inline bool Read(const uint8_t *object, size_t available, Metadata& result) {
    result = {};
    if (!object || available < ShopItemIDOffset + sizeof(int32_t)) return false;
    Metadata value;
    memcpy(&value.price,object + PriceOffset,sizeof(value.price));
    memcpy(&value.optionsIndex,object + OptionsIndexOffset,sizeof(value.optionsIndex));
    memcpy(&value.shopItemID,object + ShopItemIDOffset,sizeof(value.shopItemID));
    if (value.optionsIndex < 0 || value.optionsIndex > 4096) return false;
    result = value;
    return true;
}

template <class Reader>
bool ValidateLayout(uintptr_t image, Reader read) {
    struct Signature { uintptr_t rva; std::array<uint32_t,4> words; };
    const Signature signatures[] = {
        // Save pickup: Price -> +0x14, ShopItemID -> +0x18, Options -> +0x30.
        {0x59d850,{0xb9456688,0xb9001668,0x3955a288,0x39014268}},
        {0x59d860,{0xb9456e88,0xb9001a68,0x39558288,0x39008a68}},
        {0x59d878,{0xb9455e88,0xb9003268,0xb9457288,0xb9001e68}},
        // Options collision: compare the two pickup group IDs at +0x55c.
        {0x71d000,{0xb9455ea8,0xb9455e69,0x6b09011f,0xfa5302a4}},
    };
    for (const auto& signature : signatures) {
        std::array<uint32_t,4> actual{};
        if (!read(image + signature.rva,actual.data(),sizeof(actual)) || actual != signature.words) return false;
    }
    return true;
}

} // namespace EIDPickupMetadataPolicy
