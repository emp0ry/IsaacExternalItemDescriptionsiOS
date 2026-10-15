# Isaac External Item Descriptions iOS v0.10.0

Six more original-EID-style contextual previews, backed by native iOS game state.
All v0.9.0 features and the LiveContainer startup fix remain included.

## Glitched Crown

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

## Abyss

- Collectible descriptions show the locust count, damage multiplier, size,
  speed, and applicable special effects when the selected player owns Abyss.
- Uses the original standard-Repentance definitions: 17 special records plus
  the normal one-locust, 1x-damage fallback.
- Includes the original game's first-flag behavior: for example, Ipecac's
  locust applies poison, not the later explosive flag.
- Does not apply Repentance+ quality-based damage scaling to the older iOS game.
- Available in floor and pause-inventory descriptions, with localized text and
  English fallback where the original translation is incomplete.

## Wild Card and Vurp!

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

## The Stars? and Black Feather

- **The Stars?:** previews the oldest eligible passive item that will be removed,
  or two with Tarot Cloth. Native pickup order, current counts, starting-item
  exclusions, active-item exclusions, and quest/challenge protections are used.
  Duplicate copies are handled without inventing extra owned items.
- **Black Feather:** shows the live qualifying-item count and damage bonus.
  Duplicate collectibles, qualifying equipped/swallowed trinkets, Mom's Box,
  and golden Black Feather follow the original EID callback's calculation.
- Both previews include original localized text and icons. Unavailable or
  invalid native data preserves the ordinary description instead of guessing.

## Compatibility and verification

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

## Downloads and upgrading

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
