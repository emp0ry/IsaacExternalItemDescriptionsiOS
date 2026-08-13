# Changelog

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
