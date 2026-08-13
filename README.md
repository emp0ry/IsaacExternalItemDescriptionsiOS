# Isaac External Item Descriptions for iOS

The first publicly released native gameplay mod for **The Binding of Isaac:
Repentance on iOS**. It displays item descriptions inside the game without the
desktop Lua mod API.

The project supports two installation modes from the same ARM64 dylib:

| Device | Release file |
| --- | --- |
| Jailbroken iPhone or iPad | `IsaacExternalItemDescriptions-rootless.deb` |
| Non-jailbroken iPhone or iPad | `IsaacExternalItemDescriptions.dylib` |

The standalone dylib uses public iOS frameworks and does not link against
ElleKit, Substrate, libhooker, or any jailbreak runtime. The rootless package
uses ElleKit only as a loader.

## Features

- Native in-game overlay with no external application or server
- English and Russian descriptions
- Collectibles, trinkets, cards, runes, known pills, horse pills, and Crane
  Game prizes
- Original collectible, trinket, and card artwork from the installed game
- One consistent white icon for identified pills
- Descriptions for previously held cards after they are dropped
- Spoiler protection for untouched cards, unidentified pills, and Curse of the
  Blind pedestals
- Startup language selector that disappears during gameplay
- Transparent text-only layout positioned away from Isaac's left-side HUD
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

Place `IsaacExternalItemDescriptions.dylib` in the app's `Frameworks` directory,
add this Mach-O load command to the main executable, and sign the complete app
bundle:

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

## Description database

The dylib can read Isaac's installed item metadata without extra files. Full
English and Russian EID text can be generated locally from an existing
[External Item Descriptions](https://github.com/wofsauge/External-Item-Descriptions)
checkout:

```sh
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
```

The generated database is used automatically by local package and IPA builds.
It is ignored by Git and is not included in public release assets because the
upstream repository does not publish a redistribution license.

## Build

Requirements: macOS, Xcode, Python 3, `dpkg-deb`, and an iOS SDK.

```sh
make test
make dylib EXTRA_CFLAGS='-Wall -Wextra -Werror'
make package EXTRA_CFLAGS='-Wall -Wextra -Werror'
make audit
```

Create clean public release artifacts in `dist/`:

```sh
make release
```

The release target deliberately excludes locally imported description data.

## Technical notes

The iOS build does not expose Isaac's desktop Lua API. This implementation
resolves the native pickup, player, and slot types in the main executable,
takes bounded read-only snapshots of the fixed entity pool, and renders the
nearest eligible pickup through UIKit.

Verified native layouts are documented in
[Native layout](docs/NATIVE_LAYOUT.md). Current device and packaging coverage
is recorded in [Test matrix](docs/TEST_MATRIX.md).

## Credits and legal

Full description text is imported from the External Item Descriptions project
when supplied locally by the user. Item artwork is loaded at runtime from the
installed game and is never stored in this repository.

This is an unofficial project and is not affiliated with Nicalis, Edmund
McMillen, Valve, or the External Item Descriptions maintainers. No game files,
DLC, receipts, or purchase bypasses are distributed. Project source code is
available under the [MIT License](LICENSE).
