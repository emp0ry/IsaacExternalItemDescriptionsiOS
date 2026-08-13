# Isaac External Item Descriptions for iOS

Native ARM64 External Item Descriptions bridge for the iOS Repentance build of
The Binding of Isaac. The game does not expose the desktop Lua mod API, so this
project discovers native `IsaacRepentance::Entity_Pickup` objects and renders a
UIKit overlay from inside Isaac's process.

## Portability

The dylib links only public iOS system frameworks. The synchronization/injection
runtime is not used. Rootless ElleKit packaging is a development convenience;
the same dylib is intended to be embedded and signed inside a user-supplied IPA.

The currently supported executable UUID is
`F4357753-A25F-30EE-BACF-63709F902895`. Unknown builds fail closed instead of
scanning memory with unverified assumptions.

The validated offsets and current regression status are recorded in
[`docs/NATIVE_LAYOUT.md`](docs/NATIVE_LAYOUT.md) and
[`docs/TEST_MATRIX.md`](docs/TEST_MATRIX.md).
Installation and signing constraints are in [`docs/INSTALL.md`](docs/INSTALL.md).

## Build

```sh
make dylib
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
make package
make audit
```

Embed into a user-supplied, legally decrypted IPA without jailbreak runtime
dependencies:

```sh
EID_SOURCE=/path/to/External-Item-Descriptions \
  ./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

The unsigned output can be signed by a normal sideloading workflow, or set
`SIGNING_IDENTITY` (and optionally `ENTITLEMENTS`) for local `codesign`.

The original EID repository currently has no license file. Its code and data are
therefore not vendored here. `tools/import-eid.py` lets a user import an existing
checkout into a local, git-ignored build artifact. All 732 collectibles, 189
trinkets, and 97 cards/runes are imported in both English and Russian, and the
in-game panel provides a persistent `EN / RU` switch. Without that import, the
overlay falls back to names, icons, and short descriptions from the installed
game's own `items.xml` files. Pills are intentionally omitted until the native
"identified pill" state can be checked, avoiding spoilers for unknown pills.
Collectible descriptions also fail closed when the native forced-blind flag or
question-mark spritesheet indicates a hidden pedestal.

## Development status

The portable overlay, bilingual item database, executable version gate, live
entity-pool resolver and nearest-pedestal selection are implemented. Device
inspection verified iOS entity identity, validity and position offsets. An
early allocator-enumeration prototype was removed; the current implementation
uses snapshot reads of the exact fixed entity pool. Do not treat the current
development package as a public release until embedded-mode regression testing
is complete.
