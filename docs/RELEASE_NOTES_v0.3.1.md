# Isaac External Item Descriptions v0.3.1

This maintenance release fixes menu-only settings visibility in native iOS
Isaac: Repentance.

## Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

## Fixed

- The settings button now reliably disappears during gameplay.
- The settings button returns after Isaac reaches a menu.
- Player discovery no longer remains cached on the inactive main-menu player
  allocation when the active run uses a different heap region.

## Device validation

Validated in the real native iOS Isaac application by transitioning from the
main menu into a running save and back through menu/game state changes. The
standalone dylib remains independent of jailbreak runtime libraries.

## Credits

Special thanks to **wofsauge** and every contributor and translator of the
original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions).
The bundled description database is included with permission and attribution.
