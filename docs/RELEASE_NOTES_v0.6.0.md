# Isaac External Item Descriptions iOS v0.6.0

This release adds a native pause inventory and fixes transformation progress
across save reloads and active-item replacement.

## Highlights

- A top-left **EID Items** button now appears while a run is paused.
- The pause browser lists current collectibles, active items, trinkets, held
  cards and runes, identified pills, and all 15 transformations.
- Selecting an inventory entry displays its full localized EID description.
- The complete **EID ⚙** settings panel is now available while paused and hides
  again when gameplay resumes.
- The 14 standard transformations use Isaac's persisted native PlayerForm
  counters, preserving real progress after replacing an active item or
  reopening a save.
- Super Bum completion is detected from the native merged familiar.
- Pause, inventory, trinket-slot, pocket-slot, and transformation layouts were
  verified against iOS executable UUID
  `F4357753-A25F-30EE-BACF-63709F902895` and tested in the real game.

The release includes the standalone ARM64 dylib, rootless ElleKit package,
LiveContainer framework, embedded package, complete 20-language description
database, and SHA-256 checksums. No Isaac IPA or game data is distributed.
