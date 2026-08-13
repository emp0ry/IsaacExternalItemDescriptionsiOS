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
