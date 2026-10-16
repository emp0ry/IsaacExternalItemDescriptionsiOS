# Food and familiar conditionals

Use a disposable run for console commands. Installing this update does not
change saves; fully restart Isaac afterward. English/Russian descriptions use
the upstream standard-Repentance tables with normal English fallback.

## Binge Eater

1. `spawnitem c25`: Breakfast should initially have its ordinary description.
2. `giveitem c664`: the same pedestal gains +2.5 range, +0.2 shot speed,
   temporary +3.6 damage and -0.03 speed. For a red-heart character the healing
   changes from one to two hearts.
3. `remove c664`: the bonuses disappear without restarting the run.
4. Repeat with food IDs `22`, `23`, `24`, `26`, `346`, `456`, `707`.
   Each has its own bonuses, not a shared guessed stat pair.
5. Tainted Bethany's food conversion changes from four to six blood charges.
   Lost and other non-red-heart characters must retain their health protections.
6. Keep Binge Eater, `spawnitem c118`, and stand near the pedestal without
   picking it up. The title, icon, transformation and detail must follow the
   currently visible Brimstone/food on every switch, without the previous
   half-cycle's description. Repeat with several pedestals and move between
   them. Taking an item or leaving the room must not retain its old description.
7. Optional: Soul of Isaac's short cycle follows the same live-ID path. Glitched
   Crown keeps its tap-to-browse inspection behavior rather than following its
   rapidly rotating sprite. Blind pedestals remain hidden.

## BFFS! / Hive Mind

1. `spawnitem c8`, then `giveitem c247`: Brother Bobby's damage changes 3.5 -> 7.
2. `remove c247`, then `giveitem c248`: Brother Bobby must not receive a
   Hive Mind bonus.
3. `spawnitem c629`: Bot Fly changes 3 -> 6 with Hive Mind. `giveitem c247`
   must not change it to 12; both upgrades share the same familiar bonus.
4. `spawnitem c10` with BFFS: Halo of Flies displays the original no-effect
   warning. Repentance Holy Water (`c178`) must not get the obsolete AB+ warning.
5. `spawntrinket t54`, `spawncard 96`: supported familiar trinkets and Soul of
   Bethany show their BFFS changes too, once normal visibility permits them.
6. On a separate run `giveitem c403`, then `spawnitem c247` / `spawnitem c248`:
   upgrade pedestals explain Spider Mod's relevant bonus. These pedestal-only
   hints are suppressed when inspecting an already-owned upgrade in EID Items.

## Forgotten Lullaby

1. `giveitem c713`, `spawntrinket t141`: the trinket description includes clots.
2. `giveitem c584`: the trinket also warns that it does not boost Book of Virtues
   wisps. With Lullaby held, a `spawnitem c584` pedestal shows the same exception
   in the reverse direction.
3. Repeat exceptions with Jar of Wisps (`c685`), Vengeful Spirit (`c702`) and
   Gello (`c728`). Ordinary supported familiars must not get these exceptions.
4. Existing Lilith/Incubus and Tainted Lilith/Gello character notes still work.

Check removal/reacquisition, Continue/new-run transitions and EID Items. Merely
viewing descriptions must not change stats, inventory, room objects or RNG.
Host regression tests are separate from device acceptance of the new effects.

## Build and installation record (2026-10-16)

- Host policy/context tests, 20-language rendering tests, importer/database
  checks and documentation checks passed. ARM64 builds with
  `-Wall -Wextra -Werror`, strict code-signature verification, LiveContainer
  packaging tests and the portable-dependency audit passed.
- Installed on the development iPhone using atomic file replacement. The
  installed dylib and database hashes were verified against the host files.
  No game process was killed, no console commands were executed on the user's
  run, and no save files were changed.
- Dylib SHA-256: `e1e30e51562ddc32f91274d9eabe316c0e0be874ecc66971a5671e81f14e2822`.
- Database SHA-256: `9fbc38e9b757fae4a65f8770ea74ddaa0d034fa58749562c6ec93a430461f1a0`.
- Previous dylib/database retained at
  `/var/tmp/IsaacEID-before-food-familiars-20261016-1628.{dylib,json}`.
  Temporary upload files were removed. In-game acceptance is pending a full
  restart and the user's disposable-run checks above; installation alone does
  not establish that those scenarios passed on device.

### Short-cycle refresh follow-up

The user confirmed the food/familiar changes, but reported Binge Eater's
pedestal description lagging behind its rotating sprite. The follow-up removes
that dependency on the asynchronous 250 ms scanner: a display-link callback
revalidates only the selected short-cycle pedestal, and redraws only on a
changed identity/context. Background results are revalidated on the main thread
before rendering as well. Current subtype is authoritative, never the queued
alternate; the five-item Crown browser remains separate.

The host suite, strict ARM64 build, packaging and dependency/signature checks
passed again. The installed dylib was verified as SHA-256
`01233d9a7c12128e3a7c2d8c4f5a7fbee9068b103665ec0e6b3c798078921116`.
The description database is unchanged. The preceding dylib is retained at
`/var/tmp/IsaacEID-before-live-pedestal-e1e30e51.dylib`; the temporary upload was
removed. Visual acceptance of the switching fix remains pending a full restart
and the user's check of scenarios 6-7. No gameplay commands or save changes
were performed during installation.
