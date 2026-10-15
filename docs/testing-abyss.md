# Abyss: standard Repentance device checklist

Use a disposable run. These console commands change gameplay and should not be
used on progress you want synchronized to Steam. EID itself only reads state.

Restart Isaac after replacing both the dylib and description database. In
LiveContainer, replace the app-specific framework and its resources together.
Do not remove the existing native-frame readiness fix or single-window overlay.

## Basic test

1. `giveitem c706` gives Abyss. This may replace the previous active item.
2. Spawn one test pedestal at a time and approach it without picking it up.
3. The final Abyss section uses its icon and red text in the selected EID language.
   It must not change transformation, collection, or Spindown information.

| Command | Expected Abyss information |
| --- | --- |
| `spawnitem c25` | Breakfast: 1 ordinary locust, 1x Isaac's damage |
| `spawnitem c2` | The Inner Eye: 3 locusts, each 1x damage |
| `spawnitem c153` | Mutant Spider: 4 locusts, each 1x damage |
| `spawnitem c4` | Cricket's Head: 1 big locust, 3x damage |
| `spawnitem c7` | Blood of the Martyr: 1 locust, 2x damage |
| `spawnitem c10` | Halo of Flies: 2 locusts, each 0.5x damage |
| `spawnitem c6` | Number One: 1 fast locust, 1x damage |
| `spawnitem c3` | Spoon Bender: homing |
| `spawnitem c103` | The Common Cold: poison |
| `spawnitem c149` | Ipecac: 1 big, slow locust, 1.5x damage; poison only |
| `spawnitem c257` | Fire Mind: burn |
| `spawnitem c374` | Holy Light: light beam on hit |
| `spawnitem c494` or `spawnitem c559` | Jacob's Ladder / 120 Volt: electricity on hit |
| `spawnitem c118` | Brimstone: big locust, 1x damage; no invented beam effect |

The regular Repentance Ipecac locust applies only the first tear flag (poison),
not the later explosive flag. Do not judge this build against Repentance+ videos:
that version has different locusts and quality-based damage scaling.

## Gameplay and regressions

- Use Abyss with only the current test pedestal present. It consumes all eligible
  pedestals in the room, so previous test spawns would make counting ambiguous.
  Compare the actual count and behavior, not only the tooltip text.
- `remove c706`: the Abyss section should disappear after the next refresh while
  the ordinary item description stays. Give it back and check the section returns.
- Pause and select a collectible in EID Items: original-style hypothetical locust
  information should be available. Cards, runes, pills and trinkets get no Abyss line.
- Check English/Russian, then another language. Untranslated entries use English;
  no raw `{amount}`, `{dmg}`, or pluralization placeholders should remain visible.
- Curse of the Blind and question-mark pedestals must still hide the entire
  collectible description. Changing item quality must not change locust damage.
- Check menu/settings buttons, both gameplay sticks and a LiveContainer cold launch.

## Recorded verification

- Read-only comparison: all 17 iOS `locusts.xml` entries match the pinned original
  EID standard-Repentance table, including Ipecac's ordered `[4, 12]` tear flags.
- Host checks exercise generated text, localization/fallback, all 17 records plus
  default behavior, chance precedence, first-flag-only behavior, item removal and
  personal ownership. These are not a substitute for the gameplay checks above.
- The user confirmed the installed Abyss build works before requesting the
  subsequent Wild Card / Vurp! update. This is user acceptance, not an automated
  assertion that every individual locust combination was exercised on-device.
