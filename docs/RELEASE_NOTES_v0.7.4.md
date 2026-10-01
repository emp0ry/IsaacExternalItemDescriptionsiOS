# Isaac External Item Descriptions iOS v0.7.4

This release fixes card-family artwork so it matches the original EID mapping.

## Fixes

- Correct icons for all 17 Soul Stones.
- Correct icons for Rune Shard and Cracked Key.
- Cards, runes, Soul Stones, and related pocket items now use the original EID rule: `Card ID - 1` selects the matching frame.
- Removes the invalid native pickup-sheet fallback that could display unrelated artwork.

## Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of jailbreak-only runtimes.
- Includes rootless, standalone dylib, LiveContainer, and embedded distributions.
- No Isaac IPA or copyrighted game bundle is included.
