#pragma once
#include <cmath>
#include <cstdint>

namespace EIDHostReadinessPolicy {
class Frames {
    uintptr_t window_ = 0, view_ = 0, link_ = 0;
    double timestamp_ = 0, width_ = 0, height_ = 0;
    unsigned frames_ = 0;
public:
    bool Observe(bool active, uintptr_t window, uintptr_t view, uintptr_t link,
                 double timestamp, double width, double height) {
        if (!active || !window || !view || !link || !std::isfinite(timestamp) || timestamp <= 0 ||
            !std::isfinite(width) || !std::isfinite(height) || height <= 0 || width <= height) {
            *this = Frames{};
            return false;
        }
        if (window != window_ || view != view_ || link != link_ || width != width_ || height != height_ || timestamp < timestamp_) {
            window_ = window; view_ = view; link_ = link; width_ = width; height_ = height;
            frames_ = 1;
        } else if (timestamp > timestamp_ && frames_ < 2) {
            ++frames_;
        }
        timestamp_ = timestamp;
        return frames_ >= 2;
    }
};
}
