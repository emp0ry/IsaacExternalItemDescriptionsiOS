# Isaac External Item Descriptions v0.3.0

This release adds a native settings interface, all 20 upstream EID languages,
and complete attributed description data in every packaged loading mode.

![EID running in native iOS Repentance](https://raw.githubusercontent.com/emp0ry/IsaacExternalItemDescriptionsiOS/v0.3.0/docs/images/eid-gameplay.png)

## Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

## What's new

- Added a bottom-right settings button that is visible in Isaac's menus and
  automatically hides during a run.
- Added a reliable native language picker for all 20 EID languages.
- Added persistent horizontal and vertical description positioning, defaulting
  to 140 px from the left and 50 px from the top.
- Removed the startup information banner.
- Added English fallback for untranslated Repentance entries.
- Bundled the standard Repentance 1.7.9b (`rep`) description database in the
  rootless package, LiveContainer framework, and embedded archive.
- Added in-app credits and third-party attribution.

## Credits

Special thanks to **wofsauge** and every contributor and translator of the
original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions)
and [Steam Workshop mod](https://steamcommunity.com/sharedfiles/filedetails/?id=836319872).
The description database is bundled with permission from the original EID
author. This iOS bridge would not exist without their work.

## Device validation

Validated in the real native iOS Isaac application:

- Rootless dylib injection and clean bootstrap.
- Menu-only settings visibility and automatic hiding during gameplay.
- Language changes during a running game (`ru` → `fr` → `en_us` → `ru`).
- Horizontal and vertical description positioning with 140/50 px defaults.
- All-language Repentance 1.7.9b database loading.
- No new Isaac crash report.

The standalone dylib continues to link only public Apple frameworks and libc++;
it has no ElleKit, Substrate, libhooker, or other jailbreak-runtime dependency.
