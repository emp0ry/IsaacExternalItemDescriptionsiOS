#include "EIDPickupPolicy.hpp"
#include "EIDNativeContextPolicy.hpp"
#include "EIDPillPolicy.h"
#include "EIDPredictionPolicy.hpp"
#include "EIDSpindownPolicy.hpp"
#include "EIDRepeatPolicy.hpp"
#include "EIDInventoryPreviewPolicy.hpp"
#include "EIDCollectibleCyclePolicy.hpp"
#include "EIDHostReadinessPolicy.hpp"
#include "EIDArtworkBounds.h"
#include "EIDDescriptionInteraction.h"

#include <array>
#include <cassert>

using namespace EIDPickupPolicy;

int main() {
    {
        assert(EIDDInfinityPreviewID(0) == 489);
        const int expected[] = {476,284,105,609,437,406,285,386,166,283};
        size_t selection = 0;
        for (size_t i = 0; i < 10; ++i) {
            selection = EIDNextDescriptionSelection(selection,EIDDInfinityPreviewCount);
            assert(selection == i+1 && EIDDInfinityPreviewID(selection) == expected[i]);
        }
        assert(EIDNextDescriptionSelection(selection,EIDDInfinityPreviewCount) == 0);
        assert(EIDDInfinityPreviewID(11) == 489);
        assert(EIDNextDescriptionSelection(SIZE_MAX,10) == 0);
        assert(EIDNextDescriptionSelection(0,0) == 0);
        assert(EIDNextDescriptionSelection(0,33) == 0);
        assert(!EIDDescriptionBackgroundVisible(false,false));
        assert(EIDDescriptionBackgroundVisible(true,false));
        assert(EIDDescriptionBackgroundVisible(false,true));
        assert(EIDDescriptionBackgroundAlpha(0,true) == .72);
        assert(EIDDescriptionBackgroundAlpha(.9,true) == .9);
        assert(EIDDescriptionBackgroundAlpha(.2,false) == .2);
        assert(EIDDescriptionBackgroundAlpha(-1,false) == 0);
        assert(EIDDescriptionBackgroundAlpha(2,false) == 1);
        assert(EIDDescriptionBackgroundAlpha(NAN,false) == .28);
        assert(EIDDescriptionFittedWidth(390,80,110,27,0,1) == 139);
        assert(EIDDescriptionFittedWidth(390,80,110,27,58,1) == 167);
        assert(EIDDescriptionFittedWidth(200,240,110,27,58,1) == 200);
        assert(EIDDescriptionFittedWidth(390,80,350,27,58,1) == 379);
        assert(EIDDescriptionFittedWidth(0,80,110,27,0,1) == 0);
        assert(EIDDescriptionFittedWidth(390,NAN,110,27,0,1) == 0);
    }
    {
        using namespace EIDCollectibleCyclePolicy;
        std::vector<int32_t> original{25,2,118,689,1}, normalized;
        std::array<int32_t,MaximumAlternates> queue{};
        std::copy(original.begin()+1,original.end(),queue.begin());
        assert(Normalize(original[0],queue,4,normalized));
        const auto expected = normalized;
        assert(expected == std::vector<int32_t>({1,25,2,118,689})); // Cyclic, not ID-sorted order.
        for (size_t i = 0; i < original.size(); ++i) {
            std::rotate(original.begin(),original.begin()+1,original.end());
            std::copy(original.begin()+1,original.end(),queue.begin());
            assert(Normalize(original[0],queue,4,normalized) && normalized == expected);
        }
        original = {25,2,25,118,689,1};
        for (size_t i = 0; i < original.size(); ++i) {
            std::rotate(original.begin(),original.begin()+1,original.end());
            std::copy(original.begin()+1,original.end(),queue.begin());
            assert(Normalize(original[0],queue,5,normalized) && normalized == expected);
        }
        queue = {2,3,4,5,6,7,8,9};
        assert(Normalize(1,queue,8,normalized) && normalized.size() == 9);
        assert(!Normalize(1,queue,9,normalized) && normalized.empty());
        assert(!Normalize(1,queue,3,normalized) && normalized.empty());
        assert(!Normalize(0,queue,4,normalized) && normalized.empty());
        assert(!Normalize(733,queue,4,normalized) && normalized.empty());
        queue = {2,3,4,733,0,0,0,0};
        assert(!Normalize(1,queue,4,normalized) && normalized.empty());
        queue = {2,3,4,1,0,0,0,0};
        assert(!Normalize(1,queue,4,normalized) && normalized.empty()); // Only four unique items.
        queue = {2,3,4,5,-1,-1,-1,-1};
        assert(Normalize(1,queue,4,normalized)); // Unused queue storage is not a cycle member.
    }
    {
        using namespace EIDInventoryPreviewPolicy;
        assert(HistorySpan(0,0,0));
        assert(HistorySpan(0x1000,0x1000+56,0x1000+112));
        assert(!HistorySpan(0,28,56));
        assert(!HistorySpan(0x1001,0x1001+28,0x1001+28));
        assert(!HistorySpan(0x1000,0x1000+29,0x1000+56));
        assert(!HistorySpan(0x1000,0x1000+56,0x1000+28));
        assert(!HistorySpan(0x1000,0x1000,0x1000+(MaximumHistory+1)*28));
        std::array<int32_t,733> counts{};
        counts[25] = 1; counts[34] = 1; counts[327] = 1; counts[2] = 2; counts[3] = 1;
        std::vector<HistoryEntry> history = {
            {0,0,{},25,{}}, {10,1,{},17,{}}, {11,0,{},34,{}},
            {12,0,{},327,{}}, {13,0,{},26,{}}, {14,0,{},2,{}}, {15,0,{},2,{}}, {16,0,{},3,{}}};
        auto query = [](int32_t id) { return id == 34 || id == 327 ? Eligibility::Excluded : Eligibility::Eligible; };
        std::vector<int32_t> result;
        assert(Stars(history,counts,false,query,result) && result == std::vector<int32_t>({2}));
        assert(Stars(history,counts,true,query,result) && result == std::vector<int32_t>({2,2}));
        assert(counts[2] == 2); // The live input is never modified.
        counts[2] = 1;
        assert(Stars(history,counts,true,query,result) && result == std::vector<int32_t>({2,3}));
        counts[2] = 0;
        assert(Stars(history,counts,true,query,result) && result == std::vector<int32_t>({3}));
        counts[3] = 0;
        assert(Stars(history,counts,false,query,result) && result.empty());
        counts[2] = 1;
        assert(!Stars(history,counts,false,[](int32_t){return Eligibility::Unknown;},result) && result.empty());
        auto changed = history; changed[5].id = 3;
        assert(HistorySignature(history) != HistorySignature(changed));
        changed = history; changed[5].padding[0] = 99; changed[5].extra[0] = 100;
        assert(HistorySignature(history) == HistorySignature(changed));
        changed = history; changed[0].trinket = 2;
        assert(!Stars(changed,counts,false,query,result) && result.empty());
        assert(BlackFeatherDamage(0,false,false) == 0);
        assert(BlackFeatherDamage(2,false,false) == 1);
        assert(BlackFeatherDamage(2,true,false) == 2);
        assert(BlackFeatherDamage(2,false,true) == 2);
        assert(BlackFeatherDamage(2,true,true) == 4);
        assert(BlackFeatherDamage(-1,false,false) < 0);
    }
    {
        using namespace EIDRepeatPolicy;
        assert(WildCard(0,0,1)); // Bad Gas uses native effect zero.
        assert(WildCard(0,46,Horse|13));
        assert(WildCard(0,49,14)); // Golden pill's remembered concrete effect.
        assert(WildCard(1,48,0)); // ? Card is a native effect, not guessed from a pocket.
        assert(WildCard(1,97,0));
        assert(WildCard(2,34,0));
        assert(!WildCard(0,-1,1) && !WildCard(0,50,1));
        assert(!WildCard(0,1,0) && !WildCard(0,1,0x1001));
        assert(!WildCard(1,80,0)); // Never recursively preview Wild Card itself.
        assert(!WildCard(1,0,0) && !WildCard(1,98,0));
        assert(!WildCard(2,0,0) && !WildCard(2,733,0));
        assert(!WildCard(0xff,34,0) && !WildCard(3,34,0));
        assert(VurpColor(0,3) == 3); // No history: Vurp produces itself.
        assert(VurpColor(0,Horse|3) == (Horse|3));
        assert(VurpColor(5,3) == 5);
        assert(VurpColor(5,Horse|3) == (Horse|5));
        assert(VurpColor(Horse|5,3) == (Horse|5)); // Never lose a remembered horse bit.
        assert(VurpColor(Horse|5,Horse|3) == (Horse|5));
        assert(VurpColor(14,3) == 0 && VurpColor(Horse|14,3) == 0);
        assert(VurpColor(-1,3) == 0 && VurpColor(5,0x1003) == 0);
        assert(VurpColor(5,14) == 0 && VurpColor(5,0) == 0);
    }
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
