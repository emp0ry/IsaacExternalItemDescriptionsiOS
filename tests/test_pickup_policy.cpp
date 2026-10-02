#include "EIDPickupPolicy.hpp"

#include <array>
#include <cassert>

using namespace EIDPickupPolicy;

int main() {
    bool canFly = false;
    assert(DecodeNativeCanFly(0, canFly) && !canFly);
    assert(DecodeNativeCanFly(1, canFly) && canFly);
    assert(!DecodeNativeCanFly(2, canFly) && !canFly);
    assert(!DecodeNativeCanFly(0xff, canFly) && !canFly);

    // Current upstream EID defaults for cards and runes.
    assert(ShouldRevealFloorIdentity(300, 1, false, 0, true));   // reachable floor card
    assert(!ShouldRevealFloorIdentity(300, 1, false, 0, false)); // obstructed floor card
    assert(!ShouldRevealFloorIdentity(300, 1, true, 0, true));   // purchasable card
    assert(!ShouldRevealFloorIdentity(300, 1, false, 4, true));  // Options? card

    // Soul Stones are visible through obstructions and in shops, but the
    // default Options? rule still hides them.
    assert(ShouldRevealFloorIdentity(300, 81, false, 0, false));
    assert(ShouldRevealFloorIdentity(300, 81, true, 0, false));
    assert(!ShouldRevealFloorIdentity(300, 81, false, 4, true));

    // Current upstream defaults show shop and Options? pills when reachable,
    // while obstruction applies to known, unknown and horse pills alike.
    assert(ShouldRevealFloorIdentity(70, 1, true, 4, true));
    assert(!ShouldRevealFloorIdentity(70, 1, true, 4, false));
    assert(ShouldRevealFloorIdentity(1070, 1, false, 0, true));
    assert(!ShouldRevealFloorIdentity(1070, 1, false, 0, false));
    assert(ShouldRevealFloorIdentity(2070, 5, true, 4, true));
    assert(!ShouldRevealFloorIdentity(2070, 5, false, 0, false));

    constexpr int32_t width = 7;
    constexpr int32_t height = 7;
    std::array<int32_t, width * height> paths{};
    GridPoint start{2, 2};
    GridPoint finish{4, 4};
    assert(HasGridPath(paths.data(), paths.size(), width, height, start, finish));
    for (int32_t column = 1; column < width - 1; ++column) {
        paths[3 * width + column] = 1000;
    }
    assert(!HasGridPath(paths.data(), paths.size(), width, height, start, finish));

    GridPoint converted;
    assert(WorldToGrid(120.0f, 200.0f, width, height, converted));
    assert(converted.row == 2 && converted.column == 2);
    return 0;
}
