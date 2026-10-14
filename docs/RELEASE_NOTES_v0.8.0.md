# Isaac External Item Descriptions iOS v0.8.0

A major contextual-description update for native iOS Repentance. Descriptions now
react to your character, inventory, game mode, and current floor, with many more
rules from the original External Item Descriptions mod.

## Character-aware descriptions

- Added Lost/Keeper no-effect and lethal-use warnings, health-type replacements,
  and character-specific Birthright descriptions.
- Added Eye Drops exceptions for Cain, Azazel, Lilith, Forgotten, and their
  applicable tainted variants; Tainted Samson/Uranus; Keeper/IV Bag; tainted
  Clicker; and Dead Cat's non-red-health behavior.
- Added Lilith/Tainted Lilith BFFS! descriptions for Incubus/Gello.
- Added localized co-op difference notices. Nearby descriptions follow the
  closest player; pause conditional checks use the primary player's inventory.
- Fixed character indexing: The Lost's Breakfast warning no longer names Eden,
  and Birthright entries now use the correct native character IDs.
- Fixed same-character co-op players sharing another player's personal
  Birthright/trinket conditions.

## Item, card, and weapon synergies

- Added the original standard-Repentance weapon override block: **335 rules**,
  with both "overrides" and "overridden by" warnings, weapon priorities, Azazel,
  and special combination text rather than generic no-effect warnings.
- Includes Dr. Fetus/Trisagion, Epic Fetus, Brimstone, Mom's Knife, Tech X,
  C Section, Spirit Sword, and the other combinations in that block.
- Added **Car Battery** active-item descriptions, numeric buffs, special effects,
  and no-synergy cases. Its pedestal summary is omitted in the pause reminder,
  matching the original mod.
- Added **Tarot Cloth** card-effect descriptions using standard Repentance data,
  not Repentance+ values.
- Fixed ordered numeric replacements so decimals and repeated values are not
  accidentally changed twice or partially matched.
- Contextual tooltips refresh when inventory changes even if Isaac stays still.

## Book of Virtues and Judas' Birthright

- Added Book of Virtues previews from **165 upstream wisp records**: health,
  damage, orbit/ring, tear effects, stage-based scaling, single-room wisps,
  and active items that do not create wisps.
- A Book of Virtues pedestal previews owned active items, including secondary
  and pocket actives. Owning Book of Virtues adds the relevant wisp information
  to supported active-item descriptions.
- Added passive Book of Belial bonuses for Judas/Black Judas with Birthright,
  including Guppy's Paw's **+0.5 damage** note.
- Fixed detection of that passive effect: Isaac reports virtual ownership even
  when collectible 59 is absent from the raw inventory. The adapter reads the
  verified native condition without adding items or changing gameplay state.

## Tainted Cain and pause inventory

- Added salvage descriptions: **3–8 pickups**, or **6–16 with Birthright**,
  guaranteed room-pool rewards where known, and supported trinket bonuses.
- Personal equipped/swallowed trinkets are considered, including Lucky Toe,
  Safety Cap, and Daemon's Tail behavior.
- Quest items retain normal descriptions. Cantripped, Death Certificate's
  dimension, the native excluded room, and unavailable context do not produce
  guessed salvage information. Error Rooms have no guaranteed-pool prediction.
- Salvage pedestals do not misleadingly show collectible transformation progress.
- Added a separate **Smelted trinkets** pause section for swallowed normal and
  golden trinkets; they also participate in owned-item checks.

## Predictions, floors, modes, and transformations

- **Consolation Prize** previews the lowest normalized stat and lowest weighted
  consumable pool. Ties show `?`; Bethany/Tainted Bethany charge pools and co-op
  summaries are supported. This preview stays on Consolation Prize itself.
- **Pandora's Box** highlights the current floor's payout in green, including
  Greed/Greedier, late-game routes, Void, and Home. Strange Key highlights its
  overriding reward instead. Missing translated floor entries are not guessed.
- Fixed Pandora's Box rewards being compressed into one semicolon-separated
  English line; floor entries are now separate readable lines.
- Added Greed/Greedier conditional descriptions and applicable room-to-wave
  wording. Fixed Greed-only warnings appearing in ordinary runs and duplicate
  Russian Contract from Below warnings.
- Fixed Adult/Stompy progress on identified normal and horse pills. Unknown
  pills still reveal no transformation information.
- Transformation counters are no longer capped at completion: real progress
  can show **4/3 and higher**. Rendering now updates synchronously instead of
  replacing transformation text in a later UI callback.

## Presentation, languages, and documentation

- Added an optional black description background and independent background
  opacity setting; the default remains text-only.
- Fixed missing Repentance stat icons, including the damage sword before wisp
  DPS. All nine stat aliases are imported, with fallback for older bundles,
  without shrinking the existing text or icon sizes.
- Expanded contextual localization across all **20 EID languages**, with English
  fallback for untranslated entries.
- Updated the README and website with six new full-resolution gameplay
  screenshots, accessible gallery links, and updated social previews. Removed
  the old The Pact screenshot.
- Added detailed native-layout/parity documentation and character test commands.
- Expanded host regression tests for character IDs, weapon rules, synergies,
  transformations, native context validation, icon aliases, and packaged assets.

## Compatibility, validation, and remaining limits

- Targets Isaac iOS **1.4 / Repentance v1.7.9b.J754**, executable UUID
  `F4357753-A25F-30EE-BACF-63709F902895`. This is standard Repentance, not
  Repentance+. Unknown executable UUIDs still fail closed.
- ARM64 dylib, rootless package, LiveContainer framework, and embedded resources
  are included. The dylib does not require ElleKit, Substrate, JIT, or a daemon;
  ElleKit remains only the optional jailbreak loader.
- Strict ARM64 builds, host regression tests, dependency/signature checks, and
  LiveContainer package validation passed locally. Native startup/context reads
  were checked on the development phone; the user confirmed the latest Judas
  Birthright correction. These checks do not imply that every combination has
  been tested on every device or loading mode.
- **Tainted Cain and Tainted Lilith gameplay checks remain pending**, as they
  are not unlocked on the test account. Their implementation has host coverage;
  no save edits or unlock bypasses were used. See
  [character acceptance checks](CHARACTER_CONTEXT_TESTING.md).
- Void-absorbed actives, complete twin/subplayer presentation, and seeded
  individual salvage-drop prediction are not implemented. The co-op inventory
  list remains aggregated; personal pause conditions are scoped to the primary
  player. Book of Virtues pedestal previews include all owned actives, not only
  the selected primary slot. This is not full parity with every original EID rule.
- No Isaac IPA, game application, save data, credentials, or purchase bypass
  is included. Re-signing limitations remain unchanged.

## Downloads and upgrading

- **Rootless jailbreak:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Embedded app:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Manual setup:** standalone dylib and `descriptions.json`
- **Everything:** `IsaacExternalItemDescriptions-Full-Build.zip`

Update the binary **and** its accompanying resources together, then fully
restart Isaac. Use the complete framework/embedded archive rather than keeping
an old database or icon map. Back up application data before replacing or
re-signing an installation. `SHA256SUMS` covers the individual distribution files.

Huge thanks to **wofsauge** and all original External Item Descriptions
contributors and translators. EID-derived descriptions, artwork, and rule data
remain attributed; the bundled upstream revision is
`ee7f463a00c11263272ee737a52961fb562d26b8`.
