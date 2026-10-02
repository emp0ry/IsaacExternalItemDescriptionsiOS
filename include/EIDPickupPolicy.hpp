#pragma once

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace EIDPickupPolicy {

constexpr int32_t kCardVariant = 300;
constexpr int32_t kPillVariant = 70;
constexpr int32_t kHorsePillVariant = 1070;
constexpr int32_t kUnidentifiedPillVariant = 2070;
constexpr int32_t kFirstSoulStoneSubtype = 81;
constexpr int32_t kLastSoulStoneSubtype = 97;
constexpr int32_t kMaximumWalkableGridPath = 900;
constexpr size_t kMaximumRoomGridCells = 0x1c0;

inline bool DecodeNativeCanFly(uint8_t value, bool& canFly) {
    if (value == 0) {
        canFly = false;
        return true;
    }
    if (value == 1) {
        canFly = true;
        return true;
    }
    canFly = false;
    return false;
}

inline bool IsSoulStone(int32_t variant, int32_t subtype) {
    return variant == kCardVariant && subtype >= kFirstSoulStoneSubtype &&
        subtype <= kLastSoulStoneSubtype;
}

inline bool IsPill(int32_t variant) {
    return variant == kPillVariant || variant == kHorsePillVariant ||
        variant == kUnidentifiedPillVariant;
}

// Mirrors original EID's default card/rune/pill visibility settings. Touched is
// intentionally absent: ordinary floor cards are identified when reachable,
// shop cards stay hidden, while shop Soul Stones and shop pills are shown.
inline bool ShouldRevealFloorIdentity(int32_t variant, int32_t subtype,
                                      bool isShopItem, int32_t optionsPickupIndex,
                                      bool hasReachablePath) {
    if (variant == kCardVariant) {
        const bool soulStone = IsSoulStone(variant, subtype);
        if (optionsPickupIndex > 0) return false;
        if (isShopItem && !soulStone) return false;
        return soulStone || hasReachablePath;
    }
    if (IsPill(variant)) {
        // Original defaults show purchasable and Options? pills, but not pills
        // that require breaking obstacles or flight to reach.
        return hasReachablePath;
    }
    return true;
}

struct GridPoint {
    int32_t row = -1;
    int32_t column = -1;
};

inline bool WorldToGrid(float x, float y, int32_t width, int32_t height,
                        GridPoint& point) {
    if (!std::isfinite(x) || !std::isfinite(y) || width <= 0 || height <= 0) return false;
    // Exact constants and rounding used by Room::GetGridIndex in the supported
    // ARM64 Isaac executable (UUID F4357753-A25F-30EE-BACF-63709F902895).
    const int32_t column = static_cast<int32_t>(((x - 40.0f) / 40.0f) + 0.5f);
    const int32_t row = static_cast<int32_t>(((y - 120.0f) / 40.0f) + 0.5f);
    if (column < 0 || row < 0 || column >= width || row >= height) return false;
    point = {row, column};
    return true;
}

inline bool IsWalkable(const int32_t *paths, size_t pathCount,
                       int32_t width, int32_t height, GridPoint point) {
    // These are the same wall-border checks as original EID's EvaluateLocation.
    if (!paths || point.row < 1 || point.column < 1 ||
        point.row >= height - 1 || point.column >= width - 1) return false;
    const int64_t index = static_cast<int64_t>(point.row) * width + point.column;
    return index >= 0 && static_cast<size_t>(index) < pathCount &&
        paths[index] <= kMaximumWalkableGridPath;
}

inline bool HasGridPath(const int32_t *paths, size_t pathCount,
                        int32_t width, int32_t height,
                        GridPoint start, GridPoint finish) {
    if (!paths || width < 3 || height < 3 ||
        static_cast<int64_t>(width) * height > static_cast<int64_t>(pathCount) ||
        !IsWalkable(paths, pathCount, width, height, finish)) return false;

    const GridPoint directions[] = {{0, -1}, {-1, 0}, {0, 1}, {1, 0}};
    bool hasOpenFinishNeighbour = false;
    for (const GridPoint& direction : directions) {
        GridPoint neighbour = {finish.row + direction.row,
                               finish.column + direction.column};
        if (IsWalkable(paths, pathCount, width, height, neighbour)) {
            hasOpenFinishNeighbour = true;
            break;
        }
    }
    if (!hasOpenFinishNeighbour) return false;

    std::array<uint8_t, kMaximumRoomGridCells> visited{};
    std::array<GridPoint, kMaximumRoomGridCells> queue{};
    size_t head = 0;
    size_t tail = 0;
    auto enqueue = [&](GridPoint point) -> void {
        if (point.row < 0 || point.column < 0 || point.row >= height || point.column >= width) return;
        const size_t index = static_cast<size_t>(point.row * width + point.column);
        if (index >= visited.size() || visited[index] || tail >= queue.size()) return;
        visited[index] = 1;
        queue[tail++] = point;
    };
    enqueue(start);

    while (head < tail) {
        const GridPoint current = queue[head++];
        if (current.row == finish.row && current.column == finish.column) return true;
        for (const GridPoint& direction : directions) {
            GridPoint neighbour = {current.row + direction.row,
                                   current.column + direction.column};
            if (!IsWalkable(paths, pathCount, width, height, neighbour)) continue;
            const size_t index = static_cast<size_t>(neighbour.row * width + neighbour.column);
            if (index >= visited.size() || visited[index] || tail >= queue.size()) continue;
            visited[index] = 1;
            queue[tail++] = neighbour;
        }
    }
    return false;
}

} // namespace EIDPickupPolicy
