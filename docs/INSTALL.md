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

If a local description database exists in `build/IsaacEID.bundle`, a normal
local package build includes it automatically.

## Non-jailbroken/embedded

The release dylib belongs at:

```text
Payload/Isaac.app/Frameworks/IsaacExternalItemDescriptions.dylib
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

If `build/IsaacEID.bundle/descriptions.json` exists, the local framework embeds
that database under its own `Resources` directory. A public release build omits
locally imported description text.

## Signing limitations

Re-signing an App Store application can change its application identifier,
Keychain access groups, data-container selection, and receipt validation. Those
results depend on the signing and installation workflow.

This project does not alter StoreKit, receipts, DLC ownership, or purchase
checks. Back up the application's data before replacing an existing install.

## Full description data

Generate the optional English/Russian database from a local External Item
Descriptions checkout:

```sh
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
```

The next local package or patched IPA automatically includes the generated
database. The public release artifacts omit this database because its upstream
repository does not provide a redistribution license.
