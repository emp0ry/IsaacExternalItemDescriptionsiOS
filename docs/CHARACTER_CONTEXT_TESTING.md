# Character context acceptance checks

Use disposable runs, not a progression run. Commands below are for the separate
Isaac Debug Console iOS mod. Choose the character in Isaac's normal menu and run
each command separately. Stand near the spawned pedestal without taking it.
Test English and Russian, and leave/re-enter pause to check the item reminder.

| Character | Commands | Expected description |
| --- | --- | --- |
| Cain, Azazel, Lilith or Forgotten | `spawnitem c600` | Eye Drops adds the character's 1.2 fire-rate multiplier. Ordinary Isaac does not get that note. |
| Tainted Samson | `spawnitem c596` | Uranus warns that freezing an enemy does not count as killing it. Normal Samson has no character note. |
| Keeper | `spawnitem c135` | IV Bag says 0–1 coin. Do not use it to test the tooltip. |
| Any tainted character except Tainted Cain's salvage context | `spawnitem c482` | Clicker explains changing into another tainted character. Ordinary Isaac/Esau do not get it. |
| ??? | `spawnitem c81` | Dead Cat explains the non-red-health result. Do not take it to test the tooltip. |
| Lilith, then Tainted Lilith in another run | `spawnitem c247` | BFFS! mentions doubled Incubus, respectively Gello, damage. |
| Bethany | `spawnitem c35`; `spawnitem c164`; `spawnitem c636` | Necronomicon shows wisp stats/effects; The Candle marks a single-room wisp; R Key says no wisps. Do not activate R Key. |
| Judas or Black Judas | `spawnitem c133`; inspect; `giveitem c619`; inspect again | Guppy's Paw gains the passive Belial +0.5 damage note only after Birthright. The log must report `native passive Belial ... enabled 1`; hidden collectible 59 need not exist in the raw inventory. |
| Tainted Cain | `spawnitem c25`; inspect; `giveitem c619`; inspect again | Breakfast changes to salvage information, from 3–8 to 6–16 pickups; no Guppy/other collectible transformation row. |
| Tainted Cain | `spawntrinket t42`; pick it up; inspect `spawnitem c25` | Lucky Toe adds the bonus-pickup note, doubled with Birthright. |
| Tainted Cain | `spawnitem c327` | Polaroid is a quest item and keeps its ordinary description, not salvage. |

For Tainted Cain, repeat the ordinary-pedestal test in a Devil Room, Angel Room
and Secret Room. The guaranteed pickup line must follow the native room pool,
not a guessed room name. Error Rooms have no guaranteed-room prediction. Test
Death Certificate and Cantripped only in separate disposable runs: those must
retain ordinary item descriptions.

Co-op acceptance, if available: Isaac and The Lost looking at a flight pedestal
must get the closest player's effect plus a localized difference notice. Change
the closest player and check that the base description switches. Two characters
of the same type must not borrow each other's Birthright/trinkets for salvage.

Known scope: the pause inventory list remains aggregated, though conditional
ownership is scoped to the primary player. Book of Virtues pedestal previews
include all owned actives, not just the selected primary slot. Void-absorbed
actives, full twin/subplayer presentation, and seeded salvage drops are not
implemented. Host tests are not a substitute for these gameplay checks.

## Device acceptance status (2026-10-14)

- Native startup, resource loading and character/room context reads were verified.
- The Judas test exposed a real raw-inventory mismatch: Birthright removed active
  Book of Belial (34), but hidden passive 59 was absent from the count table. The
  effective-ownership fix follows the native HasCollectible branch and has been
  installed. The user confirmed the corrected Judas + Birthright tooltip in game.
- Tainted Cain and Tainted Lilith are not unlocked on the test account. Their
  gameplay acceptance checks remain pending. No unlock or save modification is
  performed to make those tests available.
