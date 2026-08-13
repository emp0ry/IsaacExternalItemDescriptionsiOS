# Installation

## Jailbroken/rootless

Build and install the rootless package:

```sh
make EID_SOURCE=/path/to/External-Item-Descriptions descriptions
make package
```

The package uses ElleKit only to place and inject the dylib. The dylib does not
link ElleKit, Substrate, libhooker, or any rootless filesystem library.

## Embedded IPA

Start with a user-provided, legally decrypted Isaac IPA:

```sh
EID_SOURCE=/path/to/External-Item-Descriptions \
  ./tools/patch-ipa.sh Isaac.ipa Isaac-EID.ipa
```

The patcher verifies the Isaac bundle identifier, rejects encrypted input,
copies the dylib and local description database into `Frameworks`, and adds:

`@executable_path/Frameworks/IsaacExternalItemDescriptions.dylib`

If no `SIGNING_IDENTITY` is set, the output is intentionally unsigned for a
separate sideloading/signing workflow. The dylib requires no JIT, executable
memory, private entitlement, daemon, or jailbreak path.

Re-signing an App Store application can change its application identifier,
Keychain access groups, container selection, and receipt validation. Those are
properties of the chosen signing/install workflow, not features this project
bypasses. This project does not modify StoreKit, receipts, purchases, or DLC
checks. Back up the application's data container before replacing an existing
installation.

## Description data

The upstream EID repository currently does not provide a license file, so its
data is not committed or shipped from this source repository. The importer
creates a local ignored database from a checkout supplied by the user. The
installed game remains the source of item art.
