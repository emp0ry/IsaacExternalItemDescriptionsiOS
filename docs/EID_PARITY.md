# Original EID parity target

The iOS port's behavioral reference remains revision `8b59d00c6828e333294639ad2b2b6875eae821cb` of wofsauge/External-Item-Descriptions, importing only standard-Repentance rules and excluding Repentance+ patches.

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
selected native player. Invalid native context preserves the base description.

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
conditions. Pause descriptions and the inventory list use the selected native
player's personal state, with a picker for Jacob/Esau and co-op. This is not a
complete reimplementation of every original co-op UI or twin/subplayer rule.

Tainted Cain's salvage descriptions use the actual room pool mapping, personal
Birthright, swallowed/equipped trinkets, and upstream localized pickup names.
Quest tags come from the installed game's item metadata. Cantripped (43), Death
Certificate dimension (2), and the native excluded room index (-12) preserve
ordinary descriptions. Missing native context also preserves the description.
Salvage pedestals do not show collectible transformation progress. No seeded
prediction of the individual random salvage drops is claimed.

The pause-inventory Bag of Crafting entry now reads the native cached outcome
for its actual eight ingredients and shows that item's localized description.
Partial bags show ingredient progress, never a guessed output. Viewing does not
craft or add the output to ownership. This is separate from the original EID's
full recipe-search/available-room-pickup helper, which remains unimplemented.
Pocket actives are resolved through `ActiveSlot + 1` references, preventing slot
3 from being misrepresented as Spoon Bender in the list and conditional state.

Book of Virtues uses upstream's standard-Repentance XML wisp table, localized
special effects and flags, the current absolute stage, and the original wisp/ring
icons. No-wisp and single-room cases are included. A Book of Virtues pedestal
previews the primary active slot of each native player, not all owned active,
secondary and pocket items. Passive Book
of Belial adds the imported active-item effects; ordinary Judas/Book of Belial
(34) alone does not enable it. The native `HasCollectible(59)` branch reports
virtual ownership for Judas/Black Judas with Birthright even when raw count 59
is zero. The read-only adapter evaluates that verified branch per player, honors
the native non-quest-item suppression flag, and does not insert a phantom item
into the pause inventory. Missing flag/count context suppresses the synergy.
Void's native absorbed-active list is separately inspectable. Validated active
IDs also participate in conditional ownership, including absorbed Spindown and
mimic previews, without altering physical ownership/counts or passive stats.
All new adapters are read-only.

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
equipped trinkets, and smelted regular/golden trinkets. Void-absorbed actives use
their own inventory section. Outside pause inventory, applicable any-player
conditions aggregate ownership; the pause inventory selects a native player.

## Current effects and personal inventories

Purity reads its native boost field and live temporary-effect presence, including
disabled/inactive state. It never advances RNG or predicts the next aura.
Modeling Clay reads the current room's cached item only while inspecting the
owned trinket. Equipped Clay remains available normally; swallowed-only Clay
requires **Hidden current effects**. Liberty Cap, Broken Syringe and Mom's Lock
also require this setting. Their current native trinket record selects a
candidate, which must be present in the actual applied temporary-effect list.
The iOS Liberty Cap table's mushroom order is retained rather than copied from
PC EID. No-effect rooms retain the ordinary trinket description. These reads
neither predict the next room nor advance RNG. Void reads the
persisted native int32 active-ID vector with bounded stable reads. Duplicate
copies are retained; consumed single-use items follow the game's own list.
Absorbed actives are clickable but not physically owned collectibles.
Void converts absorbed passives into stats; those are not entries in its
persisted active-ability list.

Pause rows carry native player index/type for collectibles, all four active
slots, pockets and swallowed trinkets. Same IDs belonging to different players
remain separate. Row selection does not search a combined list by item ID alone.
PlayerForm counters and current collectible/active counts are personal too.
Repeated physical collectibles use one row with a live `×N` quantity. Raw
counts and actual active-slot occurrences are merged without counting the same
copy twice, and quantity changes invalidate the inventory list signature.
Super Bum's current room familiar is matched to the native player through its
verified owner pointer. Missing/unstable room lists retain the single-player
fallback and suppress unverified co-op completion. See [release history](../CHANGELOG.md).

## Additional original conditionals

The reviewed duplicate and miscellaneous blocks are imported as declarative
rules, with explicit standard-Repentance branch filtering. No Lua is executed.
They preserve both synergy directions, owned/pedestal names, ordering layers,
unique IDs, localization replacements and colors. A duplicate-copy note applies
when owning another copy or Diplopia/Crooked Penny, but not in the item reminder.
The existing Pandora/Strange Key adapter owns its highlighting, avoiding a
second copy of that note. Unreviewed Lua expressions fail import rather than
being evaluated. Mama Mega's golden-bomb predicate uses the native player's
actual golden-bomb flag, with personal pause context and acquisition/removal
refresh. Arbitrary subplayer-count predicates remain outside this adapter;
this is not a claim to port every EID condition.

Missing Poster/Lost and Pandora's Box/Moving Box use only the selected loaded
Isaac save's achievement bytes (82 and 366), with stable manager, slot and
progress validation. Invalid or unloaded state suppresses the hint. Pandora's
current-floor highlighting follows the localized reward replacement. These
checks neither access Game Center nor alter save data.

Charge predicates use installed item metadata and actual four-slot snapshots.
They distinguish normal/timed/special charges and preserve upstream pocket-slot
inclusion/exclusion and chargeable-character rules. Pause descriptions use only
the selected player's slots. Native card and identified-pocket-pill ownership
can enable applicable conditions; unknown pills never expose their effect.

Glyph of Balance queries the supported iOS game's read-only native priority
function on the main thread, with private output variables, a validated current
player and prologue guard. This follows this executable's actual priority where
desktop thresholds differ, rather than predicting RNG or promising a specific
random room reward. It is shown in the owned pause description, not in Greed.
Sanguine Bond recognizes the native spike type/variant and renders the upstream
percent-bearing payout lines. It does not reveal the next random payout. Older
upstream translations may contain fewer probability lines than English/Russian.

## Charge-item conditionals

Three controls are independent and default to off, following original EID's
separate spoiler permissions: RNG predictions, Void/Black Rune stat previews,
and hidden current effects. Existing explicitly saved preferences are kept.
Deterministic Spindown, Flip and Glitched Crown remain enabled; the user's
existing iOS language and layout settings are unchanged.

The optional **RNG predictions (spoilers)** setting follows upstream's opt-in
approach to revealing outcomes, but uses this executable's verified native
branches. Crooked Penny displays heads/tails in its pause-inventory description,
including both Car Battery activations. Eternal D6 annotates a visible rerollable
pedestal with the next individual reroll's result; D Infinity's actual mode is
recognized. With Car Battery, the Eternal D6 label explicitly says first of two
rerolls only. No exact remaining-reroll count or second Eternal D6 outcome is
claimed. Native pedestal initialization/price handling can advance RNG after
morphing, so a desktop formula cannot establish those future states reliably.
All calculations operate on private copies, without executing an effect or
native RNG method. The setting defaults to off; malformed state suppresses the
prediction. See [release history](../CHANGELOG.md).

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

### Food and familiar conditionals

Short native pedestal cycles (Binge Eater / Soul of Isaac) follow the current
validated ID on the main thread, independently of the five-item Crown browser.
A display-link callback reads only the selected short-cycle object and redraws
only when its identity/context changes. The normal background heap/inventory
scan remains at 250 ms, and its results are revalidated before rendering so a
delayed scan cannot repaint the previous food/item. Run/room/seed, object state,
Curse of the Blind and sprite visibility are checked; removed/hidden/stale
objects are suppressed. No timing guess, native effect call or touch/window
change is used.

The standard-Repentance `bingeEaterBuffs` table supplies all eight food bonuses;
the original healing conditional also handles Tainted Bethany's blood charges.
The effective BFFS no-synergy, pedestal whitelist, Hive Mind and ignore lists
are imported with Repentance overrides, never Repentance+ patches. Familiar
number replacements share the original BFFS unique ID, so owning both upgrades
does not double the same bonus twice. Soul of Bethany and supported familiar
trinkets use their upstream-specific entries. Forgotten Lullaby includes clot
sources and the original wisp/Gello exceptions in both directions, alongside
the existing Lilith/Tainted Lilith character conditions.

Floor conditions use current any-player ownership; the pause item reminder
uses only its selected player's snapshot. Empty/unreadable fresh ownership does
not fall back to a stale aggregate. No new offsets, game hooks, RNG predictions
or native mutating calls are introduced. See [release history](../CHANGELOG.md).

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

Abyss information is pre-rendered from the pinned upstream `XMLLocusts`,
`AbyssTexts`, `AbyssLocustEffects`, and `TearFlagNames` tables. All 17 records
match the development iPhone's native `repentance-resources/data/locusts.xml`,
which is used only for private verification and is not distributed. Missing
special entries use the original one-locust, normal-size/speed, 1x-damage default.
Translated `abyssSynergies` override generated text before pluralization, as in
the original callback. Runtime ownership is scoped to the selected player's
native inventory, including pocket actives, with no gameplay writes or new
native calls. The information is also available in inventory descriptions.

For standard Repentance, only the first flag in EACH of the three locust-effect
and three tear-effect arrays is described, even if that first flag is -1. This
retains the native bug and upstream handling: Ipecac shows poison, not a second
explosive flag. Chance2/3 replace chance1 only when below 1; zero remains valid.
No Repentance+ quality damage multipliers or Repentance+ locust definitions are
imported. Host tests cover all languages, native data identity, special/default
records, removal, inventory use, and personal co-op isolation. Gameplay checks
after deployment remain separate; see the [release history](../CHANGELOG.md).

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

Absorption previews require **Void / Black Rune stat previews**, independently
of the RNG-prediction setting. With that option off the native probe skips their
forecast calculations. Enabled previews copy RNG records; they never invoke native RNG functions.
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
to host arithmetic/translation tests; see the [release history](../CHANGELOG.md).

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

Since v0.10.1, the final panel width fits the title and the widest laid-out body
line, including inline artwork and any cycle-counter header inset. The backdrop
is resized after the final header layout, without changing text scale. Every
visible description forces a backdrop with at least 72% opacity while the
native game is paused, even without an EID Items selection. Pause/resume
transitions update the existing backdrop without waiting for text changes.
This never overwrites the user's saved background preference; normal gameplay
resumes with the configured toggle and opacity.

The pause inventory also offers a read-only D Infinity browser. Its `0/10 ›`
overview cycles through the ten dice in upstream's standard-Repentance
`dinfinityList` order. This shares the existing in-header description control,
not the native Drop input or any use-item adapter. Selection survives refreshes
and resets when another inventory item is chosen or gameplay resumes. Native
D Infinity mode, charge and saves are not changed. See
[release history](../CHANGELOG.md).

## Native repetition previews

Wild Card appends the game's recorded active item, card, or concrete pill effect.
Vurp! appends the pill its saved non-golden color will produce. Both use localized
names and existing item/card/pill artwork. PlayerData saves these fields, so the
mod needs neither persistent event history nor a use-item hook. Fresh main-thread
resolution is bounded to validated current players; the raw state participates
in background refresh equality. Empty/invalid history fails closed, and unknown
pills never reveal Vurp! data. Normal/horse propagation and repeated Vurp! follow
the native implementation where upstream's Lua event-history approximation differs.
See [release history](../CHANGELOG.md).

## Pickup-order and inventory-count previews

The Stars? reads Player's native `ItemHistory` vector at `+0x24d0`, using its
28-byte records in native order. As in the game's `UseCard(73)` branch, frame-zero
starters, trinkets, active items, missing ownership, quest/protected items and
challenge starters are excluded. The native read-only removability predicate
at image `+0x505a54` supplies quest/challenge restrictions. A private copy of
counts simulates up to two removals for Tarot Cloth, including duplicate IDs;
no history entry, inventory count, RNG or save is modified. Unknown/unsupported
records suppress the prediction instead of substituting ID-sorted inventory.

Black Feather's qualifying ID lists and text are imported from original EID's
standard Repentance data. Main-thread native `GetCollectibleNum(id, false)`
(`+0x4ff70c`) and `GetTrinketMultiplier(id)` (`+0x506238`) retain stacked copies,
swallowed/golden trinkets and native effects. The renderer applies the original
callback's `0.5 * count * (Mom's Box ? 2 : 1) * (golden ? 2 : 1)` formula to the
displayed Feather. This is upstream EID preview semantics, not a claim to have
reproduced every final damage multiplier displayed by Isaac's HUD.

Both adapters validate the executable UUID, current player vector, native getter
prologues, array spans, IDs and ranges before querying. Pickup history, duplicate
collectible counts and swallowed count changes participate in refresh signatures.
Native queries run only when the corresponding description is displayed. No
gameplay hook, extra window, simulated touch or game-state mutation is added.
See [release history](../CHANGELOG.md).

## Glitched Crown native cycle

The supported `AddCollectibleCycle` routine at `0x10071812c` stores up to eight
additional collectible IDs at Pickup `+0x5e4`, with count `+0x604`. Its Glitched
Crown caller supplies four, producing five items including current SubType.
The update branch at `0x10071a520` shifts the queue and appends the old current
item before morphing to the next. No mutating routine is called by EID.

The main-thread reader validates the live pickup RTTI, type, active flags, seed,
native run/room context, curse mask and question-mark/forced-blind visibility.
Only bounded known IDs are accepted. The complete circular sequence is rotated
to a canonical representation before deduplication, so duplicate IDs cannot
make a changing cycle reset the UI. At least five unique IDs are required, as in
original EID's summary callback. Small Soul of Isaac cycles are not expanded.
The seed at `+0x3e8`, preserved by cycle Morph's keepSeed flag, identifies the
pedestal; `+0x3d8` is mutable RNG state and is not used as an identity key.

A tap on the description replaces desktop Tab. A noninteractive `0/5 ›` label
inside the header's top-right corner shows the current selection; its width is
reserved independently of the title and does not shrink body text. The overview
lists each native icon/name; subsequent taps display each full description and then return to
the overview. Bounded per-room selection records are scoped to native run,
room/dimension, entity address, seed and cycle contents. Changed reroll results
reset the selection; menu/modal/inventory/hidden/absent pickup states hide the
indicator and disable description hit-testing. Only a valid cycle enables the
description's existing panel as a control; all ordinary descriptions remain
touch-transparent. The existing single-window passthrough view and readiness gate remain.

Selected-item Spindown is freshly queried for the selected ID, not copied from
the currently flashing native subtype. Existing hypothetical Abyss, character,
transformation and Flip text remains applicable. The synthetic overview gets no
Glitched Crown collection-page reminder or Spindown chain. Native room-based
Void/Black Rune absorption predictions are suppressed for cycle previews rather
than attributed to a hypothetical item that is not currently on the pedestal.
Device acceptance is tracked in [release history](../CHANGELOG.md).
