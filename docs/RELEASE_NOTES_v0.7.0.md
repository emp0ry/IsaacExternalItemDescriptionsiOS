# Isaac External Item Descriptions iOS v0.7.0

This release improves pickup parity, active-item presentation, and settings usability.

## Highlights

- Matches upstream EID visibility rules for cards, runes, Soul Stones, and identified pills, including shop, `Options?`, obstruction, and player-flight behavior.
- Fixes Curse of the Blind suppression by checking Isaac's native curse state before showing collectible information.
- Adds the original EID active-item battery and maximum-charge indicator.
- Supports normal room charges, timed-charge items, and special or dynamic charge items such as Blank Card, Placebo, Clear Rune, and D Infinity.
- Reads item type and charge metadata from the installed game's own Repentance resources, keeping the dylib portable across jailbreak, embedded, and LiveContainer loading.
- Preserves the normal title font size when the charge indicator is present.
- Makes the EID settings panel scrollable on smaller displays.
- Shows live percentage labels for Scale and Opacity.

## Compatibility

- The native memory layout remains limited to Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- No Isaac IPA or copyrighted game bundle is included.
