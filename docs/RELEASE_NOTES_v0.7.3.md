# Isaac External Item Descriptions iOS v0.7.3

This maintenance release fixes EID interface touch handling in LiveContainer.

## Fixes

- Restores the proven single-window pass-through overlay architecture used by v0.6.1.
- EID settings, sliders, language selection, pause inventory, rows, and close buttons receive touches again.
- Touches outside visible EID controls continue directly to Isaac.
- Does not create a second `UIWindow` and does not insert EID views into the game controller hierarchy.
- Supersedes the withdrawn v0.7.2 build.

## Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- Release downloads include the rootless package, standalone dylib, LiveContainer framework, embedded package, complete description database, and checksums.
- No Isaac IPA or copyrighted game bundle is included.
