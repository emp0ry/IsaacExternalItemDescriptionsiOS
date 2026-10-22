#pragma once
#include <math.h>

enum { EIDMaximumScalePercent=400 };
static inline double EIDClampScale(double value) {
    return isfinite(value) ? fmin(EIDMaximumScalePercent/100.,fmax(.5,value)) : 1;
}
