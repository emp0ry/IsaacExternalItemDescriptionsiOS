# Isaac External Item Descriptions for iOS

The first publicly released native gameplay mod for **The Binding of Isaac:
Repentance on iOS**. It displays item descriptions inside the game without the
desktop Lua mod API.

![External Item Descriptions running in native iOS Repentance](docs/images/eid-gameplay.png)

The project supports three loading modes from the same ARM64 code:

| Device | Release file |
| --- | --- |
| Jailbroken iPhone or iPad | `IsaacExternalItemDescriptions-rootless.deb` |
| Non-jailbroken iPhone or iPad | `IsaacExternalItemDescriptions-Embedded.zip` |
| LiveContainer private app | `IsaacExternalItemDescriptions-LiveContainer.framework.zip` |

The standalone dylib uses public iOS frameworks and does not link against
ElleKit, Substrate, libhooker, or any jailbreak runtime. The rootless package
uses ElleKit only as a loader.

## Features

- Native in-game overlay with no external application or server
- All 20 languages currently exposed by the original EID language manager,
  with English fallback for untranslated Repentance entries
- Collectibles, trinkets, cards, runes, known pills, horse pills, and Crane
  Game prizes
- Original collectible, trinket, and card artwork from the installed game
- One consistent white icon for identified pills
- Descriptions for previously held cards after they are dropped
- Spoiler protection for untouched cards, unidentified pills, and Curse of the
  Blind pedestals
- Bottom-right, menu-only settings button with a native 20-language picker
- Transparent text-only layout with configurable horizontal and vertical
  position (140 px from the left and 50 px from the top by default)
- Safe executable-version gate and read-only native entity snapshots

## Compatibility

This release targets the ARM64 App Store build with bundle identifier
`com.Nicalis.Isaac-iOS` and Mach-O UUID:

```text
F4357753-A25F-30EE-BACF-63709F902895
```

Native layouts can change between game updates. An unknown executable UUID is
rejected before entity memory is scanned, so an unsupported build shows no
overlay instead of risking a crash.

## Installation

### Jailbroken devices

Install `IsaacExternalItemDescriptions-rootless.deb` with a package manager or
with `dpkg`, then restart Isaac. The package targets rootless ElleKit layouts.

### Non-jailbroken devices

Extract `IsaacExternalItemDescriptions-Embedded.zip`. Place its dylib and
`IsaacEID.bundle` in the app's `Frameworks` directory, add this Mach-O load
command to the main executable, and sign the complete app bundle:

```text
@executable_path/Frameworks/IsaacExternalItemDescriptions.dylib
```

The dylib requires no JIT, executable-memory entitlement, daemon, or jailbreak
filesystem access. The included patcher automates the bundle and Mach-O changes:

```sh
./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

Signing is intentionally separate. See [Installation](docs/INSTALL.md) for the
available signing variables and important app-signing limitations.

### LiveContainer private app

Extract `IsaacExternalItemDescriptions-LiveContainer.framework.zip`, import the
framework into an app-specific LiveContainer tweak folder, and select that
folder in Isaac's settings. Isaac must be a private app, and both **Don't Inject
TweakLoader** and **Don't Load TweakLoader** must remain disabled. See the
[LiveContainer instructions](docs/INSTALL.md#livecontainer-private-app) for the
complete click-by-click setup.

LiveContainer changes a guest executable from `MH_EXECUTE` to `MH_DYLIB`. EID
therefore identifies the loaded Isaac image by its exact verified UUID rather
than assuming the process's first executable image is the game. The same UUID
gate and read-only layout checks remain active.

## Description database

The dylib can read Isaac's installed item metadata without extra files. The
original EID language packs can be generated locally from an existing
[External Item Descriptions](https://github.com/wofsauge/External-Item-Descriptions)
checkout:

```sh
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
```

The importer combines the upstream `ab+` base tables with the standard
Repentance `rep` overrides and includes every available language. The installed
iOS 1.4 executable identifies itself as `Repentance v1.7.9b.J754`, so the
correct Steam-equivalent dataset is **Repentance (`rep`)**, not Repentance+.

The complete 20-language database is bundled in the rootless package,
LiveContainer framework, and embedded archive. It is also published as
`descriptions.json` for advanced/manual installations. The database is derived
from the original EID project and distributed with permission from its author;
see [Third-party notices](THIRD_PARTY_NOTICES.md).

## Build

Requirements: macOS, Xcode, Python 3, `dpkg-deb`, and an iOS SDK.

```sh
make test
make dylib EXTRA_CFLAGS='-Wall -Wextra -Werror'
make package EXTRA_CFLAGS='-Wall -Wextra -Werror'
make livecontainer EXTRA_CFLAGS='-Wall -Wextra -Werror'
make audit
```

Create clean public release artifacts in `dist/`:

```sh
make release
```

The release target includes the attributed all-language description database
in every packaged loading mode.

## Technical notes

The iOS build does not expose Isaac's desktop Lua API. This implementation
resolves the native pickup, player, and slot types in the main executable,
takes bounded read-only snapshots of the fixed entity pool, and renders the
nearest eligible pickup through UIKit.

Verified native layouts are documented in
[Native layout](docs/NATIVE_LAYOUT.md). Current device and packaging coverage
is recorded in [Test matrix](docs/TEST_MATRIX.md).

## Credits and legal

Special thanks to **wofsauge and every External Item Descriptions contributor**
for the original mod, its descriptions, translations, markup, and years of
maintenance. Visit the original
[GitHub project](https://github.com/wofsauge/External-Item-Descriptions) or
[Steam Workshop mod](https://steamcommunity.com/sharedfiles/filedetails/?id=836319872).
This iOS bridge would not exist without their work.

The bundled description text and translations come from the original External
Item Descriptions project and remain credited to wofsauge and its contributors.
Item artwork is loaded at runtime from the installed game and is never stored
in this repository.

This is an unofficial project and is not affiliated with Nicalis, Edmund
McMillen, Valve, or the External Item Descriptions maintainers. No game files,
DLC, receipts, or purchase bypasses are distributed. Project source code is
available under the [MIT License](LICENSE). The attributed upstream description
data is covered separately in [Third-party notices](THIRD_PARTY_NOTICES.md).
