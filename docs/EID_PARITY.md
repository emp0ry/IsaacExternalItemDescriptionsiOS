# Original EID parity target

The `main` branch contains the iOS port's work toward visual and behavioral parity with wofsauge/External-Item-Descriptions. The reference for v0.9.0 is revision `8b59d00c6828e333294639ad2b2b6875eae821cb`, importing only standard-Repentance rules and excluding Repentance+ patches.

## Reference defaults

The desktop mod currently defaults to:

- `FontType = default`
- `TextboxWidth = 130`
- `Size = 1`
- `Transparency = 0.75`
- `XPosition = 60`, `YPosition = 45`
- `LineHeight = 11`
- `DisplayMode = default`, with local mode available
- `MarkupSize = default`
- item names, item type, item icon, descriptions, and quality enabled
- `ItemNameColor = ColorEIDObjName`
- quality rendered as a dedicated inline `Quality0` … `Quality4` icon, not by recoloring the title per quality

## iOS parity layers

1. **Presentation** — EID-style item-name color, outlined text, compact line spacing, opacity and scale.
2. **Markup** — replace emoji approximations with EID inline sprite icons and honor color markup.
3. **Metadata** — expose quality, item type/charge, transformations and pools where available.
4. **Options** — mirror applicable EID display settings in the iOS settings card.
5. **Modes** — retain the fixed, nearest-object overlay; desktop local/near-item and simultaneous multi-object modes are outside this release's scope.

The upstream EID repository remains the behavioral reference. Assets copied into distributable builds must retain upstream attribution and compatible licensing notices.

## Pickup knowledge parity

The iOS native probe mirrors upstream defaults independently for ordinary
cards/runes, Soul Stones, and pills. It reads native shop price and
`OptionsPickupIndex` fields, native pill-identification state, room grid paths,
and player flight. `Pickup::Touched` is not used as a blanket identity rule.
Unknown pills keep their real color icon but never reveal their effect.

## Character and mode context

The importer includes upstream `ConditionalDescs`, Repentance `repConditions`,
`RedToX`, and Birthright tables for the supported languages. The presentation
adapter applies static character rules from the reference source, translated
health-type replacements, and static Greed/Greedier rules. Pickup descriptions
use the closest native player's character type; the pause inventory uses the
primary player. Invalid native context preserves the base description.

Exported Birthright entries are keyed by the native `PlayerType` enum (`0...40`),
not Lua's array index (`1...41`). The importer subtracts one specifically for
this table; stat-name arrays retain their normal one-based Lua indices.
Regression tests assert all 41 English names against fixed native IDs and
exercise actual Lost Breakfast and Birthright descriptions in English/Russian.

The importer also covers the miscellaneous character rules after the weapon
block: Eye Drops, Tainted Samson/Uranus, Keeper/IV Bag, tainted Clicker, and
Dead Cat's no-red-health condition. BFFS' separate Repentance localization patch
is merged for Lilith and Tainted Lilith. Esau's regular-character equivalence
does not incorrectly classify him as tainted.

Player-wide conditions examine the validated native player list; closest-player
rules retain that distinction and append localized "Different effect for ..."
annotations for other character types. Personal inventory snapshots are indexed
by native player, so same-character co-op players do not exchange ownership
conditions. Pause descriptions use the primary player's personal owned-item set;
the inventory list itself remains the existing aggregated view. This is not a
complete reimplementation of every original co-op UI or twin/subplayer rule.

Tainted Cain's salvage descriptions use the actual room pool mapping, personal
Birthright, swallowed/equipped trinkets, and upstream localized pickup names.
Quest tags come from the installed game's item metadata. Cantripped (43), Death
Certificate dimension (2), and the native excluded room index (-12) preserve
ordinary descriptions. Missing native context also preserves the description.
Salvage pedestals do not show collectible transformation progress. No seeded
prediction of the individual random salvage drops is claimed.

Book of Virtues uses upstream's standard-Repentance XML wisp table, localized
special effects and flags, the current absolute stage, and the original wisp/ring
icons. No-wisp and single-room cases are included. A Book of Virtues pedestal
previews owned active items (including the secondary/pocket active), rather than
claiming they are all the currently selected primary active slot. Passive Book
of Belial adds the imported active-item effects; ordinary Judas/Book of Belial
(34) alone does not enable it. The native `HasCollectible(59)` branch reports
virtual ownership for Judas/Black Judas with Birthright even when raw count 59
is zero. The read-only adapter evaluates that verified branch per player, honors
the native non-quest-item suppression flag, and does not insert a phantom item
into the pause inventory. Missing flag/count context suppresses the synergy.
Void-absorbed actives remain unavailable. All new adapters are read-only.

Stat icon aliases such as `Damage` are resolved to their original `DamageREP`
frames when importing assets. The renderer also resolves these aliases for older
resource bundles, which previously omitted the sword before a wisp's DPS value.
Font size and icon attachment scaling are unchanged.

Native inline collectible/trinket sprites are now cropped to their nontransparent
bounds before caching and scaling. Their original 32-pixel canvases contain very
different padding: the visible Red Key is only 14 pixels tall, while Spindown is
19. Cropping prevents the canvas padding from reducing these icons relative to
other inline symbols, without enlarging the description font or battery.

## Guest startup readiness

The bootstrap waits for the supported game's `AAPLOpenGLView`, its native
controller and `_displayLink`, landscape render bounds, and two distinct observed
frame timestamps. Application activity alone is insufficient when LiveContainer's
host is already active before its guest has finished initialization. Window
selection uses only already-loaded game views; it neither forces view loading nor
selects an unrelated host window just because that window is key. The overlay
retains the existing single-window hit-testing architecture.

The user confirmed that the startup-order correction resolves the stuck joystick
on the affected LiveContainer device, and separately confirmed the inline artwork
size correction. This is not a claim of testing every iOS/LiveContainer combination.

## Weapon overrides and synergies

The importer expands upstream's complete **Overrides / Overridden By** block
for standard Repentance, excluding its AB+-exclusive branch. Both directions
of `AddSynergyConditional`, the shared priority name in
`AddOneSidedSynergyConditional`, and normal/tainted Azazel conditions are
preserved. Imported rules retain their layer, `checkLayers`, owned-item
bulletpoint, variable text, and unique identifier. Unknown syntax aborts the
import instead of silently guessing.

The contextual renderer checks a read-only native inventory snapshot and
applies higher-priority rules first, alongside character and mode conditions.
Special combinations use their actual upstream text rather than a blanket
"no effect" warning. Names use the active language with English fallback; item
and trinket bullet icons use artwork from the installed game. The overlay's
refresh signature includes inventory identities, so acquiring or losing an
override item updates an unchanged floor pickup's description.

This covers the original weapon-override block, not all EID item synergies.
The current native inventory exposes owned collectibles, pocket actives,
equipped trinkets, and smelted regular/golden trinkets. Void-absorbed actives are
not separately tracked yet. Outside pause inventory, owned items are aggregated across native
players; the existing pause inventory also remains an aggregated view.

## Charge-item conditionals

`carBattery`, its `repCarBattery` overrides, `tarotClothBuffs`, and the effective
Repentance no-synergy/Car Battery pedestal lists are imported from upstream.
AB+-only values and Repentance+ patches are not used. Numeric pairs replace a
complete number once, including decimals; string pairs retain localized text.
The iOS renderer recognizes the associated item bullets and effect colors.
For legacy localized find strings that contain color tags missing from their
updated base text, only those obsolete formatting tags are ignored for matching.

Car Battery pedestal annotations are suppressed in the pause item reminder,
as upstream does. Its own active-item buffs and Tarot Cloth card buffs remain
visible there. Native active-item metadata limits charge modifications to
actual actives; missing inventory/metadata never invents a synergy.

## Native dynamic context

The native reader validates the floor and each player's speed, fire delay,
damage, range, consumable counts, and character-specific charge pool. Unknown
or invalid snapshots suppress only the affected prediction. There are no
gameplay hooks or game-state writes for these features.

Consolation Prize uses upstream's four normalized-stat formulas, rounding to
two decimals, consumable weighting, quantities, and localized stat/pickup
names. Equal candidates are marked `?`, not asserted as an exact seeded RNG
result. The prediction is displayed on Consolation Prize itself; the reference
snapshot's callback registration would otherwise add it to unrelated item
descriptions after owning the item. Character-specific charge candidates and
co-op player summaries are supported.

Pandora's Box uses the supported executable's native reward-stage fields, not
an inferred HUD floor name. Exact floor segments are classified per language,
including semicolon-separated entries and reviewed older translations missing
Void, Dark Room, or Home. Greed/Greedier have their own payout map. Only the
complete applicable segment turns green; an unavailable/missing entry is not
guessed. Strange Key suppresses the floor highlight and highlights its own
overriding six-item payout. This highlighting currently targets Pandora's Box,
not every floor-dependent item in the game.
For iOS presentation, semicolon-separated floor rewards become individual
lines and the desktop `NoLB` marker is removed, even with unavailable floor
context. Only the selected reward segment receives the green color.

Smelted trinkets are decoded from a bounded native vector of regular/golden
int16 count pairs. Invalid pointer ranges, strides, or counts fail closed.
They have their own pause section, are included in owned-item checks, and are
cleared with native run state. Golden trinkets and Mom's Box additionally use
the original standard-Repentance per-trinket multiplier/replacement tables.

## Advanced contextual previews

Luck formulas are exported as restricted arithmetic trees, not executable Lua.
Repentance overrides are applied; Repentance+ overrides are excluded. The
native Luck float is Player + `0x1950` (independently used by Lodestone's proc).

Spindown previews three uses and consumes two valid steps per use with Car
Battery, except that Dad's Note stops the chain. On the main thread, the native
adapter revalidates the player vector and live Spindown/Car Battery ownership,
then reads bounded collectible config pointers from Manager + `0x55f30`.
It calls `ItemConfig::IsAvailable(config, 3)` at image + `0x73fab0`, the same
flags and routine used by native Spindown at `0x100585474`. This includes
achievement locks and current-run restrictions; hidden/missing config IDs are
skipped. No reroll or RNG API is invoked. Both queried routine prologues and
the executable UUID are validated before calls. The callback flag (8) is off.

The achievement getter at image + `0x7027f8` distinguishes achievement locks
from other restrictions. It reads PersistentGameData's achievement bytes at
`+0x28` (638 entries) and respects the game's trial/daily override state. The
loader independently confirms the array. Collection-page flags at `+0xa68`
are unrelated and never determine availability. Locked and other unavailable
candidates are skipped completely, without crossed-out icons, names or warning
rows. Results form one arrow-connected paragraph, without a forced line break or
repeated Spindown prefix per use. Each use shows only the real eligible result. Missing native data
suppresses the chain; it does not assume everything is unlocked. Disappearance
is shown even after preceding successful uses. Absorbed Spindown inside Void
is not tracked yet.

Mimic charges are parsed from installed `pocketitems.xml`, including rune/Soul
Stone type distinctions and zero-based pill-effect IDs. Unknown/random pills
never reveal an effect through their charge cost. Flip's alternate identity is
read from Pickup + `0x610`, saved record subtype + `8`; ForceBlind is saved at
record + `0x23`. Existing curse, sprite and native blind checks remain in force.
Flip remains included in the build, but live device verification is pending.

Absorption previews copy RNG records; they never invoke native RNG functions.
Void uses Player's collectible RNG vector + `0x1bb0`, entry 477; Black Rune
uses the card RNG vector + `0x1bf8`, entry 41. Sixteen-byte records contain
seed and shifts. Only nonzero seeds with verified shifts `(5,9,7)` are accepted.
Void advances the private copy once before the Fisher-Yates stat selections;
Black Rune does not. Both produce two increments per absorbed pedestal.

Room entities come from Room + `0x19c8`, count + `0x19d4`, with bounded spans,
RTTI, removal, shop and crane checks. Shared Options? groups count only their
first eligible pedestal. Void ignores actives except Moving Box; Black Rune
includes them. Preview refreshes with immutable native context, off the main
thread. Co-op chooses the nearest player's inventory and RNG. Missing data
suppresses the affected feature. Live device testing is required in addition
to host arithmetic/translation tests; see `testing-advanced-previews.md`.

Transformation counts are rendered directly from the tracker for collectibles,
identified normal/horse pills, and assigned trinkets. This avoids an asynchronous
text replacement that previously left pill transformation labels unchanged.
Counts are not capped at the requirement: a valid native counter of four is
displayed as `4/3`, matching EID's native-counter path.

Some older base translations, including Russian Contract from Below, include
a static Greed no-effect caveat as well as the original conditional notice.
The importer classifies these exact legacy notes without changing the base
description. The iOS adapter renders the canonical conditional once in
Greed/Greedier and omits the legacy caveat in normal/hard runs. Unrelated Greed
enemy references are preserved. Single-entry replacement tables and ordered
first-occurrence replacement pairs retain the original conditional semantics.

An optional description background is disabled by default and is rendered in
the established non-interactive description panel. Its opacity is independent
of text opacity and the settings stay within the existing scroll view.
