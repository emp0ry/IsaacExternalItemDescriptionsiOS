# Changelog

## 0.8.0 - 2026-10-14

### Added

- Character-aware descriptions with Lost/Keeper no-effect and lethal-use warnings,
  health-type replacements, Birthright descriptions, and co-op difference notices.
- Additional character rules for Eye Drops, Uranus/Tainted Samson, Keeper/IV Bag,
  tainted Clicker, Dead Cat, and Lilith/Tainted Lilith with BFFS!.
- All 335 imported standard-Repentance weapon override rules in both directions,
  including weapon priorities, Azazel, and combination-specific synergy text.
- Car Battery and Tarot Cloth conditional descriptions, numeric effect changes,
  special active-item behavior, and no-synergy warnings.
- Book of Virtues wisp previews using 165 upstream wisp records, including health,
  damage, orbit, tear effects, single-room wisps, and no-wisp cases.
- Judas/Black Judas Birthright passive Book of Belial bonuses for supported actives.
- Tainted Cain salvage descriptions with personal Birthright/trinket bonuses,
  room-pool rewards, and quest-item/special-context protection.
- A separate pause-inventory section for smelted/swallowed normal and golden
  trinkets, also included in owned-item conditional checks.
- Consolation Prize predictions using normalized stats, weighted consumables,
  tie markers, Bethany charge pools, and co-op summaries.
- Pandora's Box current-floor payout highlighting, including Greed/Greedier,
  late-game routes, Void/Home, and Strange Key's overriding reward.
- An optional black description background with independent opacity controls.
- Imported contextual localization with English fallback across all 20 languages.

### Fixed

- Lost warnings and Birthright descriptions using the wrong character names due
  to Lua/native character-index differences, including the incorrect Eden warning.
- Judas' Birthright bonuses disappearing because passive Book of Belial is
  virtual ownership rather than a raw collectible-count entry.
- Greed-only text appearing in normal runs or being duplicated in Greed, including
  Russian Contract from Below; mode-specific room/wave wording is now applied.
- Adult/Stompy pill transformation rendering, including identified horse pills,
  and counters being capped at completion instead of showing values such as `4/3`.
- Stale contextual descriptions after inventory changes while standing still,
  and asynchronous transformation text replacement.
- Same-character co-op players borrowing another player's Birthright/trinkets;
  pause conditional checks now use the primary player's personal inventory.
- Pandora's Box floor rewards appearing on one long semicolon-separated line.
- Missing Repentance stat-icon aliases, including the damage sword in Bethany's
  wisp stats; older resource bundles also get runtime alias fallback.
- Numeric conditional replacements matching only part of a decimal or applying
  the same replacement more than once.

### Documentation and validation

- Updated README and website with six new full-resolution gameplay screenshots,
  replacing the old The Pact image; added clearer feature and limitation coverage.
- Added character acceptance commands, native-layout notes, and parity scope.
- Expanded C++/Objective-C/Python regression checks for conditional descriptions,
  all-language fallback, native state validation, icons, and LiveContainer assets.
- Retained portable ARM64, rootless, LiveContainer, and embedded distributions.
  No IPA, game binary, save, or credential is distributed.
- Tainted Cain/Tainted Lilith gameplay checks remain pending; their host tests do
  not establish full in-game parity. See the [full release notes](docs/RELEASE_NOTES_v0.8.0.md).

## 0.7.3 - 2026-10-01

- Restored the proven single-window pass-through overlay used by v0.6.1.
- Fixed EID buttons, settings controls, sliders, and inventory rows not receiving
  touches in LiveContainer.
- Kept all non-EID touches routed to Isaac without creating a second `UIWindow`
  or inserting EID views into the game controller hierarchy.
- Withdrew the broken v0.7.2 tag and release.

## 0.7.1 - 2026-10-01

- Delayed EID startup until Isaac becomes active and moved the overlay into the
  established game view hierarchy, preventing the virtual movement stick from
  remaining at the top-left launch position.
- Made the always-present description surface non-interactive and attach settings
  and inventory cards only while they are open.
- Localized the unidentified-pill title for all bundled languages even when an
  older imported description database is still installed.
- Removed the redundant question-mark description line from unidentified pills.
- Improved pixel-art sharpness for quality, battery, charge-number, and inline
  icons on Retina displays.
- Removed the empty body gap when an entry only has a title.

## 0.7.0 - 2026-10-01

- Matched upstream EID visibility rules for cards, runes, Soul Stones, shops,
  `Options?`, obstructions, player flight, identified pills, and Curse of the Blind.
- Added original EID active-item battery and charge indicators.
- Kept the normal title size when charge information is present.
- Added a scrollable settings panel with Scale and Opacity percentage labels.

## 0.6.1 - 2026-08-21

- Made transformation progress refresh immediately when one of multiple identical
  transformation pedestals is collected in the same room. The displayed count now
  combines the live inventory with Isaac's persisted PlayerForm state.

## 0.6.0 - 2026-08-20

- Added a top-left pause-only inventory browser for collectibles, active items,
  trinkets, held cards and runes, identified pills, and all transformation
  progress.
- Added native pause detection from the verified Repentance PauseScreen state.
- Replaced session-only transformation reconstruction with Isaac's persisted
  15-entry PlayerForm counter array, preserving progress across active-item
  replacement and save reloads.
- Added native Super Bum familiar detection for correct post-merge progress.
- Made the complete EID settings panel available while a run is paused and
  kept it hidden during active gameplay.

## 0.5.0 - 2026-08-20

- Fixed Curse of the Blind spoiler protection by reading the native level curse mask and suppressing every collectible pedestal while the curse is active.
- Added Dice Room descriptions using the native dice-floor effect and its live face.
- Added Sacrifice Room payout descriptions using the native room grid and current spike activation count.
- Added real transformation progress calculated from the player's current owned-collectible table, with active-item history retained for the current run.
- Added native run-seed tracking and a debounced run-end signal so card knowledge and transformation state reset reliably between runs.
- Fixed card, rune, and pill artwork so each description uses the correct frame; pills use the original EID pill atlas.
- Improved held-card and rune knowledge tracking through the native player pocket slots.
- Removed EID markup brackets from Dice Room and Sacrifice Room headings and kept long headings on one fitted line.
- Fixed the description overlay's two-stage disappearance when an item is collected.
- Added localized Dice Room and Sacrifice Room data for all 20 bundled EID languages.

## 0.4.1 - 2026-08-18

- Fixed subtype-aware card and rune artwork frame selection.
- Switched identified-pill artwork to the original EID pill atlas.
- Improved per-run transformation reset detection.

## 0.4.0 - 2026-08-18

- Added a much closer original External Item Descriptions presentation for iOS, including purple item titles, inline item artwork, original quality sprites, transformation icons, and improved description markup rendering.
- Added collectible quality metadata and Q0-Q4 quality display.
- Added transformation metadata, transformation icons, temporary per-run transformation progress tracking, duplicate-item protection, progress caps, and new-run reset behavior.
- Added localized transformation names using the selected EID language with English fallback.
- Added original EID inline icon assets and transformation resources to distributable builds.
- Added full release packaging for rootless jailbreak, LiveContainer, embedded/non-jailbreak, standalone dylib, description database, and SHA256 sums.
- Expanded GitHub Actions packaging so downloadable full-build artifacts include the bundled EID descriptions and presentation resources.

### Known bugs

- Curse of the Blind can still show item descriptions for hidden collectible pedestals.
- Rune artwork currently shows the full rune sprite sheet instead of the specific rune icon.
- Pill artwork is not yet the exact pill shown in-game; identified pills need to use the matching in-game pill appearance instead of the current static/incorrect icon.

## 0.3.1 - 2026-08-13

- Fixed the menu/gameplay detector becoming stuck after Isaac allocated the
  active player in a different heap region from the main-menu placeholder.
- Resolve and cache Isaac's native player-list vector, so the EID settings
  button hides during a run and returns after reaching a menu.

## 0.3.0 - 2026-08-13

- Added a debounced native main-menu/gameplay detector and bottom-right EID
  settings panel that automatically hides during runs.
- Replaced the context-menu language control with a native action-sheet picker
  and removed the startup information banner.
- Added selection for all 20 upstream EID languages with English fallback for
  untranslated Repentance entries.
- Added persistent horizontal and vertical position sliders with defaults of
  140 px from the left and 50 px from the top.
- Tagged generated databases for standard Repentance 1.7.9b (`rep`), matching
  the installed iOS 1.4 executable rather than Repentance+.
- Added in-app and project credits for wofsauge and the original EID
  contributors.
- Bundled the official EID Repentance description tables for all 20 supported
  languages with permission and attribution to the original project.

## 0.2.0 - 2026-08-13

- Added an app-specific framework package for LiveContainer private apps.
- Added exact Isaac image selection when LiveContainer loads the patched guest
  executable as `MH_DYLIB` inside its host process.
- Allowed the verified Isaac UUID to bootstrap EID when LiveContainer retains
  its own bundle identifier.
- Added framework-local description database discovery and package validation.

## 0.1.0 - 2026-08-13

Initial public release.

- Added native collectible, trinket, card, rune, known-pill, horse-pill, and
  Crane Game prize descriptions for Isaac: Repentance on iOS.
- Added English and Russian description support with a startup language picker.
- Added native collectible, trinket, and card artwork plus a consistent white
  icon for identified pills.
- Added guards for untouched cards, unidentified pills, Curse of the Blind, and
  unsupported executable versions.
- Added dropped-card recognition through native player pocket slots.
- Added rootless ElleKit packaging and a jailbreak-independent ARM64 dylib.
- Added an IPA patching tool, signing support, dependency audit, and automated
  importer tests.
