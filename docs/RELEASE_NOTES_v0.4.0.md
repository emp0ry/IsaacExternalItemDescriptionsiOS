# Isaac External Item Descriptions v0.4.0

This release brings the iOS port much closer to the presentation and behavior of the original External Item Descriptions mod.

## Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **All release files together:** `IsaacExternalItemDescriptions-Full-Build.zip`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

## What's new

- Closer original EID-style presentation with purple item titles and improved layout.
- Item artwork integrated into the description header.
- Original Q0-Q4 quality icons and collectible quality metadata.
- Original transformation icons and transformation membership metadata.
- Temporary per-run transformation progress such as `(1/3)`, with duplicate collectible protection and a `3/3` cap.
- Transformation progress resets when leaving the current run and starting/restarting a run.
- Transformation names now follow the selected EID language with English fallback.
- Improved inline EID icon and color markup rendering.
- Full packaged EID description database and presentation resources included in release builds.
- Rootless, LiveContainer, embedded, standalone dylib, description database, and checksum packages are generated together.

## Known bugs

- **Curse of the Blind:** item descriptions can still appear for hidden collectible pedestals.
- **Rune icons:** the current rune artwork can show the complete rune sprite sheet instead of the specific rune icon.
- **Pill icons:** identified pills do not yet use the exact pill appearance from the current game pickup; the current static/incorrect pill artwork needs to be replaced with the matching in-game pill icon.

## Notes

Transformation progress is currently tracked heuristically during the active run. Exact player-inventory based transformation progress is planned once the native collectible ownership state/function is mapped.

## Credits

Special thanks to **wofsauge** and every contributor and translator of the original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions).
The bundled description database and EID presentation resources are included with attribution.
