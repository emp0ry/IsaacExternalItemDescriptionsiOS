# Isaac External Item Descriptions iOS v0.5.0

This release expands the native iOS overlay beyond pickup descriptions and fixes several gameplay-state bugs found during on-device testing.

## Highlights

- Curse of the Blind now hides every collectible description while the native curse flag is active.
- Dice Rooms show the effect for the current floor face.
- Sacrifice Rooms show the next payout and the live sacrifice step.
- Transformation progress now comes from the player's real owned collectibles instead of temporary pickup observations.
- Cards, runes, and pills use the correct icon frame.
- Card/rune knowledge and transformation history reset reliably when a new run starts.
- Long room headings remain complete on one line, without EID markup brackets.
- Item descriptions now disappear as one clean transition when the item is collected.

The release includes the standalone ARM64 dylib, rootless ElleKit package, LiveContainer framework, embedded package, complete 20-language description database, and SHA-256 checksums.

The supported Isaac executable UUID remains `F4357753-A25F-30EE-BACF-63709F902895`.
