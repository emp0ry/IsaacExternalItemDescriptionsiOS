# Original EID parity target

The `dev` branch tracks the iOS port's work toward visual and behavioral parity with wofsauge/External-Item-Descriptions.

## Reference defaults

The desktop mod currently defaults to:

- `FontType = default`
- `TextboxWidth = 130`
- `Size = 1`
- `Transparency = 0.75`
- `XPosition = 60`, `YPosition = 45`
- `LineHeight = 11`
- `DisplayMode = default`, with local mode available
- `MarkupSize = default`
- item names, item type, item icon, descriptions, and quality enabled
- `ItemNameColor = ColorEIDObjName`
- quality rendered as a dedicated inline `Quality0` … `Quality4` icon, not by recoloring the title per quality

## iOS parity layers

1. **Presentation** — EID-style item-name color, outlined text, compact line spacing, opacity and scale.
2. **Markup** — replace emoji approximations with EID inline sprite icons and honor color markup.
3. **Metadata** — expose quality, item type/charge, transformations and pools where available.
4. **Options** — mirror applicable EID display settings in the iOS settings card.
5. **Modes** — retain the current fixed overlay and add local/near-item presentation where native coordinates are reliable.

The upstream EID repository remains the behavioral reference. Assets copied into distributable builds must retain upstream attribution and compatible licensing notices.
