#pragma once

#include <array>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <string>

namespace EIDCollectibleVisibilityPolicy {

enum class State { Visible, Blind, Unreadable };

constexpr size_t ForceBlindOffset = 0x562;
constexpr size_t LayerStatesOffset = 0x50 + 0xa8;
constexpr size_t LayerCountOffset = 0x50 + 0xb0;
// ANM2::GetLayer (0x10089f558) multiplies by 0xb0. ReplaceSpritesheet
// (0x1008a0250) writes the actual override string at layer + 0x10.
// +0x08 and stride 0x90 are NOT sprite paths/layers on this native build.
constexpr size_t LayerStride = 0xb0;
constexpr size_t LayerSpritePathOffset = 0x10;

inline bool IsQuestionMarkSpritePath(std::string path) {
    for (char& character : path) {
        if (character == '\\') character = '/';
        else character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    }
    const auto slash = path.find_last_of('/');
    const auto basename = slash == std::string::npos ? path : path.substr(slash + 1);
    return basename == "questionmark.png";
}

// Inspect this pickup's artwork, not the floor's curse mask. A previously held
// active can be dropped with visible artwork even while Curse of the Blind is
// active. Unreadable artwork must still fail closed, and a question mark on any
// layer always wins over other readable or unreadable layers.
template <class ReadLayerPath>
State Resolve(bool forceBlind, uint32_t layerCount, ReadLayerPath readLayerPath) {
    if (forceBlind) return State::Blind;
    if (!layerCount || layerCount > 32) return State::Unreadable;
    bool unreadable = false;
    for (uint32_t layer = 0; layer < layerCount; ++layer) {
        std::string path;
        if (!readLayerPath(layer, path) || (layer == 1 && path.empty())) unreadable = true;
        else if (IsQuestionMarkSpritePath(path)) return State::Blind;
    }
    return unreadable ? State::Unreadable : State::Visible;
}

template <class Reader>
bool ValidateLayout(uintptr_t image, Reader read) {
    struct Signature { uintptr_t rva; std::array<uint32_t,4> words; };
    const Signature signatures[] = {
        {0x89f558,{0xf9405688,0x52801609,0x9b292260,0xa9427bfd}},
        {0x8a0250,{0xf9405688,0x52801615,0x9bb52268,0x91004100}},
    };
    for (const auto& signature : signatures) {
        std::array<uint32_t,4> actual{};
        if (!read(image + signature.rva,actual.data(),sizeof(actual)) || actual != signature.words) return false;
    }
    return true;
}

// The same byte decoder is used by the live probe and host fixture tests.
// No collectible subtype or floor-wide exception can bypass its artwork gate.
template <class ReadMemory, class ReadString>
State ReadNativeArtwork(const uint8_t *object, size_t available,
                        ReadMemory readMemory, ReadString readString) {
    if (!object || available <= ForceBlindOffset) return State::Unreadable;
    if (object[ForceBlindOffset]) return State::Blind;
    uintptr_t layers = 0;
    uint32_t count = 0;
    memcpy(&layers,object + LayerStatesOffset,sizeof(layers));
    memcpy(&count,object + LayerCountOffset,sizeof(count));
    // Collectible artwork is always layer 1, with a separate pedestal layer 0.
    if (!layers || count < 2 || count > 32 ||
        layers > std::numeric_limits<uintptr_t>::max() - count * LayerStride) return State::Unreadable;
    return Resolve(false,count,[&](uint32_t layer, std::string& path) {
        std::array<uint8_t,LayerStride> state{};
        return readMemory(layers + layer * LayerStride,state.data(),state.size()) &&
            readString(state.data() + LayerSpritePathOffset,path);
    });
}

} // namespace EIDCollectibleVisibilityPolicy
