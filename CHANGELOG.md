# Changelog

All release changes are kept here. Older entries describe their own release; historical limitations may have been resolved by a later update.

## v1.0.0

2026-10-17

Original EID pixel rendering, refreshed descriptions and redesigned settings, with a new screenshot-led website.

### Original EID presentation

- Replaced the system description font with upstream EID bitmap fonts, glyph metrics, kerning and language-specific layout defaults. Settings and inventory controls remain native UIKit.
- Ported icon-led bullets, indentation, wrapping, title colors, quality symbols, transformation rows and active-item charge geometry. Normal, timed and special charges retain their distinct indicators.
- Unknown pills use the original red localized title and question-mark overlay on their real pill-color icon, without a redundant question-mark description.
- Restored the separate localized SINGLE USE warning for the exact 13 Repentance actives in upstream EID's list. Reusable zero-charge actives are not incorrectly marked single-use.
- Imported literal markup shortcuts and legacy string escapes, including golden-heart and chest aliases. Corrected missing character icons, clipped dice-face frames, blank bullets, leading animated-color bullets and blink/fade color preservation.
- Fixed off-screen collectible descriptions caused by unsigned bullet coordinates. Empty descriptions cannot leave a black pause backdrop; invalid layouts fall back safely.

### Descriptions and settings

- Updated the standard-Repentance database from pinned upstream EID V5.25 revision `8b59d00c6828e333294639ad2b2b6875eae821cb`, including original modular text generation and character health variants for all supported languages.
- Stat icons after arrows default to on. They can be disabled without removing other inline icons, including wisp health and damage.
- Rebuilt settings as four scrollable tabs: Content, Layout, Appearance and Advanced. Every position, scale, width and opacity slider has its own Reset button.
- Added text width from 100% to 300% of the language's original width, capped by available screen space without shrinking the font or going below the previous default.
- The Language setting now controls descriptions, settings and EID Items in all 20 languages. Labels refresh immediately while preserving other preferences and the selected settings tab.
- Retained character context, synergies, transformations, floor and room descriptions, pickup knowledge rules, pause inventory and previous previews. RNG predictions, exact absorption stat previews and hidden current effects remain independent options, off by default unless explicitly configured.

### Website and distribution

- Redesigned the website in the same visual family as Isaac Drop (Ctrl), with a real-gameplay hero, a filterable 15-image gallery, full-resolution image viewing, download cards, installation instructions and clear compatibility limits.
- Replaced older renderer screenshots in the website and README with new native iOS screenshots and feature-specific captions. Debug Console shown in some screenshots is identified as a separate mod.
- The single build workflow now runs the original-font rendering and markup audit and checks that matching fonts and resources are present in packaged releases. Tests remain local-only and are not published as a repository folder.
- Rootless DEB, LiveContainer framework, embedded package, standalone dylib, description database, checksums and complete build archive are provided. No IPA, game executable, game asset dump, save or credential is distributed.

### Verification and compatibility

- Host checks cover 445 static icons, 21,232 base description layouts, 17,375 modular character-health layouts, all 20 interface languages, single-use warnings and existing native context rules. Simulator UI checks cover two screen sizes, four tabs, individual resets and repeated language changes.
- The experimental build was installed on the development iPhone with matching hashes; supplied native screenshots demonstrate the new renderer, contextual descriptions, pause inspection and settings. Every device, locale, character and co-op/loading combination has not been exhaustively replayed.
- Compatibility remains native Isaac iOS **1.4 / Repentance 1.7.9b.J754**, **ARM64**, **iOS 15+**. This is a native EID adaptation, not a general desktop Lua-mod loader or Repentance+ support. Animated-color timing is approximate across different rendering backends.

Install the complete package for your loading method and fully restart Isaac. Existing EID preferences are retained. Do not load two EID copies at once.

Thanks to **wofsauge**, all original EID contributors and translators, and the font creators. Upstream-derived descriptions, fonts, artwork and algorithms remain attributed in the project notices.

[Website and screenshots](https://isaaceidios.emp0ry.com/) · [Complete feature guide](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS#readme) · [Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)

## v0.13.1

2026-10-16

Readable descriptions throughout Isaac's pause screen, not just inside EID Items.

- Every visible description now gains a dark background of at least 72% opacity while paused, including nearby pickups without opening EID Items.
- The backdrop updates on pause/resume even when the item and text are unchanged; it no longer depends on selecting an inventory entry.
- Resuming restores the configured gameplay background toggle and opacity. Pausing never overwrites saved settings or changes text scale and fitted panel width.
- README and website feature descriptions reflect the expanded pause behavior. All v0.13.0 features and spoiler controls remain included.

Local pause-policy, source-architecture, context, importer and documentation regressions passed, along with strict ARM64, signature, portable-dependency and packaging checks. The corrected dylib was installed on the development iPhone and its hash verified; exhaustive visual checks across all loading modes are not claimed.

Fully restart Isaac after updating. Compatibility remains native iOS **1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15+. No game files or saves are distributed or modified by this fix.

## v0.13.0

2026-10-16

Original EID spoiler defaults, current room trinket effects and save-aware unlock hints, plus Mama Mega's golden-bomb interaction.

### Settings and spoiler controls

- Three independent controls now default to **OFF**: **RNG predictions (spoilers)**, **Void / Black Rune stat previews**, and **Hidden current effects**. Enabling one does not enable the others.
- Void and Black Rune's exact future stat gains are no longer shown unless their own control is enabled; disabled forecasts are not calculated in the native probe.
- Spindown remains an enabled three-use deterministic ID preview. Flip and Glitched Crown remain enabled. Language, layout and explicitly saved settings are preserved.
- The settings panel accommodates the additional controls without overlapping its help text or credits.

### Added and improved

- With **Hidden current effects** enabled, inspect Liberty Cap, Broken Syringe and Mom's Lock to see their already-applied room effect. Verified native trinket records are checked against actual temporary effects; failed procs keep the ordinary description. This does not predict the next room's roll or advance RNG.
- Equipped Modeling Clay remains inspectable normally; swallowed-only Clay follows Hidden Info. Turning the option off removes the revealed effect, including cached pause selections.
- Missing Poster's Lost-unlock hint uses the selected Isaac save's achievement flag. Pandora's Box shows the appropriate Dark Room reward when Moving Box is already unlocked, retaining current-floor highlighting and localized text. No Game Center or save modification is involved.
- Mama Mega's reuse hint follows the actual native golden-bomb flag, refreshing on acquisition and removal. Personal pause descriptions use the selected player's state rather than borrowing another player's bomb.
- The bundled description database and README now cover these rules and independent options.

### Compatibility and verification

- The user confirmed the installed update working on the development iPhone. Local policy, importer, 20-language context and independent-toggle regressions passed, along with strict ARM64 build, signature, portable-dependency and packaging checks. Every language, co-op and loading-mode combination has not been exhaustively replayed.
- Native Isaac iOS **1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15+. Repentance+ and other executable builds are not supported by these offsets. Arbitrary Lua and unreviewed conditional expressions are not executed.
- No IPA, game executable, save or credential is distributed. Viewing descriptions does not activate items, advance game RNG or write save data.

Fully restart Isaac after updating and use only one loading method. Thanks to wofsauge and all original EID contributors and translators; attributed descriptions and resources are included with permission.

[Website](https://isaaceidios.emp0ry.com/) · [Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)

## v0.12.0

2026-10-16

More original EID context for duplicate items, active charging, item combinations and room rewards, with a simpler guide and one complete changelog.

### Added

- Original duplicate-copy descriptions for useful stacking and ineffective extra copies. Diplopia and Crooked Penny enable the applicable pickup hints; owned pause entries do not claim another copy is being acquired.
- Active-charge interactions for 9 Volt, 4.5 Volt, Sharp Plug, Vibrant/Dim Bulb and Schoolbag. Normal, timed and special charging follow installed item metadata and the appropriate primary/pocket-slot rules.
- 642 reviewed supplemental standard-Repentance conditional rules, including Black Candle/Cursed Eye, non-stacking damage multipliers, Sacrificial Altar familiars, supported weapon/fart/poop combinations, single-use items and mimic effects. Localized text, rule ordering and both synergy directions are preserved where applicable.
- Glyph of Balance's owned pause entry shows the selected player's current native pickup priority outside Greed. This is a priority preview, not a prediction of a random reward.
- Sanguine Bond spike descriptions with original localized payout probabilities, separate from ordinary Sacrifice Room steps.

### Fixed and improved

- Validated Void-absorbed actives now participate in applicable ownership conditions and native Spindown/mimic previews while Void is owned. They remain separate from physical collectibles and do not inflate inventory counts.
- Book of Virtues pedestal previews use each applicable player's primary active rather than every secondary or pocket active.
- Super Bum's merged familiar is matched to its actual native player owner, keeping personal transformation completion separate in co-op. Invalid owner/list snapshots fail closed; the established single-player fallback remains.
- Special-charge tooltips retain both relevant warnings, such as 9 Volt and Sharp Plug on Alabaster Box, rather than deduplicating one away.
- Additional conditionals use current personal inventory, active slots and eligible pocket items, without borrowing a partner's pause context or revealing unknown pills.
- Existing crafting, live rotating-pedestal descriptions, duplicate quantities, current-effect inspection, optional RNG previews and all earlier fixes remain included.

### Documentation and release packaging

- Rewritten README with a short installation/usage guide and a grouped, expandable list of every supported feature, preview, setting and limitation.
- Consolidated all per-version release-note files into this changelog. Earlier entries preserve the behavior and verification limits recorded at the time.
- Removed standalone testing guides and character-context checklists. The test suite is kept locally and is no longer tracked or distributed in GitHub source archives.
- The single universal workflow still builds and checks standalone, rootless, LiveContainer and embedded distributions. Public builds do not require the local-only test suite.
- GitHub release bodies are extracted from the matching changelog entry without repeating the release title.

### Compatibility and verification

- Native Isaac iOS **1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15+. These offsets do not support Repentance+ or other executable builds.
- The user confirmed the latest installed update working on the development phone. Host policy/context/importer checks and strict ARM64, signature, dependency and packaging checks passed before publication; not every co-op/language/loading-mode combination has been exhaustively replayed.
- Only reviewed original EID conditions are supported, not arbitrary Lua or every upstream synergy. Golden-bomb and arbitrary subplayer-count predicates remain outside the supplemental adapter.
- Viewing descriptions does not activate effects, advance game RNG or modify saves. No IPA, game binary, save, credential or purchase bypass is distributed.

Fully restart Isaac after updating and use only one loading method. Descriptions and attributed resources are included with permission from wofsauge, with thanks to all original EID contributors and translators.

[Website](https://isaaceidios.emp0ry.com/) · [Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)

## v0.11.0

This update adds native crafting and current-effect inspection, more original
EID synergies, personal pause inventories and optional outcome predictions.
It also fixes pocket-active decoding, rotating pedestal descriptions and
missing collectible quantities.

### Pocket actives and Bag of Crafting

- Pocket actives resolve through the game's real active-slot reference instead
  of using that reference as a collectible ID. This fixes Tainted Cain showing
  Spoon Bender in EID Items when he does not own it.
- Bag of Crafting shows its current ingredient icons and fill progress.
- At 8/8, inspecting the bag displays the game's cached result, including its
  title, icon, quality and full translated description.
- Replacing ingredients refreshes the result. Inspecting it never crafts,
  changes ingredients, advances RNG or adds the result to owned items.
- This is a preview of the actual bag, not a recipe browser or a planner using
  pickups outside it.

### Food and familiar synergies

- Binge Eater adds the original per-food stat bonuses, temporary damage, speed
  penalty and applicable healing changes. Character health conversions remain
  respected, including Tainted Bethany's blood charges and Lost protections.
- Supported BFFS! and Hive Mind familiar descriptions show their changed
  effects without incorrectly multiplying their shared bonus twice.
- No-effect familiar warnings, supported familiar trinkets and Soul of Bethany
  receive their applicable notes. Upgrade-pedestal hints use current ownership
  and do not appear when inspecting an already-owned upgrade.
- Forgotten Lullaby includes clot support and the relevant wisp, Gello and
  other no-effect exceptions in both directions.
- Removing an enabling item removes its conditional bonuses.

### Rotating pedestal descriptions

- Binge Eater and other short item cycles follow the pedestal's current native
  item rather than showing the previous half-cycle's description.
- The display refresh checks only the selected pedestal and redraws on a
  changed identity; it does not accelerate the full memory scan.
- Removed, reused, hidden and stale-room pickups are rejected. Curse of the
  Blind protections remain in effect.
- Glitched Crown retains its separate tap-to-browse five-item interface.

### Current effects, not future rolls

- **Void:** already-absorbed actives appear in a separate clickable EID Items
  section, including duplicate counts. The game's persisted native list is
  authoritative across Continue and consumed single-use effects.
- Absorbed actives are not physical inventory items. Passive collectibles such
  as Brimstone become stat bonuses when absorbed and correctly do not appear
  in Void's active-ability list.
- **Purity:** inspecting the owned item shows its current active aura bonus or
  inactive-until-next-room state, without predicting the next random aura.
- **Modeling Clay:** inspecting the owned trinket shows its already-applied
  room item's description and source. No-effect rooms retain the ordinary
  trinket description; temporary items are not added to physical inventory.

### Personal inventories and duplicate quantities

- EID Items offers a native-player selector for Jacob/Esau and co-op players.
- Collectibles, all four active slots, pockets, swallowed trinkets, absorbed
  actives and transformation counters are scoped to the selected player.
- Selecting a description uses that player's ownership-dependent context,
  rather than borrowing PHD, Car Battery or other effects from a partner.
- Repeated physical collectibles use one row with their current count, such
  as **Brimstone ×3**. Gaining/removing copies refreshes the list; a single copy
  has no unnecessary ×1 suffix.
- Raw counts and active-slot occurrences are merged without counting the same
  physical copy twice. Void and temporary effects do not inflate this quantity.

### Optional next-outcome previews

The **RNG predictions (spoilers)** setting is **off by default**.

- **Crooked Penny:** shows its next heads/tails outcome from copied native RNG
  and room state. Car Battery has a separate second-result line.
- **Eternal D6:** shows whether the next individual eligible pedestal reroll
  replaces or removes the item. The actual Eternal D6 mode of D Infinity is
  supported too.
- With Car Battery, Eternal D6 explicitly labels **first reroll only (1/2)**.
  It does not promise survival of both activations or a future-use count.
- Invalid/unavailable native context suppresses predictions rather than
  guessing. Reading the preview does not advance RNG or invoke an effect.

### Downloads and compatibility

The release includes standalone dylib, rootless `.deb`, complete LiveContainer
framework, embedded bundle, description database, full-build archive and
checksums. Original EID data and resources remain attributed and included with
the original author's permission.

Target: **native Isaac iOS 1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15+.
Repentance+ and other executable versions are not supported by these offsets.
The dylib has no jailbreak-only runtime dependency; jailbreak injection is
only one loading method. Direct embedding and LiveContainer still require the
appropriate host installation/signing setup.

Fully restart Isaac after updating. Use only one EID loading method. No Isaac
IPA, user saves, account credentials or purchase bypass is distributed.

### Verification and remaining scope

- Host coverage includes native-policy bounds, active-slot decoding, copied
  RNG sequences, personal context isolation, duplicate quantities, conditional
  descriptions and presentation in 20 languages, imports and package layout.
- Strict ARM64 compilation, signature verification and the portable-library
  audit passed locally; the release workflow repeats distribution checks.
- The user confirmed crafting/pocket-active changes, food/familiar changes and
  the Binge Eater refresh fix on the development phone, and subsequently
  reported the other current-effect changes working. This is not a claim that
  every co-op, character, language and loading-mode combination was replayed.
- Duplicate-quantity rendering is host-tested and installed, but its final
  on-device visual check remains pending at publication.
- Per-player ownership of the merged Super Bum familiar remains unverified;
  that personal counter is omitted in co-op rather than attributed incorrectly.
  Void actives are not treated as physically held items by every synergy
  adapter. Book of Virtues pedestal previews still consider all owned actives.
- Older pending checks, including individual tainted-character salvage cases
  and Flip regression coverage, are documented rather than assumed passed.

[Website](https://isaaceidios.emp0ry.com/) ·
[Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)

## v0.10.1

This update makes pause-inventory descriptions easier to read and adds a
read-only D Infinity description browser.

### Readable descriptions while paused

- Selecting an item in **EID Items** always shows a dark background over the
  light pause menu, even when the normal Background setting is off.
- The pause-inventory background has a minimum opacity of **72%**. A more opaque
  saved value is preserved; no saved toggle or opacity is overwritten.
- Resuming clears the inventory selection and restores the normal gameplay
  background preference.

### Background width follows the content

- Description boxes fit the actual title and widest laid-out body line instead
  of keeping a long default width for short descriptions.
- Item artwork, battery/charge and quality symbols, inline icons and the preview
  counter are included in the layout.
- Long descriptions still wrap within the available screen width. The change
  does not reduce the text's font size.
- Background bounds are updated after the final header layout, including when
  the title is hidden or the overlay host is reattached.

### D Infinity: inspect every die

Select D Infinity in **EID Items**, then tap its description to advance through:

**D Infinity overview → D1 → D4 → D6 → Eternal D6 → D7 → D8 → D10 → D12 → D20
→ D100 → overview.**

- The counter appears inside the description's top-right corner as **0/10 ›**.
- Every die has its own translated description, icon, quality and charge display.
- Periodic EID refreshes keep the selected page. Choosing the item again resets
  to its overview; selecting another item or resuming clears the browser.
- This is **description browsing only**. It does not switch the game's actual
  D Infinity mode, invoke its effect, spend charge or edit saves.
- Glitched Crown keeps its existing separate pedestal-cycle browser.

### Downloads

| Setup | File |
| --- | --- |
| Rootless jailbreak / ElleKit | `IsaacExternalItemDescriptions-rootless.deb` |
| LiveContainer private app | `IsaacExternalItemDescriptions-LiveContainer.framework.zip` |
| Direct embedding | `IsaacExternalItemDescriptions-Embedded.zip` |
| Complete archive | `IsaacExternalItemDescriptions-Full-Build.zip` |
| Manual setup | `IsaacExternalItemDescriptions.dylib`, `descriptions.json` |

Description data, original EID artwork and translations remain included in the
complete packages, with attribution and the original author's permission.
`SHA256SUMS` covers the individual distribution files. Fully restart Isaac after
updating and use only one loading method per installation.

### Compatibility and verification

The target remains **native Isaac iOS 1.4 / Repentance 1.7.9b.J754**, ARM64,
with standard-Repentance data. Repentance+ is not the target of this port.

The user confirmed the three changes working on the development iPhone. Local
regression tests cover dice ordering/wrap, background policy, fitted-width bounds,
existing description/native policies, imports, package layout and documentation.
The strict ARM64 build and portable-library audit passed before publication; the
release workflow repeats them for the published packages. This is not a claim
of exhaustive device testing of every language, setting and loading mode.

The dylib still has no jailbreak-only runtime dependency. No Isaac IPA, user
saves, account credentials or purchase bypass is distributed.

[Website](https://isaaceidios.emp0ry.com/) ·
[Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)

## v0.10.0

Six more original-EID-style contextual previews, backed by native iOS game state.
All v0.9.0 features and the LiveContainer startup fix remain included.

### Glitched Crown

- See the real item cycle stored on a pedestal instead of chasing its rapidly
  changing sprite. The overview lists each candidate's icon and localized name.
- Tap anywhere on the description to inspect the next candidate. The compact
  `0/5 ›` indicator sits inside the top-right corner of the header, with space
  reserved so it does not overlap the title. No separate floating button.
- `0/5` is the overview; `1/5` through `5/5` show individual full descriptions.
  After the last item, the next tap returns to the overview.
- Selection stays stable while the native sprite rotates. Each pedestal has its
  own selection; changed reroll results reset the preview to the new overview.
- Individual previews retain their item icon, quality, active charge indicator,
  transformations, character context, Abyss text, and applicable Flip text.
  Spindown is queried for the selected candidate, not the flashing sprite.
- The synthetic overview does not inherit a Glitched Crown collection reminder.
  Existing per-item collection reminders are otherwise unchanged.
- Curse of the Blind, forced/question-mark sprites, absent pickups, menus, and
  modal panels hide or disable the cycle UI. Ordinary descriptions stay
  touch-transparent, using the established single-window overlay.

### Abyss

- Collectible descriptions show the locust count, damage multiplier, size,
  speed, and applicable special effects when the selected player owns Abyss.
- Uses the original standard-Repentance definitions: 17 special records plus
  the normal one-locust, 1x-damage fallback.
- Includes the original game's first-flag behavior: for example, Ipecac's
  locust applies poison, not the later explosive flag.
- Does not apply Repentance+ quality-based damage scaling to the older iOS game.
- Available in floor and pause-inventory descriptions, with localized text and
  English fallback where the original translation is incomplete.

### Wild Card and Vurp!

- Wild Card names and illustrates the native recorded active item, card, or
  pill effect it will repeat. Empty history does not invent a previous use.
- Vurp! previews the pill it will create using the retained native pill color
  and its current player-specific effect. Normal/horse propagation and the
  golden-pill history exception follow the supported game's implementation.
- Inline pill artwork uses the actual color. The original card/pill text colors
  are also honored by the shared description renderer.
- Reads the game's persisted player history rather than inferring uses from
  pocket contents or drops. No mod-owned use-history save file is required.
- Unknown pills remain protected; co-op records remain player-specific.

### The Stars? and Black Feather

- **The Stars?:** previews the oldest eligible passive item that will be removed,
  or two with Tarot Cloth. Native pickup order, current counts, starting-item
  exclusions, active-item exclusions, and quest/challenge protections are used.
  Duplicate copies are handled without inventing extra owned items.
- **Black Feather:** shows the live qualifying-item count and damage bonus.
  Duplicate collectibles, qualifying equipped/swallowed trinkets, Mom's Box,
  and golden Black Feather follow the original EID callback's calculation.
- Both previews include original localized text and icons. Unavailable or
  invalid native data preserves the ordinary description instead of guessing.

### Compatibility and verification

- Native Isaac iOS **1.4 / Repentance v1.7.9b.J754**, ARM64 executable UUID
  `F4357753-A25F-30EE-BACF-63709F902895`. Unknown builds remain unsupported.
- The user confirmed the installed Abyss, Wild Card/Vurp!, The Stars?/Black
  Feather, and revised Glitched Crown builds work. These reports are basic
  gameplay acceptance, not exhaustive coverage of every special/co-op scenario.
- Host regression tests cover bounded native layouts, cycle rotations and
  duplicates, history filtering, unknown/blind protections, and formatting in
  all 20 languages. Strict ARM64 builds, code-signature/dependency audits, and
  distribution validation are part of the release build.
- Uses read-only state and validated native getters. No effect invocation, RNG
  advancement, game save editing, injected input, extra game window, JIT, or
  jailbreak-only runtime dependency is introduced.
- **Limits:** Crown summaries require at least five unique candidates. Smaller
  cycles retain the normal pickup description. Void/Black Rune room-stat
  forecasts are suppressed inside Crown candidate previews rather than attached
  to a hypothetical item with different live absorption eligibility.
- Void-absorbed active tracking, Bag of Crafting recipes, complete twin/subplayer
  presentation, and additional RNG previews are not included. Tainted Cain and
  Tainted Lilith still need dedicated on-device checks on unlocked characters;
  Flip and combined modifier cases retain their detailed acceptance checklists.

### Downloads and upgrading

- **Rootless jailbreak:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Embedded app:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Manual setup:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **All formats:** `IsaacExternalItemDescriptions-Full-Build.zip`

Update the binary and resources together, then fully restart Isaac. The database
and resource bundles are included in the packaged installation formats. No IPA,
user save, credentials, or purchase bypass is distributed.

Thanks to **wofsauge** and every contributor and translator of the original
[External Item Descriptions](https://github.com/wofsauge/External-Item-Descriptions).
The upstream source revision remains pinned to
`8b59d00c6828e333294639ad2b2b6875eae821cb` for standard Repentance compatibility;
attribution and third-party notices remain included.

## v0.9.0

2026-10-16

More useful information before you pick up, reroll, or absorb an item, plus a
LiveContainer startup fix and clearer inline artwork. All v0.8.0 character,
weapon, wisp, inventory, and floor features remain included.

### Reroll and absorption previews

- **Spindown Dice:** previews three uses in one arrow-connected chain, with item
  icons and localized names. Eligibility uses the same native availability check
  as iOS Isaac, including unlocks and current-run restrictions. Unavailable,
  hidden, and missing IDs are skipped entirely, not crossed out.
- **Car Battery:** each displayed use accounts for both valid reroll steps.
  Dad's Note stops the chain; item disappearance gets its localized message.
  Unlock state is not confused with whether an item has been collected before.
- **Void and Black Rune:** show separate stat predictions based on private copies
  of the native RNG records. Reading the description does not advance Isaac's
  RNG. Room, purchased-item, and single-item cases are handled separately, with
  native room entities and shared Options? groups considered.
- **Flip:** reads the alternate item saved on a native pedestal and adds its
  name and contextual description. Curse of the Blind and forced-blind checks
  remain enforced. Included in this release, but gameplay verification is pending.

### Luck, trinkets, and charge costs

- Supported Luck-sensitive effects now show their proc chance at the player's
  current Luck, using original **standard Repentance** formulas.
- Golden trinkets and Mom's Box apply per-trinket multipliers, special cases,
  and localized replacement descriptions, with adjusted values highlighted gold.
- Blank Card, Clear Rune, and Placebo show the displayed card, rune, or identified
  pill's charge cost from the installed game's metadata. Unknown pills cannot
  reveal their effects through a charge-cost preview.
- Includes applicable Blank Card + Tarot Cloth notes.

### Collection and pill information

- Added a final reminder for collectibles not yet picked up for the active save
  slot's collection page. This helps track the collection requirement; it does
  not grant an achievement or imply that all Dead God requirements are complete.
- Collection flags come from native persistent progress, not current-run ownership.
  Hidden entries, pause reminders, and read-only/custom-run contexts are protected.
- Visually distinctive card, rune, and Soul Stone models can be described in shops
  and behind obstacles. Shared-model unknown shop cards and Options? card choices
  stay protected; Chaos Card is not incorrectly treated as a unique model.
- PHD/False PHD descriptions follow native player-specific pill effects, including
  Virgo/Lucky Foot conversions and applicable low-health exceptions.
- False PHD shows the appropriate damage or black-heart reward, including horse
  pills. Experimental Pill and simultaneous PHD + False PHD use their own rules.
- Removing PHD/False PHD immediately clears their tooltip modifiers. A color already
  identified by Isaac may remain known, but a removed item's reward must not remain.

### Presentation and LiveContainer

- Fixed undersized inline collectible/trinket icons. Transparent sprite padding
  is cropped before scaling, including Spindown results, Bible, and Red Key.
  Existing text, title, quality, and battery sizes are preserved.
- Fixed the stuck joystick reported during LiveContainer cold launch. EID waits
  for Isaac's actual render view/controller and advancing native frame timestamps
  before loading its database or attaching UI.
- Retained the established single-window pass-through overlay. No additional
  window, simulated touch, joystick-state write, JIT, or jailbreak API is needed.
- Updated README and website with four full-resolution screenshots and captions:
  Void/Black Rune predictions, Spindown results, collection reminders, and live Luck.

### Validation and compatibility

- Targets native Isaac iOS **1.4 / Repentance v1.7.9b.J754**, ARM64 executable UUID
  `F4357753-A25F-30EE-BACF-63709F902895`. Unknown builds still fail closed.
- The user confirmed the inline icon sizes and the joystick fix on the affected
  LiveContainer device. Supplied gameplay screenshots confirm presentation of the
  new previews; they are not exhaustive numerical/gameplay validation.
- Strict ARM64 builds, host regressions, dependency/signature checks, documentation
  checks, and distribution package validation are part of this release's build.
- **Still pending:** Flip gameplay verification, Tainted Cain/Tainted Lilith checks
  on the test account, and exhaustive combination/co-op/loading-mode testing.
- Void-absorbed active tracking, complete twin/subplayer presentation, and full
  parity with every original EID synergy remain outside this release.
- No Isaac IPA, game assets extracted from an installation, save data, credentials,
  purchase bypass, or gameplay-state modification is distributed.

### Downloads and upgrading

- **Rootless jailbreak:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Embedded app:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Manual setup:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **Everything:** `IsaacExternalItemDescriptions-Full-Build.zip`

Update the binary **and** resources together, then fully restart Isaac. Use the
complete framework or embedded archive rather than retaining an old database or
icon map. Distribution file checksums are included in `SHA256SUMS`.

Huge thanks to **wofsauge** and all original EID contributors and translators.
The attributed source revision is `8b59d00c6828e333294639ad2b2b6875eae821cb`;
only standard-Repentance data and rules are imported, excluding Repentance+ patches.

## v0.8.0

2026-10-14

A major contextual-description update for native iOS Repentance. Descriptions now
react to your character, inventory, game mode, and current floor, with many more
rules from the original External Item Descriptions mod.

### Character-aware descriptions

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

### Item, card, and weapon synergies

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

### Book of Virtues and Judas' Birthright

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

### Tainted Cain and pause inventory

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

### Predictions, floors, modes, and transformations

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

### Presentation, languages, and documentation

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

### Compatibility, validation, and remaining limits

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
  [historical verification record](docs/TEST_MATRIX.md).
- Void-absorbed actives, complete twin/subplayer presentation, and seeded
  individual salvage-drop prediction are not implemented. The co-op inventory
  list remains aggregated; personal pause conditions are scoped to the primary
  player. Book of Virtues pedestal previews include all owned actives, not only
  the selected primary slot. This is not full parity with every original EID rule.
- No Isaac IPA, game application, save data, credentials, or purchase bypass
  is included. Re-signing limitations remain unchanged.

### Downloads and upgrading

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

## v0.7.6

This maintenance release fixes pickup reachability detection for flying players.

### Changes

- Shows descriptions for obstructed cards, runes, and pills when the player can fly.
- Reads Isaac's native flight state as the one-byte C++ boolean used by the game's movement and collision code.
- Keeps unreachable pickup descriptions hidden for players without flight.
- Adds regression coverage for valid and invalid native flight-state values.

### Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of jailbreak-only runtimes.
- Includes rootless, standalone dylib, LiveContainer, and embedded distributions.
- No Isaac IPA or copyrighted game bundle is included.

## v0.7.5

This data update refreshes the bundled descriptions from the latest official External Item Descriptions source available for the supported Repentance release.

### Changes

- Updates the bundled EID source from `3b50101` to `ee7f463`.
- Imports the latest corrected Russian descriptions and names.
- Includes current upstream description fixes across supported languages.
- Keeps the database explicitly targeted at Repentance `1.7.9b`; Repentance+ tables are not imported.
- Retains all card, rune, Soul Stone, and pill artwork fixes from v0.7.4.

### Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of jailbreak-only runtimes.
- Includes rootless, standalone dylib, LiveContainer, and embedded distributions.
- No Isaac IPA or copyrighted game bundle is included.

## v0.7.4

This release fixes card-family artwork so it matches the original EID mapping.

### Fixes

- Correct icons for all 17 Soul Stones.
- Correct icons for Rune Shard and Cracked Key.
- Cards, runes, Soul Stones, and related pocket items now use the original EID rule: `Card ID - 1` selects the matching frame.
- Removes the invalid native pickup-sheet fallback that could display unrelated artwork.

### Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of jailbreak-only runtimes.
- Includes rootless, standalone dylib, LiveContainer, and embedded distributions.
- No Isaac IPA or copyrighted game bundle is included.

## v0.7.3

2026-10-01

This maintenance release fixes EID interface touch handling in LiveContainer.

### Fixes

- Restores the proven single-window pass-through overlay architecture used by v0.6.1.
- EID settings, sliders, language selection, pause inventory, rows, and close buttons receive touches again.
- Touches outside visible EID controls continue directly to Isaac.
- Does not create a second `UIWindow` and does not insert EID views into the game controller hierarchy.
- Supersedes the withdrawn v0.7.2 build.

### Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- Release downloads include the rootless package, standalone dylib, LiveContainer framework, embedded package, complete description database, and checksums.
- No Isaac IPA or copyrighted game bundle is included.

## v0.7.1

2026-10-01

This maintenance release fixes startup input presentation, unidentified-pill localization, and small icon rendering.

### Highlights

- Prevents Isaac's virtual movement stick from remaining at the top-left position after launch.
- Starts EID only after the application becomes active and keeps the passive description layer outside the touch path.
- Attaches the settings and pause-inventory cards only while they are open.
- Shows the unidentified-pill title in the selected EID language, including with older imported description databases.
- Removes the redundant `?` body line from unidentified pills.
- Renders quality, battery, charge-number, and inline pixel-art icons sharply at the device's native display scale.
- Removes unused vertical space from title-only descriptions.

### Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- Release downloads include the rootless package, standalone dylib, LiveContainer framework, embedded package, complete description database, and checksums.
- No Isaac IPA or copyrighted game bundle is included.

## v0.7.0

2026-10-01

This release improves pickup parity, active-item presentation, and settings usability.

### Highlights

- Matches upstream EID visibility rules for cards, runes, Soul Stones, and identified pills, including shop, `Options?`, obstruction, and player-flight behavior.
- Fixes Curse of the Blind suppression by checking Isaac's native curse state before showing collectible information.
- Adds the original EID active-item battery and maximum-charge indicator.
- Supports normal room charges, timed-charge items, and special or dynamic charge items such as Blank Card, Placebo, Clear Rune, and D Infinity.
- Reads item type and charge metadata from the installed game's own Repentance resources, keeping the dylib portable across jailbreak, embedded, and LiveContainer loading.
- Preserves the normal title font size when the charge indicator is present.
- Makes the EID settings panel scrollable on smaller displays.
- Shows live percentage labels for Scale and Opacity.

### Compatibility

- The native memory layout remains limited to Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The dylib remains independent of ElleKit, Substrate, libhooker, and other jailbreak-only runtimes.
- No Isaac IPA or copyrighted game bundle is included.

## v0.6.1

2026-08-21

- Made transformation progress refresh immediately when one of multiple identical
  transformation pedestals is collected in the same room. The displayed count now
  combines the live inventory with Isaac's persisted PlayerForm state.

## v0.6.0

2026-08-20

This release adds a native pause inventory and fixes transformation progress
across save reloads and active-item replacement.

### Highlights

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

## v0.5.0

2026-08-20

This release expands the native iOS overlay beyond pickup descriptions and fixes several gameplay-state bugs found during on-device testing.

### Highlights

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

## v0.4.1

2026-08-18

This release improves pocket-item artwork parity and transformation tracking.

### Changes

- Fixed card artwork to follow Isaac's actual `ui_cardspills.anm2` CardFronts frame mapping.
- Fixed rune artwork to use the same subtype-aware CardFronts animation mapping as cards.
- Fixed pill artwork by using original EID's explicit 14-frame `Pills` animation instead of guessing PNG grid positions.
- Fixed transformation progress leaking into a new run by adding a native run/player identity reset signal in addition to the existing gameplay/menu reset.
- Kept full downloadable release packaging for rootless jailbreak, LiveContainer, embedded builds, descriptions, and checksums.

### Known issue

- Curse of the Blind item descriptions may still appear in some cases.

## v0.4.0

2026-08-18

This release brings the iOS port much closer to the presentation and behavior of the original External Item Descriptions mod.

### Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **All release files together:** `IsaacExternalItemDescriptions-Full-Build.zip`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

### What's new

- Closer original EID-style presentation with purple item titles and improved layout.
- Item artwork integrated into the description header.
- Original Q0-Q4 quality icons and collectible quality metadata.
- Original transformation icons and transformation membership metadata.
- Temporary per-run transformation progress such as `(1/3)`, with duplicate collectible protection and a `3/3` cap.
- Transformation progress resets when leaving the current run and starting/restarting a run.
- Transformation names now follow the selected EID language with English fallback.
- Improved inline EID icon and color markup rendering.
- Full packaged EID description database and presentation resources included in release builds.
- Rootless, LiveContainer, embedded, standalone dylib, description database, and checksum packages are generated together.

### Known bugs

- **Curse of the Blind:** item descriptions can still appear for hidden collectible pedestals.
- **Rune icons:** the current rune artwork can show the complete rune sprite sheet instead of the specific rune icon.
- **Pill icons:** identified pills do not yet use the exact pill appearance from the current game pickup; the current static/incorrect pill artwork needs to be replaced with the matching in-game pill icon.

### Notes

Transformation progress is currently tracked heuristically during the active run. Exact player-inventory based transformation progress is planned once the native collectible ownership state/function is mapped.

### Credits

Special thanks to **wofsauge** and every contributor and translator of the original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions).
The bundled description database and EID presentation resources are included with attribution.

## v0.3.1

2026-08-13

This maintenance release fixes menu-only settings visibility in native iOS
Isaac: Repentance.

### Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

### Fixed

- The settings button now reliably disappears during gameplay.
- The settings button returns after Isaac reaches a menu.
- Player discovery no longer remains cached on the inactive main-menu player
  allocation when the active run uses a different heap region.

### Device validation

Validated in the real native iOS Isaac application by transitioning from the
main menu into a running save and back through menu/game state changes. The
standalone dylib remains independent of jailbreak runtime libraries.

### Credits

Special thanks to **wofsauge** and every contributor and translator of the
original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions).
The bundled description database is included with permission and attribution.

## v0.3.0

2026-08-13

This release adds a native settings interface, all 20 upstream EID languages,
and complete attributed description data in every packaged loading mode.

### Downloads

- **Jailbroken/rootless:** `IsaacExternalItemDescriptions-rootless.deb`
- **LiveContainer private app:** `IsaacExternalItemDescriptions-LiveContainer.framework.zip`
- **Direct embedded/non-jailbreak:** `IsaacExternalItemDescriptions-Embedded.zip`
- **Advanced manual installation:** `IsaacExternalItemDescriptions.dylib` and `descriptions.json`
- **Integrity verification:** `SHA256SUMS`

No IPA or game files are included.

### What's new

- Added a bottom-right settings button that is visible in Isaac's menus and
  automatically hides during a run.
- Added a reliable native language picker for all 20 EID languages.
- Added persistent horizontal and vertical description positioning, defaulting
  to 140 px from the left and 50 px from the top.
- Removed the startup information banner.
- Added English fallback for untranslated Repentance entries.
- Bundled the standard Repentance 1.7.9b (`rep`) description database in the
  rootless package, LiveContainer framework, and embedded archive.
- Added in-app credits and third-party attribution.

### Credits

Special thanks to **wofsauge** and every contributor and translator of the
original [External Item Descriptions project](https://github.com/wofsauge/External-Item-Descriptions)
and [Steam Workshop mod](https://steamcommunity.com/sharedfiles/filedetails/?id=836319872).
The description database is bundled with permission from the original EID
author. This iOS bridge would not exist without their work.

### Device validation

Validated in the real native iOS Isaac application:

- Rootless dylib injection and clean bootstrap.
- Menu-only settings visibility and automatic hiding during gameplay.
- Language changes during a running game (`ru` → `fr` → `en_us` → `ru`).
- Horizontal and vertical description positioning with 140/50 px defaults.
- All-language Repentance 1.7.9b database loading.
- No new Isaac crash report.

The standalone dylib continues to link only public Apple frameworks and libc++;
it has no ElleKit, Substrate, libhooker, or other jailbreak-runtime dependency.

## v0.2.0

2026-08-13

- Added an app-specific framework package for LiveContainer private apps.
- Added exact Isaac image selection when LiveContainer loads the patched guest
  executable as `MH_DYLIB` inside its host process.
- Allowed the verified Isaac UUID to bootstrap EID when LiveContainer retains
  its own bundle identifier.
- Added framework-local description database discovery and package validation.

## v0.1.0

2026-08-13

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
