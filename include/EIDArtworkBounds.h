#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    size_t x, y, width, height;
    bool found;
} EIDArtworkBounds;

// Bounds in the same pixel coordinate system as the RGBA bitmap/CGImage.
static inline EIDArtworkBounds EIDVisibleArtworkBounds(const uint8_t *rgba, size_t length,
    size_t width, size_t height, size_t bytesPerRow) {
    EIDArtworkBounds result = {0,0,0,0,false};
    if (!rgba || !width || !height || width > SIZE_MAX/4 || bytesPerRow < width*4 ||
        height > SIZE_MAX/bytesPerRow || length < height*bytesPerRow) return result;
    size_t left = width, top = height, right = 0, bottom = 0;
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            if (rgba[y*bytesPerRow+x*4+3] <= 8) continue;
            result.found = true;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
        }
    }
    if (result.found) {
        result.x = left; result.y = top;
        result.width = right-left+1; result.height = bottom-top+1;
    }
    return result;
}
