# Supported native Isaac layout

This project supports the ARM64 Isaac executable whose `LC_UUID` is:

`F4357753-A25F-30EE-BACF-63709F902895`

Unknown executables fail closed before entity memory is scanned. Offsets must be
revalidated for every new UUID.

## Read-only dynamic description fields

### Original defaults, current trinket effects and unlock hints

- Three independent options mirror upstream defaults: RNG predictions, Void/
  Black Rune stat previews and Hidden Info are all off. Opting into RNG does
  not enable the other two. Spindown is an ID operation, not an RNG prediction.
- Native new-room setup at `0x10054c754` reads the trinket RNG vector at
  `Player + 0x1bc8`. Its 16-byte records for IDs 32, 132 and 153 select entries
  in tables at `0x100953360`, `0x100953378` and `0x100953398`. The tables are
  checked against this executable before use. The iOS Liberty Cap table swaps
  the two mushroom entries relative to the upstream PC table.
- The reader uses the current saved seed modulo the verified table length,
  without advancing RNG, and requires the candidate to be present in the
  current temporary-effect list. It implements the metadata-type 1/3/4 and
  disabled-byte predicate of `HasCollectibleEffect` at `0x1006fdc90` with stable
  bounded copies. A failed room proc never exposes a future result.
- `Player + 0x16d9` is the golden-bomb byte: add at `0x1005526f0`, removal at
  `0x10055272c`, and Mama Mega's branch at `0x10058ad78`. Double reads accept
  only 0/1. It is not inferred from the ordinary bomb count.
- `PersistentGameData::Unlocked` at `0x1007027f8` reads raw flags at
  `PersistentGameData + 0x28 + achievementID`. The adapter reads only Lost (82)
  and Moving Box (366), validates the selected Repentance save slot before
  and after, and suppresses hints in read-only/custom contexts. It does not
  call an unlock setter, use Game Center, or inherit the getter's special
  challenge-mode fallback. The shared localized replacement also adjusts
  Pandora's floor-highlight matching after Moving Box is unlocked.

### Additional original conditions (2026-10-16)

- `Player::GlyphOfBalance` at image + `0x554364` is called by native reward
  selection at `0x10059f034`, with arguments `(player, &variant, &subtype)`.
  Disassembly through `0x1005546c8` establishes that its game-dependent work
  reads health, consumables and current room entities; only the two output
  arguments and its private temporaries are written. The adapter runs on the
  main thread after UUID/player-vector validation and checks prologue
  `0xd10183ff`. It invokes no reward, effect or RNG path.
- Native Glyph reads the health range starting at `Player + 0x16b8`, bone
  containers at `+0x2450` and Tainted ??? poop mana at `+0x269c`. The background
  reader includes these fields only as an immutable refresh signature.
- `Familiar + 0x400` is the owning player pointer: initialization stores the
  player/spawner there at `0x1007fbf8c`; update reads the owning player's
  position at `0x10080860c`. Personal Super Bum completion uses only live
  type-3/variant-102 familiars in the authoritative current-room entity list,
  stable owner reads and exact matches against the validated player vector.
- `GridEntity_Spikes + 0x8/+0xc` are type/variant. Native spike update at
  `0x1004de0a4` reads both and compares type 8 with variant >99 for Sanguine
  behavior. `+0x10` is a different state field, not the variant. The adapter
  bounds the current grid using the native room width/height and does not
  conflate these spikes with Sacrifice Room counters at `+0x1c`.
- Ordinary charging context adds no new offsets: it uses the already validated
  four active-slot IDs and installed XML charge metadata.

A removed external read-only diagnostic confirmed native player-slot access and
a 15-by-9 room grid on the development phone. No Sanguine spikes or familiars
were present in that sample, so nonzero behavior still needs gameplay checks.

### Current effects and personal inventory (2026-10-16)

| Field | Offset | Independent native references |
| --- | --- | --- |
| Void absorbed actives | `Player + 0x1b78` int32 vector | UseVoid `0x10058bf50`; HasVoidedCollectible `0x100508b30`; PlayerData copy `0x1005501cc` |
| Purity current boost | `Player + 0x1da4` int32, 0..3 | Stat evaluation `0x1004f1b28` and siblings; selection writes `0x100502e2c`, `0x10050c460` |
| Temporary effects | `Player + 0x18d8`; vector at +8, disabled byte +0x21 | Read-only HasCollectibleEffect `0x1006fdc90` |
| Modeling Clay current item | `Player + 0x2730` int32 | New-room clear `0x10054c998`; applied result write `0x10054ce8c`; GetCollectibleNum `0x1004ffa40`; PlayerData copy `0x10054ffac` |

The effects predicate accepts metadata types 1, 3 or 4 and ID 407, exactly as
the native getter does. Purity's saved choice alone is not evidence of an active
aura. Clay reads only the already-applied room result; no RNG or selection
function is invoked. Void spans are bounded to 1024 IDs, copied twice and
revalidated; duplicates are retained. Effect lists and current fields are
bounds/type checked and unavailable state suppresses additional information.

A temporary read-only task probe on the development phone confirmed a live
Tainted Cain player, empty Void span, neutral cached fields and valid native
effect records. This baseline confirms structure access, not acceptance of
nonzero Purity/Clay/Void behavior; those still require the gameplay scenarios.
The probe is not part of the product or repository and is removed after use.

Inventory entries now carry their original native player vector index/type.
Physical actives are read from all four 28-byte records, never inferred from
raw pocket references. The UI selects a player before listing items. Per-player
PlayerForm arrays and current counts are separate from the older aggregate
compatibility API; merged Super Bum ownership is resolved as described above,
never guessed from a partner's global completion flag.

All fields below are for the UUID above, and are bounds/type checked before use:

| Field | Offset | Native reference |
| --- | --- | --- |
| Pandora reward stage | `Game + 0x0` | Pandora branch `0x10058b438`; stage tables `0x10058bb50`, `0x10058dcf8` |
| Pandora late-game route | `Game + 0x4` | Cathedral/Chest branches `0x100590928`, `0x100590358` |
| Move speed | `Player + 0x194c` (float) | Consolation Prize stat comparison `0x100502140` |
| Max fire delay | `Player + 0x1834` (float) | `0x10050214c` |
| Damage | `Player + 0x1844` (float) | `0x100502158` |
| Tear range | `Player + 0x1854` (float) | `0x100502164` |
| Coins / bombs / keys | `Player + 0x16e0 / 0x16dc / 0x16d4` (int32) | Native weighted comparison `0x1005035d8` onwards |
| Bethany soul / blood charges | `Player + 0x2478 / 0x247c` (int32) | Character branches `0x100503610`, `0x100503640` |
| Smelted trinket vector | `Player + 0x1b60` (begin/end/capacity pointers) | Native indexed count access `0x100509680`, `0x1005096d4` |
| Challenge ID | `Game + 0x1cf438` (int32) | Tainted Cain pickup guard `0x100720a68`; Cantripped is 43 |
| Current room index | `Game + 0x21558` (int32) | Tainted Cain pickup guard `0x100720a90`; native excluded index is -12 |
| Current dimension | `Game + 0x21560` (int32) | Tainted Cain pickup guard `0x100720a84`; Death Certificate is dimension 2 |
| Room-type pool maps | `ItemPool + 0x920` normal / `+0x998` Greed (int32 arrays) | `GetPoolForRoom` at `0x100877a3c`, indexed by room type |
| Non-quest-item suppression | `Player + 0x284c` (byte) | `HasCollectible` guard `0x1004eebe0`; checked before reporting effective Belial |
| Active-item slots | `Player + 0x1964`, four records, stride `0x1c` | `GetCollectibleNum` reads all four IDs at `0x1004ff7b0`; `RemoveActiveItem` resolves pocket references at `0x100505b6c` |
| Bag ingredients | `Player + 0x2690`, eight bytes | Native ingredient append/shift at `0x100554f70`; values 1–29, trailing zeroes mark empty slots |
| Bag cached result | `Player + 0x2698` (int32) | Filled by `0x100555140`; consumed by crafting at `0x100528cfc` and `0x10058a3c0`; also read by the native HUD at `0x1006e5c1c` |

The four eight-byte pocket entries contain `{value, type}`. Type 0 stores a
pill color, type 1 a card/rune ID, and type 2 **ActiveSlot + 1**, not an item ID.
Resolve a nonzero type-2 value through the corresponding active-item record.
The raw pocket array and active IDs are copied twice; changing/invalid snapshots
fail closed. This shared decoder is used both by pause inventory and personal
owned-item conditions. Genuine Spoon Bender ownership is not filtered out.

The crafting preview only reads the already calculated native result. No call
to the recipe calculator or item-use path is made. Main-thread resolution
requires a live paused player who actually owns Bag of Crafting, validates a
stable 12-byte ingredients/result snapshot, and only substitutes a result when
all eight ingredients are present and its ID is 1–732. The background context
includes bag contents so changing ingredients invalidates a selected preview.
No preview enters inventory counts, transformation history or save state.

## Optional outcome predictions

For the supported UUID only:

- Crooked Penny's branch starts at `0x10058623c`. It advances collectible RNG
  entry 485 (`Player[0x1bb0] + 485 * 16`) using shifts `(5,9,7)`. The new value
  is XORed with `Room[0x8]->DecorationSeed` at `+0x64`; zero becomes one. A
  separate stack RNG uses shifts `(1,11,6)`, and an even result is heads.
  Tails advances the original collectible stream once more for the consolation
  penny (`0x100586384`). Car Battery's second activation must continue that
  original stream, not the mixed stack RNG. No native RNG method is called.
- Eternal D6 at `0x100582340` reads the pickup's **current RNG seed `+0x3d8`**,
  not the stable InitSeed/cycle key at `+0x3e8`. The copied seed uses table index
  44, `(5,27,25)`. Native `RandomFloat` casts the roll to single precision and
  multiplies by float bits `0x2f7fffff`; the vanish comparison is `<= 0.25f`.
  Reproduce that rounding, including boundary seeds 8, 41, 74, 107, 140 and 173.
  The current upstream PC path `(5,27,8)` must not be substituted here.
- The read-only `CanReroll` getter at `0x1007180d8` and the native state guard
  using pickup `+0x55c/+0x570` prevent claims about ineligible pedestals.
  Vtable, alive state, identity, InitSeed, run session, blind sprite state and
  level curses are revalidated on the main thread before publishing a result.
- D Infinity's real per-active-slot mode is signed int16 at `record + 0x1a`;
  mode 3 is Eternal D6. Browsing hypothetical dice in EID Items is not an actual
  mode change and does not enable pedestal predictions for another die.

These previews validate native instruction signatures but never invoke the
item-use, reroll, pool-draw or RNG functions. Future Eternal D6 counts and its
second Car Battery reroll are deliberately not inferred: morphing reruns pickup
initialization and price handling, which can advance the pickup RNG. The UI
labels this limit instead of promising a safe full double activation.

`HasCollectible(59)` at `0x1004eed80` returns true for Judas/Black Judas (types
3/12) with Birthright (619), independently of a raw inventory count of 59.
The presentation snapshot reproduces this branch read-only, including the
suppression guard. The raw inventory and game state are not modified.

The pool mapper's Error Room (type 3) branch performs a random room-type choice.
That branch is not executed or simulated: Error Rooms get no guaranteed-room
pickup claim. The challenge/dimension/index offsets above are statically verified
against the supported executable; gameplay acceptance testing is recorded separately.

Each smelted slot is four bytes: regular and golden signed int16 counts.
Vector bounds, four-byte stride, counts, and the supported trinket-ID range
are checked; malformed snapshots cannot become inventory identities.
The vector validation/decoding policy is also exercised by host tests.

## Runtime types

The resolver finds C++ RTTI and primary vtables in the loaded main executable:

- `IsaacRepentance::Entity_Pickup`
- `IsaacRepentance::Entity_Player`
- `IsaacRepentance::Entity_Slot`
- `IsaacRepentance::Entity_Effect`
- `IsaacRepentance::GridEntity_Spikes`

It then takes read-only snapshots with `vm_read_overwrite`. It does not hook the
allocator and does not directly dereference mutable game allocations.

## Verified ARM64 offsets

| Field | Offset | Validation |
| --- | ---: | --- |
| Entity Type / Variant / SubType | `0x38` | Live collectible IDs matched visible pedestals |
| Entity valid / visible / exists / dead bytes | `0x1c0` | Live valid entity bytes were `1,1,1,0` |
| Entity logical position | `0x310` | Player and pedestal movement matched the screen |
| ANM2 layer-state pointer | `0x0f8` | Runtime snapshot and native spritesheet access |
| ANM2 layer count | `0x100` | Six live pedestal layers observed |
| Pickup auto-update-price byte | `0x560` | Native shop-price update code |
| Pickup touched byte | `0x561` | Native pickup init/collision/morph preservation code |
| Pickup forced-blind byte | `0x562` | ARM64 disassembly of native `SetForceBlind` |
| Pickup price | `0x564` | Native `IsShopItem` returns `Price != 0` |
| Pickup Options index | `0x56c` | Live shop and floor pickup instances; positive values identify an `Options?` group |
| Crane Game prize collectible | `0x570` | ARM64 disassembly of `Entity_Slot::SetPrizeCollectible` |
| Player can-fly byte | `Entity_Player + 0x1954` | Live flight state and repeated native `ldrb` call sites in movement/collision paths; must be read as one byte rather than as the adjacent four-byte word |
| Player character type | `Entity_Player + 0x1738` | Repentance ChangePlayerType/character-specific branches read this int32; valid native types are 0–40 |
| Game difficulty | `Game + 0x24f9d8` | Native IsGreedMode at `0x10088c994` reads `(difficulty & ~1) == 2`: normal 0, hard 1, Greed 2, Greedier 3 |
| Player pocket items | `Entity_Player + 0x1c10` | Live held-card and rune identity matched pocket slots |
| Player trinket slots | `Entity_Player + 0x1ab0` | Native GetTrinket call sites and both live slots |
| Player collectible-count table | `Entity_Player + 0x1ab8` | Live inventory changes matched collected items |
| Player transformation counters | `Entity_Player + 0x1c54` | Native 15-entry add/remove, save, and restore loops |
| Game level curse mask | `Game + 0x0c` | Live Curse of the Blind state matched mask `0x40` |
| Game current room | `Game + 0x21550` | Live room transitions matched room descriptor state |
| Game run seed | `Game + 0x25d44` | Stable within a run and changed when starting a new run |
| Game pause-menu state | `Game + 0x10dfd8` | PauseScreen state switch; valid values are `0...3` |
| Room grid-entity table | `Room + 0x30` | Live Sacrifice Room spikes and activation count |
| Room grid width / height | `Room + 0x14` / `+0x18` | Native grid-index conversion and bounds checks |
| Room grid-path table | `Room + 0xe98` | Native `GetGridCollision` and path update code |
| Game ItemPool | `Game + 0x242c0` | Native `GetPillEffect` call sites |
| ItemPool pill effect array | `ItemPool + 0xa2c` | ARM64 `GetPillEffect` implementation |
| ItemPool identified-pill bytes | `ItemPool + 0xa68` | Native identification code and state copy |

The iOS `LayerState` stride is `0xb0`; its libc++ replacement spritesheet path
starts at `+0x10`. Native `ANM2::GetLayer` at `0x10089f558` multiplies the
layer index by `0xb0`, and `ReplaceSpritesheet` at `0x1008a0250` writes the
override at layer `+0x10`. Both instruction signatures are checked at runtime.
The old `0x90`/`+0x08` layout was incorrect and could miss question-mark art.

A collectible is hidden if its forced-blind byte is set or any layer uses
`gfx/Items/Collectibles/questionmark.png`. Native blind-artwork setup at
`0x100718f9c` assigns this path to layer 1 even when ForceBlind itself is zero.
Missing layer 1, an empty item-artwork override, unreadable strings or an
unverified ABI fail closed and produce no description. The same byte decoder
is exercised by local native-layer fixtures, including long and short strings.

The current level curse mask is also read from `Game + 0x0c` for diagnostics.
Bit `0x40` identifies Curse of the Blind, but it is not a blanket suppression
rule: a previously held active left on a pedestal after swapping can have
visible artwork on the same cursed floor. Actual per-pickup artwork and native
ForceBlind determine visibility in scan, live-update and cycle paths.

## Supported pickup identities

- Variant `100`: collectibles
- Variant `300`: cards and runes
- Variant `350`: trinkets (including the golden-trinket high flag)
- Variant `70`: pills; identified colors resolve to effect IDs
- Internal variant `2070`: unidentified pills; native color is retained for artwork without exposing the effect
- Type `6`, variant `16`: Crane Game prize collectible
- Type `1000`, variant `76`: Dice Room floor effect; subtype `0...5` maps to faces `1...6`
- Room type `13`, grid type `8`: Sacrifice Room spikes; `VarData + 1` is the next payout

Normal pill descriptions use the resolved effect plus one, matching upstream
EID's lookup convention. Bit 11 selects the horse-pill table. Golden color 14
uses the upstream random-effect Golden Pill entry. Unknown pills preserve only
their color and render the upstream localized unidentified label.

Floor card/rune/pill visibility mirrors original EID's defaults. The native
price at `Entity_Pickup + 0x564` marks a shop pickup when nonzero, and the
`OptionsPickupIndex` at `+0x56c` marks an `Options?` choice when positive.
Ordinary shop cards and all `Options?` cards are hidden; shop Soul Stones and
shop/`Options?` pills are shown. Reachability uses the native room dimensions
and `Room::_gridPaths`, with the same four-direction search and `path <= 900`
rule as upstream EID. The verified native `CanFly` word bypasses obstruction.
`Pickup::Touched` is deliberately not used as a general card-knowledge flag.

The native `Entity_Player::_playerForms` array has 15 persisted `int32`
counters starting at `+0x1c54`. Isaac copies the complete 60-byte array into
and out of its player save state. EID transformation IDs are mapped to the
native PlayerForm order rather than treated as the same enum:

| EID | Native | Form |
| ---: | ---: | --- |
| 1 | 0 | Guppy |
| 2 | 2 | Fun Guy |
| 3 | 1 | Lord of the Flies |
| 4 | 7 | Conjoined |
| 5 | 5 | Spun |
| 6 | 6 | Yes Mother? |
| 7 | 9 | Oh Crap |
| 8 | 4 | Bob |
| 9 | 8 | Leviathan |
| 10 | 3 | Seraphim |
| 12 | 10 | Bookworm |
| 13 | 12 | Spider Baby |
| 14 | 11 | Adult |
| 15 | 13 | Stompy |

Super Bum is a familiar merge rather than a native PlayerForm. Its partial
progress uses the three source collectible identities, and completion is
verified from the live `Entity_Familiar` type `3`, variant `102`, so the display
remains `3/3` after the source familiars merge. In co-op, each player has an
independent counter array; the overlay displays the highest valid per-player
counter instead of incorrectly summing two players.

The pause browser reads PauseScreen state `1...3` as paused and `0` as live
gameplay. The inventory and settings buttons are enabled only for a verified
paused state; an invalid read fails closed and leaves both controls hidden.
