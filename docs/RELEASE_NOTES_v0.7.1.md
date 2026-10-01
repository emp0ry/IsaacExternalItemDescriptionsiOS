# Isaac External Item Descriptions iOS v0.7.1

This maintenance release fixes startup input presentation, unidentified-pill localization, and small icon rendering.

## Highlights

- Prevents Isaac's virtual movement stick from remaining at the top-left position after launch.
- Starts EID only after the application becomes active and keeps the passive description layer outside the touch path.
- Attaches the settings and pause-inventory cards only while they are open.
- Shows the unidentified-pill title in the selected EID language, including with older imported description databases.
- Removes the redundant `?` body line from unidentified pills.
- Renders quality, battery, charge-number, and inline pixel-art icons sharply at the device's native display scale.
- Removes unused vertical space from title-only descriptions.

## Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- Release downloads include the rootless package, standalone dylib, LiveContainer framework, embedded package, complete description database, and checksums.
- No Isaac IPA or copyrighted game bundle is included.
