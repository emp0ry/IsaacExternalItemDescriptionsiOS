# Current effects and personal pause inventories

Use disposable runs and fully restart Isaac after installing the test build.
This update never invokes gameplay effects for inspection or edits saves.

## Void's already-absorbed actives

1. On an ordinary character, `giveitem c477`, then `spawnitem c78`.
   Charge Void normally if necessary; `spawnpickup 90.0` spawns a battery.
2. Use Void normally to absorb the Book of Revelations pedestal. Pause and open
   EID Items: Void remains in Collectibles, and Book of Revelations appears in
   **Absorbed by Void**, not as a physically held active.
3. Tap the absorbed book: its full localized description and Void source are
   shown. Merely viewing it must not use the book or consume Void charges.
4. Absorb another active (`c33`), and optionally a duplicate `c78`. The list
   follows native IDs and duplicate counts. Save/Continue must retain it.
5. Consumed single-use actives must follow the game's removal. Removing Void
   hides its list; no local history invents old effects.
6. Absorbing a passive such as Brimstone (`c118`) grants stats rather than
   storing its ability. It must not appear in **Absorbed by Void**.

## Physical collectible quantities

1. In a disposable run without Brimstone, use `giveitem c118` three times.
   Pause and open EID Items: there is one Brimstone row labeled `×3`.
2. Use `remove c118` once, then inspect again: the label becomes `×2`.
   Remove another copy: the single-copy row has no `×1` suffix. Removing the
   last copy removes its row; Save/Continue must retain the actual counts.
3. If the game permits two identical held actives, verify their quantity too.
   A single active must never read `×2` merely because both native inventory
   sources report it. Pocket actives follow the same rule.
4. Jacob/Esau and co-op inventories show only their selected player's counts.
   Temporary Modeling Clay effects and Void-absorbed actives must not inflate
   the physical quantity.

## Purity

1. `giveitem c407`, pause and inspect Purity in EID Items. The added line shows
   the current aura's stat bonus, not all four possibilities as a current bonus.
2. Take damage normally in this disposable run. While the aura is inactive,
   inspect again: the added line says inactive until the next room.
3. Enter another room and inspect: the new currently active bonus is shown.
4. `remove c407` removes its inventory entry. An uncollected Purity pedestal
   must not reveal the bonus it would randomly give.

## Modeling Clay

1. `spawntrinket t166`, pick it up and visit several rooms. Its effect is not
   guaranteed in every room; no-effect rooms keep the normal description.
2. When it grants an item, inspect the trinket in EID Items: the current item's
   title, icon and description appear with a Modeling Clay source line.
3. Enter another room: the effect must refresh, not remain stuck on an old item.
   The temporary item must not appear in the physical inventory/collection.
4. Drop the trinket normally: the owned row disappears. Repeat after Continue.

## Jacob/Esau and co-op

1. Choose Jacob/Esau normally. Have the brothers pick up different items,
   cards/trinkets, then pause and open EID Items.
2. Use the player selector: P1/Jacob and P2/Esau show their own collectibles,
   active slots, pockets, swallowed trinkets and transformation counters.
   Identical IDs in both inventories must not erase one entry.
3. Open the same item for each: ownership-dependent effects must use that player,
   not the partner (for example PHD, BFFS or Car Battery).
4. Repeat with native co-op if available, including two of the same character.
   No controls or commands are used to spawn extra players.
5. Verify pocket pills stay correctly identified for their owner; existing
   D Infinity, Bag of Crafting, pause backdrop and languages still work.
6. Continue/new run resets stale selections. Super Bum's merged familiar owner
   is not established per player in co-op; its row is omitted there rather than
   showing the global completion flag for everyone.

Host tests cover bounds, fallback, localization and personal context isolation.
Real gameplay acceptance is recorded separately after user checks.

## Build and installation record (2026-10-16)

- Host policy/context tests, 20-language rendering, importer/database and
  documentation checks passed. Strict ARM64 compilation, code-signature checks,
  LiveContainer packaging and the portable-dependency audit passed.
- A temporary read-only task probe confirmed the supported fields' baseline
  structure in the running Tainted Cain process. It was removed afterward.
  It did not apply effects, grant items, change player state or edit saves.
- Installed dylib and database hashes match the host files:
  `eb8c7d982b4e1705e30be3e37e3b084ed3fec85c3e080b20748debe13bd13efe`
  and `7c7bcb5ea9d1ab06a496f22f0a8a9503ade5da7f6d8e9d663edab69db9506f1a`.
- Previous files retained at
  `/var/tmp/IsaacEID-before-current-effects-01233d9a.dylib` and
  `/var/tmp/IsaacEID-before-current-effects-9fbc38e9.json`.
  Temporary uploads were removed. No game process was killed.
- The user subsequently reported the other features working and asked about
  absorbing passive Brimstone (expected to be absent) and missing duplicate
  quantities. This is user-reported acceptance, not an independent execution
  record of every nonzero-effect/Jacob-Esau/co-op scenario above.

## Quantity follow-up (2026-10-16)

- Added live physical-collectible quantities and list invalidation when counts
  change, with independent counts for each native player. Tests cover stacked
  passives, removals, active-slot overlap, bounds and per-player isolation.
- Host tests, strict ARM64 build, signature verification, LiveContainer package
  checks and portable-dependency audit passed. Installed dylib hash matches
  `511ca624bf96245bf71be7300cfbb3d27e14cba8f0a77976b3268977808cfce1`.
  The database is unchanged. Previous dylib retained at
  `/var/tmp/IsaacEID-before-inventory-counts-eb8c7d98.dylib`.
- Temporary installer removed; no saves were edited and no process was killed.
  A full restart and the quantity checks above await user verification.
