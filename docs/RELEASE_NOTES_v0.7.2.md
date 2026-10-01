# Isaac External Item Descriptions iOS v0.7.2

This maintenance release isolates the EID interface from LiveContainer's host view hierarchy.

## Highlights

- Detects when the verified Isaac executable is loaded as a LiveContainer guest dylib.
- Uses a transparent pass-through overlay window that cannot become the key window.
- Avoids adding EID views to LiveContainer's game-hosting controller hierarchy, preventing interference with Isaac's virtual movement stick initialization.
- Leaves normal jailbreak injection and directly embedded application loading unchanged.

## Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- Release downloads include the rootless package, standalone dylib, LiveContainer framework, embedded package, complete description database, and checksums.
- No Isaac IPA or copyrighted game bundle is included.
