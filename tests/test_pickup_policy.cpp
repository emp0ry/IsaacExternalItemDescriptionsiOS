#include "EIDPickupPolicy.hpp"
#include "EIDNativeContextPolicy.hpp"
#include "EIDPillPolicy.h"
#include "EIDPredictionPolicy.hpp"
#include "EIDSpindownPolicy.hpp"
#include "EIDHostReadinessPolicy.hpp"
#include "EIDArtworkBounds.h"

#include <array>
#include <cassert>

using namespace EIDPickupPolicy;

int main() {
    {
        std::array<uint8_t,32*32*4> rgba{};
        auto empty = EIDVisibleArtworkBounds(rgba.data(),rgba.size(),32,32,128);
        assert(!empty.found);
        // A wide Red Key-shaped sprite retains its aspect ratio and no padding.
        for (size_t y = 9; y < 23; ++y)
            for (size_t x = 2; x < 29; ++x) rgba[(y*32+x)*4+3] = 255;
        auto key = EIDVisibleArtworkBounds(rgba.data(),rgba.size(),32,32,128);
        assert(key.found && key.x == 2 && key.y == 9 && key.width == 27 && key.height == 14);
        rgba.fill(0); rgba[3] = 8;
        assert(!EIDVisibleArtworkBounds(rgba.data(),rgba.size(),32,32,128).found);
        rgba[3] = 9;
        auto pixel = EIDVisibleArtworkBounds(rgba.data(),rgba.size(),32,32,128);
        assert(pixel.found && pixel.x == 0 && pixel.y == 0 && pixel.width == 1 && pixel.height == 1);
        assert(!EIDVisibleArtworkBounds(rgba.data(),rgba.size()-1,32,32,128).found);
        assert(!EIDVisibleArtworkBounds(rgba.data(),rgba.size(),32,32,127).found);
        assert(!EIDVisibleArtworkBounds(nullptr,rgba.size(),32,32,128).found);
        assert(!EIDVisibleArtworkBounds(rgba.data(),rgba.size(),SIZE_MAX,32,128).found);
    }
    {
        EIDHostReadinessPolicy::Frames frames;
        assert(!frames.Observe(true,1,2,3,0,844,390));
        assert(!frames.Observe(true,1,2,3,10,844,390));
        assert(!frames.Observe(true,1,2,3,10,844,390)); // Loaded but not rendering.
        assert(frames.Observe(true,1,2,3,11,844,390));
        assert(frames.Observe(true,1,2,3,11,844,390)); // An attached paused game stays ready.
        assert(!frames.Observe(true,1,2,3,12,390,844)); // Startup portrait bounds.
        assert(!frames.Observe(true,1,2,3,13,844,390));
        assert(frames.Observe(true,1,2,3,14,844,390));
        assert(!frames.Observe(false,1,2,3,15,844,390));
        assert(!frames.Observe(true,1,2,3,16,844,390));
        assert(frames.Observe(true,1,2,3,17,844,390));
        assert(!frames.Observe(true,4,5,6,18,844,390)); // Another guest/window.
        assert(frames.Observe(true,4,5,6,19,844,390));
        assert(!frames.Observe(true,4,5,7,20,844,390)); // Recreated native display link.
        assert(!frames.Observe(true,4,5,7,NAN,844,390));
        assert(!frames.Observe(true,0,5,7,21,844,390));
    }
    {
        using namespace EIDSpindownPolicy;
        std::vector<Step> steps;
        auto query = [](int32_t id) {
            if (id == 9) return Availability::Locked;
            if (id == 8) return Availability::Hidden;
            if (id == 7) return Availability::Missing;
            if (id == 5) return Availability::Restricted;
            return Availability::Available;
        };
        assert(Build(10,false,query,steps));
        assert(steps.size() == 3 && steps[0].result == 6 && steps[1].result == 4 && steps[2].result == 3);
        assert(steps[0].excluded.size() == 1 && steps[0].excluded[0].id == 9);
        assert(steps[1].excluded.size() == 1 && steps[1].excluded[0].reason == Availability::Restricted);
        assert(Build(10,true,query,steps));
        assert(steps[0].result == 4 && steps[0].excluded.size() == 2);
        assert(Build(2,false,query,steps));
        assert(steps.size() == 2 && steps[0].result == 1 && steps[1].result == 0);
        assert(Build(1,true,query,steps) && steps.size() == 1 && steps[0].result == 0);
        assert(Build(669,true,query,steps) && steps.size() == 1 && steps[0].result == 668);
        assert(Build(668,false,query,steps) && steps.empty());
        assert(!Build(733,false,query,steps));
        assert(!Build(10,false,[](int32_t){return Availability::Unknown;},steps) && steps.empty());
        assert(Build(732,false,[](int32_t id){return id == 1 ? Availability::Available : Availability::Locked;},steps));
        assert(steps[0].result == 1 && steps[0].excluded.size() == 730);
    }
    {
        using namespace EIDPredictionPolicy;
        RNG live{123456789,5,9,7};
        assert(Valid(live));
        assert(!Valid({0,5,9,7})); assert(!Valid({1,5,9,8}));
        auto first = Absorption(live.seed,1,false);
        auto rune = Absorption(live.seed,1,true);
        auto repeat = Absorption(live.seed,1,false);
        assert((first == std::array<unsigned,6>{0,0,1,0,1,0}));
        assert((rune == std::array<unsigned,6>{0,1,0,0,1,0}));
        assert(first == repeat && live.seed == 123456789);
        assert(first != rune);
        for (unsigned count = 0; count <= 128; ++count) {
            auto stats = Absorption(live.seed,count,false);
            unsigned total = 0; for (unsigned stat : stats) total += stat;
            assert(total == count*2);
        }
    }
    using namespace EIDNativeContextPolicy;
    assert(!EIDPillModifiersIdentify(-1));
    assert(!EIDPillModifiersIdentify(0));
    assert(EIDPillModifiersIdentify(EIDPillModifierPHD));
    assert(EIDPillModifiersIdentify(EIDPillModifierFalsePHD));
    assert(EIDPillModifiersIdentify(EIDPillModifierPHD | EIDPillModifierFalsePHD));
    assert(!EIDPillModifiersIdentify(EIDPillModifierVirgo | EIDPillModifierLuckyFoot));
    assert(!EIDPillModifiersIdentify(16));
    std::array<uint8_t,733> collection{};
    assert(ValidCollectionFlags(collection.data(),collection.size()));
    collection[732] = 1;
    assert(ValidCollectionFlags(collection.data(),collection.size()));
    collection[732] = 2;
    assert(!ValidCollectionFlags(collection.data(),collection.size()));
    collection[732] = 0;
    collection[0] = 1;
    assert(!ValidCollectionFlags(collection.data(),collection.size()));
    assert(!ValidCollectionFlags(nullptr,733));
    assert(!ValidCollectionFlags(collection.data(),732));
    for (int32_t type = 0; type <= 40; ++type) {
        assert(HasPassiveBelial(type,1,0,false) == (type == 3 || type == 12));
        assert(!HasPassiveBelial(type,0,0,false));
        assert(HasPassiveBelial(type,0,1,false));
        assert(!HasPassiveBelial(type,1,1,true));
    }
    assert(!HasPassiveBelial(-1,1,0,false));
    assert(!HasPassiveBelial(3,-1,0,false));
    assert(ValidSmeltedSpan(0,0,0));
    assert(ValidSmeltedSpan(0x1000,0x12f8,0x1400));
    assert(!ValidSmeltedSpan(0,0x1000,0x1000));
    assert(!ValidSmeltedSpan(0x1001,0x12f9,0x1400));
    assert(!ValidSmeltedSpan(0x1000,0x0ffc,0x1400));
    assert(!ValidSmeltedSpan(0x1000,0x1001,0x1400));
    assert(!ValidSmeltedSpan(0x1000,0x12f8,0x1200));
    assert(!ValidSmeltedSpan(0x1000,0x3000,0x3000));
    std::vector<SmeltedCounts> counts(190);
    counts[1].regular = 2;
    counts[189].golden = 1;
    std::vector<int32_t> smelted;
    assert(DecodeSmeltedCounts(counts,smelted));
    assert(smelted.size() == 2 && smelted[0] == 1 && smelted[1] == (189 | 0x8000));
    counts[189].regular = -1;
    assert(!DecodeSmeltedCounts(counts,smelted) && smelted.empty());
    assert(DecodeSmeltedCounts({},smelted) && smelted.empty());
    assert(!DecodeSmeltedCounts(std::vector<SmeltedCounts>(1025),smelted));
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
    for (int32_t card : {41,43,45,47,49,50,51,55,78,80,81,97}) {
        assert(IsVisuallyDistinctCard(card));
        assert(ShouldRevealFloorIdentity(300,card,true,0,false));
        assert(!ShouldRevealFloorIdentity(300,card,true,4,true));
    }
    for (int32_t card : {1,22,23,31,32,33,40,42,52,53,54,56,77,79,98}) {
        assert(!IsVisuallyDistinctCard(card));
        assert(!ShouldRevealFloorIdentity(300,card,true,0,true));
    }

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
