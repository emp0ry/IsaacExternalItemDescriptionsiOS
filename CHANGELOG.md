# Changelog

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
