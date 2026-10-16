# Description rendering

Version 1.0.0 uses the original External Item Descriptions bitmap fonts, PNG
pages, glyph metrics, kerning and ANM2 sprite geometry rather than a system
description font. The behavioral and resource reference is upstream revision
`8b59d00c6828e333294639ad2b2b6875eae821cb` (EID V5.25).

The port retains original title colors, quality symbols, transformation rows,
active-item type and normal/timed/special charge indicators, inline icon widths
and offsets, indentation and word wrapping. Localized unknown pills use the
separate red-title path and a question-mark overlay. The single-use banner is
added by a modifier using upstream's exact 13-item Repentance allowlist.

The importer compiles the original fully automated modular descriptions from
literal item data, standard-Repentance overrides, language templates and module
priorities. It preserves the original allowlist and language-specific opt-outs.
No Lua runtime or arbitrary upstream callback is executed in the application.

Stat icons after arrows intentionally default to on at the project owner's
request, unlike desktop EID's default. Other retained iOS defaults are a
140-pixel horizontal offset and 50-pixel vertical offset. Text width can grow
from its original language-specific width to 300%, bounded by screen space.

The renderer draws through public CoreGraphics in Isaac's existing UIKit
overlay. It adds no window, executable-memory allocation, JIT or synthetic
joystick input. Settings and the pause inventory remain native UIKit and follow
the selected description language. Individual slider resets affect only their
own saved setting.

## Build checks

`make release EID_SOURCE=/path/to/External-Item-Descriptions` stages matching
fonts and resources, builds the ARM64 library and packages all loading formats.
`make original-check` resolves every static icon, exercises all base and modular
description layouts across 20 languages, and audits bundled markup. These
checks run in the single public build workflow without uploading local tests.

Signed floating-point bullet coordinates and finite panel bounds prevent
off-screen layouts. Empty content cannot enable a background; invalid layouts
fall back to the established renderer. Pause temporarily adds readable contrast
without overwriting gameplay preferences.

## Limits and attribution

Identical source fonts and layout rules do not prove pixel-identical output
across different viewport scaling and graphics backends. Animated colors use a
read-only overlay clock rather than a hooked native game frame counter.
Unreviewed dynamic Lua icon callbacks, mod-added artwork and optional desktop
display modes are not executed. Native item artwork is read from the installed
game and is not included in release packages.

All EID descriptions, fonts, visual resources and ported algorithms retain
their upstream attribution. See [third-party notices](../THIRD_PARTY_NOTICES.md)
and [the original EID project](https://github.com/wofsauge/External-Item-Descriptions).
