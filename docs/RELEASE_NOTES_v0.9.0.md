# Isaac External Item Descriptions iOS v0.9.0

More useful information before you pick up, reroll, or absorb an item, plus a
LiveContainer startup fix and clearer inline artwork. All v0.8.0 character,
weapon, wisp, inventory, and floor features remain included.

## Reroll and absorption previews

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

## Luck, trinkets, and charge costs

- Supported Luck-sensitive effects now show their proc chance at the player's
  current Luck, using original **standard Repentance** formulas.
- Golden trinkets and Mom's Box apply per-trinket multipliers, special cases,
  and localized replacement descriptions, with adjusted values highlighted gold.
- Blank Card, Clear Rune, and Placebo show the displayed card, rune, or identified
  pill's charge cost from the installed game's metadata. Unknown pills cannot
  reveal their effects through a charge-cost preview.
- Includes applicable Blank Card + Tarot Cloth notes.

## Collection and pill information

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

## Presentation and LiveContainer

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

## Validation and compatibility

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

## Downloads and upgrading

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
