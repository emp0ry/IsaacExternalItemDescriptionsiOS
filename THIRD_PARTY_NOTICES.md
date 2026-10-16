# Third-party notices

## External Item Descriptions

The bundled `data/descriptions.json` database is derived from **External Item
Descriptions** by **wofsauge** and its contributors:

- GitHub: https://github.com/wofsauge/External-Item-Descriptions
- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=836319872

It contains their item descriptions, translations, and description markup for
The Binding of Isaac: Repentance. It is bundled in this project with permission
from the original EID author. Thank you to wofsauge and every translator and
contributor who built and maintained the original mod.

The MIT license in `LICENSE` applies to the IsaacExternalItemDescriptionsiOS
bridge source written for this repository. It does not claim authorship of the
upstream EID description text or translations.

The 1.0.0 renderer additionally uses EID's bitmap font
atlases/metrics and ports its rendering/layout algorithms from commit
8b59d00c6828e333294639ad2b2b6875eae821cb. Credit remains with wofsauge, EID
contributors and the original font creators (including PixelMplus). These
resources are not claimed as original bridge artwork or font designs.

PixelMplus is by itouhiro and the M+ FONTS PROJECT. Its upstream project
identifies the M+ FONT LICENSE; this bridge's MIT license does not relicense
the font. See https://github.com/itouhiro/PixelMplus for the original project.
Copyright (C) 2013 itouhiro. Copyright (C) 2002-2013 M+ FONTS PROJECT.
Language-specific EID font atlases retain their upstream names and attribution.

The modular description compiler ports the formatting/module-priority behavior
of `features/eid_modular_descriptions.lua` and the finite health transformations
of `features/eid_modular_data_modifiers.lua` from the same upstream revision.
Generated text, module data, plural forms and translations retain their original
EID attribution. No upstream Lua code executes inside the iOS application.
