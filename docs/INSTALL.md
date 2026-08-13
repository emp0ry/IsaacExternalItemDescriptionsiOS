# Installation

## Supported game build

- Bundle identifier: `com.Nicalis.Isaac-iOS`
- Architecture: ARM64
- Executable UUID: `F4357753-A25F-30EE-BACF-63709F902895`

The native layout is version-specific. Unsupported executables fail closed.

## Jailbroken/rootless

Download `IsaacExternalItemDescriptions-rootless.deb` from the matching GitHub
release and install it with a package manager or from a shell:

```sh
dpkg -i IsaacExternalItemDescriptions-rootless.deb
```

Restart Isaac after installation. ElleKit is used only to load the dylib into
the game process. The dylib itself has no jailbreak-library dependency.

To build the package locally:

```sh
make package
```

The release package includes the complete 20-language description database.
Local builds prefer a freshly generated database in `build/IsaacEID.bundle`
and otherwise use the bundled `data/descriptions.json`.

## Non-jailbroken/embedded

Extract `IsaacExternalItemDescriptions-Embedded.zip`. Its files belong at:

```text
Payload/Isaac.app/Frameworks/IsaacExternalItemDescriptions.dylib
Payload/Isaac.app/Frameworks/IsaacEID.bundle/descriptions.json
```

The main executable must contain:

```text
@executable_path/Frameworks/IsaacExternalItemDescriptions.dylib
```

The included patcher performs those changes:

```sh
./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

By default, the output is unsigned. To sign during patching:

```sh
SIGNING_IDENTITY='Apple Development: Example' \
  ./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

An entitlements file can be supplied when required by the chosen signing
workflow:

```sh
SIGNING_IDENTITY='Apple Development: Example' \
ENTITLEMENTS=/path/to/entitlements.plist \
  ./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

No JIT, private entitlement, executable-memory permission, background daemon,
or jailbreak path is required by the dylib.

## LiveContainer private app

Use the primary (Blue) LiveContainer and keep Isaac in private-app mode. Tweak
management is not available for shared apps.

1. Extract `IsaacExternalItemDescriptions-LiveContainer.framework.zip` in the
   Files app.
2. In LiveContainer, open **Tweaks**, create a new folder such as `IsaacEID`,
   enter it, and choose **Import Tweak**.
3. Import the extracted `IsaacExternalItemDescriptions.framework`.
4. Long-press Isaac, open **Settings**, and select `IsaacEID` under **Tweak
   Folder**.
5. Keep **Don't Inject TweakLoader** and **Don't Load TweakLoader** disabled.
6. If LiveContainer reports a signing problem, use **Force Sign** for the
   imported framework, then launch Isaac again.

The framework is app-specific and should not be placed in Global Tweaks. It
does not require ElleKit, Substrate, or a jailbreak library; LiveContainer's own
TweakLoader performs the load. Current upstream instructions for tweak folders
and app settings are available in the official
[LiveContainer tweak guide](https://livecontainer.github.io/docs/guides/tweaks)
and [app-settings guide](https://livecontainer.github.io/docs/guides/app-settings).

To build the private framework locally:

```sh
make livecontainer
```

The release framework embeds the attributed all-language database under its
own `Resources` directory. A local build prefers a freshly generated database
in `build/IsaacEID.bundle` and otherwise uses `data/descriptions.json`.

## Signing limitations

Re-signing an App Store application can change its application identifier,
Keychain access groups, data-container selection, and receipt validation. Those
results depend on the signing and installation workflow.

This project does not alter StoreKit, receipts, DLC ownership, or purchase
checks. Back up the application's data before replacing an existing install.

## Full description data

The release already includes the all-language database. To regenerate it from
an External Item Descriptions checkout:

```sh
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
```

The importer uses the standard Steam Repentance `rep` descriptions plus their
`ab+` base tables. This matches the native iOS 1.4 executable's embedded version
string, `Repentance v1.7.9b.J754`; do not use the newer Repentance+ dataset.

The next local package, LiveContainer framework, or patched IPA automatically
uses the regenerated database. The bundled text is distributed with permission
from the original EID author and attributed in `THIRD_PARTY_NOTICES.md`.
